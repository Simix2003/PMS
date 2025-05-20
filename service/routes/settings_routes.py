from fastapi import APIRouter

import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.settings import load_settings, save_settings, AllSettings
from service.connections.mysql import get_mysql_connection

router = APIRouter()

# Global settings cache
REFRESHED_SETTINGS = {}

@router.get("/api/settings")
def get_all_settings():
    settings = load_settings()
    return {
        "min_cycle_threshold": settings.get("min_cycle_threshold", 3.0),
        "include_nc_in_yield": settings.get("include_nc_in_yield", True),
        "exclude_saldatura_from_yield": settings.get("exclude_saldatura_from_yield", False),
        "thresholds": settings.get("thresholds", {}),
        "moduli_window": settings.get("moduli_window", {}),
        "enable_consecutive_ko": settings.get("enable_consecutive_ko", {}),
        "consecutive_ko_limit": settings.get("consecutive_ko_limit", {}),
    }


@router.post("/api/settings")
def set_all_settings(data: AllSettings):
    save_settings(data.dict())
    return {"message": "Settings saved"}


@router.post("/api/settings/refresh")
def refresh_settings():
    global REFRESHED_SETTINGS
    REFRESHED_SETTINGS = load_settings()
    return {"message": "Settings refreshed", "settings": REFRESHED_SETTINGS}


def get_refreshed_settings():
    global REFRESHED_SETTINGS
    if not REFRESHED_SETTINGS:
        REFRESHED_SETTINGS = load_settings()
    return REFRESHED_SETTINGS


@router.get("/api/lines")
def get_production_lines():
    conn = get_mysql_connection()
    with conn.cursor() as cursor:
        cursor.execute("SELECT name, display_name FROM production_lines ORDER BY id")
        lines = cursor.fetchall()

    return lines