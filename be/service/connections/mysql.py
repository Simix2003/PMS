import base64
from calendar import c
from datetime import datetime, timedelta
import json
import logging

logger = logging.getLogger(__name__)
from typing import Optional
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
VPF_DEFECT_ID_MAP = {
        0: 11,  # NG1
        1: 13,  # NG2
        2: 15,  # NG3
        3: 17,  # NG4
        4: 18,  # NG5
        5: 20,  # NG7.1
        6: 19,  # NG7
        7: 21,  # NG8
        8: 23,  # NG9
        9: 24,  # NG10
        10: 12, # NG1.1
        11: 14, # NG2.1
        12: 16, # NG3.1
        13: 22, # NG8.1
    }

AIN_DEFECT_ID_MAP = {
        0: 25,
        1: 26,
    }

ELL_DEFECT_MAP = {
    "NG PMS Elettroluminescenza": 6,  # 'Celle Rotte'
    "NG PMS Backlight": 10,           # 'Bad Soldering'
}

def log_pool_status(tag: str = ""):
    pool = global_state.mysql_pool
    try:
        total = pool.total_num      # total number of connections in the pool
        available = pool.available_num  # number of available (free) connections
        used = total - available    # number of used connections
        logger.info(f"[POOL] {tag} → used={used}, available={available}, total={total}")
    except Exception as e:
        logger.warning(f"[POOL] Failed to log status: {e}")

def get_mysql_connection():
    conn = global_state.mysql_pool.get_connection()
    #log_pool_status("GET")
    return conn

def get_line_name(line_id: int):
    """Return the production line name for a given ID."""
    with get_mysql_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute("SELECT name FROM production_lines WHERE id = %s", (line_id,))
            row = cursor.fetchone()
            return row["name"] if row else None

def load_channels_from_db() -> tuple[dict, dict]:
    """
    Load station configs from MySQL and return:
    1. CHANNELS dict: {line_name: {station_name: config_dict}}
    2. PLC DB RANGES dict: {(ip, slot): {db_number: {'min': x, 'max': y}}}
    """
    # ✅ Use connection pool (automatically reused and closed)
    with get_mysql_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, line_id, name, config, plc FROM stations")
            rows = cursor.fetchall()

    channels: dict = {}
    plc_db_ranges: dict[tuple[str, int], dict[int, dict[str, int]]] = {}

    for row in rows:
        if row["config"] is None:
            continue

        line_name = get_line_name(row["line_id"])
        if not line_name:
            continue

        try:
            cfg = json.loads(row["config"]) if isinstance(row["config"], str) else row["config"]
        except Exception:
            logger.warning(f"Invalid config JSON for station {row['name']}")
            continue

        plc_info = row.get("plc")
        if plc_info:
            try:
                cfg["plc"] = json.loads(plc_info) if isinstance(plc_info, str) else plc_info
            except Exception:
                cfg["plc"] = None

        # Save config
        channels.setdefault(line_name, {})[row["name"]] = cfg

        # Build DB range info
        plc = cfg.get("plc")
        if not plc:
            continue

        plc_key = (plc["ip"], plc.get("slot", 0))

        for key, field in cfg.items():
            if isinstance(field, dict) and "db" in field and "byte" in field:
                db = field["db"]
                byte = field["byte"]

                # Estimate memory size
                if "length" in field:
                    extra_bytes = field["length"] + 2
                elif key in {"inizio_fermo", "fine_fermo"}:
                    extra_bytes = 8
                elif key in {"evento_fermo", "stazione_fermo"}:
                    extra_bytes = 2
                else:
                    extra_bytes = 1

                db_range = plc_db_ranges.setdefault(plc_key, {}).setdefault(db, {"min": byte, "max": byte})
                db_range["min"] = min(db_range["min"], byte)
                db_range["max"] = max(db_range["max"], byte + extra_bytes)

    logger.debug(f"PLC_DB_RANGES: {plc_db_ranges}")
    return channels, plc_db_ranges

