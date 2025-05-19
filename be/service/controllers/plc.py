\# plc.py
import asyncio
import snap7.client as c
import snap7.util as u
import logging
import time
from threading import Lock

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

    def _connect(self):
        """Internal connection method."""
        try:
            self.client.connect(self.ip_address, self.rack, self.slot)
            if self.client.get_connected():
                self.connected = True
                logging.info(f"🟢 Connected to PLC at {self.ip_address}")
            else:
                self.connected = False
                logging.error(f"❌ PLC at {self.ip_address} refused connection.")
        except Exception as e:
            self.connected = False
            logging.error(f"❌ Failed to connect to PLC at {self.ip_address}: {str(e)}")

    def is_connected(self):
        """Check the current connection status using the Snap7 client."""
        try:
            return self.client.get_connected()
        except Exception as e:
            logging.error(f"❌ Error checking connection: {str(e)}")
            return False

    def _ensure_connection(self):
        """Ensure the connection is active before each operation.
           If not, attempt to reconnect.
        """
        if not self.connected or not self.is_connected():
            logging.info("Connection lost, attempting to reconnect...")
            self.reconnect()

    def reconnect(self, retries=999, delay=5):
        """Hard reconnect to PLC every 5 seconds with full Snap7 reset."""
        time.sleep(2)  # Initial delay to let the cable reconnect physically

        self._safe_callback("DISCONNECTED")
        self.connected = False

        for attempt in range(retries):
            logging.warning(f"🔄 Reconnection attempt {attempt + 1} to {self.ip_address}")

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
                    logging.info(f"✅ Successfully reconnected on attempt {attempt + 1}")
                    return True
                else:
                    logging.warning("❌ Client not connected even after connect()")
            except Exception as e:
                logging.error(f"❌ Exception during reconnect: {str(e)}")

            time.sleep(delay)

        logging.error(f"🚫 All reconnection attempts failed for PLC at {self.ip_address}")
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
                    logging.error(f"❌ Failed to run status callback: {e}")

    def disconnect(self):
        """Disconnects from the PLC safely."""
        with self.lock:
            if self.connected:
                try:
                    self.client.disconnect()
                    self.connected = False
                    logging.info(f"🔴 Disconnected from PLC at {self.ip_address}")
                except Exception as e:
                    logging.error(f"Error during disconnect: {str(e)}")
            else:
                logging.info(f"PLC at {self.ip_address} was already disconnected")

    # ---------- READ/WRITE METHODS WITH RETRY LOGIC ----------

    def read_bool(self, db_number, byte_index, bit_index):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, 1)
                return u.get_bool(byte_array, 0, bit_index)
            except Exception as e:
                logging.warning(f"⚠️ Error reading BOOL (first try) DB{db_number}, byte {byte_index}, bit {bit_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, 1)
                    return u.get_bool(byte_array, 0, bit_index)
                except Exception as e2:
                    logging.error(f"❌ Retry failed: BOOL DB{db_number}, byte {byte_index}, bit {bit_index}: {str(e2)}")
                    self.connected = False
                    return None

    def write_bool(self, db_number, byte_index, bit_index, value):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, 1)
                u.set_bool(byte_array, 0, bit_index, value)
                self.client.db_write(db_number, byte_index, byte_array)
            except Exception as e:
                logging.warning(f"⚠️ Error writing BOOL (first try) DB{db_number}, byte {byte_index}, bit {bit_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, 1)
                    u.set_bool(byte_array, 0, bit_index, value)
                    self.client.db_write(db_number, byte_index, byte_array)
                except Exception as e2:
                    logging.error(f"❌ Retry failed: BOOL write DB{db_number}, byte {byte_index}, bit {bit_index}: {str(e2)}")
                    self.connected = False

    def read_integer(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, 2)
                return u.get_int(byte_array, 0)
            except Exception as e:
                logging.warning(f"⚠️ Error reading INT (first try) DB{db_number}, byte {byte_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, 2)
                    return u.get_int(byte_array, 0)
                except Exception as e2:
                    logging.error(f"❌ Retry failed: INT DB{db_number}, byte {byte_index}: {str(e2)}")
                    self.connected = False
                    return None

    def write_integer(self, db_number, byte_index, value):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, 2)
                u.set_int(byte_array, 0, value)
                self.client.db_write(db_number, byte_index, byte_array)
            except Exception as e:
                logging.warning(f"⚠️ Error writing INT (first try) DB{db_number}, byte {byte_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, 2)
                    u.set_int(byte_array, 0, value)
                    self.client.db_write(db_number, byte_index, byte_array)
                except Exception as e2:
                    logging.error(f"❌ Retry failed: INT write DB{db_number}, byte {byte_index}: {str(e2)}")
                    self.connected = False

    def read_string(self, db_number, byte_index, max_size):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, max_size + 2)
                actual_size = byte_array[1]
                string_data = byte_array[2:2 + actual_size]
                return ''.join(map(chr, string_data))
            except Exception as e:
                logging.warning(f"⚠️ Error reading STRING (first try) DB{db_number}, byte {byte_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, max_size + 2)
                    actual_size = byte_array[1]
                    string_data = byte_array[2:2 + actual_size]
                    return ''.join(map(chr, string_data))
                except Exception as e2:
                    logging.error(f"❌ Retry failed: STRING DB{db_number}, byte {byte_index}: {str(e2)}")
                    self.connected = False
                    return None

    def write_string(self, db_number, byte_index, value, max_size):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = bytearray(max_size + 2)
                byte_array[0] = max_size  # Set maximum string length
                byte_array[1] = len(value)  # Set actual string length
                for i, c in enumerate(value[:max_size]):
                    byte_array[i + 2] = ord(c)
                self.client.db_write(db_number, byte_index, byte_array)
            except Exception as e:
                logging.warning(f"⚠️ Error writing STRING to DB{db_number}, byte {byte_index}: {str(e)}")
                self.connected = False

    def read_byte(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, 1)
                return byte_array[0]
            except Exception as e:
                logging.warning(f"⚠️ Error reading BYTE (first try) DB{db_number}, byte {byte_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, 1)
                    return byte_array[0]
                except Exception as e2:
                    logging.error(f"❌ Retry failed: BYTE DB{db_number}, byte {byte_index}: {str(e2)}")
                    self.connected = False
                    return None

    def read_date_time(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, 8)
                return u.get_dt(byte_array, 0)
            except Exception as e:
                logging.warning(f"⚠️ Error reading DATE TIME (first try) DB{db_number}, byte {byte_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, 8)
                    return u.get_dt(byte_array, 0)
                except Exception as e2:
                    logging.error(f"❌ Retry failed: DATE TIME DB{db_number}, byte {byte_index}: {str(e2)}")
                    self.connected = False
                    return None

    def read_real(self, db_number, byte_index):
        with self.lock:
            self._ensure_connection()
            try:
                byte_array = self.client.db_read(db_number, byte_index, 4)
                return u.get_real(byte_array, 0)
            except Exception as e:
                logging.warning(f"⚠️ Error reading REAL (first try) DB{db_number}, byte {byte_index}: {str(e)}")
                self.connected = False
                self.reconnect()
                try:
                    byte_array = self.client.db_read(db_number, byte_index, 4)
                    return u.get_real(byte_array, 0)
                except Exception as e2:
                    logging.error(f"❌ Retry failed: REAL DB{db_number}, byte {byte_index}: {str(e2)}")
                    self.connected = False
                    return None
