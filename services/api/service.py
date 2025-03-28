import asyncio
import configparser
import datetime
import json
import logging
import os
import time
from fastapi import FastAPI, Query, WebSocket, WebSocketDisconnect, Request
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
                    "Saldatura": {
                        "Stringa_F": {
                            f"Stringa_F[{i}]": {
                                f"String_Ribbon[{j}]": None for j in range(1, 11)
                            } for i in range(1, 7)
                        },
                        "Stringa_M_F": {
                            f"Stringa_M_F[{i}]": {
                                f"Saldatura[{j}]": None for j in range(1, 11)
                            } for i in range(1, 7)
                        },
                        "Stringa_M_B": {
                            f"Stringa_M_B[{i}]": {
                                f"Saldatura[{j}]": None for j in range(1, 11)
                            } for i in range(1, 7)
                        },
                        "Stringa_B": {
                            f"Stringa_B[{i}]": {
                                f"Saldatura[{j}]": None for j in range(1, 11)
                            } for i in range(1, 7)
                        },
                    },
                    "Disallineamento": {
                        "Ribbon": {
                        "Ribbon_Stringa_F": {
                            f"Ribbon_Stringa_F[{i}]": None for i in range(1, 13)
                        },
                        "Ribbon_Stringa_M": {
                            f"Ribbon_Stringa_M[{i}]": None for i in range(1, 13)
                        },
                        "Ribbon_Stringa_B": {
                            f"Ribbon_Stringa_B[{i}]": None for i in range(1, 13)
                        }
                        },
                        "Stringa": {
                            f"Stringa[{i}]": None for i in range(1, 13)
                        },
                    },
                    "Mancanza_Ribbon": {
                        "Ribbon": {
                            "Ribbon_Stringa_F": {
                                f"Ribbon_Stringa_F[{i}]": None for i in range(1, 13)
                            },
                            "Ribbon_Stringa_M": {
                                f"Ribbon_Stringa_M[{i}]": None for i in range(1, 13)
                            },
                            "Ribbon_Stringa_B": {
                                f"Ribbon_Stringa_B[{i}]": None for i in range(1, 13)
                            }
                        }
                    },
                    "Generali": {
                        "Non Lavorato Poe Scaduto": {},
                        "Non Lavorato da Telecamere": {},
                        "Materiale Esterno su Celle": {},
                        "Bad Soldering": {},
                        "Macchie ECA": {},
                        "Cella Rotta": {}
                    }
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
        #password="Master36!",
        database="production_data",
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

def fill_1d(length, value):
    return [value] * length

def fill_2d(rows, cols, value):
    return [[value] * cols for _ in range(rows)]

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

def build_matrix_from_raw(issues, category, row_count, col_count):
    """
    Matches paths like:
    Dati.Esito.Esito_Scarto.Difetti.Saldatura.<category>.<category>[i].Saldatura[j]
    For example: Dati.Esito.Esito_Scarto.Difetti.Saldatura.Stringa_M_B.Stringa_M_B[1].Saldatura[1]
    """
    return [
        [
            issue_matches_any(issues, fr"{category}\.{category}\[{i+1}\]\.Saldatura\[{j+1}\]")
            for j in range(col_count)
        ]
        for i in range(row_count)
    ]

def build_ribbon_array(issues, label, count):
    """
    Matches entries like:
    Dati.Esito.Esito_Scarto.Difetti.Saldatura.<label>.<label>[i]
    Adjust the pattern as needed for your new structure.
    """
    return [
        issue_matches_any(issues, fr"{label}\.{label.split('.')[-1]}\[{i+1}\]")
        for i in range(count)
    ]

