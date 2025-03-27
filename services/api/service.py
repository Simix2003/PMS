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

# Global flag for background task control (if you decide to use it)
stop_threads = {"M308": False, "M309": False, "M326": False}
# Global state for each station
passato_flags = {
    "M308": False,
    "M309": False,
    "M326": False
}
trigger_value_test = False

plc_connections = {} 

# GLOBAL
mysql_connection = None
# In-memory session history for chat
user_sessions = {} 

SESSION_TIMEOUT = 600  # 600 seconds = 10 minutes

# ---------------- LIFESPAN ----------------
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    global mysql_connection
    mysql_connection = pymysql.connect(
        host="localhost",
        user="root",
        password="Master36!",
        database="production_data",
        port=3306,
        cursorclass=DictCursor,
        autocommit=False
    )
    print("🟢 MySQL connected!")

    plc_ip, plc_slot, station_names = load_station_configs("C:/IX-Monitor/stations.ini")

    for station in station_names:
        plc_conn = PLCConnection(ip_address=plc_ip, slot=plc_slot, status_callback=make_status_callback(station))
        plc_connections[station] = plc_conn
        asyncio.create_task(background_task(plc_conn, station))
        print(f"🚀 Background task created for {station}")

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

async def send_initial_state(websocket: WebSocket, channel_id: str, plc_connection: PLCConnection):
    paths = CHANNELS[channel_id]

    # Read trigger value
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
        # Read the module ID (string)
        id_mod_conf = paths["id_modulo"]
        object_id = await asyncio.to_thread(
            plc_connection.read_string,
            id_mod_conf["db"], id_mod_conf["byte"], id_mod_conf["length"]
        )
        stringatrice = await asyncio.to_thread(
            plc_connection.read_string,
            id_mod_conf["db"], id_mod_conf["byte"], id_mod_conf["length"]
        )
        # Read fine_buona and fine_scarto (booleans)
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

        # Read the flag for issuesSubmitted
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
        
def get_latest_issues(station):
    """
    Returns the issues list for the given station (channel).
    Searches the temporary storage for the latest entry with matching channel_id.
    """
    temp_data = load_temp_data()
    # Assuming the last entry is the most recent one.
    for entry in reversed(temp_data):
        if entry.get("channel_id") == station:
            return entry.get("issues", [])
    return []

def fill_1d(length, value):
    return [value] * length

def fill_2d(rows, cols, value):
    return [[value] * cols for _ in range(rows)]

def remove_temp_issues(channel_id, object_id):
    temp_data = load_temp_data()
    filtered_data = [entry for entry in temp_data if not (entry.get("channel_id") == channel_id and entry.get("object_id") == object_id)]
    save_temp_data(filtered_data)
    print(f"🗑️ Removed temp issue for {channel_id} - {object_id}")

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

