import copy
import logging
import asyncio
from fastapi import WebSocket
from decimal import Decimal
import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.config import debug
from service.controllers.plc import PLCConnection
from service.helpers.helpers import get_channel_config
from service.state.global_state import subscriptions, plc_read_executor
import service.state.global_state as global_state

logger = logging.getLogger(__name__)

async def send_initial_state(websocket: WebSocket, channel_id: str, plc_connection: PLCConnection, line_name: str):
    paths = get_channel_config(line_name, channel_id)
    
    if paths is None:
        await websocket.send_json({"error": "Invalid line/channel combination"})
        return

    # ✅ Use `paths` for all access now (already scoped)
    trigger_conf = paths["trigger"]
    trigger_value = await asyncio.get_event_loop().run_in_executor(
        plc_read_executor,
        plc_connection.read_bool,
        trigger_conf["db"], trigger_conf["byte"], trigger_conf["bit"],
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
            object_id = await asyncio.get_event_loop().run_in_executor(
                plc_read_executor,
                plc_connection.read_string,
                id_mod_conf["db"], id_mod_conf["byte"], id_mod_conf["length"],
            )
        ###############################################################################################################################

        str_conf = paths["stringatrice"]
        values = [
            await asyncio.get_event_loop().run_in_executor(
                plc_read_executor,
                plc_connection.read_bool,
                str_conf["db"],
                str_conf["byte"],
                i,
            )
            for i in range(str_conf["length"])
        ]

        if not any(values):
            values[0] = True

        stringatrice_index = values.index(True) + 1
        stringatrice = str(stringatrice_index)

        fine_buona_conf = paths["fine_buona"]
        fine_buona = await asyncio.get_event_loop().run_in_executor(
            plc_read_executor,
            plc_connection.read_bool,
            fine_buona_conf["db"], fine_buona_conf["byte"], fine_buona_conf["bit"],
        )

        fine_scarto_conf = paths["fine_scarto"]
        fine_scarto = await asyncio.get_event_loop().run_in_executor(
            plc_read_executor,
            plc_connection.read_bool,
            fine_scarto_conf["db"], fine_scarto_conf["byte"], fine_scarto_conf["bit"],
        )

        if fine_buona:
            outcome = "buona"
        elif fine_scarto:
            outcome = "scarto"

        esito_conf = paths["esito_scarto_compilato"]
        issues_value = await asyncio.get_event_loop().run_in_executor(
            plc_read_executor,
            plc_connection.read_bool,
            esito_conf["db"], esito_conf["byte"], esito_conf["bit"],
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
    summary_key = f"{line_name}.summary"

    # Helper
    async def send_safe(ws):
        try:
            await ws.send_json(message)
            return ws  # Keep it
        except Exception:
            return None  # Drop it

    # Send to main channel
    conns = subscriptions.get(key, set())
    results = await asyncio.gather(*(send_safe(ws) for ws in conns))
    subscriptions[key] = {ws for ws in results if ws}

    # Send to summary channel
    summary_conns = subscriptions.get(summary_key, set())
    summary_results = await asyncio.gather(*(send_safe(ws) for ws in summary_conns))
    subscriptions[summary_key] = {ws for ws in summary_results if ws}


# Clean recursively: convert Decimal → float
def clean_for_json(obj):
    if isinstance(obj, dict):
        return {k: clean_for_json(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [clean_for_json(v) for v in obj]
    elif isinstance(obj, Decimal):
        return float(obj)
    elif isinstance(obj, set):  # 👈 FIX
        return list(obj)
    else:
        return obj

# Initialize once at startup
if not hasattr(global_state, "last_sent"):
    global_state.last_sent = {}

async def broadcast_zone_update(line_name: str, zone: str, payload: dict):
    logger.debug(f"📢 Broadcasting {zone} update to {line_name}")
    key = f"{line_name}.visual.{zone}"
    ws_set = subscriptions.get(key, set()).copy()

    # 🧹 Remove volatile/internal fields
    payload = copy.deepcopy(payload)
    payload.pop("__seen", None)

    # 🧼 Clean for JSON serialization
    payload_clean = clean_for_json(payload)
    if not isinstance(payload_clean, dict):
        raise ValueError("broadcast_zone_update expects payload to clean into a dict")

    # 🚫 Skip if identical to last payload
    if global_state.last_sent.get(key) == payload_clean:
        return

    global_state.last_sent[key] = payload_clean

    for ws in ws_set:
        try:
            if getattr(ws, "client_state", None) and ws.client_state.name != "CONNECTED":
                raise ConnectionError("WebSocket not connected")
            await ws.send_json(payload_clean)
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

async def broadcast_escalation_update(payload: list[dict]):
    message = {"type": "escalation_update", "payload": clean_for_json(payload)}
    websockets = global_state.escalation_websockets.copy()
    for ws in websockets:
        try:
            if getattr(ws, "client_state", None) and ws.client_state.name != "CONNECTED":
                raise ConnectionError("WebSocket not connected")
            await ws.send_json(message)
        except Exception as e:
            logger.warning(f"❌ WebSocket broadcast failed (/ws/escalations): {e}")
            global_state.escalation_websockets.discard(ws)
