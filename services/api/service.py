from functools import partial
import logging
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi import Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
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
    issues_submitted = False

    if trigger_value is True:
        object_id = await opc.read("SLS Interblocchi", paths["id_modulo_path"])

        fine_buona = await opc.read("SLS Interblocchi", paths["fine_buona_path"])
        fine_scarto = await opc.read("SLS Interblocchi", paths["fine_scarto_path"])

        if fine_buona is True:
            outcome = "buona"
        elif fine_scarto is True:
            outcome = "scarto"

        # NEW: Read "Compilato Su Ipad_Scarto presente" from the DB to set issuesSubmitted
        db_map = {
            "M308": "SLS M308_QG2 DB User",
            "M309": "SLS M309_QG2 DB User",
            "M326": "SLS M326_RW1 DB User"
        }
        db_name = db_map[channel_id]
        issues_value = await opc.read(db_name, "Dati.Esito.Esito_Scarto.Compilato Su Ipad_Scarto presente")
        if issues_value is True:
            issues_submitted = True

    await websocket.send_json({
        "trigger": trigger_value,
        "objectId": object_id,
        "outcome": outcome,
        "issuesSubmitted": issues_submitted
    })
async def broadcast(channel_id: str, message: dict):
    for ws in list(subscriptions.get(channel_id, [])):
        try:
            await ws.send_json(message)
        except:
            subscriptions[channel_id].remove(ws)

async def scan_issues(node, base_path):
    selected = []
    children = await node.get_children()

    for child in children:
        browse_name = await child.read_browse_name()
        name = browse_name.Name
        full_path = f"{base_path}.{name}"

        try:
            value = await child.read_value()
        except:
            value = None

        # 📦 If it is a struct or folder, go deeper
        if not isinstance(value, bool):
            deeper = await scan_issues(child, full_path)
            selected.extend(deeper)
        else:
            print(f"➡️ {full_path} = {value}")
            if value is True:
                selected.append(full_path)
                print(f"✅ Selected: {full_path}")

    return selected

# ---------------- PLC EVENTS ----------------

async def on_trigger_change(opc, channel_id, node, val, data):
    if not isinstance(val, bool):
        return

    if val is True:
        object_id = await opc.read("SLS Interblocchi", CHANNELS[channel_id]["id_modulo_path"])

        # NEW: Also read issuesSubmitted when broadcasting trigger = True
        db_map = {
            "M308": "SLS M308_QG2 DB User",
            "M309": "SLS M309_QG2 DB User",
            "M326": "SLS M326_RW1 DB User"
        }
        db_name = db_map[channel_id]
        issues_value = await opc.read(db_name, "Dati.Esito.Esito_Scarto.Compilato Su Ipad_Scarto presente")
        issues_submitted = issues_value is True

        await broadcast(channel_id, {
            "trigger": True,
            "objectId": object_id,
            "outcome": None,
            "issuesSubmitted": issues_submitted
        })

    elif val is False:
        print(f"🟡 Trigger on {channel_id} set to FALSE, resetting clients...")
        await broadcast(channel_id, {
            "trigger": False,
            "objectId": None,
            "outcome": None,
            "issuesSubmitted": False
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
            name = browse_name.Name.lower()
            node_class = await child.read_node_class()
            node_type = "folder"  # default

            # Read value & datatype
            try:
                value = await child.read_value()
            except:
                value = None

            # Skip "riserva" bools!
            if "riserva" in name and isinstance(value, bool):
                continue

            if isinstance(value, bool):
                node_type = "bool"
            elif isinstance(value, list):
                node_type = "folder"
            elif "ExtensionObject" in str(type(value)):
                node_type = "folder"
            else:
                node_type = "folder"

            items.append({"name": browse_name.Name, "type": node_type})

        return {"path": path, "items": items}
    except Exception as e:
        return JSONResponse(status_code=400, content={"error": str(e)})

@app.post("/api/set_issues")
async def set_issues(request: Request):
    data = await request.json()
    channel_id = data.get("channel_id")
    object_id = data.get("object_id")
    issues = data.get("issues", [])

    # 1️⃣ Map to correct DB based on channel_id
    db_map = {
        "M308": "SLS M308_QG2 DB User",
        "M309": "SLS M309_QG2 DB User",
        "M326": "SLS M326_RW1 DB User"
    }

    if channel_id not in db_map:
        return JSONResponse(status_code=400, content={"error": "Invalid channel_id"})

    db_name = db_map[channel_id]

    # 2️⃣ Write each issue
    for issue_path in issues:
        split_index = issue_path.find("Dati.")
        if split_index == -1:
            print(f"❌ Invalid path: {issue_path}")
            continue

        relative_path = issue_path[split_index:]  # "Dati.Esito...."
        path_parts = relative_path.split(".")

        success = await opc.write(db_name, relative_path, "bool", True)

        if not success:
            print(f"❌ WRITE FAILED: {db_name}.{relative_path}")

    await opc.write(db_name, "Dati.Esito.Esito_Scarto.Compilato Su Ipad_Scarto presente", "bool", True)

    return {"status": "ok"}

@app.get("/api/get_issues")
async def get_selected_issues(channel_id: str, path: str = "Dati.Esito.Esito_Scarto.Difetti"):
    if channel_id not in CHANNELS:
        return JSONResponse(status_code=404, content={"error": "Invalid channel"})

    db_map = {
        "M308": "SLS M308_QG2 DB User",
        "M309": "SLS M309_QG2 DB User",
        "M326": "SLS M326_RW1 DB User"
    }
    db_name = db_map[channel_id]

    try:
        await opc.write(db_name, "Dati.Esito.Esito_Scarto.Compilato Su Ipad_Scarto presente", "bool", False)
        db_node = await opc._find_db(db_name)
        path_parts = path.split(".")
        target_node = await opc._find_node(db_node, path_parts)

        print(f"🔍 Scanning {db_name}.{path} recursively for TRUE values...")

        selected_issues = await scan_issues(target_node, path)

        print(f"📤 Sending selected issues: {selected_issues}")
        return {"selected_issues": selected_issues}
    except Exception as e:
        print(f"❌ Error during OPC scan: {e}")
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
