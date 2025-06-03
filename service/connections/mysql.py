import base64
from datetime import datetime
import logging
import pymysql
from pymysql.cursors import DictCursor

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.temp_data import get_latest_issues
from service.helpers.helpers import detect_category, parse_issue_path, compress_base64_to_jpeg_blob
from service.routes.broadcast import broadcast_stringatrice_warning
from service.state import global_state

# ---------------- MYSQL ----------------

def get_mysql_connection():
    """
    Always return a valid, live MySQL connection stored in global_state.

    • Creates the connection on first call
    • Reconnects if the existing one is dead (e.g. MySQL timeout)
    """
    try:
        conn = global_state.mysql_connection

        # First use or explicitly closed
        if conn is None or not conn.open:
            raise RuntimeError("No active MySQL connection")

        # Reconnect if socket was dropped (e.g. idle too long)
        conn.ping(reconnect=True)
        return conn

    except Exception as e:
        logging.warning(f"MySQL connection lost or not available. Reconnecting… ({e})")
        conn = pymysql.connect(
            host="localhost",
            user="root",
            password="Master36!",
            database="ix_monitor",
            port=3306,
            cursorclass=DictCursor,
            autocommit=False,
            charset="utf8mb4"
        )
        global_state.mysql_connection = conn
        logging.info("✅ MySQL reconnected")
        return conn

async def insert_initial_production_data(data, station_name, connection, esito):
    """
    Inserts a production record using data available at cycle start.
    It sets the end_time to NULL and uses esito = 2 (in progress).
    If a production record for the same object_id and station (with esito = 2 and end_time IS NULL)
    is already present, that record is returned instead of inserting a new row.
    """
    try:
        with connection.cursor() as cursor:
            id_modulo = data.get("Id_Modulo")
            # Determine line from the 'Linea_in_Lavorazione' list.
            linea_index = data.get("Linea_in_Lavorazione", [False] * 5).index(True) + 1
            actual_line = f"Linea{linea_index}"

            # Get line_id.
            cursor.execute("SELECT id FROM production_lines WHERE name = %s", (actual_line,))
            line_row = cursor.fetchone()
            if not line_row:
                raise ValueError(f"{actual_line} not found in production_lines")
            line_id = line_row["id"]

            # Get station id using station_name and line_id.
            cursor.execute("SELECT id FROM stations WHERE name = %s AND line_id = %s", (station_name, line_id))
            station_row = cursor.fetchone()
            if not station_row:
                raise ValueError(f"Station '{station_name}' not found for {actual_line}")
            real_station_id = station_row["id"]

            # Insert into objects table.
            sql_insert_object = """
                INSERT INTO objects (id_modulo, creator_station_id)
                VALUES (%s, %s)
                ON DUPLICATE KEY UPDATE id_modulo = id_modulo
            """
            cursor.execute(sql_insert_object, (id_modulo, real_station_id))

            # Get object_id.
            cursor.execute("SELECT id FROM objects WHERE id_modulo = %s", (id_modulo,))
            object_id = cursor.fetchone()["id"]

            # ☆ Check for existing partial production record:
            cursor.execute("""
                SELECT id FROM productions 
                WHERE object_id = %s 
                  AND station_id = %s 
                  AND esito = 2 
                  AND end_time IS NULL
                ORDER BY start_time DESC
                LIMIT 1
            """, (object_id, real_station_id))
            existing_prod = cursor.fetchone()
            if existing_prod:
                production_id = existing_prod["id"]
                connection.commit()
                logging.info(f"Production record already exists: ID {production_id} for object {object_id}")
                return production_id

            # Retrieve last_station_id from stringatrice if available.
            last_station_id = None

            # Priority 1: From stringatrice flags
            str_flags = data.get("Lavorazione_Eseguita_Su_Stringatrice", [])
            if any(str_flags):
                stringatrice_index = str_flags.index(True) + 1
                stringatrice_name = f"Str{stringatrice_index}"
                cursor.execute(
                    "SELECT id FROM stations WHERE name = %s AND line_id = %s",
                    (stringatrice_name, line_id)
                )
                str_row = cursor.fetchone()
                if str_row:
                    last_station_id = str_row["id"]

            # Priority 2: From Last_Station (only if no stringatrice found)
            if not last_station_id and data.get("Last_Station"):
                last_station_id = data['Last_Station']

            # Insert into productions table with esito = 2 (in progress) and no end_time.
            sql_productions = """
                INSERT INTO productions (
                    object_id, station_id, start_time, end_time, esito, operator_id, last_station_id
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """
            cursor.execute(sql_productions, (
                object_id,
                real_station_id,
                data.get("DataInizio"),  # starting timestamp
                None,                     # end_time left as NULL
                esito,                        # esito 2 means "in progress", 4 means Escluso
                data.get("Id_Utente"),
                last_station_id
            ))
            production_id = cursor.lastrowid

            connection.commit()
            logging.info(f"Initial production inserted: ID {production_id} for object {object_id}")
            return production_id

    except Exception as e:
        connection.rollback()
        logging.error(f"Error inserting initial production data: {e}")
        return None

