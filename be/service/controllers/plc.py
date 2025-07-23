# plc.py
import asyncio
import snap7.client as c
import snap7.util as u
from snap7.type import Area
from snap7.type import Parameter
import logging
import time
from threading import Lock, Thread
import os
import sys

logger = logging.getLogger(__name__)

sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from service.config.config import WRITE_TO_PLC


class PLCConnection:
    def __init__(self, ip_address, slot, status_callback=None):
        self.lock = Lock()
        self.client = c.Client()
        self.ip_address = ip_address
        self.rack = 0
        self.slot = slot
        self.connected = False
        self.status_callback = status_callback
        self._connect()
        print("Current timeout:", self.client.get_param(Parameter.PingTimeout))
        Thread(target=self._background_reconnector, daemon=True).start()

    def _background_reconnector(self):
        while True:
            if not self.connected or not self.is_connected():
                logger.warning(f"🔌 PLC {self.ip_address} offline, tentando reconnessione...")
                self._try_connect()
            time.sleep(10)

    def _try_connect(self):
        try:
            self.client.disconnect()
        except:
            pass
        try:
            self.client = c.Client()
            self.client.set_connection_type(3)
            self.client.connect(self.ip_address, self.rack, self.slot)
            if self.client.get_connected():
                self.connected = True
                self._safe_callback("CONNECTED")
                logger.info(f"✅ PLC {self.ip_address} riconnesso")
            else:
                self.connected = False
                self._safe_callback("DISCONNECTED")
                logger.warning(f"❌ PLC {self.ip_address} ancora irraggiungibile")
        except Exception as e:
            self.connected = False
            self._safe_callback("DISCONNECTED")
            logger.error(f"❌ Fallita reconnessione PLC {self.ip_address}: {e}")

    def _connect(self):
        try:
            self.client.connect(self.ip_address, self.rack, self.slot)
            if self.client.get_connected():
                self.connected = True
                logger.debug(f"🟢 Connected to PLC at {self.ip_address}")
            else:
                self.connected = False
                logger.error(f"❌ PLC at {self.ip_address} refused connection.")
        except Exception as e:
            self.connected = False
            logger.error(f"❌ Failed to connect to PLC at {self.ip_address}: {str(e)}")
    
    def _recover_on_error(self, context: str, exc: Exception):
        """
        Handles any PLC I/O error gracefully:
        - Marks the connection as down
        - Logs the issue
        - Leaves reconnecting to the background thread (non-blocking)
        """
        self.connected = False
        logger.error(f"⚠️ PLC communication error in {context}: {exc}. Connection marked as down.")

    def is_connected(self):
        try:
            return self.client.get_connected()
        except Exception as e:
            logger.error(f"❌ Error checking connection: {str(e)}")
            return False

    def _ensure_connection(self):
        if not self.connected or not self.is_connected():
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
                    logger.error(f"❌ Failed to run status callback: {e}")

    def disconnect(self):
        with self.lock:
            if self.connected:
                try:
                    self.client.disconnect()
                    self.connected = False
                    logger.debug(f"🔴 Disconnected from PLC at {self.ip_address}")
                except Exception as e:
                    logger.error(f"Error during disconnect: {str(e)}")
            else:
                logger.debug(f"PLC at {self.ip_address} was already disconnected")

    def read_bool(self, db_number, byte_index, bit_index):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return False  # safe default
            try:
                byte_array = self.client.db_read(db_number, byte_index, 1)
                return u.get_bool(byte_array, 0, bit_index)
            except Exception as e:
                self._recover_on_error(f"read_bool DB{db_number}", e)
                return False  # safe default

    def write_bool(self, db_number, byte_index, bit_index, value, max_retries=3):
        t0 = time.perf_counter()
        if not WRITE_TO_PLC:
            logger.debug(f"[SKIPPED] write_bool(DB{db_number}, byte {byte_index}, bit {bit_index}) = {value}")
            return
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return

            def attempt_write():
                byte_array = self.client.db_read(db_number, byte_index, 1)
                u.set_bool(byte_array, 0, bit_index, value)
                self.client.db_write(db_number, byte_index, byte_array)

            for attempt in range(max_retries):
                try:
                    attempt_write()
                    break
                except Exception as e:
                    logger.warning(f"⚠️ Write attempt {attempt+1}/{max_retries} failed: {e}")
                    if attempt == max_retries - 1:
                        # Only trigger recovery after last failure
                        self._recover_on_error(f"write_bool DB{db_number}", e)
                    time.sleep(0.05 * (2 ** attempt))

            duration = time.perf_counter() - t0
            log = logger.warning if duration > 0.25 else logger.debug
            log(f"{self.ip_address} ⏱ write_bool(DB{db_number}, byte {byte_index}, bit {bit_index}) took {duration:.3f}s")

    def write_bool_new(self, db_number, byte_index, bit_index, value, max_retries=3):
        t0 = time.perf_counter()
        if not WRITE_TO_PLC:
            logger.debug(f"[SKIPPED] write_bool(DB{db_number}, byte {byte_index}, bit {bit_index}) = {value}")
            return
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return

            def attempt_write():
                buf = bytearray([0])
                if value:
                    buf[0] |= 1 << bit_index
                else:
                    buf[0] &= ~(1 << bit_index)
                logger.debug(f"✍️ Writing to DB{db_number}, b{byte_index}:{bit_index} = {value}")
                self.client.write_area(Area.DB, db_number, byte_index, buf)

            for attempt in range(max_retries):
                try:
                    attempt_write()
                    break
                except Exception as e:
                    logger.warning(f"⚠️ Write attempt {attempt+1}/{max_retries} failed: DB{db_number}, b{byte_index}:{bit_index}: {e}")
                    if attempt == max_retries - 1:
                        # Trigger reconnect only on last failure
                        self._recover_on_error(f"write_bool_new DB{db_number}", e)
                    time.sleep(0.05 * (2 ** attempt))

            duration = time.perf_counter() - t0
            log = logger.warning if duration > 0.25 else logger.debug
            log(f"{self.ip_address} ⏱ write_bool(DB{db_number}, byte {byte_index}, bit {bit_index}) took {duration:.3f}s")

    def read_integer(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return 0  # safe default
            try:
                byte_array = self.client.db_read(db_number, byte_index, 2)
                return u.get_int(byte_array, 0)
            except Exception as e:
                self._recover_on_error(f"read_integer DB{db_number}", e)
                return 0  # safe default

    def write_integer(self, db_number, byte_index, value):
        t0 = time.perf_counter()
        if not WRITE_TO_PLC:
            logger.debug(f"[SKIPPED] write_integer(DB{db_number}, byte {byte_index}) = {value}")
            return
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return
            try:
                byte_array = self.client.db_read(db_number, byte_index, 2)
                u.set_int(byte_array, 0, value)
                self.client.db_write(db_number, byte_index, byte_array)
            except Exception as e:
                self._recover_on_error(f"write_integer DB{db_number}", e)
            duration = time.perf_counter() - t0
            log = logger.warning if duration > 0.25 else logger.debug
            log(f"{self.ip_address} ⏱ write_integer(DB{db_number}, byte {byte_index}) took {duration:.3f}s")

    def read_string(self, db_number, byte_index, max_size):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return None
            try:
                byte_array = self.client.db_read(db_number, byte_index, max_size + 2)
                actual_size = byte_array[1]
                string_data = byte_array[2:2 + actual_size]
                return ''.join(map(chr, string_data))
            except Exception as e:
                self._recover_on_error(f"read_string DB{db_number}", e)
                return None

    def write_string(self, db_number, byte_index, value, max_size):
        t0 = time.perf_counter()
        if not WRITE_TO_PLC:
            logger.debug(f"[SKIPPED] write_string(DB{db_number}, byte {byte_index}) = '{value}' (WRITE_TO_PLC=False)")
            return
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return

            def attempt_write():
                byte_array = bytearray(max_size + 2)
                byte_array[0] = max_size
                byte_array[1] = len(value[:max_size])
                for i, c in enumerate(value[:max_size]):
                    byte_array[i + 2] = ord(c)
                self.client.db_write(db_number, byte_index, byte_array)

            try:
                attempt_write()
            except Exception as e:
                self._recover_on_error(f"write_string DB{db_number}", e)
            duration = time.perf_counter() - t0
            log = logger.warning if duration > 0.25 else logger.debug
            log(f"{self.ip_address} ⏱ write_string(DB{db_number}, byte {byte_index}) took {duration:.3f}s")

    def read_byte(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return None
            try:
                byte_array = self.client.db_read(db_number, byte_index, 1)
                return byte_array[0]
            except Exception as e:
                self._recover_on_error(f"read_byte DB{db_number}", e)
                return None

    def read_date_time(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return None
            try:
                byte_array = self.client.db_read(db_number, byte_index, 8)
                return u.get_dt(byte_array, 0)
            except Exception as e:
                self._recover_on_error(f"read_date_time DB{db_number}", e)
                return None

    def read_real(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return None
            try:
                byte_array = self.client.db_read(db_number, byte_index, 4)
                return u.get_real(byte_array, 0)
            except Exception as e:
                self._recover_on_error(f"read_real DB{db_number}", e)
                return None

    def db_read(self, db_number: int, start_byte: int, size: int) -> bytearray:
        CHUNK = 200
        buffer = bytearray()
        offset = 0
        while offset < size:
            chunk_size = min(CHUNK, size - offset)
            for attempt in (1, 2):
                with self.lock:
                    self._ensure_connection()
                    if not self.connected:
                        return bytearray(size)  # fallback safe
                    try:
                        part = self.client.db_read(db_number, start_byte + offset, chunk_size)
                        buffer.extend(part)
                        break
                    except Exception as e:
                        if attempt == 1:
                            logger.warning(f"⚠️ Chunk read failed DB{db_number}[{start_byte+offset}:{chunk_size}] ({e}), retrying once…")
                            time.sleep(0.05)
                        else:
                            self._recover_on_error(f"db_read DB{db_number}", e)
                            return bytearray(size)  # safe fallback
            offset += chunk_size
        return buffer

