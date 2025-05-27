from fastapi import APIRouter, Request, Query
from fastapi.responses import JSONResponse
import json

import os
import sys


sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from service.routes.station_routes import get_station_for_object
from service.config.config import debug


router = APIRouter()


@router.get("/api/overlay_config")
async def get_overlay_config(
    path: str,
    line_name: str = Query(...),
    station: str = Query(...),
    object_id: str = Query(...)
):
    # Default config file path
    config_file = f"C:/IX-Monitor/images/{line_name}/{station}/overlay_config.json"

    # Resolve origin station if we are in ReWork (M326)
    comes_from = None
    if station == "M326" and object_id:
        station_info = await get_station_for_object(object_id)
        comes_from = station_info["station"]
        # Override config path based on origin
        config_file = f"C:/IX-Monitor/images/{line_name}/M308/overlay_config.json"
        if comes_from == 'M309':
            config_file = f"C:/IX-Monitor/images/{line_name}/M309/overlay_config.json"

    # Load the config file
    if not os.path.exists(config_file):
        print(f"❌ Config file not found: {config_file}")
        return JSONResponse(status_code=417, content={"error": f"Overlay config not found for {line_name}/{station}"})

    try:
        with open(config_file, "r") as f:
            all_configs = json.load(f)
    except json.JSONDecodeError as e:
        print(f"❌ JSON decode error: {e}")
        all_configs = {}

    # Look for the matching path
    for image_name, config in all_configs.items():
        config_path = config.get("path", "")

        if config_path.lower() == path.lower():
            # Default image URL
            if debug:
                image_url = f"http://localhost:8001/images/{line_name}/{station}/{image_name}"
            else:
                image_url = f"https://172.16.250.33:8050/images/{line_name}/{station}/{image_name}"
            
            # Override image URL if station is M326 and object came from a specific QC
            if station == "M326" and comes_from:
                if debug:
                    image_url = f"http://localhost:8001/images/{line_name}/M308/{image_name}"
                else:
                    image_url = f"https://172.16.250.33:8050/images/{line_name}/M308/{image_name}"
                if comes_from == 'M309':
                    if debug:
                        image_url = f"http://localhost:8001/images/{line_name}/M309/{image_name}"
                    else:
                        image_url = f"https://172.16.250.33:8050/images/{line_name}/M309/{image_name}"

            return {
                "image_url": image_url,
                "rectangles": config.get("rectangles", [])
            }

    print(f"⚠️ No matching path found. Returning fallback with empty image URL.")
    return {
        "image_url": "",
        "rectangles": []
    }


@router.post("/api/update_overlay_config")
async def update_overlay_config(request: Request):
    data = await request.json()
    path = data.get("path")
    new_rectangles = data.get("rectangles")
    line_name = data.get("line_name")
    station = data.get("station")

    if not path or not new_rectangles or not line_name or not station:
        return JSONResponse(status_code=400, content={"error": "Missing path, rectangles, line_name, or station"})

    config_file = f"C:/IX-Monitor/images/{line_name}/{station}/overlay_config.json"

    if not os.path.exists(config_file):
        return JSONResponse(status_code=404, content={"error": f"Config file not found for {line_name}/{station}"})

    with open(config_file, "r") as f:
        config = json.load(f)

    image_to_update = None
    for image_name, entry in config.items():
        if entry.get("path") == path:
            image_to_update = image_name
            break

    if not image_to_update:
        return JSONResponse(status_code=404, content={"error": "Path not found in config"})

    config[image_to_update]["rectangles"] = new_rectangles

    with open(config_file, "w") as f:
        json.dump(config, f, indent=4)

    return {"status": "updated", "image": image_to_update}


@router.get("/api/available_overlay_paths")
async def available_overlay_paths(
    line_name: str = Query(...),
    station: str = Query(...)
):
    config_file = f"C:/IX-Monitor/images/{line_name}/{station}/overlay_config.json"

    if not os.path.exists(config_file):
        return JSONResponse(status_code=404, content={"error": f"Config file not found for {line_name}/{station}"})

    with open(config_file, "r") as f:
        all_configs = json.load(f)

    result = []
    for image_name, config in all_configs.items():
        path = config.get("path")
        if path:
            result.append({
                "image": image_name,
                "path": path
            })
    return result
