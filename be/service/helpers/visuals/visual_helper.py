# service/helpers/visuals/visual_helpers.py
from datetime import datetime, timedelta
import asyncio
import logging
import os
import sys
import copy
from collections import defaultdict
from typing import Dict, DefaultDict, Any, List, Optional
import json
from statistics import median
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection
from service.config.config import ELL_VISUAL, ZONE_SOURCES, TARGETS_FILE, DEFAULT_TARGETS
from service.state import global_state
from service.routes.broadcast import broadcast_zone_update

logger = logging.getLogger(__name__)


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

def get_shift_label(now: datetime) -> str:
    hour = now.hour
    if 6 <= hour < 14:
        return "S1"
    elif 14 <= hour < 22:
        return "S2"
    else:
        return "S3"

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
        SELECT COUNT(*) AS cnt
        FROM (
            SELECT p.object_id
            FROM productions p
            JOIN stations s ON p.station_id = s.id
            WHERE s.name IN ({placeholders})
            AND p.end_time BETWEEN %s AND %s
            {esito_condition}
            AND NOT EXISTS (
                SELECT 1
                FROM productions p2
                WHERE p2.object_id = p.object_id
                AND p2.station_id = p.station_id
                AND p2.end_time > p.end_time
            )
        ) AS latest_productions
    """
    cursor.execute(sql, tuple(params))
    return cursor.fetchone()["cnt"] or 0

def count_unique_objects_r0(cursor, station_names, start, end, esito_filter):
    placeholders = ", ".join(["%s"] * len(station_names))
    params = station_names + [start, end]
    if esito_filter == "good":
        esito_condition = "AND p.esito IN (1, 5, 7)"
    elif esito_filter == "ng":
        esito_condition = "AND p.esito = 6"
    else:
        esito_condition = ""

    sql = f"""
        SELECT COUNT(*) AS cnt
        FROM (
            SELECT p.object_id
            FROM productions p
            JOIN stations s ON p.station_id = s.id
            WHERE s.name IN ({placeholders})
              AND p.end_time BETWEEN %s AND %s
              {esito_condition}
              AND NOT EXISTS (
                  SELECT 1
                  FROM productions p2
                  WHERE p2.object_id = p.object_id
                    AND p2.station_id = p.station_id
                    AND p2.end_time < p.end_time
              )
        ) AS first_pass_productions
    """
    cursor.execute(sql, tuple(params))
    return cursor.fetchone()["cnt"] or 0

def count_unique_ng_objects(cursor, all_station_names, start, end):
    placeholders = ", ".join(["%s"] * len(all_station_names))
    params = all_station_names + [start, end]

    sql = f"""
        SELECT COUNT(DISTINCT p.object_id) AS cnt
        FROM productions p
        JOIN stations s ON p.station_id = s.id
        WHERE s.name IN ({placeholders})
        AND p.end_time BETWEEN %s AND %s
        AND p.esito = 6
        AND NOT EXISTS (
            SELECT 1
            FROM productions p2
            WHERE p2.object_id = p.object_id
            AND p2.station_id = p.station_id
            AND p2.end_time > p.end_time
        )
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


def refresh_fermi_data(zone: str, ts: datetime) -> None:
    """
    Refresh fermi_data for the zone (to be called after stop insert/update).
    Includes open stops (end_time IS NULL) so they show live in VisualPage.
    """
    if zone not in global_state.visual_data:
        logger.warning(f"Cannot refresh fermi_data for unknown zone: {zone}")
        return

    shift_start, shift_end = get_shift_window(ts)

    try:
        fermi_data = []
        available_time_29 = 0
        available_time_30 = 0

        with get_mysql_connection() as conn:
            conn.commit()  # Ensures no old snapshot
            with conn.cursor() as cursor:
                # Total stop time for station 29
                cursor.execute("""
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
                """, (shift_start, shift_end))
                row29 = cursor.fetchone() or {}
                total_stop_time_minutes_29 = (row29.get("total_time") or 0) / 60
                available_time_29 = max(0, round(100 - (total_stop_time_minutes_29 / 480 * 100)))

                # Total stop time for station 30
                cursor.execute("""
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
                """, (shift_start, shift_end))
                row30 = cursor.fetchone() or {}
                total_stop_time_minutes_30 = (row30.get("total_time") or 0) / 60
                available_time_30 = max(0, round(100 - (total_stop_time_minutes_30 / 480 * 100)))

                # Top 4 stop reasons
                cursor.execute("""
                    SELECT s.name AS station_name,
                           st.reason,
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
                """, (shift_start, shift_end))
                for row in cursor.fetchall():
                    total_minutes = round(row["total_time"] / 60)
                    fermi_data.append({
                        "causale": row["reason"],
                        "station": row["station_name"],
                        "count": row["n_occurrences"],
                        "time": total_minutes
                    })

        fermi_data.append({"Available_Time_1": f"{available_time_29}"})
        fermi_data.append({"Available_Time_2": f"{available_time_30}"})

        # ✅ Update shared memory under per-zone lock
        with global_state.zone_locks[zone]:
            global_state.visual_data[zone]["fermi_data"] = fermi_data
            payload = copy.deepcopy(global_state.visual_data[zone])

        # 🔄 Robust asyncio broadcast
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

        if loop.is_running():
            loop.call_soon_threadsafe(
                lambda: asyncio.create_task(
                    broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
                )
            )
        else:
            loop.run_until_complete(
                broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
            )
            loop.close()

    except Exception as e:
        logger.exception(f"Error refreshing fermi_data for zone={zone}: {e}")

