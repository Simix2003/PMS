import os
from pathlib import Path

debug = True

CHANNELS: dict = {}
#TODO
ZONE_SOURCES = { # Later on we will fetch them from MySQL, zones table
    "AIN": {
        "station_1_in":     ["AIN01"], # Should be AIN01
        "station_2_in":     ["AIN02"], # Should be AIN02
        "station_1_out_ng": ["MIN01"], 
        "station_2_out_ng": ["MIN02"]
    },
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
                        "Test": {}
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

BASE_DIR = Path("C:/PMS")

# Directory for all saved ML models
ML_MODELS_DIR = os.path.join(BASE_DIR, "models")

# Specific models
DEFECT_SIMILARITY_MODEL_PATH = os.path.join(ML_MODELS_DIR, "fine-tuned-defects_V2")

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

TEMP_STORAGE_PATH = os.path.join(BASE_DIR, "temp_data.json")
SETTINGS_PATH = os.path.join(BASE_DIR, "settings.json")
# In-memory cache
REFRESHED_SETTINGS = {}

XML_FOLDER_PATH = r"D:\Imix\Lavori\2025\3SUN\MBJ\xml"
#XML_FOLDER_PATH = r"\\Desktop-ofbalr8\xml"
IMAGES_DIR = BASE_DIR / "images"

COLUMN_MAP = {
    "ID Modulo": "o.id_modulo",
    "Esito": "p.esito",
    "Data": "p.end_time",
    "Operatore": "p.operator_id",
    "Linea": "pl.display_name",
    "Stazione": "s.name",
    "Tempo Ciclo": "p.cycle_time"
}