async def update_production_final(production_id, data, station_name, connection, fine_buona, fine_scarto):
    """
    Always update end_time. Update esito only if the current value is 2.
    """
    try:
        with connection.cursor() as cursor:
            # Step 1: Read current esito
            cursor.execute("SELECT esito FROM productions WHERE id = %s", (production_id,))
            row = cursor.fetchone()
            if not row:
                logging.warning(f"No production found with ID {production_id}")
                return False

            current_esito = row["esito"]
            final_esito = 6 if data.get("Compilato_Su_Ipad_Scarto_Presente") else 1
            if station_name == "RMI01":
                final_esito = 5 if fine_buona else 6
            end_time = data.get("DataFine")

            # Step 2: Conditional update
            if current_esito == 2 or station_name == "RMI01":

                sql_update = """
                    UPDATE productions 
                    SET end_time = %s, esito = %s 
                    WHERE id = %s
                """
                cursor.execute(sql_update, (end_time, final_esito, production_id))
                logging.info(f"✅ Updated end_time + esito ({final_esito}) for production {production_id}")
            else:
                sql_update = """
                    UPDATE productions 
                    SET end_time = %s 
                    WHERE id = %s
                """
                cursor.execute(sql_update, (end_time, production_id))
                logging.info(f"ℹ️ Updated only end_time for production {production_id} (esito was already {current_esito})")

            connection.commit()
            return True

    except Exception as e:
        connection.rollback()
        logging.error(f"Error updating production {production_id}: {e}")
        return False

