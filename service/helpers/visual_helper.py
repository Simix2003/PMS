# service/helpers/visual_helpers.py
from datetime import datetime, timedelta
import asyncio
import logging
import os
import sys
import copy
from collections import defaultdict
from threading import RLock 
from typing import Dict, DefaultDict

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection
from service.config.config import ZONE_SOURCES
from service.state import global_state
from service.routes.broadcast import broadcast_zone_update

_update_lock = RLock()

logger = logging.getLogger("PMS")

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

# ─────────────────────────────────────────────────────────────────────────────
def compute_zone_snapshot(zone: str, now: datetime | None = None) -> dict:
    try:
        if now is None:
            now = datetime.now()

        hour_start = now.replace(minute=0, second=0, microsecond=0)
        cfg = ZONE_SOURCES[zone]

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
                "yield": compute_yield(s1_g, s1_n),
                "start": h_start.isoformat(),
                "end": h_end.isoformat()
            })

            s2_y8h.append({
                "hour": label,
                "yield": compute_yield(s2_g, s2_n),
                "start": h_start.isoformat(),
                "end": h_end.isoformat()
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
            AND reason IN (
            'Fermo Generico',
            'Cancelli Aperti',
            'Anomalia',
            'Ciclo non Automatico',
            'Fuori Tempo Ciclo'
            )
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
            AND reason IN (
            'Fermo Generico',
            'Cancelli Aperti',
            'Anomalia',
            'Ciclo non Automatico',
            'Fuori Tempo Ciclo'
            )
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
        logger.exception(f"❌ compute_zone_snapshot() FAILED for zone={zone}: {e}")
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
        ts: datetime
    ) -> None:

    if zone not in global_state.visual_data:
        global_state.visual_data[zone] = compute_zone_snapshot(zone, now=ts)
        return

    with _update_lock:
        data = global_state.visual_data[zone]
        cfg = ZONE_SOURCES[zone]

        current_shift_start, current_shift_end = get_shift_window(ts)
        cached_shift_start = data.get("__shift_start")

        if cached_shift_start != current_shift_start.isoformat():
            global_state.visual_data[zone] = compute_zone_snapshot(zone, now=ts)
            return

        # 2. Update counters
        if station_name in cfg["station_1_in"]:
            data["station_1_in"] += 1
        elif station_name in cfg["station_2_in"]:
            data["station_2_in"] += 1

        if esito == 6:
            if station_name in cfg["station_1_out_ng"]:
                data["station_1_out_ng"] += 1
            elif station_name in cfg["station_2_out_ng"]:
                data["station_2_out_ng"] += 1

            # Refresh top defects
            #refresh_top_defects_qg2(zone, ts)

        # 3. Recompute shift yield
        s1_good = data["station_1_in"] - data["station_1_out_ng"]
        s2_good = data["station_2_in"] - data["station_2_out_ng"]
        data["station_1_yield"] = compute_yield(s1_good, data["station_1_out_ng"])
        data["station_2_yield"] = compute_yield(s2_good, data["station_2_out_ng"])

        # 3-bis. Shift throughput
        current_shift_label = (
            "S1" if 6 <= current_shift_start.hour < 14 else
            "S2" if 14 <= current_shift_start.hour < 22 else
            "S3"
        )

        is_in_station = station_name in cfg["station_1_in"] or station_name in cfg["station_2_in"]
        is_qc_station = station_name in cfg["station_1_out_ng"] or station_name in cfg["station_2_out_ng"]

        for shift in data["shift_throughput"]:
            if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
                if is_in_station:
                    shift["total"] += 1
                if esito == 6 and is_qc_station:
                    shift["ng"] += 1
                break

        # 4. Update yield shifts
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

        def _touch_hourly(list_key, is_station1: bool):
            lst = data[list_key]
            if not lst or lst[-1]["hour"] != hour_label:
                lst[:] = lst[-7:]
                lst.append({
                    "hour": hour_label,
                    "start": ts.isoformat(),
                    "end": (ts + timedelta(hours=1)).isoformat(),
                    "total": 0, "ng": 0, "yield": 100
                })

            entry = lst[-1]
            if "total" in entry:
                entry["total"] += 1
                if esito == 6:
                    entry["ng"] += 1
            else:
                if esito == 6:
                    entry["ng"] = entry.get("ng", 0) + 1
                else:
                    entry["good"] = entry.get("good", 0) + 1
                good = entry.get("good", 0)
                ng = entry.get("ng", 0)
                entry["yield"] = compute_yield(good, ng)

        if is_in_station or (esito == 6 and is_qc_station):
            _touch_hourly("last_8h_throughput", False)

        if station_name in cfg["station_1_out_ng"]:
            _touch_hourly("station_1_yield_last_8h", True)
        elif station_name in cfg["station_2_out_ng"]:
            _touch_hourly("station_2_yield_last_8h", True)

        # 6. WebSocket push
        try:
            loop = asyncio.get_running_loop()
            payload = copy.deepcopy(data)
            loop.call_soon_threadsafe(
                lambda: asyncio.create_task(
                    broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
                )
            )

        except Exception as e:
            logger.warning(f"⚠️ Could not schedule WebSocket update for {zone}: {e}")

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
                AND reason IN (
                    'Fermo Generico',
                    'Cancelli Aperti',
                    'Anomalia',
                    'Ciclo non Automatico',
                    'Fuori Tempo Ciclo'
                )
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
                AND reason IN (
                    'Fermo Generico',
                    'Cancelli Aperti',
                    'Anomalia',
                    'Ciclo non Automatico',
                    'Fuori Tempo Ciclo'
                )
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