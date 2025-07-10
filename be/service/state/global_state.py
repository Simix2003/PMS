from concurrent.futures import ThreadPoolExecutor
import os
from threading import Lock
from dotenv import load_dotenv, find_dotenv
from pymysql.cursors import DictCursor
from pymysqlpool import ConnectionPool

# Load .env variables
load_dotenv(find_dotenv())

# Environment-specific host
MYSQL_HOST = os.getenv("MYSQL_HOST", "db" if os.getenv("ENV_MODE") == "docker" else "localhost")
MYSQL_USER = os.getenv("MYSQL_USER", "root")
MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD", "Master36!")
MYSQL_DB = os.getenv("MYSQL_DB", "ix_monitor")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))

# Pool config
MYSQL_CONFIG = {
    "host": MYSQL_HOST,
    "user": MYSQL_USER,
    "password": MYSQL_PASSWORD,
    "database": MYSQL_DB,
    "port": MYSQL_PORT,
    "cursorclass": DictCursor,
    "autocommit": False,
}

# Connection pool (5 initial, 10 max)
mysql_pool = ConnectionPool(
    name="ix_monitor_pool",
    size=15,
    maxsize=25,
    pre_create_num=15,
    **MYSQL_CONFIG
)

# Thread-safe DB executor
executor = ThreadPoolExecutor(max_workers=10)

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
