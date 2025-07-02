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
    NG: bool
    G: bool
    reEntry_m326: bool

@router.post("/api/debug_trigger")
async def set_debug_trigger(payload: DebugTriggerRequest):
    station = payload.station

    global_state.debug_triggers[station] = payload.trigger
    global_state.debug_trigger_NG[station] = payload.NG
    global_state.debug_trigger_G[station] = payload.G
    global_state.reentryDebug[station] = payload.reEntry_m326

    if payload.id_modulo:
        global_state.debug_moduli[station] = payload.id_modulo

    return {
        "station": station,
        "trigger": global_state.debug_triggers[station],
        "id_modulo": global_state.debug_moduli.get(station),
        "NG": global_state.debug_trigger_NG.get(station),
        "G": global_state.debug_trigger_G.get(station),
        "reEntry_m326": global_state.reentryDebug.get(station)
    }