def build_cell_matrix(issues, category, row_count, col_count):
    # Adjust pattern to include the ".Stringa.Stringa" segment as seen in your raw issues
    return [
        [
            issue_matches_any(issues, fr"{category}\.Stringa\.Stringa\[{i+1}\]\.Cella\[{j+1}\]")
            for j in range(col_count)
        ]
        for i in range(row_count)
    ]

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

        trigger_timestamps[full_id] = datetime.datetime.now()
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
    data_inizio: datetime.datetime | None
):
    try:
        full_id = f"{line_name}.{channel_id}"

        if data_inizio is None:
            logging.warning(f"[{full_id}] data_inizio is None, assigning current time as fallback.")
            data_inizio = datetime.datetime.now()

        config = get_channel_config(line_name, channel_id)
        if config is None:
            logging.error(f"[{full_id}] ❌ Config not found.")
            return None

        data = {}

        # Read Id_Modulo string
        id_mod_conf = config["id_modulo"]
        data["Id_Modulo"] = await asyncio.to_thread(
            plc_connection.read_string,
            id_mod_conf["db"], id_mod_conf["byte"], id_mod_conf["length"]
        )

        # Read Id_Utente string
        id_utente_conf = config["id_utente"]
        data["Id_Utente"] = await asyncio.to_thread(
            plc_connection.read_string,
            id_utente_conf["db"], id_utente_conf["byte"], id_utente_conf["length"]
        )

        data["DataInizio"] = data_inizio
        data["DataFine"] = datetime.datetime.now()
        tempo_ciclo = data["DataFine"] - data_inizio
        data["Tempo_Ciclo"] = str(tempo_ciclo)

        # Update this logic if needed
        data["Linea_in_Lavorazione"] = [line_name == "Linea1", line_name == "Linea2", False, False, False]

        # Read stringatrice info
        str_conf = config["stringatrice"]
        values = [
            await asyncio.to_thread(plc_connection.read_bool, str_conf["db"], str_conf["byte"], i)
            for i in range(str_conf["length"])
        ]
        if not any(values):
            values[0] = True
        data["Lavorazione_Eseguita_Su_Stringatrice"] = values

        data["Compilato_Su_Ipad_Scarto_Presente"] = richiesta_ko

        if richiesta_ok:
            # All issue fields set to False
            data["Stringa_F"] = fill_2d(6, 10, False)
            data["Stringa_M_F"] = fill_2d(6, 10, False)
            data["Stringa_M_B"] = fill_2d(6, 10, False)
            data["Stringa_B"] = fill_2d(6, 10, False)
            data["Disallineamento"] = {
                "Ribbon_Stringa_F": fill_1d(12, False),
                "Ribbon_Stringa_M": fill_1d(12, False),
                "Ribbon_Stringa_B": fill_1d(12, False)
            }
            data["Stringa"] = fill_1d(12, False)
            data["Mancanza_Ribbon"] = {
                "Ribbon_Stringa_F": fill_1d(12, False),
                "Ribbon_Stringa_M": fill_1d(12, False),
                "Ribbon_Stringa_B": fill_1d(12, False)
            }
            generali = {
                "Non_Lavorato_Poe_Scaduto": False,
                "Non_Lavorato_da_Telecamere": False,
                "Materiale_Esterno_su_Celle": False,
                "Bad_Soldering": False,
                "Macchie ECA": False,
                "Cella_Rotta": False
            }
            for i in range(4, 16):
                generali[f"Non_Lavorato_Riserva_{i}"] = False
            data["Generali"] = generali

        elif richiesta_ko:
            issues = get_latest_issues(line_name, channel_id)
            print('issues:', issues)

            data["Stringa_F"] = build_matrix_from_raw(issues, "Stringa_F", 6, 10)
            data["Stringa_M_F"] = build_matrix_from_raw(issues, "Stringa_M_F", 6, 10)
            data["Stringa_M_B"] = build_matrix_from_raw(issues, "Stringa_M_B", 6, 10)
            data["Stringa_B"] = build_matrix_from_raw(issues, "Stringa_B", 6, 10)

            data["Disallineamento"] = {
                "Ribbon_Stringa_F": build_ribbon_array(issues, "Ribbon_Stringa_F", 12),
                "Ribbon_Stringa_M": build_ribbon_array(issues, "Ribbon_Stringa_M", 12),
                "Ribbon_Stringa_B": build_ribbon_array(issues, "Ribbon_Stringa_B", 12),
            }

            data["Stringa"] = build_ribbon_array(issues, "Stringa", 12)

            data["Mancanza_Ribbon"] = {
                "Ribbon_Stringa_F": build_ribbon_array(issues, "Mancanza_Ribbon.Ribbon_Stringa_F", 12),
                "Ribbon_Stringa_M": build_ribbon_array(issues, "Mancanza_Ribbon.Ribbon_Stringa_M", 12),
                "Ribbon_Stringa_B": build_ribbon_array(issues, "Mancanza_Ribbon.Ribbon_Stringa_B", 12),
            }

            generali = {}
            for general_issue in [
                "Non Lavorato Poe Scaduto",
                "Non Lavorato da Telecamere",
                "Materiale Esterno su Celle",
                "Bad Soldering",
                "Macchie ECA",
                "Cella Rotta"
            ]:
                generali[general_issue.replace(" ", "_")] = any(general_issue in issue for issue in issues)

            for i in range(4, 16):
                label = f"Non Lavorato Riserva {i}"
                generali[label.replace(" ", "_")] = any(label in issue for issue in issues)

            data["Generali"] = generali

        print(f"[{full_id}] ✅ Data read successfully.")
        return data

    except Exception as e:
        logging.error(f"[{full_id}] ❌ Error reading PLC data: {e}")
        return None
   
