from fastapi import APIRouter, status, Response
from typing import Dict
import os
import sys
import logging
import time
import platform
import socket
import psutil
import json
from datetime import timedelta, datetime

# Extend Python path per import interni progetto
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection
from service.state.global_state import plc_connections

router = APIRouter()
logger = logging.getLogger(__name__)

# Timestamp avvio processo
process_start_time = time.time()

# Lettura variabili build-time
build_date = os.getenv("BUILD_DATE", "26/06/2025")
app_version = os.getenv("APP_VERSION", "2.4.0")
git_commit = os.getenv("GIT_COMMIT", "DEV/0a12d46")

# --- Utility ---

def get_uptime() -> str:
    uptime_seconds = time.time() - process_start_time
    return str(timedelta(seconds=int(uptime_seconds)))

def check_database_connection() -> Dict[str, str]:
    try:
        conn = get_mysql_connection()
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1")
        return {"status": "ok", "message": "MySQL OK"}
    except Exception as e:
        logger.error(f"MySQL health check failed: {e}")
        return {"status": "error", "message": str(e)}

def check_plc_connections() -> Dict[str, Dict[str, str]]:
    statuses: Dict[str, Dict[str, str]] = {}
    for full_id, plc_conn in plc_connections.items():
        try:
            line_name, channel_id = full_id.split(".")
        except ValueError:
            continue
        if line_name not in statuses:
            statuses[line_name] = {}
        statuses[line_name][channel_id] = "CONNECTED" if plc_conn.connected else "DISCONNECTED"
    return statuses

def all_plcs_connected(plc_statuses: Dict[str, Dict[str, str]]) -> bool:
    for line in plc_statuses.values():
        if any(status != "CONNECTED" for status in line.values()):
            return False
    return True

def check_system_resources() -> Dict[str, str]:
    cpu_usage = psutil.cpu_percent(interval=1)
    ram = psutil.virtual_memory()
    disk = psutil.disk_usage("/")
    return {
        "cpu_usage": f"{cpu_usage}%",
        "ram_usage": f"{ram.percent}%",
        "disk_free": f"{round(disk.free / (1024**3), 2)} GB",
        "disk_total": f"{round(disk.total / (1024**3), 2)} GB"
    }

# --- Health Check API ---

@router.get("/api/health_check")
async def health_check(response: Response):
    backend_info = {
        "status": "ok",
        "version": app_version,
        "build_date": build_date,
        "git_commit": git_commit,
        "uptime": get_uptime(),
        "hostname": platform.node(),
        "ip": socket.gethostbyname(socket.gethostname()),
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }

    db_status = check_database_connection()
    plc_statuses = check_plc_connections()
    sys_resources = check_system_resources()

    critical_failure = (
        db_status["status"] != "ok" or not all_plcs_connected(plc_statuses)
    )

    if critical_failure:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    health_response = {
        "status": "ok" if not critical_failure else "degraded",
        "backend": backend_info,
        "system": sys_resources,
        "database": db_status,
        "plc_connections": plc_statuses
    }

    # Logging JSON conforme alle specifiche cliente
    logger.info(json.dumps({
        "event": "health_check",
        "timestamp": backend_info["timestamp"],
        "result": health_response
    }))

    return health_response


# --- Web Health Endpoint ---

@router.get("/web_health")
async def web_health() -> Response:
    """Simple endpoint used to check that the frontend is reachable."""
    return Response(content="OK", media_type="text/plain")