# ---------------- PLC EVENTS ----------------
async def on_trigger_change(plc_connection: PLCConnection, channel_id, node, val, data):
    if not isinstance(val, bool):
        return

    if val:
        print(f"🟡 Trigger on {channel_id} set to TRUE, reading...")
        trigger_timestamps.pop(channel_id, None)

        # Write FALSE to esito_scarto_compilato
        esito_conf = CHANNELS[channel_id]["esito_scarto_compilato"]
        await asyncio.to_thread(
            plc_connection.write_bool,
            esito_conf["db"], esito_conf["byte"], esito_conf["bit"], False
        )

        # Read the module ID string
        id_mod_conf = CHANNELS[channel_id]["id_modulo"]
        object_id = await asyncio.to_thread(
            plc_connection.read_string,
            id_mod_conf["db"], id_mod_conf["byte"], id_mod_conf["length"]
        )
        if trigger_value_test:
            object_id = 'test'

        print('object_id: ', object_id)

        # Read matrix data from the stringatrice configuration
        str_conf = CHANNELS[channel_id]["stringatrice"]
        values = [
            await asyncio.to_thread(plc_connection.read_bool, str_conf["db"], str_conf["byte"], i)
            for i in range(str_conf["length"])
        ]

        # Ensure at least one True (fallback)
        if not any(values):
            values[0] = True

        # Get the index of the True value → stringatrice number (1-based)
        stringatrice_index = values.index(True) + 1
        stringatrice = str(stringatrice_index)

        # Read issues flag again
        issues_value = await asyncio.to_thread(
            plc_connection.read_bool,
            esito_conf["db"], esito_conf["byte"], esito_conf["bit"]
        )
        issues_submitted = issues_value is True

        trigger_timestamps[channel_id] = datetime.datetime.now()
        print('trigger_timestamps[channel_id]: ', trigger_timestamps[channel_id])

        await broadcast(channel_id, {
            "trigger": True,
            "objectId": object_id,
            "stringatrice": stringatrice,
            "outcome": None,
            "issuesSubmitted": issues_submitted
        })

    else:
        print(f"🟡 Trigger on {channel_id} set to FALSE, resetting clients...")
        passato_flags[channel_id] = False
        await broadcast(channel_id, {
            "trigger": False,
            "objectId": None,
            "stringatrice": None,
            "outcome": None,
            "issuesSubmitted": False
        })

async def read_data(plc_connection: PLCConnection, station, richiesta_ko, richiesta_ok, data_inizio):
    try:
        data = {}

        # Read Id_Modulo string
        id_mod_conf = CHANNELS[station]["id_modulo"]
        data["Id_Modulo"] = await asyncio.to_thread(
            plc_connection.read_string,
            id_mod_conf["db"], id_mod_conf["byte"], id_mod_conf["length"]
        )

        # Read Id_Utente string
        id_utente_conf = CHANNELS[station]["id_utente"]
        data["Id_Utente"] = await asyncio.to_thread(
            plc_connection.read_string,
            id_utente_conf["db"], id_utente_conf["byte"], id_utente_conf["length"]
        )

        data["DataInizio"] = data_inizio
        data["DataFine"] = datetime.datetime.now()
        data["Linea_in_Lavorazione"] = [False, True, False, False, False]

        # Read matrix data from the stringatrice configuration
        str_conf = CHANNELS[station]["stringatrice"]
        values = [
            await asyncio.to_thread(plc_connection.read_bool, str_conf["db"], str_conf["byte"], i)
            for i in range(str_conf["length"])
        ]
        # Ensure at least one True
        if not any(values):
            values[0] = True  # or random.choice if you want it randomized

        data["Lavorazione_Eseguita_Su_Stringatrice"] = values

        data["Compilato_Su_Ipad_Scarto_Presente"] = True if richiesta_ko else False

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
                "Cella Rotta": False
            }
            for i in range(4, 16):
                generali[f"Non_Lavorato_Riserva_{i}"] = False
            data["Generali"] = generali

        elif richiesta_ko:
            issues = get_latest_issues(station)
            print('issues:', issues)

            # Saldatura Matrici
            data["Stringa_F"] = build_matrix_from_raw(issues, "Stringa_F", 6, 10)
            data["Stringa_M_F"] = build_matrix_from_raw(issues, "Stringa_M_F", 6, 10)
            data["Stringa_M_B"] = build_matrix_from_raw(issues, "Stringa_M_B", 6, 10)
            data["Stringa_B"] = build_matrix_from_raw(issues, "Stringa_B", 6, 10)

            # Disallineamento
            data["Disallineamento"] = {
                "Ribbon_Stringa_F": build_ribbon_array(issues, "Ribbon_Stringa_F", 12),
                "Ribbon_Stringa_M": build_ribbon_array(issues, "Ribbon_Stringa_M", 12),
                "Ribbon_Stringa_B": build_ribbon_array(issues, "Ribbon_Stringa_B", 12),
            }

            # Stringa (1D)
            data["Stringa"] = build_ribbon_array(issues, "Stringa", 12)

            # Mancanza Ribbon
            data["Mancanza_Ribbon"] = {
                "Ribbon_Stringa_F": build_ribbon_array(issues, "Mancanza_Ribbon.Ribbon_Stringa_F", 12),
                "Ribbon_Stringa_M": build_ribbon_array(issues, "Mancanza_Ribbon.Ribbon_Stringa_M", 12),
                "Ribbon_Stringa_B": build_ribbon_array(issues, "Mancanza_Ribbon.Ribbon_Stringa_B", 12),
            }

            # Generali
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

        print(f"[{station}] Data read successfully.")
        print('data: ', data)
        return data

    except Exception as e:
        logging.error(f"[{station}] Error reading PLC data: {e}")
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

