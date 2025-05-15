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
