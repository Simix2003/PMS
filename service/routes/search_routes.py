# service/routes/search_routes.py
import logging
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from datetime import datetime, timedelta
from collections import defaultdict
import re

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.config import COLUMN_MAP
from service.connections.mysql import get_mysql_connection

router = APIRouter()

@router.post("/api/search")
async def search_results(request: Request):
    try:
        payload = await request.json()

        filters = payload.get("filters", [])
        order_by_input = payload.get("order_by", "Data")
        order_by = COLUMN_MAP.get(order_by_input, "p.end_time")
        order_direction = payload.get("order_direction", "DESC")
        limit = int(payload.get("limit", 1000))
        direction = "ASC" if order_direction.lower() == "crescente" else "DESC"

        join_clauses = []
        where_clauses = []
        params = []

        has_defect_filter = any(f.get("type") == "Difetto" for f in filters)

        # ✅ Always join defects for category info
        join_clauses.append("LEFT JOIN object_defects od ON p.id = od.production_id")
        join_clauses.append("LEFT JOIN defects d ON od.defect_id = d.id")

        grouped_filters = defaultdict(list)
        for f in filters:
            grouped_filters[f.get("type")].append(f)

        for filter_type, group in grouped_filters.items():
            if filter_type == "Difetto":
                defect_filter_or_clauses = []
                defect_filter_or_params = []

                for f in group:
                    value = f.get("value")
                    if not value:
                        continue

                    parts = value.split(" > ")
                    defect_category = parts[0]
                    clause_parts = ["d.category = %s"]
                    clause_params = [defect_category]

                    if defect_category == "Generali" and len(parts) > 1:
                        clause_parts.append("od.defect_type = %s")
                        clause_params.append(parts[1])
                    elif defect_category == "Saldatura":
                        if len(parts) > 1:
                            match = re.search(r'\[(\d+)\]', parts[1])
                            if match:
                                clause_parts.append("od.stringa = %s")
                                clause_params.append(int(match.group(1)))
                        if len(parts) > 2:
                            lato = parts[2].replace("Lato ", "").strip()
                            clause_parts.append("od.ribbon_lato = %s")
                            clause_params.append(lato)
                        if len(parts) > 3:
                            match = re.search(r'\[(\d+)\]', parts[3])
                            if match:
                                clause_parts.append("od.s_ribbon = %s")
                                clause_params.append(int(match.group(1)))
                    elif defect_category == "Disallineamento":
                        if len(parts) > 1 and parts[1] == "Stringa" and len(parts) > 2:
                            match = re.search(r'\[(\d+)\]', parts[2])
                            if match:
                                clause_parts.append("od.stringa = %s")
                                clause_params.append(int(match.group(1)))
                        elif len(parts) > 1 and parts[1] == "Ribbon":
                            if len(parts) > 2:
                                lato = parts[2].replace("Lato ", "").strip()
                                clause_parts.append("od.ribbon_lato = %s")
                                clause_params.append(lato)
                            if len(parts) > 3:
                                match = re.search(r'\[(\d+)\]', parts[3])
                                if match:
                                    clause_parts.append("od.i_ribbon = %s")
                                    clause_params.append(int(match.group(1)))
                    elif defect_category == "Mancanza Ribbon":
                        if len(parts) > 1:
                            lato = parts[1].replace("Lato ", "").strip()
                            clause_parts.append("od.ribbon_lato = %s")
                            clause_params.append(lato)
                        if len(parts) > 2:
                            match = re.search(r'\[(\d+)\]', parts[2])
                            if match:
                                clause_parts.append("od.i_ribbon = %s")
                                clause_params.append(int(match.group(1)))
                    elif defect_category == "I_Ribbon Leadwire":
                        if len(parts) > 1:
                            lato = parts[1].replace("Lato ", "").strip()
                            clause_parts.append("od.ribbon_lato = %s")
                            clause_params.append(lato)
                        if len(parts) > 2:
                            match = re.search(r'\[(\d+)\]', parts[2])
                            if match:
                                clause_parts.append("od.i_ribbon = %s")
                                clause_params.append(int(match.group(1)))
                    elif defect_category in ("Macchie ECA", "Celle Rotte", "Lunghezza String Ribbon", "Graffio su Cella", "Bad Soldering") and len(parts) > 1:
                        match = re.search(r'\[(\d+)\]', parts[1])
                        if match:
                            clause_parts.append("od.stringa = %s")
                            clause_params.append(int(match.group(1)))
                    elif defect_category == "Altro" and len(parts) > 1:
                        clause_parts.append("od.extra_data LIKE %s")
                        clause_params.append(f"%{parts[1]}%")

                    defect_filter_or_clauses.append("(" + " AND ".join(clause_parts) + ")")
                    defect_filter_or_params.extend(clause_params)

                if defect_filter_or_clauses:
                    where_clauses.append("(" + " OR ".join(defect_filter_or_clauses) + ")")
                    params.extend(defect_filter_or_params)

            else:
                group_clauses = []
                group_params = []

                for f in group:
                    value = f.get("value")
                    if filter_type == "ID Modulo":
                        group_clauses.append("o.id_modulo LIKE %s")
                        group_params.append(f"%{value}%")
                    elif filter_type == "Esito":
                        esito_map = {"G": 1, "In Produzione": 2, "Escluso": 4, "G Operatore": 5, "NG": 6}
                        if value in esito_map:
                            group_clauses.append("p.esito = %s")
                            group_params.append(esito_map[value])
                    elif filter_type == "Operatore":
                        group_clauses.append("p.operator_id LIKE %s")
                        group_params.append(f"%{value}%")
                    elif filter_type == "Linea":
                        group_clauses.append("pl.display_name = %s")
                        group_params.append(value)
                    elif filter_type == "Stazione":
                        group_clauses.append("s.name = %s")
                        group_params.append(value)
                    elif filter_type == "Stringatrice":
                        stringatrice_map = {"1": "Str1", "2": "Str2", "3": "Str3", "4": "Str4", "5": "Str5"}
                        if value in stringatrice_map:
                            join_clauses.append("LEFT JOIN stations ls ON p.last_station_id = ls.id")
                            group_clauses.append("ls.name = %s")
                            group_params.append(stringatrice_map[value])
                    elif filter_type == "Data":
                        from_iso = f.get("start")
                        to_iso = f.get("end")
                        if from_iso and to_iso:
                            from_dt = datetime.fromisoformat(from_iso)
                            to_dt = datetime.fromisoformat(to_iso)
                            group_clauses.append("p.end_time BETWEEN %s AND %s")
                            group_params.extend([from_dt, to_dt])
                    elif filter_type == "Tempo Ciclo":
                        condition = f.get("condition")
                        seconds = f.get("seconds")
                        if seconds:
                            try:
                                seconds_float = float(seconds)
                                if condition == "Minore Di":
                                    group_clauses.append("p.cycle_time < %s")
                                elif condition == "Maggiore Di":
                                    group_clauses.append("p.cycle_time > %s")
                                elif condition == "Uguale A":
                                    group_clauses.append("p.cycle_time = %s")
                                elif condition == "Minore o Uguale a":
                                    group_clauses.append("p.cycle_time <= %s")
                                elif condition == "Maggiore o Uguale a":
                                    group_clauses.append("p.cycle_time >= %s")
                                group_params.append(seconds_float)
                            except ValueError:
                                continue

                if group_clauses:
                    where_clauses.append("(" + " OR ".join(group_clauses) + ")")
                    params.extend(group_params)


        join_sql = " ".join(join_clauses)
        where_sql = "WHERE " + " AND ".join(where_clauses) if where_clauses else ""

        if order_by in {"p.esito", "p.cycle_time"}:
            order_clause = f"ORDER BY ISNULL({order_by}), {order_by} {direction}"
        else:
            order_clause = f"ORDER BY {order_by} {direction}"

        # ✅ Add defect_categories field always
        select_fields = """
            p.id AS production_id,
            o.id_modulo, 
            p.esito, 
            p.operator_id, 
            p.cycle_time, 
            p.start_time, 
            p.end_time,
            s.name AS station_name,
            pl.display_name AS line_display_name,
            GROUP_CONCAT(DISTINCT d.category) AS defect_categories
        """


        if has_defect_filter:
            select_fields += """,
                MIN(od.defect_type) AS defect_type,
                MIN(od.i_ribbon) AS i_ribbon,
                MIN(od.stringa) AS stringa,
                MIN(od.ribbon_lato) AS ribbon_lato,
                MIN(od.s_ribbon) AS s_ribbon,
                MIN(od.extra_data) AS extra_data
            """

        query = f"""
        SELECT {select_fields}
        FROM productions p
        JOIN objects o ON p.object_id = o.id
        JOIN stations s ON p.station_id = s.id
        {join_sql}
        LEFT JOIN production_lines pl ON s.line_id = pl.id
        {where_sql}
        GROUP BY p.id
        {order_clause}
        LIMIT %s
        """
        params.append(limit)

        conn = get_mysql_connection()
        with conn.cursor() as cursor:
            cursor.execute(query, tuple(params))
            rows = cursor.fetchall()

            # Group rows by id_modulo (i.e. unique object)
            grouped = defaultdict(list)
            for row in rows:
                grouped[row["id_modulo"]].append(row)

            # Sort each group by end_time, then build final response
            results = []
            # Sort each group by end_time, ignoring None values
            for object_id, events in grouped.items():
                # Remove entries with no end_time
                valid_events = [e for e in events if e["end_time"] is not None]

                if not valid_events:
                    continue  # Skip group if all events are invalid

                valid_events.sort(key=lambda x: x["end_time"], reverse=True)
                latest = valid_events[0]
                history = valid_events[1:]

                results.append({
                    "object_id": object_id,
                    "latest_event": latest,
                    "history": history,
                    "event_count": len(valid_events),
                })
        return {"results": results}


    except Exception as e:
        logging.error(f"Search API Error: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})