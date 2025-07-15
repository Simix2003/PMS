import configparser
import os
from pathlib import Path
from dotenv import load_dotenv, find_dotenv

debug = False

CHANNELS: dict = {}

#TODO
ZONE_SOURCES = { # Later on we will fetch them from MySQL, zones table
    "AIN": {
        "station_1_in":     ["MIN01"],
        "station_2_in":     ["MIN02"],
        "station_1_out_ng": ["MIN01"], 
        "station_2_out_ng": ["MIN02"]
    },
    "VPF": {
        "station_1_in":     ["VPF01"],
        "station_1_out_ng": ["VPF01"],
    },
    "ELL": {
        "station_1_in":     ["ELL01"],
        "station_2_in":     ["RMI01"],
        "station_1_out_ng": ["ELL01"],
        "station_2_out_ng": ["RMI01"],
    }
}

NEW_ZONES = {
"STR": {
        "station_1_in":     ["STR01"],
        "station_2_in":     ["STR02"],
        "station_3_in":     ["STR03"],
        "station_4_in":     ["STR04"],
        "station_5_in":     ["STR05"],
        "station_1_out_ng": ["STR01"],
        "station_2_out_ng": ["STR02"],
        "station_3_out_ng": ["STR03"],
        "station_4_out_ng": ["STR04"],
        "station_5_out_ng": ["STR05"],
    }
}
# Default fallback values
DEFAULT_TARGETS = {
    "yield_target": 90,
    "shift_target": 366
}


PLC_DB_RANGES: dict = {}  # {(ip, slot): {db_number: {"min": x, "max": y}}}

ISSUE_TREE = {
    "Dati": {
        "Esito": {
            "Esito_Scarto": {
                "Difetti": {
                    "Generali": {
                        "Non Lavorato Poe Scaduto": {}, 
                        "No Good da Bussing": {},
                        "Materiale Esterno su Celle": {},
                        "Passthrough al Bussing": {},
                        "Poe in Eccesso": {},
                        "Solo Poe": {},
                        "Solo Vetro": {},
                        "Matrice Incompleta": {},
                        "Molteplici Bus Bar": {},
                        "Test": {},
                        "Transitato per Controllo": {},
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
                     "I Ribbon Leadwire": {
                        f"Ribbon[{i}]": {
                            "M": None,
                        } for i in range(1, 5)
                    },
                    "Macchie ECA": {
                        f"Stringa[{i}]": None for i in range(1, 13)
                    },
                    "Celle Rotte": {
                        f"Stringa[{i}]": None for i in range(1, 13)
                    },
                    "Bad Soldering": {
                        f"Stringa[{i}]": None for i in range(1, 13)
                    },
                     "Lunghezza String Ribbon": {
                        f"Stringa[{i}]": None for i in range(1, 13)
                    },
                    "Graffio su Cella": {
                        f"Stringa[{i}]": None for i in range(1, 13)
                    },
                    "Altro": {}
                }
            }
        }
    }
}

load_dotenv(find_dotenv())

env_mode = os.getenv("ENV_MODE", "local")  # fallback to 'local' if not set

if env_mode == "docker":
    BASE_DIR = Path(os.getenv("BASE_DIR", "/data"))
else:
    BASE_DIR = Path(os.getenv("BASE_DIR", "C:/PMS"))

# Read .ini config
config_ini = configparser.ConfigParser()
config_ini.read(BASE_DIR / "config.ini")

# Read log levels with fallback
LOGS_FILE = config_ini.get("logging", "LOGS_FILE", fallback="INFO").upper()
LOGS_TERMINAL = config_ini.get("logging", "LOGS_TERMINAL", fallback="WARNING").upper()

ML_MODELS_DIR = BASE_DIR / "models"
DEFECT_SIMILARITY_MODEL_PATH = ML_MODELS_DIR / "fine-tuned-defects_V2"
TEMP_STORAGE_PATH = BASE_DIR / "temp_data.json"
SETTINGS_PATH = BASE_DIR / "settings.json"
TARGETS_FILE = BASE_DIR / "visual_targets.json"
os.makedirs(os.path.dirname(TARGETS_FILE), exist_ok=True)
LOG_PATH = BASE_DIR / "logs"
# Create logs directory if missing
os.makedirs(LOG_PATH, exist_ok=True)
# Set log file path
LOG_FILE = LOG_PATH / "pms.log"
IMAGES_DIR = BASE_DIR / "images"
if debug:
    XML_FOLDER_PATH = BASE_DIR / "xml"
else:
    XML_FOLDER_PATH = Path(r"\\192.168.32.205\ell01b\XML")

KNOWN_DEFECTS = [
    "Non Lavorato Poe Scaduto", 
    "No Good da Bussing",
    "Materiale Esterno su Celle",
    "Passthrough al Bussing",
    "Poe in Eccesso",
    "Solo Poe",
    "Solo Vetro",
    "Matrice Incompleta",
    "Molteplici Bus Bar",
    "Test",
    "Transitato per Controllo",
    "Saldatura",
    "Disallineamento Ribbon",
    "Disallineamento Stringa",
    "Mancanza Ribbon",
    "I Ribbon Leadwire",
    "Macchie ECA",
    "Celle Rotte",
    "Bad Soldering",
    "Lunghezza String Ribbon",
    "Graffio su Cella",
]


# In-memory cache
REFRESHED_SETTINGS = {}

COLUMN_MAP = {
    "ID Modulo": "o.id_modulo",
    "Esito": "p.esito",
    "Data": "p.end_time",
    "Operatore": "p.operator_id",
    "Linea": "pl.display_name",
    "Stazione": "s.name",
    "Tempo Ciclo": "p.cycle_time"
}