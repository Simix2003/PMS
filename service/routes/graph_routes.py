from fastapi import APIRouter, Request, Query
from fastapi.responses import JSONResponse
from datetime import datetime, timedelta
from typing import Any, Optional, Dict, List
from collections import defaultdict
import logging

import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.state import global_state
from service.helpers.helpers import generate_time_buckets
from service.config.config import CHANNELS
from service.connections.mysql import get_mysql_connection

router = APIRouter()

@router.post("/api/graph_data")
async def get_graph_data(request: Request):
    payload = await request.json()
    line = payload["line"]
    station = payload["station"]
    start = datetime.fromisoformat(payload["start"])
    end = datetime.fromisoformat(payload["end"])
    metrics = payload.get("metrics", [])
    group_by = payload.get("groupBy", "hourly")
    extra_filter = payload.get("extra_filter")

    print("\n--- API /graph_data called ---")

    date_format = {
        "daily": "%Y-%m-%d",
        "weekly": "%Y-%m-%d",
    }.get(group_by, "%Y-%m-%d %H:00:00")

    conn = get_mysql_connection()
    result: Dict[str, List[Dict[str, Any]]] = defaultdict(list)

    # ESITO / YIELD / CYCLE TIME
    if "Esito" in metrics or "Yield" in metrics or "CycleTime" in metrics:
        with conn.cursor() as cur:
            print("\nRunning ESITO / CYCLE query...")
            cur.execute("""
                SELECT
                DATE_FORMAT(p.end_time, %s) AS bucket,
                p.esito,
                COUNT(*) AS count,
                AVG(TIMESTAMPDIFF(SECOND, p.start_time, p.end_time)) AS avg_cycle_time
                FROM productions p
                JOIN stations s ON p.station_id = s.id
                JOIN production_lines pl ON s.line_id = pl.id
                WHERE pl.display_name = %s
                AND s.name = %s
                AND p.end_time BETWEEN %s AND %s
                GROUP BY bucket, p.esito
                ORDER BY bucket
            """, (date_format, line, station, start, end))

            rows = cur.fetchall()

        agg = defaultdict(lambda: {"G": 0, "NG": 0, "Escluso": 0, "In Produzione": 0, "G Operatore": 0, "total": 0, "avg_cycle_time": 0})
        for r in rows:
            b = r["bucket"]
            e = r["esito"]
            c = r["count"]
            avg_ct = r["avg_cycle_time"] or 0

            if e == 1:
                agg[b]["G"] += c
            elif e == 6:
                agg[b]["NG"] += c
            elif e == 0:
                agg[b]["Escluso"] += c
            elif e == 2:
                agg[b]["In Produzione"] += c
            elif e == 8:
                agg[b]["G Operatore"] += c
            agg[b]["total"] += c
            agg[b]["avg_cycle_time"] = avg_ct

        for b, v in agg.items():
            dt = datetime.strptime(b, date_format)
            ts = dt.isoformat()

            if "Esito" in metrics:
                if extra_filter:
                    value = v.get(extra_filter, 0)
                    result[extra_filter].append({"timestamp": ts, "value": value})
                else:
                    result["Esito"].append({"timestamp": ts, "value": v["total"]})

            if "Yield" in metrics:
                tot = v["G"] + v["NG"]
                pct = (v["G"] / tot) * 100 if tot > 0 else 0
                result["Yield"].append({"timestamp": ts, "value": pct})

            if "CycleTime" in metrics:
                result["CycleTime"].append({"timestamp": ts, "value": v["avg_cycle_time"]})

        expected_buckets = generate_time_buckets(start, end, group_by)
        keys_to_pad = []
        if "Esito" in metrics and extra_filter:
            keys_to_pad.append(extra_filter)
        if "Yield" in metrics:
            keys_to_pad.append("Yield")
        if "CycleTime" in metrics:
            keys_to_pad.append("CycleTime")

        for key in keys_to_pad:
            existing = {item["timestamp"] for item in result[key]}
            for bucket in expected_buckets:
                dt = datetime.strptime(bucket, date_format)
                ts = dt.isoformat()
                if ts not in existing:
                    result[key].append({"timestamp": ts, "value": 0})
            result[key].sort(key=lambda x: x["timestamp"])

    # DIFETTO
    if "Difetto" in metrics and extra_filter:
        category = extra_filter.strip()
        print(f"[🔍] Selected defect category: {category}")

        query = f"""
            SELECT
            DATE_FORMAT(p.end_time, %s) AS bucket,
            COUNT(*) AS count
            FROM productions p
            JOIN stations s ON p.station_id = s.id
            JOIN production_lines pl ON s.line_id = pl.id
            JOIN object_defects od ON p.id = od.production_id
            JOIN defects d ON od.defect_id = d.id
            WHERE
            pl.display_name = %s AND
            s.name = %s AND
            p.end_time BETWEEN %s AND %s AND
            d.category = %s
            GROUP BY bucket
            ORDER BY bucket
        """
        params = [date_format, line, station, start, end, category]

        with conn.cursor() as cur:
            cur.execute(query, tuple(params))
            defect_rows = cur.fetchall()

        for row in defect_rows:
            dt = datetime.strptime(row["bucket"], date_format)
            result[category].append({
                "timestamp": dt.isoformat(),
                "value": row["count"]
            })

        expected_buckets = generate_time_buckets(start, end, group_by)
        existing = {item["timestamp"] for item in result[category]}
        for bucket in expected_buckets:
            ts = datetime.strptime(bucket, date_format).isoformat()
            if ts not in existing:
                result[category].append({"timestamp": ts, "value": 0})
        result[category].sort(key=lambda x: x["timestamp"])

    return result

