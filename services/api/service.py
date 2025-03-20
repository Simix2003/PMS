import configparser
from functools import partial
import logging
import threading
import time
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from controllers.plc import OPCClient, PLCConnection
import uvicorn
from typing import AsyncGenerator
from contextlib import asynccontextmanager


# ---------------- CONFIG & GLOBALS ----------------
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

# These globals are used to track WebSocket subscriptions and PLC subscription state.
subscriptions = {}
plc_subscriptions = {}
fine_subscriptions = {}  # For tracking "fine lavorazione" subscriptions if needed

# Global flag for background task control (if you decide to use it)
stop_threads = {"M308": False, "M309": False, "M326": False}

# Instantiate OPC client with your OPC UA URL
opc = OPCClient("opc.tcp://192.168.1.1:4840")


# ---------------- LIFESPAN ----------------
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    # 1️⃣ Connect to OPC UA
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

    # Load PLC IP/SLOT + Stations
    plc_ip, plc_slot, station_configs = load_station_configs("C:/IX-Monitor/stations.ini")

    for station, params in station_configs.items():
        try:
            plc_connection = PLCConnection(ip_address=plc_ip, slot=plc_slot)
        except Exception as e:
            logging.error(f"[{station}] Failed to connect to PLC: {e}")
            continue

        # Start background task for this station
        thread = threading.Thread(
            target=background_task,
            args=(plc_connection, params, station),
            daemon=True
        )
        thread.start()
        logging.info(f"[{station}] Snap7 background thread started.")

    yield

    # 4️⃣ Cleanup logic
    print("🔴 Disconnecting OPC...")
    await opc.disconnect()
    print("🟠 Shutting down Snap7 threads...")
    for station in stop_threads:
        stop_threads[station] = True
    print("✅ Clean exit.")


app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust for production use
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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

        # Read the "issuesSubmitted" flag from the corresponding DB
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
        except Exception as e:
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

        # If not a boolean, assume it's a folder/struct and scan deeper
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

import logging

