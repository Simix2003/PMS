# service/helpers/visual_helpers.py
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

from service.connections.mysql import get_mysql_connection, get_mysql_read_connection
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

def count_unique_objects(cursor, station_groups, start, end, esito_filter):
    """Count unique objects for multiple station groups in a single query.

    ``station_groups`` can be either a list of station names (preserving the
    previous behaviour and returning a single integer) or a list of
    ``(station_names, alias)`` tuples.  In the latter case the function returns
    a dictionary mapping each alias to its count.
    """

    # Backwards compatibility: allow a single list of station names
    single_group = False
    if station_groups and isinstance(station_groups[0], str):
        station_groups = [(station_groups, "__cnt")]
        single_group = True

    if esito_filter == "good":
        esito_condition = "AND p.esito IN (1, 5, 7)"
    elif esito_filter == "ng":
        esito_condition = "AND p.esito = 6"
    else:
        esito_condition = ""

    subqueries = []
    params = []
    for names, alias in station_groups:
        placeholders = ", ".join(["%s"] * len(names))
        params.extend(names + [start, end])
        subqueries.append(
            f"""
            SELECT '{alias}' AS grp, p.object_id
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
            """
        )

    sql = f"""
        SELECT grp, COUNT(*) AS cnt
        FROM (
            {' UNION ALL '.join(subqueries)}
        ) AS latest_productions
        GROUP BY grp
    """

    cursor.execute(sql, tuple(params))
    rows = cursor.fetchall()
    result = {alias: 0 for _, alias in station_groups}
    for row in rows:
        result[row["grp"]] = row["cnt"] or 0

    if single_group:
        return result["__cnt"]
    return result

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

def _dispatch_snapshot(zone: str, now: datetime) -> dict:
    """Select the proper snapshot computation for the given zone."""
    if zone == "VPF":
        return _compute_snapshot_vpf(now)
    if zone == "AIN":
        return _compute_snapshot_ain(now)
    if zone == "ELL":
        return _compute_snapshot_ell(now)
    if zone == "STR":
        return _compute_snapshot_str(now)
    raise ValueError(f"Unknown zone: {zone}")


def _schedule_snapshot(zone: str, now: datetime, shift: str, missing: bool):
    """Submit snapshot computation to the background executor.

    If ``missing`` is True the call will wait for completion and return the
    resulting snapshot; otherwise it returns immediately after scheduling.
    """

    def _update_cache(fut):
        try:
            data = fut.result()
            data["__timestamp"] = datetime.now().isoformat()
            data["__shift"] = shift
            with global_state.visual_data_lock:
                global_state.visual_data[zone] = data
                global_state.visual_futures.pop(zone, None)
        except Exception as exc:  # pragma: no cover - logging path
            logger.exception(
                f"compute_zone_snapshot() FAILED for zone={zone}: {exc}"
            )
            with global_state.visual_data_lock:
                global_state.visual_futures.pop(zone, None)

    with global_state.visual_data_lock:
        future = global_state.visual_futures.get(zone)
        if future is None or future.done():
            future = global_state.executor.submit(_dispatch_snapshot, zone, now)
            global_state.visual_futures[zone] = future
            future.add_done_callback(_update_cache)

    if missing:
        result = future.result()
        result["__timestamp"] = datetime.now().isoformat()
        result["__shift"] = shift
        with global_state.visual_data_lock:
            global_state.visual_data[zone] = result
            global_state.visual_futures.pop(zone, None)
        return result
    return None


def compute_zone_snapshot(zone: str, now: datetime | None = None, *, force_refresh: bool = False) -> dict:
    """Return the cached snapshot for ``zone``.

    Snapshot computation is off‑loaded to a background thread. The cached value
    is returned immediately while the refresh happens asynchronously. Only when
    no cache is available do we wait for the computation to finish.
    """

    if now is None:
        now = datetime.now()

    shift = get_shift_label(now)

    with global_state.visual_data_lock:
        cached = copy.deepcopy(global_state.visual_data.get(zone))

    cache_missing = cached is None
    stale = False
    if cached:
        ts_str = cached.get("__timestamp")
        cached_shift = cached.get("__shift")
        try:
            ts = datetime.fromisoformat(ts_str) if ts_str else now
        except ValueError:
            ts = now
        stale = (now - ts >= timedelta(hours=1)) or (cached_shift != shift)

    if force_refresh:
        stale = True

    if cache_missing or stale:
        result = _schedule_snapshot(zone, now, shift, cache_missing)
        if result is not None:
            return copy.deepcopy(result)

    return cached if cached is not None else {}

