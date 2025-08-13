import asyncio
import concurrent.futures
import logging
import os
import socket
import snap7.client as c
import snap7.type as t
import snap7.util as u
import time
from datetime import datetime
from threading import RLock, Thread

# Configuration imports
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from service.config.config import RECONNECT_AFTER_MINS, WRITE_TO_PLC, PROBE_DB, PROBE_OFFSET

# Constants
DEFAULT_CHUNK   = 480           # safe chunk size for DB reads
MAX_BACKOFF_SEC = 5.0           # exponential back-off ceiling
PLC_REGISTRY    = []

# Logger setup
logger = logging.getLogger(__name__)

# Dedicated logger for DB read errors
db_read_logger = logging.getLogger("db_read_errors")
db_read_logger.setLevel(logging.ERROR)
if not db_read_logger.handlers:
    log_dir = os.path.join(os.path.dirname(__file__), "logs")
    os.makedirs(log_dir, exist_ok=True)
    fh = logging.FileHandler(os.path.join(log_dir, "plc_db_read_errors.log"))
    fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s\n" +
                            "--------------------------------------------------------------\n")
    fh.setFormatter(fmt)
    db_read_logger.addHandler(fh)


class PLCConnection:
    def __init__(self, ip_address, slot, *, max_chunk: int = DEFAULT_CHUNK,
                 status_callback=None):
        self.ip_address = ip_address
        self.rack = 0
        self.slot = slot
        self.max_chunk = max_chunk
        self.status_callback = status_callback

        self.lock = RLock()
        self.client = c.Client()
        self._init_client_params()

        self.connected = False
        self._last_manual_reconnect_ts = 0.0
        self._reconnect_count = 0
        self._reconnect_in_progress = False
        self._watchdog_executor = concurrent.futures.ThreadPoolExecutor(max_workers=1)
        self._last_probe = 0

        self._connect()
        PLC_REGISTRY.append(self)

        # Background reconnection threads
        Thread(target=self._background_reconnector, daemon=True).start()
        Thread(target=self._reconnect_on_timer, daemon=True).start()

    def _init_client_params(self):
        self.client.set_connection_type(3)
        self.client.set_param(t.Parameter.PingTimeout, 5000)
        self.client.set_param(t.Parameter.SendTimeout, 5000)
        self.client.set_param(t.Parameter.RecvTimeout, 5000)

    def _check_tcp_port(self, port=102, timeout=1.0):
        try:
            with socket.create_connection((self.ip_address, port), timeout=timeout):
                return True
        except Exception as e:
            logger.warning(f"🔍 Port {port} check failed for {self.ip_address}: {e}")
            return False

    def _background_reconnector(self):
        last = 0
        while True:
            now = time.time()
            if self._reconnect_in_progress:
                time.sleep(1)
                continue

            if not self.connected or not self.is_connected():
                if now - last > 5:
                    last = now
                    if self._check_tcp_port():
                        logger.debug(f"🔎 Port open, reconnecting {self.ip_address}")
                        self._reconnect_in_progress = True
                        try:
                            self._try_connect()
                        finally:
                            self._reconnect_in_progress = False
                    else:
                        logger.warning(f"🚫 Cannot reach PLC {self.ip_address} on port 102")
            time.sleep(1)

    def _try_connect(self):
        reset_flag = False
        if not self._reconnect_in_progress:
            self._reconnect_in_progress = True
            reset_flag = True

        try:
            logger.info(f"➡️ Executing _try_connect() for {self.ip_address}")
            self._reconnect_count += 1
            if self._reconnect_count % 10 == 0:
                logger.warning(f"⚠️ Reconnect count {self._reconnect_count} for {self.ip_address}")

            new_client = c.Client()
            new_client.set_connection_type(3)
            new_client.set_param(t.Parameter.PingTimeout, 5000)
            new_client.set_param(t.Parameter.SendTimeout, 5000)
            new_client.set_param(t.Parameter.RecvTimeout, 5000)

            connect_exc = None
            try:
                new_client.connect(self.ip_address, self.rack, self.slot)
                time.sleep(0.5)
                ok = new_client.get_connected()
            except Exception as e:
                ok = False
                connect_exc = e
                try: new_client.disconnect()
                except Exception: pass
                try: new_client.destroy()
                except Exception: pass
                new_client = None

            with self.lock:
                try: self.client.disconnect()
                except Exception: pass
                try: self.client.destroy()
                except Exception: pass

                if ok and new_client:
                    self.client = new_client
                    self.connected = True
                    self._last_probe = 0
                    self._last_probe_result = True
                    self._last_check = 0
                    self._safe_callback("CONNECTED")
                    logger.info(f"✅ PLC {self.ip_address} reconnected")
                else:
                    self.client = c.Client()
                    self._init_client_params()
                    self.connected = False
                    self._safe_callback("DISCONNECTED")
                    if connect_exc:
                        logger.error(f"❌ Reconnect failed for {self.ip_address}: {connect_exc}")
                    else:
                        logger.warning(f"❌ PLC {self.ip_address} unreachable")
        finally:
            if reset_flag:
                self._reconnect_in_progress = False

    def _reconnect_on_timer(self, skip_timer: bool = False):
        while True:
            if not skip_timer:
                logger.info(f"⏳ Next timed reconnect in {RECONNECT_AFTER_MINS} min for {self.ip_address}")
                time.sleep(RECONNECT_AFTER_MINS * 60)

            if self._reconnect_in_progress:
                logger.info(f"⏭️ Skipping timed reconnect; already in progress for {self.ip_address}")
                if skip_timer:
                    break
                continue

            elapsed = time.time() - self._last_manual_reconnect_ts
            if elapsed < 10 * 60 and not skip_timer:
                logger.info(f"⏭️ Skipped timed reconnect for {self.ip_address} (manual cooldown)")
                if skip_timer:
                    break
                continue

            self._reconnect_in_progress = True
            try:
                start = datetime.now()
                logger.info(f"🔁 [Timed Reconnect] START {start.isoformat()} for {self.ip_address}")

                with self.lock:
                    try: self.client.disconnect()
                    except Exception: pass
                    try: self.client.destroy()
                    except Exception: pass
                    self.connected = False

                time.sleep(1)
                self._try_connect()

                elapsed = (datetime.now() - start).total_seconds()
                logger.info(f"✅ [Timed Reconnect] DONE for {self.ip_address} — {elapsed:.2f}s")
            finally:
                self._reconnect_in_progress = False
                if skip_timer:
                    break

    def reconnect_once_now(self, reason: str = ""):
        if self._reconnect_in_progress:
            logger.warning(f"🛑 Reconnect already in progress for {self.ip_address}")
            return

        self._reconnect_in_progress = True
        logger.warning(f"⚠️ Forcing reconnect for {self.ip_address}: {reason}")
        Thread(target=self._reconnect_on_timer, kwargs={'skip_timer': True}, daemon=True).start()

    def force_reconnect(self, reason: str = "Manual trigger"):
        now = time.time()
        if self._reconnect_in_progress:
            logger.warning(f"🛑 Reconnect already in progress for {self.ip_address}")
            return
        if now - self._last_manual_reconnect_ts < 10:
            logger.warning(f"⏳ Force reconnect skipped (cooldown) for {self.ip_address}")
            return
        self._last_manual_reconnect_ts = now
        self._reconnect_in_progress = True

        logger.warning(f"🛠️ [Force Reconnect] {reason} for {self.ip_address}")

        try:
            with self.lock:
                try:
                    self.client.disconnect()
                except Exception:
                    pass
                try:
                    self.client.destroy()
                except Exception:
                    pass
                self.client = c.Client()
                self._init_client_params()
                self.connected = False
            self._try_connect()
        finally:
            self._reconnect_in_progress = False

    def _connect(self):
        self._try_connect()

    def _recover_on_error(self, context: str, exc: Exception):
        self.connected = False

        try:
            self.client.disconnect()
        except Exception:
            pass
        try:
            self.client.destroy()
        except Exception:
            pass

        msg = str(exc).lower()

        # Snap7 client is in invalid state
        if "invalid object" in msg:
            logger.warning(f"🧨 Invalid client object during {context} on {self.ip_address}, recreating")
            self.client = c.Client()
            self._init_client_params()
            return

        # Known connection reset
        if isinstance(exc, ConnectionResetError) or "reset by peer" in msg or "10054" in msg or "104" in msg:
            logger.error(f"🔁 [Server Reset] {self.ip_address} in {context}: {exc}")
            time.sleep(1)
            self._try_connect()
            return

        # Timeout or TCP recv error → allow PLC to recover
        if "timeout" in msg or "recv tcp" in msg:
            logger.warning(f"🌩️ Timeout error on {self.ip_address}, backing off before reconnect")
            time.sleep(3)
            self._try_connect()
            return

        logger.error(f"⚠️ PLC {self.ip_address} comms error in {context}: {exc}. Marked down.")
        self.client = c.Client()
        self._init_client_params()

    def _watchdog_call(self, timeout, fn, *args, **kwargs):
        fut = self._watchdog_executor.submit(fn, *args, **kwargs)
        try:
            return fut.result(timeout)
        except concurrent.futures.TimeoutError:
            raise TimeoutError(f"{fn.__name__} timed out ({timeout}s)")

    def is_connected(self, *, force: bool = False):
        with self.lock:
            now = time.time()
            if not force and now - getattr(self, "_last_probe", 0) < 5.0:
                if hasattr(self, "_last_probe_result"):
                    return self._last_probe_result
            self._last_probe = now

            try:
                if not self.client:
                    logger.warning(f"⚠️ No client object for {self.ip_address}")
                    self._last_probe_result = False
                    return False

                if not self.client.get_connected():
                    self._last_probe_result = False
                    return False

                try:
                    self._watchdog_call(2.5, self.client.db_read, PROBE_DB, PROBE_OFFSET, 1)
                except TimeoutError:
                    logger.error(f"❌ Liveness probe timeout for {self.ip_address}")
                    self._last_probe_result = False
                    return False
                except Exception as e:
                    msg = str(e).lower()

                    if "invalid object" in msg:
                        logger.warning(f"🧨 Invalid client object for {self.ip_address}, recreating")
                        try:
                            self.client.destroy()
                        except Exception:
                            pass
                        self.client = c.Client()
                        self._init_client_params()
                        self.connected = False
                        self._last_probe_result = False
                        return False

                    elif "reset by peer" in msg or "10054" in msg or "104" in msg:
                        logger.warning(f"🔁 [Server Reset] Detected on {self.ip_address}: {e}")
                    else:
                        logger.error(f"❌ Liveness probe failed for {self.ip_address}: {e}")
                    self._last_probe_result = False
                    return False

                self._last_probe_result = True
                return True

            except Exception as e:
                logger.error(f"❌ Error checking connection for {self.ip_address}: {e}")
                self._last_probe_result = False
                return False

    def _ensure_connection(self):
        now = time.time()
        if now - getattr(self, '_last_check', 0) < 1.0:
            return
        self._last_check = now

        if not self.client or not isinstance(self.client, c.Client):
            logger.warning(f"🧨 Invalid client object for {self.ip_address} in _ensure_connection")
            self.connected = False
            return

        if not self.connected or not self.is_connected():
            self.connected = False
            logger.info(f"🚫 PLC {self.ip_address} ENSURE_CONNECTION failed")

    def _safe_callback(self, status):
        if not self.status_callback:
            return
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
                    logger.debug(f"🔴 Disconnected from PLC {self.ip_address}")
                except Exception as e:
                    logger.error(f"Error during disconnect: {e}")
            else:
                logger.debug(f"PLC {self.ip_address} was already disconnected")

    # ─── Read / Write Primitives ──────────────────────────────────────────

    def read_bool(self, db, byte, bit):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return False
            try:
                data = self.client.db_read(db, byte, 1)
                return u.get_bool(data, 0, bit)
            except Exception as e:
                self._recover_on_error(f"read_bool DB{db}", e)
                return False

    def write_bool_LEGACY(self, db, byte, bit, value, max_retries=3, current_byte=None):
        if not WRITE_TO_PLC:
            logger.debug(f"SKIPPED write_bool DB{db} b{byte}:{bit} = {value}")
            return

        backoff = 0.01
        for attempt in range(1, max_retries + 1):
            t0 = time.perf_counter()
            with self.lock:
                self._ensure_connection()
                waited = 0.0
                while not self.connected and waited < 1.0:
                    time.sleep(0.01)
                    waited += 0.01
                if not self.connected:
                    logger.error(f"❌ write_bool DB{db}: still not connected after 1s — skipping")
                    return
                try:
                    if current_byte is None:
                        orig = self.client.db_read(db, byte, 1)[0]
                    else:
                        orig = current_byte

                    new = (orig | (1 << bit)) if value else (orig & ~(1 << bit))
                    if orig == new:
                        return

                    payload = bytearray([new])
                    self._watchdog_call(1.0, self.client.db_write, db, byte, payload)

                    duration = time.perf_counter() - t0

                    if duration > 2.0:
                        logger.warning(f"{self.ip_address} ⏱ write_bool DB{db} b{byte}:{bit} took {duration:.3f}s")
                        logger.warning(f"🧨 Slow write_bool ({duration:.2f}s) — forcing reconnect")
                        self.force_reconnect(reason=f"slow write {duration:.2f}s")
                    else:
                        logger.debug(f"{self.ip_address} ⏱ write_bool DB{db} b{byte}:{bit} took {duration:.3f}s")

                    return

                except TimeoutError as te:
                    logger.error(f"⚠️ write_bool timeout on DB{db}: {te}")
                    self._recover_on_error(f"write_bool DB{db}", te)

                except Exception as e:
                    logger.warning(f"⚠️ Attempt {attempt}/{max_retries} write_bool DB{db} failed: {e}")
                    self._recover_on_error(f"write_bool DB{db}", e)

            time.sleep(backoff)
            backoff = min(backoff * 2, MAX_BACKOFF_SEC)

    def write_bool(self, db, byte, bit, value, *, current_byte):
        """
        Minimal write_bool:
        - non fa ensure_connection/is_connected
        - non usa retry né watchdog
        - non legge il byte da PLC (usa current_byte)
        """
        if not WRITE_TO_PLC:
            return

        orig = current_byte
        new  = (orig | (1 << bit)) if value else (orig & ~(1 << bit))
        if new == orig:
            return

        payload = bytes([new])
        with self.lock:
            try:
                # scrive direttamente in DB
                self.client.write_area(t.Area.DB, db, byte, payload)
            except Exception as e:
                logger.error(f"Minimal write_bool failed DB{db}:{byte} bit{bit} → {e}")
                # opzionale: in caso di errore di connessione, si può richiamare il write_bool completo
                # super().write_bool(db, byte, bit, value, current_byte=orig)

    def read_integer(self, db, byte):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return 0
            try:
                data = self.client.db_read(db, byte, 2)
                return u.get_int(data, 0)
            except Exception as e:
                self._recover_on_error(f"read_integer DB{db}", e)
                return 0

    def write_integer(self, db, byte, value):
        if not WRITE_TO_PLC:
            logger.debug(f"SKIPPED write_integer DB{db} byte {byte} = {value}")
            return
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return
            try:
                ba = self.client.db_read(db, byte, 2)
                u.set_int(ba, 0, value)
                self.client.write_area(t.Area.DB, db, byte, ba)
            except Exception as e:
                self._recover_on_error(f"write_integer DB{db}", e)

    def read_string(self, db, byte, max_size):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return None
            try:
                raw = self.client.db_read(db, byte, max_size+2)
                length = raw[1]
                return raw[2:2+length].decode('ascii', errors='ignore')
            except Exception as e:
                self._recover_on_error(f"read_string DB{db}", e)
                return None

    def write_string(self, db, byte, value, max_size):
        if not WRITE_TO_PLC:
            logger.debug(f"SKIPPED write_string DB{db} byte {byte} = '{value}'")
            return
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return
            ba = bytearray(max_size+2)
            ba[0] = max_size
            text = value[:max_size]
            ba[1] = len(text)
            ba[2:2+len(text)] = text.encode('ascii', errors='ignore')
            try:
                self.client.write_area(t.Area.DB, db, byte, ba)
            except Exception as e:
                self._recover_on_error(f"write_string DB{db}", e)

    def read_byte(self, db, byte):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return None
            try:
                return self.client.db_read(db, byte, 1)[0]
            except Exception as e:
                self._recover_on_error(f"read_byte DB{db}", e)
                return None

    def read_date_time(self, db, byte):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return None
            try:
                raw = self.client.db_read(db, byte, 8)
                return u.get_dt(raw, 0)
            except Exception as e:
                self._recover_on_error(f"read_date_time DB{db}", e)
                return None

    def read_real(self, db, byte):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return None
            try:
                raw = self.client.db_read(db, byte, 4)
                return u.get_real(raw, 0)
            except Exception as e:
                self._recover_on_error(f"read_real DB{db}", e)
                return None

    def db_read(self, db, start, size):
        chunk = min(self.max_chunk, size)
        buf = bytearray()
        offset = 0
        backoff = 0.05
        while offset < size:
            length = min(chunk, size - offset)
            with self.lock:
                self._ensure_connection()
                if not self.connected:
                    return bytearray(size)
                try:
                    part = self.client.db_read(db, start+offset, length)
                    buf.extend(part)
                    offset += length
                    backoff = 0.05
                except Exception as e:
                    self._recover_on_error(f"db_read DB{db}", e)
                    time.sleep(backoff)
                    backoff = min(backoff*2, MAX_BACKOFF_SEC)
        return buf
