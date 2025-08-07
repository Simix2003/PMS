# service/routes/websocket_routes.py

import asyncio
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Request
import logging
import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.helpers.helpers import get_channel_config
from service.routes.broadcast import send_initial_state
from service.state.global_state import subscriptions, escalation_websockets

router = APIRouter()
logger = logging.getLogger(__name__)

# ---------------- WEB SOCKETS ----------------

@router.websocket("/ws/summary/{line_name}")
async def websocket_summary(websocket: WebSocket, line_name: str):
    await websocket.accept()
    key = f"{line_name}.summary"
    logger.debug(f"Dashboard summary client connected for {line_name}")

    subscriptions.setdefault(key, set()).add(websocket)

    try:
        while True:
            await websocket.receive_text()  # keep-alive
    except WebSocketDisconnect:
        logger.debug(f"Dashboard summary client for {line_name} disconnected")
        subscriptions[key].remove(websocket)

@router.websocket("/ws/visual/{line_name}/{zone}")
async def websocket_visual(websocket: WebSocket, line_name: str, zone: str):
    await websocket.accept()
    key = f"{line_name}.visual.{zone}"
    logger.debug(f"Visual page client connected for {line_name} / {zone}")

    subscriptions.setdefault(key, set()).add(websocket)

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        logger.debug(f"Visual page client for {line_name}/{zone} disconnected")
        subscriptions[key].remove(websocket)

@router.websocket("/ws/warnings/{line_name}")
async def websocket_warnings(websocket: WebSocket, line_name: str):
    await websocket.accept()
    key = f"{line_name}.warnings"
    logger.debug(f"Stringatrice‑warning client connected for {line_name}")

    subscriptions.setdefault(key, set()).add(websocket)

    try:
        while True:
            await websocket.receive_text()  # keep-alive
    except WebSocketDisconnect:
        logger.debug(f"Stringatrice‑warning client for {line_name} disconnected")
        subscriptions[key].remove(websocket)


@router.websocket("/ws/escalations")
async def websocket_escalations(websocket: WebSocket):
    await websocket.accept()
    escalation_websockets.add(websocket)
    logger.debug("Escalation client connected")
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        logger.debug("Escalation client disconnected")
    finally:
        escalation_websockets.discard(websocket)


@router.websocket("/ws/export/{progress_id}")
async def websocket_export_progress(websocket: WebSocket, progress_id: str):
    """WebSocket endpoint for Excel export progress updates."""
    await websocket.accept()
    key = f"export.{progress_id}"

    subscriptions.setdefault(key, set()).add(websocket)

    try:
        while True:
            await websocket.receive_text()  # keep-alive
    except WebSocketDisconnect:
        subscriptions[key].remove(websocket)


@router.websocket("/ws/{line_name}/{channel_id}")
async def websocket_endpoint(websocket: WebSocket, line_name: str, channel_id: str):
    full_id = f"{line_name}.{channel_id}"

    if get_channel_config(line_name, channel_id) is None:
        await websocket.close()
        logger.warning(f"Invalid channel config for {full_id}")
        return

    await websocket.accept()
    await websocket.send_json({"handshake": True})
    logger.debug(f"Client subscribed to {full_id}")

    subscriptions.setdefault(full_id, set()).add(websocket)

    # Accessing app state through websocket
    app = websocket.app  # This is available starting from FastAPI 0.68+
    plc_connections = app.state.plc_connections
    plc_connection = plc_connections.get(full_id)

    if not plc_connection:
        logger.warning(f"No PLC connection found for {full_id}.")
        await websocket.close()
        return

    if not plc_connection.connected or not plc_connection.is_connected():
        logger.debug(f"⚠️ PLC for {full_id} is disconnected. Attempting reconnect for WebSocket...")
        plc_connection.reconnect_once_now(reason="WebSocket initial handshake")
        await asyncio.sleep(2)  # Give it time to reconnect

        if not plc_connection.connected or not plc_connection.is_connected():
            logger.warning(f"❌ Failed to reconnect PLC for {full_id}. Closing socket.")
            await websocket.close()
            return
        else:
            logger.debug(f"✅ PLC reconnected for {full_id}!")


    await send_initial_state(websocket, channel_id, plc_connection, line_name)

    try:
        while True:
            await websocket.receive_text()  # keep-alive
    except WebSocketDisconnect:
        logger.debug(f"Client disconnected from {full_id}")
    finally:
        subscriptions[full_id].remove(websocket)
