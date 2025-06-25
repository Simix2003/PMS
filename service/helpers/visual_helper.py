# service/helpers/visual_helpers.py
from datetime import datetime, timedelta
import asyncio
import logging
import os
import sys
import copy
from collections import defaultdict
from threading import RLock 
from typing import Dict, DefaultDict, Any, Optional
import json
from statistics import median

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection
from service.config.config import ZONE_SOURCES, TARGETS_FILE, DEFAULT_TARGETS
from service.state import global_state
from service.routes.broadcast import broadcast_zone_update

_update_lock = RLock()

logger = logging.getLogger("PMS")


def load_targets():
    try:
        with open(TARGETS_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return DEFAULT_TARGETS.copy()

def save_targets(data: dict):
    with open(TARGETS_FILE, "w") as f:
        json.dump(data, f)

# ─────────────────────────────────────────────────────────────────────────────
def get_shift_window(now: datetime):
    hour = now.hour
    if 6 <= hour < 14:
        start = now.replace(hour=6, minute=0, second=0, microsecond=0)
        end   = now.replace(hour=14, minute=0, second=0, microsecond=0)
    elif 14 <= hour < 22:
        start = now.replace(hour=14, minute=0, second=0, microsecond=0)
        end   = now.replace(hour=22, minute=0, second=0, microsecond=0)
    else:
        if hour >= 22:
            start = now.replace(hour=22, minute=0, second=0, microsecond=0)
            end   = (now + timedelta(days=1)).replace(hour=6, minute=0, second=0, microsecond=0)
        else:
            start = (now - timedelta(days=1)).replace(hour=22, minute=0, second=0, microsecond=0)
            end   = now.replace(hour=6, minute=0, second=0, microsecond=0)
    return start, end

def count_unique_objects(cursor, station_names, start, end, esito_filter):
    placeholders = ", ".join(["%s"] * len(station_names))
    params = station_names + [start, end]
    if esito_filter == "good":
        esito_condition = "AND p.esito IN (1, 5, 7)"
    elif esito_filter == "ng":
        esito_condition = "AND p.esito = 6"
    else:
        esito_condition = ""

    sql = f"""
        SELECT COUNT(DISTINCT p.object_id) AS cnt
        FROM productions p
        JOIN stations s ON p.station_id = s.id
        WHERE s.name IN ({placeholders})
          AND p.end_time BETWEEN %s AND %s
          {esito_condition}
    """
    cursor.execute(sql, tuple(params))
    return cursor.fetchone()["cnt"] or 0

def get_previous_shifts(now: datetime, n: int = 3):
    shifts = []
    ref = now
    for _ in range(n):
        start, end = get_shift_window(ref)
        label = (
            "S1" if 6 <= start.hour < 14 else
            "S2" if 14 <= start.hour < 22 else
            "S3"
        )
        shifts.insert(0, (label, start, end))  # newest at the end
        ref = start - timedelta(seconds=1)
    return shifts

def get_last_8h_bins(now: datetime):
    bins = []
    for i in range(8):
        h_start = (now - timedelta(hours=7 - i)).replace(minute=0, second=0, microsecond=0)
        h_end   = h_start + timedelta(hours=1)
        label   = h_start.strftime("%H:%M")
        bins.append((label, h_start, h_end))
    return bins

def compute_yield(good: int, ng: int):
    total = good + ng
    if total == 0:
        return 0  # or return None if you want to hide it from the frontend
    return round((good / total) * 100)

def time_to_seconds(time_val: timedelta) -> int:
    return time_val.seconds if isinstance(time_val, timedelta) else 0

def compute_zone_snapshot(zone: str, now: datetime | None = None) -> dict:
    try:
        if now is None:
            now = datetime.now()

        if zone == "VPF":
            return _compute_snapshot_vpf(now)
        elif zone == "AIN":
            return _compute_snapshot_ain(now)
        else:
            raise ValueError(f"Unknown zone: {zone}")

    except Exception as e:
        logger.exception(f"❌ compute_zone_snapshot() FAILED for zone={zone}: {e}")
        raise

# ─────────────────────────────────────────────────────────────────────────────
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

        conn = get_mysql_connection()

        cursor = conn.cursor()

        # -------- current shift totals / yield ----------
        s1_in  = count_unique_objects(cursor, cfg["station_1_in"],  shift_start, shift_end, "all")
        s1_ng  = count_unique_objects(cursor, cfg["station_1_out_ng"], shift_start, shift_end, "ng")
        s1_g   = s1_in - s1_ng
        s1_y   = compute_yield(s1_g, s1_ng)

        # -------- count re-entered modules in VPF (same object_id multiple times) --------
        sql_reentered = """
            SELECT COUNT(*) AS re_entered
            FROM (
              SELECT object_id
              FROM productions
              WHERE station_id = %s
                AND start_time BETWEEN %s AND %s
              GROUP BY object_id
              HAVING COUNT(*) > 1
            ) sub
        """
        cursor.execute(sql_reentered, (56, shift_start, shift_end))  # or cfg["station_1_in_id"] if defined
        result = cursor.fetchone()
        s1_reEntered = result["re_entered"] if result and "re_entered" in result else 0

        # -------- last 3 shifts yield + throughput -------
        s1_yield_shifts = []
        for label, start, end in get_previous_shifts(now):
            # yields
            s1_in_  = count_unique_objects(cursor, cfg["station_1_in"],  start, end, "all")
            s1_n = count_unique_objects(cursor, cfg["station_1_out_ng"], start, end, "ng")
            s1_g = s1_in_ - s1_n

            s1_yield_shifts.append({
                "label": label,
                "start": start.isoformat(),
                "end": end.isoformat(),
                "yield": compute_yield(s1_g, s1_n),
                "good": s1_g,
                "ng": s1_n
            })
        
        # -------- last 8 h bins (yield + throughput) -----
        s1_y8h = []
        for label, h_start, h_end in get_last_8h_bins(now):
            # THROUGHPUT
            # YIELDS PER STATION
            s1_in_  = count_unique_objects(cursor, cfg["station_1_in"],  h_start, h_end, "all") or 0
            s1_n = count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng") or 0
            s1_g = s1_in_ - s1_n

            s1_y8h.append({
                "hour": label,
                "good": s1_g,
                "ng":   s1_n,
                "yield": compute_yield(s1_g, s1_n),
                "start": h_start.isoformat(),
                "end":   h_end.isoformat(),
            })

        # -------- top_defects_vpf (defects from station 56, flat count) ------
        sql_vpf_productions = """
            SELECT p56.id
            FROM productions p56
            WHERE p56.esito = 6
            AND p56.station_id = 56
            AND p56.start_time BETWEEN %s AND %s
            AND NOT EXISTS (
                SELECT 1
                FROM productions p_prev
                WHERE p_prev.object_id = p56.object_id
                AND p_prev.station_id = 56
                AND p_prev.start_time < p56.start_time
            )
        """
        cursor.execute(sql_vpf_productions, (shift_start, shift_end))
        vpf_rows = cursor.fetchall()

        vpf_prod_ids = [row['id'] for row in vpf_rows]

        if not vpf_prod_ids:
            defects_vpf = []
        else:
            placeholders = ','.join(['%s'] * len(vpf_prod_ids))
            sql_vpf_defects = f"""
                SELECT d.category, COUNT(*) AS count
                FROM object_defects od
                JOIN defects d ON od.defect_id = d.id
                WHERE od.production_id IN ({placeholders})
                GROUP BY d.category
            """
            cursor.execute(sql_vpf_defects, vpf_prod_ids)
            defects_vpf = [
                {"label": row["category"], "count": row["count"]}
                for row in cursor.fetchall()
            ]

        # Always prefill eq_defects with zeros
        eq_defects = {
            cat: {station_name: 0 for _, station_name in station_info}
            for cat, station_info in category_station_map.items()
        }

        if vpf_prod_ids:
            # Get mapping defect_category → set(object_id)
            sql_defect_objects = f"""
                SELECT d.category, p.object_id
                FROM object_defects od
                JOIN defects d ON d.id = od.defect_id
                JOIN productions p ON p.id = od.production_id
                WHERE od.production_id IN ({','.join(['%s'] * len(vpf_prod_ids))})
            """
            cursor.execute(sql_defect_objects, vpf_prod_ids)
            defect_to_objects = {}
            for row in cursor.fetchall():
                cat = row["category"]
                oid = row["object_id"]
                defect_to_objects.setdefault(cat, set()).add(oid)

            for cat, station_info in category_station_map.items():
                station_ids = [sid for sid, _ in station_info]
                station_names = {sid: name for sid, name in station_info}

                if cat not in defect_to_objects:
                    continue

                object_ids = defect_to_objects[cat]
                if not station_ids or not object_ids:
                    continue

                object_placeholders = ','.join(['%s'] * len(object_ids))
                station_placeholders = ','.join(['%s'] * len(station_ids))

                sql_check_passages = f"""
                    SELECT p.station_id, COUNT(DISTINCT p.object_id) AS count
                    FROM productions p
                    WHERE p.object_id IN ({object_placeholders})
                    AND p.station_id IN ({station_placeholders})
                    AND p.start_time < (
                        SELECT MIN(p2.start_time)
                        FROM productions p2
                        WHERE p2.station_id = 56
                        AND p2.object_id = p.object_id
                    )
                    GROUP BY p.station_id
                """
                cursor.execute(sql_check_passages, (*object_ids, *station_ids))
                rows = cursor.fetchall()

                for row in rows:
                    sid = row["station_id"]
                    count = row["count"]
                    station_name = station_names.get(sid)
                    if station_name:
                        eq_defects[cat][station_name] = count

        # -------- speed_ratio (median vs current cycle time at station 56) ------
        sql_speed_data = """
            SELECT p.cycle_time
            FROM productions p
            WHERE p.station_id = 56
            AND p.cycle_time IS NOT NULL
            AND p.start_time BETWEEN %s AND %s
            ORDER BY p.start_time ASC
        """
        cursor.execute(sql_speed_data, (shift_start, shift_end))
        raw_rows = cursor.fetchall()
        cycle_times = [time_to_seconds(row["cycle_time"]) for row in raw_rows]

        if cycle_times:
            median_sec = median(cycle_times)
            current_sec = min(cycle_times[-1], 120)
        else:
            median_sec = 0
            current_sec = 0
            print(f"[VPF] No cycle times available — setting both median and current to 0")

        speed_ratio = [{
            "medianSec": median_sec,
            "currentSec": current_sec
        }]

    except Exception as e:
        logger.exception(f"❌ compute_zone_snapshot() FAILED for zone=AIN: {e}")
        raise

    return {
    "station_1_in": s1_in,
    "station_1_out_ng": s1_ng,
    "station_1_re_entered": s1_reEntered,
    "speed_ratio": speed_ratio,
    "station_1_yield": s1_y,
    "station_1_shifts": s1_yield_shifts,
    "station_1_yield_last_8h": s1_y8h,
    "__shift_start": shift_start.isoformat(),
    "__last_hour": hour_start.isoformat(),
    "defects_vpf": defects_vpf,
    "eq_defects": eq_defects,
}

def _compute_snapshot_ain(now: datetime) -> dict:
    try:
        if now is None:
            now = datetime.now()

        hour_start = now.replace(minute=0, second=0, microsecond=0)
        cfg = ZONE_SOURCES["AIN"]

        shift_start, shift_end = get_shift_window(now)

        conn = get_mysql_connection()

        cursor = conn.cursor()

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
        # get top 4 stops in current shift

        # Query total stop time for station 29
        sql_total_29 = """
            SELECT SUM(st.stop_time) AS total_time
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
            SELECT SUM(st.stop_time) AS total_time
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

        # Query top 4 stops for both stations
        sql = """
            SELECT s.name AS station_name, st.reason, COUNT(*) AS n_occurrences, SUM(st.stop_time) AS total_time
            FROM stops st
            JOIN stations s ON st.station_id = s.id
            WHERE st.type = 'STOP'
            AND st.station_id IN (29, 30)
            AND st.start_time BETWEEN %s AND %s
            GROUP BY st.station_id, st.reason
            ORDER BY total_time DESC
            LIMIT 4
        """
        cursor.execute(sql, (shift_start, shift_end))
        fermi_data = []
        for row in cursor.fetchall():
            total_minutes = round(row["total_time"] / 60)
            fermi_data.append({
                "causale": row["reason"],
                "station": row["station_name"],
                "count": row["n_occurrences"],
                "time": total_minutes
            })

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

    except Exception as e:
        logger.exception(f"❌ compute_zone_snapshot() FAILED for zone=AIN: {e}")
        raise

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

def update_visual_data_on_new_module(
    zone: str,
    station_name: str,
    esito: int,
    ts: datetime,
    cycle_time: Optional[str] = None
) -> None:
    if zone not in global_state.visual_data:
        global_state.visual_data[zone] = compute_zone_snapshot(zone, now=ts)
        return

    with _update_lock:
        current_shift_start, _ = get_shift_window(ts)
        data = global_state.visual_data[zone]
        cached_shift_start = data.get("__shift_start")

        if cached_shift_start != current_shift_start.isoformat():
            global_state.visual_data[zone] = compute_zone_snapshot(zone, now=ts)
            return

        if zone == "VPF":
            _update_snapshot_vpf(data, station_name, esito, ts, cycle_time)
        elif zone == "AIN":
            _update_snapshot_ain(data, station_name, esito, ts)
        else:
            logger.warning(f"⚠️ Unknown zone: {zone}")
            return

        # Push via WebSocket
        try:
            loop = asyncio.get_running_loop()
            payload = copy.deepcopy(data)
            print('payload for zone :', zone, 'is:', payload)
            loop.call_soon_threadsafe(
                lambda: asyncio.create_task(
                    broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
                )
            )
        except Exception as e:
            logger.warning(f"⚠️ Could not schedule WebSocket update for {zone}: {e}")

def _update_snapshot_ain(
    data: dict,
    station_name: str,
    esito: int,
    ts: datetime
) -> None:
    cfg = ZONE_SOURCES["AIN"]

    current_shift_start, _ = get_shift_window(ts)
    current_shift_label = (
        "S1" if 6 <= current_shift_start.hour < 14 else
        "S2" if 14 <= current_shift_start.hour < 22 else
        "S3"
    )

    # 1. Update counters
    if station_name in cfg["station_1_in"]:
        data["station_1_in"] += 1
    elif station_name in cfg["station_2_in"]:
        data["station_2_in"] += 1

    if esito == 6:
        if station_name in cfg["station_1_out_ng"]:
            data["station_1_out_ng"] += 1
        elif station_name in cfg["station_2_out_ng"]:
            data["station_2_out_ng"] += 1

    # 2. Recompute yield
    s1_good = data["station_1_in"] - data["station_1_out_ng"]
    s2_good = data["station_2_in"] - data["station_2_out_ng"]
    data["station_1_yield"] = compute_yield(s1_good, data["station_1_out_ng"])
    data["station_2_yield"] = compute_yield(s2_good, data["station_2_out_ng"])

    # 3. Update shift throughput
    is_in_station = station_name in cfg["station_1_in"] or station_name in cfg["station_2_in"]
    is_qc_station = station_name in cfg["station_1_out_ng"] or station_name in cfg["station_2_out_ng"]

    for shift in data["shift_throughput"]:
        if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
            if is_in_station:
                shift["total"] += 1
            if esito == 6 and is_qc_station:
                shift["ng"] += 1
            break

    # 4. Update yield per shift
    def update_shift_yield(station_yield_shifts, is_relevant_station):
        if not is_relevant_station:
            return
        for shift in station_yield_shifts:
            if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
                if esito == 6:
                    shift["ng"] += 1
                else:
                    shift["good"] += 1
                shift["yield"] = compute_yield(shift["good"], shift["ng"])
                break

    update_shift_yield(data["station_1_yield_shifts"], station_name in cfg["station_1_out_ng"])
    update_shift_yield(data["station_2_yield_shifts"], station_name in cfg["station_2_out_ng"])

    # 5. Update hourly bins
    hour_start = ts.replace(minute=0, second=0, microsecond=0)
    hour_label = hour_start.strftime("%H:%M")

    def _touch_hourly(list_key: str):
        lst = data[list_key]
        for entry in lst:
            if entry["hour"] == hour_label:
                if list_key == "last_8h_throughput":
                    entry["total"] += 1
                    if esito == 6:
                        entry["ng"] += 1
                else:
                    if esito == 6:
                        entry["ng"] += 1
                    else:
                        entry["good"] += 1
                    entry["yield"] = compute_yield(entry["good"], entry["ng"])
                break
        else:
            new_entry: Dict[str, Any] = {
                "hour": hour_label,
                "start": hour_start.isoformat(),
                "end": (hour_start + timedelta(hours=1)).isoformat(),
            }
            if list_key == "last_8h_throughput":
                new_entry.update({"total": 1, "ng": 1 if esito == 6 else 0})
            else:
                new_entry.update({
                    "good": 0 if esito == 6 else 1,
                    "ng":   1 if esito == 6 else 0,
                })
                new_entry["yield"] = compute_yield(new_entry["good"], new_entry["ng"])
            lst.append(new_entry)
            lst[:] = lst[-8:]

    if is_in_station or (esito == 6 and is_qc_station):
        _touch_hourly("last_8h_throughput")

    if station_name in cfg["station_1_out_ng"]:
        _touch_hourly("station_1_yield_last_8h")
    elif station_name in cfg["station_2_out_ng"]:
        _touch_hourly("station_2_yield_last_8h")

def _update_snapshot_vpf(
    data: dict,
    station_name: str,
    esito: int,
    ts: datetime,
    cycle_time: Optional[str]
) -> None:
    cfg = ZONE_SOURCES["VPF"]

    current_shift_start, _ = get_shift_window(ts)
    current_shift_label = (
        "S1" if 6 <= current_shift_start.hour < 14 else
        "S2" if 14 <= current_shift_start.hour < 22 else
        "S3"
    )

    # 1. Update counters
    is_in_station = station_name in cfg["station_1_in"]
    is_qc_station = station_name in cfg["station_1_out_ng"]

    if is_in_station:
        data["station_1_in"] += 1

    if esito == 6 and is_qc_station:
        data["station_1_out_ng"] += 1

    # 2. Recompute yield
    good = data["station_1_in"] - data["station_1_out_ng"]
    data["station_1_yield"] = compute_yield(good, data["station_1_out_ng"])

    # 3. Update shift yield (station_1_shifts)
    for shift in data["station_1_shifts"]:
        if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
            if esito == 6:
                shift["ng"] += 1
            else:
                shift["good"] += 1
            shift["yield"] = compute_yield(shift["good"], shift["ng"])
            break

    # 4. Update last 8h hourly bins (station_1_yield_last_8h)
    hour_start = ts.replace(minute=0, second=0, microsecond=0)
    hour_label = hour_start.strftime("%H:%M")

    def _touch_hourly(list_key: str):
        lst = data[list_key]
        for entry in lst:
            if entry["hour"] == hour_label:
                if esito == 6:
                    entry["ng"] += 1
                else:
                    entry["good"] += 1
                entry["yield"] = compute_yield(entry["good"], entry["ng"])
                return
        # Create new hour bin if not found
        new_entry: dict = {
            "hour": hour_label,
            "start": hour_start.isoformat(),
            "end": (hour_start + timedelta(hours=1)).isoformat(),
            "good": 0 if esito == 6 else 1,
            "ng": 1 if esito == 6 else 0,
        }
        new_entry["yield"] = compute_yield(new_entry["good"], new_entry["ng"])
        lst.append(new_entry)
        lst[:] = lst[-8:]

    if is_in_station or (esito == 6 and is_qc_station):
        _touch_hourly("station_1_yield_last_8h")
  
    # 5. Update speed_ratio
    if cycle_time:
        try:
            # Convert cycle_time string to seconds (float)
            h, m, s = cycle_time.split(":")
            current_sec = int(h) * 3600 + int(m) * 60 + float(s)

            # Reuse existing median if present, else fallback
            median_sec = (
                data["speed_ratio"][0]["medianSec"]
                if "speed_ratio" in data and isinstance(data["speed_ratio"], list) and data["speed_ratio"]
                else current_sec
            )

            # Overwrite with latest currentSec, keep fixed median
            data["speed_ratio"] = [{
                "medianSec": median_sec,
                "currentSec": current_sec
            }]

        except Exception as e:
            logger.warning(f"⚠️ Failed to parse cycle_time '{cycle_time}': {e}")

def refresh_fermi_data(zone: str, ts: datetime) -> None:
    """
    Refresh fermi_data for the zone (to be called after stop insert/update).
    """
    with _update_lock:
        if zone not in global_state.visual_data:
            logger.warning(f"⚠️ Cannot refresh fermi_data for unknown zone: {zone}")
            return

        data = global_state.visual_data[zone]
        shift_start, shift_end = get_shift_window(ts)
        conn = get_mysql_connection()
        cursor = conn.cursor()

        try:
            # Total stop time for station 29
            sql_total_29 = """
                SELECT SUM(st.stop_time) AS total_time
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

            # Total stop time for station 30
            sql_total_30 = """
                SELECT SUM(st.stop_time) AS total_time
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

            # Top 4 stop reasons
            sql = """
                SELECT s.name AS station_name, st.reason, COUNT(*) AS n_occurrences, SUM(st.stop_time) AS total_time
                FROM stops st
                JOIN stations s ON st.station_id = s.id
                WHERE st.type = 'STOP'
                  AND st.station_id IN (29, 30)
                  AND st.start_time BETWEEN %s AND %s
                GROUP BY st.station_id, st.reason
                ORDER BY total_time DESC
                LIMIT 4
            """
            cursor.execute(sql, (shift_start, shift_end))
            fermi_data = []
            for row in cursor.fetchall():
                total_minutes = round(row["total_time"] / 60)
                fermi_data.append({
                    "causale": row["reason"],
                    "station": row["station_name"],
                    "count": row["n_occurrences"],
                    "time": total_minutes
                })

            # Add availability values
            fermi_data.append({"Available_Time_1": f"{available_time_29}"})
            fermi_data.append({"Available_Time_2": f"{available_time_30}"})

            # Save and broadcast
            data["fermi_data"] = fermi_data

            loop = asyncio.get_running_loop()
            payload = copy.deepcopy(data)
            loop.call_soon_threadsafe(
                lambda: asyncio.create_task(
                    broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
                )
            )

        except Exception as e:
            logger.exception(f"❌ Error refreshing fermi_data for zone={zone}: {e}")

def refresh_top_defects_qg2(zone: str, ts: datetime) -> None:
    """
    Refresh top_defects_qg2 for the zone (based on esito=6 in current shift).
    """

    try:
        with _update_lock:
            if zone not in global_state.visual_data:
                logger.warning(f"⚠️ Cannot refresh top_defects_qg2 for unknown zone: {zone}")
                return

            data = global_state.visual_data[zone]
            shift_start, shift_end = get_shift_window(ts)

            conn = get_mysql_connection()
            cursor = conn.cursor()

            # 1️⃣ NG productions
            sql_productions = """
                SELECT id, station_id
                FROM productions
                WHERE esito = 6
                AND station_id IN (1, 2)
                AND start_time BETWEEN %s AND %s
            """
            cursor.execute(sql_productions, (shift_start, shift_end))
            rows = cursor.fetchall()

            production_ids_1 = [row['id'] for row in rows if row['station_id'] == 1]
            production_ids_2 = [row['id'] for row in rows if row['station_id'] == 2]
            all_production_ids = production_ids_1 + production_ids_2

            if not all_production_ids:
                data["top_defects_qg2"] = []
                return

            # 2️⃣ Join with object_defects
            placeholders = ','.join(['%s'] * len(all_production_ids))
            sql_defects = f"""
                SELECT od.production_id, d.category
                FROM object_defects od
                JOIN defects d ON od.defect_id = d.id
                WHERE od.production_id IN ({placeholders})
            """
            cursor.execute(sql_defects, all_production_ids)
            rows = cursor.fetchall()

            production_station_map = {pid: 1 for pid in production_ids_1}
            production_station_map.update({pid: 2 for pid in production_ids_2})

            defect_counter = defaultdict(lambda: {1: set(), 2: set()})
            for row in rows:
                pid = row['production_id']
                cat = row['category']
                station_id = production_station_map.get(pid)
                if station_id:
                    defect_counter[cat][station_id].add(pid)

            full_results = []
            for category, stations in defect_counter.items():
                ain1 = len(stations[1])
                ain2 = len(stations[2])
                total = ain1 + ain2
                full_results.append({
                    "label": category,
                    "ain1": ain1,
                    "ain2": ain2,
                    "total": total
                })

            # Compute total over all categories ✅
            data['total_defects_qg2'] = sum(r["total"] for r in full_results)

            top5 = sorted(full_results, key=lambda r: r["total"], reverse=True)[:5]
            data["top_defects_qg2"] = [{"label": r["label"], "ain1": r["ain1"], "ain2": r["ain2"]} for r in top5]

            loop = asyncio.get_running_loop()
            payload = copy.deepcopy(data)
            loop.call_soon_threadsafe(
                lambda: asyncio.create_task(
                    broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
                )
            )

    except Exception as e:
        logger.exception(f"❌ Exception in refresh_top_defects_qg2: {e}")

def refresh_top_defects_vpf(zone: str, ts: datetime) -> None:
    """
    Refresh top_defects_vpf for the zone (based on esito=6 at station_id=56 in current shift,
    and only defects with defect_id in (12, 14, 15)), split by original station_id (29 or 30 → ain1/ain2).
    """
    try:
        with _update_lock:
            if zone not in global_state.visual_data:
                logger.warning(f"⚠️ Cannot refresh top_defects_vpf for unknown zone: {zone}")
                return

            data = global_state.visual_data[zone]
            shift_start, shift_end = get_shift_window(ts)

            conn = get_mysql_connection()
            cursor = conn.cursor()

            # 1️⃣ Get NG productions at station 56, with origin station 29 or 30
            sql_productions = """
                SELECT p56.id, origin.station_id AS origin_station
                FROM productions p56
                JOIN productions origin ON p56.object_id = origin.object_id
                WHERE p56.esito = 6
                  AND p56.station_id = 56
                  AND p56.start_time BETWEEN %s AND %s
                  AND origin.station_id IN (29, 30)
            """
            cursor.execute(sql_productions, (shift_start, shift_end))
            rows = cursor.fetchall()
            production_ids = [row['id'] for row in rows]
            production_station_map = {row['id']: row['origin_station'] for row in rows}

            if not production_ids:
                data["top_defects_vpf"] = []
                return

            # 2️⃣ Filter by defect_id IN (12, 14, 15)
            placeholders = ','.join(['%s'] * len(production_ids))
            sql_defects = f"""
                SELECT od.production_id, d.category
                FROM object_defects od
                JOIN defects d ON od.defect_id = d.id
                WHERE od.production_id IN ({placeholders})
                  AND od.defect_id IN (12, 14, 15)
            """
            cursor.execute(sql_defects, production_ids)
            rows = cursor.fetchall()

            # 3️⃣ Count by category and origin station (29 → ain1, 30 → ain2)
            defect_counter: DefaultDict[str, Dict[int, int]] = defaultdict(lambda: {29: 0, 30: 0})
            for row in rows:
                pid = row["production_id"]
                category = row["category"]
                origin_station = production_station_map.get(pid)
                if isinstance(origin_station, int) and origin_station in (29, 30):
                    defect_counter[category][origin_station] += 1


            # 4️⃣ Aggregate + top 5 by total
            full_results = []
            for category, stations in defect_counter.items():
                c29 = stations[29]
                c30 = stations[30]
                total = c29 + c30
                full_results.append({
                    "label": category,
                    "ain1": c29,  # 29
                    "ain2": c30,  # 30
                    "total": total
                })

            top5 = sorted(full_results, key=lambda r: r["total"], reverse=True)[:5]
            data["top_defects_vpf"] = [
                {"label": r["label"], "ain1": r["ain1"], "ain2": r["ain2"]}
                for r in top5
            ]

            # 5️⃣ WebSocket push
            loop = asyncio.get_running_loop()
            payload = copy.deepcopy(data)
            loop.call_soon_threadsafe(
                lambda: asyncio.create_task(
                    broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
                )
            )

    except Exception as e:
        logger.exception(f"❌ Exception in refresh_top_defects_vpf: {e}")