# ---------------- MYSQL ----------------
DB_SCHEMA = """
Il database contiene le seguenti tabelle:

1 `productions`
- id (PK)
- linea (INT)
- station (ENUM: 'M308', 'M309', 'M326')
- stringatrice (INT)
- id_modulo (VARCHAR)
- id_utente (VARCHAR)
- data_inizio (DATETIME)
- data_fine (DATETIME)
- esito (BOOLEAN)
- tempo_ciclo (TIME)

2 `ribbon`
- id (PK)
- production_id (FK to productions.id)
- tipo_difetto (ENUM: 'Disallineamento', 'Mancanza')
- tipo (ENUM: 'F', 'M', 'B')
- position (INT)
- scarto (BOOLEAN)

3 `saldatura`
- id (PK)
- production_id (FK)
- category ENUM('Stringa_F', 'Stringa_M_F', 'Stringa_M_B', 'Stringa_B')
- stringa (INT)
- ribbon (INT)
- scarto (BOOLEAN)

4 `disallineamento_stringa`
- id (PK)
- production_id (FK)
- position (INT)
- scarto (BOOLEAN)

5 `lunghezza_string_ribbon`
- id (PK)
- production_id (FK)
- position (INT)
- scarto (BOOLEAN)

6 `generali`
- id (PK)
- production_id (FK)
- tipo_difetto ENUM('Non Lavorato Poe Scaduto', 'Non Lavorato da Telecamere', 'Materiale Esterno su Celle', 'Bad Soldering', 'Macchie ECA', 'Cella Rotta')
- scarto (BOOLEAN)

Regole:
- Chiedi chiarimenti all'utente se la richiesta è vaga.
- Genera solo query sicure e leggibili.
- Non generare query che modificano il database (NO INSERT, UPDATE, DELETE).
"""

