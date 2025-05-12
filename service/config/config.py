import os
import configparser
from pathlib import Path

debug = False
debugModulo = "3SBHBGHC25407300"
# ---------------- CONFIG & GLOBALS ----------------
if not debug :
    CHANNELS = {
        "Linea1": {
            "M308": {
                "trigger": {"db": 19606, "byte": 0, "bit": 4},
                "id_modulo": {"db": 19606, "byte": 2, "length": 20},
                "id_utente": {"db": 19606, "byte": 24, "length": 20},
                "fine_buona": {"db": 19606, "byte": 0, "bit": 6},
                "fine_scarto": {"db": 19606, "byte": 0, "bit": 7},
                "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 0},
                "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 19606, "byte": 144, "bit": 3},
                "stringatrice": {"db": 19606, "byte": 46, "length": 5},
                "stazione_esclusa": {"db": 19606, "byte": 1, "bit": 3},
            },
            "M309": {
                "trigger": {"db": 19606, "byte": 48, "bit": 4},
                "id_modulo": {"db": 19606, "byte": 50, "length": 20},
                "id_utente": {"db": 19606, "byte": 72, "length": 20},
                "fine_buona": {"db": 19606, "byte": 48, "bit": 6},
                "fine_scarto": {"db": 19606, "byte": 48, "bit": 7},
                "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 1},
                "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 19606, "byte": 144, "bit": 4},
                "stringatrice": {"db": 19606, "byte": 94, "length": 5},
                "stazione_esclusa": {"db": 19606, "byte": 49, "bit": 3},
            },
            "M326": {
                    "trigger": {"db": 19606, "byte": 96, "bit": 4},
                    "id_modulo": {"db": 19606, "byte": 98, "length": 20},
                    "id_utente": {"db": 19606, "byte": 120, "length": 20},
                    "fine_buona": {"db": 19606, "byte": 96, "bit": 5},
                    "fine_scarto": {"db": 19606, "byte": 96, "bit": 6},
                    "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 2},
                    "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 19606, "byte": 144, "bit": 5},
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
                "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 19606, "byte": 144, "bit": 3},
                "stringatrice": {"db": 19606, "byte": 46, "length": 5},
                "stazione_esclusa": {"db": 19606, "byte": 1, "bit": 3},
            },
            "M309": {
                "trigger": {"db": 19606, "byte": 48, "bit": 4},
                "id_modulo": {"db": 19606, "byte": 50, "length": 20},
                "id_utente": {"db": 19606, "byte": 72, "length": 20},
                "fine_buona": {"db": 19606, "byte": 48, "bit": 6},
                "fine_scarto": {"db": 19606, "byte": 48, "bit": 7},
                "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 1},
                "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 19606, "byte": 144, "bit": 4},
                "stringatrice": {"db": 19606, "byte": 94, "length": 5},
                "stazione_esclusa": {"db": 19606, "byte": 49, "bit": 3},
            },
            "M326": {
                    "trigger": {"db": 19606, "byte": 96, "bit": 4},
                    "id_modulo": {"db": 19606, "byte": 98, "length": 20},
                    "id_utente": {"db": 19606, "byte": 120, "length": 20},
                    "fine_buona": {"db": 19606, "byte": 96, "bit": 5},
                    "fine_scarto": {"db": 19606, "byte": 96, "bit": 6},
                    "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 2},
                    "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 19606, "byte": 144, "bit": 5},
                    "stringatrice": {"db": 19606, "byte": 142, "length": 5},
                },
        },
        "Linea3": {
            "M308": {
                "trigger": {"db": 19606, "byte": 0, "bit": 4},
                "id_modulo": {"db": 19606, "byte": 2, "length": 20},
                "id_utente": {"db": 19606, "byte": 24, "length": 20},
                "fine_buona": {"db": 19606, "byte": 0, "bit": 6},
                "fine_scarto": {"db": 19606, "byte": 0, "bit": 7},
                "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 0},
                "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 19606, "byte": 144, "bit": 3},
                "stringatrice": {"db": 19606, "byte": 46, "length": 5},
                "stazione_esclusa": {"db": 19606, "byte": 1, "bit": 3},
            },
            "M309": {
                "trigger": {"db": 19606, "byte": 48, "bit": 4},
                "id_modulo": {"db": 19606, "byte": 50, "length": 20},
                "id_utente": {"db": 19606, "byte": 72, "length": 20},
                "fine_buona": {"db": 19606, "byte": 48, "bit": 6},
                "fine_scarto": {"db": 19606, "byte": 48, "bit": 7},
                "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 1},
                "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 19606, "byte": 144, "bit": 4},
                "stringatrice": {"db": 19606, "byte": 94, "length": 5},
                "stazione_esclusa": {"db": 19606, "byte": 49, "bit": 3},
            },
            "M326": {
                    "trigger": {"db": 19606, "byte": 96, "bit": 4},
                    "id_modulo": {"db": 19606, "byte": 98, "length": 20},
                    "id_utente": {"db": 19606, "byte": 120, "length": 20},
                    "fine_buona": {"db": 19606, "byte": 96, "bit": 5},
                    "fine_scarto": {"db": 19606, "byte": 96, "bit": 6},
                    "esito_scarto_compilato": {"db": 19606, "byte": 144, "bit": 2},
                    "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 19606, "byte": 144, "bit": 5},
                    "stringatrice": {"db": 19606, "byte": 142, "length": 5},
                },
        },
    }
