import json
from pydantic import BaseModel
from typing import Dict

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.config import SETTINGS_PATH

class AllSettings(BaseModel):
    min_cycle_threshold: float
    include_nc_in_yield: bool
    exclude_saldatura_from_yield: bool
    thresholds: Dict[str, int]
    moduli_window: Dict[str, int]
    enable_consecutive_ko: Dict[str, bool]
    consecutive_ko_limit: Dict[str, int]

def load_settings():
    if os.path.exists(SETTINGS_PATH):
        with open(SETTINGS_PATH, "r") as f:
            return json.load(f)
    return {}

def save_settings(data: dict):
    os.makedirs(os.path.dirname(SETTINGS_PATH), exist_ok=True)
    with open(SETTINGS_PATH, "w") as f:
        json.dump(data, f, indent=2)