def insert_initial_production_data(data, station_name, connection, esito):
    """
    Inserts a production record using data available at cycle start.
    It sets the end_time to NULL and uses esito = 2 (in progress).
    If a production record for the same object_id and station (with esito = 2 and end_time IS NULL)
    is already present, that record is returned instead of inserting a new row.
    """
    try:
        with connection.cursor() as cursor:
            id_modulo = data.get("Id_Modulo")
            if not id_modulo:
                raise ValueError("Missing Id_Modulo")

            # Get line name (Linea1–5)
            linea_flags = data.get("Linea_in_Lavorazione", [False] * 5)
            try:
                linea_index = linea_flags.index(True) + 1
            except ValueError:
                raise ValueError("No active line found in Linea_in_Lavorazione")
            actual_line = f"Linea{linea_index}"

            # Fetch line_id + station_id together
            cursor.execute("""
                SELECT l.id AS line_id, s.id AS station_id
                FROM production_lines l
                JOIN stations s ON s.line_id = l.id
                WHERE l.name = %s AND s.name = %s
                LIMIT 1
            """, (actual_line, station_name))
            result = cursor.fetchone()
            if not result:
                raise ValueError(f"Line '{actual_line}' or Station '{station_name}' not found")
            line_id, station_id = result["line_id"], result["station_id"]

            # Insert (or confirm existence of) object
            cursor.execute("""
                INSERT INTO objects (id_modulo, creator_station_id)
                VALUES (%s, %s)
                ON DUPLICATE KEY UPDATE id_modulo = id_modulo
            """, (id_modulo, station_id))

            # Get object_id
            cursor.execute("SELECT id FROM objects WHERE id_modulo = %s", (id_modulo,))
            object_id = cursor.fetchone()["id"]

            # Check for existing partial production
            cursor.execute("""
                SELECT id FROM productions 
                WHERE object_id = %s AND station_id = %s AND esito = 2 AND end_time IS NULL
                ORDER BY start_time DESC LIMIT 1
            """, (object_id, station_id))
            existing = cursor.fetchone()
            if existing:
                production_id = existing["id"]
                connection.commit()
                logger.debug(f"✅ Existing production found: ID {production_id} for object {object_id}")
                return production_id

            # Determine last_station_id
            last_station_id = None
            str_flags = data.get("Lavorazione_Eseguita_Su_Stringatrice", [])
            if any(str_flags):
                str_index = str_flags.index(True) + 1
                str_name = f"STR{str_index:02d}"
                cursor.execute("""
                    SELECT id FROM stations WHERE name = %s AND line_id = %s
                """, (str_name, line_id))
                str_row = cursor.fetchone()
                if str_row:
                    last_station_id = str_row["id"]
            elif data.get("Last_Station"):
                last_station_id = data["Last_Station"]

            # Insert new production
            cursor.execute("""
                INSERT INTO productions (
                    object_id, station_id, start_time, end_time, esito, operator_id, last_station_id
                ) VALUES (%s, %s, %s, NULL, %s, %s, %s)
            """, (
                object_id,
                station_id,
                data.get("DataInizio"),
                esito,
                data.get("Id_Utente"),
                last_station_id
            ))
            production_id = cursor.lastrowid
            connection.commit()

            logger.debug(f"✅ New production inserted: ID {production_id} for object {object_id}")
            return production_id

    except Exception as e:
        connection.rollback()
        logger.error(f"❌ insert_initial_production_data error: {e}")
        return None

def update_production_final(production_id, data, station_name, connection, fine_buona, fine_scarto):
    try:
        with connection.cursor() as cursor:
            final_esito = 6 if data.get("Compilato_Su_Ipad_Scarto_Presente") else 1
            if station_name == "RMI01":
                final_esito = 5 if fine_buona else 6

            end_time = data.get("DataFine")

            # Perform conditional esito update only if esito == 2 OR station_name == 'RMI01'
            sql_update = """
                UPDATE productions 
                SET 
                    end_time = %s,
                    esito = CASE 
                        WHEN esito = 2 OR %s = 'RMI01' THEN %s 
                        ELSE esito 
                    END
                WHERE id = %s
            """
            cursor.execute(sql_update, (end_time, station_name, final_esito, production_id))
            affected = cursor.rowcount

            connection.commit()

            if affected == 0:
                logger.warning(f"No rows updated for production {production_id}")
                return False, None, None

            logger.debug(f"✅ Updated production {production_id}: end_time={end_time}, esito={final_esito}")
            return True, final_esito, end_time

    except Exception as e:
        connection.rollback()
        logger.error(f"Error updating production {production_id}: {e}")
        return False, None, None