def is_safe_query(query: str) -> bool:
    query_lower = query.lower()
    # Only allow SELECT queries without risky subcommands
    if not query_lower.strip().startswith("select"):
        return False
    # Block UNION, INTO OUTFILE, DROP, DELETE, UPDATE, INSERT, etc.
    blacklist = ["insert", "update", "delete", "drop", "alter", "union", "outfile"]
    return not any(bad in query_lower for bad in blacklist)

def insert_production_data(data, station, connection):
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
                    (linea, station, stringatrice, id_modulo, id_utente, data_inizio, data_fine, esito)
                VALUES 
                    (%s, %s, %s, %s, %s, %s, %s, %s)
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
            return production_id

    except Exception as e:
        connection.rollback()
        logging.error(f"Error inserting production data: {e}")
        return None

# ---------------- CONFIG PARSING ----------------
        
def load_station_configs(file_path):
    config = configparser.ConfigParser()
    config.read(file_path)

    plc_ip = config.get("PLC", "IP")
    plc_slot = config.getint("PLC", "SLOT")

    # Just load station names that start with "M"
    station_names = []

    for section in config.sections():
        if section.startswith("M"):
            station_names.append(section)

    return plc_ip, plc_slot, station_names

# ---------------- BACKGROUND TASK ----------------
def make_status_callback(station):
    async def callback(status):
        try:
            await broadcast(station, {"plc_status": status})
        except Exception as e:
            logging.error(f"❌ Failed to send PLC status for {station}: {e}")
    return callback

async def background_task(plc_connection: PLCConnection, station):
    global trigger_value_test
    print(f"[{station}] Starting background task.")
    prev_trigger = False

    while True:
        try:
            # Ensure connection is alive or try reconnect
            if not plc_connection.connected or not plc_connection.is_connected():
                print(f"⚠️ PLC disconnected for {station}, attempting reconnect...")
                await asyncio.to_thread(plc_connection.reconnect, retries=3, delay=5)
                await asyncio.sleep(10)
                continue  # Retry after delay

            # Safe trigger read
            trigger_conf = CHANNELS[station]["trigger"]
            #trigger_value = await asyncio.to_thread(
            #    plc_connection.read_bool,
            #    trigger_conf["db"], trigger_conf["byte"], trigger_conf["bit"]
            #)
            trigger_value = trigger_value_test

            if trigger_value is None:
                raise Exception("Trigger read returned None")

            if trigger_value != prev_trigger:
                prev_trigger = trigger_value
                await on_trigger_change(plc_connection, station, None, trigger_value, None)

            # Outcome check
            fb_conf = CHANNELS[station]["fine_buona"]
            fs_conf = CHANNELS[station]["fine_scarto"]
            fine_buona = await asyncio.to_thread(
                plc_connection.read_bool,
                fb_conf["db"], fb_conf["byte"], fb_conf["bit"]
            )
            fine_scarto = await asyncio.to_thread(
                plc_connection.read_bool,
                fs_conf["db"], fs_conf["byte"], fs_conf["bit"]
            )

            if fine_buona is None or fine_scarto is None:
                raise Exception("Outcome read returned None")

            if (fine_buona or fine_scarto) and not passato_flags[station]:
                print(f"[{station}] Processing data (trigger detected)")
                data_inizio = trigger_timestamps.get(station)
                result = await read_data(plc_connection, station,
                                         richiesta_ok=fine_buona,
                                         richiesta_ko=fine_scarto,
                                         data_inizio=data_inizio)
                if result:
                    passato_flags[station] = True
                    print(f"[{station}] ✅ Inserting into MySQL...")
                    insert_production_data(result, station, mysql_connection)
                    print(f"[{station}] 🟢 Data inserted successfully!")
                    await asyncio.to_thread(plc_connection.write_bool, fb_conf["db"], fb_conf["byte"], fb_conf["bit"], False)
                    await asyncio.to_thread(plc_connection.write_bool, fs_conf["db"], fs_conf["byte"], fs_conf["bit"], False)
                    remove_temp_issues(station, result.get("Id_Modulo"))

            await asyncio.sleep(1)

        except Exception as e:
            logging.error(f"[{station}] 🔴 Error in background task: {str(e)}")
            await asyncio.to_thread(plc_connection.reconnect, retries=3, delay=5)
            await asyncio.sleep(5)