async def insert_production_data(data, line, station, connection):
    """
    Inserts the PLC data into the normalized MySQL tables.
    """
    try:
        with connection.cursor() as cursor:
            # --- 1. Insert into productions table ---
            # Determine the active 'linea'
            for idx, val in enumerate(data.get("Linea_in_Lavorazione", [])):
                if val:  # Only save True
                    linea = idx + 1
                    break  # exit after the first true value
            
            # Determine the active 'stringatrice'
            for idx, val in enumerate(data.get("Lavorazione_Eseguita_Su_Stringatrice", [])):
                if val:  # Only save True
                    stringatrice = idx + 1
                    break

            sql_productions = """
                INSERT INTO productions 
                    (linea, station, stringatrice, id_modulo, id_utente, data_inizio, data_fine, esito, tempo_ciclo)
                VALUES 
                    (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            cursor.execute(sql_productions, (
                linea,
                station,
                stringatrice,
                data.get("Id_Modulo"),
                data.get("Id_Utente"),
                data.get("DataInizio"),
                data.get("DataFine"),
                6 if data.get("Compilato_Su_Ipad_Scarto_Presente") else 1,  # 5 = OK_Operatore
                data.get("Tempo_Ciclo"),
            ))
            production_id = cursor.lastrowid

            # --- 2. Insert into saldatura ---
            for category in ['Stringa_F', 'Stringa_M_F', 'Stringa_M_B', 'Stringa_B']:
                matrix = data.get(category, [])
                for row_index, row in enumerate(matrix):
                    for col_index, val in enumerate(row):
                        if val:  # Only save True entries
                            sql = """
                                INSERT INTO saldatura (production_id, category, stringa, ribbon, scarto)
                                VALUES (%s, %s, %s, %s, %s)
                            """
                            cursor.execute(sql, (production_id, category, row_index + 1, col_index + 1, True))

            # --- 3. Insert into disallineamento_stringa ---
            for idx, val in enumerate(data.get("Stringa", [])):
                if val:  # Only insert if True
                    sql = "INSERT INTO disallineamento_stringa (production_id, position, scarto) VALUES (%s, %s, %s)"
                    cursor.execute(sql, (production_id, idx + 1, True))

            # --- 4. Insert into generali ---
            generali = data.get("Generali", {})
            for flag_name, val in generali.items():
                if val:
                    # Replace underscores with spaces to match the ENUM values in your schema
                    defect_type = flag_name.replace("_", " ")
                    sql = "INSERT INTO generali (production_id, tipo_difetto, scarto) VALUES (%s, %s, %s)"
                    cursor.execute(sql, (production_id, defect_type, True))

            # --- 5. Insert into ribbon ---
            # For Disallineamento defects
            dis = data.get("Disallineamento", {})
            for ribbon_area in ['Ribbon_Stringa_F', 'Ribbon_Stringa_M', 'Ribbon_Stringa_B']:
                arr = dis.get(ribbon_area, [])
                for pos, val in enumerate(arr):
                    if val:
                        # Extract the type (F, M, B) from the key (e.g. "Ribbon_Stringa_F")
                        tipo_letter = ribbon_area.split("_")[-1]
                        sql = """
                            INSERT INTO ribbon (production_id, tipo_difetto, tipo, position, scarto)
                            VALUES (%s, %s, %s, %s, %s)
                        """
                        cursor.execute(sql, (production_id, 'Disallineamento', tipo_letter, pos + 1, True))

            # For Mancanza defects
            mr = data.get("Mancanza_Ribbon", {})
            for ribbon_area in ['Ribbon_Stringa_F', 'Ribbon_Stringa_M', 'Ribbon_Stringa_B']:
                arr = mr.get(ribbon_area, [])
                for pos, val in enumerate(arr):
                    if val:
                        tipo_letter = ribbon_area.split("_")[-1]
                        sql = """
                            INSERT INTO ribbon (production_id, tipo_difetto, tipo, position, scarto)
                            VALUES (%s, %s, %s, %s, %s)
                        """
                        cursor.execute(sql, (production_id, 'Mancanza', tipo_letter, pos + 1, True))

            # Commit the transaction if all inserts are successful
            connection.commit()
            logging.info(f"Production data inserted with id: {production_id}")
            asyncio.create_task(broadcast(line, "summary", {"type": "update_summary"}))
            return production_id
        

    except Exception as e:
        connection.rollback()
        logging.error(f"Error inserting production data: {e}")
        return None

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
                                         richiesta_ok=fine_buona,
                                         richiesta_ko=fine_scarto,
                                         data_inizio=data_inizio)
                if result:
                    passato_flags[full_station_id] = True
                    print(f"[{full_station_id}] ✅ Inserting into MySQL...")
                    await insert_production_data(result, line_name, channel_id, mysql_connection)
                    print(f"[{full_station_id}] 🟢 Data inserted successfully!")
                    await asyncio.to_thread(plc_connection.write_bool, fb_conf["db"], fb_conf["byte"], fb_conf["bit"], False)
                    await asyncio.to_thread(plc_connection.write_bool, fs_conf["db"], fs_conf["byte"], fs_conf["bit"], False)
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

    if not os.path.exists(config_file):
        return JSONResponse(status_code=417, content={"error": f"Overlay config not found for {line_name}/{station}"})

    with open(config_file, "r") as f:
        all_configs = json.load(f)

    for image_name, config in all_configs.items():
        if config.get("path", "").lower() == path.lower():
            return {
                "image_url": f"http://192.168.0.10:8000/images/{line_name}/{station}/{image_name}",
                "rectangles": config.get("rectangles", [])
            }

    return JSONResponse(status_code=404, content={"error": f"No config matches the provided path '{path}'"})


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

@app.post("/api/simulate_trigger")
async def simulate_trigger(request: Request):
    data = await request.json()
    line_name = data.get("line_name")
    channel_id = data.get("channel_id")

    paths = get_channel_config(line_name, channel_id)
    if not paths:
        return JSONResponse(status_code=404, content={"error": "Invalid line or channel"})

    conf = paths["trigger"]
    plc_conn = plc_connections.get(channel_id)
    if not plc_conn:
        return JSONResponse(status_code=404, content={"error": "PLC connection not found"})

    current_value = await asyncio.to_thread(plc_conn.read_bool, conf["db"], conf["byte"], conf["bit"])
    new_value = not current_value

    await asyncio.to_thread(plc_conn.write_bool, conf["db"], conf["byte"], conf["bit"], new_value)
    return {"status": "trigger toggled", "value": new_value}

@app.post("/api/simulate_outcome")
async def simulate_outcome(request: Request):
    data = await request.json()
    line_name = data.get("line_name")
    channel_id = data.get("channel_id")
    outcome = data.get("value")  # "buona" or "scarto"

    paths = get_channel_config(line_name, channel_id)
    if not paths or outcome not in ["buona", "scarto"]:
        return JSONResponse(status_code=400, content={"error": "Invalid data"})

    conf = paths["fine_buona"] if outcome == "buona" else paths["fine_scarto"]
    plc_conn = plc_connections.get(channel_id)
    if not plc_conn:
        return JSONResponse(status_code=404, content={"error": "PLC connection not found"})

    current_value = await asyncio.to_thread(plc_conn.read_bool, conf["db"], conf["byte"], conf["bit"])
    new_value = not current_value

    await asyncio.to_thread(plc_conn.write_bool, conf["db"], conf["byte"], conf["bit"], new_value)

    return {"status": f"{outcome} toggled", "value": new_value}

@app.post("/api/simulate_objectId")
async def simulate_objectId(request: Request):
    data = await request.json()
    line_name = data.get("line_name")
    channel_id = data.get("channel_id")
    object_id = data.get("objectId")

    if not line_name or not channel_id or not object_id:
        return JSONResponse(status_code=400, content={"error": "Missing parameters"})

    paths = get_channel_config(line_name, channel_id)
    if not paths:
        return JSONResponse(status_code=404, content={"error": "Invalid line or channel"})

    plc_conn = plc_connections.get(channel_id)
    if not plc_conn:
        return JSONResponse(status_code=404, content={"error": "PLC connection not found"})

    config = paths["id_modulo"]

    try:
        await asyncio.to_thread(
            plc_conn.write_string,
            config["db"],
            config["byte"],
            object_id,
            config["length"]
        )

        obj = await asyncio.to_thread(
            plc_conn.read_string,
            config["db"],
            config["byte"],
            config["length"]
        )

        print(f"✅ ObjectId '{obj}' written to PLC on {line_name} / {channel_id}")
        return {"status": "ObjectId written", "value": object_id}
    except Exception as e:
        logging.error(f"❌ Failed to write ObjectId: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})

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
                    return JSONResponse(status_code=400, content={"error": "Invalid turno number (must be 1, 2, or 3)"})

                start_time, end_time = turno_times[turno]

                if turno == 3:  # Night shift spans two dates
                    where_clause += """
                        AND (
                            (TIME(data_fine) >= %s AND DATE(data_fine) = %s) OR
                            (TIME(data_fine) <= %s AND DATE(data_fine) = DATE_ADD(%s, INTERVAL 1 DAY))
                        )
                    """
                    params += (start_time, date, end_time, date)
                else:
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
                    SELECT p.station, COUNT(*) AS defect_count
                    FROM {table} t
                    JOIN productions p ON p.id = t.production_id
                    {where_clause} AND t.scarto = 1
                    GROUP BY p.station
                """, params)
                for row in cursor.fetchall():
                    stations[row['station']].setdefault("defects", {})[label] = row['defect_count']

            fetch_defect_summary("ribbon", "Mancanza Ribbon")
            fetch_defect_summary("saldatura", "Saldatura")
            fetch_defect_summary("disallineamento_stringa", "Disallineamento")
            fetch_defect_summary("generali", "Generali")

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