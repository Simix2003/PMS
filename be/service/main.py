import asyncio
import os
import sys
import logging
import logging.config
import logging.handlers
import json
import time
from typing import AsyncGenerator
from contextlib import asynccontextmanager
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.middleware.base import BaseHTTPMiddleware

# ----------- JSON Formatter -----------
class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        json_data = getattr(record, "json", None)
        if isinstance(json_data, dict):
            log_record = dict(json_data)
        else:
            log_record = {"message": record.getMessage()}

        log_record.update({
            "timestamp": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "name": record.name,
        })

        if record.exc_info:
            log_record["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_record, ensure_ascii=False)

# ----------- Logging Config -----------
def configure_logging() -> dict:
    log_config = {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "json": {"()": JsonFormatter}
        },
        "handlers": {
            "default": {
                "class": "logging.StreamHandler",
                "formatter": "json",
                "stream": "ext://sys.stdout",
                "level": LOGS_TERMINAL,  # ← Inject from config
            },
            "file": {
                "class": "logging.handlers.TimedRotatingFileHandler",
                "filename": str(LOG_FILE),
                "formatter": "json",
                "when": "midnight",
                "backupCount": 7,
                "encoding": "utf-8",
                "level": LOGS_FILE,  # ← Inject from config
            },
        },
        "root": {
            "level": "DEBUG",  # Keep root permissive; handlers do filtering
            "handlers": ["default", "file"]
        },
        "loggers": {
            "uvicorn": {
                "handlers": ["default"],
                "level": "INFO",
                "propagate": False
            },
            "uvicorn.error": {
                "handlers": ["default"],
                "level": "INFO",
                "propagate": False
            },
            "uvicorn.access": {
                "handlers": ["default"],
                "level": "INFO",
                "propagate": False
            },
        },
    }

    logging.config.dictConfig(log_config)
    return log_config

class AccessLogMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        start_time = time.perf_counter()
        response = await call_next(request)
        duration_ms = round((time.perf_counter() - start_time) * 1000, 2)
        logging.getLogger("uvicorn.access").info(
            "",
            extra={
                "json": {
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": response.status_code,
                    "duration_ms": duration_ms,
                }
            },
        )
        return response

# Extend Python path for module resolution
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

if sys.platform.startswith("win"):
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

# Local imports
from controllers.plc import PLCConnection
from service.controllers.debug_plc import FakePLCConnection
from service.config.config import CHANNELS, IMAGES_DIR, LOG_FILE, PLC_DB_RANGES, LOGS_FILE, LOGS_TERMINAL, debug
from service.connections.mysql import get_mysql_connection, load_channels_from_db
from service.tasks.main_esito_task import background_task
from service.tasks.main_fermi_task import fermi_task
from service.helpers.visuals.visual_helper import refresh_median_cycle_time_ELL, refresh_median_cycle_time_vpf
from service.state.global_state import (
    plc_connections,
    stop_threads,
    inizio_true_passato_flags,
    inizio_false_passato_flags,
    fine_false_passato_flags,
    fine_true_passato_flags,
    executor,
    db_write_queue,
)
from service.routes.plc_routes import router as plc_router
from service.routes.issue_routes import router as issue_router
from service.routes.warning_routes import router as warning_router
from service.routes.overlay_routes import router as overlay_router
from service.routes.export_routes import router as export_router
from service.routes.settings_routes import router as settings_router, get_refreshed_settings
from service.routes.graph_routes import router as graph_router
from service.routes.station_routes import router as station_router
from service.routes.search_routes import router as search_router
from service.routes.websocket_routes import router as websocket_router
from service.routes.health_check_routes import router as health_check_router
from service.routes.mbj_routes import router as mbj_router
from service.routes.ml_routes import router as ml_router
from service.routes.visual_routes import initialize_visual_cache, router as visual_router
from service.routes.escalation_routes import router as escalation_router
from service.routes.simix_rca_routes import router as simix_rca_router

LOG_CONFIG = configure_logging()
logger = logging.getLogger(__name__)

logger.info(f"Logging to {LOG_FILE} with level {LOGS_FILE} and DEBUG={debug}")

# Log uncaught asyncio exceptions instead of crashing
loop = asyncio.get_event_loop()

