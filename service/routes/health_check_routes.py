from fastapi import APIRouter
from typing import Dict
import os
import sys
import socket
import logging


sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection
from service.state.global_state import plc_connections

router = APIRouter()

# -------------------------
# Check Functions
# -------------------------

def check_database_connection() -> Dict[str, str]:
    try:
        conn = get_mysql_connection()
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1")
        return {"status": "ok", "message": "MySQL OK"}
    except Exception as e:
        logging.error(f"MySQL health check failed: {e}")
        return {"status": "error", "message": str(e)}

def check_plc_connections() -> Dict[str, Dict[str, str]]:
    """
    Reads from global_state.plc_connections and returns:
    {
        "LineaA": { "MIN01": "CONNECTED", "MIN02": "DISCONNECTED" },
        "LineaB": { "MIN01": "CONNECTED", ... }
    }
    """
    statuses: Dict[str, Dict[str, str]] = {}

    for full_id, plc_conn in plc_connections.items():
        try:
            line_name, channel_id = full_id.split(".")
        except ValueError:
            continue  # malformed key

        if line_name not in statuses:
            statuses[line_name] = {}

        statuses[line_name][channel_id] = "CONNESSO" if plc_conn.connected else "DISCONESSO"

    return statuses

# -------------------------
# Health Check Endpoint
# -------------------------

@router.get("/api/health_check")
async def health_check():
    return {
        "backend": {"status": "ok", "message": "Backend OK"},
        "database": check_database_connection(),
        "frontend": {"status": "ok", "message": "Frontend OK"},
        "plc_connections": check_plc_connections(),
    }
