# service/helpers/visual_helpers.py
from datetime import datetime, timedelta
import asyncio
import logging
import os
import sys
import copy

from service.routes.broadcast import broadcast_zone_update
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection
from service.config.config import ZONE_SOURCES
from threading import Lock
from service.state import global_state

_update_lock = Lock()

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
    """
    Heavy calculation → called only at startup or if you need a full refresh.
    Returns the full metric dictionary for one zone.
    """
    if now is None:
        now = datetime.now()
        #fake_now = now - timedelta(days=6)
        #now = fake_now

    cfg = ZONE_SOURCES[zone]
    shift_start, shift_end = get_shift_window(now)
    conn = get_mysql_connection()
    cursor = conn.cursor()

    # -------- current shift totals / yield ----------
    s1_in  = count_unique_objects(cursor, cfg["station_1_in"],  shift_start, shift_end, "all")
    s2_in  = count_unique_objects(cursor, cfg["station_2_in"],  shift_start, shift_end, "all")
    s1_ng  = count_unique_objects(cursor, cfg["station_1_out_ng"], shift_start, shift_end, "ng")
    s2_ng  = count_unique_objects(cursor, cfg["station_2_out_ng"], shift_start, shift_end, "ng")
    s1_g   = count_unique_objects(cursor, cfg["station_1_out_ng"], shift_start, shift_end, "good")
    s2_g   = count_unique_objects(cursor, cfg["station_2_out_ng"], shift_start, shift_end, "good")
    s1_y   = compute_yield(s1_g, s1_ng)
    s2_y   = compute_yield(s2_g, s2_ng)

    # -------- last 3 shifts yield + throughput -------
    s1_yield_shifts, s2_yield_shifts, shift_throughput = [], [], []
    qc_stations = cfg["station_1_out_ng"] + cfg["station_2_out_ng"]
    for label, start, end in get_previous_shifts(now):
        # yields
        s1_g = count_unique_objects(cursor, cfg["station_1_out_ng"], start, end, "good")
        s1_n = count_unique_objects(cursor, cfg["station_1_out_ng"], start, end, "ng")
        s2_g = count_unique_objects(cursor, cfg["station_2_out_ng"], start, end, "good")
        s2_n = count_unique_objects(cursor, cfg["station_2_out_ng"], start, end, "ng")

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

        s1_g = count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, "good") or 0
        s1_n = count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, "ng") or 0
        s2_g = count_unique_objects(cursor, cfg["station_2_out_ng"], h_start, h_end, "good") or 0
        s2_n = count_unique_objects(cursor, cfg["station_2_out_ng"], h_start, h_end, "ng") or 0

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

    sql = """
        SELECT s.name AS station_name, st.reason, COUNT(*) AS n_occurrences, SUM(st.stop_time) AS total_time
        FROM stops st
        JOIN stations s ON st.station_id = s.id
        WHERE st.type = 'STOP'
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
        "fermi_data": fermi_data,
    }

# --------------------------------------------------------------------------- #
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
        cfg  = ZONE_SOURCES[zone]

        # 1. SHIFT rollover check
        current_shift_start, current_shift_end = get_shift_window(ts)
        cached_shift_start = data.get("__shift_start")

        if cached_shift_start != current_shift_start.isoformat():
            global_state.visual_data[zone] = compute_zone_snapshot(zone, now=ts)
            return
        
                # Update fermi_data after each new module
        try:
            conn = get_mysql_connection()
            cursor = conn.cursor()

            sql = """
                SELECT s.name AS station_name, st.reason, COUNT(*) AS n_occurrences, SUM(st.stop_time) AS total_time
                FROM stops st
                JOIN stations s ON st.station_id = s.id
                WHERE st.type = 'STOP'
                  AND st.start_time BETWEEN %s AND %s
                GROUP BY st.station_id, st.reason
                ORDER BY total_time DESC
                LIMIT 4
            """
            cursor.execute(sql, (current_shift_start, current_shift_end))
            fermi_data = []
            for row in cursor.fetchall():
                total_minutes = round(row["total_time"] / 60)
                fermi_data.append({
                    "causale": row["reason"],
                    "station": row["station_name"],
                    "count": row["n_occurrences"],
                    "time": total_minutes
                })
            data["fermi_data"] = fermi_data

        except Exception as e:
            logger.warning(f"⚠️ Error while refreshing fermi_data: {e}")

        # 2. Update station counters
        if station_name in cfg["station_1_in"]:
            data["station_1_in"] += 1
        elif station_name in cfg["station_2_in"]:
            data["station_2_in"] += 1

        if esito == 6:
            if station_name in cfg["station_1_out_ng"]:
                data["station_1_out_ng"] += 1
            elif station_name in cfg["station_2_out_ng"]:
                data["station_2_out_ng"] += 1

        # 3. Recompute shift yield
        s1_good = data["station_1_in"] - data["station_1_out_ng"]
        s2_good = data["station_2_in"] - data["station_2_out_ng"]
        data["station_1_yield"] = compute_yield(s1_good, data["station_1_out_ng"])
        data["station_2_yield"] = compute_yield(s2_good, data["station_2_out_ng"])

        # 3-bis. Incremental update for shifts
        current_shift_label = (
            "S1" if 6 <= current_shift_start.hour < 14 else
            "S2" if 14 <= current_shift_start.hour < 22 else
            "S3"
        )

        is_in_station = station_name in cfg["station_1_in"] or station_name in cfg["station_2_in"]
        is_qc_station = station_name in cfg["station_1_out_ng"] or station_name in cfg["station_2_out_ng"]

        # Update shift_throughput  ➜ count IN once, NG only when QC marks the part as NG
        for shift in data["shift_throughput"]:
            if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
                if is_in_station:
                    shift["total"] += 1         # real-throughput
                if esito == 6 and is_qc_station:
                    shift["ng"] += 1            # rejections
                break

        # Update station yield shifts
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

        # 4. Update hourly bins
        hour_start = ts.replace(minute=0, second=0, microsecond=0)
        hour_label = hour_start.strftime("%H:%M")

        def _touch_hourly(list_key, is_station1: bool):
            lst = data[list_key]
            if not lst or lst[-1]["hour"] != hour_label:
                lst[:] = lst[-7:]
                lst.append({"hour": hour_label, "start": ts.isoformat(),
                            "end": (ts + timedelta(hours=1)).isoformat(),
                            "total": 0, "ng": 0, "yield": 100})

            entry = lst[-1]
            if "total" in entry:                       # throughput list
                entry["total"] += 1
                if esito == 6:
                    entry["ng"] += 1
            else:                                      # yield list entry
                if esito == 6:
                    entry["ng"] = entry.get("ng", 0) + 1
                else:
                    entry["good"] = entry.get("good", 0) + 1
                good = entry.get("good", 0)
                ng   = entry.get("ng", 0)
                entry["yield"] = compute_yield(good, ng)

        # Throughput list
        if is_in_station or (esito == 6 and is_qc_station):
            _touch_hourly("last_8h_throughput", False)

        # Yield per station lists
        if station_name in cfg["station_1_out_ng"]:
            _touch_hourly("station_1_yield_last_8h", True)
        elif station_name in cfg["station_2_out_ng"]:
            _touch_hourly("station_2_yield_last_8h", True)

        # 5.  Optionally push over WebSocket
       
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