def insert_defects(
    data,
    production_id,
    channel_id,
    line_name,
    cursor,
    from_vpf: bool = False,
    from_ain: bool = False,
    from_ell: bool = False
):
    # 1. Get defect categories mapping from DB
    cursor.execute("SELECT id, category FROM defects")
    cat_map = {row["category"]: row["id"] for row in cursor.fetchall()}

    # --- VPF Defects ---
    if from_vpf:
        flags = data.get("Tipo_NG_VPF", [])
        for idx, flag in enumerate(flags):
            if not flag or idx not in VPF_DEFECT_ID_MAP:
                continue
            defect_id = VPF_DEFECT_ID_MAP[idx]
            cursor.execute("""
                INSERT INTO object_defects (
                    production_id, defect_id, defect_type, stringa,
                    s_ribbon, i_ribbon, ribbon_lato, extra_data, photo_id
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                production_id,
                defect_id,
                f"VPF_NG_{idx+1}",
                None, None, None, None, None, None
            ))
        return

    # --- AIN Defects ---
    if from_ain:
        flags = data.get("Tipo_NG_AIN", [])
        for idx, flag in enumerate(flags):
            if not flag or idx not in AIN_DEFECT_ID_MAP:
                continue
            defect_id = AIN_DEFECT_ID_MAP[idx]
            defect_type = f"AIN_NG{idx + 2}"  # NG2 or NG3
            cursor.execute("""
                INSERT INTO object_defects (
                    production_id, defect_id, defect_type, stringa,
                    s_ribbon, i_ribbon, ribbon_lato, extra_data, photo_id
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                production_id,
                defect_id,
                defect_type,
                None, None, None, None, None, None
            ))
        return

    # --- ELL Defects ---
    mbj = data.get("MBJ_Defects")
    if from_ell and isinstance(mbj, dict):
        defects_to_insert = []
        cell_defects_data = mbj.get("cell_defects", {})
        cracked_cells = []
        bad_solder_cells = []

        if isinstance(cell_defects_data, list):
            for cell in cell_defects_data:
                defects = set(cell.get("defects", []))
                cell_index = f"x{cell.get('x', '?')}_y{cell.get('y', '?')}"
                if 7 in defects:
                    cracked_cells.append(cell_index)
                if 81 in defects:
                    bad_solder_cells.append(cell_index)

        # ➤ Insert Celle Rotte (defect_id=6)
        if cracked_cells:
            defects_to_insert.append({
                "production_id": production_id,
                "defect_id": 6,
                "defect_type": "ELL_MBJ",
                "i_ribbon": None,
                "stringa": None,
                "ribbon_lato": None,
                "s_ribbon": None,
                "extra_data": None,
                "photo_id": None
            })

        # ➤ Insert Bad Soldering (defect_id=10)
        if bad_solder_cells:
            defects_to_insert.append({
                "production_id": production_id,
                "defect_id": 10,
                "defect_type": "ELL_MBJ",
                "i_ribbon": None,
                "stringa": None,
                "ribbon_lato": None,
                "s_ribbon": None,
                "extra_data": None,
                "photo_id": None
            })

        if defects_to_insert:
            cursor.executemany("""
                INSERT INTO object_defects (
                    production_id, defect_id, defect_type, i_ribbon,
                    stringa, ribbon_lato, s_ribbon, extra_data, photo_id
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, [
                (
                    d["production_id"], d["defect_id"], d["defect_type"], d["i_ribbon"],
                    d["stringa"], d["ribbon_lato"], d["s_ribbon"], d["extra_data"], d["photo_id"]
                )
                for d in defects_to_insert
            ])
            cursor.connection.commit()
        return

    # --- Fallback: Vision-based Issues ---
    issues = get_latest_issues(line_name, channel_id)
    data["issues"] = issues

    for issue in issues:
        path = issue.get("path")
        image_base64 = issue.get("image_base64")
        if not path:
            continue

        category = detect_category(path)
        defect_id = cat_map.get(category, cat_map["Altro"])
        parsed = parse_issue_path(path, category)

        photo_id = None
        if image_base64:
            image_blob = compress_base64_to_jpeg_blob(image_base64, quality=70)
            if image_blob is None:
                raise ValueError(f"Invalid image for defect path: {path}")

            cursor.execute("INSERT INTO photos (photo) VALUES (%s)", (pymysql.Binary(image_blob),))
            photo_id = cursor.lastrowid

        cursor.execute("""
            INSERT INTO object_defects (
                production_id, defect_id, defect_type, stringa,
                s_ribbon, i_ribbon, ribbon_lato, extra_data, photo_id
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            production_id,
            defect_id,
            parsed["defect_type"],
            parsed["stringa"],
            parsed["s_ribbon"],
            parsed["i_ribbon"],
            parsed["ribbon_lato"],
            parsed["extra_data"],
            photo_id
        ))

