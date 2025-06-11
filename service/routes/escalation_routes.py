from fastapi import APIRouter, HTTPException
from typing import Dict, Any
import os
import sys
import logging

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection, create_stop, update_stop_status, get_stops_for_station, get_stop_with_levels

router = APIRouter()

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
        conn = get_mysql_connection()

        stop_id = create_stop(
            station_id = payload["station_id"],
            start_time = payload["start_time"],
            end_time = payload.get("end_time"),
            operator_id = payload["operator_id"],
            stop_type = payload["stop_type"],
            reason = payload["reason"],
            status = payload["status"],
            linked_production_id = payload.get("linked_production_id"),
            conn = conn
        )
        return {"status": "ok", "stop_id": stop_id}
    except Exception as e:
        logging.error(f"Error creating stop: {e}")
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
        conn = get_mysql_connection()

        update_stop_status(
            stop_id = payload["stop_id"],
            new_status = payload["new_status"],
            changed_at = payload["changed_at"],
            operator_id = payload["operator_id"],
            conn = conn
        )
        return {"status": "ok"}
    except Exception as e:
        logging.error(f"Error updating stop status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# -------------------------
# Get stops for a station
# -------------------------
@router.get("/api/escalation/get_stops/{station_id}")
async def api_get_stops(station_id: int, limit: int = 100):
    try:
        conn = get_mysql_connection()
        stops = get_stops_for_station(station_id, conn, limit)
        return {"status": "ok", "stops": stops}
    except Exception as e:
        logging.error(f"Error fetching stops: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# -------------------------
# Get full stop + escalation levels
# -------------------------
@router.get("/api/escalation/get_stop_details/{stop_id}")
async def api_get_stop_details(stop_id: int):
    try:
        conn = get_mysql_connection()
        data = get_stop_with_levels(stop_id, conn)
        return {"status": "ok", "stop": data}
    except Exception as e:
        logging.error(f"Error fetching stop details: {e}")
        raise HTTPException(status_code=500, detail=str(e))
