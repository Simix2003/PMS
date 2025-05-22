import os
import logging

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

import service.state.global_state as global_state

def preload_xml_index(xml_folder: str = "C:/IX-Monitor/xml"):
    import glob
    from datetime import datetime, timedelta
    from xml.etree import ElementTree as ET

    global_state.xml_index.clear()

    pattern = os.path.join(xml_folder, "*.xml")
    for file_path in glob.glob(pattern):
        try:
            fname = os.path.basename(file_path)
            parts = fname.replace(".xml", "").split("_")
            if len(parts) < 3:
                continue

            modulo_id = parts[0]
            dt = datetime.strptime(parts[1] + parts[2], "%Y%m%d%H%M%S")

            # Check if esito is already in the filename
            if len(parts) > 3 and parts[3].isdigit():
                raw_esito = int(parts[3])
            else:
                # Parse <FinalJudgement> from XML
                try:
                    tree = ET.parse(file_path)
                    root = tree.getroot()
                    judgement = root.findtext(".//FinalJudgement")
                    raw_esito = int(judgement) if judgement and judgement.isdigit() else 10
                except Exception as e:
                    logging.warning(f"Failed to parse FinalJudgement in {file_path}: {e}")
                    raw_esito = 10

                # Map esito here
                esito = 1 if raw_esito == 0 else 6 if raw_esito == 4 else 10

                # Rename file with mapped esito
                new_fname = f"{modulo_id}_{parts[1]}_{parts[2]}_{esito}.xml"
                new_path = os.path.join(xml_folder, new_fname)
                try:
                    os.rename(file_path, new_path)
                    file_path = new_path
                except Exception as e:
                    logging.warning(f"Failed to rename {file_path} → {new_path}: {e}")
            # Map even if esito came from filename
            esito = 1 if raw_esito == 0 else 6 if raw_esito == 4 else raw_esito

            entry = {
                "id_modulo": modulo_id,
                "start_time": dt,
                "end_time": dt + timedelta(minutes=1),
                "station_name": "MBJ",
                "line_display_name": "Linea B",
                "cycle_time": 60.0,
                "esito": esito,
                "operator_id": "OPERATOR_ID",
                "production_id": None,
                "defect_categories": "",
                "extra_data": "",
                "file_path": file_path,
            }

            global_state.xml_index.setdefault(modulo_id, []).append(entry)
        except Exception as e:
            logging.warning(f"Skipping file {file_path}: {e}")

def get_mbj_events_for_modulo(modulo_id: str):
    return global_state.xml_index.get(modulo_id, [])
