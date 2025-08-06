from fastapi import APIRouter, Depends, Query
import logging
import os
import sys
import json
import asyncio
from pydantic import BaseModel
from typing import Optional

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.state.global_state import plc_connections, plc_read_executor
import service.state.global_state as global_state
from service.helpers.buffer_plc_extract import extract_s7_string
from service.connections.mysql import get_mysql_connection

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/api/plc_status")
async def plc_status():
    statuses = {}

    for full_id, plc_conn in plc_connections.items():
        try:
            line_name, channel_id = full_id.split(".")
        except ValueError:
            continue

        if line_name not in statuses:
            statuses[line_name] = {}

        statuses[line_name][channel_id] = "CONNECTED" if plc_conn.connected else "DISCONNECTED"

    return statuses

class ReWorkBufferIds(BaseModel):
    db: int
    byte: int
    length: int
    string_length: Optional[int] = 20  # default


class DebugTriggerRequest(BaseModel):
    station: str         # e.g. "LineaB.M309"
    trigger: bool        # True or False
    id_modulo: str | None = None
    NG: bool
    G: bool
    reEntry_m326: bool

@router.post("/api/debug_trigger")
async def set_debug_trigger(payload: DebugTriggerRequest):
    station = payload.station

    global_state.debug_triggers[station] = payload.trigger
    global_state.debug_trigger_NG[station] = payload.NG
    global_state.debug_trigger_G[station] = payload.G
    global_state.reentryDebug[station] = payload.reEntry_m326

    if payload.id_modulo:
        global_state.debug_moduli[station] = payload.id_modulo

    return {
        "station": station,
        "trigger": global_state.debug_triggers[station],
        "id_modulo": global_state.debug_moduli.get(station),
        "NG": global_state.debug_trigger_NG.get(station),
        "G": global_state.debug_trigger_G.get(station),
        "reEntry_m326": global_state.reentryDebug.get(station)
    }

@router.get("/api/rwk_buffer_defects")
async def get_rwk_buffer_defects(
    plc_ip: str = Query(..., description="IP address of the PLC"),
    debug: bool = Query(False),
    rwk_conf: ReWorkBufferIds = Depends()
):
    data = {}

    # ✅ Find plc_connection by IP
    plc_connection = next(
        (conn for conn in plc_connections.values() if conn.ip_address == plc_ip),
        None
    )

    if not plc_connection and not debug:
        return {"error": f"No PLC connection found for IP {plc_ip}"}

    # ✅ Read from PLC or simulate
    rwk_vals: list[str] = []
    slen = (rwk_conf.string_length or 20) + 2

    if not debug and plc_connection:
        raw = await asyncio.get_event_loop().run_in_executor(
            plc_read_executor,
            plc_connection.db_read,
            rwk_conf.db,
            rwk_conf.byte,
            rwk_conf.length * slen,
        )
        rwk_vals = [extract_s7_string(raw, i * slen) for i in range(rwk_conf.length)]
    elif debug:
        rwk_vals = ["3SBHBGHC25620697", "3SBHBGHC25614686", "3SBHBGHC25620697"]

    data["BufferIds_Rework"] = rwk_vals

    # ✅ MySQL defect trace
    if rwk_vals:
        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                bufferIds = [b.strip() for b in rwk_vals if b and b.strip()]
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
                            ON p.object_id = o.id AND p.esito = 6
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

    return data