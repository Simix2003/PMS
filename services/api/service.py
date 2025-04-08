import asyncio
import configparser
import datetime
from datetime import datetime, timedelta
import json
import logging
import os
import time
from fastapi import FastAPI, Form, Query, UploadFile, WebSocket, WebSocketDisconnect, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from controllers.plc import PLCConnection
import uvicorn
from typing import AsyncGenerator
from contextlib import asynccontextmanager
from pymysql.cursors import DictCursor
import pymysql
import re
from fastapi.staticfiles import StaticFiles
from typing import Optional, Union, Dict


# ---------------- CONFIG & GLOBALS ----------------
CHANNELS = {
    "Linea1": {
        "M308": {
            "trigger": {"db": 19606, "byte": 0, "bit": 4},
            "id_modulo": {"db": 19606, "byte": 2, "length": 20},
            "id_utente": {"db": 19606, "byte": 24, "length": 20},
            "fine_buona": {"db": 19606, "byte": 0, "bit": 6},
            "fine_scarto": {"db": 19606, "byte": 0, "bit": 7},
            "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 0},
            "stringatrice": {"db": 19606, "byte": 46, "length": 5},
        },
        "M309": {
            "trigger": {"db": 19606, "byte": 48, "bit": 4},
            "id_modulo": {"db": 19606, "byte": 50, "length": 20},
            "id_utente": {"db": 19606, "byte": 72, "length": 20},
            "fine_buona": {"db": 19606, "byte": 48, "bit": 6},
            "fine_scarto": {"db": 19606, "byte": 48, "bit": 7},
            "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 1},
            "stringatrice": {"db": 19606, "byte": 94, "length": 5},
        },
    "M326": {
            "trigger": {"db": 19606, "byte": 96, "bit": 4},
            "id_modulo": {"db": 19606, "byte": 98, "length": 20},
            "id_utente": {"db": 19606, "byte": 120, "length": 20},
            "fine_buona": {"db": 19606, "byte": 96, "bit": 4},
            "fine_scarto": {"db": 19606, "byte": 96, "bit": 5},
            "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 2},
            "stringatrice": {"db": 19606, "byte": 142, "length": 5},
        },
    },
    "Linea2": {
        "M308": {
            "trigger": {"db": 19606, "byte": 0, "bit": 4},
            "id_modulo": {"db": 19606, "byte": 2, "length": 20},
            "id_utente": {"db": 19606, "byte": 24, "length": 20},
            "fine_buona": {"db": 19606, "byte": 0, "bit": 6},
            "fine_scarto": {"db": 19606, "byte": 0, "bit": 7},
            "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 0},
            "stringatrice": {"db": 19606, "byte": 46, "length": 5},
        },
        "M309": {
            "trigger": {"db": 19606, "byte": 48, "bit": 4},
            "id_modulo": {"db": 19606, "byte": 50, "length": 20},
            "id_utente": {"db": 19606, "byte": 72, "length": 20},
            "fine_buona": {"db": 19606, "byte": 48, "bit": 6},
            "fine_scarto": {"db": 19606, "byte": 48, "bit": 7},
            "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 1},
            "stringatrice": {"db": 19606, "byte": 94, "length": 5},
        },
    "M326": {
            "trigger": {"db": 19606, "byte": 96, "bit": 4},
            "id_modulo": {"db": 19606, "byte": 98, "length": 20},
            "id_utente": {"db": 19606, "byte": 120, "length": 20},
            "fine_buona": {"db": 19606, "byte": 96, "bit": 4},
            "fine_scarto": {"db": 19606, "byte": 96, "bit": 5},
            "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 2},
            "stringatrice": {"db": 19606, "byte": 142, "length": 5},
        },
    },
}

ISSUE_TREE = {
    "Dati": {
        "Esito": {
            "Esito_Scarto": {
                "Difetti": {
                    "Generali": {
                        "Non Lavorato Poe Scaduto": {},
                        "Non Lavorato da Telecamere": {},
                        "Materiale Esterno su Celle": {},
                        "Bad Soldering": {}
                    },
                    "Saldatura": {
                        f"Stringa[{i}]": {
                            f"Pin[{j}]": {
                                "F": None,
                                "M": None,
                                "B": None
                            } for j in range(1, 21)
                        } for i in range(1, 13)
                    },
                   "Disallineamento": {
                        **{f"Stringa[{i}]": None for i in range(1, 13)},
                        **{f"Ribbon[{i}]": {
                            "F": None,
                            "M": None,
                            "B": None
                        } for i in range(1, 11)}
                    },
                    "Mancanza Ribbon": {
                        f"Ribbon[{i}]": {
                            "F": None,
                            "M": None,
                            "B": None
                        } for i in range(1, 11)
                    },
                    "Macchie ECA": {
                        f"Stringa[{i}]": None for i in range(1, 13)
                    },
                    "Celle Rotte": {
                        f"Stringa[{i}]": None for i in range(1, 13)
                    },
                     "Lunghezza String Ribbon": {
                        f"Stringa[{i}]": None for i in range(1, 13)
                    },
                }
            }
        }
    }
}

TEMP_STORAGE_PATH = os.path.join("C:/IX-Monitor", "temp_data.json")

# These globals are used to track WebSocket subscriptions and PLC subscription state.
subscriptions = {}
# Temporary store for trigger timestamps
trigger_timestamps = {}

stop_threads = {}
passato_flags = {}

# Then during startup:
for line in CHANNELS:
    for station in CHANNELS[line]:
        key = f"{line}.{station}"
        stop_threads[key] = False
        passato_flags[key] = False


plc_connections = {} 

# GLOBAL
mysql_connection = None
# In-memory session history for chat
user_sessions = {} 

