from fastapi import APIRouter
from fastapi.responses import JSONResponse
import glob
from datetime import datetime, timedelta
from xml.etree import ElementTree as ET
from fastapi.responses import JSONResponse

import os
import sys
from service.config.config import XML_FOLDER_PATH
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.helpers.mbj_xml import extract_CellDefects, extract_GlassCellDistance, extract_InterconnectionCellDistance, extract_InterconnectionGlassDistance, extract_RelativeCellPosition

router = APIRouter()

@router.get("/api/mbj_events/{modulo_id}")
def get_mbj_details(modulo_id: str):
    pattern = os.path.join(XML_FOLDER_PATH, f"{modulo_id}_*.xml")
    matching_files = glob.glob(pattern)

    if not matching_files:
        # Try fallback: match contains id_modulo anywhere
        pattern_fallback = os.path.join(XML_FOLDER_PATH, f"*{modulo_id}*.xml")
        matching_files = glob.glob(pattern_fallback)

    if not matching_files:
        return JSONResponse(status_code=404, content={"detail": "No XML file found for this modulo"})

    # Sort by modified time or filename for latest
    latest_file = max(matching_files, key=os.path.getmtime)

    try:
        tree = ET.parse(latest_file)
        root = tree.getroot()

        # Extract InspectionTime
        inspection_time_str = root.findtext("InspectionTime")
        if not inspection_time_str:
            return JSONResponse(status_code=422, content={"detail": "Missing InspectionTime in XML"})

        inspection_time = datetime.fromisoformat(inspection_time_str.split("+")[0])
        inspection_end_time = inspection_time + timedelta(seconds=60)

        final_judgement_str = root.findtext(".//FinalJudgement")
        raw_esito = int(final_judgement_str) if final_judgement_str and final_judgement_str.isdigit() else 10
        esito = 1 if raw_esito == 0 else 6 if raw_esito == 4 else 10

        TOLERANCES = {
            "ribbon": (12.0, 2),
            "cell": (1.0, 2),
            "gap": (1.0, 2),
            "glass": (12.0, 2),
        }
        count_crack = 0
        count_bad_soldering = 0

        def check_any_value_below(data, threshold, precision, depth=0):
            if isinstance(data, dict):
                for value in data.values():
                    if isinstance(value, (int, float)):
                        if round(value, precision) < threshold:
                            return True
                    elif isinstance(value, (dict, list)):
                        if check_any_value_below(value, threshold, precision, depth + 1):
                            return True
            elif isinstance(data, list):
                for value in data:
                    if isinstance(value, (int, float)):
                        if round(value, precision) < threshold:
                            return True
                    elif isinstance(value, (dict, list)):
                        if check_any_value_below(value, threshold, precision, depth + 1):
                            return True
            return False

        ribbon_data = extract_InterconnectionGlassDistance(root)
        cell_data = extract_InterconnectionCellDistance(root)
        cell_gap_data = extract_RelativeCellPosition(root)
        glass_cell_data = extract_GlassCellDistance(root)
        cell_defects = extract_CellDefects(root)
        if isinstance(cell_defects, dict):
            for cell in cell_defects.get("cell_defects", []):
                defects = set(cell.get("defects", []))
                if 7 in defects:
                    count_crack += 1
                if 81 in defects:
                    count_bad_soldering += 1

        has_el_defects = (count_crack + count_bad_soldering) == 0 and cell_defects["cell_defects"]

        has_backlight_defects = (
            check_any_value_below(ribbon_data["interconnection_ribbon"], *TOLERANCES["ribbon"]) or
            check_any_value_below(cell_data["interconnection_cell"], *TOLERANCES["cell"]) or
            check_any_value_below(cell_gap_data["horizontal_cell_mm"], *TOLERANCES["gap"]) or
            check_any_value_below(cell_gap_data["vertical_cell_mm"], *TOLERANCES["gap"]) or
            check_any_value_below(glass_cell_data["glass_cell_mm"], *TOLERANCES["glass"])
        )

        return {
            "id_modulo": modulo_id,
            "station_name": "MBJ",
            "start_time": inspection_time.isoformat(),
            "end_time": inspection_end_time.isoformat(),
            "cycle_time": 60.0,
            "esito": esito,
            "operator_id": "OPERATOR_ID",
            "last_station_display_name": "...",
            "line_display_name": "Linea B",
            "production_id": None,
            "defect_categories": "",
            "extra_data": "",
            "file_path": latest_file,
            "glass_width": 2166,
            "glass_height": 1297,
            **ribbon_data,
            **cell_data,
            **cell_gap_data,
            **glass_cell_data,
            **cell_defects,
            'NG PMS Backlight': has_backlight_defects,
            'NG PMS Elettroluminescenza': has_el_defects,
            'Count Crack': count_crack,
            'Count Bad Solid': count_bad_soldering,
        }

    except Exception as e:
        return JSONResponse(status_code=500, content={"detail": f"Failed to parse XML: {e}"})