def refresh_top_defects_qg2(zone: str, ts: datetime) -> None:
    """
    Refresh top_defects_qg2 for the zone (based on esito=6 in current shift).
    """
    if zone not in global_state.visual_data:
        logger.warning(f"Cannot refresh top_defects_qg2 for unknown zone: {zone}")
        return

    shift_start, shift_end = get_shift_window(ts)

    try:
        top_defects = []
        total_defects = 0

        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
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

                if all_production_ids:
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
                        sid = production_station_map.get(pid)
                        if sid:
                            defect_counter[cat][sid].add(pid)

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

                    total_defects = sum(r["total"] for r in full_results)
                    top5 = sorted(full_results, key=lambda r: r["total"], reverse=True)[:5]
                    top_defects = [{"label": r["label"], "ain1": r["ain1"], "ain2": r["ain2"]} for r in top5]

        # ✅ Lock only during shared memory update
        with global_state.zone_locks[zone]:
            data = global_state.visual_data[zone]
            data["top_defects_qg2"] = top_defects
            data["total_defects_qg2"] = total_defects
            payload = copy.deepcopy(data)

        # 🔄 Robust asyncio handling for WebSocket broadcast
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

        if loop.is_running():
            loop.call_soon_threadsafe(
                lambda: asyncio.create_task(
                    broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
                )
            )
        else:
            loop.run_until_complete(
                broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
            )
            loop.close()

    except Exception as e:
        logger.exception(f"Exception in refresh_top_defects_qg2: {e}")

def refresh_top_defects_vpf(zone: str, ts: datetime) -> None:
    """
    Refresh top_defects_vpf for the zone (based on esito=6 at station_id=56 in current shift,
    and only defects with defect_id in (12, 14, 15)), split by original station_id (29 or 30 → ain1/ain2).
    """
    if zone not in global_state.visual_data:
        logger.warning(f"Cannot refresh top_defects_vpf for unknown zone: {zone}")
        return

    shift_start, shift_end = get_shift_window(ts)
    top_defects = []

    try:
        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
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
                production_ids = [row["id"] for row in rows]
                production_station_map = {row["id"]: row["origin_station"] for row in rows}

                if production_ids:
                    placeholders = ",".join(["%s"] * len(production_ids))
                    sql_defects = f"""
                        SELECT od.production_id, d.category
                        FROM object_defects od
                        JOIN defects d ON od.defect_id = d.id
                        WHERE od.production_id IN ({placeholders})
                        AND od.defect_id IN (12, 14, 15)
                    """
                    cursor.execute(sql_defects, production_ids)
                    rows = cursor.fetchall()

                    defect_counter: DefaultDict[str, Dict[int, int]] = defaultdict(lambda: {29: 0, 30: 0})
                    for row in rows:
                        pid = row["production_id"]
                        cat = row["category"]
                        origin = production_station_map.get(pid)
                        if origin is not None and origin in (29, 30):
                            defect_counter[cat][origin] += 1

                    full_results = []
                    for cat, counts in defect_counter.items():
                        c29 = counts[29]
                        c30 = counts[30]
                        total = c29 + c30
                        full_results.append({
                            "label": cat,
                            "ain1": c29,
                            "ain2": c30,
                            "total": total
                        })

                    top5 = sorted(full_results, key=lambda r: r["total"], reverse=True)[:5]
                    top_defects = [{"label": r["label"], "ain1": r["ain1"], "ain2": r["ain2"]} for r in top5]

        # ✅ Per-zone lock only during shared memory update
        with global_state.zone_locks[zone]:
            data = global_state.visual_data[zone]
            data["top_defects_vpf"] = top_defects
            payload = copy.deepcopy(data)

        # 🔄 Safe asyncio broadcast
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

        if loop.is_running():
            loop.call_soon_threadsafe(
                lambda: asyncio.create_task(
                    broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
                )
            )
        else:
            loop.run_until_complete(
                broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
            )
            loop.close()

    except Exception as e:
        logger.exception(f"Exception in refresh_top_defects_vpf: {e}")

