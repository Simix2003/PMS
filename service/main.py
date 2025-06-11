import asyncio
import os
import sys
import logging
from typing import AsyncGenerator
from contextlib import asynccontextmanager
from concurrent.futures import ThreadPoolExecutor

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

# Setup logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("PMS")

# Extend Python path for module resolution
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

# Local imports
from controllers.plc import PLCConnection
from service.controllers.debug_plc import FakePLCConnection
from service.config.config import CHANNELS, IMAGES_DIR, PLC_DB_RANGES, debug
from service.connections.mysql import get_mysql_connection, load_channels_from_db
from service.connections.xml_watcher import watch_folder_for_new_xml
from service.tasks.main_task import background_task, make_status_callback
from service.state.global_state import plc_connections, stop_threads, passato_flags
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

# ---------------- INIT GLOBAL FLAGS ----------------
def init_global_flags():
    stop_threads.clear()
    passato_flags.clear()
    for line, stations in CHANNELS.items():
        for station in stations:
            key = f"{line}.{station}"
            stop_threads[key] = False
            passato_flags[key] = False

# ---------------- FAST STARTUP ----------------
_executor = ThreadPoolExecutor(max_workers=10)

async def async_load_channels():
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_executor, load_channels_from_db)

async def async_get_refreshed_settings():
    loop = asyncio.get_running_loop()
    await loop.run_in_executor(_executor, get_refreshed_settings)

async def start_background_tasks():
    try:
        initialize_visual_cache()
        logger.info("✅ visual_data cache initialized")
    except Exception as e:
        logger.error(f"❌ visual_data cache init failed: {e}")

    #try:
    #    asyncio.create_task(watch_folder_for_new_xml())
    #    logger.info("✅ XML watcher task started")
    #except Exception as e:
    #    logger.error(f"❌ XML watcher task failed: {e}")

    logger.info("🔄 Starting PLC background tasks")
    shared_conns: dict[tuple[str, int], PLCConnection] = {}
    for line, stations in CHANNELS.items():
        for station, config in stations.items():
            key = f"{line}.{station}"
            plc_info = config.get("plc")
            if not plc_info:
                logger.warning(f"⚠️ No PLC config for {key}")
                continue

            ip, slot = plc_info.get("ip"), plc_info.get("slot", 0)
            pkey = (ip, slot)

            if debug:
                plc = FakePLCConnection(station)
            else:
                try:
                    if pkey in shared_conns:
                        plc = shared_conns[pkey]
                    else:
                        plc = PLCConnection(ip_address=ip, slot=slot, status_callback=make_status_callback(station))
                        shared_conns[pkey] = plc
                except Exception as e:
                    logger.error(f"❌ PLC connect failed for {key}: {e}")
                    continue

            plc_connections[key] = plc
            asyncio.create_task(background_task(plc, key))
    logger.info("✅ All PLC background tasks launched")

# ---------------- LIFESPAN ----------------
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    logger.info("🚀 FastAPI lifespan STARTUP")

    # Fast connect check
    try:
        conn = get_mysql_connection()
        logger.info("🟢 MySQL connected")
    except Exception as e:
        logger.error(f"❌ MySQL failed: {e}")
        raise

    # Load channels + DB ranges
    try:
        CHANNELS.clear()
        PLC_DB_RANGES.clear()
        channels, plc_ranges = await async_load_channels()
        CHANNELS.update(channels)
        PLC_DB_RANGES.update(plc_ranges)
        init_global_flags()
        logger.info("✅ CHANNELS loaded")
    except Exception as e:
        logger.error(f"❌ CHANNEL loading failed: {e}")
        raise

    # Settings reload (non-blocking)
    asyncio.create_task(async_get_refreshed_settings())

    # Start other background jobs (non-blocking)
    asyncio.create_task(start_background_tasks())

    app.state.plc_connections = plc_connections
    try:
        logger.info("✅ STARTUP complete")
        yield
    finally:
        logger.info("🔄 SHUTDOWN phase")
        try:
            conn = get_mysql_connection()
            conn.close()
            logger.info("🔴 MySQL disconnected")
        except Exception as e:
            logger.warning(f"⚠️ MySQL close failed: {e}")
        logger.info("✅ SHUTDOWN complete")

# ---------------- FASTAPI INIT ----------------
logger.info("🔄 Creating FastAPI app")
app = FastAPI(lifespan=lifespan)

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.mount("/images", StaticFiles(directory=str(IMAGES_DIR)), name="images")

# Register routers
for router, name in [
    (issue_router, "issue"), (warning_router, "warning"), (plc_router, "plc"),
    (overlay_router, "overlay"), (export_router, "export"), (settings_router, "settings"),
    (graph_router, "graph"), (station_router, "station"), (search_router, "search"),
    (websocket_router, "websocket"), (health_check_router, "health_check"),
    (mbj_router, "mbj"), (ml_router, "ml"), (visual_router, "visual"), (escalation_router, "escalation")
]:
    app.include_router(router)
    logger.info(f"  • {name}_router registered")

logger.info("✅ FastAPI app ready")

# ---------------- MAIN ENTRY ----------------
if __name__ == "__main__":
    logger.info("🚀 Launching Uvicorn")
    uvicorn.run(app, host="0.0.0.0", port=8001)
