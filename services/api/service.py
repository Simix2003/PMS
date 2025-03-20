from functools import partial
import logging
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi import APIRouter, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from controllers.plc import OPCClient
import uvicorn
from contextlib import asynccontextmanager
import asyncio

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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # You can restrict this to your frontend IP in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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

    if val is True:
        object_id = await opc.read("SLS Interblocchi", CHANNELS[channel_id]["id_modulo_path"])
        await broadcast(channel_id, {
            "trigger": True,
            "objectId": object_id,
            "outcome": None
        })

    elif val is False:
        # 🚩 Object finished, go back to idle state
        print(f"🟡 Trigger on {channel_id} set to FALSE, resetting clients...")
        await broadcast(channel_id, {
            "trigger": False,
            "objectId": None,
            "outcome": None
        })

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

@app.get("/api/issues/{channel_id}")
async def get_issues(channel_id: str, path: str = "Dati.Esito.Esito_Scarto.Difetti"):
    if channel_id not in CHANNELS:
        return JSONResponse(status_code=404, content={"error": "Invalid channel"})

    db_map = {
        "M308": "SLS M308_QG2 DB User",
        "M309": "SLS M309_QG2 DB User",
        "M326": "SLS M326_RW1 DB User"
    }
    db_name = db_map[channel_id]

    try:
        db_node = await opc._find_db(db_name)
        path_parts = path.split(".")
        target_node = await opc._find_node(db_node, path_parts)
        children = await target_node.get_children()

        items = []
        for child in children:
            browse_name = await child.read_browse_name()
            node_class = await child.read_node_class()
            node_type = "item" if node_class.value == 2 else "folder"
            items.append({"name": browse_name.Name, "type": node_type})

        return {"path": path, "items": items}
    except Exception as e:
        return JSONResponse(status_code=400, content={"error": str(e)})

@app.post("/api/set_outcome")
async def set_outcome(request: Request):
    data = await request.json()
    channel_id = data.get("channel_id")
    object_id = data.get("object_id")
    outcome = data.get("outcome")  # "buona" or "scarto"

    if channel_id not in CHANNELS or outcome not in ["buona", "scarto"]:
        return JSONResponse(status_code=400, content={"error": "Invalid data"})

    # Read current Object ID from PLC (authoritative source)
    current_object_id = await opc.read("SLS Interblocchi", CHANNELS[channel_id]["id_modulo_path"])

    if str(current_object_id) != str(object_id):
        return JSONResponse(status_code=409, content={"error": "Stale object, already processed or expired."})

    # Proceed to write to PLC
    path = CHANNELS[channel_id]["fine_buona_path"] if outcome == "buona" else CHANNELS[channel_id]["fine_scarto_path"]
    success = await opc.write("SLS Interblocchi", path, "bool", True)

    if success:
        print(f"✅ Outcome '{outcome.upper()}' written for object {object_id} on {channel_id}")

        # Broadcast result to ALL active clients for this channel
        await broadcast(channel_id, {
            "trigger": None,
            "objectId": object_id,
            "outcome": outcome
        })
        return {"status": "ok"}
    else:
        return JSONResponse(status_code=500, content={"error": "PLC write failed"})

# ---------------- MAIN ----------------

if __name__ == "__main__":
    uvicorn.run("service:app", host="0.0.0.0", port=8000)
