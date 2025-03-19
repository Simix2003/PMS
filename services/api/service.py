import asyncio
from functools import partial
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from controllers.plc import OPCClient
import uvicorn
from contextlib import asynccontextmanager

opc = OPCClient("opc.tcp://192.168.1.1:4840")

@asynccontextmanager
async def lifespan(app: FastAPI):
    await opc.connect()
    print("🟢 OPC Connected. Subscribing to all trigger paths...")

    for channel_id, paths in CHANNELS.items():
        await opc.subscribe(
            "SLS Interblocchi",
            paths["trigger_path"],
            partial(on_trigger_change, opc, channel_id)
        )
        print(f"🔔 Subscribed to trigger for {channel_id}")
        plc_subscriptions[channel_id] = True

    yield

    # Unsubscribe cleanup if needed
    print("🔴 Disconnecting OPC...")
    await opc.disconnect()

app = FastAPI(lifespan=lifespan)

# ---------------- CONFIG ----------------
CHANNELS = {
    "M308": {
        "trigger_path": "Da Bottero A CapGemini.M308_QG2.Inizio Lavorazione in Automatico",
        "id_modulo_path": "Da Bottero A CapGemini.M308_QG2.Id_Modulo",
        "fine_buona_path": "Da Bottero A CapGemini.M308_QG2.Fine Lavorazione Buona",
        "fine_scarto_path": "Da Bottero A CapGemini.M308_QG2.Fine Lavorazione Scarto"
    },
    "M309": {
        "trigger_path": "Da Bottero A CapGemini.M309_QG2.Inizio Lavorazione in Automatico",
        "id_modulo_path": "Da Bottero A CapGemini.M309_QG2.Id_Modulo",
        "fine_buona_path": "Da Bottero A CapGemini.M309_QG2.Fine Lavorazione Buona",
        "fine_scarto_path": "Da Bottero A CapGemini.M309_QG2.Fine Lavorazione Scarto"
    },
    "M326": {
        "trigger_path": "Da Bottero A CapGemini.M326_RW1.Inizio Lavorazione in Automatico",
        "id_modulo_path": "Da Bottero A CapGemini.M326_RW1.Id_Modulo",
        "fine_buona_path": "Da Bottero A CapGemini.M326_RW1.Fine Lavorazione Buona",
        "fine_scarto_path": "Da Bottero A CapGemini.M326_RW1.Fine Lavorazione Scarto"
    }
}

subscriptions = {}
plc_subscriptions = {}
fine_subscriptions = {}  # Track fine lavorazione subs per cleanup

# ---------------- HELPERS ----------------

async def send_initial_state(websocket: WebSocket, channel_id: str):
    paths = CHANNELS[channel_id]
    trigger_value = await opc.read("SLS Interblocchi", paths["trigger_path"])
    object_id = ""
    outcome = None

    if trigger_value is True:
        object_id = await opc.read("SLS Interblocchi", paths["id_modulo_path"])

        fine_buona = await opc.read("SLS Interblocchi", paths["fine_buona_path"])
        fine_scarto = await opc.read("SLS Interblocchi", paths["fine_scarto_path"])

        if fine_buona is True:
            outcome = "buona"
        elif fine_scarto is True:
            outcome = "scarto"

    await websocket.send_json({
        "trigger": trigger_value,
        "objectId": object_id,
        "outcome": outcome
    })

async def broadcast(channel_id: str, message: dict):
    for ws in list(subscriptions.get(channel_id, [])):
        try:
            await ws.send_json(message)
        except:
            subscriptions[channel_id].remove(ws)

# ---------------- PLC EVENTS ----------------

async def on_trigger_change(opc, channel_id, node, val, data):
    if not isinstance(val, bool):
        return

    print(f"✅ Trigger on {channel_id} -> val: {val}")
    paths = CHANNELS[channel_id]
    object_id = ""

    if val is True:
        object_id = await opc.read("SLS Interblocchi", paths["id_modulo_path"])
        print(f"📦 Id_Modulo = {object_id}")

        # ➕ Subscribe to fine lavorazione signals dynamically
        fine_buona_sub = await opc.subscribe(
            "SLS Interblocchi",
            paths["fine_buona_path"],
            partial(on_fine_lavorazione, opc, channel_id, object_id, "buona")
        )

        fine_scarto_sub = await opc.subscribe(
            "SLS Interblocchi",
            paths["fine_scarto_path"],
            partial(on_fine_lavorazione, opc, channel_id, object_id, "scarto")
        )

        fine_subscriptions[channel_id] = [fine_buona_sub, fine_scarto_sub]

    await broadcast(channel_id, {
        "trigger": val,
        "objectId": object_id,
        "outcome": None
    })

async def on_fine_lavorazione(opc, channel_id, object_id, outcome, node, val, data):
    if isinstance(val, bool) and val is True:
        print(f"🏁 Fine lavorazione {outcome} on {channel_id} | objectId={object_id}")
        
        # 🔄 Broadcast to Flutter
        await broadcast(channel_id, {
            "trigger": None,
            "objectId": object_id,
            "outcome": outcome
        })

        # 🧹 Cleanup fine lavorazione subscriptions
        if channel_id in fine_subscriptions:
            for sub_id in fine_subscriptions[channel_id]:
                await opc.unsubscribe(sub_id)
            del fine_subscriptions[channel_id]

# ---------------- ROUTES ----------------

@app.websocket("/ws/{channel_id}")
async def websocket_endpoint(websocket: WebSocket, channel_id: str):
    if channel_id not in CHANNELS:
        await websocket.close()
        return

    await websocket.accept()
    print(f"📲 Client subscribed to {channel_id}")

    subscriptions.setdefault(channel_id, set()).add(websocket)

    await send_initial_state(websocket, channel_id)

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        print(f"⚠️ Client disconnected from {channel_id}")
    finally:
        subscriptions[channel_id].remove(websocket)

# ---------------- MAIN ----------------

if __name__ == "__main__":
    uvicorn.run("service:app", host="0.0.0.0", port=8000)
