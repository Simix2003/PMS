from fastapi import APIRouter
import logging
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.settings import load_settings, save_settings, AllSettings
from service.connections.mysql import get_mysql_connection
from service.config.config import CHANNELS

router = APIRouter()
logger = logging.getLogger(__name__)

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
        "always_export_history": settings.get("always_export_history", False),
        "export_mbj_image": settings.get("export_mbj_image", True),
        "mbj_fields": settings.get("mbj_fields", {}),
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
        logger.debug(lines)

    # Corrected version: include everything except invalid dummy rows
    lines_list = []
    for row in lines:
        name = row['name']
        display_name = row['display_name']

        if name.lower() == 'name' and display_name.lower() == 'display_name':
            logging.debug(f"⚠️ Skipping invalid entry from DB: name={name}, display_name={display_name}")
            continue

        lines_list.append({"name": name, "display_name": display_name})

    if not lines_list:
        logging.warning("⚠️ No valid production lines found, check database content.")

    # Build stations from channels map (unchanged)
    station_names = []
    for line, stations in CHANNELS.items():
        station_names.extend(stations)

    return {
        "lines": lines_list,
        "stations": station_names
    }