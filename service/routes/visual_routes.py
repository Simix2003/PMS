from fastapi import APIRouter, HTTPException, Query

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.state import global_state
from service.helpers.visual_helper import compute_zone_snapshot
from service.config.config import ZONE_SOURCES

router = APIRouter()

def initialize_visual_cache():
    for zone in ZONE_SOURCES:
        global_state.visual_data[zone] = compute_zone_snapshot(zone)

# ──────────────────────────────────────────────────
@router.get("/api/visual_data")
async def get_visual_data(zone: str = Query(...)):
    if zone not in global_state.visual_data:
        raise HTTPException(status_code=404, detail="Unknown zone")
    # Return a shallow copy so callers can't mutate your cache
    return dict(global_state.visual_data[zone])
