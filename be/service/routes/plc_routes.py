from fastapi import APIRouter
import logging
import os
import sys

from pydantic import BaseModel
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.state.global_state import plc_connections
import service.state.global_state as global_state

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/api/plc_status")
async def plc_status():
    statuses = {}

    for full_id, plc_conn in plc_connections.items():
        try:
            line_name, channel_id = full_id.split(".")
        except ValueError:
            continue

        if line_name not in statuses:
            statuses[line_name] = {}

        statuses[line_name][channel_id] = "CONNECTED" if plc_conn.connected else "DISCONNECTED"

    return statuses

class DebugTriggerRequest(BaseModel):
    station: str         # e.g. "LineaB.M309"
    trigger: bool        # True or False
    id_modulo: str | None = None
    ko_fisico: bool

@router.post("/api/debug_trigger")
async def set_debug_trigger(payload: DebugTriggerRequest):
    global_state.debug_triggers[payload.station] = payload.trigger
    if payload.id_modulo:
        global_state.debug_moduli[payload.station] = payload.id_modulo
    global_state.debug_triggers_fisici[payload.station] = payload.ko_fisico

    logger.debug(f"Trigger set for {payload.station}: {payload.trigger}")
    return {
        "station": payload.station,
        "trigger": global_state.debug_triggers[payload.station],
        "id_modulo": global_state.debug_moduli.get(payload.station),
        "ko_fisico": global_state.debug_triggers_fisici.get(payload.station),
    }