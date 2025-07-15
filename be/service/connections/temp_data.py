import json
import os
import sys
from threading import Lock

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.config import TEMP_STORAGE_PATH

_temp_cache: list | None = None
_cache_mtime: float | None = None
_lock = Lock()

def load_temp_data() -> list:
    """Load temp data from disk with caching."""
    global _temp_cache, _cache_mtime

    os.makedirs(os.path.dirname(TEMP_STORAGE_PATH), exist_ok=True)

    try:
        mtime = os.path.getmtime(TEMP_STORAGE_PATH)
    except FileNotFoundError:
        with open(TEMP_STORAGE_PATH, "w") as file:
            json.dump([], file, indent=4)
        _temp_cache = []
        _cache_mtime = os.path.getmtime(TEMP_STORAGE_PATH)
        return _temp_cache

    with _lock:
        if _temp_cache is None or _cache_mtime != mtime:
            try:
                with open(TEMP_STORAGE_PATH, "r") as file:
                    _temp_cache = json.load(file)
            except json.JSONDecodeError:
                _temp_cache = []
            _cache_mtime = mtime

    if _temp_cache is None:
        return []
    return _temp_cache

def save_temp_data(data):
    """Persist data to disk and update cache."""
    global _temp_cache, _cache_mtime

    os.makedirs(os.path.dirname(TEMP_STORAGE_PATH), exist_ok=True)
    with _lock:
        with open(TEMP_STORAGE_PATH, "w") as file:
            json.dump(data, file, indent=4)
        _temp_cache = data
        _cache_mtime = os.path.getmtime(TEMP_STORAGE_PATH)
        
def get_latest_issues(line_name: str, channel_id: str):
    """
    Returns the issues list for the given station.
    Searches the temporary storage for the latest entry with matching line_name and channel_id.
    """
    temp_data = load_temp_data()
    for entry in reversed(temp_data):
        if (
            entry.get("line_name") == line_name and
            entry.get("channel_id") == channel_id
        ):
            return entry.get("issues", [])
    return []

def remove_temp_issues(line_name, channel_id, object_id):
    temp_data = load_temp_data()
    filtered_data = [
        entry for entry in temp_data
        if not (
            entry.get("line_name") == line_name and
            entry.get("channel_id") == channel_id and
            entry.get("object_id") == object_id
        )
    ]
    save_temp_data(filtered_data)