def refresh_top_defects_ell(zone: str, ts: datetime) -> None:
    """
    Refresh top_defects for the ELL zone, based on esito=6 at station_id in (1, 2, 9)
    and count per defect category, split into min1 (station 1), min2 (station 2), and ell (station 9).
    """
    if zone not in global_state.visual_data:
        logger.warning(f"Cannot refresh top_defects_ell for unknown zone: {zone}")
        return

    shift_start, shift_end = get_shift_window(ts)
    top_defects = []

    try:
        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                sql_productions = """
                    SELECT id, station_id
                    FROM productions
                    WHERE esito = 6
                    AND station_id IN (1, 2, 9)
                    AND start_time BETWEEN %s AND %s
                """
                cursor.execute(sql_productions, (shift_start, shift_end))
                rows = cursor.fetchall()

                production_ids_1 = [row['id'] for row in rows if row['station_id'] == 1]
                production_ids_2 = [row['id'] for row in rows if row['station_id'] == 2]
                production_ids_9 = [row['id'] for row in rows if row['station_id'] == 9]

                all_ids = tuple(production_ids_1 + production_ids_2 + production_ids_9)
                if not all_ids:
                    top_defects = []
                else:
                    sql_defects = """
                        SELECT od.production_id, d.category
                        FROM object_defects od
                        JOIN defects d ON od.defect_id = d.id
                        WHERE od.production_id IN %s
                    """
                    cursor.execute(sql_defects, (all_ids,))
                    rows = cursor.fetchall()

                    station_map = {pid: 1 for pid in production_ids_1}
                    station_map.update({pid: 2 for pid in production_ids_2})
                    station_map.update({pid: 9 for pid in production_ids_9})

                    defect_counter = defaultdict(lambda: {1: set(), 2: set(), 9: set()})
                    for row in rows:
                        pid = row['production_id']
                        category = row['category']
                        sid = station_map.get(pid)
                        if sid:
                            defect_counter[category][sid].add(pid)

                    full_results = []
                    for category, stations in defect_counter.items():
                        min1 = len(stations[1])
                        min2 = len(stations[2])
                        ell = len(stations[9])
                        total = min1 + min2 + ell
                        full_results.append({
                            "label": category,
                            "min1": min1,
                            "min2": min2,
                            "ell": ell,
                            "total": total
                        })

                    top5 = sorted(full_results, key=lambda r: r["total"], reverse=True)[:5]
                    top_defects = [
                        {"label": r["label"], "min1": r["min1"], "min2": r["min2"], "ell": r["ell"]}
                        for r in top5
                    ]

        # ✅ Only lock shared memory during write
        with global_state.zone_locks[zone]:
            data = global_state.visual_data[zone]
            data["top_defects"] = top_defects
            payload = copy.deepcopy(data)

        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

        if loop.is_running():
            loop.call_soon_threadsafe(
                lambda: asyncio.create_task(
                    broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
                )
            )
        else:
            loop.run_until_complete(
                broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
            )
            loop.close()

    except Exception as e:
        logger.exception(f"Exception in refresh_top_defects_ell: {e}")

def refresh_median_cycle_time_vpf(now: Optional[datetime] = None) -> float:
    if now is None:
        now = datetime.now()

    shift_start, shift_end = get_shift_window(now)

    try:
        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
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
                if not cycle_times:
                    logger.debug("No cycle times found for VPF, median remains unchanged.")
                    return 0.0

                new_median = median(cycle_times)

        # ✅ Update shared memory under VPF lock only
        with global_state.zone_locks["VPF"]:
            vpf_data = global_state.visual_data.get("VPF")
            if (
                vpf_data and
                isinstance(vpf_data.get("speed_ratio"), list) and
                vpf_data["speed_ratio"]
            ):
                vpf_data["speed_ratio"][0]["medianSec"] = new_median
                logger.info(f"Updated VPF medianSec to {new_median:.2f} sec")

        return new_median

    except Exception as e:
        logger.exception(f"Failed to refresh VPF median cycle time: {e}")
        return 0.0

