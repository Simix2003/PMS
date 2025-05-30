from pymysql.connections import Connection
mysql_connection: Connection | None = None


plc_connections = {}
subscriptions = {}
trigger_timestamps = {}
incomplete_productions = {}  # Tracks production_id per station (e.g., "Linea1.MIN01")
stop_threads = {}
passato_flags = {}
debug_triggers = {}  # Dict[str, bool], e.g., "LineaB.M309": True
debug_triggers_fisici = {}  # Dict[str, bool], e.g., "LineaB.M309": True
debug_moduli = {}    # Dict[str, str], e.g., "LineaB.M309": "3SBHBGHC25412345"
expected_moduli = {}  # Dict[str, str] — stores expected Id_Modulo per full_station_id
xml_index = {}  # key: id_modulo → value: list of dicts with start_time, file_path, etc.


