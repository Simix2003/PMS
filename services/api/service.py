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
import ollama


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
                    },
                    "Stringa": {
                        f"Stringa[{i}]": None for i in range(1, 13)
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
                     "Rottura_Celle": {
                        "Stringa": {
                            f"Stringa[{i}]": {
                                f"Cella[{j}]": None for j in range(1, 11)
                            } for i in range(1, 13)
                        }
                        },
                     "Macchie_ECA_Celle": {
                        "Stringa": {
                            f"Stringa[{i}]": {
                                f"Cella[{j}]": None for j in range(1, 11)
                            } for i in range(1, 13)
                        }
                        },
                    "Generali": {
                        "Non Lavorato Poe Scaduto": {},
                        "Non Lavorato da Telecamere": {},
                        "Materiale Esterno su Celle": {},
                        "Bad Soldering": {},
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
        host="127.0.0.1",
        user="root",
        password="Master36!",
        database="production_data",
        port=3306,
        cursorclass=DictCursor,
        autocommit=False
    )
    print("🟢 MySQL connected!")
    
    plc_ip, plc_slot, station_configs = load_station_configs("C:/IX-Monitor/stations.ini")
    for station, params in station_configs.items():
        plc_conn = PLCConnection(ip_address=plc_ip, slot=plc_slot)
        plc_connections[station] = plc_conn
        asyncio.create_task(background_task(plc_conn, params, station))
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

async def send_initial_state(websocket: WebSocket, channel_id: str, plc_connection: PLCConnection):
    paths = CHANNELS[channel_id]

    # Read trigger value
    trigger_conf = paths["trigger"]
    trigger_value = await asyncio.to_thread(
        plc_connection.read_bool,
        trigger_conf["db"], trigger_conf["byte"], trigger_conf["bit"]
    )

    object_id = ""
    outcome = None
    issues_submitted = False

    if trigger_value:
        # Read the module ID (string)
        id_mod_conf = paths["id_modulo"]
        object_id = await asyncio.to_thread(
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

def extract_leaf(issue: str) -> str:
    # Step 1: Split by dot "." and get the last part
    last_part = issue.split(".")[-1].strip()
    
    return last_part

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
            "outcome": None,
            "issuesSubmitted": issues_submitted
        })

    else:
        print(f"🟡 Trigger on {channel_id} set to FALSE, resetting clients...")
        passato_flags[channel_id] = False
        await broadcast(channel_id, {
            "trigger": False,
            "objectId": None,
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
        data["Linea_in_Lavorazione"] = [True, False, False, False, False]

        # Read matrix data from the stringatrice configuration
        str_conf = CHANNELS[station]["stringatrice"]
        data["Lavorazione_Eseguita_Su_Stringatrice"] = [
            await asyncio.to_thread(plc_connection.read_bool, str_conf["db"], str_conf["byte"], i)
            for i in range(str_conf["length"])
        ]


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
            data["Rottura_Celle"] = fill_2d(12, 10, False)
            data["Macchie_ECA_Celle"] = fill_2d(12, 10, False)
            generali = {
                "Non_Lavorato_Poe_Scaduto": False,
                "Non_Lavorato_da_Telecamere": False,
                "Materiale_Esterno_su_Celle": False,
                "Bad_Soldering": False
            }
            for i in range(4, 16):
                generali[f"Non_Lavorato_Riserva_{i}"] = False
            data["Generali"] = generali

        elif richiesta_ko:
            issues = get_latest_issues(station)
            data["Stringa_F"] = fill_2d(6, 10, "Stringa_F" in issues)
            data["Stringa_M_F"] = fill_2d(6, 10, "Stringa_M_F" in issues)
            data["Stringa_M_B"] = fill_2d(6, 10, "Stringa_M_B" in issues)
            data["Stringa_B"] = fill_2d(6, 10, "Stringa_B" in issues)
            data["Disallineamento"] = {
                "Ribbon_Stringa_F": fill_1d(12, "Disallineamento_Ribbon_Stringa_F" in issues),
                "Ribbon_Stringa_M": fill_1d(12, "Disallineamento_Ribbon_Stringa_M" in issues),
                "Ribbon_Stringa_B": fill_1d(12, "Disallineamento_Ribbon_Stringa_B" in issues)
            }
            data["Stringa"] = fill_1d(12, "Stringa" in issues)
            data["Mancanza_Ribbon"] = {
                "Ribbon_Stringa_F": fill_1d(12, "Mancanza_Ribbon_Ribbon_Stringa_F" in issues),
                "Ribbon_Stringa_M": fill_1d(12, "Mancanza_Ribbon_Ribbon_Stringa_M" in issues),
                "Ribbon_Stringa_B": fill_1d(12, "Mancanza_Ribbon_Ribbon_Stringa_B" in issues)
            }
            data["Rottura_Celle"] = fill_2d(12, 10, "Rottura_Celle" in issues)
            data["Macchie_ECA_Celle"] = fill_2d(12, 10, "Macchie_ECA_Celle" in issues)
            generali = {
                "Non Lavorato Poe Scaduto": "Non Lavorato Poe Scaduto" in issues,
                "Non Lavorato da Telecamere": "Non Lavorato da Telecamere" in issues,
                "Materiale Esterno su Celle": "Materiale Esterno su Celle" in issues,
                "Bad Soldering": "Bad Soldering" in issues
            }
            for i in range(4, 16):
                generali[f"Non Lavorato Riserva {i}"] = f"Non Lavorato Riserva {i}" in issues
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

1️⃣ `productions`
- id (PK)
- station (ENUM: 'M308', 'M309', 'M326')
- id_modulo (VARCHAR)
- id_utente (VARCHAR)
- data_inizio (DATETIME)
- data_fine (DATETIME)
- esito (BOOLEAN)

2️⃣ `ribbons`
- id (PK)
- production_id (FK to productions.id)
- category (VARCHAR)  -- ('Linea_in_Lavorazione', 'Lavorazione_Eseguita_Su_Stringatrice', 'Stringa')
- position (INT)
- scarto (BOOLEAN)

3️⃣ `saldatura`
- id (PK)
- production_id (FK)
- category (VARCHAR)  -- ('Stringa_F', 'Stringa_M_F', etc.)
- stringa (INT)
- ribbon (INT)
- scarto (BOOLEAN)

4️⃣ `celle`  -- this replaces `matrix_12x10`
- id (PK)
- production_id (FK)
- category (VARCHAR)  -- ('Rottura_Celle', 'Macchie_ECA_Celle')
- stringa (INT)
- cella (INT)
- scarto (BOOLEAN)

5️⃣ `ribbon_defects`
- id (PK)
- production_id (FK)
- tipo (VARCHAR) -- ('Disallineamento', 'Mancanza_Ribbon')
- stringa (VARCHAR)
- position (INT)
- scarto (BOOLEAN)

6️⃣ `generali_flags`
- id (PK)
- production_id (FK)
- tipo (VARCHAR)
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

    Parameters:
        data (dict): Dictionary returned by read_station_data.
        station (str): Station identifier ('M308', 'M309', or 'M326').
        connection: An active pymysql connection.
        
    Returns:
        production_id (int) if successful, None otherwise.
    """
    try:
        with connection.cursor() as cursor:
            # --- 1. Insert into productions table ---
            sql_productions = """
                INSERT INTO productions 
                    (station, id_modulo, id_utente, data_inizio, data_fine, esito)
                VALUES 
                    (%s, %s, %s, %s, %s, %s)
            """
            cursor.execute(sql_productions, (
                station,
                data.get("Id_Modulo"),
                data.get("Id_Utente"),
                data.get("DataInizio"),
                data.get("DataFine"),
                #this should be inverted
                0 if data.get("Compilato_Su_Ipad_Scarto_Presente") else 1,

            ))
            production_id = cursor.lastrowid

            # --- 2. Insert into ribbons table (1D arrays) ---
            for idx, val in enumerate(data.get("Linea_in_Lavorazione", [])):
                if val:  # Only save True
                    sql = "INSERT INTO ribbons (production_id, category, position, scarto) VALUES (%s, %s, %s, %s)"
                    cursor.execute(sql, (production_id, 'Linea_in_Lavorazione', idx+1, val))

            
            # Only insert TRUE values for "Lavorazione_Eseguita_Su_Stringatrice"
            for idx, val in enumerate(data.get("Lavorazione_Eseguita_Su_Stringatrice", [])):
                if val:  # Only save True
                    sql = "INSERT INTO ribbons (production_id, category, position, scarto) VALUES (%s, %s, %s, %s)"
                    cursor.execute(sql, (production_id, 'Lavorazione_Eseguita_Su_Stringatrice', idx+1, val))

            
            # For "Stringa" (1D array) - ONLY TRUE values
            for idx, val in enumerate(data.get("Stringa", [])):
                if val:  # Only insert if True
                    sql = "INSERT INTO ribbons (production_id, category, position, scarto) VALUES (%s, %s, %s, %s)"
                    cursor.execute(sql, (production_id, 'Stringa', idx+1, val))

            # --- 3. Insert into matrix_6x10 table (only True values) ---
            for category in ['Stringa_F', 'Stringa_M_F', 'Stringa_M_B', 'Stringa_B']:
                matrix = data.get(category, [])
                for row_index, row in enumerate(matrix):
                    for col_index, val in enumerate(row):
                        if val:  # Only save True
                            sql = """
                                INSERT INTO saldatura (production_id, category, stringa, ribbon, scarto)
                                VALUES (%s, %s, %s, %s, %s)
                            """
                            cursor.execute(sql, (production_id, category, row_index+1, col_index+1, True))

            # --- 4. Insert into matrix_12x10 table (only True values) ---
            for category in ['Rottura_Celle', 'Macchie_ECA_Celle']:
                matrix = data.get(category, [])
                for row_index, row in enumerate(matrix):
                    for col_index, val in enumerate(row):
                        if val:  # Only save True
                            sql = """
                                INSERT INTO celle (production_id, category, stringa, cella, scarto)
                                VALUES (%s, %s, %s, %s, %s)
                            """
                            cursor.execute(sql, (production_id, category, row_index+1, col_index+1, True))

            # --- 5. Insert into ribbon_defects table ---
            # For Disallineamento
            dis = data.get("Disallineamento", {})
            for ribbon_area in ['Ribbon_Stringa_F', 'Ribbon_Stringa_M', 'Ribbon_Stringa_B']:
                arr = dis.get(ribbon_area, [])
                for pos, val in enumerate(arr):
                    if val:
                        sql = """
                            INSERT INTO ribbon_defects (production_id, tipo, stringa, position, scarto)
                            VALUES (%s, %s, %s, %s, %s)
                        """
                        cursor.execute(sql, (production_id, 'Disallineamento', ribbon_area, pos+1, val))

            # For Mancanza_Ribbon
            mr = data.get("Mancanza_Ribbon", {})
            for ribbon_area in ['Ribbon_Stringa_F', 'Ribbon_Stringa_M', 'Ribbon_Stringa_B']:
                arr = mr.get(ribbon_area, [])
                for pos, val in enumerate(arr):
                    if val:
                        sql = """
                            INSERT INTO ribbon_defects (production_id, tipo, stringa, position, scarto)
                            VALUES (%s, %s, %s, %s, %s)
                        """
                        cursor.execute(sql, (production_id, 'Mancanza_Ribbon', ribbon_area, pos+1, val))

            # --- 6. Insert into generali_flags table (only True flags) ---
            generali = data.get("Generali", {})
            for flag_name, val in generali.items():
                if val:
                    sql = "INSERT INTO generali_flags (production_id, tipo, scarto) VALUES (%s, %s, %s)"
                    cursor.execute(sql, (production_id, flag_name, val))

            
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
async def background_task(plc_connection, params, station):
    print(f"[{station}] Starting background task.")
    prev_trigger = False  # To detect changes (rising/falling edge)

    while True:
        try:
            trigger_conf = CHANNELS[station]["trigger"]
            trigger_value = await asyncio.to_thread(plc_connection.read_bool, trigger_conf["db"], trigger_conf["byte"], trigger_conf["bit"])

            # Detect change in trigger
            if trigger_value != prev_trigger:
                prev_trigger = trigger_value
                await on_trigger_change(plc_connection, station, None, trigger_value, None)

            # Your existing fine_buona / fine_scarto logic
            fb_conf = CHANNELS[station]["fine_buona"]
            fs_conf = CHANNELS[station]["fine_scarto"]
            fine_buona = await asyncio.to_thread(plc_connection.read_bool, fb_conf["db"], fb_conf["byte"], fb_conf["bit"])
            fine_scarto = await asyncio.to_thread(plc_connection.read_bool, fs_conf["db"], fs_conf["byte"], fs_conf["bit"])

            if (fine_buona or fine_scarto) and not passato_flags[station]:
                print(f"[{station}] Processing data (trigger detected)")
                data_inizio = trigger_timestamps.get(station)
                print('Data INIZIOOOOO: ', data_inizio)
                result = await read_data(plc_connection, station, richiesta_ok=fine_buona, richiesta_ko=fine_scarto, data_inizio=data_inizio)
                if result:
                    passato_flags[station] = True
                    print(f"[{station}] Data ready! ✅ Inserting into MySQL...")
                    insert_production_data(result, station, mysql_connection)
                    print(f"[{station}] Data inserted successfully!")

            await asyncio.sleep(1)
        except Exception as e:
            logging.error(f"[{station}] Error in background task: {str(e)}")
            await asyncio.sleep(5)

# ---------------- ROUTES ----------------
@app.websocket("/ws/{channel_id}")
async def websocket_endpoint(websocket: WebSocket, channel_id: str):
    if channel_id not in CHANNELS:
        await websocket.close()
        return

    await websocket.accept()
    print(f"📲 Client subscribed to {channel_id}")

    subscriptions.setdefault(channel_id, set()).add(websocket)

    # Use the GLOBAL connection
    plc_connection = plc_connections[channel_id]

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

    # Normalize issues using extract_leaf()
    normalized_issues = [extract_leaf(issue) for issue in issues]
    print('normalized issues:', normalized_issues)

    # Load existing data
    existing_data = load_temp_data()

    # Append new data
    existing_data.append({
        "channel_id": channel_id,
        "object_id": object_id,
        "issues": normalized_issues
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
    if str(current_object_id) != str(object_id):
        return JSONResponse(status_code=409, content={"error": "Stale object, already processed or expired."})

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
async def get_issue_tree(channel_id: str, path: str = Query("")):
    if channel_id not in CHANNELS:
        return JSONResponse(status_code=404, content={"error": "Invalid channel ID"})

    # Traverse ISSUE_TREE
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

@app.post("/api/reset_session")
async def reset_session(request: Request):
    data = await request.json()
    session_id = data.get("session_id")
    if not session_id:
        return JSONResponse(status_code=400, content={"error": "Missing session_id"})
    
    user_sessions.pop(session_id, None)
    return {"status": "Session reset successfully"}

@app.post("/api/chat")
async def chat_with_ai(request: Request):
    global mysql_connection, user_sessions
    data = await request.json()
    user_input = data.get("prompt")
    session_id = data.get("session_id", "default")

    if not user_input:
        return JSONResponse(status_code=400, content={"error": "Missing prompt"})

    current_time = time.time()

    # Get or initialize session
    session = user_sessions.get(session_id)

    # Check if expired
    if session and current_time - session.get("last_active", 0) > SESSION_TIMEOUT:
        print(f"⏰ Session '{session_id}' expired!")
        session = None  # Reset

    if not session:
        # Start new session
        session = {
            "messages": [{
                "role": "assistant",
                "content": "Ciao! 👋 Sono il tuo assistente SQL. Come posso aiutarti?"
            }],
            "last_active": current_time
        }

    # Add user message and update timestamp
    session["messages"].append({"role": "user", "content": user_input})
    session["last_active"] = current_time

    # Store back session
    user_sessions[session_id] = session

    # AI chat
    response = ollama.chat(
    model="gemma:2b-instruct",
    messages=[
        {
            "role": "system",
            "content": f"""Sei un assistente SQL per un database MySQL.
    Genera SOLO query SQL di tipo SELECT. Se mancano dettagli, chiedi ulteriori informazioni all'utente.
    Non aggiungere spiegazioni, restituisci solo la query SQL oppure una domanda per chiarimenti.
    Rispondi SEMPRE in italiano.

    Ecco la struttura del database:
    {DB_SCHEMA}
    """
            },
            *session["messages"]
        ]
    )


    ai_reply = response['message']['content']
    print(f"💡 AI says: {ai_reply}")

    # Save AI reply
    session["messages"].append({"role": "assistant", "content": ai_reply})

    # Store back updated session
    user_sessions[session_id] = session

    # If the reply is not a SELECT, just return the AI message
    if not ai_reply.strip().lower().startswith("select"):
        return {"ai_message": ai_reply}

    if not is_safe_query(ai_reply):
        return JSONResponse(status_code=400, content={"error": "Query non sicura.", "query": ai_reply})

    # Execute query
    try:
        assert mysql_connection is not None
        with mysql_connection.cursor() as cursor:
            cursor.execute(ai_reply)
            rows = cursor.fetchall()
        return {"query": ai_reply, "results": rows}
    except Exception as e:
        return JSONResponse(status_code=400, content={"error": f"Errore nella query: {str(e)}", "query": ai_reply})


# ---------------- MAIN ----------------
if __name__ == "__main__":
    uvicorn.run("service:app", host="0.0.0.0", port=8000)