SESSION_TIMEOUT = 600  # 600 seconds = 10 minutes

def get_channel_config(line_name: str, channel_id: str):
    return CHANNELS.get(line_name, {}).get(channel_id)

# ---------------- LIFESPAN ----------------
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    global mysql_connection
    mysql_connection = pymysql.connect(
        host="localhost",
        user="root",
        password="Master36!",
        database="ix_monitor",
        port=3306,
        cursorclass=DictCursor,
        autocommit=False
    )
    print("🟢 MySQL connected!")

    line_configs = load_station_configs("C:/IX-Monitor/stations.ini")

    for line, config in line_configs.items():
        plc_ip = config["PLC"]["IP"]
        plc_slot = config["PLC"]["SLOT"]

        for station in config["stations"]:
            plc_conn = PLCConnection(ip_address=plc_ip, slot=plc_slot, status_callback=make_status_callback(station))
            plc_connections[f"{line}.{station}"] = plc_conn
            asyncio.create_task(background_task(plc_conn, f"{line}.{station}"))
            print(f"🚀 Background task created for {line}.{station}")

    yield

    mysql_connection.close()
    print("🔴 MySQL disconnected.")

app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust for production use
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount("/images", StaticFiles(directory="C:/IX-Monitor/images"), name="images")

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

    if trigger_value:
        id_mod_conf = paths["id_modulo"]
        object_id = await asyncio.to_thread(
            plc_connection.read_string,
            id_mod_conf["db"], id_mod_conf["byte"], id_mod_conf["length"]
        )

        # 🔁 FIX THIS LINE – it was still accessing CHANNELS by only channel_id!
        str_conf = paths["stringatrice"]  # ✅ Use `paths` here
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

def load_temp_data():
    # Ensure directory exists
    os.makedirs(os.path.dirname(TEMP_STORAGE_PATH), exist_ok=True)
    
    if not os.path.exists(TEMP_STORAGE_PATH):
        # Create an empty JSON file if it doesn't exist
        with open(TEMP_STORAGE_PATH, "w") as file:
            json.dump([], file, indent=4)
        return []

    # If it exists, load normally
    with open(TEMP_STORAGE_PATH, "r") as file:
        try:
            return json.load(file)
        except json.JSONDecodeError:
            # If the file is corrupted or empty
            return []

def save_temp_data(data):
    # Ensure directory exists before saving
    os.makedirs(os.path.dirname(TEMP_STORAGE_PATH), exist_ok=True)
    with open(TEMP_STORAGE_PATH, "w") as file:
        json.dump(data, file, indent=4)
        
def get_latest_issues(line_name: str, channel_id: str):
    """
    Returns the issues list for the given station.
    Searches the temporary storage for the latest entry with matching line_name and channel_id.
    """
    temp_data = load_temp_data()
    for entry in reversed(temp_data):
        if (
            entry.get("line_name") == line_name and
            entry.get("channel_id") == channel_id
        ):
            return entry.get("issues", [])
    return []

def remove_temp_issues(line_name, channel_id, object_id):
    temp_data = load_temp_data()
    filtered_data = [
        entry for entry in temp_data
        if not (
            entry.get("line_name") == line_name and
            entry.get("channel_id") == channel_id and
            entry.get("object_id") == object_id
        )
    ]
    save_temp_data(filtered_data)
    print(f"🗑️ Removed temp issue for {line_name}.{channel_id} - {object_id}")

def issue_matches_any(issues, pattern):
    return any(re.search(pattern, issue) for issue in issues)

async def on_trigger_change(plc_connection: PLCConnection, line_name: str, channel_id: str, node, val, data):
    if not isinstance(val, bool):
        return

    full_id = f"{line_name}.{channel_id}"

    paths = get_channel_config(line_name, channel_id)
    if not paths:
        print(f"❌ Config not found for {full_id}")
        return

    if val:
        print(f"🟡 Trigger on {full_id} set to TRUE, reading...")
        trigger_timestamps.pop(full_id, None)

        # Write FALSE to esito_scarto_compilato
        esito_conf = paths["esito_scarto_compilato"]
        await asyncio.to_thread(
            plc_connection.write_bool,
            esito_conf["db"], esito_conf["byte"], esito_conf["bit"], False
        )

        # Read the module ID string
        id_mod_conf = paths["id_modulo"]
        object_id = await asyncio.to_thread(
            plc_connection.read_string,
            id_mod_conf["db"], id_mod_conf["byte"], id_mod_conf["length"]
        )
        print('object_id: ', object_id)

        # Read matrix data from the stringatrice configuration
        str_conf = paths["stringatrice"]
        values = [
            await asyncio.to_thread(plc_connection.read_bool, str_conf["db"], str_conf["byte"], i)
            for i in range(str_conf["length"])
        ]
        if not any(values):
            values[0] = True

        stringatrice_index = values.index(True) + 1
        stringatrice = str(stringatrice_index)

        # Read issues flag again
        issues_value = await asyncio.to_thread(
            plc_connection.read_bool,
            esito_conf["db"], esito_conf["byte"], esito_conf["bit"]
        )
        issues_submitted = issues_value is True

        trigger_timestamps[full_id] = datetime.now()
        print(f'trigger_timestamps[{full_id}]: {trigger_timestamps[full_id]}')

        await broadcast(line_name, channel_id, {
            "trigger": True,
            "objectId": object_id,
            "stringatrice": stringatrice,
            "outcome": None,
            "issuesSubmitted": issues_submitted
        })

    else:
        print(f"🟡 Trigger on {full_id} set to FALSE, resetting clients...")
        passato_flags[full_id] = False
        await broadcast(line_name, channel_id, {
            "trigger": False,
            "objectId": None,
            "stringatrice": None,
            "outcome": None,
            "issuesSubmitted": False
        })

