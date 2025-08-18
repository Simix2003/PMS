# service/controllers/debug_plc.py
from __future__ import annotations

import logging
import os
import sys
from threading import RLock
from typing import Dict

logger = logging.getLogger(__name__)

# Ensure local imports resolve like in production
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.controllers.plc import PLCConnection  # type: ignore
import service.state.global_state as global_state


class FakePLCConnection(PLCConnection):
    """
    A fake PLC connection that mirrors the public surface of PLCConnection.
    - No background threads
    - Always 'connected'
    - Simulated per-DB memory with auto-resize
    - Safe no-op reconnect methods
    """

    # Default debug wiring (adjust if needed)
    DEBUG_TRIGGER_DB = 19606
    TRIGGER_BYTE = 100
    TRIGGER_BIT = 0
    ID_MODULO_START = 102
    ID_MODULO_MAXLEN = 20

    def __init__(self, station_id: str, ip_address: str = "192.168.32.2", slot: int = 1):
        # DO NOT call super().__init__ — avoids real snap7 client + threads
        self.station_id = station_id
        self.ip_address = ip_address
        self.rack = 0
        self.slot = slot
        self.max_chunk = 480

        self.lock = RLock()
        self.connected = True

        # Simulated per-DB memory: db_number -> bytearray
        self._dbs: Dict[int, bytearray] = {}

        # Minimal fake client used by base methods that call client.write_area/db_read
        self.client = _FakeClient(self)

        logger.debug(f"🧪 FakePLCConnection ready for station {station_id} at {ip_address}")

    # ── Helpers ───────────────────────────────────────────────────────────

    def _ensure_db_size(self, db: int, end_offset_exclusive: int) -> None:
        """Grow the simulated DB to at least end_offset_exclusive."""
        if db not in self._dbs:
            self._dbs[db] = bytearray(end_offset_exclusive)
        else:
            buf = self._dbs[db]
            if len(buf) < end_offset_exclusive:
                buf.extend(b"\x00" * (end_offset_exclusive - len(buf)))

    # ── Connection/Liveness overrides ─────────────────────────────────────

    def is_connected(self, *, force: bool = False) -> bool:  # match new signature
        return True

    def _ensure_connection(self) -> None:  # no-op but keep the call sites happy
        return

    def force_reconnect(self, reason: str = "Manual trigger") -> None:
        logger.debug(f"🔁 (Fake) force_reconnect ignored: {reason}")

    def reconnect_once_now(self, reason: str = "") -> None:
        logger.debug(f"🔁 (Fake) reconnect_once_now ignored: {reason}")

    def disconnect(self) -> None:
        with self.lock:
            self.connected = False
            logger.debug("🔌 (Fake) Disconnected")

    # ── Read / Write Primitives (overrides where base touches real client) ─

    def read_bool(self, db: int, byte: int, bit: int) -> bool:
        with self.lock:
            # Prefer global_state trigger when reading the “debug” address
            if db == self.DEBUG_TRIGGER_DB and byte == self.TRIGGER_BYTE and bit == self.TRIGGER_BIT:
                return bool(global_state.debug_triggers.get(self.station_id, False))

            # Otherwise read from simulated DB
            self._ensure_db_size(db, byte + 1)
            value = self._dbs[db][byte]
            return bool(value & (1 << bit))

    def write_bool(self, db: int, byte: int, bit: int, value: bool, *args, **kwargs) -> None:
        """
        Mirrors new minimal signature but tolerates legacy calls:
        - new: write_bool(db, byte, bit, value, *, current_byte=...)
        - old: write_bool(db, byte, bit, value, max_retries=3, current_byte=None)
        """
        current_byte = kwargs.get("current_byte", None)

        with self.lock:
            if current_byte is None:
                # pull from simulated DB if not provided
                self._ensure_db_size(db, byte + 1)
                orig = self._dbs[db][byte]
            else:
                orig = int(current_byte) & 0xFF

            new = (orig | (1 << bit)) if value else (orig & ~(1 << bit))
            if new == orig:
                logger.debug(f"✍️ (Fake) write_bool DB{db}.{byte}.{bit} unchanged ({value})")
                return

            self._ensure_db_size(db, byte + 1)
            self._dbs[db][byte] = new
            logger.debug(f"✍️ (Fake) write_bool DB{db}.{byte}.{bit} = {value} (0x{orig:02X} → 0x{new:02X})")

    def read_integer(self, db: int, byte: int) -> int:
        with self.lock:
            self._ensure_db_size(db, byte + 2)
            b = self._dbs[db][byte:byte + 2]
            # Siemens INT is big-endian signed 16-bit
            val = int.from_bytes(b, "big", signed=True)
            return val

    def write_integer(self, db: int, byte: int, value: int) -> None:
        with self.lock:
            self._ensure_db_size(db, byte + 2)
            self._dbs[db][byte:byte + 2] = int(value).to_bytes(2, "big", signed=True)
            logger.debug(f"✍️ (Fake) write_integer DB{db}.{byte} = {value}")

    def read_string(self, db: int, byte: int, max_size: int) -> str | None:
        with self.lock:
            self._ensure_db_size(db, byte + max_size + 2)
            raw = self._dbs[db][byte:byte + max_size + 2]
            if not raw:
                return ""
            declared_max = raw[0]
            length = raw[1]
            length = min(length, declared_max, max_size)
            return bytes(raw[2:2 + length]).decode("ascii", errors="ignore")

    def write_string(self, db: int, byte: int, value: str, max_size: int) -> None:
        with self.lock:
            text = (value or "")[:max_size]
            self._ensure_db_size(db, byte + max_size + 2)
            self._dbs[db][byte] = max_size
            self._dbs[db][byte + 1] = len(text)
            self._dbs[db][byte + 2:byte + 2 + len(text)] = text.encode("ascii", errors="ignore")
            logger.debug(f"✍️ (Fake) write_string DB{db}.{byte} = '{text}' (max {max_size})")

    def read_byte(self, db: int, byte: int) -> int | None:
        with self.lock:
            self._ensure_db_size(db, byte + 1)
            return self._dbs[db][byte]

    def read_date_time(self, db: int, byte: int):
        # Keep simple: not needed by most debug paths; return None or a constant
        logger.debug(f"🕒 (Fake) read_date_time DB{db}.{byte} → None")
        return None

    def read_real(self, db: int, byte: int):
        # Keep simple: not needed by most debug paths; return None
        logger.debug(f"🧮 (Fake) read_real DB{db}.{byte} → None")
        return None

    def db_read(self, db_number: int, start: int, size: int) -> bytearray:
        """
        Simulate a chunked DB read. Also injects:
        - Trigger bit (from global_state.debug_triggers)
        - id_modulo string (from global_state.debug_moduli)
        """
        with self.lock:
            # Base memory
            self._ensure_db_size(db_number, start + size)
            buffer = bytearray(self._dbs[db_number][start:start + size])

            # Inject trigger state if reading the debug DB region
            if db_number == self.DEBUG_TRIGGER_DB:
                # Trigger
                trig_idx = self.TRIGGER_BYTE - start
                if 0 <= trig_idx < size:
                    trigger = bool(global_state.debug_triggers.get(self.station_id, False))
                    if trigger:
                        buffer[trig_idx] |= (1 << self.TRIGGER_BIT)
                    else:
                        buffer[trig_idx] &= ~(1 << self.TRIGGER_BIT)

                # id_modulo string in S7 format (maxlen, curlen, data…)
                s_idx = self.ID_MODULO_START - start
                if 0 <= s_idx < size - 2:
                    id_modulo = str(global_state.debug_moduli.get(self.station_id, "SIMULATED123456789"))[: self.ID_MODULO_MAXLEN]
                    # Write into the backing store too, so subsequent reads align
                    self._ensure_db_size(db_number, self.ID_MODULO_START + 2 + self.ID_MODULO_MAXLEN)
                    self._dbs[db_number][self.ID_MODULO_START] = self.ID_MODULO_MAXLEN
                    self._dbs[db_number][self.ID_MODULO_START + 1] = len(id_modulo)
                    self._dbs[db_number][self.ID_MODULO_START + 2:self.ID_MODULO_START + 2 + len(id_modulo)] = id_modulo.encode("ascii", errors="ignore")
                    # Reflect in this read window
                    buffer[s_idx] = self.ID_MODULO_MAXLEN
                    buffer[s_idx + 1] = len(id_modulo)
                    for i, c in enumerate(id_modulo.encode("ascii")):
                        if s_idx + 2 + i < size:
                            buffer[s_idx + 2 + i] = c

            return buffer


