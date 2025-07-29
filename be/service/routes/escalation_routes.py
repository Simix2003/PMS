from fastapi import APIRouter, HTTPException
from typing import Dict, Any
from datetime import datetime
import os
import sys
import logging

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import (
    get_mysql_connection,
    create_stop,
    update_stop_status,
    get_stops_for_station,
    get_stop_with_levels,
    update_stop_reason,
)
from service.routes.broadcast import broadcast_escalation_update
from service.helpers.visual_helper import refresh_fermi_data, refresh_snapshot
from service.helpers.executor import run_in_thread

router = APIRouter()
logger = logging.getLogger(__name__)

STATION_NAME_TO_ID = {
    "AIN01": 29,
    "AIN02": 30,
    "STR01": 4,
    "STR02": 5,
    "STR03": 6,
    "STR04": 7,
    "STR05": 8,
}

# Mapping from station IDs to visual zones
STATION_ID_TO_ZONE = {
    29: "AIN",
    30: "AIN",
    3: "ELL",
    9: "ELL",
    4: "STR",
    5: "STR",
    6: "STR",
    7: "STR",
    8: "STR",
}

def build_escalation_list(conn, shifts_back: int = 3) -> list[dict]:
    items: list[dict] = []
    for name, sid in STATION_NAME_TO_ID.items():
        stops = get_stops_for_station(sid, conn, shifts_back)
        for stop in stops:
            items.append({
                "id": stop["id"],
                "title": stop["reason"],
                "status": stop["status"],
                "station": name,
                "start_time": stop["start_time"].isoformat(),
                "end_time": stop["end_time"].isoformat() if stop.get("end_time") else None,
            })
    items.sort(key=lambda x: x["id"], reverse=True)
    return items

# -------------------------
# Create new stop
# -------------------------
@router.post("/api/escalation/create_stop")
async def api_create_stop(payload: Dict[str, Any]):
    """
    Create a new stop with initial status.
    Required fields inside payload:
    - station_id, start_time, operator_id, stop_type, reason, status, linked_production_id
    """
    try:
        with get_mysql_connection() as conn:
            stop_id = create_stop(
                station_id=payload["station_id"],
                start_time=payload["start_time"],
                end_time=payload.get("end_time"),
                operator_id=payload["operator_id"],
                stop_type=payload["stop_type"],
                reason=payload["reason"],
                status=payload["status"],
                linked_production_id=payload.get("linked_production_id"),
                conn=conn,
            )

            if payload.get("stop_type") == "STOP":
                zone = STATION_ID_TO_ZONE.get(payload.get("station_id"))
                if zone:
                    ts = datetime.fromisoformat(str(payload.get("start_time")).split("+")[0])
                    if zone in ("AIN", "ELL"):
                        await run_in_thread(refresh_fermi_data, zone, ts)
                    elif zone == "STR":
                        await run_in_thread(refresh_snapshot, zone)

            updated = build_escalation_list(conn)
            await broadcast_escalation_update(updated)
        return {"status": "ok", "stop_id": stop_id}
    except Exception as e:
        logger.error(f"Error creating stop: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# -------------------------
# Update status of stop
# -------------------------
@router.post("/api/escalation/update_status")
async def api_update_status(payload: Dict[str, Any]):
    """
    Update status of existing stop.
    Required fields inside payload:
    - stop_id, new_status, changed_at, operator_id
    """
    try:
        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT station_id, type FROM stops WHERE id=%s", (payload["stop_id"],))
                row = cursor.fetchone()

            update_stop_status(
                stop_id=payload["stop_id"],
                new_status=payload["new_status"],
                changed_at=payload["changed_at"],
                operator_id=payload["operator_id"],
                conn=conn,
            )

            if row and row.get("type") == "STOP":
                zone = STATION_ID_TO_ZONE.get(row.get("station_id"))
                if zone:
                    ts = datetime.fromisoformat(str(payload.get("changed_at")).split("+")[0])
                    if zone in ("AIN", "ELL"):
                        await run_in_thread(refresh_fermi_data, zone, ts)
                    elif zone == "STR":
                        await run_in_thread(refresh_snapshot, zone)

            updated = build_escalation_list(conn)
            await broadcast_escalation_update(updated)
        return {"status": "ok"}
    except Exception as e:
        logger.error(f"Error updating stop status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# -------------------------
# Update reason/title of a stop
# -------------------------
@router.post("/api/escalation/update_reason")
async def api_update_reason(payload: Dict[str, Any]):
    """Update reason/title text for an existing stop."""
    try:
        with get_mysql_connection() as conn:
            update_stop_reason(
                stop_id=payload["stop_id"],
                reason=payload["reason"],
                conn=conn,
            )
            updated = build_escalation_list(conn)
            await broadcast_escalation_update(updated)
        return {"status": "ok"}
    except Exception as e:
        logger.error(f"Error updating stop reason: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# -------------------------
# Get stops for a station
# -------------------------
@router.get("/api/escalation/get_stops/{station_id}")
async def api_get_stops(station_id: int, shifts_back: int = 3):
    try:
        with get_mysql_connection() as conn:
            stops = get_stops_for_station(station_id, conn, shifts_back)
        return {"status": "ok", "stops": stops}
    except Exception as e:
        logger.error(f"Error fetching stops: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# -------------------------
# Get full stop + escalation levels
# -------------------------
@router.get("/api/escalation/get_stop_details/{stop_id}")
async def api_get_stop_details(stop_id: int):
    try:
        with get_mysql_connection() as conn:
            data = get_stop_with_levels(stop_id, conn)
        return {"status": "ok", "stop": data}
    except Exception as e:
        logger.error(f"Error fetching stop details: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/api/escalation/delete_stop/{stop_id}")
async def api_delete_stop(stop_id: int):
    try:
        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT station_id, type, start_time FROM stops WHERE id=%s", (stop_id,))
                row = cursor.fetchone()

                # 1️⃣ First delete related status change records
                cursor.execute("DELETE FROM stop_status_changes WHERE stop_id = %s", (stop_id,))

                # 2️⃣ Then delete the main stop entry
                cursor.execute("DELETE FROM stops WHERE id = %s", (stop_id,))

            conn.commit()
            updated = build_escalation_list(conn)
            await broadcast_escalation_update(updated)

            if row and row.get("type") == "STOP":
                zone = STATION_ID_TO_ZONE.get(row.get("station_id"))
                if zone:
                    ts = row.get("start_time")
                    if zone in ("AIN", "ELL"):
                        await run_in_thread(refresh_fermi_data, zone, ts)
                    elif zone == "STR":
                        await run_in_thread(refresh_snapshot, zone)
        return {"status": "ok"}
    except Exception as e:
        logger.error(f"Error deleting stop {stop_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