def _handle_async_exception(loop, context):
    err = context.get("exception") or context.get("message")
    logger.error(f"Unhandled asyncio exception: {err}")

loop.set_exception_handler(_handle_async_exception)

async def monitor_plc_ports(plcs: list[tuple[str, int]], interval: int = 10, warn_threshold_ms: float = 100.0):
    """
    Monitora la porta 102 di ogni PLC e logga latenza o timeout.
    - DEBUG per latenza normale
    - WARNING se la latenza supera warn_threshold_ms
    - WARNING per errori di connessione
    """
    import socket
    from datetime import datetime
    while True:
        for ip, slot in plcs:
            start = time.perf_counter()
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(2.0)
                sock.connect((ip, 102))
                latency = (time.perf_counter() - start) * 1000
                sock.close()

                log_func = logger.warning if latency > warn_threshold_ms else logger.debug
                log_func(
                    "",
                    extra={"json": {
                        "event": "plc_port_check",
                        "ip": ip,
                        "slot": slot,
                        "status": "ok",
                        "latency_ms": round(latency, 2),
                        "timestamp": datetime.now().isoformat()
                    }},
                )
            except Exception as e:
                logger.warning(
                    "",
                    extra={"json": {
                        "event": "plc_port_check",
                        "ip": ip,
                        "slot": slot,
                        "status": "error",
                        "error": str(e),
                        "timestamp": datetime.now().isoformat()
                    }},
                )
        await asyncio.sleep(interval)

# ---------------- INIT GLOBAL FLAGS ----------------
def init_global_flags():
    stop_threads.clear()
    inizio_true_passato_flags.clear()
    inizio_false_passato_flags.clear()
    fine_true_passato_flags.clear()
    fine_false_passato_flags.clear()
    for line, stations in CHANNELS.items():
        for station in stations:
            key = f"{line}.{station}"
            stop_threads[key] = False
            inizio_true_passato_flags[key] = False
            inizio_false_passato_flags[key] = False
            fine_true_passato_flags[key] = False
            fine_false_passato_flags[key] = False

# ---------------- FAST STARTUP ----------------
async def async_load_channels():
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(executor, load_channels_from_db)

async def async_get_refreshed_settings():
    loop = asyncio.get_running_loop()
    await loop.run_in_executor(executor, get_refreshed_settings)

async def start_background_tasks():
    try:
        initialize_visual_cache()
        logger.debug("visual_data cache initialized")
    except Exception as e:
        logger.error(f"visual_data cache init failed: {e}")

    # Start queue for deferred DB writes
    db_write_queue.start()

    logger.debug("Starting PLC background tasks and Fermi tasks")

    shared_conns: dict[tuple[str, int], PLCConnection] = {}

    # STEP 1 — Build unique PLC list first
    unique_plcs = set()

    for line, stations in CHANNELS.items():
        for station, config in stations.items():
            plc_info = config.get("plc")
            if not plc_info:
                continue

            ip, slot = plc_info.get("ip"), plc_info.get("slot", 0)
            unique_plcs.add((ip, slot))

    # STEP 2 — Create 1 connection and fermi_task per PLC
    for ip, slot in unique_plcs:
        try:
            if debug:
                plc = FakePLCConnection(f"{ip}:{slot}")
            else:
                plc = PLCConnection(ip_address=ip, slot=slot, status_callback=None)
            shared_conns[(ip, slot)] = plc
            asyncio.create_task(fermi_task(plc, ip, slot))
            logger.debug(f"Fermi task started for PLC {ip}:{slot}")
        except Exception as e:
            logger.error(f"PLC connect failed for {ip}:{slot}: {e}")

    # STEP 3 — Now create background tasks per station
    for line, stations in CHANNELS.items():
        for station, config in stations.items():
            key = f"{line}.{station}"
            plc_info = config.get("plc")
            if not plc_info:
                logger.warning(f"No PLC config for {key}")
                continue

            ip, slot = plc_info.get("ip"), plc_info.get("slot", 0)

            default_plc = config.get("plc")
            if not default_plc:
                logger.warning(f"No PLC config for {key}")
                continue

            # Get field-level PLC overrides
            trigger_plc = config.get("trigger", {}).get("plc") or default_plc
            fine_buona_plc = config.get("fine_buona", {}).get("plc") or default_plc

            # Extract both keys
            trigger_key = (trigger_plc["ip"], trigger_plc.get("slot", 0))
            end_key = (fine_buona_plc["ip"], fine_buona_plc.get("slot", 0))

            # Lookup connections
            conn_trigger = shared_conns.get(trigger_key)
            conn_end = shared_conns.get(end_key)

            if not conn_trigger:
                logger.warning(f"No PLC connection for trigger {trigger_key} at station {key}")
                continue
            if not conn_end:
                logger.warning(f"No PLC connection for end {end_key} at station {key}")
                continue

            # Pass single or dual connection depending on match
            if trigger_key == end_key:
                plc_connections[key] = conn_trigger
                asyncio.create_task(background_task([conn_trigger], key))
            else:
                plc_connections[key] = conn_trigger  # ← default: store trigger one
                asyncio.create_task(background_task([conn_trigger, conn_end], key))

            logger.debug(f"Background task started for station {key} (Trigger: {trigger_key}, End: {end_key})")

    # STEP 4 — Refresh VPF median every 59 minutes
    async def loop_refresh_median():
        while True:
            try:
                refresh_median_cycle_time_vpf()
            except Exception as e:
                logger.warning(f"VPF Median refresh failed: {e}")
            
            try:
                refresh_median_cycle_time_ELL()
            except Exception as e:
                logger.warning(f"ELL Median refresh failed: {e}")
            await asyncio.sleep(59 * 60)  # 59 minutes

    asyncio.create_task(loop_refresh_median())
    logger.debug("Scheduled VPF median refresh every 59 minutes")

    # Avvia il monitor della porta 102 ogni 10 secondi
    #if not debug: 
    #    asyncio.create_task(monitor_plc_ports(list(unique_plcs), interval=10))
    #logger.debug("PLC port 102 monitor task avviato")

    logger.debug("All PLC and background tasks launched")