def read_station_data(plc_connection, station):
    station_db_map = {
        "M308": 19004,
        "M309": 19005,
        "M326": 19006
    }

    db_number = station_db_map.get(station)
    if db_number is None:
        logging.error(f"Unknown station '{station}' provided.")
        return None

    try:
        data = {}

        # ---- Strings ----
        data["Id_Modulo"] = plc_connection.read_string(db_number, 0, 20)
        data["Id_Utente"] = plc_connection.read_string(db_number, 22, 20)

        # ---- Bit Arrays ----
        data["Linea_in_Lavorazione"] = [plc_connection.read_bool(db_number, 60, i) for i in range(5)]
        data["Lavorazione_Eseguita_Su_Stringatrice"] = [plc_connection.read_bool(db_number, 62, i) for i in range(5)]

        # ---- Single Bool ----
        data["Compilato_Su_Ipad_Scarto_Presente"] = plc_connection.read_bool(db_number, 64, 0)

        # ---- Stringa_F ----
        data["Stringa_F"] = []
        for i in range(6):
            base = 66 + i * 2
            ribbons = [plc_connection.read_bool(db_number, base, j) for j in range(10)]
            data["Stringa_F"].append(ribbons)

        # ---- Stringa_M_F ----
        data["Stringa_M_F"] = []
        for i in range(6):
            base = 78 + i * 2
            saldatura = [plc_connection.read_bool(db_number, base, j) for j in range(10)]
            data["Stringa_M_F"].append(saldatura)

        # ---- Stringa_M_B ----
        data["Stringa_M_B"] = []
        for i in range(6):
            base = 90 + i * 2
            saldatura = [plc_connection.read_bool(db_number, base, j) for j in range(10)]
            data["Stringa_M_B"].append(saldatura)

        # ---- Stringa_B ----
        data["Stringa_B"] = []
        for i in range(6):
            base = 102 + i * 2
            saldatura = [plc_connection.read_bool(db_number, base, j) for j in range(10)]
            data["Stringa_B"].append(saldatura)

        # ---- Disallineamento Ribbon ----
        dis = {}
        dis["Ribbon_Stringa_F"] = [plc_connection.read_bool(db_number, 114, i) for i in range(12)]
        dis["Ribbon_Stringa_M"] = [plc_connection.read_bool(db_number, 116, i) for i in range(12)]
        dis["Ribbon_Stringa_B"] = [plc_connection.read_bool(db_number, 118, i) for i in range(12)]
        data["Disallineamento"] = dis

        # ---- Stringa ----
        data["Stringa"] = [plc_connection.read_bool(db_number, 120, i) for i in range(12)]

        # ---- Mancanza_Ribbon ----
        mr = {}
        mr["Ribbon_Stringa_F"] = [plc_connection.read_bool(db_number, 122, i) for i in range(12)]
        mr["Ribbon_Stringa_M"] = [plc_connection.read_bool(db_number, 124, i) for i in range(12)]
        mr["Ribbon_Stringa_B"] = [plc_connection.read_bool(db_number, 126, i) for i in range(12)]
        data["Mancanza_Ribbon"] = mr

        # ---- Rottura_Celle ----
        rc = []
        for s in range(12):
            base = 128 + s * 2
            celle = [plc_connection.read_bool(db_number, base, i) for i in range(10)]
            rc.append(celle)
        data["Rottura_Celle"] = rc

        # ---- Macchie_ECA_Celle ----
        mec = []
        for s in range(12):
            base = 152 + s * 2
            celle = [plc_connection.read_bool(db_number, base, i) for i in range(10)]
            mec.append(celle)
        data["Macchie_ECA_Celle"] = mec

        # ---- Generali ----
        generali = {}
        generali["Non_Lavorato_Poe_Scaduto"] = plc_connection.read_bool(db_number, 176, 0)
        generali["Non_Lavorato_da_Telecamere"] = plc_connection.read_bool(db_number, 176, 1)
        generali["Materiale_Esterno_su_Celle"] = plc_connection.read_bool(db_number, 176, 2)
        generali["Bad_Soldering"] = plc_connection.read_bool(db_number, 176, 3)
        for i in range(4, 16):
            byte = 176 + i // 8
            bit = i % 8
            generali[f"Non_Lavorato_Riserva_{i}"] = plc_connection.read_bool(db_number, byte, bit)
        data["Generali"] = generali

        logging.info(f"[{station}] Data read successfully.")
        return data

    except Exception as e:
        logging.error(f"[{station}] Error reading PLC data: {e}")
        return None

# ---------------- CONFIG PARSING ----------------
        
def load_station_configs(file_path):
    config = configparser.ConfigParser()
    config.read(file_path)

    plc_ip = config.get("PLC", "IP")
    plc_slot = config.getint("PLC", "SLOT")
    station_configs = {}

    for section in config.sections():
        if section.startswith("M"):
            station_configs[section] = {
                "Richiesta_DB": config.getint(section, "Richiesta_DB"),
                "Richiesta_Byte": config.getint(section, "Richiesta_Byte"),
                "Richiesta_Bit": config.getint(section, "Richiesta_Bit"),
                "CLOCK_DB": config.getint(section, "CLOCK_DB"),
                "CLOCK_Byte": config.getint(section, "CLOCK_Byte"),
                "CLOCK_Bit": config.getint(section, "CLOCK_Bit"),
                "Lettura_DB": config.getint(section, "Lettura_DB"),
                "Lettura_Byte": config.getint(section, "Lettura_Byte"),
                "Lettura_Bit": config.getint(section, "Lettura_Bit"),
            }

    return plc_ip, plc_slot, station_configs


