import snap7.client as c
import snap7.util as u
import logging
import time
from threading import Lock

class PLCConnection:
    def __init__(self, ip_address, slot):
        self.lock = Lock()
        self.client = c.Client()
        self.ip_address = ip_address
        self.rack = 0
        self.slot = slot
        self.connected = False
        self._connect()

    def _connect(self):
        """Internal connection method"""
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

    def reconnect(self, retries=3, delay=2):
        for attempt in range(retries):
            logging.warning(f"🔄 Reconnection attempt {attempt + 1} to {self.ip_address}")
            
            self.force_reset()
            
            try:
                self.client.connect(self.ip_address, self.rack, self.slot)
                time.sleep(0.5)
                if self.client.get_connected():
                    self.connected = True
                    logging.info(f"✅ Successfully reconnected on attempt {attempt + 1}")
                    return True
                else:
                    logging.warning("❌ Client not connected even after connect()")
            except Exception as e:
                logging.error(f"❌ Exception during reconnect: {str(e)}")
            
            time.sleep(delay)
        
        self.connected = False
        logging.error(f"🚫 All reconnection attempts failed for PLC at {self.ip_address}")
        return False

    def disconnect(self):
        """Disconnects from the PLC safely"""
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

    def _ensure_connection(self):
        """Ensure connection is active before each operation"""
        if not self.connected:
            self.reconnect()

    def force_reset(self):
        """Forcefully reset Snap7 client and create a new one"""
        print('FORCE RESET!!')
        with self.lock:
            try:
                self.client.destroy()
            except Exception as e:
                logging.warning(f"🔧 Error destroying client: {str(e)}")
            self.client = c.Client()
            self.connected = False
            print('disconnected OKKK')
            time.sleep(1)  # Allow OS to release the socket
            logging.warning(f"🔁 Snap7 client forcefully reset for {self.ip_address}")

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
                print('connected = False')
                self.reconnect()
                print('reconnected')
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
                byte_array[0] = max_size  # Max string length
                byte_array[1] = len(value)  # Actual string length
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
