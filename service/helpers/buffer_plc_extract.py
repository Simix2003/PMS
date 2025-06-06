import snap7.util as u

def extract_bool(buffer, byte_offset, bit_index, base_offset):
    return u.get_bool(buffer, byte_offset - base_offset, bit_index)

def extract_string(buffer, byte_offset, length, base_offset):
    pos = byte_offset - base_offset
    actual_length = buffer[pos + 1]
    return buffer[pos + 2 : pos + 2 + actual_length].decode("utf-8", errors="ignore")
