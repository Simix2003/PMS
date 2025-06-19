import logging
import asyncio
from fastapi import WebSocket

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.config import debug
from service.controllers.plc import PLCConnection
from service.helpers.helpers import get_channel_config
from service.state.global_state import subscriptions
import service.state.global_state as global_state

logger = logging.getLogger("PMS")

async def send_initial_state(websocket: WebSocket, channel_id: str, plc_connection: PLCConnection, line_name: str):
    paths = get_channel_config(line_name, channel_id)
    
    if paths is None:
        print(f"❌ Invalid config for line={line_name}, channel={channel_id}")
        await websocket.send_json({"error": "Invalid line/channel combination"})
        return

    # ✅ Use `paths` for all access now (already scoped)
    trigger_conf = paths["trigger"]
    trigger_value = await asyncio.to_thread(
        plc_connection.read_bool,
        trigger_conf["db"], trigger_conf["byte"], trigger_conf["bit"]
    )

    object_id = ""
    stringatrice = ""
    outcome = None
    issues_submitted = False
    full_id = f"{line_name}.{channel_id}"

    if trigger_value:
        id_mod_conf = paths["id_modulo"]

        ###############################################################################################################################
        if debug:
            object_id = global_state.debug_moduli.get(full_id)
        else:
            object_id = await asyncio.to_thread(
                plc_connection.read_string,
                id_mod_conf["db"], id_mod_conf["byte"], id_mod_conf["length"]
            )
        ###############################################################################################################################

        str_conf = paths["stringatrice"]
        values = [
            await asyncio.to_thread(plc_connection.read_bool, str_conf["db"], str_conf["byte"], i)
            for i in range(str_conf["length"])
        ]

        if not any(values):
            values[0] = True

        stringatrice_index = values.index(True) + 1
        stringatrice = str(stringatrice_index)

        fine_buona_conf = paths["fine_buona"]
        fine_buona = await asyncio.to_thread(
            plc_connection.read_bool,
            fine_buona_conf["db"], fine_buona_conf["byte"], fine_buona_conf["bit"]
        )

        fine_scarto_conf = paths["fine_scarto"]
        fine_scarto = await asyncio.to_thread(
            plc_connection.read_bool,
            fine_scarto_conf["db"], fine_scarto_conf["byte"], fine_scarto_conf["bit"]
        )

        if fine_buona:
            outcome = "buona"
        elif fine_scarto:
            outcome = "scarto"

        esito_conf = paths["esito_scarto_compilato"]
        issues_value = await asyncio.to_thread(
            plc_connection.read_bool,
            esito_conf["db"], esito_conf["byte"], esito_conf["bit"]
        )
        issues_submitted = issues_value is True

    await websocket.send_json({
        "trigger": trigger_value,
        "objectId": object_id,
        "stringatrice": stringatrice,
        "outcome": outcome,
        "issuesSubmitted": issues_submitted
    })

async def broadcast(line_name: str, channel_id: str, message: dict):
    key = f"{line_name}.{channel_id}"
    for ws in list(subscriptions.get(key, [])):
        try:
            await ws.send_json(message)
        except Exception:
            subscriptions[key].remove(ws)

    # Also broadcast to per-line summary, if any
    summary_key = f"{line_name}.summary"
    for ws in list(subscriptions.get(summary_key, [])):
        try:
            await ws.send_json(message)
        except Exception:
            subscriptions[summary_key].remove(ws)

# Initialize this once (preferably in your global_state)
if not hasattr(global_state, "last_sent"):
    global_state.last_sent = {}

async def broadcast_zone_update(line_name: str, zone: str, payload: dict):
    print(f"📢 Broadcasting {zone} update to {line_name}")
    key = f"{line_name}.visual.{zone}"
    ws_set = subscriptions.get(key, set()).copy()

    # 🚫 Skip if identical to last payload sent
    if global_state.last_sent.get(key) == payload:
        return

    global_state.last_sent[key] = payload  # 💾 Cache latest payload

    for ws in ws_set:
        try:
            if getattr(ws, "client_state", None) and ws.client_state.name != "CONNECTED":
                raise ConnectionError("WebSocket not connected")
            await ws.send_json(payload)
        except Exception as e:
            logger.warning(f"❌ WebSocket broadcast failed ({key}): {e}")
            subscriptions[key].discard(ws)

async def broadcast_stringatrice_warning(line_name: str, warning: dict):
    """
    Send a warning packet to every subscriber of /ws/warnings/{line_name}
    """
    key = f"{line_name}.warnings"
    websockets = subscriptions.get(key, set()).copy()   # snapshot avoids RuntimeError
    for ws in websockets:
        try:
            await ws.send_json(warning)
        except Exception:
            subscriptions[key].discard(ws)

async def broadcast_export_progress(progress_id: str, payload: dict):
    """Broadcast export progress updates to subscribers."""
    key = f"export.{progress_id}"
    websockets = subscriptions.get(key, set()).copy()
    for ws in websockets:
        try:
            if getattr(ws, "client_state", None) and ws.client_state.name != "CONNECTED":
                raise ConnectionError("WebSocket not connected")
            await ws.send_json(payload)
        except Exception as e:
            logger.warning(f"❌ WebSocket broadcast failed ({key}): {e}")
            subscriptions[key].discard(ws)