# ─────────────────────────────────────────────────────────────────────────────
def _compute_snapshot_ain(now: datetime) -> dict:
    try:
        if now is None:
            now = datetime.now()

        hour_start = now.replace(minute=0, second=0, microsecond=0)
        cfg = ZONE_SOURCES["AIN"]

        shift_start, shift_end = get_shift_window(now)

        with get_mysql_read_connection() as conn:
            with conn.cursor() as cursor:
                # -------- current shift totals / yield ----------
                counts_in = count_unique_objects(
                    cursor,
                    [
                        (cfg["station_1_in"], "s1_in"),
                        (cfg["station_2_in"], "s2_in"),
                    ],
                    shift_start,
                    shift_end,
                    "all",
                )
                counts_ng = count_unique_objects(
                    cursor,
                    [
                        (cfg["station_1_out_ng"], "s1_ng"),
                        (cfg["station_2_out_ng"], "s2_ng"),
                    ],
                    shift_start,
                    shift_end,
                    "ng",
                )

                s1_in = counts_in["s1_in"]
                s2_in = counts_in["s2_in"]
                s1_ng = counts_ng["s1_ng"]
                s2_ng = counts_ng["s2_ng"]
                s1_g   = s1_in - s1_ng
                s2_g   = s2_in - s2_ng
                s1_y   = compute_yield(s1_g, s1_ng)
                s2_y   = compute_yield(s2_g, s2_ng)

                # -------- last 3 shifts yield + throughput -------
                s1_yield_shifts, s2_yield_shifts, shift_throughput = [], [], []
                qc_stations = cfg["station_1_out_ng"] + cfg["station_2_out_ng"]
                for label, start, end in get_previous_shifts(now):
                    # yields
                    counts_in = count_unique_objects(
                        cursor,
                        [
                            (cfg["station_1_in"], "s1_in"),
                            (cfg["station_2_in"], "s2_in"),
                        ],
                        start,
                        end,
                        "all",
                    )
                    counts_ng = count_unique_objects(
                        cursor,
                        [
                            (cfg["station_1_out_ng"], "s1_ng"),
                            (cfg["station_2_out_ng"], "s2_ng"),
                        ],
                        start,
                        end,
                        "ng",
                    )
                    s1_in_ = counts_in["s1_in"]
                    s2_in_ = counts_in["s2_in"]
                    s1_n = counts_ng["s1_ng"]
                    s2_n = counts_ng["s2_ng"]
                    s1_g = s1_in_ - s1_n
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
                    tot = s1_in_ + s2_in_
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
                    counts_in = count_unique_objects(
                        cursor,
                        [
                            (cfg["station_1_in"], "s1_in"),
                            (cfg["station_2_in"], "s2_in"),
                        ],
                        h_start,
                        h_end,
                        "all",
                    )
                    counts_ng = count_unique_objects(
                        cursor,
                        [
                            (cfg["station_1_out_ng"], "s1_ng"),
                            (cfg["station_2_out_ng"], "s2_ng"),
                        ],
                        h_start,
                        h_end,
                        "ng",
                    )

                    s1_in_ = counts_in["s1_in"]
                    s2_in_ = counts_in["s2_in"]
                    s1_n = counts_ng["s1_ng"]
                    s2_n = counts_ng["s2_ng"]
                    s1_g = s1_in_ - s1_n
                    s2_g = s2_in_ - s2_n

                    tot = s1_in_ + s2_in_
                    ng = s1_n + s2_n

                    last_8h_throughput.append({
                        "hour": label,
                        "start": h_start.isoformat(),
                        "end": h_end.isoformat(),
                        "total": tot,
                        "ng": ng
                    })

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

        with get_mysql_read_connection() as conn:
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
    try:
        if now is None:
            now = datetime.now()

        hour_start = now.replace(minute=0, second=0, microsecond=0)
        cfg = ZONE_SOURCES["ELL"]

        shift_start, shift_end = get_shift_window(now)

        with get_mysql_read_connection() as conn:
            with conn.cursor() as cursor:

                def count_objects_with_esito_ng(cursor, station_name, start, end):
                    sql = """
                        SELECT COUNT(DISTINCT p.object_id) AS cnt
                        FROM productions p
                        JOIN stations s ON p.station_id = s.id
                        WHERE s.name = %s
                        AND p.esito = 6
                        AND p.start_time BETWEEN %s AND %s
                    """
                    cursor.execute(sql, (station_name, start, end))
                    return cursor.fetchone()["cnt"] or 0
                
                # --- Wipe ELL buffer tables (SAFE if called hourly/shiftly) ---
                cursor.execute("DELETE FROM ell_productions_buffer")
                cursor.execute("DELETE FROM ell_defects_buffer")

                # --- Refill buffer tables from current shift's data ---
                # 1. Fill ell_productions_buffer
                cursor.execute("""
                    INSERT INTO ell_productions_buffer (id, object_id, station_id, start_time, end_time, esito)
                    SELECT id, object_id, station_id, start_time, end_time, esito
                    FROM productions
                    WHERE station_id IN (1, 2, 3, 9)
                    AND start_time BETWEEN %s AND %s
                    AND esito <> 2
                """, (shift_start, shift_end))

                # 2. Fill ell_defects_buffer
                cursor.execute("""
                    INSERT INTO ell_defects_buffer (
                        id, production_id, station_id, object_id, defect_id, defect_type,
                        i_ribbon, stringa, ribbon_lato, s_ribbon, extra_data, photo_id, category
                    )
                    SELECT
                        od.id, od.production_id, p.station_id, p.object_id, od.defect_id, od.defect_type,
                        od.i_ribbon, od.stringa, od.ribbon_lato, od.s_ribbon, od.extra_data, od.photo_id, d.category
                    FROM object_defects od
                    JOIN productions p ON od.production_id = p.id
                    JOIN defects d ON od.defect_id = d.id
                    WHERE p.station_id IN (1, 2, 3, 9)
                    AND p.start_time BETWEEN %s AND %s
                """, (shift_start, shift_end))
                conn.commit()

                # First pass stats
                counts_in = count_unique_objects(
                    cursor,
                    [
                        (cfg["station_1_in"], "s1_in"),
                        (cfg["station_2_in"], "s2_in"),
                    ],
                    shift_start,
                    shift_end,
                    "all",
                )
                counts_ng = count_unique_objects(
                    cursor,
                    [
                        (cfg["station_1_out_ng"], "s1_ng"),
                        (cfg["station_2_out_ng"], "s2_ng"),
                        (cfg["station_qg_1"], "qg2_ng_1"),
                        (cfg["station_qg_2"], "qg2_ng_2"),
                    ],
                    shift_start,
                    shift_end,
                    "ng",
                )

                s1_in = counts_in["s1_in"]
                s1_in_r0 = count_unique_objects_r0(cursor, cfg["station_1_in"], shift_start, shift_end, "all")
                s1_ng = counts_ng["s1_ng"]
                s1_ng_r0 = count_unique_objects_r0(cursor, cfg["station_1_out_ng"], shift_start, shift_end, "ng")
                s1_g = s1_in - s1_ng
                s1_g_r0 = s1_in_r0 - s1_ng_r0

                s2_in_r0  = count_unique_objects_r0(cursor, cfg["station_2_in"],  shift_start, shift_end, "all")
                s2_ng_r0 = count_unique_objects_r0(cursor, cfg["station_2_out_ng"], shift_start, shift_end, "ng")
                s2_g_r0 = s2_in_r0 - s2_ng_r0

                # Rework stats
                s2_in = counts_in["s2_in"]
                s2_ng = counts_ng["s2_ng"]
                s2_g = s2_in - s2_ng

                value_gauge_1 = round((s2_g_r0 / s2_in_r0) * 100, 2) if s2_in_r0 else 0.0

                # NEW: accurate numerator for value_gauge_2
                s1_esito_ng = count_objects_with_esito_ng(cursor, cfg["station_1_in"], shift_start, shift_end)

                # ---- Gauge 2 ---------------------------------------------------------------
                good_after_rework = count_good_after_rework(cursor, shift_start, shift_end)
                value_gauge_2 = round((good_after_rework / s2_g) * 100, 2) if s2_g else 0.0

                # --- NG Counters ---
                qg2_ng_1 = counts_ng["qg2_ng_1"]
                qg2_ng_2 = counts_ng["qg2_ng_2"]
                qg2_ng = qg2_ng_1 + qg2_ng_2

                # Combined NG across ELL (station_1) + QG2_1 + QG2_2 (deduplicated by object_id)
                stations_ng = cfg["station_1_out_ng"] + cfg["station_qg_1"] + cfg["station_qg_2"]
                ng_tot = count_unique_ng_objects(cursor, stations_ng, shift_start, shift_end)

                # Optional deeper inspection — show object IDs
                cursor.execute(f"""
                    SELECT DISTINCT p.object_id, s.name AS station, p.start_time
                    FROM productions p
                    JOIN stations s ON p.station_id = s.id
                    WHERE s.name IN ({','.join(['%s']*len(stations_ng))})
                    AND p.esito = 6
                    AND p.start_time BETWEEN %s AND %s
                """, (*stations_ng, shift_start, shift_end))
                rows = cursor.fetchall()

                # Yields
                # FPY = good on first pass / total first-pass
                fpy_y = compute_yield(s1_g_r0, s1_ng_r0)

                cursor.execute("""
                    SELECT COUNT(DISTINCT p.object_id) AS cnt
                    FROM productions p
                    JOIN stations s ON p.station_id = s.id
                    WHERE s.name = %s
                    AND p.start_time BETWEEN %s AND %s
                """, (cfg["station_1_in"], shift_start, shift_end))
                total_started = cursor.fetchone()["cnt"] or 0

                #–– Final‐good = each module’s last pass at station 1 was OK
                sql = """
                WITH last1 AS (
                SELECT p.object_id, p.esito,
                        ROW_NUMBER() OVER (PARTITION BY p.object_id
                                            ORDER BY p.start_time DESC) AS rn
                FROM productions p
                JOIN stations s ON p.station_id = s.id
                WHERE s.name = %s
                    AND p.start_time BETWEEN %s AND %s
                )
                SELECT COUNT(*) AS cnt
                FROM last1
                WHERE rn = 1
                AND esito <> 6
                """
                cursor.execute(sql, (cfg["station_1_in"], shift_start, shift_end))
                final_good = cursor.fetchone()["cnt"] or 0

                final_failed = total_started - final_good
                rwk_y = compute_yield(final_good, final_failed)

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

                    # FPY yield
                    FPY_yield_shifts.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "yield": compute_yield(s1_g_r0_, s1_ng_r0_),
                        "good": s1_g_r0_,
                        "ng":   s1_ng_r0_
                    })

                    # --- RWK yield: count distinct modules whose LAST pass @ station 1 is good ---
                    cursor.execute("""
                        SELECT COUNT(DISTINCT p.object_id) AS cnt
                        FROM productions p
                        JOIN stations s ON p.station_id = s.id
                        WHERE s.name = %s
                        AND p.start_time BETWEEN %s AND %s
                    """, (cfg["station_1_in"], start, end))
                    total_started = cursor.fetchone()["cnt"] or 0

                    sql_last_good = """
                    WITH last1 AS (
                        SELECT p.object_id,
                            p.esito,
                            ROW_NUMBER() OVER (
                                PARTITION BY p.object_id
                                ORDER BY p.start_time DESC
                            ) AS rn
                        FROM productions p
                        JOIN stations s ON p.station_id = s.id
                        WHERE s.name = %s
                        AND p.start_time BETWEEN %s AND %s
                    )
                    SELECT COUNT(*) AS cnt
                    FROM last1
                    WHERE rn = 1 AND esito <> 6
                    """
                    cursor.execute(sql_last_good, (cfg["station_1_in"], start, end))
                    final_good_shift = cursor.fetchone()["cnt"] or 0

                    rwk_failed = total_started - final_good_shift

                    RWK_yield_shifs.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "yield": compute_yield(final_good_shift, rwk_failed),
                        "good": final_good_shift,
                        "ng":   rwk_failed,
                        "station_1_in": s1_in_,
                        "station_1_out_ng": s1_n_,
                        "station_2_in": s2_in_
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

                    FPY_y8h.append({
                        "hour": label,
                        "good": s1_g_r0_,
                        "ng":   s1_ng_r0_,
                        "yield": compute_yield(s1_g_r0_, s1_ng_r0_),
                        "start": h_start.isoformat(),
                        "end":   h_end.isoformat(),
                    })

                    # RWK yield per 8h bin (based on each module’s final result at Station 1)
                    cursor.execute("""
                        SELECT COUNT(DISTINCT p.object_id) AS cnt
                        FROM productions p
                        JOIN stations s ON p.station_id = s.id
                        WHERE s.name = %s
                        AND p.start_time BETWEEN %s AND %s
                    """, (cfg["station_1_in"], h_start, h_end))
                    total_started_h = cursor.fetchone()["cnt"] or 0


                    sql_last_good_h = """
                    WITH last1 AS (
                        SELECT p.object_id,
                            p.esito,
                            ROW_NUMBER() OVER (
                                PARTITION BY p.object_id
                                ORDER BY p.start_time DESC
                            ) AS rn
                        FROM productions p
                        JOIN stations s ON p.station_id = s.id
                        WHERE s.name = %s
                        AND p.start_time BETWEEN %s AND %s
                    )
                    SELECT COUNT(*) AS cnt
                    FROM last1
                    WHERE rn = 1 AND esito <> 6
                    """
                    cursor.execute(sql_last_good_h, (cfg["station_1_in"], h_start, h_end))
                    final_good_h = cursor.fetchone()["cnt"] or 0

                    rwk_failed_h = total_started_h - final_good_h

                    RWK_y8h.append({
                        "hour": label,
                        "station_1_in": total_started_h,
                        "station_1_out_ng": s1_ng_r0_,  # NG from R0
                        "station_2_in": count_unique_objects(cursor, cfg["station_2_in"], h_start, h_end, "all") or 0,
                        "good": final_good_h,
                        "ng":   rwk_failed_h,
                        "yield": compute_yield(final_good_h, rwk_failed_h),
                        "start": h_start.isoformat(),
                        "end":   h_end.isoformat(),
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
                        SELECT object_id
                        FROM productions
                        WHERE station_id IN (9, 3)
                        AND start_time BETWEEN %s AND %s
                        GROUP BY object_id
                        HAVING COUNT(DISTINCT station_id) > 1
                    ) sub
                """
                cursor.execute(sql_reentered_ell, (shift_start, shift_end))
                result = cursor.fetchone()
                reentered_count = result["re_entered"] if result and "re_entered" in result else 0


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
            "value_gauge_2": value_gauge_2 #
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

    with get_mysql_read_connection() as conn, conn.cursor() as cur:
        station_in, station_ng, station_scrap, station_yield = {}, {}, {}, {}

        # 1. Current shift totals per station
        for idx, st_id in enumerate(STATION_IDS, start=1):
            g = _sum_for_window(cur, "string_G", st_id, shift_start, shift_end)
            n = _sum_for_window(cur, "string_NG", st_id, shift_start, shift_end)
            c = _sum_for_window(cur, "cell_NG", st_id, shift_start, shift_end)

            station_in[f"station_{idx}_in"] = g + n
            station_ng[f"station_{idx}_out_ng"] = n
            station_scrap[f"station_{idx}_scrap"] = c
            station_yield[f"station_{idx}_yield"] = compute_yield(g, n)

        # 2. Last 3 shifts (calculate STR yield and Overall yield identically for now)
        str_yield_shifts, overall_yield_shifts, shift_throughput = [], [], []
        for label, st, et in get_previous_shifts(now):
            good_shift = sum(_sum_for_window(cur, "string_G", sid, st, et) for sid in STATION_IDS)
            ng_shift = sum(_sum_for_window(cur, "string_NG", sid, st, et) for sid in STATION_IDS)
            scrap_shift = sum(_sum_for_window(cur, "cell_NG", sid, st, et) for sid in STATION_IDS)

            # STR Yield (zone view)
            str_yield_shifts.append({
                "label": label,
                "start": st.isoformat(),
                "end": et.isoformat(),
                "yield": compute_yield(good_shift, ng_shift),
                "good": good_shift,
                "ng": ng_shift,
                "scrap": scrap_shift
            })

            # Overall Yield (calculated same way for now)
            overall_yield_shifts.append({
                "label": label,
                "start": st.isoformat(),
                "end": et.isoformat(),
                "yield": compute_yield(good_shift, ng_shift),
                "good": good_shift,
                "ng": ng_shift
            })

            # Throughput (also for all stations combined)
            shift_throughput.append({
                "label": label,
                "start": st.isoformat(),
                "end": et.isoformat(),
                "total": good_shift + ng_shift,
                "ng": ng_shift,
                "scrap": scrap_shift
            })

        # 3. Last 8 hourly bins (calculate STR yield and Overall yield identically for now)
        str_y8h, overall_y8h = [], []
        for label, hs, he in get_last_8h_bins(now):
            good_bin = sum(_sum_for_window(cur, "string_G", sid, hs, he) for sid in STATION_IDS)
            ng_bin = sum(_sum_for_window(cur, "string_NG", sid, hs, he) for sid in STATION_IDS)

            # STR Yield (zone view)
            str_y8h.append({
                "hour": label,
                "start": hs.isoformat(),
                "end": he.isoformat(),
                "good": good_bin,
                "ng": ng_bin,
                "yield": compute_yield(good_bin, ng_bin),
            })

            # Overall Yield (same calculation for now)
            overall_y8h.append({
                "hour": label,
                "start": hs.isoformat(),
                "end": he.isoformat(),
                "good": good_bin,
                "ng": ng_bin,
                "yield": compute_yield(good_bin, ng_bin),
            })


        # 4. Station stops (availability) – mirror AIN fermi_data style
        fermi_data = []
        SHIFT_DURATION_MINUTES = 480
        station_labels = {4: "STR01", 5: "STR02", 6: "STR03", 7: "STR04", 8: "STR05"}

        for sid in STATION_IDS:
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
                "count": row["n_occurrences"],
                "time": total_minutes
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
                "count": 1,
                "time": elapsed_min
            }
            if not any(f.get("causale") == stop_entry["causale"] and f.get("station") == stop_entry["station"]
                       for f in fermi_data):
                fermi_data.insert(0, stop_entry)

        # 5. Top defects (QG2) — extract into helper if reused
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

            # Explicit typing to satisfy Pylance
            vpf_counter: Dict[str, Dict[int, int]] = defaultdict(lambda: {29: 0, 30: 0})
            for r in defect_rows:
                pid = r.get("production_id")
                cat = r.get("category")
                st = vpf_map.get(pid)

                if not isinstance(cat, str) or st not in (29, 30):
                    continue  # Skip invalid categories or stations

                vpf_counter[cat][st] += 1

            vpf_results = []
            for cat, stations in vpf_counter.items():
                c29, c30 = stations.get(29, 0), stations.get(30, 0)
                vpf_results.append({
                    "label": cat,
                    "ain1": c29,
                    "ain2": c30,
                    "total": c29 + c30
                })

            top_defects_vpf = sorted(vpf_results, key=lambda x: x["total"], reverse=True)[:5]

    return {
        **station_in,
        **station_ng,
        **station_scrap,
        **station_yield,
        "str_yield_shifts": str_yield_shifts,
        "overall_yield_shifts": overall_yield_shifts,
        "str_yield_last_8h": str_y8h,
        "overall_yield_last_8h": overall_y8h,
        "shift_throughput": shift_throughput,
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
    cycle_time: Optional[str] = None,
    reentered: bool = False,
    bufferIds: List[str] = [],
    object_id: Optional[str] = None
) -> None:
    if zone not in global_state.visual_data:
        global_state.visual_data[zone] = compute_zone_snapshot(zone, now=ts)
        return

    # ✅ Per-zone lock: does NOT block other zones or the line
    with global_state.zone_locks[zone]:
        current_shift_start, _ = get_shift_window(ts)
        data = global_state.visual_data[zone]
        cached_shift_start = data.get("__shift_start")

        if cached_shift_start != current_shift_start.isoformat():
            global_state.visual_data[zone] = compute_zone_snapshot(zone, now=ts)
            return

        if zone == "VPF":
            _update_snapshot_vpf(data, station_name, esito, ts, cycle_time, reentered)
        elif zone == "AIN":
            _update_snapshot_ain(data, station_name, esito, ts)
        elif zone == "ELL":
            data.setdefault("latest_esito", {})
            if not ELL_VISUAL:
                return
            print('Calling _update_snapshot_ell_new()')
            _update_snapshot_ell_new(data, station_name, esito, ts, cycle_time, bufferIds, object_id)
        elif zone == "STR":
            _update_snapshot_str(data, station_name, esito, ts)
        else:
            logger.info(f"Unknown zone: {zone}")
            return

        try:
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
            logger.warning(f"Could not schedule WebSocket update for {zone}: {e}")

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
    cycle_time: Optional[str],
    reentered: bool = False
) -> None:
    cfg = ZONE_SOURCES["VPF"]

    current_shift_start, _ = get_shift_window(ts)
    current_shift_label = (
        "S1" if 6 <= current_shift_start.hour < 14 else
        "S2" if 14 <= current_shift_start.hour < 22 else
        "S3"
    )

    is_in_station = station_name in cfg["station_1_in"]
    is_qc_station = station_name in cfg["station_1_out_ng"]

    if reentered:
        data["station_1_re_entered"] += 1
        return  # ✅ skip all stats

    # 1. Update counters
    if is_in_station:
        data["station_1_in"] += 1

    if esito == 6 and is_qc_station:
        data["station_1_out_ng"] += 1

    # 2. Recompute yield
    good = data["station_1_in"] - data["station_1_out_ng"]
    data["station_1_yield"] = compute_yield(good, data["station_1_out_ng"])

    # 3. Update shift yield
    for shift in data["station_1_shifts"]:
        if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
            if esito == 6:
                shift["ng"] += 1
            else:
                shift["good"] += 1
            shift["yield"] = compute_yield(shift["good"], shift["ng"])
            break

    # 4. Update hourly bins
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
        # Create new hour bin
        new_entry: dict = {
            "hour": hour_label,
            "start": hour_start.isoformat(),
            "end": (hour_start + timedelta(hours=1)).isoformat(),
            "good": 1 if esito != 6 else 0,
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
            h, m, s = cycle_time.split(":")
            current_sec = int(h) * 3600 + int(m) * 60 + float(s)

            median_sec = (
                data["speed_ratio"][0]["medianSec"]
                if "speed_ratio" in data and isinstance(data["speed_ratio"], list) and data["speed_ratio"]
                else current_sec
            )

            data["speed_ratio"] = [{
                "medianSec": median_sec,
                "currentSec": current_sec
            }]

        except Exception as e:
            logger.warning(f"Failed to parse cycle_time '{cycle_time}': {e}")

def _update_snapshot_ell_new(
    data: dict,
    station_name: str,
    esito: int,
    ts: datetime,
    cycle_time: Optional[str],
    bufferIds: List[str] = [],
    object_id: Optional[str] = None,
    reentered: bool = False
    ) -> None:

    try:
        cfg = ZONE_SOURCES["ELL"]
        current_shift_start, _ = get_shift_window(ts)
        current_shift_label = (
            "S1" if 6 <= current_shift_start.hour < 14 else
            "S2" if 14 <= current_shift_start.hour < 22 else
            "S3"
        )

        # ———————————————————————————————————————————————————————————————
        # 0. Ensure our helper sets exist on the `data` dict:
        data.setdefault("s1_ng_set", set())                # for gauge 2 denominator fix
        data.setdefault("reworked_set", set())             # modules good @RMI
        data.setdefault("good_after_rework_set", set())    # modules good @ELL after RMI
        # ———————————————————————————————————————————————————————————————

        # 1. Update Counters
        if not reentered:
            if station_name in cfg["station_1_in"]:
                data["station_1_in"] += 1
                data["station_1_r0_in"] += 1
            elif station_name in cfg["station_2_in"]:
                data["station_2_in"] += 1
                data["station_2_r0_in"] += 1
        
            if esito == 6:
                if station_name in cfg['station_qg_1']:
                    data["station_1_ng_qg2"] += 1
                    data["ng_tot"] += 1
                elif station_name in cfg['station_qg_2']:
                    data["station_1_ng_qg2"] += 1
                    data["ng_tot"] += 1
                elif station_name in cfg["station_1_out_ng"]:
                    data["station_1_r0_ng"] += 1
                    data["station_1_esito_ng"] += 1
                    data["station_1_out_ng"] += 1
                    data["ng_tot"] += 1
                elif station_name in cfg["station_2_out_ng"]:
                    data["station_2_r0_ng"] += 1
                    data["station_2_out_ng"] += 1
        
        if reentered:
            if esito == 1:
                if station_name in cfg["station_1_out_ng"]:
                    data["station_1_out_ng"] -= 1
                    data["ng_tot"] -= 1

        # 1a. Track “distinct modules that hit NG at station 1”:
        if station_name in cfg["station_1_in"] and esito == 6:
            data["s1_ng_set"].add(object_id)

        # 1b. Track “modules that passed rework”:
        if station_name in cfg["station_2_in"] and esito != 6:
            data["reworked_set"].add(object_id)

        # 1c. Track “of those, who then passed at ELL”:
        if station_name in cfg["station_1_in"] and esito != 6:
            # only count if they were reworked
            if object_id in data["reworked_set"]:
                data["good_after_rework_set"].add(object_id)

        # 2 Yield
        # FPY = good on first pass / total first-pass
        s1_good_r0 = data["station_1_r0_in"] - data["station_1_r0_ng"]
        data["FPY_yield"] = compute_yield(s1_good_r0, data["station_1_r0_ng"])

        #RWK = Good after being Reworked / total in

        # Always track latest esito for RWK calculation
        if station_name in cfg["station_1_in"] + cfg["station_1_out_ng"]:
            data["latest_esito"][object_id] = esito
        
        latest_esito = data["latest_esito"]

        total_started = data["station_1_r0_in"]  # First-pass only
        final_good = sum(1 for e in latest_esito.values() if e != 6)
        final_ng = total_started - final_good

        data["RWK_yield"] = compute_yield(final_good, final_ng)

        # ———————————————————————————————————————————————————————————————
        # 3. Gauge 1: s2_g_r0 / s2_in_r0  (first‐pass yield @ RMI)
        s2_in_r0 = data["station_2_r0_in"]
        s2_g_r0  = s2_in_r0 - data["station_2_r0_ng"]
        data["value_gauge_1"] = (
            round((s2_g_r0 / s2_in_r0) * 100, 2)
            if s2_in_r0 else
            0.0
        )

        # 4. Gauge 2: good_after_rework / good_through_rework
        #    ↳ SQL’s count_objects_with_esito_ng   ⇐ not needed any more
        #    ↳ SQL’s count_good_after_rework
        #       WITH reworked AS (… station_id=3 good …)
        #       … good @ station_id=9 …
        #
        # In‐RAM equivalent:
        total_reworked_good = len(data["reworked_set"])             # s2_g
        total_good_after  = len(data["good_after_rework_set"])     # good_after_rework
        data["value_gauge_2"] = (
            round((total_good_after / total_reworked_good) * 100, 2)
            if total_reworked_good else
            0.0
        )
        # ———————————————————————————————————————————————————————————————

        # 5 Update Throughput
        def update_shift_throughput(thr_data):
            is_in_station = station_name in cfg["station_1_in"] or station_name in cfg["station_2_in"]
            is_ell_station = station_name in cfg["station_1_out_ng"]
            is_scrap_station = station_name in cfg["station_2_out_ng"]

            for shift in thr_data:
                if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
                    if is_in_station:
                        shift["total"] += 1
                    if esito == 6 and is_ell_station:
                        shift["ng"] += 1
                    if esito == 6 and is_scrap_station:
                        shift["scrap"] += 1
                    break

        update_shift_throughput(data["shift_throughput"])

        # 6 Update shift yields
        def update_shift_yield_fpy(fpy_shift_data, is_r0_at_s1: bool):
            if not is_r0_at_s1:
                return
            for shift in fpy_shift_data:
                if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
                    if esito == 6:
                        shift["ng"] += 1
                    else:
                        shift["good"] += 1
                    shift["yield"] = compute_yield(shift["good"], shift["ng"])
                    break

        def update_shift_yield_rwk(rwk_shift_data, station_name: str, object_id: Optional[str], esito: int):
            if object_id is None:
                return
            # Track latest esito by object_id globally
            latest_esito = data["latest_esito"]
            latest_esito[object_id] = esito

            # Recompute good/ng per shift
            for shift in rwk_shift_data:
                start_ts = shift["start"]
                if shift["label"] == current_shift_label and start_ts == current_shift_start.isoformat():
                    total_started = data["station_1_r0_in"]
                    final_good = sum(1 for e in latest_esito.values() if e != 6)
                    final_ng = total_started - final_good
                    shift["good"] = final_good
                    shift["ng"] = final_ng
                    shift["yield"] = compute_yield(final_good, final_ng)
                    break

        # Update per-shift FPY
        update_shift_yield_fpy(
            data["FPY_yield_shifts"],
            not reentered and station_name in cfg["station_1_out_ng"]
        )

        # Update per-shift RWK
        update_shift_yield_rwk(
            data["RWK_yield_shifts"],
            station_name,
            object_id,
            esito
        )

        # 7 Update hourly bins
        hour_start = ts.replace(minute=0, second=0, microsecond=0)
        hour_label = hour_start.strftime("%H:%M")

        def _touch_hourly_fpy():
            if not reentered and station_name in cfg["station_1_out_ng"]:
                lst = data["FPY_yield_last_8h"]
                for entry in lst:
                    if entry["hour"] == hour_label:
                        if esito == 6:
                            entry["ng"] += 1
                        else:
                            entry["good"] += 1
                        entry["yield"] = compute_yield(entry["good"], entry["ng"])
                        break
                else:
                    data["FPY_yield_last_8h"].append({
                        "hour": hour_label,
                        "start": hour_start.isoformat(),
                        "end": (hour_start + timedelta(hours=1)).isoformat(),
                        "good": 0 if esito == 6 else 1,
                        "ng": 1 if esito == 6 else 0,
                        "yield": compute_yield(0 if esito == 6 else 1, 1 if esito == 6 else 0)
                    })
                    data["FPY_yield_last_8h"][:] = data["FPY_yield_last_8h"][-8:]

        def _touch_hourly_rwk():
            if object_id is None:
                return
            # always update RWK using latest_esito
            lst = data["RWK_yield_last_8h"]
            final_good = sum(1 for e in data["latest_esito"].values() if e != 6)
            total_started = data["station_1_r0_in"]
            final_ng = total_started - final_good
            yield_val = compute_yield(final_good, final_ng)

            for entry in lst:
                if entry["hour"] == hour_label:
                    entry["good"] = final_good
                    entry["ng"] = final_ng
                    entry["yield"] = yield_val
                    break
            else:
                data["RWK_yield_last_8h"].append({
                    "hour": hour_label,
                    "start": hour_start.isoformat(),
                    "end": (hour_start + timedelta(hours=1)).isoformat(),
                    "good": final_good,
                    "ng": final_ng,
                    "yield": yield_val
                })
                data["RWK_yield_last_8h"][:] = data["RWK_yield_last_8h"][-8:]

        def _touch_hourly_throughput():
            is_in_station = station_name in cfg["station_1_in"] or station_name in cfg["station_2_in"]
            is_ell_station = station_name in cfg["station_1_out_ng"]
            is_scrap_station = station_name in cfg["station_2_out_ng"]

            if not (is_in_station or (esito == 6 and (is_ell_station or is_scrap_station))):
                return

            lst = data["last_8h_throughput"]
            for entry in lst:
                if entry["hour"] == hour_label:
                    if is_in_station:
                        entry["total"] += 1
                    if esito == 6 and is_ell_station:
                        entry["ng"] += 1
                    if esito == 6 and is_scrap_station:
                        entry["scrap"] += 1
                    break
            else:
                lst.append({
                    "hour": hour_label,
                    "start": hour_start.isoformat(),
                    "end": (hour_start + timedelta(hours=1)).isoformat(),
                    "total": 1 if is_in_station else 0,
                    "ng": 1 if esito == 6 and is_ell_station else 0,
                    "scrap": 1 if esito == 6 and is_scrap_station else 0
                })
                lst[:] = lst[-8:]

        _touch_hourly_fpy()
        _touch_hourly_rwk()
        _touch_hourly_throughput()

        # ===================== 4. Buffer‑ID defect trace  =====================
        if bufferIds:
            with get_mysql_connection() as conn:
                with conn.cursor() as cursor:
                    bufferIds = [b.strip() for b in bufferIds if b and b.strip()]
                    if bufferIds:
                        placeholders = ",".join(["%s"] * len(bufferIds))
                        cursor.execute(
                            f"""
                            SELECT 
                            o.id_modulo,
                            COALESCE(p.id, 0) AS production_id,
                            SUM(p.station_id = 3) AS rwk_count,
                            COALESCE(
                                JSON_ARRAYAGG(
                                    JSON_OBJECT(
                                        'defect_id', od.defect_id,
                                        'defect_type',
                                            CASE 
                                                WHEN od.defect_id = 1 THEN od.defect_type
                                                ELSE COALESCE(d.category, 'Sconosciuto')
                                            END,
                                        'extra_data', IFNULL(od.extra_data,'')
                                    )
                                ),
                                JSON_ARRAY()
                            ) AS defects
                        FROM objects o
                        LEFT JOIN productions p
                            ON p.object_id = o.id
                        AND p.esito = 6
                        LEFT JOIN object_defects od 
                            ON od.production_id = p.id
                        LEFT JOIN defects d 
                            ON d.id = od.defect_id
                        WHERE o.id_modulo IN ({placeholders})
                        GROUP BY o.id_modulo, p.id;
                            """,
                            bufferIds,
                        )
                        data["bufferDefectSummary"] = [
                            {
                                "object_id": row["id_modulo"],
                                "production_id": row["production_id"],
                                "rework_count": int(row["rwk_count"] or 0),
                                "defects": json.loads(row["defects"]) if row["defects"] else [],
                            }
                            for row in cursor.fetchall()
                        ]
        else:
            data["bufferDefectSummary"] = []

        print('data: ', data)

    except Exception:
        logger.exception("Error in _update_snapshot_ell_new()")
        raise

def count_good_after_rework_buffer(cursor, start, end):
    """
    GOOD @S9 after GOOD @S3 (buffer version)
    """
    sql = """
        WITH reworked AS (
            SELECT DISTINCT object_id
            FROM ell_productions_buffer
            WHERE station_id = 3              -- Re-work station
              AND esito <> 6                  -- GOOD
              AND start_time BETWEEN %s AND %s
        )
        SELECT COUNT(DISTINCT p.object_id) AS cnt
        FROM ell_productions_buffer p
        JOIN reworked r USING (object_id)
        WHERE p.station_id = 9               -- ELL final test
          AND p.esito <> 6                   -- GOOD
          AND p.start_time BETWEEN %s AND %s
    """
    cursor.execute(sql, (start, end, start, end))
    return cursor.fetchone()["cnt"] or 0

def _update_snapshot_ell(bufferIds: List[str]) -> dict:
    try:
        now = datetime.now()

        hour_start = now.replace(minute=0, second=0, microsecond=0)
        cfg = ZONE_SOURCES["ELL"]

        shift_start, shift_end = get_shift_window(now)

        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:

                def count_objects_with_esito_ng(cursor, station_name, start, end):
                    sql = """
                        SELECT COUNT(DISTINCT p.object_id) AS cnt
                        FROM ell_productions_buffer p
                        JOIN stations s ON p.station_id = s.id
                        WHERE s.name = %s
                        AND p.esito = 6
                        AND p.start_time BETWEEN %s AND %s
                    """
                    cursor.execute(sql, (station_name, start, end))
                    return cursor.fetchone()["cnt"] or 0
                
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

                value_gauge_1 = round((s2_g_r0 / s2_in_r0) * 100, 2) if s2_in_r0 else 0.0

                # NEW: accurate numerator for value_gauge_2
                s1_esito_ng = count_objects_with_esito_ng(cursor, cfg["station_1_in"], shift_start, shift_end)

                qg2_ng_1 = count_unique_objects(cursor, cfg["station_qg_1"],  shift_start, shift_end, "ng")
                qg2_ng_2 = count_unique_objects(cursor, cfg["station_qg_2"],  shift_start, shift_end, "ng")

                qg2_ng = qg2_ng_1 + qg2_ng_2

                # Final NG total across station 1 and both QG2 stations (deduplicated)
                stations_ng = cfg["station_1_out_ng"] + cfg["station_qg_1"] + cfg["station_qg_2"]
                ng_tot = count_unique_ng_objects(cursor, stations_ng, shift_start, shift_end)

                # ---------- Gauge 2 (GOOD@S9 after GOOD@S3) ----------
                good_after_rework = count_good_after_rework_buffer(cursor, shift_start, shift_end)
                value_gauge_2     = round((good_after_rework / s2_g) * 100, 2) if s2_g else 0.0

                # ----- FPY -----
                fpy_y = compute_yield(s1_g_r0, s1_ng_r0)

                # ----- RWK (final-good / total-started) -----
                total_started = s1_in

                sql_final_good = """
                WITH last1 AS (
                    SELECT p.object_id,
                        p.esito,
                        ROW_NUMBER() OVER (PARTITION BY p.object_id
                                            ORDER BY p.start_time DESC) AS rn
                    FROM ell_productions_buffer p
                    JOIN stations s ON p.station_id = s.id
                    WHERE s.name = %s
                    AND p.start_time BETWEEN %s AND %s
                )
                SELECT COUNT(*) AS cnt
                FROM last1
                WHERE rn = 1 AND esito <> 6            -- good on last pass
                """
                cursor.execute(sql_final_good, (cfg["station_1_in"], shift_start, shift_end))
                final_good = cursor.fetchone()["cnt"] or 0

                rwk_y = compute_yield(final_good, total_started - final_good)


                # -------- last 3 shifts yield + throughput -------
                FPY_yield_shifts, RWK_yield_shifs, shift_throughput = [], [], []
                for label, start, end in get_previous_shifts(now):
                    # yield R0
                    s1_in_r0_  = count_unique_objects_r0(cursor, cfg["station_1_in"],  start, end, "all")
                    s1_ng_r0_ = count_unique_objects_r0(cursor, cfg["station_1_out_ng"], start, end, "ng")
                    s1_g_r0_ = s1_in_r0_ - s1_ng_r0_

                    s1_in_  = count_unique_objects(cursor, cfg["station_1_in"],  start, end, "all")
                    s1_n_ = count_unique_objects(cursor, cfg["station_1_out_ng"], start, end, "ng")
                    s1_g_ = s1_in_ - s1_n_

                    s2_in_  = count_unique_objects(cursor, cfg["station_2_in"],  start, end, "all")
                    s2_n_ = count_unique_objects(cursor, cfg["station_2_out_ng"], start, end, "ng")
                    s2_g_ = s2_in_ - s2_n_

                    FPY_yield_shifts.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "yield": compute_yield(s1_g_r0_, s1_ng_r0_),
                        "good": s1_g_r0_,
                        "ng": s1_ng_r0_
                    })

                    # --- RWK yield for that shift ---
                    cursor.execute("""
                        SELECT COUNT(DISTINCT p.object_id) AS cnt
                        FROM ell_productions_buffer p
                        JOIN stations s ON p.station_id = s.id
                        WHERE s.name = %s
                        AND p.start_time BETWEEN %s AND %s
                    """, (cfg["station_1_in"], start, end))
                    total_started = cursor.fetchone()["cnt"] or 0

                    sql_last_good_shift = """
                    WITH last1 AS (
                        SELECT p.object_id, p.esito,
                            ROW_NUMBER() OVER (PARTITION BY p.object_id
                                                ORDER BY p.start_time DESC) AS rn
                        FROM ell_productions_buffer p
                        JOIN stations s ON p.station_id = s.id
                        WHERE s.name = %s
                        AND p.start_time BETWEEN %s AND %s
                    )
                    SELECT COUNT(*) AS cnt
                    FROM last1
                    WHERE rn = 1 AND esito <> 6
                    """
                    cursor.execute(sql_last_good_shift, (cfg["station_1_in"], start, end))
                    final_good_shift = cursor.fetchone()["cnt"] or 0
                    rwk_failed = total_started - final_good_shift

                    RWK_yield_shifs.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end":   end.isoformat(),
                        "yield": compute_yield(final_good_shift, rwk_failed),
                        "good":  final_good_shift,        # modules whose last pass @ S1 is good
                        "ng":    rwk_failed,              # those still NG at end of shift
                        "station_1_in": s1_in_,
                        "station_1_out_ng": s1_n_,
                        "station_2_in": s2_in_
                    })

                    # throughput
                    tot = (count_unique_objects(cursor, cfg["station_1_in"], start, end, "all") +
                        count_unique_objects(cursor, cfg["station_2_in"], start, end, "all"))
                    ng = s1_n_
                    shift_throughput.append({
                        "label": label,
                        "start": start.isoformat(),
                        "end": end.isoformat(),
                        "total": tot,
                        "ng": ng,
                        "scrap" : s2_n_

                    })

                FPY_yield_shifts.insert(0, {
                    "label": label,
                    "start": shift_start.isoformat(),
                    "end": now.isoformat(),
                    "good": s1_in_r0 - s1_ng_r0,
                    "ng": s1_ng_r0,
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
                    # THROUGHPUT
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

                    # YIELDS PER STATION
                    s1_in_  = count_unique_objects(cursor, cfg["station_1_in"],  h_start, h_end, "all") or 0
                    s1_n_ = count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng") or 0
                    s1_g_ = s1_in_ - s1_n_

                    s1_in_r0_  = count_unique_objects_r0(cursor, cfg["station_1_in"],  h_start, h_end, "all") or 0
                    s1_ng_r0_ = count_unique_objects_r0(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng") or 0
                    s1_g_r0_ = s1_in_r0_ - s1_ng_r0_

                    s2_in_  = count_unique_objects(cursor, cfg["station_2_in"],  h_start, h_end, "all") or 0
                    s2_n_ = count_unique_objects(cursor, cfg["station_2_out_ng"], h_start, h_end, "ng") or 0
                    s2_g_ = s2_in_ - s2_n_

                    FPY_y8h.append({
                        "hour": label,
                        "good": s1_g_r0_,
                        "ng":   s1_ng_r0_,
                        "yield": compute_yield(s1_g_r0_, s1_ng_r0_),
                        "start": h_start.isoformat(),
                        "end":   h_end.isoformat(),
                    })

                    # --- RWK yield per 8 h ---
                    cursor.execute("""
                        SELECT COUNT(DISTINCT p.object_id) AS cnt
                        FROM ell_productions_buffer p
                        JOIN stations s ON p.station_id = s.id
                        WHERE s.name = %s
                        AND p.start_time BETWEEN %s AND %s
                    """, (cfg["station_1_in"], h_start, h_end))
                    total_started_h = cursor.fetchone()["cnt"] or 0

                    sql_last_good_h = """
                    WITH last1 AS (
                        SELECT p.object_id, p.esito,
                            ROW_NUMBER() OVER (PARTITION BY p.object_id
                                                ORDER BY p.start_time DESC) AS rn
                        FROM ell_productions_buffer p
                        JOIN stations s ON p.station_id = s.id
                        WHERE s.name = %s
                        AND p.start_time BETWEEN %s AND %s
                    )
                    SELECT COUNT(*) AS cnt
                    FROM last1
                    WHERE rn = 1 AND esito <> 6
                    """
                    cursor.execute(sql_last_good_h, (cfg["station_1_in"], h_start, h_end))
                    final_good_h = cursor.fetchone()["cnt"] or 0
                    rwk_failed_h = total_started_h - final_good_h

                    RWK_y8h.append({
                        "hour": label,
                        "station_1_in": total_started_h,
                        "station_1_out_ng": s1_ng_r0_,    # NG on first pass
                        "station_2_in": s2_in_,           # just for reference / UI
                        "good":  final_good_h,            # last-pass good
                        "ng":    rwk_failed_h,            # still NG
                        "yield": compute_yield(final_good_h, rwk_failed_h),
                        "start": h_start.isoformat(),
                        "end":   h_end.isoformat(),
                    })

                # -------- top_defects_qg2 calculation from ell_productions_buffer + object_defects --------
                # 1️⃣ Query ell_productions_buffer table for esito 6 on stations 1+2+9
                sql_productions = """
                    SELECT id, station_id
                    FROM ell_productions_buffer
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
                    FROM ell_defects_buffer od
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
                        SELECT object_id
                        FROM ell_productions_buffer
                        WHERE station_id IN (9, 3)
                        AND start_time BETWEEN %s AND %s
                        GROUP BY object_id
                        HAVING COUNT(DISTINCT station_id) > 1
                    ) sub
                """
                cursor.execute(sql_reentered_ell, (shift_start, shift_end))
                result = cursor.fetchone()
                reentered_count = result["re_entered"] if result and "re_entered" in result else 0

                # ===================== 4. Buffer‑ID defect trace  =====================
                buffer_defect_summary = []
                bufferIds = [b.strip() for b in bufferIds if b and b.strip()]
                if bufferIds:
                    placeholders = ",".join(["%s"] * len(bufferIds))
                    cursor.execute(
                        f"""
                        SELECT 
                        o.id_modulo,
                        COALESCE(p.id, 0) AS production_id,
                        SUM(p.station_id = 3) AS rwk_count,
                        COALESCE(
                            JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    'defect_id', od.defect_id,
                                    'defect_type',
                                        CASE 
                                            WHEN od.defect_id = 1 THEN od.defect_type
                                            ELSE COALESCE(d.category, 'Sconosciuto')
                                        END,
                                    'extra_data', IFNULL(od.extra_data,'')
                                )
                            ),
                            JSON_ARRAY()
                        ) AS defects
                    FROM objects o
                    LEFT JOIN productions p
                        ON p.object_id = o.id
                    AND p.esito = 6
                    LEFT JOIN object_defects od 
                        ON od.production_id = p.id
                    LEFT JOIN defects d 
                        ON d.id = od.defect_id
                    WHERE o.id_modulo IN ({placeholders})
                    GROUP BY o.id_modulo, p.id;
                        """,
                        bufferIds,
                    )
                    buffer_defect_summary = [
                        {
                            "object_id": row["id_modulo"],
                            "production_id": row["production_id"],
                            "rework_count": int(row["rwk_count"] or 0),
                            "defects": json.loads(row["defects"]) if row["defects"] else [],
                        }
                        for row in cursor.fetchall()
                    ]


                # -------- speed_ratio (median vs current cycle time at station 3 = ReWork1) ------
                sql_speed_data = """
                    SELECT p.cycle_time
                    FROM ell_productions_buffer p
                    WHERE p.station_id = 3
                    AND p.cycle_time IS NOT NULL
                    AND p.start_time BETWEEN %s AND %s
                    ORDER BY p.start_time ASC
                """
                cursor.execute(sql_speed_data, (shift_start, shift_end))
                raw_rows = cursor.fetchall()
                cycle_times_all = [time_to_seconds(row["cycle_time"]) for row in raw_rows]

                try:
                    if len(cycle_times_all) >= 10:
                        import numpy as np

                        # Compute dynamic filtering bounds using 10th–90th percentile
                        lower_bound = np.percentile(cycle_times_all, 10)
                        upper_bound = np.percentile(cycle_times_all, 90)

                        cycle_times = [t for t in cycle_times_all if lower_bound <= t <= upper_bound]
                        logger.debug(f"[ELL] Cycle time filtered range: {lower_bound:.1f}–{upper_bound:.1f} sec")
                    else:
                        # Not enough data — use all values
                        cycle_times = cycle_times_all
                        lower_bound = min(cycle_times_all) if cycle_times_all else 0
                        upper_bound = max(cycle_times_all) if cycle_times_all else 600
                        logger.debug(f"[ELL] Using all cycle times — count: {len(cycle_times)}")

                    if cycle_times:
                        median_sec = median(cycle_times)
                        current_sec = min(cycle_times[-1], float(upper_bound))
                        max_sec = upper_bound  # reflects top of valid/filtered range
                    else:
                        median_sec = 0
                        current_sec = 0
                        max_sec = 600
                        logger.debug(f"[ELL] No valid cycle times after filtering — setting all to 0/default")

                    speed_ratio = [{
                        "medianSec": median_sec,
                        "currentSec": current_sec,
                        "maxSec": max_sec
                    }]
                except Exception as e:
                    logger.exception(f"[ELL] Failed computing speed_ratio: {e}")
                    speed_ratio = [{
                        "medianSec": 0,
                        "currentSec": 0,
                        "maxSec": 600
                    }]

    except Exception as e:
        logger.exception(f"compute_zone_snapshot() FAILED for zone=ELL: {e}")
        raise

    return {
            "station_1_in": s1_in,
            "station_2_in": s2_in,
            "station_1_ng_qg2": qg2_ng,
            "station_1_out_ng": s1_ng,
            "station_2_out_ng": s2_ng,
            "ng_tot": ng_tot,
            "station_1_r0_in": s1_in_r0,
            "station_1_r0_ng": s1_ng_r0,
            "station_2_r0_in":  s2_in_r0,
            "station_2_r0_ng":  s2_ng_r0,
            "station_1_esito_ng": s1_esito_ng,
            "station_1_re_entered": reentered_count,
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
            "top_defects": top_defects,
            "value_gauge_1": value_gauge_1,
            "value_gauge_2": value_gauge_2,
            "speed_ratio": speed_ratio,
            "bufferDefectSummary": buffer_defect_summary,
}

def _update_snapshot_str(
    data: dict,
    station_name: str,
    esito: int,
    ts: datetime
) -> None:
    """
    Incrementally update the in-memory STR snapshot using per-module deltas
    from str_visual_snapshot. PLC resets counters after each module, so we
    sum the deltas manually instead of fixed +1 increments.
    Matches the full aggregation logic from _compute_snapshot_str().
    """
    cfg = ZONE_SOURCES["STR"]
    current_shift_start, _ = get_shift_window(ts)
    hour = ts.hour

    # Determine current shift label (S1/S2/S3)
    if 6 <= hour < 14:
        current_shift_label = "S1"
    elif 14 <= hour < 22:
        current_shift_label = "S2"
    else:
        current_shift_label = "S3"

    # Station name → station_id
    station_map = {"STR01": 4, "STR02": 5, "STR03": 6, "STR04": 7, "STR05": 8}
    st_id = station_map.get(station_name)
    if not st_id:
        return

    # Fetch latest module counts from DB
    cell_g = cell_ng = string_g = string_ng = 0
    try:
        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT cell_G, cell_NG, string_G, string_NG
                    FROM str_visual_snapshot
                    WHERE station_id=%s
                    ORDER BY timestamp DESC
                    LIMIT 1
                """, (st_id,))
                row = cursor.fetchone()
                if row:
                    cell_g = row.get("cell_G") or 0
                    cell_ng = row.get("cell_NG") or 0
                    string_g = row.get("string_G") or 0
                    string_ng = row.get("string_NG") or 0
    except Exception as e:
        logger.warning(f"STR snapshot DB read failed for {station_name}: {e}")

    total_processed = string_g + string_ng

    # Update per-station totals
    for i in range(1, 6):
        in_key = f"station_{i}_in"
        out_key = f"station_{i}_out_ng"
        if in_key not in data:
            data[in_key] = 0
        if out_key not in data:
            data[out_key] = 0
        if station_name in cfg[in_key]:
            data[in_key] += total_processed
        if esito == 6 and station_name in cfg[out_key]:
            data[out_key] += string_ng

    # Update yields per station
    for i in range(1, 6):
        good = data.get(f"station_{i}_in", 0) - data.get(f"station_{i}_out_ng", 0)
        data[f"station_{i}_yield"] = compute_yield(good, data.get(f"station_{i}_out_ng", 0))

    # Update shift throughput (total and NG counts for all STR stations)
    is_in = any(station_name in cfg[f"station_{i}_in"] for i in range(1, 6))
    is_ng = esito == 6 and any(station_name in cfg[f"station_{i}_out_ng"] for i in range(1, 6))
    for shift in data.get("shift_throughput", []):
        if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
            if is_in:
                shift["total"] += total_processed
            if is_ng:
                shift["ng"] += string_ng
            break

    # Update STR aggregate yield (all 5 stations)
    for shift in data.get("str_yield_shifts", []):
        if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
            shift["good"] += string_g
            shift["ng"] += string_ng
            shift["scrap"] = shift.get("scrap", 0) + cell_ng  # scrap totals
            shift["yield"] = compute_yield(shift["good"], shift["ng"])
            break

    # Update Overall yield (now also all 5 stations, same as STR for now)
    for shift in data.get("overall_yield_shifts", []):
        if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
            shift["good"] += string_g
            shift["ng"] += string_ng
            shift["yield"] = compute_yield(shift["good"], shift["ng"])
            break

    # Hourly bins (rolling last 8 hours) for both STR and Overall (identical)
    hour_start = ts.replace(minute=0, second=0, microsecond=0)
    hour_label = hour_start.strftime("%H:%M")

    def touch(list_key: str, add_good: int, add_ng: int):
        lst = data.get(list_key, [])
        for entry in lst:
            if entry["hour"] == hour_label:
                entry["good"] += add_good
                entry["ng"] += add_ng
                entry["yield"] = compute_yield(entry["good"], entry["ng"])
                break
        else:
            new_entry = {
                "hour": hour_label,
                "start": hour_start.isoformat(),
                "end": (hour_start + timedelta(hours=1)).isoformat(),
                "good": add_good,
                "ng": add_ng,
            }
            new_entry["yield"] = compute_yield(new_entry["good"], new_entry["ng"])
            lst.append(new_entry)
        data[list_key] = lst[-8:]  # keep last 8 bins

    if is_in or is_ng:
        touch("str_yield_last_8h", string_g, string_ng)
        touch("overall_yield_last_8h", string_g, string_ng)

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
