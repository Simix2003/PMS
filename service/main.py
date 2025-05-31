import asyncio
import os
import sys
import logging

from typing import AsyncGenerator
from contextlib import asynccontextmanager

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
from service.config.config import CHANNELS, IMAGES_DIR, STATIONS_CONFIG_PATH, load_station_configs, debug
from service.connections.mysql import get_mysql_connection
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
# from service.AI.AI import router as ai_router  # Uncomment if needed

# ---------------- INIT GLOBAL FLAGS ----------------
logger.info("🔄 Initializing global flags for each Line.Station")
for line in CHANNELS:
    for station in CHANNELS[line]:
        key = f"{line}.{station}"
        stop_threads[key] = False
        passato_flags[key] = False
logger.info("✅ Global flags initialized.")


# ---------------- START PLC BACKGROUND TASKS ----------------
def start_plc_background_tasks():
    logger.info("🔄 Loading station configurations and starting PLC background tasks")
    try:
        line_configs = load_station_configs(str(STATIONS_CONFIG_PATH))
        logger.info(f"✅ Loaded station configs from {STATIONS_CONFIG_PATH}")
    except Exception as e:
        logger.error(f"❌ Failed to load station configs: {e}")
        raise

    for line, config in line_configs.items():
        plc_ip = config["PLC"]["IP"]
        plc_slot = config["PLC"]["SLOT"]
        for station in config["stations"]:
            key = f"{line}.{station}"
            if debug:
                plc_conn = FakePLCConnection(station)
                logger.info(f"  • Using FakePLCConnection for {key}")
            else:
                plc_conn = PLCConnection(
                    ip_address=plc_ip,
                    slot=plc_slot,
                    status_callback=make_status_callback(station),
                )
                logger.info(f"  • Connecting to real PLC at {plc_ip}:{plc_slot} for {key}")

            plc_connections[key] = plc_conn
            asyncio.create_task(background_task(plc_conn, key))
            logger.info(f"🚀 Background task created and scheduled for {key}")
    logger.info("✅ All PLC background tasks started.")


# ---------------- APP LIFESPAN ----------------
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    logger.info("🚀 FastAPI lifespan: STARTUP phase")
    # --- Initialize MySQL ---
    logger.info("🔄 Attempting to connect to MySQL")
    try:
        conn = get_mysql_connection()
        logger.info("🟢 MySQL connected.")
    except Exception as e:
        logger.error(f"❌ MySQL connection failed: {e}")
        raise

    # --- Load settings ---
    logger.info("🔄 Loading and refreshing settings")
    try:
        get_refreshed_settings()
        logger.info("✅ Settings refreshed.")
    except Exception as e:
        logger.error(f"❌ Settings refresh failed: {e}")
        raise

    # --- Start PLC tasks ---
    start_plc_background_tasks()

    # --- Start XML watcher ---
    logger.info("🔄 Starting XML folder watcher task")
    try:
        asyncio.create_task(watch_folder_for_new_xml())
        logger.info("✅ XML watcher task scheduled.")
    except Exception as e:
        logger.error(f"❌ Failed to schedule XML watcher: {e}")

    # Expose PLC connections on app.state
    app.state.plc_connections = plc_connections

    logger.info("✅ FastAPI lifespan: STARTUP phase complete. Yielding control to FastAPI.")
    try:
        yield
    finally:
        # --- Shutdown / Cleanup ---
        logger.info("🔄 FastAPI lifespan: SHUTDOWN phase")
        try:
            conn = get_mysql_connection()
            conn.close()
            logger.info("🔴 MySQL disconnected.")
        except Exception as e:
            logger.warning(f"⚠️ MySQL disconnection failed: {e}")
        logger.info("✅ FastAPI lifespan: SHUTDOWN phase complete.")


# ---------------- APP INIT ----------------
logger.info("🔄 Initializing FastAPI application instance")
app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Change this in production!
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
logger.info("✅ CORS middleware configured")

# Mount static directory for images
app.mount("/images", StaticFiles(directory=str(IMAGES_DIR)), name="images")
logger.info(f"✅ StaticFiles mounted at /images -> {IMAGES_DIR}")


# ---------------- ROUTE REGISTRATION ----------------
def register_routers(app: FastAPI):
    logger.info("🔄 Registering API routers")
    app.include_router(issue_router)
    logger.info("  • issue_router registered")
    app.include_router(warning_router)
    logger.info("  • warning_router registered")
    app.include_router(plc_router)
    logger.info("  • plc_router registered")
    app.include_router(overlay_router)
    logger.info("  • overlay_router registered")
    app.include_router(export_router)
    logger.info("  • export_router registered")
    app.include_router(settings_router)
    logger.info("  • settings_router registered")
    app.include_router(graph_router)
    logger.info("  • graph_router registered")
    app.include_router(station_router)
    logger.info("  • station_router registered")
    app.include_router(search_router)
    logger.info("  • search_router registered")
    app.include_router(websocket_router)
    logger.info("  • websocket_router registered")
    app.include_router(health_check_router)
    logger.info("  • health_check_router registered")
    app.include_router(mbj_router)
    logger.info("  • mbj_router registered")
    app.include_router(ml_router)
    logger.info("  • ml_router registered")
    # app.include_router(ai_router)
    # logger.info("  • ai_router registered (commented out)")

    logger.info("✅ All routers registered")


register_routers(app)
logger.info("✅ FastAPI application initialization complete")


# ---------------- MAIN ENTRY ----------------
if __name__ == "__main__":
    logger.info("🚀 Starting Uvicorn server")
    uvicorn.run(app, host="0.0.0.0", port=8001)
    logger.info("🚪 Uvicorn server terminated")