else:
    CHANNELS = {
        "Linea1": {
            "M308": {
                "trigger": {"db": 9606, "byte": 0, "bit": 4},
                "id_modulo": {"db": 9606, "byte": 2, "length": 20},
                "id_utente": {"db": 9606, "byte": 24, "length": 20},
                "fine_buona": {"db": 9606, "byte": 0, "bit": 6},
                "fine_scarto": {"db": 9606, "byte": 0, "bit": 7},
                "esito_scarto_compilato": {"db": 9606, "byte": 144, "bit": 0},
                "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 9606, "byte": 144, "bit": 3},
                "stringatrice": {"db": 9606, "byte": 46, "length": 5},
                "stazione_esclusa": {"db": 9606, "byte": 1, "bit": 3},
            },
            "M309": {
                "trigger": {"db": 9606, "byte": 48, "bit": 4},
                "id_modulo": {"db": 9606, "byte": 50, "length": 20},
                "id_utente": {"db": 9606, "byte": 72, "length": 20},
                "fine_buona": {"db": 9606, "byte": 48, "bit": 6},
                "fine_scarto": {"db": 9606, "byte": 48, "bit": 7},
                "esito_scarto_compilato": {"db": 9606, "byte": 144, "bit": 1},
                "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 9606, "byte": 144, "bit": 4},
                "stringatrice": {"db": 9606, "byte": 94, "length": 5},
                "stazione_esclusa": {"db": 9606, "byte": 49, "bit": 3},
            },
            "M326": {
                    "trigger": {"db": 9606, "byte": 96, "bit": 4},
                    "id_modulo": {"db": 9606, "byte": 98, "length": 20},
                    "id_utente": {"db": 9606, "byte": 120, "length": 20},
                    "fine_buona": {"db": 9606, "byte": 96, "bit": 5},
                    "fine_scarto": {"db": 9606, "byte": 96, "bit": 6},
                    "esito_scarto_compilato": {"db": 9606, "byte": 144, "bit": 2},
                    "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 9606, "byte": 144, "bit": 5},
                    "stringatrice": {"db": 9606, "byte": 142, "length": 5},
                },
        },
        "Linea2": {
            "M308": {
                "trigger": {"db": 9606, "byte": 0, "bit": 4},
                "id_modulo": {"db": 9606, "byte": 2, "length": 20},
                "id_utente": {"db": 9606, "byte": 24, "length": 20},
                "fine_buona": {"db": 9606, "byte": 0, "bit": 6},
                "fine_scarto": {"db": 9606, "byte": 0, "bit": 7},
                "esito_scarto_compilato": {"db": 9606, "byte": 144, "bit": 0},
                "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 9606, "byte": 144, "bit": 3},
                "stringatrice": {"db": 9606, "byte": 46, "length": 5},
                "stazione_esclusa": {"db": 9606, "byte": 1, "bit": 3},
            },
            "M309": {
                "trigger": {"db": 9606, "byte": 48, "bit": 4},
                "id_modulo": {"db": 9606, "byte": 50, "length": 20},
                "id_utente": {"db": 9606, "byte": 72, "length": 20},
                "fine_buona": {"db": 9606, "byte": 48, "bit": 6},
                "fine_scarto": {"db": 9606, "byte": 48, "bit": 7},
                "esito_scarto_compilato": {"db": 9606, "byte": 144, "bit": 1},
                "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 9606, "byte": 144, "bit": 4},
                "stringatrice": {"db": 9606, "byte": 94, "length": 5},
                "stazione_esclusa": {"db": 9606, "byte": 49, "bit": 3},
            },
            "M326": {
                    "trigger": {"db": 9606, "byte": 96, "bit": 4},
                    "id_modulo": {"db": 9606, "byte": 98, "length": 20},
                    "id_utente": {"db": 9606, "byte": 120, "length": 20},
                    "fine_buona": {"db": 9606, "byte": 96, "bit": 5},
                    "fine_scarto": {"db": 9606, "byte": 96, "bit": 6},
                    "esito_scarto_compilato": {"db": 9606, "byte": 144, "bit": 2},
                    "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 9606, "byte": 144, "bit": 5},
                    "stringatrice": {"db": 9606, "byte": 142, "length": 5},
                },
        },
        "Linea3": {
            "M308": {
                "trigger": {"db": 9606, "byte": 0, "bit": 4},
                "id_modulo": {"db": 9606, "byte": 2, "length": 20},
                "id_utente": {"db": 9606, "byte": 24, "length": 20},
                "fine_buona": {"db": 9606, "byte": 0, "bit": 6},
                "fine_scarto": {"db": 9606, "byte": 0, "bit": 7},
                "esito_scarto_compilato": {"db": 9606, "byte": 144, "bit": 0},
                "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 9606, "byte": 144, "bit": 3},
                "stringatrice": {"db": 9606, "byte": 46, "length": 5},
                "stazione_esclusa": {"db": 9606, "byte": 1, "bit": 3},
            },
            "M309": {
                "trigger": {"db": 9606, "byte": 48, "bit": 4},
                "id_modulo": {"db": 9606, "byte": 50, "length": 20},
                "id_utente": {"db": 9606, "byte": 72, "length": 20},
                "fine_buona": {"db": 9606, "byte": 48, "bit": 6},
                "fine_scarto": {"db": 9606, "byte": 48, "bit": 7},
                "esito_scarto_compilato": {"db": 9606, "byte": 144, "bit": 1},
                "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 9606, "byte": 144, "bit": 4},
                "stringatrice": {"db": 9606, "byte": 94, "length": 5},
                "stazione_esclusa": {"db": 9606, "byte": 49, "bit": 3},
            },
            "M326": {
                    "trigger": {"db": 9606, "byte": 96, "bit": 4},
                    "id_modulo": {"db": 9606, "byte": 98, "length": 20},
                    "id_utente": {"db": 9606, "byte": 120, "length": 20},
                    "fine_buona": {"db": 9606, "byte": 96, "bit": 5},
                    "fine_scarto": {"db": 9606, "byte": 96, "bit": 6},
                    "esito_scarto_compilato": {"db": 9606, "byte": 144, "bit": 2},
                    "pezzo_salvato_su_DB_con_inizio_ciclo": {"db": 9606, "byte": 144, "bit": 5},
                    "stringatrice": {"db": 9606, "byte": 142, "length": 5},
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
                        "No Good da Bussing": {}, #NO GOOD DA BUSSING............... old: Non Lavorato da Telecamere
                        "Materiale Esterno su Celle": {},
                        "Bad Soldering": {},
                        "Passthroug": {},
                        "Poe in Eccesso": {}
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
                     "Lunghezza String Ribbon": {
                        f"Stringa[{i}]": None for i in range(1, 13)
                    },
                    "Graffio su Cella": {
                        f"Stringa[{i}]": None for i in range(1, 13)
                    },
                }
            }
        }
    }
}

TEMP_STORAGE_PATH = os.path.join("C:/IX-Monitor", "temp_data.json")
SETTINGS_PATH = os.path.join("C:/IX-Monitor", "settings.json")
# In-memory cache
REFRESHED_SETTINGS = {}
SESSION_TIMEOUT = 600  # 600 seconds = 10 minutes

BASE_DIR = Path("C:/IX-Monitor")
IMAGES_DIR = BASE_DIR / "images"
STATIONS_CONFIG_PATH = BASE_DIR / "stations.ini"

COLUMN_MAP = {
    "ID Modulo": "o.id_modulo",
    "Esito": "p.esito",
    "Data": "p.end_time",
    "Operatore": "p.operator_id",
    "Linea": "pl.display_name",
    "Stazione": "s.name",
    "Tempo Ciclo": "p.cycle_time"
}

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