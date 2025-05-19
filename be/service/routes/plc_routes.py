from fastapi import APIRouter

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.state.global_state import plc_connections

router = APIRouter()

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