async def read_data(
    plc_connection: PLCConnection,
    line_name: str,
    channel_id: str,
    richiesta_ko: bool,
    richiesta_ok: bool,
    data_inizio: datetime | None
):
    try:
        full_id = f"{line_name}.{channel_id}"

        if data_inizio is None:
            data_inizio = datetime.now()

        config = get_channel_config(line_name, channel_id)
        if config is None:
            return None

        data = {}

        # Read Id_Modulo
        id_mod_conf = config["id_modulo"]
        data["Id_Modulo"] = await asyncio.to_thread(
            plc_connection.read_string,
            id_mod_conf["db"], id_mod_conf["byte"], id_mod_conf["length"]
        )

        # Read Id_Utente
        id_utente_conf = config["id_utente"]
        data["Id_Utente"] = await asyncio.to_thread(
            plc_connection.read_string,
            id_utente_conf["db"], id_utente_conf["byte"], id_utente_conf["length"]
        )

        data["DataInizio"] = data_inizio
        data["DataFine"] = datetime.now()
        tempo_ciclo = data["DataFine"] - data_inizio
        data["Tempo_Ciclo"] = str(tempo_ciclo)

        # Set linea_in_lavorazione if needed
        data["Linea_in_Lavorazione"] = [line_name == "Linea1", line_name == "Linea2", False, False, False]

        # Read stringatrice bits if relevant
        str_conf = config["stringatrice"]
        values = [
            await asyncio.to_thread(plc_connection.read_bool, str_conf["db"], str_conf["byte"], i)
            for i in range(str_conf["length"])
        ]
        if not any(values):
            values[0] = True
        data["Lavorazione_Eseguita_Su_Stringatrice"] = values

        data["Compilato_Su_Ipad_Scarto_Presente"] = richiesta_ko

        return data

    except Exception as e:
        logging.error(f"[{full_id}] ❌ Error reading PLC data: {e}")
        return None
   
# ---------------- MYSQL ----------------
DB_SCHEMA = """
Il database contiene le seguenti tabelle:

1 `objects`
- id (PK)
- id_modulo (VARCHAR, UNIQUE)
- creator_station_id (FK to stations.id)
- created_at (DATETIME)

2 `stations`
- id (PK)
- line_id (FK to production_lines.id)
- name (VARCHAR)
- display_name (VARCHAR)
- type (ENUM: 'creator', 'qc', 'rework', 'other')
- config (JSON)

3 `production_lines`
- id (PK)
- name (VARCHAR)
- display_name (VARCHAR)
- description (TEXT)

4 `productions`
- id (PK)
- object_id (FK to objects.id)
- station_id (FK to stations.id)
- start_time (DATETIME)
- end_time (DATETIME)
- esito (INT) -- 1 = OK, 6 = KO
- operator_id (VARCHAR)
- cycle_time (TIME) -- calcolato come differenza tra end_time e start_time
- last_station_id (FK to stations.id, NULLABLE)

5 `defects`
- id (PK)
- category (ENUM: 'Generali', 'Saldatura', 'Disallineamento', 'Mancanza Ribbon', 'Macchie ECA', 'Celle Rotte', 'Altro')

6 `object_defects`
- id (PK)
- production_id (FK to productions.id)
- defect_id (FK to defects.id)
- defect_type (VARCHAR, NULLABLE) -- usato solo per i "Generali"
- stringa (INT, NULLABLE)
- s_ribbon (INT, NULLABLE)
- i_ribbon (INT, NULLABLE)
- ribbon_lato (ENUM: 'F', 'M', 'B', NULLABLE)
- extra_data (JSON, NULLABLE)

7 `station_defects`
- station_id (FK to stations.id)
- defect_id (FK to defects.id)
(Chiave primaria composta: station_id + defect_id)

Regole:
- Usa la tabella `object_defects` per registrare **tutti i difetti** rilevati durante una produzione.
- La colonna `defect_type` è obbligatoria solo per difetti di categoria "Generali".
- Le altre colonne (`stringa`, `s_ribbon`, `i_ribbon`, `ribbon_lato`) vengono compilate **in base alla categoria del difetto**.
- Non inserire, modificare o eliminare dati tramite query SQL generate: sono consentite solo query **di lettura** (SELECT).
"""

