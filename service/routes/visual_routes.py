from fastapi import APIRouter, Query, HTTPException
from datetime import datetime, timedelta
import logging, os, sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from service.connections.mysql import get_mysql_connection

router = APIRouter()

ZONE_SOURCES = {
    "AIN": {
        "station_1_in":      ["MIN01"],
        "station_2_in":      ["MIN02"],
        "station_1_out_ng":  ["MIN01"],
        "station_2_out_ng":  ["MIN02"]
    },
}

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
    for i in range(n):
        start, end = get_shift_window(ref)
        label = f"S{i+1}"
        shifts.insert(0, (label, start, end))
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
    return round((good / total) * 100) if total > 0 else 100

@router.get("/api/visual_data")
async def get_visual_data(zone: str = Query(...)):
    if zone not in ZONE_SOURCES:
        raise HTTPException(status_code=404, detail="Unknown zone")

    try:
        now = datetime.now()
        fake_now = now - timedelta(days=1)
        now = fake_now
        
        shift_start, shift_end = get_shift_window(now)
        cfg = ZONE_SOURCES[zone]

        conn = get_mysql_connection()
        cursor = conn.cursor()

        # Bussing IN
        s1_in = count_unique_objects(cursor, cfg["station_1_in"], shift_start, shift_end, esito_filter="all")
        s2_in = count_unique_objects(cursor, cfg["station_2_in"], shift_start, shift_end, esito_filter="all")

        # QC NG OUT
        s1_ng = count_unique_objects(cursor, cfg["station_1_out_ng"], shift_start, shift_end, esito_filter="ng")
        s2_ng = count_unique_objects(cursor, cfg["station_2_out_ng"], shift_start, shift_end, esito_filter="ng")

        # QC GOOD for yield
        s1_good = count_unique_objects(cursor, cfg["station_1_out_ng"], shift_start, shift_end, esito_filter="good")
        s2_good = count_unique_objects(cursor, cfg["station_2_out_ng"], shift_start, shift_end, esito_filter="good")

        s1_yield = compute_yield(s1_good, s1_ng)
        s2_yield = compute_yield(s2_good, s2_ng)

        # Yield history (3 shifts)
        s1_yield_shifts = []
        s2_yield_shifts = []
        for i, (label, start, end) in enumerate(get_previous_shifts(now)):
            s1_g = count_unique_objects(cursor, cfg["station_1_out_ng"], start, end, esito_filter="good")
            s1_n = count_unique_objects(cursor, cfg["station_1_out_ng"], start, end, esito_filter="ng")
            s2_g = count_unique_objects(cursor, cfg["station_2_out_ng"], start, end, esito_filter="good")
            s2_n = count_unique_objects(cursor, cfg["station_2_out_ng"], start, end, esito_filter="ng")

            s1_yield_shifts.append({
                "label": label,
                "start": start.isoformat(),
                "end": end.isoformat(),
                "yield": compute_yield(s1_g, s1_n)
            })
            s2_yield_shifts.append({
                "label": label,
                "start": start.isoformat(),
                "end": end.isoformat(),
                "yield": compute_yield(s2_g, s2_n)
            })

        shift_throughput = []
        for label, start, end in get_previous_shifts(now):
            total_1 = count_unique_objects(cursor, cfg["station_1_in"], start, end, esito_filter="all")
            total_2 = count_unique_objects(cursor, cfg["station_2_in"], start, end, esito_filter="all")
            ng_1    = count_unique_objects(cursor, cfg["station_1_out_ng"], start, end, esito_filter="ng")
            ng_2    = count_unique_objects(cursor, cfg["station_2_out_ng"], start, end, esito_filter="ng")
            shift_throughput.append({
                "label": label,
                "start": start.isoformat(),
                "end": end.isoformat(),
                "total": total_1 + total_2,
                "ng": ng_1 + ng_2
            })


        # Last 8h bins
        last_8h_throughput = []
        station_1_yield_last_8h = []
        station_2_yield_last_8h = []

        for label, h_start, h_end in get_last_8h_bins(now):
            total_1 = count_unique_objects(cursor, cfg["station_1_in"], h_start, h_end, esito_filter="all")
            total_2 = count_unique_objects(cursor, cfg["station_2_in"], h_start, h_end, esito_filter="all")
            ng_1    = count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, esito_filter="ng")
            ng_2    = count_unique_objects(cursor, cfg["station_2_out_ng"], h_start, h_end, esito_filter="ng")
            last_8h_throughput.append({
                "hour": label,
                "start": h_start.isoformat(),
                "end": h_end.isoformat(),
                "total": total_1 + total_2,
                "ng": ng_1 + ng_2
            })


            # Yield for station 1
            s1_g = count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, esito_filter="good")
            s1_n = count_unique_objects(cursor, cfg["station_1_out_ng"], h_start, h_end, esito_filter="ng")
            station_1_yield_last_8h.append({
                "hour": label,
                "start": h_start.isoformat(),
                "end": h_end.isoformat(),
                "yield": compute_yield(s1_g, s1_n)
            })

            # Yield for station 2
            s2_g = count_unique_objects(cursor, cfg["station_2_out_ng"], h_start, h_end, esito_filter="good")
            s2_n = count_unique_objects(cursor, cfg["station_2_out_ng"], h_start, h_end, esito_filter="ng")
            station_2_yield_last_8h.append({
                "hour": label,
                "start": h_start.isoformat(),
                "end": h_end.isoformat(),
                "yield": compute_yield(s2_g, s2_n)
            })

        return {
            "station_1_in": s1_in,
            "station_2_in": s2_in,
            "station_1_out_ng": s1_ng,
            "station_2_out_ng": s2_ng,
            "station_1_yield": s1_yield,
            "station_2_yield": s2_yield,
            "station_1_yield_shifts": s1_yield_shifts,
            "station_2_yield_shifts": s2_yield_shifts,
            "station_1_yield_last_8h": station_1_yield_last_8h,
            "station_2_yield_last_8h": station_2_yield_last_8h,
            "shift_throughput": shift_throughput,
            "last_8h_throughput": last_8h_throughput
        }

    except Exception as e:
        logging.error(f"❌ Error in /api/visual_data zone={zone}: {e}")
        raise HTTPException(status_code=500, detail="Server error")