class _FakeClient:
    """
    Minimal client used by base class methods that call:
      - client.db_read(db, start, size)
      - client.write_area(Area.DB, db, start, bytes)
    It delegates to the owning FakePLCConnection's simulated DBs.
    """
    class _Area:
        DB = 0

    Area = _Area

    def __init__(self, owner: FakePLCConnection):
        self._owner = owner
        self._connected = True

    def get_connected(self) -> bool:
        return self._connected

    def connect(self, ip: str, rack: int, slot: int) -> None:
        logger.debug(f"🔌 (FakeClient) connect ip={ip} rack={rack} slot={slot}")
        self._connected = True

    def disconnect(self) -> None:
        logger.debug("🔌 (FakeClient) disconnect")
        self._connected = False

    # Used by PLCConnection.read_* paths
    def db_read(self, db_number: int, start: int, size: int) -> bytearray:
        return self._owner.db_read(db_number, start, size)

    def write_area(self, area, db_number: int, start: int, data: bytes) -> None:
        if area != self.Area.DB:
            logger.debug(f"📦 (FakeClient) write_area ignored for non-DB area: {area}")
            return
        with self._owner.lock:
            end = start + len(data)
            self._owner._ensure_db_size(db_number, end)
            self._owner._dbs[db_number][start:end] = data
            logger.debug(f"📤 (FakeClient) write_area DB{db_number}[{start}:{end}] = {data!r}")
