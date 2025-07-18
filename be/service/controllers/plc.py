# plc.py
import asyncio
import snap7.client as c
import snap7.util as u
from snap7.type import Area
from snap7.type import Parameter
import logging

logger = logging.getLogger(__name__)
import time
from threading import Lock

import os
import sys

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

    def _connect(self):
        """Internal connection method."""
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

    def is_connected(self):
        """Check the current connection status using the Snap7 client."""
        try:
            return self.client.get_connected()
        except Exception as e:
            logger.error(f"❌ Error checking connection: {str(e)}")
            return False

    def _ensure_connection(self):
        """Ensure the connection is active before each operation.
           If not, attempt to reconnect.
        """
        if not self.connected or not self.is_connected():
            logger.warning("Connection lost, attempting to reconnect...")
            self.reconnect()

    def reconnect(self, retries=999, delay=5):
        """Hard reconnect to PLC every 5 seconds with full Snap7 reset."""
        time.sleep(2)  # Initial delay to let the cable reconnect physically

        self._safe_callback("DISCONNECTED")
        self.connected = False

        for attempt in range(retries):
            logger.warning(f"🔄 Reconnection attempt {attempt + 1} to {self.ip_address}")

            try:
                self.client.disconnect()
            except:
                pass  # Ignore disconnect errors

            try:
                self.client = c.Client()  # 🔁 Reset client instance completely
                self.client.set_connection_type(3)  # 🛠 Reset connection type to default PG
                self.client.connect(self.ip_address, self.rack, self.slot)
                time.sleep(0.5)

                if self.client.get_connected():
                    self._safe_callback("CONNECTED")
                    self.connected = True
                    logger.debug(f"✅ Successfully reconnected on attempt {attempt + 1}")
                    return True
                else:
                    logger.warning("❌ Client not connected even after connect()")
            except Exception as e:
                logger.error(f"❌ Exception during reconnect: {str(e)}")

            time.sleep(delay)

        logger.error(f"🚫 All reconnection attempts failed for PLC at {self.ip_address}")
        return False

    def _safe_callback(self, status):
        """Safely call the async status callback from any thread."""
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
        """Disconnects from the PLC safely."""
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

    # ---------- READ/WRITE METHODS WITH RETRY LOGIC ----------

    def read_bool(self, db_number, byte_index, bit_index):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, 1)
                return u.get_bool(byte_array, 0, bit_index)
            except Exception as e:
                logger.warning(f"⚠️ Error reading BOOL (first try) DB{db_number}, byte {byte_index}, bit {bit_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, 1)
                    return u.get_bool(byte_array, 0, bit_index)
                except Exception as e2:
                    logger.error(f"❌ Retry failed: BOOL DB{db_number}, byte {byte_index}, bit {bit_index}: {str(e2)}")
                    self.connected = False
                    return None

    def write_bool(self, db_number, byte_index, bit_index, value, max_retries=3):
        """
        Write a BOOL to the PLC with quick retry logic (no full reconnect unless needed).
        - max_retries: how many quick attempts to do before reconnecting
        """
        t0 = time.perf_counter()

        if not WRITE_TO_PLC:
            logger.debug(f"[SKIPPED] write_bool(DB{db_number}, byte {byte_index}, bit {bit_index}) = {value}")
            return

        with self.lock:
            self._ensure_connection()

            def attempt_write():
                byte_array = self.client.db_read(db_number, byte_index, 1)
                u.set_bool(byte_array, 0, bit_index, value)
                self.client.db_write(db_number, byte_index, byte_array)

            # Try quick retries first (with short sleeps)
            for attempt in range(max_retries):
                try:
                    attempt_write()
                    break  # Success, exit retry loop
                except Exception as e:
                    logger.warning(f"⚠️ Write attempt {attempt+1}/{max_retries} failed: DB{db_number}, b{byte_index}:{bit_index}: {e}")
                    # Small progressive wait before retry (50ms, 100ms, 200ms...)
                    time.sleep(0.05 * (2 ** attempt))
            else:
                # All quick retries failed, do a full reconnect and last try
                self.connected = False
                self.reconnect()
                try:
                    attempt_write()
                except Exception as e2:
                    logger.error(f"❌ Retry after reconnect failed: BOOL DB{db_number}, byte {byte_index}, bit {bit_index}: {e2}")
                    self.connected = False

        duration = time.perf_counter() - t0
        log = logger.warning if duration > 0.250 else logger.debug
        log(f"{self.ip_address} ⏱ write_bool(DB{db_number}, byte {byte_index}, bit {bit_index}) took {duration:.3f}s")

    def write_bool_new(self, db_number, byte_index, bit_index, value, max_retries=3):
        """
        Optimized BOOL write with fast retries before doing a full reconnect.
        - max_retries: quick retry attempts before reconnect (50ms → 100ms → 200ms)
        """
        t0 = time.perf_counter()
        if not WRITE_TO_PLC:
            logger.debug(f"[SKIPPED] write_bool(DB{db_number}, byte {byte_index}, bit {bit_index}) = {value}")
            return

        with self.lock:
            self._ensure_connection()

            def attempt_write():
                # Build 1-byte buffer with only the target bit set/cleared
                buf = bytearray([0])
                if value:
                    buf[0] |= 1 << bit_index
                else:
                    buf[0] &= ~(1 << bit_index)

                logger.debug(f"✍️ Writing to DB{db_number}, b{byte_index}:{bit_index} = {value}")

                # Direct area write
                self.client.write_area(Area.DB, db_number, byte_index, buf)

            # Quick retry loop
            for attempt in range(max_retries):
                try:
                    attempt_write()
                    break  # Success → exit retry loop
                except Exception as e:
                    logger.warning(
                        f"⚠️ Write attempt {attempt+1}/{max_retries} failed: DB{db_number}, b{byte_index}:{bit_index}: {e}"
                    )
                    # Small progressive delay before next try (50ms, 100ms, 200ms...)
                    time.sleep(0.05 * (2 ** attempt))
            else:
                # All quick retries failed → try reconnect once
                self.connected = False
                self.reconnect()
                try:
                    attempt_write()
                except Exception as e2:
                    logger.error(f"❌ Retry after reconnect failed: {e2}")
                    self.connected = False

        duration = time.perf_counter() - t0
        log = logger.warning if duration > 0.250 else logger.debug
        log(f"{self.ip_address} ⏱ write_bool(DB{db_number}, byte {byte_index}, bit {bit_index}) took {duration:.3f}s")

    def read_integer(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, 2)
                return u.get_int(byte_array, 0)
            except Exception as e:
                logger.warning(f"⚠️ Error reading INT (first try) DB{db_number}, byte {byte_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, 2)
                    return u.get_int(byte_array, 0)
                except Exception as e2:
                    logger.error(f"❌ Retry failed: INT DB{db_number}, byte {byte_index}: {str(e2)}")
                    self.connected = False
                    return None

    def write_integer(self, db_number, byte_index, value):
        t0 = time.perf_counter()

        if not WRITE_TO_PLC:
            logger.debug(f"[SKIPPED] write_integer(DB{db_number}, byte {byte_index}) = {value} (WRITE_TO_PLC=False)")
            return

        with self.lock:
            self._ensure_connection()

            def attempt_write():
                byte_array = self.client.db_read(db_number, byte_index, 2)
                u.set_int(byte_array, 0, value)
                self.client.db_write(db_number, byte_index, byte_array)

            try:
                attempt_write()
            except Exception as e:
                logger.warning(f"⚠️ Error writing INT (1st try) DB{db_number}, byte {byte_index}: {e}")
                self.connected = False
                self.reconnect()
                try:
                    attempt_write()
                except Exception as e2:
                    logger.error(f"❌ Retry failed: INT write DB{db_number}, byte {byte_index}: {e2}")
                    self.connected = False

        duration = time.perf_counter() - t0
        if duration > 0.250:
            logger.warning(f"{self.ip_address} ⏱ write_integer(DB{db_number}, byte {byte_index}) took {duration:.3f}s")
        else:
            logger.debug(f"write_integer(DB{db_number}, byte {byte_index}) took {duration:.3f}s")

    def read_string(self, db_number, byte_index, max_size):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, max_size + 2)
                actual_size = byte_array[1]
                string_data = byte_array[2:2 + actual_size]
                return ''.join(map(chr, string_data))
            except Exception as e:
                logger.warning(f"⚠️ Error reading STRING (first try) DB{db_number}, byte {byte_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, max_size + 2)
                    actual_size = byte_array[1]
                    string_data = byte_array[2:2 + actual_size]
                    return ''.join(map(chr, string_data))
                except Exception as e2:
                    logger.error(f"❌ Retry failed: STRING DB{db_number}, byte {byte_index}: {str(e2)}")
                    self.connected = False
                    return None

    def write_string(self, db_number, byte_index, value, max_size):
        t0 = time.perf_counter()

        if not WRITE_TO_PLC:
            logger.debug(f"[SKIPPED] write_string(DB{db_number}, byte {byte_index}) = '{value}' (WRITE_TO_PLC=False)")
            return

        with self.lock:
            self._ensure_connection()

            def attempt_write():
                byte_array = bytearray(max_size + 2)
                byte_array[0] = max_size                # Max length
                byte_array[1] = len(value[:max_size])   # Actual length
                for i, c in enumerate(value[:max_size]):
                    byte_array[i + 2] = ord(c)
                self.client.db_write(db_number, byte_index, byte_array)

            try:
                attempt_write()
            except Exception as e:
                logger.warning(f"⚠️ Error writing STRING (1st try) DB{db_number}, byte {byte_index}: {e}")
                self.connected = False
                self.reconnect()
                try:
                    attempt_write()
                except Exception as e2:
                    logger.error(f"❌ Retry failed: STRING write DB{db_number}, byte {byte_index}: {e2}")
                    self.connected = False

        duration = time.perf_counter() - t0
        if duration > 0.250:
            logger.warning(f"{self.ip_address} ⏱ write_string(DB{db_number}, byte {byte_index}) took {duration:.3f}s")
        else:
            logger.debug(f"write_string(DB{db_number}, byte {byte_index}) took {duration:.3f}s")

    def read_byte(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, 1)
                return byte_array[0]
            except Exception as e:
                logger.warning(f"⚠️ Error reading BYTE (first try) DB{db_number}, byte {byte_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, 1)
                    return byte_array[0]
                except Exception as e2:
                    logger.error(f"❌ Retry failed: BYTE DB{db_number}, byte {byte_index}: {str(e2)}")
                    self.connected = False
                    return None

    def read_date_time(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, 8)
                return u.get_dt(byte_array, 0)
            except Exception as e:
                logger.warning(f"⚠️ Error reading DATE TIME (first try) DB{db_number}, byte {byte_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, 8)
                    return u.get_dt(byte_array, 0)
                except Exception as e2:
                    logger.error(f"❌ Retry failed: DATE TIME DB{db_number}, byte {byte_index}: {str(e2)}")
                    self.connected = False
                    return None

    def read_real(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, 4)
                return u.get_real(byte_array, 0)
            except Exception as e:
                logger.warning(f"⚠️ Error reading REAL (first try) DB{db_number}, byte {byte_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, 4)
                    return u.get_real(byte_array, 0)
                except Exception as e2:
                    logger.error(f"❌ Retry failed: REAL DB{db_number}, byte {byte_index}: {str(e2)}")
                    self.connected = False
                    return None
                
    def db_read(self, db_number: int, start_byte: int, size: int) -> bytearray:
        with self.lock:
            self._ensure_connection()
            try:
                return self.client.db_read(db_number, start_byte, size)
            except Exception as e:
                logger.warning(f"⚠️ Error reading DB block {db_number} from byte {start_byte} (size {size}): {e}")
                self.connected = False
                self.reconnect()
                try:
                    return self.client.db_read(db_number, start_byte, size)
                except Exception as e2:
                    logger.error(f"❌ Retry failed: DB{db_number} [{start_byte}:{start_byte + size}]: {e2}")
                    self.connected = False
                    return bytearray(size)  # Return dummy buffer to avoid crash
