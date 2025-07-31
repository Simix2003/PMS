import asyncio
import snap7.client as c
import snap7.util as u
from snap7.type import Area, Parameter
import logging
import time
from threading import Lock, Thread
import os
import sys
import socket

logger = logging.getLogger(__name__)

sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from service.config.config import WRITE_TO_PLC

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
        self.client.set_param(Parameter.PingTimeout, 500)
        self.client.set_param(Parameter.SendTimeout, 500)
        self.client.set_param(Parameter.RecvTimeout, 500)
        self.ip_address = ip_address
        self.rack = 0
        self.slot = slot
        self.connected = False
        self.status_callback = status_callback
        self.max_chunk = max_chunk
        self._connect()
        Thread(target=self._background_reconnector, daemon=True).start()

    def _check_tcp_port(self, port=102, timeout=1.0):
        try:
            with socket.create_connection((self.ip_address, port), timeout=timeout):
                return True
        except (socket.timeout, ConnectionRefusedError, OSError) as e:
            logger.warning(f"🔍 Port {port} check failed for {self.ip_address}: {e}")
            return False

    def _background_reconnector(self):
        while True:
            if not self.connected or not self.is_connected():
                if self._check_tcp_port():
                    logger.debug(f"🔎 Port 102 open, trying Snap7 reconnect…")
                    self._try_connect()
                else:
                    logger.warning(f"🚫 Cannot reach PLC {self.ip_address} on port 102")
            time.sleep(10)

    def _try_connect(self):
        try:
            self.client.disconnect()
        except Exception:
            pass
        try:
            self.client = c.Client()
            self.client.set_connection_type(3)
            self.client.set_param(Parameter.PingTimeout, 500)
            self.client.set_param(Parameter.SendTimeout, 500)
            self.client.set_param(Parameter.RecvTimeout, 500)
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

    def _connect(self):
        try:
            self.client.set_param(Parameter.PingTimeout, 500)
            self.client.set_param(Parameter.SendTimeout, 500)
            self.client.set_param(Parameter.RecvTimeout, 500)
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
        logger.error(f"⚠️ PLC comms error in {context}: {exc}. Connection marked down.")

    def is_connected(self):
        try:
            return self.client.get_connected()
        except Exception as e:
            logger.error(f"❌ Error checking connection: {e}")
            return False

    def _ensure_connection(self):
        if not self.connected or not self.is_connected():
            if self._check_tcp_port():
                self._try_connect()
            else:
                logger.error(f"🚫 PLC {self.ip_address} port 102 unreachable")
            self.connected = False

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
            with self.lock:
                self._ensure_connection()
                if not self.connected:
                    return
                try:
                    # Read current byte and compute new value
                    orig = self.client.db_read(db_number, byte_index, 1)
                    orig_val = orig[0]
                    new_val = (orig_val | (1 << bit_index)) if value else (orig_val & ~(1 << bit_index))
                    if orig_val == new_val:
                        logger.debug("No-op write_bool(DB%d, byte %d, bit %d): already %s",
                                     db_number, byte_index, bit_index, value)
                        return

                    payload = bytearray([new_val])
                    t0 = time.perf_counter()
                    self.client.write_area(Area.DB, db_number, byte_index, payload)
                    dt = time.perf_counter() - t0

                    log = logger.warning if dt > 0.05 else logger.debug
                    log("%s ⏱ write_bool(DB%d, byte %d, bit %d) %.3fs",
                        self.ip_address, db_number, byte_index, bit_index, dt)
                    return
                except Exception as e:
                    logger.warning("⚠️ write attempt %d/%d failed: %s",
                                   attempt + 1, max_retries, e)
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
                self.client.write_area(Area.DB, db_number, byte_index, data)
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
                self.client.write_area(Area.DB, db_number, byte_index, ba)
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