@router.get("/api/productions_summary")
async def productions_summary(
    date: Optional[str] = Query(default=None),
    from_date: Optional[str] = Query(default=None, alias="from"),
    to_date: Optional[str] = Query(default=None, alias="to"),
    line_name: Optional[str] = Query(default=None),
    turno: Optional[int] = Query(default=None),
    start_time: Optional[str] = Query(default=None),
    end_time: Optional[str] = Query(default=None),
):
    try:
        conn = get_mysql_connection()
        with conn.cursor() as cursor:
            params = []
            where_clause = "WHERE 1=1"

            if not turno and start_time and end_time:
                try:
                    _ = datetime.fromisoformat(start_time)
                    _ = datetime.fromisoformat(end_time)
                    where_clause += " AND p.end_time BETWEEN %s AND %s"
                    params.extend([start_time, end_time])
                except ValueError:
                    return JSONResponse(status_code=400, content={"error": "start_time and end_time must be ISO 8601 formatted strings"})

            if turno:
                turno_times = {
                    1: ("06:00:00", "13:59:59"),
                    2: ("14:00:00", "21:59:59"),
                    3: ("22:00:00", "05:59:59"),
                }
                if turno not in turno_times:
                    return JSONResponse(status_code=400, content={"error": "Invalid turno number (must be 1, 2, or 3)"})

                turno_start, turno_end = turno_times[turno]

                if turno == 3:
                    if date:
                        shift_day = datetime.strptime(date, "%Y-%m-%d")
                        next_day = shift_day + timedelta(days=1)
                        where_clause += """
                            AND (
                                (DATE(p.end_time) = %s AND TIME(p.end_time) >= '22:00:00')
                                OR
                                (DATE(p.end_time) = %s AND TIME(p.end_time) <= '05:59:59')
                            )
                        """
                        params.extend([shift_day.strftime("%Y-%m-%d"), next_day.strftime("%Y-%m-%d")])
                    elif from_date and to_date:
                        where_clause += """
                            AND (
                                TIME(p.end_time) >= '22:00:00'
                                OR TIME(p.end_time) <= '05:59:59'
                            )
                        """
                    else:
                        return JSONResponse(status_code=400, content={"error": "Missing 'date' or 'from' and 'to'"})
                else:
                    if date:
                        shift_day = datetime.strptime(date, "%Y-%m-%d").strftime("%Y-%m-%d")
                        where_clause += " AND DATE(p.end_time) = %s AND TIME(p.end_time) BETWEEN %s AND %s"
                        params.extend([shift_day, turno_start, turno_end])
                    elif from_date and to_date:
                        from_dt = datetime.strptime(from_date, "%Y-%m-%d")
                        to_dt = datetime.strptime(to_date, "%Y-%m-%d")
                        days = [(from_dt + timedelta(days=i)).strftime("%Y-%m-%d") for i in range((to_dt - from_dt).days + 1)]
                        placeholders = ", ".join(["%s"] * len(days))
                        where_clause += f" AND DATE(p.end_time) IN ({placeholders}) AND TIME(p.end_time) BETWEEN %s AND %s"
                        params.extend(days + [turno_start, turno_end])
                    else:
                        return JSONResponse(status_code=400, content={"error": "Missing 'date' for turno filtering"})

            if line_name:
                try:
                    where_clause += " AND pl.name = %s"
                    params.append(line_name)
                except ValueError:
                    return JSONResponse(status_code=400, content={"error": "Invalid line_name format"})

            query = f"""
                SELECT
                    s.name AS station_name,
                    s.display_name AS station_display,
                    SUM(CASE WHEN p.esito = 1 THEN 1 ELSE 0 END) AS good_count,
                    SUM(CASE WHEN p.esito = 2 THEN 1 ELSE 0 END) AS in_prod_count,
                    SUM(CASE WHEN p.esito = 4 THEN 1 ELSE 0 END) AS escluso_count,
                    SUM(CASE WHEN p.esito = 5 THEN 1 ELSE 0 END) AS ok_op_count,
                    SUM(CASE WHEN p.esito = 6 THEN 1 ELSE 0 END) AS bad_count,
                    SEC_TO_TIME(AVG(TIME_TO_SEC(p.cycle_time))) AS avg_cycle_time
                FROM productions p
                JOIN stations s ON p.station_id = s.id
                LEFT JOIN production_lines pl ON s.line_id = pl.id
                {where_clause}
                GROUP BY s.name, s.display_name
            """
            cursor.execute(query, tuple(params))
            stations = {}
            for row in cursor.fetchall():
                name = row['station_name']
                stations[name] = {
                    "display": row['station_display'],
                    "good_count": int(row['good_count']),
                    "bad_count": int(row['bad_count']),
                    "escluso_count": int(row['escluso_count']),
                    "in_prod_count": int(row['in_prod_count']),
                    "ok_op_count": int(row['ok_op_count']),
                    "avg_cycle_time": str(row['avg_cycle_time']),
                    "last_cycle_time": "00:00:00"
                }

            query_time_cycles = f"""
                SELECT s.name as station_code, TIME_TO_SEC(p.cycle_time) as cycle_seconds
                FROM productions p
                JOIN stations s ON p.station_id = s.id
                LEFT JOIN production_lines pl ON s.line_id = pl.id
                {where_clause} AND (
                    p.esito = 1 OR (s.name = 'M326' AND p.esito = 5)
                )
            """
            cursor.execute(query_time_cycles, tuple(params))
            for row in cursor.fetchall():
                station = row['station_code']
                cycle = row['cycle_seconds']
                if station in stations:
                    stations[station].setdefault("cycle_times", []).append(float(cycle))

            all_station_names = [station for line, stations_list in CHANNELS.items() if line == line_name or line_name is None for station in stations_list]
            for station in all_station_names:
                stations.setdefault(station, {
                    "display": station,
                    "good_count": 0,
                    "bad_count": 0,
                    "escluso_count": 0,
                    "in_prod_count": 0,
                    "ok_op_count": 0,
                    "avg_cycle_time": "00:00:00",
                    "last_cycle_time": "00:00:00",
                    "cycle_times": []
                })

            def fetch_defect_summary(category_label, label):
                q = f"""
                    SELECT 
                        s.name AS station_code, 
                        d.category,
                        COUNT(DISTINCT CONCAT(od.production_id, '-', d.category)) AS unique_defect_count
                    FROM object_defects od
                    JOIN defects d ON od.defect_id = d.id
                    JOIN productions p ON p.id = od.production_id
                    JOIN stations s ON p.station_id = s.id
                    LEFT JOIN production_lines pl ON s.line_id = pl.id
                    {where_clause} AND p.esito = 6
                    GROUP BY s.name, d.category
                """
                cursor.execute(q, tuple(params))
                for row in cursor.fetchall():
                    station_code = row['station_code']
                    category = row['category']
                    count = int(row['unique_defect_count'])
                    if station_code in stations:
                        stations[station_code].setdefault("defects", {})[category] = count

            for category in ["Mancanza Ribbon", "I_Ribbon Leadwire", "Saldatura", "Disallineamento", "Generali", "Macchie ECA", "Celle Rotte", "Lunghezza String Ribbon", "Graffio su Cella"]:
                fetch_defect_summary(category, category)

            for station, data in stations.items():
                bad_count_val = int(data["bad_count"])
                defects = data.get("defects", {})
                total_defects = sum(defects.values())
                generic = bad_count_val - total_defects
                if generic > 0:
                    stations[station].setdefault("defects", {})["Generico"] = generic

            query_last = f"""
                SELECT s.name as station, o.id_modulo, p.esito, p.cycle_time, p.start_time, p.end_time
                FROM productions p
                JOIN stations s ON p.station_id = s.id
                JOIN objects o ON p.object_id = o.id
                LEFT JOIN production_lines pl ON s.line_id = pl.id
                {where_clause}
                ORDER BY p.end_time DESC
            """
            cursor.execute(query_last, tuple(params))
            seen_stations = set()
            for row in cursor.fetchall():
                station = row['station']
                if station not in seen_stations and station in stations:
                    stations[station]["last_object"] = row["id_modulo"]
                    stations[station]["last_esito"] = row["esito"]
                    stations[station]["last_cycle_time"] = str(row["cycle_time"])
                    stations[station]["last_in_time"] = str(row["start_time"])
                    stations[station]["last_out_time"] = str(row["end_time"])
                    seen_stations.add(station)

            return {
                "good_count": sum(s["good_count"] for s in stations.values()),
                "bad_count": sum(s["bad_count"] for s in stations.values()),
                "escluso_count": sum(s["escluso_count"] for s in stations.values()),
                "in_prod_count": sum(s["in_prod_count"] for s in stations.values()),
                "ok_op_count": sum(s["ok_op_count"] for s in stations.values()),
                "stations": stations,
            }

    except Exception as e:
        logging.error(f"MySQL Error: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})