# ---------------- ROUTES ----------------
            
@app.get("/api/plc_status")
async def plc_status():
    statuses = {}
    for station, plc_conn in plc_connections.items():
        statuses[station] = "CONNECTED" if plc_conn.connected else "DISCONNECTED"
    return statuses

@app.websocket("/ws/{channel_id}")
async def websocket_endpoint(websocket: WebSocket, channel_id: str):
    if channel_id not in CHANNELS:
        await websocket.close()
        return

    await websocket.accept()
    await websocket.send_json({"handshake": True})
    print(f"📲 Client subscribed to {channel_id}")

    subscriptions.setdefault(channel_id, set()).add(websocket)
    plc_connection = plc_connections.get(channel_id)

    if not plc_connection:
        print(f"❌ No PLC connection found for {channel_id}.")
        await websocket.close()
        return

    # Check connection status before sending initial state
    if not plc_connection.connected or not plc_connection.is_connected():
        print(f"⚠️ PLC for {channel_id} is disconnected. Attempting reconnect for WebSocket...")
        if not plc_connection.reconnect(retries=3, delay=5):
            print(f"❌ Failed to reconnect PLC for {channel_id}. Closing socket.")
            await websocket.close()
            return
        else:
            print(f"✅ PLC reconnected for {channel_id}!")

    await send_initial_state(websocket, channel_id, plc_connection)

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        print(f"⚠️ Client disconnected from {channel_id}")
    finally:
        subscriptions[channel_id].remove(websocket)

@app.post("/api/set_issues")
async def set_issues(request: Request):
    data = await request.json()
    channel_id = data.get("channel_id")
    object_id = data.get("object_id")
    issues = data.get("issues", [])

    if not channel_id or not object_id or not issues:
        return JSONResponse(status_code=400, content={"error": "Missing data"})

    print('raw issues received:', issues)

    # Load existing data
    existing_data = load_temp_data()

    # Append new data
    existing_data.append({
        "channel_id": channel_id,
        "object_id": object_id,
        "issues": issues
    })

    # Save updated data
    save_temp_data(existing_data)
    print('issues saved:', existing_data)

    plc_connection = plc_connections[channel_id]

    target = CHANNELS[channel_id].get("esito_scarto_compilato")
    if not target:
        return JSONResponse(status_code=404, content={"error": "Channel mapping not found"})

    await asyncio.to_thread(plc_connection.write_bool, target["db"], target["byte"], target["bit"], True)

    return {"status": "ok"}

