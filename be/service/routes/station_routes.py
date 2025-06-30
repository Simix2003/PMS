from fastapi import APIRouter, Request, HTTPException
from fastapi.responses import JSONResponse
import asyncio
import logging

import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.helpers.helpers import get_channel_config
from service.state.global_state import plc_connections
from service.routes.broadcast import broadcast
from service.config.config import debug
from service.connections.mysql import get_mysql_connection

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/api/station_for_object")
async def get_station_for_object(id_modulo: str):
    try:
        conn = get_mysql_connection()
        with conn.cursor() as cursor:
            cursor.execute("SELECT id FROM objects WHERE id_modulo = %s", (id_modulo,))
            obj = cursor.fetchone()
            if not obj:
                raise HTTPException(status_code=404, detail="Object not found.")

            obj_id = obj["id"]

            cursor.execute("""
                SELECT s.name AS station_name
                FROM productions p
                JOIN stations s ON p.station_id = s.id
                WHERE p.object_id = %s AND s.type = 'qc'
                ORDER BY p.end_time DESC
                LIMIT 1
            """, (obj_id,))
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="QC station not found for this object.")

            return {"station": row["station_name"]}

    except Exception as e:
        logger.error(f"Error in get_station_for_object({id_modulo}): {e}")
        raise HTTPException(status_code=500, detail="Server error.")

@router.post("/api/set_outcome")
async def set_outcome(request: Request):
    data = await request.json()
    line_name = data.get("line_name")
    channel_id = data.get("channel_id")
    object_id = data.get("object_id")
    outcome = data.get("outcome")  # "buona" or "scarto"
    rework = data.get("rework")

    if not line_name or not channel_id or outcome not in ["buona", "scarto"]:
        return JSONResponse(status_code=400, content={"error": "Invalid data"})

    config = get_channel_config(line_name, channel_id)
    if not config:
        return JSONResponse(status_code=404, content={"error": "Channel not found"})

    plc_connection = plc_connections.get(f"{line_name}.{channel_id}")
    if not plc_connection:
        return JSONResponse(status_code=404, content={"error": "PLC connection not found"})

    read_conf = config["id_modulo"]
    try:
        current_object_id = await asyncio.to_thread(
            plc_connection.read_string,
            read_conf["db"], read_conf["byte"], read_conf["length"]
        )
    except Exception as e:
        logger.error(f"Error reading PLC data: {e}")

    if not debug:
        if not rework:
            if str(current_object_id) != str(object_id):
                return JSONResponse(status_code=409, content={"error": "Stale object, already processed or expired."})

    logger.debug(f"Outcome '{outcome.upper()}' written for object {object_id} on {line_name}.{channel_id}")
    await broadcast(line_name, channel_id, {
        "trigger": None,
        "objectId": object_id,
        "outcome": outcome
    })

    return {"status": "ok"}

@router.get("/api/tablet_stations")
async def get_qg_stations():
    try:
        conn = get_mysql_connection()
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT name, display_name 
                FROM stations 
                WHERE type IN ('qc', 'rework')
                  AND config IS NOT NULL 
                  AND config != ''
                  AND plc IS NOT NULL 
                  AND plc != ''
            """)
            stations = cursor.fetchall()
        return {"stations": stations}
    except Exception as e:
        return {"error": str(e)}
