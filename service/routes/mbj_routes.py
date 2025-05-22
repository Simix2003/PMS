from fastapi import APIRouter
from fastapi.responses import JSONResponse

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.helpers.mbj_xml import extract_CellDefects, extract_GlassCellDistance, extract_InterconnectionCellDistance, extract_InterconnectionGlassDistance, extract_RelativeCellPosition, preload_xml_index

router = APIRouter()

@router.get("/api/mbj_events/{modulo_id}")
def get_mbj_details(modulo_id: str):
    import glob
    import os
    from datetime import datetime, timedelta
    from xml.etree import ElementTree as ET
    from fastapi.responses import JSONResponse

    xml_folder = "C:/IX-Monitor/xml"
    pattern = os.path.join(xml_folder, f"{modulo_id}_*.xml")
    matching_files = glob.glob(pattern)

    if not matching_files:
        return JSONResponse(status_code=404, content={"detail": "No XML file found for this modulo"})

    # Pick the latest file by filename timestamp
    latest_file = sorted(matching_files)[-1]

    try:
        tree = ET.parse(latest_file)
        root = tree.getroot()

        # Extract inspection time
        inspection_time_str = root.findtext("InspectionTime")
        if not inspection_time_str:
            return JSONResponse(status_code=422, content={"detail": "Missing InspectionTime in XML"})

        inspection_time = datetime.fromisoformat(inspection_time_str.split("+")[0])
        inspection_end_time = inspection_time + timedelta(minutes=1)

        # Extract FinalJudgement and convert to esito
        final_judgement_str = root.findtext(".//FinalJudgement")
        raw_esito = int(final_judgement_str) if final_judgement_str and final_judgement_str.isdigit() else 10
        esito = 1 if raw_esito == 0 else 6 if raw_esito == 4 else 10

        ribbon_data = extract_InterconnectionGlassDistance(root)
        cell_data = extract_InterconnectionCellDistance(root)
        cell_gap_data = extract_RelativeCellPosition(root)
        glass_cell_data = extract_GlassCellDistance(root)
        cell_defects = extract_CellDefects(root)

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
            "glass_width": 2166, #2166,
            "glass_height": 1297, #1297,
            **ribbon_data,
            **cell_data,
            **cell_gap_data,
            **glass_cell_data,
            **cell_defects,
        }


    except Exception as e:
        return JSONResponse(status_code=500, content={"detail": f"Failed to parse XML: {e}"})

@router.post("/api/reload_xml_index")
def reload_xml_index():
    preload_xml_index("C:/IX-Monitor/xml")
    return {"status": "ok"}
