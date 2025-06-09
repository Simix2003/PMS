from datetime import datetime, timedelta
import os
import sys
import json

sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from service.connections.mysql import get_mysql_connection

ZONE_LOGIC = {
    "AIN": {
        "view_type": "2_station",
        "display_names": ("AIN 1", "AIN 2"),
        "data_sources": {
            "AIN 1": ["AIN01", "MIN01"],
            "AIN 2": ["AIN02", "MIN02"]
        }
    },
    # You can add more zones with similar structure
}

def get_current_shift(now: datetime):
    if now.hour < 14:
        return 1
    elif now.hour < 22:
        return 2
    return 3

async def compute_and_store_visual_summary():
    now = datetime.now()
    conn = get_mysql_connection()
    cursor = conn.cursor()

    for zone, config in ZONE_LOGIC.items():
        view_type = config["view_type"]
        station_1_label, station_2_label = config["display_names"]
        station_1_sources = config["data_sources"][station_1_label]
        station_2_sources = config["data_sources"][station_2_label]

        def fetch_counts(station_names, start_time=None, end_time=None):
            placeholders = ", ".join(["%s"] * len(station_names))
            filters = f"s.name IN ({placeholders})"
            params = station_names[:]

            if start_time and end_time:
                filters += " AND p.end_time BETWEEN %s AND %s"
                params.extend([start_time, end_time])

            cursor.execute(f"""
                SELECT
                    COUNT(*) AS total,
                    SUM(CASE WHEN p.esito = 6 THEN 1 ELSE 0 END) AS ng,
                    SUM(CASE WHEN p.esito IN (1, 5, 7) THEN 1 ELSE 0 END) AS good
                FROM productions p
                JOIN stations s ON p.station_id = s.id
                WHERE {filters}
            """, tuple(params))
            result = cursor.fetchone()
            assert result is not None
            return result["total"] or 0, result["ng"] or 0, result["good"] or 0

        def compute_yield(total, ng):
            total = float(total)
            ng = float(ng)
            if total == 0:
                return 100.0
            return round(100.0 * (total - ng) / total, 2)


        # Global counts
        s1_total, s1_ng, s1_g = fetch_counts(station_1_sources)
        s2_total, s2_ng, s2_g = fetch_counts(station_2_sources)

        # Shift yields
        shift_yields_s1 = []
        shift_yields_s2 = []
        shift_totals = []

        for shift in range(1, 4):
            start = now.replace(hour=6 + 8 * (shift - 1), minute=0, second=0, microsecond=0)
            end = start + timedelta(hours=8)
            s1_t, s1_n, _  = fetch_counts(station_1_sources, start, end)
            s2_t, s2_n, _ = fetch_counts(station_2_sources, start, end)
            shift_yields_s1.append(compute_yield(s1_t, s1_n))
            shift_yields_s2.append(compute_yield(s2_t, s2_n))
            shift_totals.append(s1_t + s2_t)

        # Last 8 hours - hourly split
        hourly_throughput = {}
        hourly_yield_s1 = {}
        hourly_yield_s2 = {}

        for i in range(8):
            hour = now - timedelta(hours=7 - i)
            h_start = hour.replace(minute=0, second=0, microsecond=0)
            h_end = h_start + timedelta(hours=1)
            label = h_start.strftime("%H:%M")

            s1_t, s1_n, _ = fetch_counts(station_1_sources, h_start, h_end)
            s2_t, s2_n, _ = fetch_counts(station_2_sources, h_start, h_end)

            hourly_throughput[label] = s1_t + s2_t
            hourly_yield_s1[label] = compute_yield(s1_t, s1_n)
            hourly_yield_s2[label] = compute_yield(s2_t, s2_n)

        cursor.execute("""
                REPLACE INTO visual_summary (
                zone, view_type, station_1_name, station_2_name, timestamp,
                station_1_in, station_1_out_ng, station_1_yield,
                station_1_yield_shift_1, station_1_yield_shift_2, station_1_yield_shift_3,
                station_1_yield_last_8_hour_json,
                station_2_in, station_2_out_ng, station_2_yield,
                station_2_yield_shift_1, station_2_yield_shift_2, station_2_yield_shift_3,
                station_2_yield_last_8_hour_json,
                stations_throughput_shift_1, stations_throughput_shift_2, stations_throughput_shift_3,
                stations_throughput_last_8_hour_json
            )
            VALUES (%s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s)
        """, (
            zone, view_type, station_1_label, station_2_label, now,
            s1_total, s1_ng, compute_yield(s1_total, s1_ng),
            *shift_yields_s1, json.dumps(hourly_yield_s1),
            s2_total, s2_ng, compute_yield(s2_total, s2_ng),
            *shift_yields_s2, json.dumps(hourly_yield_s2),
            *shift_totals, json.dumps(hourly_throughput)
        ))
        conn.commit()
        print(f"✅ Visual summary inserted for zone {zone}")