# ---------------- BACKGROUND TASK ----------------
def background_task(plc_connection, params, station):
    global stop_threads
    stop_threads.setdefault(station, False)

    last_plc_clock_value = None
    plc_clock_stable_time = 0
    last_toggle_time = time.time()
    toggle_state = False

    print(f"[{station}] Starting background task.")

    while not stop_threads.get(station, False):
        try:
            richiesta = plc_connection.read_bool(
                params["Richiesta_DB"],
                params["Richiesta_Byte"],
                params["Richiesta_Bit"]
            )
            if richiesta is None:
                time.sleep(1)
                continue

            # Toggle PC_CLOCK
            if time.time() - last_toggle_time >= 1:
                toggle_state = not toggle_state
                plc_connection.write_bool(
                    params["CLOCK_DB"],
                    params["CLOCK_Byte"],
                    params["CLOCK_Bit"],
                    toggle_state
                )
                logging.info(f"[{station}] PC_CLOCK toggled to {toggle_state}")
                last_toggle_time = time.time()

            # Track PLC_CLOCK stability
            plc_clock_value = plc_connection.read_bool(
                params["CLOCK_DB"],
                params["CLOCK_Byte"],
                params["CLOCK_Bit"]
            )
            if plc_clock_value == last_plc_clock_value:
                plc_clock_stable_time += 1
                if plc_clock_stable_time >= 10:
                    logging.warning(f"[{station}] PLC_CLOCK stable for 10 seconds.")
            else:
                plc_clock_stable_time = 0
                last_plc_clock_value = plc_clock_value

            # Process Richiesta
            if richiesta:
                print(f"[{station}] Richiesta active, processing data...")

                result = read_station_data(plc_connection, station)
                if result:
                    print(f"Read result: {result}")

                # 👉 Write "true" to Lettura
                plc_connection.write_bool(
                    params["Lettura_DB"],
                    params["Lettura_Byte"],
                    params["Lettura_Bit"],
                    True
                )
                logging.info(f"[{station}] Set Lettura bit to TRUE.")

            time.sleep(1)

        except Exception as e:
            logging.error(f"Error in background task for {station}: {str(e)}")
            time.sleep(5)


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
            # Wait for messages from the client (if needed)
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
            node_type = "folder"  # Default node type

            try:
                value = await child.read_value()
            except:
                value = None

            if "riserva" in name and isinstance(value, bool):
                continue

            if isinstance(value, bool):
                node_type = "bool"
            # Other type checks can be added as needed

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

    db_map = {
        "M308": "SLS M308_QG2 DB User",
        "M309": "SLS M309_QG2 DB User",
        "M326": "SLS M326_RW1 DB User"
    }

    if channel_id not in db_map:
        return JSONResponse(status_code=400, content={"error": "Invalid channel_id"})

    db_name = db_map[channel_id]

    for issue_path in issues:
        split_index = issue_path.find("Dati.")
        if split_index == -1:
            print(f"❌ Invalid path: {issue_path}")
            continue

        relative_path = issue_path[split_index:]
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
        # Reset the "issuesSubmitted" flag before scanning
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
    outcome = data.get("outcome")  # Should be "buona" or "scarto"

    if channel_id not in CHANNELS or outcome not in ["buona", "scarto"]:
        return JSONResponse(status_code=400, content={"error": "Invalid data"})

    # Check the current Object ID from the PLC (as the authoritative source)
    current_object_id = await opc.read("SLS Interblocchi", CHANNELS[channel_id]["id_modulo_path"])
    if str(current_object_id) != str(object_id):
        return JSONResponse(status_code=409, content={"error": "Stale object, already processed or expired."})

    path = CHANNELS[channel_id]["fine_buona_path"] if outcome == "buona" else CHANNELS[channel_id]["fine_scarto_path"]
    success = await opc.write("SLS Interblocchi", path, "bool", True)

    if success:
        print(f"✅ Outcome '{outcome.upper()}' written for object {object_id} on {channel_id}")
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
