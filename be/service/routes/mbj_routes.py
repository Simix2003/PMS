from fastapi import APIRouter, HTTPException
import glob
from datetime import datetime, timedelta
from xml.etree import ElementTree as ET
import logging

import os
import sys
from service.config.config import XML_FOLDER_PATH
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.helpers.mbj_xml import extract_CellDefects, extract_GlassCellDistance, extract_InterconnectionCellDistance, extract_InterconnectionGlassDistance, extract_RelativeCellPosition

router = APIRouter()
logger = logging.getLogger(__name__)

def parse_mbj_details(modulo_id: str) -> dict | None:
    pattern = os.path.join(XML_FOLDER_PATH, f"{modulo_id}_*.xml")
    matching_files = glob.glob(pattern)

    if not matching_files:
        pattern_fallback = os.path.join(XML_FOLDER_PATH, f"*{modulo_id}*.xml")
        matching_files = glob.glob(pattern_fallback)

    if not matching_files:
        logger.debug(f"[MBJ] No XML file found for modulo {modulo_id}")
        return None

    latest_file = max(matching_files, key=os.path.getmtime)

    try:
        tree = ET.parse(latest_file)
        root = tree.getroot()

        inspection_time_str = root.findtext("InspectionTime")
        if not inspection_time_str:
            logger.warning(f"[MBJ] Missing InspectionTime in XML for {modulo_id}")
            return None

        inspection_time = datetime.fromisoformat(inspection_time_str.split("+")[0])
        inspection_end_time = inspection_time + timedelta(seconds=60)

        final_judgement_str = root.findtext(".//FinalJudgement")
        raw_esito = int(final_judgement_str) if final_judgement_str and final_judgement_str.isdigit() else 10
        esito = 1 if raw_esito == 0 else 6 if raw_esito == 4 else 10

        TOLERANCES = {
            "ribbon": (11.9999, 2),
            "cell": (1.0, 2),
            "gap": (1.0, 2),
            "glass": (11.9999, 2),
        }

        count_crack = 0
        count_bad_soldering = 0

        def check_any_value_below(data, threshold, precision):
            if isinstance(data, dict):
                return any(
                    check_any_value_below(v, threshold, precision) for v in data.values()
                )
            if isinstance(data, list):
                return any(
                    check_any_value_below(v, threshold, precision) for v in data
                )
            if isinstance(data, (int, float)):
                return round(data, precision) < threshold
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


        has_el_defects = (count_crack + count_bad_soldering) == 0 and bool(cell_defects.get("cell_defects"))

        b1 = check_any_value_below(ribbon_data["interconnection_ribbon"], *TOLERANCES["ribbon"])
        b2 = check_any_value_below(cell_data["interconnection_cell"], *TOLERANCES["cell"])
        b3 = check_any_value_below(cell_gap_data["horizontal_cell_mm"], *TOLERANCES["gap"])
        b4 = check_any_value_below(cell_gap_data["vertical_cell_mm"], *TOLERANCES["gap"])
        b5 = check_any_value_below(glass_cell_data["glass_cell_mm"], *TOLERANCES["glass"])
        has_backlight_defects = b1 or b2 or b3 or b4 or b5

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
            "NG PMS Backlight": has_backlight_defects,
            "NG PMS Elettroluminescenza": has_el_defects,
            "Count Crack": count_crack,
            "Count Bad Solid": count_bad_soldering,
        }

    except Exception as e:
        logger.exception(f"[MBJ] Error parsing XML for {modulo_id}")
        return None


@router.get("/api/mbj_events/{modulo_id}")
def get_mbj_details(modulo_id: str):
    data = parse_mbj_details(modulo_id)
    if not data:
        raise HTTPException(status_code=404, detail="No valid XML data found")
    return data