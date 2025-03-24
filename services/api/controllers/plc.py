import snap7.client as c
import snap7.util as u
import logging
from threading import Lock

class PLCConnection:
    def __init__(self, ip_address, slot):
        self.lock = Lock()
        self.client = c.Client()
        self.ip_address = ip_address
        self.rack = 0
        self.slot = slot
        
        print(f"Attempting to connect to PLC at {self.ip_address}")
        try:
            self.client.connect(self.ip_address, self.rack, self.slot)
            print("Successfully connected to PLC.")
        except Exception as e:
            logging.error(f"Failed to connect to PLC: {str(e)}")
            raise

    def disconnect(self):
        """Disconnects from the PLC safely."""
        with self.lock:
            try:
                if self.connected:
                    self.client.disconnect()
                    self.connected = False
                    logging.info(f"Disconnected from PLC at {self.ip_address}")
                else:
                    logging.info(f"PLC at {self.ip_address} was already disconnected")
            except Exception as e:
                logging.error(f"Failed to disconnect from PLC: {str(e)}")

    def read_bool(self, db_number, byte_index, bit_index):
        with self.lock:
            try:
                byte_array = self.client.db_read(db_number, byte_index, 1)
                return u.get_bool(byte_array, 0, bit_index)
            except Exception as e:
                logging.warning(f"Error reading BOOL from DB{db_number}, byte {byte_index}, bit {bit_index}: {str(e)}")
                return None

    def write_bool(self, db_number, byte_index, bit_index, value):
        with self.lock:
            try:
                byte_array = self.client.db_read(db_number, byte_index, 1)
                u.set_bool(byte_array, 0, bit_index, value)
                self.client.db_write(db_number, byte_index, byte_array)
            except Exception as e:
                logging.warning(f"Error writing BOOL to DB{db_number}, byte {byte_index}, bit {bit_index}: {str(e)}")

    def read_integer(self, db_number, byte_index):
        with self.lock:
            try:
                byte_array = self.client.db_read(db_number, byte_index, 2)
                return u.get_int(byte_array, 0)
            except Exception as e:
                logging.warning(f"Error reading INT from DB{db_number}, byte {byte_index}: {str(e)}")
                return None
        
    def write_integer(self, db_number, byte_index, value):
        with self.lock:
            try:
                # Read the current data from the PLC to preserve other bytes
                byte_array = self.client.db_read(db_number, byte_index, 2)
                # Set the integer value in the byte array
                u.set_int(byte_array, 0, value)
                # Write the updated byte array back to the PLC
                self.client.db_write(db_number, byte_index, byte_array)
                logging.info(f"Successfully wrote INT value {value} to DB{db_number}, byte {byte_index}")
            except Exception as e:
                logging.warning(f"Error writing INT to DB{db_number}, byte {byte_index}: {str(e)}")   

    def read_string(self, db_number, byte_index, max_size):
        with self.lock:
            try:
                byte_array = self.client.db_read(db_number, byte_index, max_size + 2)  # +2 for metadata
                actual_size = byte_array[1]  # The second byte contains the actual string length
                string_data = byte_array[2:2 + actual_size]  # Get the actual string bytes
                return ''.join(map(chr, string_data))
            except Exception as e:
                logging.warning(f"Error reading STRING from DB{db_number}, byte {byte_index}: {str(e)}")
                return None

    def read_byte(self, db_number, byte_index):
        with self.lock:
            try:
                byte_array = self.client.db_read(db_number, byte_index, 1)
                return byte_array[0]
            except Exception as e:
                logging.warning(f"Error reading BYTE from DB{db_number}, byte {byte_index}: {str(e)}")
                return None

    def read_date_time(self, db_number, byte_index):
        with self.lock:
            try:
                byte_array = self.client.db_read(db_number, byte_index, 8)
                return u.get_dt(byte_array, 0)
            except Exception as e:
                logging.warning(f"Error reading DATE AND TIME from DB{db_number}, byte {byte_index}: {str(e)}")
                return None
    
    def read_real(self, db_number, byte_index):
        with self.lock:
            try:
                byte_array = self.client.db_read(db_number, byte_index, 4)
                return u.get_real(byte_array, 0)
            except Exception as e:
                logging.warning(f"Error reading REAL from DB{db_number}, byte {byte_index}: {str(e)}")
                return None