async def insert_defects(data, production_id, channel_id, line_name, cursor):
    # 1. Get defects mapping from DB.
    cursor.execute("SELECT id, category FROM defects")
    cat_map = {row["category"]: row["id"] for row in cursor.fetchall()}

    # 2. Load the issues from temporary storage using the proper line name.
    issues = get_latest_issues(line_name, channel_id)
    data["issues"] = issues  # Inject into data if needed later.
    
    # 3. Insert each defect
    for issue in issues:
        path = issue.get("path")
        image_base64 = issue.get("image_base64")

        if not path:
            continue  # skip invalid

        category = detect_category(path)
        defect_id = cat_map.get(category, cat_map["Altro"])
        parsed = parse_issue_path(path, category)

        # Decode image if present
        if image_base64:
            image_blob = compress_base64_to_jpeg_blob(image_base64, quality=70)
            if image_blob is None:
                raise ValueError(f"Invalid image for defect path: {path}")
        else:
            image_blob = None

        sql = """
            INSERT INTO object_defects (
                production_id, defect_id, defect_type, stringa,
                s_ribbon, i_ribbon, ribbon_lato, extra_data, photo
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(sql, (
            production_id,
            defect_id,
            parsed["defect_type"],
            parsed["stringa"],
            parsed["s_ribbon"],
            parsed["i_ribbon"],
            parsed["ribbon_lato"],
            parsed["extra_data"],
            image_blob
        ))

async def update_esito(esito: int, production_id: int, cursor, connection):
    """
    Update the 'esito' field in the productions table for the given production ID.
    """
    try:
        sql_update = """
            UPDATE productions 
            SET esito = %s 
            WHERE id = %s
        """
        cursor.execute(sql_update, (esito, production_id))
        return True
    except Exception as e:
        if connection:
            connection.rollback()
        logging.error(f"❌ Error updating esito for production_id={production_id}: {e}")
        return False
   
def save_warning_on_mysql(
    warning_payload: dict,
    mysql_conn,
    target_station: dict,
    defect_name: str,
    source_station: dict,
    suppress_on_source: bool = False,
    image_blob: bytes = None # type: ignore
):
    try:
        source_station_name = source_station["display_name"] if isinstance(source_station, dict) else str(source_station)

        with mysql_conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO stringatrice_warnings (
                    line_name,
                    station_name,
                    station_display,
                    defect,
                    type,
                    value,
                    limit_value,
                    timestamp,
                    source_station,
                    suppress_on_source,
                    photo
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                target_station["line_name"],
                target_station["name"],
                target_station["display_name"],
                defect_name,
                warning_payload["type"],
                warning_payload["value"],
                warning_payload["limit"],
                datetime.now(),
                source_station_name,
                suppress_on_source,
                image_blob
            ))
            mysql_conn.commit()
            inserted_id = cursor.lastrowid
            print(f"💾 Warning saved for {target_station['name']} (from {source_station_name}) with ID {inserted_id}")
            return inserted_id
    except Exception as e:
        logging.error(f"❌ Failed to save warning to MySQL: {e}")
        return None

async def check_stringatrice_warnings(line_name: str, mysql_conn, settings):
    try:
        with mysql_conn.cursor() as cursor:
            # Step 1: Get the most recent production
            cursor.execute("""
                SELECT p.id AS production_id, p.object_id, p.last_station_id, p.station_id, p.end_time
                FROM productions p
                ORDER BY p.id DESC
                LIMIT 1
            """)
            last_prod = cursor.fetchone()

            if not last_prod:
                print("⚠️ No production data found.")
                return

            prod_id = last_prod["production_id"]
            object_id = last_prod["object_id"]
            last_station_id = last_prod["last_station_id"]
            station_id = last_prod["station_id"]

            if last_station_id is None:
                return

            # Step 2: Get source station info
            cursor.execute("""
                SELECT s.name, s.display_name, pl.name AS line_name
                FROM stations s
                JOIN production_lines pl ON s.line_id = pl.id
                WHERE s.id = %s
            """, (station_id,))
            source_station = cursor.fetchone()

            # Step 3: Get last station info
            cursor.execute("""
                SELECT s.name, s.display_name, pl.name AS line_name
                FROM stations s
                JOIN production_lines pl ON s.line_id = pl.id
                WHERE s.id = %s
            """, (last_station_id,))
            station = cursor.fetchone()

            if not station:
                return

            full_station_id = f"{station['line_name']}.{station['name']}"

            # Step 4: Fetch the most recent 24 productions by end_time
            cursor.execute("""
                SELECT 
                    p.id AS production_id, 
                    p.object_id, 
                    p.end_time, 
                    p.esito,
                    GROUP_CONCAT(DISTINCT d.category) AS defect_categories,
                    GROUP_CONCAT(DISTINCT od.defect_type) AS custom_defects
                FROM productions p
                LEFT JOIN object_defects od ON p.id = od.production_id
                LEFT JOIN defects d ON od.defect_id = d.id
                WHERE p.last_station_id = %s AND p.id != %s
                GROUP BY p.id
                ORDER BY p.end_time DESC
                LIMIT 24
            """, (last_station_id, prod_id))
            recent_productions = cursor.fetchall()

            # Step 4.1: Fetch defect categories for the most recent one manually
            cursor.execute("""
                SELECT 
                    p.id AS production_id, 
                    p.object_id, 
                    p.end_time, 
                    p.esito,
                    GROUP_CONCAT(DISTINCT d.category) AS defect_categories,
                    GROUP_CONCAT(DISTINCT od.defect_type) AS custom_defects
                FROM productions p
                LEFT JOIN object_defects od ON p.id = od.production_id
                LEFT JOIN defects d ON od.defect_id = d.id
                WHERE p.id = %s
                GROUP BY p.id
            """, (prod_id,))
            current = cursor.fetchone()

            # Combine them (manual entry first)
            productions = [current] + recent_productions

            # Step 5: Analyze based on settings
            thresholds = settings.get("thresholds", {})
            moduli_window = settings.get("moduli_window", {})
            enable_consecutive_ko = settings.get("enable_consecutive_ko", {})
            consecutive_ko_limit = settings.get("consecutive_ko_limit", {})

            for defect_name in thresholds:
                window = moduli_window.get(defect_name, 10)
                threshold = thresholds[defect_name]
                enable_consecutive = enable_consecutive_ko.get(defect_name, False)
                consecutive_limit = consecutive_ko_limit.get(defect_name, 2)

                count = 0
                consecutive = 0

                for i, p in enumerate(productions[:window]):
                    categories = p.get("defect_categories", "")
                    customs = p.get("custom_defects", "")
                    all_defects = (categories or "").split(",") + (customs or "").split(",")
                    all_defects = [d.strip() for d in all_defects if d]

                    if defect_name in all_defects:
                        count += 1
                        consecutive += 1

                        if enable_consecutive and consecutive >= consecutive_limit:
                            print(f"🔴 Warning (consecutive KO)")
                            warning_payload = {
                                "timestamp": datetime.now().isoformat(),
                                "station_name": station["name"],
                                "station_display": station["display_name"],
                                "line_name": station["line_name"],
                                "defect": defect_name,
                                "type": "consecutive",
                                "value": consecutive,
                                "limit": consecutive_limit,
                                "source_station": source_station['name']
                            }
                            inserted_id = save_warning_on_mysql(warning_payload, mysql_conn, station, defect_name, source_station, False)
                            if inserted_id:
                                with mysql_conn.cursor(DictCursor) as cursor:
                                    cursor.execute("SELECT * FROM stringatrice_warnings WHERE id = %s", (inserted_id,))
                                    row = cursor.fetchone()
                                    if row:
                                        row["suppress_on_source"] = bool(int(row.get("suppress_on_source", 0)))
                                        if row.get("photo") is not None:
                                            row["photo"] = base64.b64encode(row["photo"]).decode("utf-8")

                                        await broadcast_stringatrice_warning(row["line_name"], row)


                            break  # ✅ Optional: stop loop after warning
                    else:
                        consecutive = 0

                # ✅ Check threshold AFTER the loop
                if count >= threshold:
                    print(f"🔴 Warning (threshold)")
                    warning_payload = {
                        "timestamp": datetime.now().isoformat(),
                        "station_name": station["name"],
                        "station_display": station["display_name"],
                        "line_name": station["line_name"],
                        "defect": defect_name,
                        "type": "threshold",
                        "value": count,
                        "limit": threshold,
                        "source_station": source_station['name']
                    }
                    inserted_id = save_warning_on_mysql(warning_payload, mysql_conn, station, defect_name, source_station, False)
                    if inserted_id:
                        with mysql_conn.cursor(DictCursor) as cursor:
                            cursor.execute("SELECT * FROM stringatrice_warnings WHERE id = %s", (inserted_id,))
                            row = cursor.fetchone()
                            if row:
                                row["suppress_on_source"] = bool(int(row.get("suppress_on_source", 0)))
                                if row.get("photo") is not None:
                                    row["photo"] = base64.b64encode(row["photo"]).decode("utf-8")

                                await broadcast_stringatrice_warning(row["line_name"], row)

    except Exception as e:
        logging.error(f"❌ Error fetching last production origin: {e}")

def get_last_station_id_from_productions(id_modulo, connection):
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT p.station_id
                FROM productions p
                JOIN objects o ON p.object_id = o.id
                WHERE o.id_modulo = %s AND p.end_time IS NOT NULL
                ORDER BY p.end_time DESC
                LIMIT 1
            """, (id_modulo,))
            row = cursor.fetchone()
            return row["station_id"] if row else None
    except Exception as e:
        logging.error(f"❌ Failed to retrieve last station for {id_modulo}: {e}")
        return None

def check_existing_production(id_modulo, station: str, timestamp: datetime, conn) -> bool:
    """Check if a production record for this module, station, and time already exists."""
    cursor = conn.cursor() 
    query = """
        SELECT 1 FROM productions p
        JOIN stations s ON p.last_station_id = s.id
        JOIN objects o ON p.object_id = o.id
        WHERE o.id_modulo = %s
          AND s.name = %s
          AND ABS(TIMESTAMPDIFF(SECOND, p.start_time, %s)) < 10
        LIMIT 1;
    """
    cursor.execute(query, (id_modulo, station, timestamp))
    result = cursor.fetchone()
    cursor.close()
    return result is not None