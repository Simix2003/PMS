# service/helpers/visuals/compute.py
from datetime import datetime
import logging
import os
import sys
from collections import defaultdict
from typing import Dict
from statistics import median
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection
from service.helpers.visuals.visual_helper import compute_yield, count_unique_ng_objects, count_unique_objects, count_unique_objects_r0, get_last_8h_bins, get_previous_shifts, get_shift_window, time_to_seconds
from service.config.config import ZONE_SOURCES

logger = logging.getLogger(__name__)

def compute_zone_snapshot(zone: str, now: datetime | None = None) -> dict:
    try:
        if now is None:
            now = datetime.now()
        #now = now - timedelta(days=14)

        if zone == "VPF":
            return _compute_snapshot_vpf(now)
        elif zone == "AIN":
            return _compute_snapshot_ain(now)
        elif zone == "ELL":
            return _compute_snapshot_ell(now)
        elif zone == "STR":
            return _compute_snapshot_str(now)
        elif zone == "LMN":
            return _compute_snapshot_lmn(now)
        elif zone == "DELTAMAX":
            return _compute_snapshot_deltamax(now)
        else:
            raise ValueError(f"Unknown zone: {zone}")

    except Exception as e:
        logger.exception(f"compute_zone_snapshot() FAILED for zone={zone}: {e}")
        raise

