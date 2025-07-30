from fastapi import APIRouter, Request, Query
from fastapi.responses import JSONResponse
import json
import os
import logging

from service.routes.station_routes import get_station_for_object
from service.config.config import debug, IMAGES_DIR

router = APIRouter()
logger = logging.getLogger(__name__)


def get_config_path(line_name: str, station: str):
    return os.path.join(IMAGES_DIR, line_name, station, "overlay_config.json")

@router.get("/api/overlay_config")
async def get_overlay_config(
    path: str,
    line_name: str = Query(...),
    station: str = Query(...),
    object_id: str = Query(...)
):
    comes_from = None
    target_station = station
    if station == "RMI01" and object_id:
        station_info = await get_station_for_object(object_id)
        comes_from = station_info["station"]
        target_station = comes_from if comes_from in ["MIN01", "MIN02"] else "MIN01"

    config_file = get_config_path(line_name, target_station)

    if not os.path.exists(config_file):
        logger.error(f"Config file not found: {config_file}")
        return JSONResponse(status_code=417, content={"error": f"Overlay config not found for {line_name}/{station}"})

    try:
        with open(config_file, "r") as f:
            all_configs = json.load(f)
    except json.JSONDecodeError as e:
        logging.error(f"JSON decode error: {e}")
        all_configs = {}

    for image_name, config in all_configs.items():
        config_path = config.get("path", "")
        if config_path.lower() == path.lower():
            image_url = f"/images/{line_name}/{target_station}/{image_name}"
            if not debug:
                image_url = f"https://172.16.250.33:8050{image_url}"
            else:
                image_url = f"http://localhost:8001{image_url}"

            return {
                "image_url": image_url,
                "rectangles": config.get("rectangles", [])
            }

    #logging.warning("No matching path found. Returning fallback with empty image URL.")
    return {"image_url": "", "rectangles": []}


@router.post("/api/update_overlay_config")
async def update_overlay_config(request: Request):
    data = await request.json()
    path = data.get("path")
    new_rectangles = data.get("rectangles")
    line_name = data.get("line_name")
    station = data.get("station")

    if not all([path, new_rectangles, line_name, station]):
        return JSONResponse(status_code=400, content={"error": "Missing path, rectangles, line_name, or station"})

    config_file = get_config_path(line_name, station)

    if not os.path.exists(config_file):
        return JSONResponse(status_code=404, content={"error": f"Config file not found for {line_name}/{station}"})

    with open(config_file, "r") as f:
        config = json.load(f)

    image_to_update = next((name for name, c in config.items() if c.get("path") == path), None)
    if not image_to_update:
        return JSONResponse(status_code=404, content={"error": "Path not found in config"})

    config[image_to_update]["rectangles"] = new_rectangles

    with open(config_file, "w") as f:
        json.dump(config, f, indent=4)

    return {"status": "updated", "image": image_to_update}


@router.get("/api/available_overlay_paths")
async def available_overlay_paths(line_name: str = Query(...), station: str = Query(...)):
    config_file = get_config_path(line_name, station)

    if not os.path.exists(config_file):
        return JSONResponse(status_code=404, content={"error": f"Config file not found for {line_name}/{station}"})

    with open(config_file, "r") as f:
        all_configs = json.load(f)

    result = [
        {"image": name, "path": config.get("path")}
        for name, config in all_configs.items()
        if config.get("path")
    ]
    return result
