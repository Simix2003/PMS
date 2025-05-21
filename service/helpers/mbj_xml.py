import os
import logging

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

import service.state.global_state as global_state

def preload_xml_index(xml_folder: str = "C:/IX-Monitor/xml"):
    import glob
    from datetime import datetime, timedelta

    pattern = os.path.join(xml_folder, "*.xml")
    for file_path in glob.glob(pattern):
        try:
            fname = os.path.basename(file_path)
            parts = fname.replace(".xml", "").split("_")
            if len(parts) < 3:
                continue

            modulo_id = parts[0]
            dt = datetime.strptime(parts[1] + parts[2], "%Y%m%d%H%M%S")
            entry = {
                "id_modulo": modulo_id,
                "start_time": dt,
                "end_time": dt + timedelta(minutes=1),
                "station_name": "MBJ",
                "line_display_name": "Linea B",
                "cycle_time": 60.0,
                "esito": 10,
                "operator_id": "OPERATOR_ID",
                "production_id": None,
                "defect_categories": "",
                "extra_data": "",
                "file_path": file_path,
            }
            global_state.xml_index.setdefault(modulo_id, []).append(entry)
        except Exception as e:
            logging.warning(f"Skipping invalid XML file name: {file_path} — {e}")

def get_mbj_events_for_modulo(modulo_id: str):
    return global_state.xml_index.get(modulo_id, [])
