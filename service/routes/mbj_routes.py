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

        def check_any_value_below(data, threshold):
            """Recursively check if any float value in nested dict/list is below the given threshold."""
            if isinstance(data, dict):
                for value in data.values():
                    if check_any_value_below(value, threshold):
                        return True
            elif isinstance(data, list):
                for value in data:
                    if isinstance(value, (int, float)) and value < threshold:
                        return True
                    elif isinstance(value, (dict, list)):
                        if check_any_value_below(value, threshold):
                            return True
            return False


        ribbon_data = extract_InterconnectionGlassDistance(root)
        cell_data = extract_InterconnectionCellDistance(root)
        cell_gap_data = extract_RelativeCellPosition(root)
        glass_cell_data = extract_GlassCellDistance(root)
        cell_defects = extract_CellDefects(root)
        has_el_defects = isinstance(cell_defects, dict) and len(cell_defects.get("cell_defects", [])) > 0

        # Apply checks
        has_backlight_defects = (
            check_any_value_below(ribbon_data, 12.0) or
            check_any_value_below(cell_data, 1.0) or
            check_any_value_below(cell_gap_data, 1.0) or
            check_any_value_below(glass_cell_data, 12.0)
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
        }

    except Exception as e:
        return JSONResponse(status_code=500, content={"detail": f"Failed to parse XML: {e}"})