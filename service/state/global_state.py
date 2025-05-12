from pymysql.connections import Connection
mysql_connection: Connection | None = None


plc_connections = {}
subscriptions = {}
trigger_timestamps = {}
incomplete_productions = {}  # Tracks production_id per station (e.g., "Linea1.M308")
stop_threads = {}
passato_flags = {}