# ─────────────────────────────────────────────────────────────────────────────
def _compute_snapshot_ain(now: datetime) -> dict:
    try:
        if now is None:
            now = datetime.now()

        hour_start = now.replace(minute=0, second=0, microsecond=0)
        cfg = ZONE_SOURCES["AIN"]

        shift_start, shift_end = get_shift_window(now)

        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                # -------- current shift totals / yield ----------
                s1_in  = count_unique_objects(cursor, cfg["station_1_in"],  shift_start, shift_end, "all")
                s2_in  = count_unique_objects(cursor, cfg["station_2_in"],  shift_start, shift_end, "all")
                s1_ng  = count_unique_objects(cursor, cfg["station_1_out_ng"], shift_start, shift_end, "ng")
                s2_ng  = count_unique_objects(cursor, cfg["station_2_out_ng"], shift_start, shift_end, "ng")
                s1_g   = s1_in - s1_ng
                s2_g   = s2_in - s2_ng
                s1_y   = compute_yield(s1_g, s1_ng)
                s2_y   = compute_yield(s2_g, s2_ng)

                # -------- last 3 shifts yield + throughput -------
                s1_yield_shifts, s2_yield_shifts, shift_throughput = [], [], []
                qc_stations = cfg["station_1_out_ng"] + cfg["station_2_out_ng"]
                for label, start, end in get_previous_shifts(now):
                    # yields
                    s1_in_  = count_unique_objects(cursor, cfg["station_1_in"],  start, end, "all")
                    s2_in_  = count_unique_objects(cursor, cfg["station_2_in"],  start, end, "all")
                    s1_n = count_unique_objects(cursor, cfg["station_1_out_ng"], start, end, "ng")
                    s1_g = s1_in_ - s1_n
                    s2_n = count_unique_objects(cursor, cfg["station_2_out_ng"], start, end, "ng")
                    s2_g = s2_in_ - s2_n

                    s1_yield_shifts.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "yield": compute_yield(s1_g, s1_n),
                        "good": s1_g,
                        "ng": s1_n
                    })

                    s2_yield_shifts.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "yield": compute_yield(s2_g, s2_n),
                        "good": s2_g,
                        "ng": s2_n
                    })

                    # throughput
                    tot = (count_unique_objects(cursor, cfg["station_1_in"], start, end, "all") +
                        count_unique_objects(cursor, cfg["station_2_in"], start, end, "all"))
                    ng = s1_n + s2_n
                    shift_throughput.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "total": tot,
                        "ng": ng
                    })

                # -------- last 8 h bins (yield + throughput) -----
                last_8h_throughput, s1_y8h, s2_y8h = [], [], []
                for label, h_start, h_end in get_last_8h_bins(now):
                    # THROUGHPUT
                    tot  = (count_unique_objects(cursor, cfg["station_1_in"], h_start, h_end, "all") +
                            count_unique_objects(cursor, cfg["station_2_in"], h_start, h_end, "all")) or 0
                    ng   = (count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng") +
                            count_unique_objects(cursor, cfg["station_2_out_ng"], h_start, h_end, "ng")) or 0

                    last_8h_throughput.append({
                        "hour": label,
                        "start": h_start.isoformat(),
                        "end": h_end.isoformat(),
                        "total": tot,
                        "ng": ng
                    })

                    # YIELDS PER STATION
                    s1_in_  = count_unique_objects(cursor, cfg["station_1_in"],  h_start, h_end, "all") or 0
                    s2_in_  = count_unique_objects(cursor, cfg["station_2_in"],  h_start, h_end, "all") or 0
                    s1_n = count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng") or 0
                    s1_g = s1_in_ - s1_n
                    s2_n = count_unique_objects(cursor, cfg["station_2_out_ng"], h_start, h_end, "ng") or 0
                    s2_g = s2_in_ - s2_n

                    s1_y8h.append({
                        "hour": label,
                        "good": s1_g,          # ➊ keep counts
                        "ng":   s1_n,
                        "yield": compute_yield(s1_g, s1_n),
                        "start": h_start.isoformat(),
                        "end":   h_end.isoformat(),
                    })
                    s2_y8h.append({
                        "hour": label,
                        "good": s2_g,
                        "ng":   s2_n,
                        "yield": compute_yield(s2_g, s2_n),
                        "start": h_start.isoformat(),
                        "end":   h_end.isoformat(),
                    })

                # -------- fermi_data calculation --------
                # Query total stop time for station 29
                sql_total_29 = """
                    SELECT SUM(
                        CASE 
                            WHEN st.end_time IS NULL THEN TIMESTAMPDIFF(SECOND, st.start_time, NOW())
                            ELSE st.stop_time
                        END
                    ) AS total_time
                    FROM stops st
                    WHERE st.type = 'STOP'
                    AND st.station_id = 29
                    AND st.start_time BETWEEN %s AND %s
                """
                cursor.execute(sql_total_29, (shift_start, shift_end))
                row29 = cursor.fetchone() or {}
                total_stop_time_29 = row29.get("total_time") or 0
                total_stop_time_minutes_29 = total_stop_time_29 / 60
                available_time_29 = max(0, round(100 - (total_stop_time_minutes_29 / 480 * 100)))

                # Query total stop time for station 30
                sql_total_30 = """
                    SELECT SUM(
                        CASE 
                            WHEN st.end_time IS NULL THEN TIMESTAMPDIFF(SECOND, st.start_time, NOW())
                            ELSE st.stop_time
                        END
                    ) AS total_time
                    FROM stops st
                    WHERE st.type = 'STOP'
                    AND st.station_id = 30
                    AND st.start_time BETWEEN %s AND %s
                """
                cursor.execute(sql_total_30, (shift_start, shift_end))
                row30 = cursor.fetchone() or {}
                total_stop_time_30 = row30.get("total_time") or 0
                total_stop_time_minutes_30 = total_stop_time_30 / 60
                available_time_30 = max(0, round(100 - (total_stop_time_minutes_30 / 480 * 100)))

                # Query top 4 stops (grouped) for both stations
                sql_top = """
                    SELECT s.name AS station_name, st.reason,
                        COUNT(*) AS n_occurrences,
                        SUM(
                            CASE 
                                WHEN st.end_time IS NULL THEN TIMESTAMPDIFF(SECOND, st.start_time, NOW())
                                ELSE st.stop_time
                            END
                        ) AS total_time
                    FROM stops st
                    JOIN stations s ON st.station_id = s.id
                    WHERE st.type = 'STOP'
                    AND st.station_id IN (29, 30)
                    AND st.start_time BETWEEN %s AND %s
                    GROUP BY st.station_id, st.reason
                    ORDER BY total_time DESC
                    LIMIT 4
                """
                cursor.execute(sql_top, (shift_start, shift_end))
                fermi_data = []
                top_rows = cursor.fetchall()

                for row in top_rows:
                    total_minutes = round(row["total_time"] / 60)
                    fermi_data.append({
                        "causale": row["reason"],
                        "station": row["station_name"],
                        "count": row["n_occurrences"],
                        "time": total_minutes
                    })

                # Query all currently OPEN stops (not grouped)
                sql_open = """
                    SELECT s.name AS station_name, st.reason, st.start_time
                    FROM stops st
                    JOIN stations s ON st.station_id = s.id
                    WHERE st.type = 'STOP'
                    AND st.status = 'OPEN'
                    AND st.station_id IN (29, 30)
                """
                cursor.execute(sql_open)
                open_rows = cursor.fetchall()

                for row in open_rows:
                    elapsed_min = int((datetime.now() - row["start_time"]).total_seconds() // 60)
                    stop_entry = {
                        "causale": row["reason"] or "Fermo",
                        "station": row["station_name"],
                        "count": 1,
                        "time": elapsed_min
                    }
                    if not any(f["causale"] == stop_entry["causale"] and f["station"] == stop_entry["station"] for f in fermi_data):
                        fermi_data.insert(0, stop_entry)

                # Append both available times at the end
                fermi_data.append({"Available_Time_1": f"{available_time_29}"})
                fermi_data.append({"Available_Time_2": f"{available_time_30}"})


                # -------- top_defects_qg2 calculation from productions + object_defects --------
                # 1️⃣ Query productions table for esito 6 on stations 1+2
                sql_productions = """
                    SELECT id, station_id
                    FROM productions
                    WHERE esito = 6
                    AND station_id IN (1, 2)
                    AND start_time BETWEEN %s AND %s
                """
                cursor.execute(sql_productions, (shift_start, shift_end))
                rows = cursor.fetchall()

                # Split production IDs by station
                production_ids_1 = [row['id'] for row in rows if row['station_id'] == 1]
                production_ids_2= [row['id'] for row in rows if row['station_id'] == 2]

                all_production_ids = tuple(production_ids_1 + production_ids_2)
                if not all_production_ids:
                    all_production_ids = (0,)

                # 2️⃣ Query object_defects JOIN defects
                sql_defects = """
                    SELECT od.production_id, od.defect_id, d.category
                    FROM object_defects od
                    JOIN defects d ON od.defect_id = d.id
                    WHERE od.production_id IN %s
                """
                cursor.execute(sql_defects, (all_production_ids,))
                rows = cursor.fetchall()

                # Build mapping production_id → station_id
                production_station_map = {pid: 1 for pid in production_ids_1}
                production_station_map.update({pid: 2 for pid in production_ids_2})

                defect_counter = defaultdict(lambda: {1: set(), 2: set()})

                for row in rows:
                    prod_id = row['production_id']
                    category = row['category']
                    station_id = production_station_map.get(prod_id)
                    if station_id:
                        defect_counter[category][station_id].add(prod_id)

                # Aggregate counts
                full_results = []
                for category, stations in defect_counter.items():
                    ain1_count = len(stations[1])
                    ain2_count = len(stations[2])
                    total = ain1_count + ain2_count
                    full_results.append({
                        "label": category,
                        "ain1": ain1_count,
                        "ain2": ain2_count,
                        "total": total
                    })

                # Compute total over all categories ✅
                total_defects_qg2 = sum(r["total"] for r in full_results)

                # Then get top 5
                results = sorted(full_results, key=lambda x: x['total'], reverse=True)[:5]
                top_defects_qg2 = [{"label": r["label"], "ain1": r["ain1"], "ain2": r["ain2"]} for r in results]

                # -------- top_defects_vpf (defects 12,14,15 from station 56, grouped by source station 29/30) ------
                sql_vpf_productions = """
                    SELECT p56.id, origin.station_id AS origin_station
                    FROM productions p56
                    JOIN productions origin ON p56.object_id = origin.object_id
                    WHERE p56.esito = 6
                    AND p56.station_id = 56
                    AND p56.start_time BETWEEN %s AND %s
                    AND origin.station_id IN (29, 30)
                """
                cursor.execute(sql_vpf_productions, (shift_start, shift_end))
                vpf_rows = cursor.fetchall()

                vpf_prod_ids = [row['id'] for row in vpf_rows]
                vpf_prod_map = {row['id']: row['origin_station'] for row in vpf_rows}

                if not vpf_prod_ids:
                    top_defects_vpf = []
                else:
                    placeholders = ','.join(['%s'] * len(vpf_prod_ids))
                    sql_vpf_defects = f"""
                        SELECT od.production_id, d.category
                        FROM object_defects od
                        JOIN defects d ON od.defect_id = d.id
                        WHERE od.production_id IN ({placeholders})
                        AND od.defect_id IN (12, 14, 15)
                    """
                    cursor.execute(sql_vpf_defects, vpf_prod_ids)
                    defect_rows = cursor.fetchall()

                    vpf_counter: Dict[str, Dict[int, int]] = defaultdict(lambda: {29: 0, 30: 0})
                    for row in defect_rows:
                        pid = row["production_id"]
                        category = row["category"]
                        if pid in vpf_prod_map:
                            station = vpf_prod_map[pid]
                            if station in (29, 30):
                                vpf_counter[category][station] += 1

                    vpf_results = []
                    for category, stations in vpf_counter.items():
                        c29 = stations[29]
                        c30 = stations[30]
                        total = c29 + c30
                        vpf_results.append({
                            "label": category,
                            "ain1": c29,  # AIN1 = 29
                            "ain2": c30,  # AIN2 = 30
                            "total": total
                        })

                    top5_vpf = sorted(vpf_results, key=lambda r: r["total"], reverse=True)[:5]
                    top_defects_vpf = [
                        {"label": r["label"], "ain1": r["ain1"], "ain2": r["ain2"]}
                        for r in top5_vpf
                    ]

                return {
                    "station_1_in": s1_in,
                    "station_2_in": s2_in,
                    "station_1_out_ng": s1_ng,
                    "station_2_out_ng": s2_ng,
                    "station_1_yield": s1_y,
                    "station_2_yield": s2_y,
                    "station_1_yield_shifts": s1_yield_shifts,
                    "station_2_yield_shifts": s2_yield_shifts,
                    "station_1_yield_last_8h": s1_y8h,
                    "station_2_yield_last_8h": s2_y8h,
                    "shift_throughput": shift_throughput,
                    "last_8h_throughput": last_8h_throughput,
                    "__shift_start": shift_start.isoformat(),
                    "__last_hour": hour_start.isoformat(),
                    "fermi_data": fermi_data,
                    "top_defects_qg2": top_defects_qg2,
                    "top_defects_vpf": top_defects_vpf,
                    "total_defects_qg2": total_defects_qg2,
                }
    except Exception as e:
        logger.exception(f"compute_zone_snapshot() FAILED for zone=AIN: {e}")
        raise

def _compute_snapshot_vpf(now: datetime) -> dict:
    category_station_map = {
        'NG1':   [(40, 'RWS01'), (3, 'RMI01'), (93, 'LMN01'), (47, 'LMN02')],
        'NG1.1': [(40, 'RWS01'), (3, 'RMI01'), (93, 'LMN01'), (47, 'LMN02'), (29, 'AIN01'), (30, 'AIN02')],
        'NG2':   [(4, 'STR01'), (5, 'STR02'), (6, 'STR03'), (7, 'STR04'), (8, 'STR05')],
        'NG2.1': [(40, 'RWS01'), (3, 'RMI01')],
        'NG3':   [(29, 'AIN01'), (30, 'AIN02'), (93, 'LMN01'), (47, 'LMN02'), (40, 'RWS01'), (3, 'RMI01')],
        'NG3.1': [(4, 'STR01'), (5, 'STR02'), (6, 'STR03'), (7, 'STR04'), (8, 'STR05')],
        'NG7':   [(93, 'LMN01'), (47, 'LMN02')],
        'NG7.1': [(93, 'LMN01'), (47, 'LMN02')],
    }

    try:
        if now is None:
            now = datetime.now()

        hour_start = now.replace(minute=0, second=0, microsecond=0)
        cfg = ZONE_SOURCES["VPF"]
        shift_start, shift_end = get_shift_window(now)

        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                s1_in  = count_unique_objects(cursor, cfg["station_1_in"],  shift_start, shift_end, "all")
                s1_ng  = count_unique_objects(cursor, cfg["station_1_out_ng"], shift_start, shift_end, "ng")
                s1_g   = s1_in - s1_ng
                s1_y   = compute_yield(s1_g, s1_ng)

                cursor.execute("""
                    SELECT COUNT(*) AS re_entered
                    FROM (
                        SELECT object_id FROM productions
                        WHERE station_id = %s AND start_time BETWEEN %s AND %s
                        GROUP BY object_id HAVING COUNT(*) > 1
                    ) sub
                """, (56, shift_start, shift_end))
                s1_reEntered = cursor.fetchone().get("re_entered", 0)

                s1_yield_shifts = []
                for label, start, end in get_previous_shifts(now):
                    s1_in_  = count_unique_objects(cursor, cfg["station_1_in"],  start, end, "all")
                    s1_n = count_unique_objects(cursor, cfg["station_1_out_ng"], start, end, "ng")
                    s1_g = s1_in_ - s1_n
                    s1_yield_shifts.append({
                        "label": label, "start": start.isoformat(), "end": end.isoformat(),
                        "yield": compute_yield(s1_g, s1_n), "good": s1_g, "ng": s1_n
                    })

                s1_y8h = []
                for label, h_start, h_end in get_last_8h_bins(now):
                    s1_in_  = count_unique_objects(cursor, cfg["station_1_in"],  h_start, h_end, "all") or 0
                    s1_n = count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng") or 0
                    s1_g = s1_in_ - s1_n
                    s1_y8h.append({
                        "hour": label, "good": s1_g, "ng": s1_n,
                        "yield": compute_yield(s1_g, s1_n),
                        "start": h_start.isoformat(), "end": h_end.isoformat()
                    })

                # -------- last 8 h bins (yield + throughput) -----
                last_8h_throughput= []
                for label, h_start, h_end in get_last_8h_bins(now):
                    # Throughput (distinct entries on station 1 + station 2)
                    tot  = (count_unique_objects(cursor, cfg["station_1_in"], h_start, h_end, "all")) or 0
                    ng   = (count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng")) or 0

                    last_8h_throughput.append({
                        "hour": label,
                        "start": h_start.isoformat(),
                        "end": h_end.isoformat(),
                        "total": tot,
                        "ng": ng,
                    })

                cursor.execute("""
                    SELECT p56.id FROM productions p56
                    WHERE p56.esito = 6 AND p56.station_id = 56
                    AND p56.start_time BETWEEN %s AND %s
                    AND NOT EXISTS (
                        SELECT 1 FROM productions p_prev
                        WHERE p_prev.object_id = p56.object_id
                        AND p_prev.station_id = 56
                        AND p_prev.start_time < p56.start_time
                    )
                """, (shift_start, shift_end))
                vpf_prod_ids = [row['id'] for row in cursor.fetchall()]

                defects_vpf = []
                if vpf_prod_ids:
                    placeholders = ','.join(['%s'] * len(vpf_prod_ids))
                    cursor.execute(f"""
                        SELECT d.category, COUNT(*) AS count
                        FROM object_defects od
                        JOIN defects d ON od.defect_id = d.id
                        WHERE od.production_id IN ({placeholders})
                        GROUP BY d.category
                    """, vpf_prod_ids)
                    defects_vpf = [{"label": r["category"], "count": r["count"]} for r in cursor.fetchall()]

                eq_defects = {
                    cat: {name: 0 for _, name in stations}
                    for cat, stations in category_station_map.items()
                }

                if vpf_prod_ids:
                    cursor.execute(f"""
                        SELECT d.category, p.object_id
                        FROM object_defects od
                        JOIN defects d ON d.id = od.defect_id
                        JOIN productions p ON p.id = od.production_id
                        WHERE od.production_id IN ({','.join(['%s'] * len(vpf_prod_ids))})
                    """, vpf_prod_ids)
                    defect_to_objects = {}
                    for row in cursor.fetchall():
                        defect_to_objects.setdefault(row["category"], set()).add(row["object_id"])

                    for cat, stations in category_station_map.items():
                        if cat not in defect_to_objects:
                            continue
                        object_ids = list(defect_to_objects[cat])
                        station_ids = [sid for sid, _ in stations]
                        station_map = {sid: name for sid, name in stations}
                        obj_ph = ','.join(['%s'] * len(object_ids))
                        stn_ph = ','.join(['%s'] * len(station_ids))
                        cursor.execute(f"""
                            SELECT p.station_id, COUNT(DISTINCT p.object_id) AS count
                            FROM productions p
                            WHERE p.object_id IN ({obj_ph})
                            AND p.station_id IN ({stn_ph})
                            AND p.start_time < (
                                SELECT MIN(p2.start_time)
                                FROM productions p2
                                WHERE p2.station_id = 56
                                AND p2.object_id = p.object_id
                            )
                            GROUP BY p.station_id
                        """, (*object_ids, *station_ids))
                        for row in cursor.fetchall():
                            sid, count = row["station_id"], row["count"]
                            if sid in station_map:
                                eq_defects[cat][station_map[sid]] = count

                cursor.execute("""
                    SELECT p.cycle_time FROM productions p
                    WHERE p.station_id = 56
                    AND p.cycle_time IS NOT NULL
                    AND p.start_time BETWEEN %s AND %s
                    ORDER BY p.start_time ASC
                """, (shift_start, shift_end))
                cycle_times = [time_to_seconds(r["cycle_time"]) for r in cursor.fetchall()]
                if cycle_times:
                    median_sec = median(cycle_times)
                    current_sec = min(cycle_times[-1], 120)
                else:
                    median_sec = 0
                    current_sec = 0
                    logger.debug(f"[VPF] No cycle times available — setting both median and current to 0")

                speed_ratio = [{"medianSec": median_sec, "currentSec": current_sec}]

    except Exception as e:
        logger.exception(f"compute_zone_snapshot() FAILED for zone=VPF: {e}")
        raise

    return {
        "station_1_in": s1_in,
        "station_1_out_ng": s1_ng,
        "station_1_re_entered": s1_reEntered,
        "last_8h_throughput": last_8h_throughput,
        "speed_ratio": speed_ratio,
        "station_1_yield": s1_y,
        "station_1_shifts": s1_yield_shifts,
        "station_1_yield_last_8h": s1_y8h,
        "__shift_start": shift_start.isoformat(),
        "__last_hour": hour_start.isoformat(),
        "defects_vpf": defects_vpf,
        "eq_defects": eq_defects,
    }

def count_good_after_rework(cursor, start, end):
    """
    # GOOD @S9 after GOOD @S3
    """
    sql = """
        WITH reworked AS (
            SELECT DISTINCT object_id
            FROM productions
            WHERE station_id = 3              -- ReWork
              AND esito <> 6                  -- GOOD
              AND start_time BETWEEN %s AND %s
        )
        SELECT COUNT(DISTINCT p.object_id) AS cnt
        FROM productions p
        JOIN reworked r USING (object_id)
        WHERE p.station_id = 9                -- back to ELL
          AND p.esito <> 6                    -- GOOD
          AND p.start_time BETWEEN %s AND %s
    """
    cursor.execute(sql, (start, end, start, end))
    return cursor.fetchone()["cnt"] or 0

def _compute_snapshot_ell(now: datetime) -> dict:
    def fpy_counts(cursor, station_name: str, start, end):
        sql = f"""
            WITH first_pass AS (
                SELECT o.id_modulo AS object_id,
                    p.esito,
                    ROW_NUMBER() OVER (
                        PARTITION BY o.id_modulo
                        ORDER BY p.start_time ASC
                    ) AS rn
                FROM productions p
                JOIN stations s ON p.station_id = s.id
                JOIN objects o ON o.id = p.object_id
                WHERE s.name = %s
                AND p.start_time BETWEEN %s AND %s
            )
            SELECT
                COALESCE(SUM(esito <> 6), 0) AS good,
                COALESCE(SUM(esito  = 6), 0) AS ng,
                COUNT(*)                     AS total
            FROM first_pass
            WHERE rn = 1
        """
        cursor.execute(sql, (station_name, start, end))
        return cursor.fetchone()

    def rwk_counts(cursor, station_name: str, start, end):
        sql = f"""
            WITH last_pass AS (
                SELECT o.id_modulo AS object_id,
                    p.esito,
                    ROW_NUMBER() OVER (
                        PARTITION BY o.id_modulo
                        ORDER BY p.start_time DESC
                    ) AS rn
                FROM productions p
                JOIN stations s ON p.station_id = s.id
                JOIN objects o ON o.id = p.object_id
                WHERE s.name = %s
                AND p.start_time BETWEEN %s AND %s
            )
            SELECT
                COALESCE(SUM(esito <> 6), 0) AS good,
                COALESCE(SUM(esito  = 6), 0) AS ng,
                COUNT(*)                     AS total
            FROM last_pass
            WHERE rn = 1
        """
        cursor.execute(sql, (station_name, start, end))
        return cursor.fetchone()

    try:
        if now is None:
            now = datetime.now()

        hour_start = now.replace(minute=0, second=0, microsecond=0)
        cfg = ZONE_SOURCES["ELL"]

        shift_start, shift_end = get_shift_window(now)

        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:

                # First pass stats
                s1_in = count_unique_objects(cursor, cfg["station_1_in"], shift_start, shift_end, "all")
                s1_in_r0 = count_unique_objects_r0(cursor, cfg["station_1_in"], shift_start, shift_end, "all")
                s1_ng = count_unique_objects(cursor, cfg["station_1_out_ng"], shift_start, shift_end, "ng")
                s1_ng_r0 = count_unique_objects_r0(cursor, cfg["station_1_out_ng"], shift_start, shift_end, "ng")
                s1_g = s1_in - s1_ng
                s1_g_r0 = s1_in_r0 - s1_ng_r0

                s2_in_r0  = count_unique_objects_r0(cursor, cfg["station_2_in"],  shift_start, shift_end, "all")
                s2_ng_r0 = count_unique_objects_r0(cursor, cfg["station_2_out_ng"], shift_start, shift_end, "ng")
                s2_g_r0 = s2_in_r0 - s2_ng_r0

                # Rework stats
                s2_in = count_unique_objects(cursor, cfg["station_2_in"], shift_start, shift_end, "all")
                s2_ng = count_unique_objects(cursor, cfg["station_2_out_ng"], shift_start, shift_end, "ng")
                s2_g = s2_in - s2_ng

                # Gauge 1: re-entry rate
                cursor.execute("""
                    SELECT COUNT(*) AS multi_entry
                    FROM (
                        SELECT o.id_modulo AS object_id
                        FROM productions p
                        JOIN stations s ON s.id = p.station_id
                        JOIN objects o ON o.id = p.object_id
                        WHERE s.name = %s
                        AND p.start_time BETWEEN %s AND %s
                        GROUP BY o.id_modulo
                        HAVING COUNT(*) > 1
                    ) AS sub
                """, (cfg["station_1_in"], shift_start, shift_end))

                multi_entry = cursor.fetchone()["multi_entry"] or 0

                s2_in = count_unique_objects(cursor, cfg["station_2_in"], shift_start, shift_end, "all")


                value_gauge_1 = round((multi_entry / s2_in) * 100, 2) if s2_in else 0.0

                # ---- Gauge 2 ---------------------------------------------------------------
                # Step 1 — Get all object_ids that passed station_1_in >1 times
                cursor.execute("""
                    SELECT o.id_modulo AS object_id
                    FROM productions p
                    JOIN stations s ON s.id = p.station_id
                    JOIN objects o ON o.id = p.object_id
                    WHERE s.name = %s
                    AND p.start_time BETWEEN %s AND %s
                    GROUP BY o.id_modulo
                    HAVING COUNT(*) > 1
                """, (cfg["station_1_in"], shift_start, shift_end))

                multi_entry_ids = [row["object_id"] for row in cursor.fetchall()]
                multi_entry_count = len(multi_entry_ids)

                if not multi_entry_ids:
                    value_gauge_2 = 0.0
                else:
                    format_ids = ','.join(['%s'] * len(multi_entry_ids))
                    cursor.execute(f"""
                        WITH last_pass AS (
                            SELECT o.id_modulo AS object_id, p.esito,
                                ROW_NUMBER() OVER (
                                    PARTITION BY o.id_modulo
                                    ORDER BY p.start_time DESC
                                ) AS rn
                            FROM productions p
                            JOIN stations s ON s.id = p.station_id
                            JOIN objects o ON o.id = p.object_id
                            WHERE s.name = %s
                            AND o.id_modulo IN ({format_ids})
                        )
                        SELECT COUNT(*) AS good_final
                        FROM last_pass
                        WHERE rn = 1 AND esito = 1
                    """, (cfg["station_1_in"], *multi_entry_ids))

                    good_final = cursor.fetchone()["good_final"] or 0
                    value_gauge_2 = round((good_final / multi_entry_count) * 100, 2)

                # --- NG Counters ---
                s1_ng = count_unique_objects(cursor, cfg["station_1_out_ng"], shift_start, shift_end, "ng")

                qg2_ng_1 = count_unique_objects(cursor, cfg["station_qg_1"], shift_start, shift_end, "ng")
                qg2_ng_2 = count_unique_objects(cursor, cfg["station_qg_2"], shift_start, shift_end, "ng")

                qg2_ng = qg2_ng_1 + qg2_ng_2

                # Combined NG across ELL (station_1) + QG2_1 + QG2_2 (deduplicated by object_id)
                stations_ng = cfg["station_1_out_ng"] + cfg["station_qg_1"] + cfg["station_qg_2"]
                ng_tot = count_unique_ng_objects(cursor, stations_ng, shift_start, shift_end)

                # Optional deeper inspection — show object IDs
                cursor.execute(f"""
                    SELECT DISTINCT o.id_modulo AS object_id, s.name AS station, p.start_time
                    FROM productions p
                    JOIN stations s ON p.station_id = s.id
                    JOIN objects o ON o.id = p.object_id
                    WHERE s.name IN ({','.join(['%s']*len(stations_ng))})
                    AND p.esito = 6
                    AND p.start_time BETWEEN %s AND %s
                """, (*stations_ng, shift_start, shift_end))
                rows = cursor.fetchall()

                cnt_fpy = fpy_counts(cursor, cfg["station_1_in"][0], shift_start, now)
                cnt_rwk = rwk_counts(cursor, cfg["station_1_in"][0], shift_start, now)

                fpy_y = compute_yield(cnt_fpy["good"], cnt_fpy["ng"])
                rwk_y = compute_yield(cnt_rwk["good"], cnt_rwk["ng"])

                # -------- last 3 shifts yield + throughput -------
                FPY_yield_shifts, RWK_yield_shifs, shift_throughput = [], [], []
                for label, start, end in get_previous_shifts(now):
                    # First-pass (R0) yield stats
                    s1_in_r0_  = count_unique_objects_r0(cursor, cfg["station_1_in"],  start, end, "all")
                    s1_ng_r0_  = count_unique_objects_r0(cursor, cfg["station_1_out_ng"], start, end, "ng")
                    s1_g_r0_   = s1_in_r0_ - s1_ng_r0_

                    s1_in_     = count_unique_objects(cursor, cfg["station_1_in"],  start, end, "all")
                    s1_n_      = count_unique_objects(cursor, cfg["station_1_out_ng"], start, end, "ng")

                    s2_in_     = count_unique_objects(cursor, cfg["station_2_in"],  start, end, "all")
                    s2_n_      = count_unique_objects(cursor, cfg["station_2_out_ng"], start, end, "ng")

                    cnt_f = fpy_counts(cursor, cfg["station_1_in"][0], start, end)
                    cnt_r = rwk_counts(cursor, cfg["station_1_in"][0], start, end)

                    FPY_yield_shifts.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "yield": compute_yield(cnt_f["good"], cnt_f["ng"]),
                        "good": cnt_f["good"],
                        "ng":   cnt_f["ng"]
                    })

                    RWK_yield_shifs.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "yield": compute_yield(cnt_r["good"], cnt_r["ng"]),
                        "good": cnt_r["good"],
                        "ng":   cnt_r["ng"]
                    })

                    # Throughput (sum of distinct entries on station 1 + station 2)
                    tot = (count_unique_objects(cursor, cfg["station_1_in"], start, end, "all") +
                        count_unique_objects(cursor, cfg["station_2_in"], start, end, "all"))
                    ng = s1_n_
                    shift_throughput.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "total": tot,
                        "ng": ng,
                        "scrap": s2_n_
                    })

                # Insert current shift’s yield at the front
                FPY_yield_shifts.insert(0, {
                    "label": label,
                    "start": shift_start.isoformat(),
                    "end": now.isoformat(),
                    "good": s1_in_r0 - s1_ng_r0,
                    "ng":   s1_ng_r0,
                    "yield": fpy_y
                })

                RWK_yield_shifs.insert(0, {
                    "label": label,
                    "start": shift_start.isoformat(),
                    "end": now.isoformat(),
                    "station_1_in": s1_in,
                    "station_1_out_ng": s1_ng,
                    "station_2_in": s2_in,
                    "yield": rwk_y
                })

                # -------- last 8 h bins (yield + throughput) -----
                last_8h_throughput, FPY_y8h, RWK_y8h = [], [], []
                for label, h_start, h_end in get_last_8h_bins(now):
                    # Throughput (distinct entries on station 1 + station 2)
                    tot  = (count_unique_objects(cursor, cfg["station_1_in"], h_start, h_end, "all") +
                            count_unique_objects(cursor, cfg["station_2_in"], h_start, h_end, "all")) or 0
                    ng   = (count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng")) or 0
                    scrap = count_unique_objects(cursor, cfg["station_2_out_ng"], h_start, h_end, "ng") or 0

                    last_8h_throughput.append({
                        "hour": label,
                        "start": h_start.isoformat(),
                        "end": h_end.isoformat(),
                        "total": tot,
                        "ng": ng,
                        "scrap": scrap
                    })

                    # FPY yield per 8h bin (first-pass only)
                    s1_in_r0_  = count_unique_objects_r0(cursor, cfg["station_1_in"], h_start, h_end, "all") or 0
                    s1_ng_r0_  = count_unique_objects_r0(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng") or 0
                    s1_g_r0_   = s1_in_r0_ - s1_ng_r0_

                    cnt_f = fpy_counts(cursor, cfg["station_1_in"][0], h_start, h_end)
                    cnt_r = rwk_counts(cursor, cfg["station_1_in"][0], h_start, h_end)

                    FPY_y8h.append({
                        "hour": label,
                        "good": cnt_f["good"],
                        "ng":   cnt_f["ng"],
                        "yield": compute_yield(cnt_f["good"], cnt_f["ng"]),
                        "start": h_start.isoformat(),
                        "end": h_end.isoformat(),
                    })

                    RWK_y8h.append({
                        "hour": label,
                        "good": cnt_r["good"],
                        "ng":   cnt_r["ng"],
                        "yield": compute_yield(cnt_r["good"], cnt_r["ng"]),
                        "start": h_start.isoformat(),
                        "end": h_end.isoformat(),
                    })

                # -------- top_defects_qg2 calculation from productions + object_defects --------
                # 1️⃣ Query productions table for esito 6 on stations 1+2+9
                sql_productions = """
                    SELECT id, station_id
                    FROM productions
                    WHERE esito = 6
                    AND station_id IN (1, 2, 9)
                    AND start_time BETWEEN %s AND %s
                """
                cursor.execute(sql_productions, (shift_start, shift_end))
                rows = cursor.fetchall()

                # Split production IDs by station
                production_ids_1 = [row['id'] for row in rows if row['station_id'] == 1]
                production_ids_2= [row['id'] for row in rows if row['station_id'] == 2]
                production_ids_9 = [row['id'] for row in rows if row['station_id'] == 9]

                all_production_ids = tuple(production_ids_1 + production_ids_2 + production_ids_9)
                if not all_production_ids:
                    all_production_ids = (0,)

                # 2️⃣ Query object_defects JOIN defects
                sql_defects = """
                    SELECT od.production_id, od.defect_id, d.category
                    FROM object_defects od
                    JOIN defects d ON od.defect_id = d.id
                    WHERE od.production_id IN %s
                """
                cursor.execute(sql_defects, (all_production_ids,))
                rows = cursor.fetchall()

                # Build mapping production_id → station_id
                production_station_map = {pid: 1 for pid in production_ids_1}
                production_station_map.update({pid: 2 for pid in production_ids_2})
                production_station_map.update({pid: 9 for pid in production_ids_9})

                defect_counter = defaultdict(lambda: {1: set(), 2: set(), 9: set()})

                for row in rows:
                    prod_id = row['production_id']
                    category = row['category']
                    station_id = production_station_map.get(prod_id)
                    if station_id:
                        defect_counter[category][station_id].add(prod_id)

                # Aggregate counts
                full_results = []
                for category, stations in defect_counter.items():
                    min1_count = len(stations[1])
                    min2_count = len(stations[2])
                    ell_count = len(stations[9])
                    total = min1_count + min2_count + ell_count
                    full_results.append({
                        "label": category,
                        "min1": min1_count,
                        "min2": min2_count,
                        "ell": ell_count,
                        "total": total
                    })

                # Then get top 5
                results = sorted(full_results, key=lambda x: x['total'], reverse=True)[:5]
                top_defects = [{"label": r["label"], "min1": r["min1"], "min2": r["min2"], "ell": r["ell"]} for r in results]

                        # -------- count re-entered modules in ELL (station 9 + station 3) --------
                sql_reentered_ell = """
                    SELECT COUNT(*) AS re_entered
                    FROM (
                        SELECT o.id_modulo AS object_id
                        FROM productions p
                        JOIN objects o ON o.id = p.object_id
                        WHERE station_id IN (9, 3)
                        AND start_time BETWEEN %s AND %s
                        GROUP BY o.id_modulo
                        HAVING COUNT(DISTINCT station_id) > 1
                    ) sub
                """
                cursor.execute(sql_reentered_ell, (shift_start, shift_end))
                result = cursor.fetchone()
                reentered_count = result["re_entered"] if result and "re_entered" in result else 0

                # ========== For real-time gauge tracking after restart ==========
                # Multi-entry object_ids
                cursor.execute("""
                    SELECT o.id_modulo AS object_id, COUNT(*) AS cnt
                    FROM productions p
                    JOIN stations s ON s.id = p.station_id
                    JOIN objects o ON o.id = p.object_id
                    WHERE s.name = %s AND p.start_time BETWEEN %s AND %s
                    GROUP BY o.id_modulo
                """, (cfg["station_1_in"], shift_start, now))

                s1_entry_count = {}
                multi_entry_set = set()
                for row in cursor.fetchall():
                    oid = row["object_id"]
                    cnt = row["cnt"]
                    s1_entry_count[oid] = cnt
                    if cnt > 1:
                        multi_entry_set.add(oid)

                # s2_entry_set
                cursor.execute("""
                    SELECT DISTINCT o.id_modulo AS object_id
                    FROM productions p
                    JOIN stations s ON s.id = p.station_id
                    JOIN objects o ON o.id = p.object_id
                    WHERE s.name = %s AND p.start_time BETWEEN %s AND %s
                """, (cfg["station_2_in"], shift_start, now))
                s2_entry_set = {row["object_id"] for row in cursor.fetchall()}

                # s1_success_set: multi-entry modules with final esito = 1
                s1_success_set = set()
                if multi_entry_set:
                    format_ids = ','.join(['%s'] * len(multi_entry_set))
                    cursor.execute(f"""
                        WITH last_pass AS (
                            SELECT o.id_modulo AS object_id, p.esito,
                                ROW_NUMBER() OVER (
                                    PARTITION BY o.id_modulo
                                    ORDER BY p.start_time DESC
                                ) AS rn
                            FROM productions p
                            JOIN stations s ON s.id = p.station_id
                            JOIN objects o ON o.id = p.object_id
                            WHERE s.name = %s
                            AND o.id_modulo IN ({format_ids})
                        )
                        SELECT object_id
                        FROM last_pass
                        WHERE rn = 1 AND esito = 1
                    """, (cfg["station_1_in"], *multi_entry_set))
                    s1_success_set = {row["object_id"] for row in cursor.fetchall()}

                # latest_esito + latest_ts
                cursor.execute("""
                    SELECT o.id_modulo AS object_id, p.esito, p.start_time
                    FROM productions p
                    JOIN stations s ON s.id = p.station_id
                    JOIN objects o ON o.id = p.object_id
                    WHERE s.name IN (%s, %s) AND p.start_time BETWEEN %s AND %s
                """, (*cfg["station_1_in"], *cfg["station_1_out_ng"], shift_start, now))

                latest_esito, latest_ts = {}, {}
                for row in cursor.fetchall():
                    oid = row["object_id"]
                    ts = row["start_time"]
                    if oid not in latest_ts or ts > latest_ts[oid]:
                        latest_ts[oid] = ts
                        latest_esito[oid] = row["esito"]


    except Exception as e:
        logger.exception(f"compute_zone_snapshot() FAILED for zone=ELL: {e}")
        raise

    return {
            "station_1_in": s1_in, #
            "station_2_in": s2_in, #
            "station_1_ng_qg2": qg2_ng, #
            "station_1_out_ng": s1_ng, #
            "station_2_out_ng": s2_ng, #
            "ng_tot": ng_tot, #
            "station_1_r0_in": s1_in_r0, #
            "station_1_r0_ng": s1_ng_r0, #
            "station_2_r0_in":  s2_in_r0, #
            "station_2_r0_ng":  s2_ng_r0, #
            "FPY_yield": fpy_y, #
            "RWK_yield": rwk_y, #
            "FPY_yield_shifts": FPY_yield_shifts, #
            "RWK_yield_shifts": RWK_yield_shifs, #
            "FPY_yield_last_8h": FPY_y8h, #
            "RWK_yield_last_8h": RWK_y8h, #
            "shift_throughput": shift_throughput, #
            "last_8h_throughput": last_8h_throughput, #
            "__shift_start": shift_start.isoformat(),
            "__last_hour": hour_start.isoformat(),
            "top_defects": top_defects,
            "value_gauge_1": value_gauge_1, #
            "value_gauge_2": value_gauge_2, #
            "s1_entry_count": s1_entry_count,
            "s2_entry_set": s2_entry_set,
            "multi_entry_set": multi_entry_set,
            "s1_success_set": s1_success_set,
            "latest_esito": latest_esito,
            "latest_ts": {k: v.isoformat() for k, v in latest_ts.items()}
        }

def _compute_snapshot_str(now: datetime | None) -> dict:
    """
    Build the full STR snapshot from str_visual_snapshot.

    str_visual_snapshot rows are written per module, with cell_G, cell_NG,
    string_G, string_NG reset to zero by the PLC after each module.
    We aggregate these deltas over time windows.

    Station → ID mapping:
        4 : STR01
        5 : STR02
        6 : STR03
        7 : STR04
        8 : STR05
    """
    if now is None:
        now = datetime.now()

    hour_start = now.replace(minute=0, second=0, microsecond=0)
    shift_start, shift_end = get_shift_window(now)
    STATION_IDS = [4, 5, 6, 7, 8]  # STR stations

    def _sum_for_window(cur, col, st_id, t0, t1):
        cur.execute(
            f"""
            SELECT COALESCE(SUM({col}),0) AS val
            FROM str_visual_snapshot
            WHERE station_id=%s AND timestamp BETWEEN %s AND %s
            """,
            (st_id, t0, t1),
        )
        return cur.fetchone()["val"] or 0

    with get_mysql_connection() as conn, conn.cursor() as cur:
        station_in, station_g, station_ng, station_scrap, station_yield = {}, {}, {}, {}, {}

        # 1) Current shift totals per station (include cell_NG as string-equivalent NG)
        for idx, st_id in enumerate(STATION_IDS, start=1):
            g = _sum_for_window(cur, "string_G", st_id, shift_start, shift_end)
            n = _sum_for_window(cur, "string_NG", st_id, shift_start, shift_end)
            c = _sum_for_window(cur, "cell_NG",  st_id, shift_start, shift_end)

            cell_ngs = c // 10                    # integer strings from defective cells
            total_ng = n + cell_ngs               # strings NG + cell-derived NG
            total_in = g + total_ng               # processed = good + all NG

            y = compute_yield(g, total_ng)

            # 🔍 Debug print
            print(f"[Station {idx} / ID={st_id}] "
                f"G={g}, NG={n}, cell_NG={c}, cell_ngs={cell_ngs}, "
                f"total_ng={total_ng}, total_in={total_in}, YIELD={y}%")

            station_in[f"station_{idx}_in"]       = total_in
            station_g[f"station_{idx}_g"]         = g
            station_ng[f"station_{idx}_out_ng"]   = total_ng
            station_scrap[f"station_{idx}_scrap"] = cell_ngs
            station_yield[f"station_{idx}_yield"] = y

            #[Station 1 / ID=4] G=0, NG=0, cell_NG=0, cell_ngs=0, total_ng=0, total_in=0, YIELD=0%
            #[Station 2 / ID=5] G=205, NG=8, cell_NG=42, cell_ngs=4, total_ng=12, total_in=217, YIELD=94%
            #[Station 3 / ID=6] G=120, NG=3, cell_NG=45, cell_ngs=4, total_ng=7, total_in=127, YIELD=94%
            #[Station 4 / ID=7] G=127, NG=4, cell_NG=24, cell_ngs=2, total_ng=6, total_in=133, YIELD=95%
            #[Station 5 / ID=8] G=215, NG=3, cell_NG=31, cell_ngs=3, total_ng=6, total_in=221, YIELD=97%


        # 2) Last 3 shifts (STR yield and Overall yield identical for now)
        str_yield_shifts, overall_yield_shifts, shift_throughput = [], [], []
        for label, st, et in get_previous_shifts(now):
            good_shift   = sum(_sum_for_window(cur, "string_G", sid, st, et) for sid in STATION_IDS)
            ng_shift     = sum(_sum_for_window(cur, "string_NG", sid, st, et) for sid in STATION_IDS)
            cell_total   = sum(_sum_for_window(cur, "cell_NG",  sid, st, et) for sid in STATION_IDS)
            cell_ngs_all = cell_total // 10

            total_ng_shift = ng_shift + cell_ngs_all
            total_proc     = good_shift + total_ng_shift

            # STR Yield (zone view)
            str_yield_shifts.append({
                "label": label,
                "start": st.isoformat(),
                "end":   et.isoformat(),
                "yield": compute_yield(good_shift, total_ng_shift),
                "good":  good_shift,
                "ng":    total_ng_shift,
                "scrap": cell_ngs_all,
            })

            # Overall Yield (same formula for now)
            overall_yield_shifts.append({
                "label": label,
                "start": st.isoformat(),
                "end":   et.isoformat(),
                "yield": compute_yield(good_shift, total_ng_shift),
                "good":  good_shift,
                "ng":    total_ng_shift,
            })

            # Throughput (good + all NG)
            shift_throughput.append({
                "label": label,
                "start": st.isoformat(),
                "end":   et.isoformat(),
                "total": total_proc,
                "ng":    total_ng_shift,
                "scrap": cell_ngs_all,
            })

        # 3) Last 8 hourly bins (STR + Overall). Also build per-station hourly throughput.
        hourly_bins_by_station = {idx: [] for idx in range(1, 6)}  # station_1..5
        str_y8h, overall_y8h = [], []
        for label, hs, he in get_last_8h_bins(now):
            good_bin   = sum(_sum_for_window(cur, "string_G", sid, hs, he) for sid in STATION_IDS)
            ng_bin     = sum(_sum_for_window(cur, "string_NG", sid, hs, he) for sid in STATION_IDS)
            cell_bin   = sum(_sum_for_window(cur, "cell_NG",  sid, hs, he) for sid in STATION_IDS)
            cell_ngs_b = cell_bin // 10

            total_ng_bin = ng_bin + cell_ngs_b

            # Per-station hourly throughput (include cell-derived NG in ng)
            for idx, sid in enumerate(STATION_IDS, start=1):
                g_s = _sum_for_window(cur, "string_G", sid, hs, he)
                n_s = _sum_for_window(cur, "string_NG", sid, hs, he)
                c_s = _sum_for_window(cur, "cell_NG",  sid, hs, he)
                hourly_bins_by_station[idx].append({
                    "hour":  label,
                    "start": hs.isoformat(),
                    "end":   he.isoformat(),
                    "ok":    g_s,
                    "ng":    n_s + (c_s // 10),
                })

            # STR Yield (zone)
            str_y8h.append({
                "hour":  label,
                "start": hs.isoformat(),
                "end":   he.isoformat(),
                "good":  good_bin,
                "ng":    total_ng_bin,
                "yield": compute_yield(good_bin, total_ng_bin),
            })

            # Overall Yield (same)
            overall_y8h.append({
                "hour":  label,
                "start": hs.isoformat(),
                "end":   he.isoformat(),
                "good":  good_bin,
                "ng":    total_ng_bin,
                "yield": compute_yield(good_bin, total_ng_bin),
            })

        # 4) Stops / fermi (unchanged logic, kept as-is)
        fermi_data = []
        SHIFT_DURATION_MINUTES = 480
        station_labels = {4: "STR01", 5: "STR02", 6: "STR03", 7: "STR04", 8: "STR05"}

        sql_total = """
            SELECT SUM(
                CASE 
                    WHEN st.end_time IS NULL THEN TIMESTAMPDIFF(SECOND, st.start_time, NOW())
                    ELSE st.stop_time
                END
            ) AS total_time
            FROM stops st
            WHERE st.type = 'STOP'
              AND st.station_id = %s
              AND st.start_time BETWEEN %s AND %s
        """
        for sid in STATION_IDS:
            cur.execute(sql_total, (sid, shift_start, shift_end))
            row = cur.fetchone() or {}
            total_secs = row.get("total_time") or 0
            total_min = total_secs / 60
            available = max(0, round(100 - (total_min / SHIFT_DURATION_MINUTES * 100)))
            fermi_data.append({f"Available_Time_{station_labels[sid]}": f"{available}"})

        # Top 4 stops (grouped) across all STR stations
        placeholders = ','.join(['%s'] * len(STATION_IDS))
        sql_top = f"""
            SELECT s.name AS station_name, st.reason,
                   COUNT(*) AS n_occurrences,
                   SUM(
                       CASE 
                           WHEN st.end_time IS NULL THEN TIMESTAMPDIFF(SECOND, st.start_time, NOW())
                           ELSE st.stop_time
                       END
                   ) AS total_time
            FROM stops st
            JOIN stations s ON st.station_id = s.id
            WHERE st.type = 'STOP'
              AND st.station_id IN ({placeholders})
              AND st.start_time BETWEEN %s AND %s
            GROUP BY st.station_id, st.reason
            ORDER BY total_time DESC
            LIMIT 4
        """
        cur.execute(sql_top, (*STATION_IDS, shift_start, shift_end))
        top_rows = cur.fetchall()
        for row in top_rows:
            total_minutes = round(row["total_time"] / 60)
            fermi_data.insert(0, {
                "causale": row["reason"],
                "station": row["station_name"],
                "count":   row["n_occurrences"],
                "time":    total_minutes
            })

        # Currently OPEN stops (not grouped)
        sql_open = f"""
            SELECT s.name AS station_name, st.reason, st.start_time
            FROM stops st
            JOIN stations s ON st.station_id = s.id
            WHERE st.type = 'STOP'
              AND st.status = 'OPEN'
              AND st.station_id IN ({placeholders})
        """
        cur.execute(sql_open, (*STATION_IDS,))
        open_rows = cur.fetchall()
        for row in open_rows:
            elapsed_min = int((datetime.now() - row["start_time"]).total_seconds() // 60)
            stop_entry = {
                "causale": row["reason"] or "Fermo",
                "station": row["station_name"],
                "count":   1,
                "time":    elapsed_min
            }
            if not any(f.get("causale") == stop_entry["causale"] and f.get("station") == stop_entry["station"]
                       for f in fermi_data):
                fermi_data.insert(0, stop_entry)

        # 5) Top defects (QG2 / VPF) — unchanged
        sql_prod = """
            SELECT id, station_id
            FROM productions
            WHERE esito=6 AND station_id IN (1,2)
              AND start_time BETWEEN %s AND %s
        """
        cur.execute(sql_prod, (shift_start, shift_end))
        prod_rows = cur.fetchall()
        prod_ids_1 = [r['id'] for r in prod_rows if r['station_id'] == 1]
        prod_ids_2 = [r['id'] for r in prod_rows if r['station_id'] == 2]
        all_prod_ids = tuple(prod_ids_1 + prod_ids_2) or (0,)
        sql_defects = """
            SELECT od.production_id, d.category
            FROM object_defects od
            JOIN defects d ON od.defect_id = d.id
            WHERE od.production_id IN %s
        """
        cur.execute(sql_defects, (all_prod_ids,))
        defect_rows = cur.fetchall()
        prod_station_map = {pid: 1 for pid in prod_ids_1}
        prod_station_map.update({pid: 2 for pid in prod_ids_2})
        defect_counter = defaultdict(lambda: {1: set(), 2: set()})
        for r in defect_rows:
            pid, cat = r['production_id'], r['category']
            sid = prod_station_map.get(pid)
            if sid:
                defect_counter[cat][sid].add(pid)
        full_results = []
        for cat, stations in defect_counter.items():
            a1, a2 = len(stations[1]), len(stations[2])
            full_results.append({"label": cat, "ain1": a1, "ain2": a2, "total": a1 + a2})
        total_defects_qg2 = sum(r["total"] for r in full_results)
        top_defects_qg2 = sorted(full_results, key=lambda x: x["total"], reverse=True)[:5]

        sql_vpf_prod = """
            SELECT p56.id, origin.station_id AS origin_station
            FROM productions p56
            JOIN productions origin ON p56.object_id = origin.object_id
            WHERE p56.esito=6 AND p56.station_id=56
              AND p56.start_time BETWEEN %s AND %s
              AND origin.station_id IN (29,30)
        """
        cur.execute(sql_vpf_prod, (shift_start, shift_end))
        vpf_rows = cur.fetchall()
        vpf_prod_ids = [r['id'] for r in vpf_rows]
        vpf_map: Dict[int, int] = {r['id']: r['origin_station'] for r in vpf_rows}

        top_defects_vpf = []
        if vpf_prod_ids:
            placeholders = ','.join(['%s'] * len(vpf_prod_ids))
            cur.execute(f"""
                SELECT od.production_id, d.category
                FROM object_defects od
                JOIN defects d ON od.defect_id = d.id
                WHERE od.production_id IN ({placeholders})
                  AND od.defect_id IN (12,14,15)
            """, vpf_prod_ids)
            defect_rows = cur.fetchall()

            vpf_counter: Dict[str, Dict[int, int]] = defaultdict(lambda: {29: 0, 30: 0})
            for r in defect_rows:
                pid = r.get("production_id")
                cat = r.get("category")
                st  = vpf_map.get(pid)
                if not isinstance(cat, str) or st not in (29, 30):
                    continue
                vpf_counter[cat][st] += 1

            vpf_results = []
            for cat, stations in vpf_counter.items():
                c29, c30 = stations.get(29, 0), stations.get(30, 0)
                vpf_results.append({"label": cat, "ain1": c29, "ain2": c30, "total": c29 + c30})
            top_defects_vpf = sorted(vpf_results, key=lambda x: x["total"], reverse=True)[:5]

    return {
        **station_in,
        **station_g,
        **station_ng,
        **station_scrap,
        **station_yield,
        "str_yield_shifts": str_yield_shifts,
        "overall_yield_shifts": overall_yield_shifts,
        "str_yield_last_8h": str_y8h,
        "overall_yield_last_8h": overall_y8h,
        "hourly_throughput_per_station": hourly_bins_by_station,
        "shift_throughput": shift_throughput,
        "__shift_start": shift_start.isoformat(),
        "__last_hour": hour_start.isoformat(),
        "fermi_data": fermi_data,
        "top_defects_qg2": top_defects_qg2,
        "top_defects_vpf": top_defects_vpf,
        "total_defects_qg2": total_defects_qg2,
    }

def _compute_snapshot_lmn(now: datetime) -> dict:
    try:
        if now is None:
            now = datetime.now()

        hour_start = now.replace(minute=0, second=0, microsecond=0)
        cfg = ZONE_SOURCES["LMN"]

        shift_start, shift_end = get_shift_window(now)

        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                # -------- current shift totals / yield ----------
                s1_in  = count_unique_objects(cursor, cfg["station_1_in"],  shift_start, shift_end, "all")
                s2_in  = count_unique_objects(cursor, cfg["station_2_in"],  shift_start, shift_end, "all")
                s1_ng  = count_unique_objects(cursor, cfg["station_1_out_ng"], shift_start, shift_end, "ng")
                s2_ng  = count_unique_objects(cursor, cfg["station_2_out_ng"], shift_start, shift_end, "ng")
                s1_g   = s1_in - s1_ng
                s2_g   = s2_in - s2_ng
                s1_y   = compute_yield(s1_g, s1_ng)
                s2_y   = compute_yield(s2_g, s2_ng)

                # -------- last 3 shifts yield + throughput -------
                s1_yield_shifts, s2_yield_shifts, shift_throughput = [], [], []
                qc_stations = cfg["station_1_out_ng"] + cfg["station_2_out_ng"]
                for label, start, end in get_previous_shifts(now):
                    # yields
                    s1_in_  = count_unique_objects(cursor, cfg["station_1_in"],  start, end, "all")
                    s2_in_  = count_unique_objects(cursor, cfg["station_2_in"],  start, end, "all")
                    s1_n = count_unique_objects(cursor, cfg["station_1_out_ng"], start, end, "ng")
                    s1_g = s1_in_ - s1_n
                    s2_n = count_unique_objects(cursor, cfg["station_2_out_ng"], start, end, "ng")
                    s2_g = s2_in_ - s2_n

                    s1_yield_shifts.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "yield": compute_yield(s1_g, s1_n),
                        "good": s1_g,
                        "ng": s1_n
                    })

                    s2_yield_shifts.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "yield": compute_yield(s2_g, s2_n),
                        "good": s2_g,
                        "ng": s2_n
                    })

                    # throughput
                    tot = (count_unique_objects(cursor, cfg["station_1_in"], start, end, "all") +
                        count_unique_objects(cursor, cfg["station_2_in"], start, end, "all"))
                    ng = s1_n + s2_n
                    shift_throughput.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "total": tot,
                        "ng": ng
                    })

                # -------- last 8 h bins (yield + throughput) -----
                last_8h_throughput, s1_y8h, s2_y8h = [], [], []
                for label, h_start, h_end in get_last_8h_bins(now):
                    # THROUGHPUT
                    tot  = (count_unique_objects(cursor, cfg["station_1_in"], h_start, h_end, "all") +
                            count_unique_objects(cursor, cfg["station_2_in"], h_start, h_end, "all")) or 0
                    ng   = (count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng") +
                            count_unique_objects(cursor, cfg["station_2_out_ng"], h_start, h_end, "ng")) or 0

                    last_8h_throughput.append({
                        "hour": label,
                        "start": h_start.isoformat(),
                        "end": h_end.isoformat(),
                        "total": tot,
                        "ng": ng
                    })

                    # YIELDS PER STATION
                    s1_in_  = count_unique_objects(cursor, cfg["station_1_in"],  h_start, h_end, "all") or 0
                    s2_in_  = count_unique_objects(cursor, cfg["station_2_in"],  h_start, h_end, "all") or 0
                    s1_n = count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng") or 0
                    s1_g = s1_in_ - s1_n
                    s2_n = count_unique_objects(cursor, cfg["station_2_out_ng"], h_start, h_end, "ng") or 0
                    s2_g = s2_in_ - s2_n

                    s1_y8h.append({
                        "hour": label,
                        "good": s1_g,          # ➊ keep counts
                        "ng":   s1_n,
                        "yield": compute_yield(s1_g, s1_n),
                        "start": h_start.isoformat(),
                        "end":   h_end.isoformat(),
                    })
                    s2_y8h.append({
                        "hour": label,
                        "good": s2_g,
                        "ng":   s2_n,
                        "yield": compute_yield(s2_g, s2_n),
                        "start": h_start.isoformat(),
                        "end":   h_end.isoformat(),
                    })

                # -------- fermi_data calculation --------
                # Query total stop time for station 93 LMN01
                sql_total_93 = """
                    SELECT SUM(
                        CASE 
                            WHEN st.end_time IS NULL THEN TIMESTAMPDIFF(SECOND, st.start_time, NOW())
                            ELSE st.stop_time
                        END
                    ) AS total_time
                    FROM stops st
                    WHERE st.type = 'STOP'
                    AND st.station_id = 93
                    AND st.start_time BETWEEN %s AND %s
                """
                cursor.execute(sql_total_93, (shift_start, shift_end))
                row93 = cursor.fetchone() or {}
                total_stop_time_93 = row93.get("total_time") or 0
                total_stop_time_minutes_93 = total_stop_time_93 / 60
                available_time_93 = max(0, round(100 - (total_stop_time_minutes_93 / 480 * 100)))

                # Query total stop time for station 47 LMN02
                sql_total_47 = """
                    SELECT SUM(
                        CASE 
                            WHEN st.end_time IS NULL THEN TIMESTAMPDIFF(SECOND, st.start_time, NOW())
                            ELSE st.stop_time
                        END
                    ) AS total_time
                    FROM stops st
                    WHERE st.type = 'STOP'
                    AND st.station_id = 47
                    AND st.start_time BETWEEN %s AND %s
                """
                cursor.execute(sql_total_47, (shift_start, shift_end))
                row47 = cursor.fetchone() or {}
                total_stop_time_47 = row47.get("total_time") or 0
                total_stop_time_minutes_47 = total_stop_time_47 / 60
                available_time_47 = max(0, round(100 - (total_stop_time_minutes_47 / 480 * 100)))

                # Query top 4 stops (grouped) for both stations
                sql_top = """
                    SELECT s.name AS station_name, st.reason,
                        COUNT(*) AS n_occurrences,
                        SUM(
                            CASE 
                                WHEN st.end_time IS NULL THEN TIMESTAMPDIFF(SECOND, st.start_time, NOW())
                                ELSE st.stop_time
                            END
                        ) AS total_time
                    FROM stops st
                    JOIN stations s ON st.station_id = s.id
                    WHERE st.type = 'STOP'
                    AND st.station_id IN (93, 47)
                    AND st.start_time BETWEEN %s AND %s
                    GROUP BY st.station_id, st.reason
                    ORDER BY total_time DESC
                    LIMIT 4
                """
                cursor.execute(sql_top, (shift_start, shift_end))
                fermi_data = []
                top_rows = cursor.fetchall()

                for row in top_rows:
                    total_minutes = round(row["total_time"] / 60)
                    fermi_data.append({
                        "causale": row["reason"],
                        "station": row["station_name"],
                        "count": row["n_occurrences"],
                        "time": total_minutes
                    })

                # Query all currently OPEN stops (not grouped)
                sql_open = """
                    SELECT s.name AS station_name, st.reason, st.start_time
                    FROM stops st
                    JOIN stations s ON st.station_id = s.id
                    WHERE st.type = 'STOP'
                    AND st.status = 'OPEN'
                    AND st.station_id IN (93, 47)
                """
                cursor.execute(sql_open)
                open_rows = cursor.fetchall()

                for row in open_rows:
                    elapsed_min = int((datetime.now() - row["start_time"]).total_seconds() // 60)
                    stop_entry = {
                        "causale": row["reason"] or "Fermo",
                        "station": row["station_name"],
                        "count": 1,
                        "time": elapsed_min
                    }
                    if not any(f["causale"] == stop_entry["causale"] and f["station"] == stop_entry["station"] for f in fermi_data):
                        fermi_data.insert(0, stop_entry)

                # Append both available times at the end
                fermi_data.append({"Available_Time_1": f"{available_time_93}"})
                fermi_data.append({"Available_Time_2": f"{available_time_47}"})


                # -------- top_defects_qg2 calculation from productions + object_defects --------
                # 1️⃣ Query productions table for esito 6 on stations 1+2
                sql_productions = """
                    SELECT id, station_id
                    FROM productions
                    WHERE esito = 6
                    AND station_id IN (1, 2)
                    AND start_time BETWEEN %s AND %s
                """
                cursor.execute(sql_productions, (shift_start, shift_end))
                rows = cursor.fetchall()

                # Split production IDs by station
                production_ids_1 = [row['id'] for row in rows if row['station_id'] == 1]
                production_ids_2= [row['id'] for row in rows if row['station_id'] == 2]

                all_production_ids = tuple(production_ids_1 + production_ids_2)
                if not all_production_ids:
                    all_production_ids = (0,)

                # 2️⃣ Query object_defects JOIN defects
                sql_defects = """
                    SELECT od.production_id, od.defect_id, d.category
                    FROM object_defects od
                    JOIN defects d ON od.defect_id = d.id
                    WHERE od.production_id IN %s
                """
                cursor.execute(sql_defects, (all_production_ids,))
                rows = cursor.fetchall()

                # Build mapping production_id → station_id
                production_station_map = {pid: 1 for pid in production_ids_1}
                production_station_map.update({pid: 2 for pid in production_ids_2})

                defect_counter = defaultdict(lambda: {1: set(), 2: set()})

                for row in rows:
                    prod_id = row['production_id']
                    category = row['category']
                    station_id = production_station_map.get(prod_id)
                    if station_id:
                        defect_counter[category][station_id].add(prod_id)

                # Aggregate counts
                full_results = []
                for category, stations in defect_counter.items():
                    lmn1_count = len(stations[1])
                    lmn2_count = len(stations[2])
                    total = lmn1_count + lmn2_count
                    full_results.append({
                        "label": category,
                        "lmn1": lmn1_count,
                        "lmn2": lmn2_count,
                        "total": total
                    })

                # Compute total over all categories ✅
                total_defects_qg2 = sum(r["total"] for r in full_results)

                # Then get top 5
                results = sorted(full_results, key=lambda x: x['total'], reverse=True)[:5]
                top_defects_qg2 = [{"label": r["label"], "lmn1": r["lmn1"], "lmn2": r["lmn2"]} for r in results]

                # -------- top_defects_vpf (defects 12,14,15 from station 56, grouped by source station 93/47) ------
                sql_vpf_productions = """
                    SELECT p56.id, origin.station_id AS origin_station
                    FROM productions p56
                    JOIN productions origin ON p56.object_id = origin.object_id
                    WHERE p56.esito = 6
                    AND p56.station_id = 56
                    AND p56.start_time BETWEEN %s AND %s
                    AND origin.station_id IN (93, 47)
                """
                cursor.execute(sql_vpf_productions, (shift_start, shift_end))
                vpf_rows = cursor.fetchall()

                vpf_prod_ids = [row['id'] for row in vpf_rows]
                vpf_prod_map = {row['id']: row['origin_station'] for row in vpf_rows}

                if not vpf_prod_ids:
                    top_defects_vpf = []
                else:
                    placeholders = ','.join(['%s'] * len(vpf_prod_ids))
                    sql_vpf_defects = f"""
                        SELECT od.production_id, d.category
                        FROM object_defects od
                        JOIN defects d ON od.defect_id = d.id
                        WHERE od.production_id IN ({placeholders})
                        AND od.defect_id IN (12, 14, 15)
                    """
                    cursor.execute(sql_vpf_defects, vpf_prod_ids)
                    defect_rows = cursor.fetchall()

                    vpf_counter: Dict[str, Dict[int, int]] = defaultdict(lambda: {93: 0, 47: 0})
                    for row in defect_rows:
                        pid = row["production_id"]
                        category = row["category"]
                        if pid in vpf_prod_map:
                            station = vpf_prod_map[pid]
                            if station in (93, 47):
                                vpf_counter[category][station] += 1

                    vpf_results = []
                    for category, stations in vpf_counter.items():
                        c93 = stations[93]
                        c47 = stations[47]
                        total = c93 + c47
                        vpf_results.append({
                            "label": category,
                            "lmn1": c93,  # LMN1 = 93
                            "lmn2": c47,  # LMN02 = 47
                            "total": total
                        })

                    top5_vpf = sorted(vpf_results, key=lambda r: r["total"], reverse=True)[:5]
                    top_defects_vpf = [
                        {"label": r["label"], "lmn1": r["lmn1"], "lmn2": r["lmn2"]}
                        for r in top5_vpf
                    ]

                return {
                    "station_1_in": s1_in,
                    "station_2_in": s2_in,
                    "station_1_out_ng": s1_ng,
                    "station_2_out_ng": s2_ng,
                    "station_1_yield": s1_y,
                    "station_2_yield": s2_y,
                    "station_1_yield_shifts": s1_yield_shifts,
                    "station_2_yield_shifts": s2_yield_shifts,
                    "station_1_yield_last_8h": s1_y8h,
                    "station_2_yield_last_8h": s2_y8h,
                    "shift_throughput": shift_throughput,
                    "last_8h_throughput": last_8h_throughput,
                    "__shift_start": shift_start.isoformat(),
                    "__last_hour": hour_start.isoformat(),
                    "fermi_data": fermi_data,
                    "top_defects_qg2": top_defects_qg2,
                    "top_defects_vpf": top_defects_vpf,
                    "total_defects_qg2": total_defects_qg2,
                }
    except Exception as e:
        logger.exception(f"compute_zone_snapshot() FAILED for zone=AIN: {e}")
        raise

def _compute_snapshot_deltamax(now: datetime) -> dict:

    def fpy_counts(cursor, station_name: str, start, end):
        sql = f"""
            WITH first_pass AS (
                SELECT o.id_modulo AS object_id,
                    p.esito,
                    ROW_NUMBER() OVER (
                        PARTITION BY o.id_modulo
                        ORDER BY p.start_time ASC
                    ) AS rn
                FROM productions p
                JOIN stations s ON p.station_id = s.id
                JOIN objects o ON o.id = p.object_id
                WHERE s.name = %s
                AND p.start_time BETWEEN %s AND %s
            )
            SELECT
                COALESCE(SUM(esito <> 6), 0) AS good,
                COALESCE(SUM(esito  = 6), 0) AS ng,
                COUNT(*)                     AS total
            FROM first_pass
            WHERE rn = 1
        """
        cursor.execute(sql, (station_name, start, end))
        return cursor.fetchone()

    def rwk_counts(cursor, station_name: str, start, end):
        sql = f"""
            WITH last_pass AS (
                SELECT o.id_modulo AS object_id,
                    p.esito,
                    ROW_NUMBER() OVER (
                        PARTITION BY o.id_modulo
                        ORDER BY p.start_time DESC
                    ) AS rn
                FROM productions p
                JOIN stations s ON p.station_id = s.id
                JOIN objects o ON o.id = p.object_id
                WHERE s.name = %s
                AND p.start_time BETWEEN %s AND %s
            )
            SELECT
                COALESCE(SUM(esito <> 6), 0) AS good,
                COALESCE(SUM(esito  = 6), 0) AS ng,
                COUNT(*)                     AS total
            FROM last_pass
            WHERE rn = 1
        """
        cursor.execute(sql, (station_name, start, end))
        return cursor.fetchone()

    try:
        if now is None:
            now = datetime.now()

        hour_start = now.replace(minute=0, second=0, microsecond=0)
        cfg = ZONE_SOURCES["DELTAMAX"]

        shift_start, shift_end = get_shift_window(now)

        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:

                # First pass stats
                s1_in = count_unique_objects(cursor, cfg["station_1_in"], shift_start, shift_end, "all")
                s1_in_r0 = count_unique_objects_r0(cursor, cfg["station_1_in"], shift_start, shift_end, "all")
                s1_ng = count_unique_objects(cursor, cfg["station_1_out_ng"], shift_start, shift_end, "ng")
                s1_ng_r0 = count_unique_objects_r0(cursor, cfg["station_1_out_ng"], shift_start, shift_end, "ng")
                s1_g = s1_in - s1_ng
                s1_g_r0 = s1_in_r0 - s1_ng_r0

                s2_in_r0  = count_unique_objects_r0(cursor, cfg["station_2_in"],  shift_start, shift_end, "all")
                s2_ng_r0 = count_unique_objects_r0(cursor, cfg["station_2_out_ng"], shift_start, shift_end, "ng")
                s2_g_r0 = s2_in_r0 - s2_ng_r0

                # Rework stats
                s2_in = count_unique_objects(cursor, cfg["station_2_in"], shift_start, shift_end, "all")
                s2_ng = count_unique_objects(cursor, cfg["station_2_out_ng"], shift_start, shift_end, "ng")
                s2_g = s2_in - s2_ng

                # Gauge 1: re-entry rate
                cursor.execute("""
                    SELECT COUNT(*) AS multi_entry
                    FROM (
                        SELECT o.id_modulo AS object_id
                        FROM productions p
                        JOIN stations s ON s.id = p.station_id
                        JOIN objects o ON o.id = p.object_id
                        WHERE s.name = %s
                        AND p.start_time BETWEEN %s AND %s
                        GROUP BY o.id_modulo
                        HAVING COUNT(*) > 1
                    ) AS sub
                """, (cfg["station_1_in"], shift_start, shift_end))

                multi_entry = cursor.fetchone()["multi_entry"] or 0

                s2_in = count_unique_objects(cursor, cfg["station_2_in"], shift_start, shift_end, "all")


                value_gauge_1 = round((multi_entry / s2_in) * 100, 2) if s2_in else 0.0

                # ---- Gauge 2 ---------------------------------------------------------------
                # Step 1 — Get all object_ids that passed station_1_in >1 times
                cursor.execute("""
                    SELECT o.id_modulo AS object_id
                    FROM productions p
                    JOIN stations s ON s.id = p.station_id
                    JOIN objects o ON o.id = p.object_id
                    WHERE s.name = %s
                    AND p.start_time BETWEEN %s AND %s
                    GROUP BY o.id_modulo
                    HAVING COUNT(*) > 1
                """, (cfg["station_1_in"], shift_start, shift_end))

                multi_entry_ids = [row["object_id"] for row in cursor.fetchall()]
                multi_entry_count = len(multi_entry_ids)

                if not multi_entry_ids:
                    value_gauge_2 = 0.0
                else:
                    format_ids = ','.join(['%s'] * len(multi_entry_ids))
                    cursor.execute(f"""
                        WITH last_pass AS (
                            SELECT o.id_modulo AS object_id, p.esito,
                                ROW_NUMBER() OVER (
                                    PARTITION BY o.id_modulo
                                    ORDER BY p.start_time DESC
                                ) AS rn
                            FROM productions p
                            JOIN stations s ON s.id = p.station_id
                            JOIN objects o ON o.id = p.object_id
                            WHERE s.name = %s
                            AND o.id_modulo IN ({format_ids})
                        )
                        SELECT COUNT(*) AS good_final
                        FROM last_pass
                        WHERE rn = 1 AND esito = 1
                    """, (cfg["station_1_in"], *multi_entry_ids))

                    good_final = cursor.fetchone()["good_final"] or 0
                    value_gauge_2 = round((good_final / multi_entry_count) * 100, 2)

                # --- NG Counters ---
                s1_ng = count_unique_objects(cursor, cfg["station_1_out_ng"], shift_start, shift_end, "ng")

                cnt_fpy = fpy_counts(cursor, cfg["station_1_in"][0], shift_start, now)
                cnt_rwk = rwk_counts(cursor, cfg["station_1_in"][0], shift_start, now)

                fpy_y = compute_yield(cnt_fpy["good"], cnt_fpy["ng"])
                rwk_y = compute_yield(cnt_rwk["good"], cnt_rwk["ng"])

                # -------- last 3 shifts yield + throughput -------
                FPY_yield_shifts, RWK_yield_shifs, shift_throughput = [], [], []
                for label, start, end in get_previous_shifts(now):
                    # First-pass (R0) yield stats
                    s1_in_r0_  = count_unique_objects_r0(cursor, cfg["station_1_in"],  start, end, "all")
                    s1_ng_r0_  = count_unique_objects_r0(cursor, cfg["station_1_out_ng"], start, end, "ng")
                    s1_g_r0_   = s1_in_r0_ - s1_ng_r0_

                    s1_in_     = count_unique_objects(cursor, cfg["station_1_in"],  start, end, "all")
                    s1_n_      = count_unique_objects(cursor, cfg["station_1_out_ng"], start, end, "ng")

                    s2_in_     = count_unique_objects(cursor, cfg["station_2_in"],  start, end, "all")
                    s2_n_      = count_unique_objects(cursor, cfg["station_2_out_ng"], start, end, "ng")

                    cnt_f = fpy_counts(cursor, cfg["station_1_in"][0], start, end)
                    cnt_r = rwk_counts(cursor, cfg["station_1_in"][0], start, end)

                    FPY_yield_shifts.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "yield": compute_yield(cnt_f["good"], cnt_f["ng"]),
                        "good": cnt_f["good"],
                        "ng":   cnt_f["ng"]
                    })

                    RWK_yield_shifs.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "yield": compute_yield(cnt_r["good"], cnt_r["ng"]),
                        "good": cnt_r["good"],
                        "ng":   cnt_r["ng"]
                    })

                    # Throughput (sum of distinct entries on station 1 + station 2)
                    tot = (count_unique_objects(cursor, cfg["station_1_in"], start, end, "all") +
                        count_unique_objects(cursor, cfg["station_2_in"], start, end, "all"))
                    ng = s1_n_
                    shift_throughput.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "total": tot,
                        "ng": ng,
                        "scrap": s2_n_
                    })

                # Insert current shift’s yield at the front
                FPY_yield_shifts.insert(0, {
                    "label": label,
                    "start": shift_start.isoformat(),
                    "end": now.isoformat(),
                    "good": s1_in_r0 - s1_ng_r0,
                    "ng":   s1_ng_r0,
                    "yield": fpy_y
                })

                RWK_yield_shifs.insert(0, {
                    "label": label,
                    "start": shift_start.isoformat(),
                    "end": now.isoformat(),
                    "station_1_in": s1_in,
                    "station_1_out_ng": s1_ng,
                    "station_2_in": s2_in,
                    "yield": rwk_y
                })

                # -------- last 8 h bins (yield + throughput) -----
                last_8h_throughput, FPY_y8h, RWK_y8h = [], [], []
                for label, h_start, h_end in get_last_8h_bins(now):
                    # Throughput (distinct entries on station 1 + station 2)
                    tot  = (count_unique_objects(cursor, cfg["station_1_in"], h_start, h_end, "all") +
                            count_unique_objects(cursor, cfg["station_2_in"], h_start, h_end, "all")) or 0
                    ng   = (count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng")) or 0
                    scrap = count_unique_objects(cursor, cfg["station_2_out_ng"], h_start, h_end, "ng") or 0

                    last_8h_throughput.append({
                        "hour": label,
                        "start": h_start.isoformat(),
                        "end": h_end.isoformat(),
                        "total": tot,
                        "ng": ng,
                        "scrap": scrap
                    })

                    # FPY yield per 8h bin (first-pass only)
                    s1_in_r0_  = count_unique_objects_r0(cursor, cfg["station_1_in"], h_start, h_end, "all") or 0
                    s1_ng_r0_  = count_unique_objects_r0(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng") or 0
                    s1_g_r0_   = s1_in_r0_ - s1_ng_r0_

                    cnt_f = fpy_counts(cursor, cfg["station_1_in"][0], h_start, h_end)
                    cnt_r = rwk_counts(cursor, cfg["station_1_in"][0], h_start, h_end)

                    FPY_y8h.append({
                        "hour": label,
                        "good": cnt_f["good"],
                        "ng":   cnt_f["ng"],
                        "yield": compute_yield(cnt_f["good"], cnt_f["ng"]),
                        "start": h_start.isoformat(),
                        "end": h_end.isoformat(),
                    })

                    RWK_y8h.append({
                        "hour": label,
                        "good": cnt_r["good"],
                        "ng":   cnt_r["ng"],
                        "yield": compute_yield(cnt_r["good"], cnt_r["ng"]),
                        "start": h_start.isoformat(),
                        "end": h_end.isoformat(),
                    })

                        # -------- count re-entered modules in Deltamax (station 92 + station 40) --------
                sql_reentered_ell = """
                    SELECT COUNT(*) AS re_entered
                    FROM (
                        SELECT o.id_modulo AS object_id
                        FROM productions p
                        JOIN objects o ON o.id = p.object_id
                        WHERE station_id IN (92, 40)
                        AND start_time BETWEEN %s AND %s
                        GROUP BY o.id_modulo
                        HAVING COUNT(DISTINCT station_id) > 1
                    ) sub
                """
                cursor.execute(sql_reentered_ell, (shift_start, shift_end))
                result = cursor.fetchone()
                reentered_count = result["re_entered"] if result and "re_entered" in result else 0

                # ========== For real-time gauge tracking after restart ==========
                # Multi-entry object_ids
                cursor.execute("""
                    SELECT o.id_modulo AS object_id, COUNT(*) AS cnt
                    FROM productions p
                    JOIN stations s ON s.id = p.station_id
                    JOIN objects o ON o.id = p.object_id
                    WHERE s.name = %s AND p.start_time BETWEEN %s AND %s
                    GROUP BY o.id_modulo
                """, (cfg["station_1_in"], shift_start, now))

                s1_entry_count = {}
                multi_entry_set = set()
                for row in cursor.fetchall():
                    oid = row["object_id"]
                    cnt = row["cnt"]
                    s1_entry_count[oid] = cnt
                    if cnt > 1:
                        multi_entry_set.add(oid)

                # s2_entry_set
                cursor.execute("""
                    SELECT DISTINCT o.id_modulo AS object_id
                    FROM productions p
                    JOIN stations s ON s.id = p.station_id
                    JOIN objects o ON o.id = p.object_id
                    WHERE s.name = %s AND p.start_time BETWEEN %s AND %s
                """, (cfg["station_2_in"], shift_start, now))
                s2_entry_set = {row["object_id"] for row in cursor.fetchall()}

                # s1_success_set: multi-entry modules with final esito = 1
                s1_success_set = set()
                if multi_entry_set:
                    format_ids = ','.join(['%s'] * len(multi_entry_set))
                    cursor.execute(f"""
                        WITH last_pass AS (
                            SELECT o.id_modulo AS object_id, p.esito,
                                ROW_NUMBER() OVER (
                                    PARTITION BY o.id_modulo
                                    ORDER BY p.start_time DESC
                                ) AS rn
                            FROM productions p
                            JOIN stations s ON s.id = p.station_id
                            JOIN objects o ON o.id = p.object_id
                            WHERE s.name = %s
                            AND o.id_modulo IN ({format_ids})
                        )
                        SELECT object_id
                        FROM last_pass
                        WHERE rn = 1 AND esito = 1
                    """, (cfg["station_1_in"], *multi_entry_set))
                    s1_success_set = {row["object_id"] for row in cursor.fetchall()}

                # latest_esito + latest_ts
                cursor.execute("""
                    SELECT o.id_modulo AS object_id, p.esito, p.start_time
                    FROM productions p
                    JOIN stations s ON s.id = p.station_id
                    JOIN objects o ON o.id = p.object_id
                    WHERE s.name IN (%s, %s) AND p.start_time BETWEEN %s AND %s
                """, (*cfg["station_1_in"], *cfg["station_1_out_ng"], shift_start, now))

                latest_esito, latest_ts = {}, {}
                for row in cursor.fetchall():
                    oid = row["object_id"]
                    ts = row["start_time"]
                    if oid not in latest_ts or ts > latest_ts[oid]:
                        latest_ts[oid] = ts
                        latest_esito[oid] = row["esito"]


    except Exception as e:
        logger.exception(f"compute_zone_snapshot() FAILED for zone=ELL: {e}")
        raise

    return {
            "station_1_in": s1_in,
            "station_2_in": s2_in,
            "station_1_out_ng": s1_ng,
            "station_2_out_ng": s2_ng,
            "station_1_r0_in": s1_in_r0,
            "station_1_r0_ng": s1_ng_r0,
            "station_2_r0_in":  s2_in_r0,
            "station_2_r0_ng":  s2_ng_r0,
            "FPY_yield": fpy_y,
            "RWK_yield": rwk_y,
            "FPY_yield_shifts": FPY_yield_shifts,
            "RWK_yield_shifts": RWK_yield_shifs,
            "FPY_yield_last_8h": FPY_y8h,
            "RWK_yield_last_8h": RWK_y8h,
            "shift_throughput": shift_throughput,
            "last_8h_throughput": last_8h_throughput,
            "__shift_start": shift_start.isoformat(),
            "__last_hour": hour_start.isoformat(),
            "value_gauge_1": value_gauge_1,
            "value_gauge_2": value_gauge_2,
            "s1_entry_count": s1_entry_count,
            "s2_entry_set": s2_entry_set,
            "multi_entry_set": multi_entry_set,
            "s1_success_set": s1_success_set,
            "latest_esito": latest_esito,
            "latest_ts": {k: v.isoformat() for k, v in latest_ts.items()}
        }