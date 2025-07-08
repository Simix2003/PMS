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

def extract_DT(buffer, byte_offset, base_offset):
    pos = byte_offset - base_offset
    iso_string = u.get_dt(buffer, pos)
    return datetime.fromisoformat(iso_string)