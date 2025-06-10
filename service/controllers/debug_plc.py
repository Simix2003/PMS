from threading import Lock
import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.config import debug
from service.controllers.plc import PLCConnection
import service.state.global_state as global_state


class FakePLCConnection(PLCConnection):
    def __init__(self, station_id: str):
        self.connected = True
        self.station_id = station_id
        self.ip_address = "192.168.32.2"
        self.slot = 1
        self.client = FakeClient()
        self.lock = Lock()
        self.fake_buffer = bytearray([0] * 256)  # 🧠 simulate DB block

    def is_connected(self):
        return True

    def reconnect(self, retries=3, delay=5):
        print("🔌 (Fake) Reconnect called.")

    def read_bool(self, db, byte, bit):
        with self.lock:
            return global_state.debug_triggers.get(self.station_id, False)

    def write_bool(self, db, byte, bit, value):
        with self.lock:
            print(f"✍️ (Fake) Write bool to DB{db}.{byte}.{bit} = {value}")

    def read_string(self, db, byte, length):
        with self.lock:
            return global_state.debug_moduli.get(self.station_id, "Fake String")

    def db_read(self, db_number, start, size):
        buffer = bytearray([0] * size)

        # Simulate trigger at DB19606, byte 100, bit 0
        # Match whatever is used in your real PLC config
        DEBUG_TRIGGER_DB = 19606
        TRIGGER_BYTE = 100
        TRIGGER_BIT = 0

        if db_number == DEBUG_TRIGGER_DB:
            trigger = global_state.debug_triggers.get(self.station_id, False)
            byte_index = TRIGGER_BYTE - start
            if 0 <= byte_index < size:
                if trigger:
                    buffer[byte_index] |= (1 << TRIGGER_BIT)
                else:
                    buffer[byte_index] &= ~(1 << TRIGGER_BIT)

            # Simulate id_modulo at byte 102 (standard for string)
            id_modulo = global_state.debug_moduli.get(self.station_id, "SIMULATED123456789")
            string_start = 102 - start
            if 0 <= string_start < size - 2:
                buffer[string_start] = 20  # max length
                buffer[string_start + 1] = len(id_modulo)  # actual length
                for i, c in enumerate(id_modulo.encode("ascii")):
                    buffer[string_start + 2 + i] = c

        return buffer

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
        return bytearray([0] * size)

    def db_write(self, db_number, start, data):
        print(f"📤 (Fake) Writing to DB{db_number}, start={start}, data={data}")