async def insert_production_data(data, station_name, connection):
    try:
        with connection.cursor() as cursor:
            id_modulo = data.get("Id_Modulo")
            # Determine the line by checking the 'Linea_in_Lavorazione' list.
            # We assume the list is ordered like [Linea1, Linea2, ...]
            linea_index = data.get("Linea_in_Lavorazione", [False] * 5).index(True) + 1
            actual_line = f"Linea{linea_index}"

            # Get the line_id from production_lines using the line name.
            cursor.execute("SELECT id FROM production_lines WHERE name = %s", (actual_line,))
            line_row = cursor.fetchone()
            if not line_row:
                raise ValueError(f"{actual_line} not found in production_lines")
            line_id = line_row["id"]

            # Get the station's numeric id from stations table using station name and line_id.
            cursor.execute("SELECT id FROM stations WHERE name = %s AND line_id = %s", (station_name, line_id))
            station_row = cursor.fetchone()
            if not station_row:
                raise ValueError(f"Station '{station_name}' not found for {actual_line}")
            real_station_id = station_row["id"]

            # 1️⃣ Insert (or update) into objects table.
            sql_insert_object = """
                INSERT INTO objects (id_modulo, creator_station_id)
                VALUES (%s, %s)
                ON DUPLICATE KEY UPDATE id_modulo = id_modulo
            """
            cursor.execute(sql_insert_object, (id_modulo, real_station_id))

            # 3️⃣ Get object_id
            cursor.execute("SELECT id FROM objects WHERE id_modulo = %s", (id_modulo,))
            object_id = cursor.fetchone()["id"]

                        # 3️⃣ Retrieve last_station_id from stringatrice
            last_station_id = None
            str_flags = data.get("Lavorazione_Eseguita_Su_Stringatrice", [])
            if any(str_flags):
                stringatrice_index = str_flags.index(True) + 1
                stringatrice_name = f"Str{stringatrice_index}"

                # Query station_id for the stringatrice (last station)
                cursor.execute(
                    "SELECT id FROM stations WHERE name = %s AND line_id = %s",
                    (stringatrice_name, line_id)
                )
                str_row = cursor.fetchone()
                if str_row:
                    last_station_id = str_row["id"]


            # 4️⃣ Insert into productions table.
            sql_productions = """
                INSERT INTO productions (
                    object_id, station_id, start_time, end_time, esito, operator_id, last_station_id
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """
            cursor.execute(sql_productions, (
                object_id,
                real_station_id,
                data.get("DataInizio"),
                data.get("DataFine"),
                6 if data.get("Compilato_Su_Ipad_Scarto_Presente") else 1,
                data.get("Id_Utente"),
                last_station_id
            ))
            production_id = cursor.lastrowid

            # 5 Insert defects.
            # Pass the correct line name (actual_line) to get_latest_issues.
            await insert_defects(data, production_id, channel_id=station_name, line_name=actual_line, cursor=cursor)

            connection.commit()
            logging.info(f"Inserted production {production_id} for object {object_id}")
            # Broadcast update (using actual_line for the summary).
            asyncio.create_task(broadcast(actual_line, "summary", {"type": "update_summary"}))
            return production_id

    except Exception as e:
        connection.rollback()
        logging.error(f"Error inserting production data: {e}")
        return None


