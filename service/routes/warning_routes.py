import base64
from datetime import datetime
from doctest import debug
import logging
from fastapi import APIRouter, Body, HTTPException
from pymysql.cursors import DictCursor

import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection, save_warning_on_mysql
from service.routes.broadcast import broadcast_stringatrice_warning
from service.helpers.helpers import compress_base64_to_jpeg_blob

router = APIRouter()

@router.get("/api/warnings/{line_name}")
def get_unacknowledged_warnings(line_name: str):
    conn = get_mysql_connection()

    with conn.cursor(DictCursor) as cursor:
        cursor.execute("""
            SELECT w.*, p.photo
            FROM stringatrice_warnings w
            LEFT JOIN photos p ON w.photo_id = p.id
            WHERE w.line_name = %s AND w.acknowledged = 0
            ORDER BY w.timestamp DESC
        """, (line_name,))
        rows = cursor.fetchall()

        for row in rows:
            row["suppress_on_source"] = bool(int(row.get("suppress_on_source", 0)))
            if row.get("photo") is not None:
                row["photo"] = base64.b64encode(row["photo"]).decode("utf-8")

        return rows

@router.post("/api/warnings/acknowledge/{warning_id}")
def acknowledge_warning(warning_id: int):
    conn = get_mysql_connection()

    with conn.cursor() as cursor:
        cursor.execute("""
            UPDATE stringatrice_warnings
            SET acknowledged = 1,
                suppress_on_source = TRUE
            WHERE id = %s
        """, (warning_id,))
        conn.commit()

    return {"message": "Warning acknowledged"}

@router.post("/api/suppress_warning")
async def suppress_warning(payload: dict):
    conn = get_mysql_connection()
    try:
        line = payload.get("line_name")
        timestamp_raw = payload.get("timestamp")

        if not line or not timestamp_raw:
            raise HTTPException(status_code=400, detail="Missing parameters")

        # ✅ Now safe to parse
        timestamp = datetime.fromisoformat(timestamp_raw).strftime('%Y-%m-%d %H:%M:%S')

        if not line or not timestamp:
            raise HTTPException(status_code=400, detail="Missing parameters")

        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE stringatrice_warnings
                SET suppress_on_source = TRUE
                WHERE line_name = %s AND timestamp = %s
            """, (line, timestamp))

            conn.commit()

        return {"status": "ok", "updated": True}
    except Exception as e:
        logging.error(f"❌ Failed to suppress warning: {e}")
        raise HTTPException(status_code=500, detail="Server error")


@router.post("/api/warnings/suppress_with_photo")
async def suppress_with_photo(data: dict = Body(...)):
    conn = get_mysql_connection()

    line_name = data["line_name"]
    timestamp_raw = data["timestamp"]
    timestamp = datetime.fromisoformat(timestamp_raw).strftime('%Y-%m-%d %H:%M:%S')

    image_base64 = data.get("photo")
    image_blob = compress_base64_to_jpeg_blob(image_base64, quality=70) if image_base64 else None

    try:
        with conn.cursor() as cursor:
            photo_id = None
            if image_blob:
                cursor.execute("INSERT INTO photos (photo) VALUES (%s)", (image_blob,))
                photo_id = cursor.lastrowid

            cursor.execute("""
                UPDATE stringatrice_warnings
                SET suppress_on_source = 1,
                    photo_id = %s
                WHERE line_name = %s AND timestamp = %s
            """, (photo_id, line_name, timestamp))
            conn.commit()
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Database error: {e}")

    return {"status": "ok"}

if debug:
    @router.post("/api/debug_warning")
    async def debug_warning(payload: dict):
        """
        Trigger a fake warning broadcast manually from Postman.
        Also stores it in MySQL with proper ID.
        """
        line = payload.get("line_name", "No Line")
        station_name = payload.get("station_name", "No Station")
        station_display = payload.get("station_display", "No Display")
        defect = payload.get("defect", "No Defect")
        wtype = payload.get("type", "No Type")
        value = payload.get("value", 0)
        limit = payload.get("limit", 0)
        source_station = payload.get("source_station", "No Source")

        warning_payload = {
            "timestamp": datetime.now().isoformat(),
            "station_name": station_name,
            "station_display": station_display,
            "line_name": line,
            "defect": defect,
            "type": wtype,
            "value": value,
            "limit": limit,
            "source_station": source_station,
        }

        station = {
            "line_name": line,
            "name": station_name,
            "display_name": station_display,
        }

        conn = get_mysql_connection()

        inserted_id = save_warning_on_mysql(
            warning_payload,
            conn,
            station,
            defect,
            {"display_name": source_station},
            suppress_on_source=False
        )

        if inserted_id:
            with conn.cursor(DictCursor) as cursor:
                cursor.execute("""
                    SELECT w.*, p.photo
                    FROM stringatrice_warnings w
                    LEFT JOIN photos p ON w.photo_id = p.id
                    WHERE w.id = %s
                """, (inserted_id,))
                row = cursor.fetchone()

                if row:
                    row["suppress_on_source"] = bool(int(row.get("suppress_on_source", 0)))
                    if row.get("photo"):
                        row["photo"] = base64.b64encode(row["photo"]).decode("utf-8")

                    if isinstance(row.get("timestamp"), datetime):
                        row["timestamp"] = row["timestamp"].isoformat()

                    await broadcast_stringatrice_warning(line, row)
                    return {"status": "sent", "payload": row}

        return {"status": "error", "reason": "Could not insert warning"}