import os
import logging

from collections import defaultdict
from statistics import mean
from xml.etree.ElementTree import Element
import glob
from datetime import datetime, timedelta
from xml.etree import ElementTree as ET

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

import service.state.global_state as global_state

def preload_xml_index(xml_folder: str = "C:/IX-Monitor/xml"):
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

def extract_InterconnectionGlassDistance(root):
    # Structure: row_index → {"left": [...], "right": [...]}
    distances_by_row = defaultdict(lambda: {"left": [], "right": []})

    for elem in root.findall(".//InterconnectionGlassDistance"):
        x = elem.findtext("IndexX")
        y = elem.findtext("IndexY")
        dist = elem.findtext("Distance")
        if not (x and y and dist):
            continue

        try:
            row = int(x)
            pos = "left" if y == "0" else "right" if y == "19" else None
            if pos and row in range(6):
                distances_by_row[row][pos].append(float(dist))
        except ValueError:
            continue

    # Build final structured result
    result = {}
    for row in range(6):
        left = distances_by_row[row]["left"]
        right = distances_by_row[row]["right"]

        result[str(row)] = {
            "left": {
                "top": mean(left[:2]) if len(left) >= 2 else None,
                "bottom": mean(left[-2:]) if len(left) >= 2 else None,
            },
            "right": {
                "top": mean(right[:2]) if len(right) >= 2 else None,
                "bottom": mean(right[-2:]) if len(right) >= 2 else None,
            },
        }
    
    return {"interconnection_ribbon": result}

def extract_InterconnectionCellDistance(root: Element) -> dict:
    """
    Returns a structure like
    {
        "0": {"y0": {"top": 1.76, "bottom": 1.77},
              "y9": {"top": 2.11, "bottom": 2.05},
              "y10": {...},
              "y19": {...}},
        "1": { ... },   # rows 1-4
        ...
    }
    Distances are the mean of the first-2 and last-2 values for each (row, IndexY).
    """

    target_ys = {"0": "y0", "9": "y9", "10": "y10", "19": "y19"}
    raw = defaultdict(lambda: defaultdict(list))          # row → pos → list[float]

    for elem in root.findall(".//InterconnectionCellDistance"):
        x = elem.findtext("IndexX")
        y = elem.findtext("IndexY")
        d = elem.findtext("Distance")
        if x is None or y not in target_ys or d is None:
            continue
        try:
            row = int(x)
            if row not in range(6):      # only first 6 rows (0-5)
                continue
            raw[row][target_ys[y]].append(float(d))
        except ValueError:
            continue

    result: dict[str, dict[str, dict[str, float|None]]] = {}
    for row in range(6):
        row_dict = {}
        for key in ("y0", "y9", "y10", "y19"):
            vals = raw[row][key]
            row_dict[key] = {
                "top":    round(mean(vals[:2]), 3)  if len(vals) >= 2 else None,
                "bottom": round(mean(vals[-2:]), 3) if len(vals) >= 2 else None,
            }
        result[str(row)] = row_dict

    return {"interconnection_cell": result}

def extract_RelativeCellPosition(root: ET.Element) -> dict:
    from collections import defaultdict
    from statistics import mean

    horizontal = defaultdict(lambda: defaultdict(list))  # row → col → list[float]
    vertical = defaultdict(lambda: defaultdict(list))    # col → row → list[float]

    for rc in root.findall(".//RelativeCellPosition"):
        x = rc.findtext("IndexX")  # row
        y = rc.findtext("IndexY")  # column
        posX = rc.findtext("PositionsX_mm")
        posY = rc.findtext("PositionsY_mm")

        try:
            assert x is not None and y is not None
            row = int(x)
            col = int(y)
        except (ValueError, TypeError):
            continue

        # ✅ Horizontal gap: vertical line (X == 0), measure Y distance
        if posX is not None and float(posX) == 0.0 and posY is not None:
            if row in range(6) and col in range(20):
                val = float(posY)
                horizontal[row][col].append(val)

        # ✅ Vertical gap: no print for now
        if posY is not None and float(posY) == 0.0 and posX is not None:
            row_above = row - 1
            if row_above in range(5) and col in range(20):
                vertical[col][row_above].append(float(posX))

    def mean_first_last(vals):
        selected = vals[:2] + vals[-2:] if len(vals) >= 2 else []
        return round(mean(selected), 3) if selected else None

    horiz_result = {}
    for row in range(6):
        row_result = []
        for col in range(20):
            values = horizontal[row][col]
            avg = mean_first_last(values)
            row_result.append(avg)
        horiz_result[str(row)] = row_result

    vert_result = {
        str(col): [mean_first_last(vertical[col][row]) for row in range(5)] + [None]
        for col in range(20)
    }

    return {
        "horizontal_cell_mm": horiz_result,
        "vertical_cell_mm": vert_result
    }

def extract_GlassCellDistance(root: ET.Element) -> dict:
    """
    Row-to-glass clearances (mm).

    Row 0  ➜  distance from top glass edge  
    Row 5  ➜  distance from bottom glass edge

    Returns:
    {
        "glass_cell_mm": {
            "top":    [d0 … d19],   # row 0 – first-2 / last-2 mean
            "bottom": [d0 … d19]    # row 5 – first-2 / last-2 mean
        }
    }
    """
    raw_top    = defaultdict(list)   # col → list[float]
    raw_bottom = defaultdict(list)   # col → list[float]

    for g in root.findall(".//GlassCellDistance"):
        rx = g.findtext("IndexX")
        ry = g.findtext("IndexY")
        px = g.findtext("PositionsX")   # we need Y distance → use PositionsY
        py = g.findtext("PositionsY")
        if rx is None or ry is None or px is None:
            continue
        try:
            row = int(rx)
            col = int(ry)
            val = float(px)
            if col not in range(20):
                continue
            if row == 0:
                raw_top[col].append(val)
            elif row == 5:
                raw_bottom[col].append(val)
        except ValueError:
            continue

    def avg(vals: list[float]) -> float | None:
        return round(mean(vals[:2] + vals[-2:]), 3) if len(vals) >= 2 else None

    top_row    = [avg(raw_top[c])    for c in range(20)]
    bottom_row = [avg(raw_bottom[c]) for c in range(20)]

    return {"glass_cell_mm": {"top": top_row, "bottom": bottom_row}}

def extract_CellDefects(root: ET.Element) -> dict:
    """
    Extracts cells with defects from the XML.

    Returns:
    {
        "cell_defects": [
            {"x": 3, "y": 5, "defects": [81]},
            {"x": 4, "y": 2, "defects": [12, 42]},
            ...
        ]
    }
    """
    result = []

    for cell in root.findall(".//CellResult"):
        x = cell.findtext("IndexX")
        y = cell.findtext("IndexY")
        defect_nodes = cell.findall(".//DetectedDefects/DefectArea")

        if not defect_nodes or x is None or y is None:
            continue

        try:
            x = int(x)
            y = int(y)
        except ValueError:
            continue

        defect_ids = []
        for defect in defect_nodes:
            defect_id_text = defect.findtext("DefectTypeID")
            if defect_id_text and defect_id_text.isdigit():
                defect_ids.append(int(defect_id_text))

        if defect_ids:
            result.append({"x": x, "y": y, "defects": defect_ids})

    return {"cell_defects": result}