def refresh_median_cycle_time_ELL(now: Optional[datetime] = None) -> float:
    if now is None:
        now = datetime.now()

    shift_start, shift_end = get_shift_window(now)

    try:
        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                sql_speed_data = """
                    SELECT p.cycle_time
                    FROM productions p
                    WHERE p.station_id = 3
                    AND p.cycle_time IS NOT NULL
                    AND p.start_time BETWEEN %s AND %s
                    ORDER BY p.start_time ASC
                """
                cursor.execute(sql_speed_data, (shift_start, shift_end))
                raw_rows = cursor.fetchall()

                cycle_times = [time_to_seconds(row["cycle_time"]) for row in raw_rows]
                if not cycle_times:
                    logger.debug("No cycle times found for ELL, median remains unchanged.")
                    return 0.0

                new_median = median(cycle_times)

        # ✅ Update shared memory under ELL lock only
        with global_state.zone_locks["ELL"]:
            ell_data = global_state.visual_data.get("ELL")
            if (
                ell_data and
                isinstance(ell_data.get("speed_ratio"), list) and
                ell_data["speed_ratio"]
            ):
                ell_data["speed_ratio"][0]["medianSec"] = new_median
                logger.info(f"Updated ELL medianSec to {new_median:.2f} sec")

        return new_median

    except Exception as e:
        logger.exception(f"Failed to refresh ELL median cycle time: {e}")
        return 0.0

def refresh_vpf_defects_data(now: datetime) -> None:
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

    if now is None:
        now = datetime.now()

    shift_start, shift_end = get_shift_window(now)
    defects_vpf = []
    eq_defects = {
        cat: {station_name: 0 for _, station_name in stations}
        for cat, stations in category_station_map.items()
    }

    try:
        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                # 1️⃣ NG production IDs at VPF (first pass only)
                cursor.execute("""
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
                """, (shift_start, shift_end))
                vpf_rows = cursor.fetchall()
                vpf_prod_ids = [row["id"] for row in vpf_rows]

                # 2️⃣ Defects summary
                if vpf_prod_ids:
                    placeholders = ','.join(['%s'] * len(vpf_prod_ids))
                    cursor.execute(f"""
                        SELECT d.category, COUNT(*) AS count
                        FROM object_defects od
                        JOIN defects d ON od.defect_id = d.id
                        WHERE od.production_id IN ({placeholders})
                        GROUP BY d.category
                    """, vpf_prod_ids)
                    defects_vpf = [
                        {"label": row["category"], "count": row["count"]}
                        for row in cursor.fetchall()
                    ]

                # 3️⃣ eq_defects per NG category and path
                if vpf_prod_ids:
                    placeholders = ','.join(['%s'] * len(vpf_prod_ids))
                    cursor.execute(f"""
                        SELECT d.category, p.object_id
                        FROM object_defects od
                        JOIN defects d ON d.id = od.defect_id
                        JOIN productions p ON p.id = od.production_id
                        WHERE od.production_id IN ({placeholders})
                    """, vpf_prod_ids)
                    defect_to_objects = defaultdict(set)
                    for row in cursor.fetchall():
                        defect_to_objects[row["category"]].add(row["object_id"])

                    for cat, stations in category_station_map.items():
                        station_ids = [sid for sid, _ in stations]
                        station_names = {sid: name for sid, name in stations}
                        object_ids = defect_to_objects.get(cat, set())
                        if not object_ids or not station_ids:
                            continue

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
                            sid = row["station_id"]
                            count = row["count"]
                            station_name = station_names.get(sid)
                            if station_name:
                                eq_defects[cat][station_name] = count

        # ✅ Update shared memory under VPF lock
        with global_state.zone_locks["VPF"]:
            data = global_state.visual_data.get("VPF")
            if not data:
                logger.warning("VPF zone data not found in global_state")
                return
            data["defects_vpf"] = defects_vpf
            data["eq_defects"] = eq_defects
            payload = copy.deepcopy(data)

        # 🔄 Safe asyncio broadcast
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

        if loop.is_running():
            loop.call_soon_threadsafe(
                lambda: asyncio.create_task(
                    broadcast_zone_update(line_name="Linea2", zone="VPF", payload=payload)
                )
            )
        else:
            loop.run_until_complete(
                broadcast_zone_update(line_name="Linea2", zone="VPF", payload=payload)
            )
            loop.close()

    except Exception as e:
        logger.exception(f"refresh_vpf_defects_data() FAILED: {e}")