@app.get("/api/get_issues")
async def get_selected_issues(channel_id: str, object_id: str):
    if not channel_id or not object_id:
        return JSONResponse(status_code=400, content={"error": "Missing channel_id or object_id"})

    # Load issues from temp storage
    temp_data = load_temp_data()

    # Filter issues based on channel_id + object_id
    matching_entry = next((entry for entry in temp_data if entry["channel_id"] == channel_id and entry["object_id"] == object_id), None)

    if not matching_entry:
        return {"selected_issues": []}  # Return empty if not found

    return {"selected_issues": matching_entry["issues"]}

@app.post("/api/set_outcome")
async def set_outcome(request: Request):
    data = await request.json()
    channel_id = data.get("channel_id")
    object_id = data.get("object_id")
    outcome = data.get("outcome")  # "buona" or "scarto"

    if channel_id not in CHANNELS or outcome not in ["buona", "scarto"]:
        return JSONResponse(status_code=400, content={"error": "Invalid data"})

    plc_connection = plc_connections[channel_id]
    
    # Read current object_id using Snap7
    read_conf = CHANNELS[channel_id]["id_modulo"]
    current_object_id = await asyncio.to_thread(
        plc_connection.read_string,
        read_conf["db"], read_conf["byte"], read_conf["length"]
    )
    #if str(current_object_id) != str(object_id):
    #    return JSONResponse(status_code=409, content={"error": "Stale object, already processed or expired."})

    # Write outcome using a configuration stored in CHANNELS (or a dedicated mapping)
    #outcome_conf = CHANNELS[channel_id]["fine_buona"] if outcome == "buona" else CHANNELS[channel_id]["fine_scarto"]
    #await asyncio.to_thread(
    #    plc_connection.write_bool,
    #    outcome_conf["db"], outcome_conf["byte"], outcome_conf["bit"], True
    #)

    print(f"✅ Outcome '{outcome.upper()}' written for object {object_id} on {channel_id}")
    await broadcast(channel_id, {
        "trigger": None,
        "objectId": object_id,
        "outcome": outcome
    })
    return {"status": "ok"}

@app.get("/api/issues/{channel_id}")
async def get_issue_tree(channel_id: str, path: str = Query("Dati.Esito.Esito_Scarto.Difetti")):
    if channel_id not in CHANNELS:
        return JSONResponse(status_code=404, content={"error": "Invalid channel ID"})

    # Traverse ISSUE_TREE using the dot-separated path.
    current_node = ISSUE_TREE
    if path:
        for part in path.split("."):
            current_node = current_node.get(part)
            if current_node is None:
                return JSONResponse(status_code=404, content={"error": "Path not found"})

    items = []
    for name, child in current_node.items():
        item_type = "folder" if child else "leaf"
        items.append({"name": name, "type": item_type})
    return {"items": items}

@app.get("/api/overlay_config")
async def get_overlay_config(path: str):
    safe_folder = "Linea2"
    config_file = f"C:/IX-Monitor/images/{safe_folder}/overlay_config.json"

    if not os.path.exists(config_file):
        return JSONResponse(status_code=417, content={"error": "Overlay config not found"})

    with open(config_file, "r") as f:
        all_configs = json.load(f)

    # Try to match entry based on provided path
    for image_name, config in all_configs.items():
        if config.get("path", "").lower() == path.lower():
            return {
                "image_url": f"http://localhost:8000/images/{safe_folder}/{image_name}",
                "rectangles": config.get("rectangles", [])
            }

    return JSONResponse(status_code=404, content={"error": "No config matches the provided path"})

@app.post("/api/update_overlay_config")
async def update_overlay_config(request: Request):
    data = await request.json()
    path = data.get("path")
    new_rectangles = data.get("rectangles")

    if not path or not new_rectangles:
        return JSONResponse(status_code=400, content={"error": "Missing path or rectangles"})

    config_file = "C:/IX-Monitor/images/Linea2/overlay_config.json"

    if not os.path.exists(config_file):
        return JSONResponse(status_code=404, content={"error": "Config file not found"})

    with open(config_file, "r") as f:
        config = json.load(f)

    # Find matching image by path
    image_to_update = None
    for image_name, entry in config.items():
        if entry.get("path") == path:
            image_to_update = image_name
            break

    if not image_to_update:
        return JSONResponse(status_code=404, content={"error": "Path not found in config"})

    # Update rectangles
    config[image_to_update]["rectangles"] = new_rectangles

    with open(config_file, "w") as f:
        json.dump(config, f, indent=4)

    return {"status": "updated", "image": image_to_update}

