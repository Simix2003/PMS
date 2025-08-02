from fastapi import APIRouter, HTTPException, Query
from datetime import datetime, timedelta
import logging
import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.state import global_state
from service.helpers.visual_helper import compute_zone_snapshot, load_targets, save_targets
from service.config.config import ZONE_SOURCES

router = APIRouter()
logger = logging.getLogger(__name__)

def initialize_visual_cache():
    for zone in ZONE_SOURCES:
        compute_zone_snapshot(zone)

# ──────────────────────────────────────────────────
@router.get("/api/visual_data")
async def get_visual_data(zone: str = Query(...), useCache: bool = Query(True)):
    if zone not in ZONE_SOURCES:
        raise HTTPException(status_code=404, detail="Unknown zone")

    now = datetime.now()
    data = compute_zone_snapshot(zone, now=now, force_refresh=not useCache)
    return dict(data)

@router.get("/api/visual_targets")
async def get_visual_targets():
    targets = load_targets()
    return {
        "yield_target": targets.get("yield_target", 90),
        "shift_target": targets.get("shift_target", 366),
        "hourly_shift_target": targets.get("shift_target", 366) // 8
    }


from pydantic import BaseModel

class TargetUpdate(BaseModel):
    yield_target: int
    shift_target: int

@router.post("/api/visual_targets")
async def set_visual_targets(update: TargetUpdate):
    save_targets({
        "yield_target": update.yield_target,
        "shift_target": update.shift_target
    })
    return {"status": "ok"}