# ---------------- LIFESPAN ----------------
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    logger.debug("FastAPI lifespan STARTUP")

    logger.info("Debug value is set to {}".format(debug))

    # Load channels + DB ranges
    try:
        CHANNELS.clear()
        PLC_DB_RANGES.clear()
        channels, plc_ranges = await async_load_channels()
        CHANNELS.update(channels)
        PLC_DB_RANGES.update(plc_ranges)
        init_global_flags()
        logger.debug("CHANNELS loaded")
    except Exception as e:
        logger.error(f"CHANNEL loading failed: {e}")
        raise

    # Settings reload (non-blocking)
    asyncio.create_task(async_get_refreshed_settings())

    # Start other background jobs (non-blocking)
    asyncio.create_task(start_background_tasks())

    app.state.plc_connections = plc_connections
    try:
        logger.debug("STARTUP complete")
        yield
    finally:
        logger.debug("SHUTDOWN phase")
        try:
            with get_mysql_connection() as conn:
                conn.close()
            logger.debug("MySQL disconnected")
        except Exception as e:
            logger.warning(f"MySQL close failed: {e}")
        logger.debug("SHUTDOWN complete")

# ---------------- FASTAPI INIT ----------------
logger.debug("Creating FastAPI app")
app = FastAPI(lifespan=lifespan)

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.add_middleware(AccessLogMiddleware)
app.mount("/images", StaticFiles(directory=str(IMAGES_DIR)), name="images")

# Register routers
for router, name in [
    (issue_router, "issue"), (warning_router, "warning"), (plc_router, "plc"),
    (overlay_router, "overlay"), (export_router, "export"), (settings_router, "settings"),
    (graph_router, "graph"), (station_router, "station"), (search_router, "search"),
    (websocket_router, "websocket"), (health_check_router, "health_check"),
    (mbj_router, "mbj"), (ml_router, "ml"), (visual_router, "visual"), (escalation_router, "escalation"), (simix_rca_router, "simix_rca")
]:
    app.include_router(router)
    logger.debug(f"  • {name}_router registered")

logger.debug("FastAPI app ready")

# ---------------- MAIN ENTRY ----------------
if __name__ == "__main__":
    logger.debug("Launching Uvicorn")
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8001,
        log_config=LOG_CONFIG,
        access_log=False,
    )