@app.get("/api/available_overlay_paths")
async def available_overlay_paths():
    config_file = "C:/IX-Monitor/images/Linea2/overlay_config.json"
    if not os.path.exists(config_file):
        return JSONResponse(status_code=404, content={"error": "Config file not found"})

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
    global trigger_value_test

    data = await request.json()
    channel_id = data.get("channel_id")

    conf = CHANNELS[channel_id]["trigger"]
    plc_conn = plc_connections[channel_id]

    current_value = await asyncio.to_thread(plc_conn.read_bool, conf["db"], conf["byte"], conf["bit"])
    new_value = not current_value

    trigger_value_test = not trigger_value_test



    return {"status": "trigger toggled", "value": new_value}

@app.post("/api/simulate_outcome")
async def simulate_outcome(request: Request):
    data = await request.json()
    channel_id = data.get("channel_id")
    outcome = data.get("value")  # "buona" or "scarto"

    conf = CHANNELS[channel_id]["fine_buona"] if outcome == "buona" else CHANNELS[channel_id]["fine_scarto"]
    plc_conn = plc_connections[channel_id]

    current_value = await asyncio.to_thread(plc_conn.read_bool, conf["db"], conf["byte"], conf["bit"])
    new_value = not current_value

    await asyncio.to_thread(plc_conn.write_bool, conf["db"], conf["byte"], conf["bit"], new_value)

    return {"status": "outcome toggled", "value": new_value}

