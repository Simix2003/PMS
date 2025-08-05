import asyncio
import snap7.client as c
import snap7.util as u
import snap7.type as t
import logging
import time
from threading import Lock, Thread
import os
import sys
import socket
from datetime import datetime

logger = logging.getLogger(__name__)

sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from service.config.config import RECONNECT_AFTER_MINS, WRITE_TO_PLC

DEFAULT_CHUNK   = 480           # safe chunk size for DB reads
MAX_BACKOFF_SEC = 5.0           # exponential back-off ceiling

# Dedicated logger for DB read errors
db_read_logger = logging.getLogger("db_read_errors")
db_read_logger.setLevel(logging.ERROR)
if not db_read_logger.handlers:
    log_dir = os.path.join(os.path.dirname(__file__), "logs")
    os.makedirs(log_dir, exist_ok=True)
    file_handler = logging.FileHandler(os.path.join(log_dir, "plc_db_read_errors.log"))
    formatter = logging.Formatter(
        "%(asctime)s [%(levelname)s] %(message)s\n"
        "--------------------------------------------------------------\n"
    )
    file_handler.setFormatter(formatter)
    db_read_logger.addHandler(file_handler)

class PLCConnection:
    def __init__(self, ip_address, slot, *, max_chunk: int = DEFAULT_CHUNK,
                 status_callback=None):
        self.lock = Lock()
        self.client = c.Client()
        self.client.set_connection_type(3)
        self.client.set_param(t.Parameter.PingTimeout, 5000)
        self.client.set_param(t.Parameter.SendTimeout, 5000)
        self.client.set_param(t.Parameter.RecvTimeout, 5000)
        self.ip_address = ip_address
        self.rack = 0
        self.slot = slot
        self.connected = False
        self.status_callback = status_callback
        self.max_chunk = max_chunk
        self._connect()
        self._last_manual_reconnect_ts = 0.0
        self._reconnect_count = 0
        Thread(target=self._background_reconnector, daemon=True).start()
        Thread(target=self._reconnect_on_timer, daemon=True).start()

    def _check_tcp_port(self, port=102, timeout=1.0):
        try:
            with socket.create_connection((self.ip_address, port), timeout=timeout):
                return True
        except (socket.timeout, ConnectionRefusedError, OSError) as e:
            logger.warning(f"🔍 Port {port} check failed for {self.ip_address}: {e}")
            return False

    def _background_reconnector(self):
        last_attempt = 0
        while True:
            now = time.time()
            if not self.connected or not self.is_connected():
                if now - last_attempt > 5:
                    last_attempt = now
                    if self._check_tcp_port():
                        logger.debug(f"🔎 Port 102 open, trying Snap7 reconnect…")
                        self._try_connect()
                    else:
                        logger.warning(f"🚫 Cannot reach PLC {self.ip_address} on port 102")
            time.sleep(1)


    def _try_connect(self):
        self._reconnect_count += 1
        if self._reconnect_count % 10 == 0:
            logger.warning(f"⚠️ Reconnect count for {self.ip_address}: {self._reconnect_count}")
        with self.lock:
            try:
                if self.client.get_connected():
                    self.client.disconnect()
            except Exception:
                pass

            try:
                # Don't recreate the client — reuse existing one
                self.client.set_connection_type(3)
                self.client.set_param(t.Parameter.PingTimeout, 5000)
                self.client.set_param(t.Parameter.SendTimeout, 5000)
                self.client.set_param(t.Parameter.RecvTimeout, 5000)

                self.client.connect(self.ip_address, self.rack, self.slot)

                if self.client.get_connected():
                    self.connected = True
                    self._safe_callback("CONNECTED")
                    logger.info(f"✅ PLC {self.ip_address} reconnected")
                else:
                    self.connected = False
                    self._safe_callback("DISCONNECTED")
                    logger.warning(f"❌ PLC {self.ip_address} still unreachable")
            except Exception as e:
                self.connected = False
                self._safe_callback("DISCONNECTED")
                logger.error(f"❌ Failed PLC reconnect {self.ip_address}: {e}")

    def _reconnect_on_timer(self):
        while True:
            logger.info(f"⏳ Next reconnect for PLC {self.ip_address} in {RECONNECT_AFTER_MINS} minutes")
            time.sleep(RECONNECT_AFTER_MINS * 60)

            now = time.time()
            elapsed_since_manual = now - self._last_manual_reconnect_ts
            cooldown_secs = 10 * 60  # 10 minutes

            if elapsed_since_manual < cooldown_secs:
                logger.info(
                    f"⏭️ [Timed Reconnect] Skipped for {self.ip_address} — manual reconnect was {elapsed_since_manual:.0f}s ago"
                )
                continue

            start_time = datetime.now()
            logger.info(f"🔁 [Timed Reconnect] START at {start_time.isoformat()} for PLC {self.ip_address}")

            with self.lock:
                try:
                    self.client.disconnect()
                    self.connected = False
                except Exception:
                    pass

            time.sleep(1.0)
            self._try_connect()

            end_time = datetime.now()
            elapsed = (end_time - start_time).total_seconds()
            logger.info(
                f"✅ [Timed Reconnect] DONE for PLC {self.ip_address} — Duration: {elapsed:.2f}s"
            )

    def force_reconnect(self, reason: str = "Manual trigger"):
        now = time.time()
        if now - self._last_manual_reconnect_ts < 10:
            logger.warning(f"⏳ [Force Reconnect] Skipped (cooldown active)")
            return
        self._last_manual_reconnect_ts = now

        logger.warning(f"🛠️ [Force Reconnect] Triggered due to: {reason}")
        with self.lock:
            try:
                self.client.disconnect()
                self.connected = False
                logger.info(f"🔌 Disconnected client for {self.ip_address}")
            except Exception as e:
                logger.exception(f"❌ Exception during disconnect: {e}")

            time.sleep(1.0)

            try:
                self._try_connect()
                logger.info(f"✅ Reconnected to PLC at {self.ip_address}")
            except Exception as e:
                logger.exception(f"❌ Exception during reconnect: {e}")


    def _connect(self):
        with self.lock:
            try:
                if self.client.get_connected():
                    self.client.disconnect()
            except Exception:
                pass
            try:
                self.client.set_connection_type(3)
                self.client.set_param(t.Parameter.PingTimeout, 5000)
                self.client.set_param(t.Parameter.SendTimeout, 5000)
                self.client.set_param(t.Parameter.RecvTimeout, 5000)
                self.client.connect(self.ip_address, self.rack, self.slot)
                if self.client.get_connected():
                    self.connected = True
                    logger.debug(f"🟢 Connected to PLC at {self.ip_address}")
                else:
                    self.connected = False
                    logger.error(f"❌ Connection refused by PLC {self.ip_address}")
            except Exception as e:
                self.connected = False
                logger.error(f"❌ Initial connect to PLC {self.ip_address} failed: {e}")

    def _recover_on_error(self, context: str, exc: Exception):
        self.connected = False
        try:
            self.client.disconnect()
        except Exception:
            pass
        logger.error(
            f"⚠️ PLC {self.ip_address} comms error in {context}: {exc}. Connection marked down."
        )

    def is_connected(self):
        try:
            return self.client.get_connected()
        except Exception as e:
            logger.error(f"❌ Error checking connection: {e}")
            return False

    def _ensure_connection(self):
        now = time.time()
        if now - getattr(self, '_last_check', 0) < 1.0:
            return
        self._last_check = now
        if not self.connected or not self.is_connected():
            logger.info(f"🚫 PLC {self.ip_address} ENSURE CONNECTION FAILED")

    def _safe_callback(self, status):
        if self.status_callback:
            try:
                loop = asyncio.get_running_loop()
                loop.call_soon_threadsafe(asyncio.create_task, self.status_callback(status))
            except RuntimeError:
                try:
                    asyncio.run(self.status_callback(status))
                except Exception as e:
                    logger.error(f"❌ Status callback failed: {e}")

    def disconnect(self):
        with self.lock:
            if self.connected:
                try:
                    self.client.disconnect()
                    self.connected = False
                    logger.debug(f"🔴 Disconnected from PLC at {self.ip_address}")
                except Exception as e:
                    logger.error(f"Error during disconnect: {e}")
            else:
                logger.debug(f"PLC at {self.ip_address} was already disconnected")

    def read_bool(self, db_number, byte_index, bit_index):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return False
            try:
                byte_array = self.client.db_read(db_number, byte_index, 1)
                return u.get_bool(byte_array, 0, bit_index)
            except Exception as e:
                self._recover_on_error(f"read_bool DB{db_number}", e)
                return False

    def write_bool(self, db_number, byte_index, bit_index, value, max_retries=3):
        if not WRITE_TO_PLC:
            logger.debug("SKIPPED write_bool DB%04d b%d:%d = %s",
                        db_number, byte_index, bit_index, value)
            return

        backoff = 0.01
        for attempt in range(max_retries):
            t_attempt_start = time.perf_counter()

            with self.lock:
                t_lock_acquired = time.perf_counter()

                t_ensure_start = time.perf_counter()
                self._ensure_connection()
                t_ensure_end = time.perf_counter()
                logger.debug(f"🔌 _ensure_connection took {t_ensure_end - t_ensure_start:.3f}s")

                if not self.connected:
                    logger.warning("⛔ Skipped write: PLC not connected")
                    return

                try:
                    # Step 1: Read current byte
                    t_read_start = time.perf_counter()
                    orig = self.client.db_read(db_number, byte_index, 1)
                    t_read_end = time.perf_counter()
                    logger.debug(f"📥 db_read took {t_read_end - t_read_start:.3f}s")

                    # Step 2: Check if value already correct
                    t_logic_start = time.perf_counter()
                    orig_val = orig[0]
                    new_val = (orig_val | (1 << bit_index)) if value else (orig_val & ~(1 << bit_index))
                    t_logic_end = time.perf_counter()
                    logger.debug(f"🧠 bit logic computation took {t_logic_end - t_logic_start:.6f}s")

                    if orig_val == new_val:
                        logger.debug("No-op write_bool(DB%d, byte %d, bit %d): already %s",
                                    db_number, byte_index, bit_index, value)
                        return

                    # Step 3: Perform write
                    payload = bytearray([new_val])
                    t_write_start = time.perf_counter()
                    self.client.write_area(t.Area.DB, db_number, byte_index, payload)
                    t_write_end = time.perf_counter()

                    write_duration = t_write_end - t_write_start
                    log = logger.warning if write_duration > 0.05 else logger.debug
                    log("%s ⏱ write_area(DB%d, byte %d, bit %d) took %.3fs",
                        self.ip_address, db_number, byte_index, bit_index, write_duration)

                    # Full timing for this attempt
                    t_attempt_end = time.perf_counter()
                    logger.debug(f"✅ Total write_bool attempt {attempt + 1} duration: {(t_attempt_end - t_attempt_start):.3f}s "
                                f"(lock={t_lock_acquired - t_attempt_start:.3f}s, ensure={t_ensure_end - t_ensure_start:.3f}s, "
                                f"read={t_read_end - t_read_start:.3f}s, write={write_duration:.3f}s)")
                    return

                except Exception as e:
                    t_attempt_error = time.perf_counter()
                    logger.warning("⚠️ write attempt %d/%d failed after %.3fs: %s",
                                attempt + 1, max_retries, t_attempt_error - t_attempt_start, e)
                    self._recover_on_error(f"write_bool DB{db_number}", e)

            time.sleep(backoff)
            backoff = min(backoff * 2, MAX_BACKOFF_SEC)

    def read_integer(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return 0
            try:
                data = self.client.db_read(db_number, byte_index, 2)
                return u.get_int(data, 0)
            except Exception as e:
                self._recover_on_error(f"read_integer DB{db_number}", e)
                return 0

    def write_integer(self, db_number, byte_index, value):
        if not WRITE_TO_PLC:
            logger.debug(f"[SKIPPED] write_integer(DB{db_number}, byte {byte_index}) = {value}")
            return
        t0 = time.perf_counter()
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return
            try:
                data = self.client.db_read(db_number, byte_index, 2)
                u.set_int(data, 0, value)
                self.client.write_area(t.Area.DB, db_number, byte_index, data)
            except Exception as e:
                self._recover_on_error(f"write_integer DB{db_number}", e)
        duration = time.perf_counter() - t0
        log = logger.warning if duration > 0.25 else logger.debug
        log(f"{self.ip_address} ⏱ write_integer(DB{db_number}, byte {byte_index}) {duration:.3f}s")

    def read_string(self, db_number, byte_index, max_size):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return None
            try:
                raw = self.client.db_read(db_number, byte_index, max_size + 2)
                length = raw[1]
                return raw[2:2+length].decode('ascii', errors='ignore')
            except Exception as e:
                self._recover_on_error(f"read_string DB{db_number}", e)
                return None

    def write_string(self, db_number, byte_index, value, max_size):
        if not WRITE_TO_PLC:
            logger.debug(f"[SKIPPED] write_string(DB{db_number}, byte {byte_index}) = '{value}'")
            return
        t0 = time.perf_counter()
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return
            ba = bytearray(max_size + 2)
            ba[0] = max_size
            ba[1] = len(value := value[:max_size])
            ba[2:2+len(value)] = value.encode('ascii', errors='ignore')
            try:
                self.client.write_area(t.Area.DB, db_number, byte_index, ba)
            except Exception as e:
                self._recover_on_error(f"write_string DB{db_number}", e)
        duration = time.perf_counter() - t0
        log = logger.warning if duration > 0.25 else logger.debug
        log(f"{self.ip_address} ⏱ write_string(DB{db_number}, byte {byte_index}) {duration:.3f}s")

    def read_byte(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return None
            try:
                ba = self.client.db_read(db_number, byte_index, 1)
                return ba[0]
            except Exception as e:
                self._recover_on_error(f"read_byte DB{db_number}", e)
                return None

    def read_date_time(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return None
            try:
                ba = self.client.db_read(db_number, byte_index, 8)
                return u.get_dt(ba, 0)
            except Exception as e:
                self._recover_on_error(f"read_date_time DB{db_number}", e)
                return None

    def read_real(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return None
            try:
                ba = self.client.db_read(db_number, byte_index, 4)
                return u.get_real(ba, 0)
            except Exception as e:
                self._recover_on_error(f"read_real DB{db_number}", e)
                return None

    def db_read(self, db_number: int, start_byte: int, size: int) -> bytearray:
        chunk_size = min(self.max_chunk, size)
        buffer = bytearray()
        offset = 0
        backoff = 0.05
        while offset < size:
            chunk = min(chunk_size, size - offset)
            with self.lock:
                self._ensure_connection()
                if not self.connected:
                    return bytearray(size)
                try:
                    t0 = time.perf_counter()
                    part = self.client.db_read(db_number, start_byte + offset, chunk)
                    logger.debug("DB%04d[%d:%d] OK in %.3fs",
                                 db_number, start_byte + offset, chunk,
                                 time.perf_counter() - t0)
                    buffer.extend(part)
                    backoff = 0.05
                    offset += chunk
                except Exception as e:
                    self._recover_on_error(f"db_read DB{db_number}", e)
                    time.sleep(backoff)
                    backoff = min(backoff * 2, MAX_BACKOFF_SEC)
        return buffer
