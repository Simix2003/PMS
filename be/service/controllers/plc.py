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
        except:
            pass
        try:
            self.client = c.Client()
            self.client.set_connection_type(3)
            self.client.set_param(Parameter.PingTimeout, 5000)
            self.client.set_param(Parameter.SendTimeout, 5000)
            self.client.set_param(Parameter.RecvTimeout, 5000)
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
            self.client.set_param(Parameter.PingTimeout, 5000)
            self.client.set_param(Parameter.SendTimeout, 5000)
            self.client.set_param(Parameter.RecvTimeout, 5000)
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
        self.connected = False
        try:
            self.client.disconnect()
        except Exception:
            pass
        logger.error(f"⚠️ PLC communication error in {context}: {exc}. Connection marked as down.")

    def is_connected(self):
        try:
            return self.client.get_connected()
        except Exception as e:
            logger.error(f"❌ Error checking connection: {str(e)}")
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
                return False
            try:
                byte_array = self.client.db_read(db_number, byte_index, 1)
                return u.get_bool(byte_array, 0, bit_index)
            except Exception as e:
                self._recover_on_error(f"read_bool DB{db_number}", e)
                return False

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
                        self._recover_on_error(f"write_bool_new DB{db_number}", e)
                    time.sleep(0.05 * (2 ** attempt))

            duration = time.perf_counter() - t0
            log = logger.warning if duration > 0.25 else logger.debug
            log(f"{self.ip_address} ⏱ write_bool(DB{db_number}, byte {byte_index}, bit {bit_index}) took {duration:.3f}s")

    def read_integer(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            if not self.connected:
                return 0
            try:
                byte_array = self.client.db_read(db_number, byte_index, 2)
                return u.get_int(byte_array, 0)
            except Exception as e:
                self._recover_on_error(f"read_integer DB{db_number}", e)
                return 0

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
                        return bytearray(size)
                    try:
                        part = self.client.db_read(db_number, start_byte + offset, chunk_size)
                        buffer.extend(part)
                        break
                    except Exception as e:
                        logger.exception(
                            f"⚠️ Chunk read failed DB{db_number}[{start_byte+offset}:{chunk_size}], attempt {attempt}/2"
                        )
                        if attempt == 2:
                            self._recover_on_error(f"db_read DB{db_number}", e)
                            return bytearray(size)
                        time.sleep(0.05)
            offset += chunk_size
        return buffer
