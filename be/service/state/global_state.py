from concurrent.futures import ThreadPoolExecutor
import os
from threading import Lock, RLock
from typing import List
from dotenv import load_dotenv, find_dotenv
from pymysql.cursors import DictCursor
from pymysqlpool import ConnectionPool
from service.helpers.db_queue import DBWriteQueue
from collections import defaultdict
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.config import ZONE_SOURCES

# Load .env variables
load_dotenv(find_dotenv())

# Environment-specific host
MYSQL_HOST = os.getenv("MYSQL_HOST", "db" if os.getenv("ENV_MODE") == "docker" else "localhost")
MYSQL_USER = os.getenv("MYSQL_USER", "root")
MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD", "Master36!")
MYSQL_DB = os.getenv("MYSQL_DB", "ix_monitor")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))

# Shared pool config
MYSQL_CONFIG = {
    "host": MYSQL_HOST,
    "user": MYSQL_USER,
    "password": MYSQL_PASSWORD,
    "database": MYSQL_DB,
    "port": MYSQL_PORT,
    "cursorclass": DictCursor,
}

# Write pool – smaller, transactional
MYSQL_WRITE_CONFIG = {"autocommit": False, **MYSQL_CONFIG}
mysql_write_pool = ConnectionPool(
    name="ix_monitor_write_pool",
    size=5,
    maxsize=10,
    pre_create_num=5,
    **MYSQL_WRITE_CONFIG
)

# Read pool – larger, autocommit enabled
MYSQL_READ_CONFIG = {"autocommit": True, **MYSQL_CONFIG}
mysql_read_pool = ConnectionPool(
    name="ix_monitor_read_pool",
    size=15,
    maxsize=30,
    pre_create_num=15,
    **MYSQL_READ_CONFIG
)

zone_locks = {
    "ELL": RLock(),
    "AIN": RLock(),
    "VPF": RLock(),
    "STR": RLock()
}

STATION_TO_ZONES = defaultdict(set)  #use set instead of list for unique zones

for zone, cfg in ZONE_SOURCES.items():
    for v in cfg.values():
        if isinstance(v, list):
            for station in v:
                STATION_TO_ZONES[station].add(zone)

def get_zones_from_station(station: str) -> List[str]:
    return list(STATION_TO_ZONES.get(station, []))

# Thread-safe DB executor
executor = ThreadPoolExecutor(max_workers=20)
plc_executor = ThreadPoolExecutor(max_workers=30)

# Asynchronous queue for deferred DB writes
db_write_queue = DBWriteQueue()

# Global runtime state
plc_connections = {}
subscriptions = {}
trigger_timestamps = {}
incomplete_productions = {}
stop_threads = {}
fine_true_passato_flags = {}
fine_false_passato_flags = {}
inizio_true_passato_flags = {}
inizio_false_passato_flags = {}
escalation_websockets = set()

# Debug tools
debug_triggers = {}
debug_trigger_NG = {}
debug_trigger_G = {}
reentryDebug = {}
debug_moduli = {}
expected_moduli = {}
xml_index = {}

# Visual snapshot state
visual_data: dict[str, dict] = {}
visual_data_lock = Lock()
last_sent: dict[str, dict] = {}

db_range_cache: dict[str, tuple[int, int]] = {}

