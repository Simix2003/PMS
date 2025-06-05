# Extend Python path for module resolution
import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

# Local imports
from service.config.config import debug
from service.controllers.plc import PLCConnection
import service.state.global_state as global_state


class FakePLCConnection(PLCConnection):
    def __init__(self, station_id: str):
        self.connected = True
        self.station_id = station_id  # e.g. "LineaB.M309"
         # Required for buffer logic
        self.ip_address = f"192.168.32.2"
        self.slot = 1
        self.client = FakeClient()

    def is_connected(self):
        return True

    def reconnect(self, retries=3, delay=5):
        print("🔌 (Fake) Reconnect called.")

    def read_bool(self, db, byte, bit):
        # You can refine this with specific DB/byte/bit if needed
        return global_state.debug_triggers.get(self.station_id, False)

    def write_bool(self, db, byte, bit, value):
        print(f"✍️ (Fake) Write bool to DB{db}.{byte}.{bit} = {value}")

    def read_string(self, db, byte, length):
        return global_state.debug_moduli.get(self.station_id, "Fake String")

class FakeClient:
    def __init__(self):
        self.connected = True

    def get_connected(self):
        return self.connected

    def connect(self, ip, rack, slot):
        print(f"🔌 (Fake) Connected to PLC at {ip}")

    def disconnect(self):
        print("🔌 (Fake) Disconnected")

    def db_read(self, db_number, start, size):
        # Return dummy bytearray of requested size
        return bytearray([0] * size)

    def db_write(self, db_number, start, data):
        print(f"📤 (Fake) Writing to DB{db_number}, start={start}, data={data}")