async def insert_defects(data, production_id, channel_id, line_name, cursor):
    # 1. Get defects mapping from DB.
    cursor.execute("SELECT id, category FROM defects")
    cat_map = {row["category"]: row["id"] for row in cursor.fetchall()}

    # 2. Load the issues from temporary storage using the proper line name.
    issues = get_latest_issues(line_name, channel_id)
    data["issues"] = issues  # Inject into data if needed later.

    # 3. For each issue path, parse and insert a row.
    for path in issues:
        category = detect_category(path)  # e.g. "Generali"
        defect_id = cat_map.get(category, cat_map["Altro"])  # fallback if unknown
        parsed = parse_issue_path(path, category)
        sql = """
            INSERT INTO object_defects (
                production_id, defect_id, defect_type, stringa, s_ribbon, i_ribbon, ribbon_lato
            ) VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(sql, (
            production_id,
            defect_id,
            parsed["defect_type"],
            parsed["stringa"],
            parsed["s_ribbon"],
            parsed["i_ribbon"],
            parsed["ribbon_lato"],
        ))
  
def detect_category(path: str) -> str:
    parts = path.split(".")
    if len(parts) < 5:
        return "Altro"
    return parts[4]  # Now returns the actual category, e.g. "Saldatura"

def parse_issue_path(path: str, category: str):
    """
    Returns a dict with fields:
      {
        "defect_type": ...   # For Generali
        "stringa": ...       # For Saldatura, Disallineamento, Macchie ECA, etc.
        "s_ribbon": ...      # For Saldatura (Pin)
        "i_ribbon": ...      # For Disallineamento/Mancanza Ribbon
        "ribbon_lato": ...   # Possibly 'F','M','B'
      }
    """
    res: Dict[str, Optional[Union[str, int]]] = {
        "defect_type": None,
        "stringa": None,
        "s_ribbon": None,
        "i_ribbon": None,
        "ribbon_lato": None
    }

    # Split
    parts = path.split(".")

    if category == "Generali":
        # last part might be the actual defect, e.g. "Bad Soldering"
        # path might be: "...Generali.Bad Soldering"
        if len(parts) >= 5:
            res["defect_type"] = parts[-1]  # e.g. "Bad Soldering"
        return res

    elif category == "Saldatura":
        # path e.g. "Dati.Esito.Esito_Scarto.Difetti.Saldatura.Stringa[2].Pin[5].M"
        # Let's parse out 'Stringa[2]' => stringa=2
        # 'Pin[5]' => s_ribbon=5
        # 'M' => ribbon_lato='M'
        # That might be parts[4], parts[5], parts[6]
        # e.g. parts[4]="Stringa[2]", parts[5]="Pin[5]", parts[6]="M"
        str_match = re.search(r"Stringa\[(\d+)\]", path)
        pin_match = re.search(r"Pin\[(\d+)\]", path)
        side_match = re.search(r"\ - (F|M|B)$", path)  # the last segment

        if str_match:
            res["stringa"] = int(str_match.group(1))
        if pin_match:
            res["s_ribbon"] = int(pin_match.group(1))
        if side_match:
            res["ribbon_lato"] = side_match.group(1)

    elif category == "Disallineamento":
        # Could be: "...Disallineamento.Stringa[3]" or "...Disallineamento.Ribbon[5].F"
        str_match = re.search(r"Stringa\[(\d+)\]", path)
        if str_match:
            res["stringa"] = int(str_match.group(1))
        else:
            # else check Ribbon
            # e.g. "Disallineamento.Ribbon[5].M"
            rib_match = re.search(r"Ribbon\[(\d+)\]", path)
            side_match = re.search(r"\ - (F|M|B)$", path)
            if rib_match:
                res["i_ribbon"] = int(rib_match.group(1))
            if side_match:
                res["ribbon_lato"] = side_match.group(1)

    elif category == "Mancanza Ribbon":
        # e.g. "Mancanza Ribbon.Ribbon[2].B"
        # i_ribbon=2, ribbon_lato='B'
        rib_match = re.search(r"Ribbon\[(\d+)\]", path)
        side_match = re.search(r"\ - (F|M|B)$", path)
        if rib_match:
            res["i_ribbon"] = int(rib_match.group(1))
        if side_match:
            res["ribbon_lato"] = side_match.group(1)

    elif category == "Macchie ECA":
        # e.g. "Macchie ECA.Stringa[4]"
        str_match = re.search(r"Stringa\[(\d+)\]", path)
        if str_match:
            res["stringa"] = int(str_match.group(1))

    elif category == "Celle Rotte":
        # e.g. "Celle Rotte.Stringa[6]"
        str_match = re.search(r"Stringa\[(\d+)\]", path)
        if str_match:
            res["stringa"] = int(str_match.group(1))

    return res

# ---------------- CONFIG PARSING ----------------
def load_station_configs(file_path):
    config = configparser.ConfigParser()
    config.read(file_path)

    line_configs = {}

    current_line = None
    for section in config.sections():
        if section.upper().startswith("LINEA"):
            current_line = section
            line_configs[current_line] = {
                "PLC": {},
                "PC": {},
                "stations": []
            }

        elif section.upper() == "PLC" and current_line:
            line_configs[current_line]["PLC"]["IP"] = config.get(section, "IP")
            line_configs[current_line]["PLC"]["SLOT"] = config.getint(section, "SLOT")

        elif section.upper() == "PC" and current_line:
            line_configs[current_line]["PC"]["IP"] = config.get(section, "IP")
            line_configs[current_line]["PC"]["PORT"] = config.getint(section, "PORT")

        elif section.startswith("M") and current_line:
            line_configs[current_line]["stations"].append(section)

    return line_configs

# ---------------- BACKGROUND TASK ----------------
def make_status_callback(full_station_id: str):
    async def callback(status):
        try:
            line_name, channel_id = full_station_id.split(".")
            await broadcast(line_name, channel_id, {"plc_status": status})
        except Exception as e:
            logging.error(f"❌ Failed to send PLC status for {full_station_id}: {e}")
    return callback

async def background_task(plc_connection: PLCConnection, full_station_id: str):
    print(f"[{full_station_id}] Starting background task.")
    prev_trigger = False

    line_name, channel_id = full_station_id.split(".")

    while True:
        try:
            # Ensure connection is alive or try reconnect
            if not plc_connection.connected or not plc_connection.is_connected():
                print(f"⚠️ PLC disconnected for {full_station_id}, attempting reconnect...")
                await asyncio.to_thread(plc_connection.reconnect, retries=3, delay=5)
                await asyncio.sleep(10)
                continue  # Retry after delay

            paths = get_channel_config(line_name, channel_id)
            if not paths:
                logging.error(f"❌ Invalid line/channel: {line_name}.{channel_id}")
                await asyncio.sleep(1)
                continue  # Skip this cycle if config not found

            trigger_conf = paths["trigger"]
            trigger_value = await asyncio.to_thread(
                plc_connection.read_bool,
                trigger_conf["db"], trigger_conf["byte"], trigger_conf["bit"]
            )


            if trigger_value is None:
                raise Exception("Trigger read returned None")

            if trigger_value != prev_trigger:
                prev_trigger = trigger_value
                await on_trigger_change(plc_connection, line_name, channel_id, None, trigger_value, None)

            # Outcome check
            paths = get_channel_config(line_name, channel_id)
            if not paths:
                logging.error(f"❌ Missing config for {line_name}.{channel_id}")
                await asyncio.sleep(1)
                continue  # Or return / skip, depending on context

            # Now you're safe to use it:
            fb_conf = paths["fine_buona"]
            fs_conf = paths["fine_scarto"]
            fine_buona = await asyncio.to_thread(plc_connection.read_bool, fb_conf["db"], fb_conf["byte"], fb_conf["bit"])
            fine_scarto = await asyncio.to_thread(plc_connection.read_bool, fs_conf["db"], fs_conf["byte"], fs_conf["bit"])


            if fine_buona is None or fine_scarto is None:
                raise Exception("Outcome read returned None")

            if (fine_buona or fine_scarto) and not passato_flags[full_station_id]:
                print(f"[{full_station_id}] Processing data (trigger detected)")
                data_inizio = trigger_timestamps.get(full_station_id)
                result = await read_data(plc_connection, line_name, channel_id,
                                         #richiesta_ok=fine_buona,
                                         #richiesta_ko=fine_scarto,
                                         richiesta_ok=False,
                                         richiesta_ko=True,
                                         data_inizio=data_inizio)
                if result:
                    passato_flags[full_station_id] = True
                    print(f"[{full_station_id}] ✅ Inserting into MySQL...")
                    await insert_production_data(result, channel_id, mysql_connection)
                    print(f"[{full_station_id}] 🟢 Data inserted successfully!")
                    remove_temp_issues(line_name, channel_id, result.get("Id_Modulo"))

            await asyncio.sleep(1)

        except Exception as e:
            logging.error(f"[{full_station_id}] 🔴 Error in background task: {str(e)}")
            await asyncio.to_thread(plc_connection.reconnect, retries=3, delay=5)
            await asyncio.sleep(5)

# ---------------- WEB SOCKET ----------------
@app.websocket("/ws/summary/{line_name}")
async def websocket_summary(websocket: WebSocket, line_name: str):
    await websocket.accept()
    key = f"{line_name}.summary"
    print(f"📊 Dashboard summary client connected for {line_name}")

    subscriptions.setdefault(key, set()).add(websocket)

    try:
        while True:
            await websocket.receive_text()  # Or just keep alive
    except WebSocketDisconnect:
        print(f"❌ Dashboard summary client for {line_name} disconnected")
        subscriptions[key].remove(websocket)

@app.websocket("/ws/{line_name}/{channel_id}")
async def websocket_endpoint(websocket: WebSocket, line_name: str, channel_id: str):
    full_id = f"{line_name}.{channel_id}"

    if get_channel_config(line_name, channel_id) is None:
        await websocket.close()
        print(f"❌ Invalid channel config for {full_id}")
        return

    await websocket.accept()
    await websocket.send_json({"handshake": True})
    print(f"📲 Client subscribed to {full_id}")

    subscriptions.setdefault(full_id, set()).add(websocket)
    plc_connection = plc_connections.get(full_id)

    if not plc_connection:
        print(f"❌ No PLC connection found for {full_id}.")
        await websocket.close()
        return

    # Check connection status before sending initial state
    if not plc_connection.connected or not plc_connection.is_connected():
        print(f"⚠️ PLC for {full_id} is disconnected. Attempting reconnect for WebSocket...")
        if not plc_connection.reconnect(retries=3, delay=5):
            print(f"❌ Failed to reconnect PLC for {full_id}. Closing socket.")
            await websocket.close()
            return
        else:
            print(f"✅ PLC reconnected for {full_id}!")

    await send_initial_state(websocket, channel_id, plc_connection, line_name)

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        print(f"⚠️ Client disconnected from {full_id}")
    finally:
        subscriptions[full_id].remove(websocket)


# ---------------- ROUTES ----------------
            
@app.get("/api/plc_status")
async def plc_status():
    statuses = {}

    for full_id, plc_conn in plc_connections.items():
        try:
            line_name, channel_id = full_id.split(".")
        except ValueError:
            continue  # Skip malformed keys, just in case

        if line_name not in statuses:
            statuses[line_name] = {}

        statuses[line_name][channel_id] = "CONNECTED" if plc_conn.connected else "DISCONNECTED"

    return statuses

@app.post("/api/set_issues")
async def set_issues(request: Request):
    data = await request.json()
    line_name = data.get("line_name")
    channel_id = data.get("channel_id")
    object_id = data.get("object_id")
    issues = data.get("issues", [])

    if not line_name or not channel_id or not object_id or not issues:
        return JSONResponse(status_code=400, content={"error": "Missing data"})

    full_id = f"{line_name}.{channel_id}"
    print('raw issues received:', issues)

    # Load existing data
    existing_data = load_temp_data()

    # Append new data
    existing_data.append({
        "line_name": line_name,
        "channel_id": channel_id,
        "object_id": object_id,
        "issues": issues
    })

    # Save updated data
    save_temp_data(existing_data)
    print('issues saved:', existing_data)

    plc_connection = plc_connections.get(full_id)
    if not plc_connection:
        return JSONResponse(status_code=404, content={"error": f"No PLC connection for {full_id}."})

    paths = get_channel_config(line_name, channel_id)
    if not paths:
        return JSONResponse(status_code=404, content={"error": "Channel mapping not found"})

    target = paths.get("esito_scarto_compilato")
    if not target:
        return JSONResponse(status_code=404, content={"error": "esito_scarto_compilato not found in mapping"})

    await asyncio.to_thread(plc_connection.write_bool, target["db"], target["byte"], target["bit"], True)

    return {"status": "ok"}

@app.get("/api/get_issues")
async def get_selected_issues(line_name: str, channel_id: str, object_id: str):
    if not line_name or not channel_id or not object_id:
        return JSONResponse(status_code=400, content={"error": "Missing line_name, channel_id, or object_id"})

    # Load issues from temp storage
    temp_data = load_temp_data()

    # Filter issues based on line_name + channel_id + object_id
    matching_entry = next(
        (
            entry for entry in temp_data
            if entry.get("line_name") == line_name and
               entry.get("channel_id") == channel_id and
               entry.get("object_id") == object_id
        ),
        None
    )

    if not matching_entry:
        return {"selected_issues": []}  # Return empty if not found

    return {"selected_issues": matching_entry["issues"]}

@app.post("/api/set_outcome")
async def set_outcome(request: Request):
    data = await request.json()
    line_name = data.get("line_name")
    channel_id = data.get("channel_id")
    object_id = data.get("object_id")
    outcome = data.get("outcome")  # "buona" or "scarto"

    if not line_name or not channel_id or outcome not in ["buona", "scarto"]:
        return JSONResponse(status_code=400, content={"error": "Invalid data"})

    # Get channel config
    config = get_channel_config(line_name, channel_id)
    if not config:
        return JSONResponse(status_code=404, content={"error": "Channel not found"})

    plc_connection = plc_connections.get(f"{line_name}.{channel_id}")
    if not plc_connection:
        return JSONResponse(status_code=404, content={"error": "PLC connection not found"})

    # Read current object_id from PLC
    read_conf = config["id_modulo"]
    current_object_id = await asyncio.to_thread(
        plc_connection.read_string,
        read_conf["db"], read_conf["byte"], read_conf["length"]
    )

    if str(current_object_id) != str(object_id):
        return JSONResponse(status_code=409, content={"error": "Stale object, already processed or expired."})

    # Optional: Write outcome back to PLC if needed (currently commented out)
    # outcome_conf = config["fine_buona"] if outcome == "buona" else config["fine_scarto"]
    # await asyncio.to_thread(
    #     plc_connection.write_bool,
    #     outcome_conf["db"], outcome_conf["byte"], outcome_conf["bit"], True
    # )

    print(f"✅ Outcome '{outcome.upper()}' written for object {object_id} on {line_name}.{channel_id}")
    await broadcast(line_name, channel_id, {
        "trigger": None,
        "objectId": object_id,
        "outcome": outcome
    })

    return {"status": "ok"}

@app.get("/api/issues/{line_name}/{channel_id}")
async def get_issue_tree(
    line_name: str,
    channel_id: str,
    path: str = Query("Dati.Esito.Esito_Scarto.Difetti")
):
    # Validate channel
    config = get_channel_config(line_name, channel_id)
    if not config:
        return JSONResponse(status_code=404, content={"error": "Invalid line or channel"})

    # Traverse ISSUE_TREE using the dot-separated path
    current_node = ISSUE_TREE
    if path:
        for part in path.split("."):
            current_node = current_node.get(part)
            if current_node is None:
                return JSONResponse(status_code=404, content={"error": f"Path '{path}' not found"})

    items = []
    for name, child in current_node.items():
        item_type = "folder" if child else "leaf"
        items.append({"name": name, "type": item_type})

    return {"items": items}

@app.get("/api/overlay_config")
async def get_overlay_config(
    path: str,
    line_name: str = Query(...),
    station: str = Query(...)
):
    config_file = f"C:/IX-Monitor/images/{line_name}/{station}/overlay_config.json"
    print(f"🔍 Requested overlay config for path: '{path}' (line: {line_name}, station: {station})")
    print(f"📄 Looking for config file at: {config_file}")

    if not os.path.exists(config_file):
        print(f"❌ Config file not found.")
        return JSONResponse(status_code=417, content={"error": f"Overlay config not found for {line_name}/{station}"})

    try:
        with open(config_file, "r") as f:
            all_configs = json.load(f)
            print(f"✅ Loaded overlay_config.json with keys: {list(all_configs.keys())}")
    except json.JSONDecodeError as e:
        print(f"❌ JSON decode error: {e}")
        all_configs = {}

    for image_name, config in all_configs.items():
        config_path = config.get("path", "")
        print(f"➡️ Checking config: image = '{image_name}', path = '{config_path}'")

        if config_path.lower() == path.lower():
            image_url = f"http://localhost:8000/images/{line_name}/{station}/{image_name}"
            print(f"✅ MATCH FOUND! Returning image: {image_url}")
            return {
                "image_url": image_url,
                "rectangles": config.get("rectangles", [])
            }

    print(f"⚠️ No matching path found. Returning fallback with empty image URL.")
    return {
        "image_url": "",
        "rectangles": []
    }

@app.post("/api/update_overlay_config")
async def update_overlay_config(request: Request):
    data = await request.json()
    path = data.get("path")
    new_rectangles = data.get("rectangles")
    line_name = data.get("line_name")
    station = data.get("station")

    if not path or not new_rectangles or not line_name or not station:
        return JSONResponse(status_code=400, content={"error": "Missing path, rectangles, line_name, or station"})

    config_file = f"C:/IX-Monitor/images/{line_name}/{station}/overlay_config.json"

    if not os.path.exists(config_file):
        return JSONResponse(status_code=404, content={"error": f"Config file not found for {line_name}/{station}"})

    with open(config_file, "r") as f:
        config = json.load(f)

    image_to_update = None
    for image_name, entry in config.items():
        if entry.get("path") == path:
            image_to_update = image_name
            break

    if not image_to_update:
        return JSONResponse(status_code=404, content={"error": "Path not found in config"})

    config[image_to_update]["rectangles"] = new_rectangles

    with open(config_file, "w") as f:
        json.dump(config, f, indent=4)

    return {"status": "updated", "image": image_to_update}

@app.get("/api/available_overlay_paths")
async def available_overlay_paths(
    line_name: str = Query(...),
    station: str = Query(...)
):
    config_file = f"C:/IX-Monitor/images/{line_name}/{station}/overlay_config.json"

    if not os.path.exists(config_file):
        return JSONResponse(status_code=404, content={"error": f"Config file not found for {line_name}/{station}"})

    with open(config_file, "r") as f:
        all_configs = json.load(f)

    result = []
    for image_name, config in all_configs.items():
        path = config.get("path")
        if path:
            result.append({
                "image": image_name,
                "path": path
            })
    return result

@app.get("/api/productions_summary")
async def productions_summary(
    date: str = Query(default=None),
    from_date: str = Query(default=None, alias="from"),
    to_date: str = Query(default=None, alias="to"),
    line_name: str = Query(default=None),  # Optional filter by line
    turno: int = Query(default=None),      # New turno parameter (1, 2, 3)
):
    global mysql_connection
    try:
        assert mysql_connection is not None
        with mysql_connection.cursor() as cursor:

            if from_date and to_date:
                where_clause = "WHERE DATE(data_fine) BETWEEN %s AND %s"
                params = (from_date, to_date)
            elif date:
                if turno and turno == 3:
                    # For Shift 3, use a datetime range: from 22:00 on the selected date
                    # to 05:59:59 on the next day.
                    start_dt = f"{date} 22:00:00"
                    end_dt = (datetime.strptime(date, "%Y-%m-%d") + timedelta(days=1)).strftime("%Y-%m-%d 05:59:59")
                    where_clause = "WHERE data_fine BETWEEN %s AND %s"
                    params = (start_dt, end_dt)
                else:
                    where_clause = "WHERE DATE(data_fine) = %s"
                    params = (date,)
            else:
                return JSONResponse(status_code=400, content={"error": "Missing 'date' or 'from' and 'to'"})

            if turno:
                # Define the time range for each turno
                turno_times = {
                    1: ("06:00:00", "13:59:59"),
                    2: ("14:00:00", "21:59:59"),
                    3: ("22:00:00", "05:59:59"),
                }

                if turno not in turno_times:
                    return JSONResponse(
                        status_code=400,
                        content={"error": "Invalid turno number (must be 1, 2, or 3)"}
                    )

                start_time, end_time = turno_times[turno]

                if turno == 3:
                    if date:
                        shift_day = datetime.strptime(date, "%Y-%m-%d")
                        next_day = shift_day + timedelta(days=1)

                        where_clause += """
                            AND (
                                (DATE(data_fine) = %s AND TIME(data_fine) >= '22:00:00')
                                OR
                                (DATE(data_fine) = %s AND TIME(data_fine) <= '05:59:59')
                            )
                        """
                        params += (shift_day.strftime("%Y-%m-%d"), next_day.strftime("%Y-%m-%d"))

                    elif from_date and to_date:
                        # Keep WHERE DATE(data_fine) BETWEEN from_date AND to_date
                        # Add time-based filter for turno 3
                        where_clause += """
                            AND (
                                TIME(data_fine) >= '22:00:00'
                                OR TIME(data_fine) <= '05:59:59'
                            )
                        """

                    else:
                        return JSONResponse(
                            status_code=400,
                            content={"error": "Missing 'date' or 'from' and 'to'"}
                        )

                else:
                    # Turno 1 or 2 — simple time filter
                    where_clause += " AND TIME(data_fine) BETWEEN %s AND %s"
                    params += (start_time, end_time)

            if line_name:
                try:
                    line_number = int(line_name.replace("Linea", ""))  # Extract numeric part from "Linea1"
                    where_clause += " AND linea = %s"
                    params += (line_number,)
                except ValueError:
                    return JSONResponse(status_code=400, content={"error": "Invalid line_name format"})

            # --- Summary per station ---
            cursor.execute(f"""
                SELECT
                    station,
                    SUM(CASE WHEN esito = 1 THEN 1 ELSE 0 END) AS good_count,
                    SUM(CASE WHEN esito = 6 THEN 1 ELSE 0 END) AS bad_count,
                    SEC_TO_TIME(AVG(TIME_TO_SEC(tempo_ciclo))) AS avg_cycle_time
                FROM productions
                {where_clause}
                GROUP BY station
            """, params)

            stations = {}
            for row in cursor.fetchall():
                stations[row['station']] = {
                    "good_count": row['good_count'],
                    "bad_count": row['bad_count'],
                    "avg_cycle_time": str(row['avg_cycle_time']),
                    "last_cycle_time": "00:00:00"
                }
            
            print('stations: ', stations)

            # Fill missing stations (for visual consistency)
            all_station_names = [
                station for line, stations in CHANNELS.items()
                if line == line_name or line_name is None
                for station in stations
            ]

            for station in all_station_names:
                stations.setdefault(station, {
                    "good_count": 0,
                    "bad_count": 0,
                    "avg_cycle_time": "00:00:00",
                    "last_cycle_time": "00:00:00"
                })

                        # Fetch defect summary for each defect type
            def fetch_defect_summary(table, label):
                cursor.execute(f"""
                    SELECT p.station, COUNT(DISTINCT p.id) AS defect_count
                    FROM {table} t
                    JOIN productions p ON p.id = t.production_id
                    {where_clause} AND t.scarto = 1 AND p.esito = 6
                    GROUP BY p.station
                """, params)
                for row in cursor.fetchall():
                    stations[row['station']].setdefault("defects", {})[label] = int(row['defect_count'])

            fetch_defect_summary("ribbon", "Mancanza Ribbon")
            fetch_defect_summary("saldatura", "Saldatura")
            fetch_defect_summary("disallineamento_stringa", "Disallineamento")
            fetch_defect_summary("generali", "Generali")

            # Now calculate "KO Generico" for each station
            for station, data in stations.items():
                bad_count = int(data["bad_count"])
                defects = data.get("defects", {})
                total_defects = sum(defects.values())
                generic = bad_count - total_defects
                if generic > 0:
                    stations[station].setdefault("defects", {})["Generico"] = generic


            # Last cycle time for single-day requests
            if date:
                # Adding the last object ID, esito, and cycle times for the station
                cursor.execute("""
                    SELECT station, id_modulo, esito, tempo_ciclo, data_inizio, data_fine
                    FROM productions
                    WHERE DATE(data_fine) = %s
                    ORDER BY data_fine DESC
                """, (date,))
                seen_stations = set()
                for row in cursor.fetchall():
                    station = row['station']
                    if station not in seen_stations and station in stations:
                        stations[station]["last_object"] = row["id_modulo"]  # Last Object ID
                        stations[station]["last_esito"] = row["esito"]  # Esito
                        stations[station]["last_cycle_time"] = str(row["tempo_ciclo"])  # Last Cycle Time
                        stations[station]["last_in_time"] = str(row["data_inizio"])  # Last Start Time (data_inizio)
                        stations[station]["last_out_time"] = str(row["data_fine"])  # Last End Time (data_fine)
                        seen_stations.add(station)

            good_count = sum(s["good_count"] for s in stations.values())
            bad_count = sum(s["bad_count"] for s in stations.values())

            return {
                "good_count": good_count,
                "bad_count": bad_count,
                "stations": stations,
            }

    except Exception as e:
        logging.error(f"MySQL Error: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})

# ---------------- MAIN ----------------
if __name__ == "__main__":
   uvicorn.run(app, host="0.0.0.0", port=8000)