def update_esito(esito: int, production_id: int, cursor, connection):
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
        logger.error(f"❌ Error updating esito for production_id={production_id}: {e}")
        return False
   
def save_warning_on_mysql(
    warning_payload: dict,
    mysql_conn,
    target_station: dict,
    defect_name: str,
    source_station: dict,
    suppress_on_source: bool = False,
    image_blob: Optional[bytes] = None
):
    try:
        source_station_name = source_station["display_name"] if isinstance(source_station, dict) else str(source_station)

        with mysql_conn.cursor() as cursor:
            # Insert image if present
            photo_id = None
            if image_blob:
                cursor.execute("INSERT INTO photos (photo) VALUES (%s)", (pymysql.Binary(image_blob),))
                photo_id = cursor.lastrowid

            # Insert warning with photo_id
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
                    photo_id
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
                photo_id
            ))
            mysql_conn.commit()
            inserted_id = cursor.lastrowid
            logger.debug(
                f"💾 Warning saved for {target_station['name']} (from {source_station_name}) with ID {inserted_id}"
            )
            return inserted_id

    except Exception as e:
        logger.error(f"❌ Failed to save warning to MySQL: {e}")
        return None

async def check_stringatrice_warnings(line_name: str, mysql_conn, settings):
    try:
        logger.debug(f"[{line_name}] ▶️ Starting check_stringatrice_warnings")

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
                logger.warning(f"[{line_name}] ⚠️ No production data found.")
                return

            prod_id = last_prod["production_id"]
            object_id = last_prod["object_id"]
            last_station_id = last_prod["last_station_id"]
            station_id = last_prod["station_id"]

            logger.debug(f"[{line_name}] Last production: prod_id={prod_id}, object_id={object_id}, last_station_id={last_station_id}, station_id={station_id}")

            if last_station_id is None:
                logger.warning(f"[{line_name}] ⛔ Skipping: last_station_id is None")
                return

            # Step 2: Get source station debug
            cursor.execute("""
                SELECT s.name, s.display_name, pl.name AS line_name
                FROM stations s
                JOIN production_lines pl ON s.line_id = pl.id
                WHERE s.id = %s
            """, (station_id,))
            source_station = cursor.fetchone()
            if not source_station:
                logger.warning(f"[{line_name}] ⚠️ Source station ID {station_id} not found")
                return

            # Step 3: Get last station debug
            cursor.execute("""
                SELECT s.name, s.display_name, pl.name AS line_name
                FROM stations s
                JOIN production_lines pl ON s.line_id = pl.id
                WHERE s.id = %s
            """, (last_station_id,))
            station = cursor.fetchone()

            if not station:
                logger.warning(f"[{line_name}] ⚠️ Last station ID {last_station_id} not found")
                return

            full_station_id = f"{station['line_name']}.{station['name']}"
            logger.debug(f"[{line_name}] Full station ID for check: {full_station_id}")

            # Step 4: Get last 24 recent productions from same source
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

            logger.debug(f"[{line_name}] Found {len(recent_productions)} recent productions from last_station_id={last_station_id}")

            # Step 4.1: Add current production separately
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

            if not current:
                logger.warning(f"[{line_name}] ❗ No defect data found for current production ID {prod_id}")
                return

            productions = [current] + recent_productions

            # Step 5: Analyze for each defect
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

                logger.debug(f"[{full_station_id}] Checking defect '{defect_name}' in window={window}, threshold={threshold}, consecutive_limit={consecutive_limit}, enabled={enable_consecutive}")

                for i, p in enumerate(productions[:window]):
                    categories = p.get("defect_categories", "")
                    customs = p.get("custom_defects", "")
                    all_defects = (categories or "").split(",") + (customs or "").split(",")
                    all_defects = [d.strip() for d in all_defects if d]

                    logger.debug(f"[{full_station_id}] Prod {p['production_id']}: defects={all_defects}")

                    if defect_name in all_defects:
                        count += 1
                        consecutive += 1
                        logger.debug(f"[{full_station_id}] Defect match {defect_name}: count={count}, consecutive={consecutive}")

                        if enable_consecutive and consecutive >= consecutive_limit:
                            logger.warning(f"[{full_station_id}] 🔴 Consecutive KO warning for '{defect_name}' — {consecutive}/{consecutive_limit}")

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
                                    cursor.execute("""
                                        SELECT w.*, p.photo
                                        FROM stringatrice_warnings w
                                        LEFT JOIN photos p ON w.photo_id = p.id
                                        WHERE w.id = %s
                                    """, (inserted_id,))
                                    row = cursor.fetchone()
                                    if row:
                                        row["suppress_on_source"] = bool(int(row.get("suppress_on_source", 0)))
                                        if row.get("photo") is not None:
                                            row["photo"] = base64.b64encode(row["photo"]).decode("utf-8")

                                        await broadcast_stringatrice_warning(row["line_name"], row)
                                        logger.debug(f"[{full_station_id}] 📡 Broadcasted consecutive warning for {defect_name}")

                            break  # stop checking if already triggered
                    else:
                        consecutive = 0

                if count >= threshold:
                    logger.warning(f"[{full_station_id}] 🔴 Threshold warning for '{defect_name}' — {count}/{threshold}")

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
                            cursor.execute("""
                                SELECT w.*, p.photo
                                FROM stringatrice_warnings w
                                LEFT JOIN photos p ON w.photo_id = p.id
                                WHERE w.id = %s
                            """, (inserted_id,))
                            row = cursor.fetchone()
                            if row:
                                row["suppress_on_source"] = bool(int(row.get("suppress_on_source", 0)))
                                if row.get("photo") is not None:
                                    row["photo"] = base64.b64encode(row["photo"]).decode("utf-8")

                                await broadcast_stringatrice_warning(row["line_name"], row)
                                logger.debug(f"[{full_station_id}] 📡 Broadcasted threshold warning for {defect_name}")

        logger.debug(f"[{line_name}] ✅ check_stringatrice_warnings completed")

    except Exception as e:
        logger.exception(f"[{line_name}] ❌ Error in check_stringatrice_warnings: {e}")

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
        logger.error(f"❌ Failed to retrieve last station for {id_modulo}: {e}")
        return None

