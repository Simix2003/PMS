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
from service.routes.visual_routes import router as visual_router
# from service.AI.AI import router as ai_router  # Uncomment if needed

# ---------------- INIT GLOBAL FLAGS ----------------
def init_global_flags():
    logger.info("🔄 Initializing global flags for each Line.Station")
    stop_threads.clear()
    passato_flags.clear()
    for line, stations in CHANNELS.items():
        for station in stations:
            key = f"{line}.{station}"
            stop_threads[key] = False
            passato_flags[key] = False
    logger.info("✅ Global flags initialized.")

def start_plc_background_tasks():
    logger.info("🔄 Starting PLC background tasks using MySQL-based CHANNELS")

    shared_plc_connections: dict[tuple[str, int], PLCConnection] = {}

    for line, stations in CHANNELS.items():
        for station, config in stations.items():
            key = f"{line}.{station}"

            plc_info = config.get("plc")
            if not plc_info:
                logger.warning(f"⚠️ Skipping {key} – missing 'plc' configuration")
                continue

            plc_ip = plc_info.get("ip")
            plc_slot = plc_info.get("slot", 0)
            plc_key = (plc_ip, plc_slot)

            if debug:
                plc_conn = FakePLCConnection(station)
                logger.info(f"  • Using FakePLCConnection for {key}")
            else:
                if plc_key in shared_plc_connections:
                    plc_conn = shared_plc_connections[plc_key]
                    logger.info(f"  • Reusing existing PLC connection for {key} ({plc_ip}:{plc_slot})")
                else:
                    try:
                        plc_conn = PLCConnection(
                            ip_address=plc_ip,
                            slot=plc_slot,
                            status_callback=make_status_callback(station),
                        )
                        shared_plc_connections[plc_key] = plc_conn
                        logger.info(f"  • Created new PLC connection to {plc_ip}:{plc_slot} for {key}")
                    except Exception as e:
                        logger.error(f"❌ Failed to connect PLC for {key}: {e}")
                        continue

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

    # --- Load channel configurations ---
    logger.info("🔄 Loading station channel configurations from DB")
    try:
        CHANNELS.clear()
        PLC_DB_RANGES.clear()  # ← Assuming you define this global elsewhere

        channels, plc_db_ranges = load_channels_from_db()

        CHANNELS.update(channels)
        PLC_DB_RANGES.update(plc_db_ranges)

        init_global_flags()
        logger.info("✅ CHANNELS loaded from DB")
    except Exception as e:
        logger.error(f"❌ Failed to load CHANNELS: {e}")
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
    #start_plc_background_tasks()

    # --- Start XML watcher ---
    #logger.info("🔄 Starting XML folder watcher task")
    #try:
    #    asyncio.create_task(watch_folder_for_new_xml())
    #    logger.info("✅ XML watcher task scheduled.")
    #except Exception as e:
    #    logger.error(f"❌ Failed to schedule XML watcher: {e}")

    # --- Start visual summary updater ---
    #logger.info("🔄 Starting Visual Summary background task")
    #try:
    #    asyncio.create_task(visual_summary_background_task())
    #    logger.info("✅ Visual Summary updater task scheduled.")
    #except Exception as e:
    #    logger.error(f"❌ Failed to start visual summary task: {e}")

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
    app.include_router(visual_router)
    logger.info("  • visual_router registered")
    # app.include_router(ai_router)
    # logger.info("  • ai_router registered")

    logger.info("✅ All routers registered")


register_routers(app)
logger.info("✅ FastAPI application initialization complete")


# ---------------- MAIN ENTRY ----------------
if __name__ == "__main__":
    logger.info("🚀 Starting Uvicorn server")
    uvicorn.run(app, host="0.0.0.0", port=8001)
    logger.info("🚪 Uvicorn server terminated")