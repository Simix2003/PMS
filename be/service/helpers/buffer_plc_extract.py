import snap7.util as u
from datetime import datetime

def extract_bool(buffer, byte_offset, bit_index, base_offset):
    return u.get_bool(buffer, byte_offset - base_offset, bit_index)

def extract_string(buffer, byte_offset, length, base_offset):
    pos = byte_offset - base_offset
    if pos + 1 >= len(buffer):
        return ""

    actual_length = buffer[pos + 1]
    actual_length = min(actual_length, length)

    max_available = len(buffer) - (pos + 2)
    actual_length = min(actual_length, max_available)

    return buffer[pos + 2 : pos + 2 + actual_length].decode("utf-8", errors="ignore")

def extract_s7_string(buffer: bytes, offset: int) -> str:
    if offset + 2 > len(buffer):
        return ""
    max_len = buffer[offset]
    actual_len = buffer[offset + 1]
    actual_len = min(actual_len, max_len)
    end = offset + 2 + actual_len
    if end > len(buffer):
        return ""
    return buffer[offset + 2:end].decode("utf-8", errors="ignore").strip()

def extract_int(buffer, byte_offset, base_offset):
    pos = byte_offset - base_offset
    return u.get_int(buffer, pos)

def extract_swapped_int(buffer, byte_offset, base_offset):
    pos = byte_offset - base_offset
    b1 = buffer[pos]
    b2 = buffer[pos + 1]

    print(f"RAW BYTES @ {byte_offset}: b1={b1} (0x{b1:02X}), b2={b2} (0x{b2:02X})")

    # Standard Siemens byte swap (little-endian)
    value = b2 * 256 + b1

    print(f"Computed PLC counter (Siemens little-endian): {value}")
    return value

def extract_DT(buffer, byte_offset, base_offset):
    pos = byte_offset - base_offset
    iso_string = u.get_dt(buffer, pos)
    return datetime.fromisoformat(iso_string)