@app.post("/api/simulate_objectId")
async def simulate_objectId(request: Request):
    data = await request.json()
    channel_id = data.get("channel_id")
    object_id = data.get("objectId")

    if not channel_id or not object_id:
        return JSONResponse(status_code=400, content={"error": "Missing channel_id or objectId"})

    if channel_id not in CHANNELS:
        return JSONResponse(status_code=404, content={"error": "Invalid channel ID"})

    plc_conn = plc_connections[channel_id]
    config = CHANNELS[channel_id]["id_modulo"]
    print(config)

    try:
        await asyncio.to_thread(
            plc_conn.write_string,
            config["db"],
            config["byte"],
            object_id,       # <-- value
            config["length"] # <-- max_size
        )

        obj = await asyncio.to_thread(
            plc_conn.read_string,
            config["db"],
            config["byte"],
            config["length"]
        )
        print(f"✅ ObjectId '{obj}' written to PLC on channel {channel_id}")
        return {"status": "ObjectId written", "value": object_id}
    except Exception as e:
        logging.error(f"❌ Failed to write ObjectId: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.get("/api/productions_summary")
async def productions_summary(date: str):
    global mysql_connection
    queries = {
        "overall_summary": """
            SELECT
                SUM(CASE WHEN esito = 1 THEN 1 ELSE 0 END) AS good_count,
                SUM(CASE WHEN esito = 0 THEN 1 ELSE 0 END) AS bad_count,
                station
            FROM productions
            WHERE DATE(data_fine) = %s
            GROUP BY station
        """,
        "station_production": """
            SELECT 
                station, 
                COUNT(*) as total_production
            FROM productions
            WHERE DATE(data_fine) = %s
            GROUP BY station
        """,
        "ribbon_defects": """
            SELECT 
                CONCAT(tipo_difetto, ' - ', tipo) AS defect_type,
                COUNT(*) AS defect_count
            FROM ribbon
            JOIN productions ON productions.id = ribbon.production_id
            WHERE DATE(productions.data_fine) = %s AND ribbon.scarto = 1
            GROUP BY tipo_difetto, tipo
        """,
        "cell_defects": """
            SELECT 
                tipo_difetto AS defect_type, 
                COUNT(*) AS defect_count
            FROM celle
            JOIN productions ON productions.id = celle.production_id
            WHERE DATE(productions.data_fine) = %s AND celle.scarto = 1
            GROUP BY tipo_difetto
        """,
        "welding_defects": """
            SELECT 
                category AS defect_type, 
                COUNT(*) AS defect_count
            FROM saldatura
            JOIN productions ON productions.id = saldatura.production_id
            WHERE DATE(productions.data_fine) = %s AND saldatura.scarto = 1
            GROUP BY category
        """,
        "disallineamento_defects": """
            SELECT 
                'Disallineamento Stringa' AS defect_type,
                COUNT(*) AS defect_count
            FROM disallineamento_stringa
            JOIN productions ON productions.id = disallineamento_stringa.production_id
            WHERE DATE(productions.data_fine) = %s AND disallineamento_stringa.scarto = 1
        """,
        "lunghezza_ribbon_defects": """
            SELECT 
                'Lunghezza String Ribbon' AS defect_type,
                COUNT(*) AS defect_count
            FROM lunghezza_string_ribbon
            JOIN productions ON productions.id = lunghezza_string_ribbon.production_id
            WHERE DATE(productions.data_fine) = %s AND lunghezza_string_ribbon.scarto = 1
        """,
        "generali_defects": """
            SELECT 
                tipo_difetto AS defect_type,
                COUNT(*) AS defect_count
            FROM generali
            JOIN productions ON productions.id = generali.production_id
            WHERE DATE(productions.data_fine) = %s AND generali.scarto = 1
            GROUP BY tipo_difetto
        """
    }

    try:
        assert mysql_connection is not None
        with mysql_connection.cursor() as cursor:
            results = {}

            # Overall
            cursor.execute(queries["overall_summary"], (date,))
            overall_summary = cursor.fetchall()
            good_count = sum(row['good_count'] for row in overall_summary)
            bad_count = sum(row['bad_count'] for row in overall_summary)

            # Stations
            cursor.execute(queries["station_production"], (date,))
            station_production = cursor.fetchall()
            stations = {row['station']: row['total_production'] for row in station_production}
            for station in ['M308', 'M309', 'M326']:
                if station not in stations:
                    stations[station] = 0

            # Defects
            defect_types = {}

            # Ribbon
            cursor.execute(queries["ribbon_defects"], (date,))
            for row in cursor.fetchall():
                defect_types[f"Ribbon - {row['defect_type']}"] = row['defect_count']

            # Celle
            cursor.execute(queries["cell_defects"], (date,))
            for row in cursor.fetchall():
                defect_types[f"Celle - {row['defect_type']}"] = row['defect_count']

            # Saldatura
            cursor.execute(queries["welding_defects"], (date,))
            for row in cursor.fetchall():
                defect_types[f"Saldatura - {row['defect_type']}"] = row['defect_count']

            # Disallineamento Stringa
            cursor.execute(queries["disallineamento_defects"], (date,))
            row = cursor.fetchone()
            if row:
                defect_types[row['defect_type']] = row['defect_count']

            # Lunghezza String Ribbon
            cursor.execute(queries["lunghezza_ribbon_defects"], (date,))
            row = cursor.fetchone()
            if row:
                defect_types[row['defect_type']] = row['defect_count']

            # Generali
            cursor.execute(queries["generali_defects"], (date,))
            for row in cursor.fetchall():
                defect_types[f"Generali - {row['defect_type']}"] = row['defect_count']

            return {
                "good_count": good_count,
                "bad_count": bad_count,
                "stations": stations,
                "defect_types": defect_types
            }

    except Exception as e:
        logging.error(f"MySQL Error: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})

# ---------------- MAIN ----------------
if __name__ == "__main__":
   uvicorn.run(app, host="0.0.0.0", port=8000)