def check_existing_production(id_modulo, station: str, timestamp: datetime, conn) -> bool:
    """Check if a production record for this module, station, and time already exists."""
    with conn.cursor() as cursor:
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
    return result is not None

# Create full stop + first level entry
def create_stop(
    station_id: int,
    start_time,
    end_time,
    operator_id: str,
    stop_type: str,
    reason: str,
    status: str,
    linked_production_id: Optional[int],
    conn
) -> int:
    """Insert a new stop and its initial status level."""
    with conn.cursor() as cursor:
        # Insert stop
        query_stop = """
            INSERT INTO stops (station_id, start_time, end_time, operator_id, type, reason, status, linked_production_id)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(query_stop, (station_id, start_time, end_time, operator_id, stop_type, reason, status, linked_production_id))
        stop_id = cursor.lastrowid

        # Insert first status level
        query_level = """
            INSERT INTO stop_status_changes (stop_id, status, changed_at, operator_id)
            VALUES (%s, %s, %s, %s)
        """
        cursor.execute(query_level, (stop_id, status, start_time, operator_id))

    conn.commit()
    return stop_id

def update_stop_status(stop_id, new_status, changed_at, operator_id, conn):
    with conn.cursor() as cursor:
        logger.debug("➡ Updating main stops table...")

        sql = """
            UPDATE stops 
            SET status=%s, operator_id=%s
            WHERE id=%s
        """
        cursor.execute(sql, (new_status, operator_id, stop_id))

        # Insert new status change row into history table
        insert_level = """
            INSERT INTO stop_status_changes (stop_id, status, changed_at, operator_id)
            VALUES (%s, %s, %s, %s)
        """
        cursor.execute(insert_level, (stop_id, new_status, changed_at, operator_id))

        if new_status == "CLOSED":
            cursor.execute("SELECT start_time FROM stops WHERE id=%s", (stop_id,))
            row = cursor.fetchone()

            if not row or not row['start_time']:
                raise Exception(f"Start time not found for stop_id={stop_id}")

            start_time = row['start_time']

            end_time = datetime.now()

            # Only update end_time — stop_time is auto-generated
            cursor.execute("""
                UPDATE stops 
                SET end_time=%s
                WHERE id=%s
            """, (end_time, stop_id))

    conn.commit()

def update_stop_reason(stop_id: int, reason: str, conn):
    """Update the reason/title of a stop."""
    with conn.cursor() as cursor:
        cursor.execute(
            """
            UPDATE stops
            SET reason=%s
            WHERE id=%s
            """,
            (reason, stop_id),
        )
    conn.commit()

# Example shift configuration
SHIFT_DURATION_HOURS = 8
SHIFT_START_TIMES = ["06:00", "14:00", "22:00"]

def get_shift_start(now: datetime):
    date = now.date()
    for shift_time in reversed(SHIFT_START_TIMES):
        shift_hour, shift_minute = map(int, shift_time.split(":"))
        shift_start = datetime(date.year, date.month, date.day, shift_hour, shift_minute)
        if now >= shift_start:
            return shift_start
    # if now before first shift of day
    yesterday = date - timedelta(days=1)
    shift_hour, shift_minute = map(int, SHIFT_START_TIMES[-1].split(":"))
    return datetime(yesterday.year, yesterday.month, yesterday.day, shift_hour, shift_minute)

def get_stops_for_station(station_id: int, conn, shifts_back: int = 3):
    """Get stops for a station within last N shifts."""
    now = datetime.now()
    current_shift_start = get_shift_start(now)
    target_start_time = current_shift_start - timedelta(hours=SHIFT_DURATION_HOURS * (shifts_back-1))

    with conn.cursor() as cursor:
        query = """
        SELECT id, station_id, start_time, end_time, stop_time, operator_id, type, reason, status, linked_production_id, created_at
        FROM stops
        WHERE station_id = %s AND type = %s AND start_time >= %s
        ORDER BY start_time DESC
        """
        params = (station_id, "ESCALATION", target_start_time)
        cursor.execute(query, params)
        results = cursor.fetchall()
    return results

# Get full stop with escalation levels
def get_stop_with_levels(stop_id: int, conn):
    """Fetch stop info + all its levels."""
    with conn.cursor() as cursor:

        stop_query = """
            SELECT id, station_id, start_time, end_time, stop_time, operator_id, type, reason, status, linked_production_id, created_at
            FROM stops
            WHERE id = %s
        """
        cursor.execute(stop_query, (stop_id,))
        stop_data = cursor.fetchone()

        levels_query = """
            SELECT id, status, changed_at, operator_id, created_at
            FROM stop_status_changes
            WHERE stop_id = %s
            ORDER BY changed_at ASC
        """
        cursor.execute(levels_query, (stop_id,))
        levels_data = cursor.fetchall()

    return {
        "stop": stop_data,
        "levels": levels_data
    }

# Delete stop fully
def delete_stop(stop_id: int, conn):
    """Delete stop and its levels (full cleanup)."""
    with conn.cursor() as cursor:
        cursor.execute("DELETE FROM stop_status_changes WHERE stop_id = %s", (stop_id,))
        cursor.execute("DELETE FROM stops WHERE id = %s", (stop_id,))
        conn.commit()
