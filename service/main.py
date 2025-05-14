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
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("PMS")

# Extend Python path for module resolution
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

# Local imports
from controllers.plc import PLCConnection
from service.config.config import CHANNELS, IMAGES_DIR, STATIONS_CONFIG_PATH, load_station_configs
from service.connections.mysql import get_mysql_connection
from service.state import global_state
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
from service.routes.images_routes import router as images_router
from service.routes.search_routes import router as search_router
from service.routes.websocket_routes import router as websocket_router


# ---------------- INIT GLOBAL FLAGS ----------------
for line in CHANNELS:
    for station in CHANNELS[line]:
        key = f"{line}.{station}"
        stop_threads[key] = False
        passato_flags[key] = False

# ---------------- START PLC BACKGROUND TASKS ----------------
def start_plc_background_tasks():
    line_configs = load_station_configs(str(STATIONS_CONFIG_PATH))
    for line, config in line_configs.items():
        plc_ip = config["PLC"]["IP"]
        plc_slot = config["PLC"]["SLOT"]
        for station in config["stations"]:
            key = f"{line}.{station}"
            plc_conn = PLCConnection(ip_address=plc_ip, slot=plc_slot, status_callback=make_status_callback(station))
            plc_connections[key] = plc_conn
            asyncio.create_task(background_task(plc_conn, key))
            logger.info(f"🚀 Background task created for {key}")

# ---------------- APP LIFESPAN ----------------
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    try:
        conn = get_mysql_connection()  # ✅ This ensures the global connection is initialized and valid
        logger.info("🟢 MySQL connected.")

        get_refreshed_settings()
        #start_plc_background_tasks()

        app.state.plc_connections = plc_connections
        yield

    finally:
        try:
            conn = get_mysql_connection()  # ✅ This will return the live connection or reconnect if needed
            conn.close()
            logger.info("🔴 MySQL disconnected.")
        except Exception as e:
            logger.warning(f"MySQL disconnection failed: {e}")


# ---------------- APP INIT ----------------
app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Change this in production!
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/images", StaticFiles(directory=str(IMAGES_DIR)), name="images")

# ---------------- ROUTE REGISTRATION ----------------
def register_routers(app: FastAPI):
    app.include_router(issue_router)
    app.include_router(warning_router)
    app.include_router(plc_router)
    app.include_router(overlay_router)
    app.include_router(export_router)
    app.include_router(settings_router)
    app.include_router(graph_router)
    app.include_router(station_router)
    app.include_router(images_router)
    app.include_router(search_router)
    app.include_router(websocket_router) 

register_routers(app)

# ---------------- MAIN ENTRY ----------------
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)
