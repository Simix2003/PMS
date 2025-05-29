from datetime import datetime, timedelta
import re
from typing import Dict, List, Optional, Union
from PIL import Image
import base64
import io

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.config import CHANNELS


def compress_base64_to_jpeg_blob(base64_str: str, quality: int = 70) -> bytes:
    try:
        raw = base64.b64decode(base64_str)
        with Image.open(io.BytesIO(raw)) as img:
            if img.mode in ("RGBA", "P"):
                img = img.convert("RGB")

            out_io = io.BytesIO()
            img.save(out_io, format="JPEG", quality=quality, optimize=True)
            return out_io.getvalue()
    except Exception as e:
        print(f"⚠️ Compression failed: {e}")
        return base64.b64decode(base64_str)  # fallback: uncompressed
    
def get_channel_config(line_name: str, channel_id: str):
    return CHANNELS.get(line_name, {}).get(channel_id)

def detect_category(path: str) -> str:
    parts = path.split(".")
    if len(parts) < 5:
        return "Altro"
    category_raw = parts[4]
    if ":" in category_raw:
        category_raw = category_raw.split(":")[0].strip()
    return category_raw

def parse_issue_path(path: str, category: str):
    """
    Returns a dict with fields:
      {
        "defect_type": ...   # For Generali
        "stringa": ...       # For Saldatura, Disallineamento, Macchie ECA, etc.
        "s_ribbon": ...      # For Saldatura (Pin)
        "i_ribbon": ...      # For Disallineamento/Mancanza Ribbon, I_Ribbon Leadwire
        "ribbon_lato": ...   # Possibly 'F','M','B'
      }
    """
    res: Dict[str, Optional[Union[str, int]]] = {
        "defect_type": None,
        "stringa": None,
        "s_ribbon": None,
        "i_ribbon": None,
        "ribbon_lato": None,
        "extra_data": None
    }

    # Split
    parts = path.split(".")

    if category == "Generali":
        # last part might be the actual defect, e.g. "Bad Soldering"
        # path might be: "...Generali.Bad Soldering"
        if len(parts) >= 5:
            res["defect_type"] = parts[-1]  # e.g. "Bad Soldering"
        return res

    elif category == "Saldatura":
        # path e.g. "Dati.Esito.Esito_Scarto.Difetti.Saldatura.Stringa[2].Pin[5].M"
        # Let's parse out 'Stringa[2]' => stringa=2
        # 'Pin[5]' => s_ribbon=5
        # 'M' => ribbon_lato='M'
        # That might be parts[4], parts[5], parts[6]
        # e.g. parts[4]="Stringa[2]", parts[5]="Pin[5]", parts[6]="M"
        str_match = re.search(r"Stringa\[(\d+)\]", path)
        pin_match = re.search(r"Pin\[(\d+)\]", path)
        side_match = re.search(r"\.(F|M|B)$", path)

        if str_match:
            res["stringa"] = int(str_match.group(1))
        if pin_match:
            res["s_ribbon"] = int(pin_match.group(1))
        if side_match:
            res["ribbon_lato"] = side_match.group(1)

    elif category == "Disallineamento":
        # Could be: "...Disallineamento.Stringa[3]" or "...Disallineamento.Ribbon[5].F"
        str_match = re.search(r"Stringa\[(\d+)\]", path)
        if str_match:
            res["stringa"] = int(str_match.group(1))
        else:
            # else check Ribbon
            # e.g. "Disallineamento.Ribbon[5].M"
            rib_match = re.search(r"Ribbon\[(\d+)\]", path)
            side_match = re.search(r"\.(F|M|B)$", path)
            if rib_match:
                res["i_ribbon"] = int(rib_match.group(1))
            if side_match:
                res["ribbon_lato"] = side_match.group(1)

    elif category == "Mancanza Ribbon":
        # e.g. "Mancanza Ribbon.Ribbon[2].B"
        # i_ribbon=2, ribbon_lato='B'
        rib_match = re.search(r"Ribbon\[(\d+)\]", path)
        side_match = re.search(r"\.(F|M|B)$", path)
        if rib_match:
            res["i_ribbon"] = int(rib_match.group(1))
        if side_match:
            res["ribbon_lato"] = side_match.group(1)
    
    elif category == "I_Ribbon Leadwire":
        # e.g. "I_Ribbon Leadwire.Ribbon[2].M"
        # i_ribbon=2, ribbon_lato='M'
        rib_match = re.search(r"Ribbon\[(\d+)\]", path)
        side_match = re.search(r"\.(F|M|B)$", path)
        if rib_match:
            res["i_ribbon"] = int(rib_match.group(1))
        if side_match:
            res["ribbon_lato"] = side_match.group(1)

    elif category == "Macchie ECA":
        # e.g. "Macchie ECA.Stringa[4]"
        str_match = re.search(r"Stringa\[(\d+)\]", path)
        if str_match:
            res["stringa"] = int(str_match.group(1))
    
    elif category == "Bad Soldering":
        # e.g. "Bad Soldering.Stringa[5]"
        str_match = re.search(r"Stringa\[(\d+)\]", path)
        if str_match:
            res["stringa"] = int(str_match.group(1))

    elif category == "Celle Rotte":
        # e.g. "Celle Rotte.Stringa[6]"
        str_match = re.search(r"Stringa\[(\d+)\]", path)
        if str_match:
            res["stringa"] = int(str_match.group(1))

    elif category == "Lunghezza String Ribbon":
        # e.g. "Lunghezza String Ribbon.Stringa[2]"
        str_match = re.search(r"Stringa\[(\d+)\]", path)
        if str_match:
            res["stringa"] = int(str_match.group(1))

    elif category == "Graffio su Cella":
        # e.g. "Graffio su Cella.Stringa[2]"
        str_match = re.search(r"Stringa\[(\d+)\]", path)
        if str_match:
            res["stringa"] = int(str_match.group(1))

    elif category == "Altro":
        # Example: "Dati.Esito.Esito_Scarto.Difetti.Altro: Macchia sulla cella"
        print('ALTRO Path: %s' % path)
        if ":" in path:
            res["extra_data"] = path.split(":", 1)[1].strip()


    return res

def generate_unique_filename(base_path, base_name, extension):
    i = 1
    full_path = os.path.join(base_path, f"{base_name}{extension}")
    while os.path.exists(full_path):
        full_path = os.path.join(base_path, f"{base_name}_{i}{extension}")
        i += 1
    return full_path

def generate_time_buckets(start: datetime, end: datetime, group_by: str) -> List[str]:
    buckets = []
    current = start.replace(minute=0, second=0, microsecond=0)

    if group_by == "hourly":
        delta = timedelta(hours=1)
        fmt = "%Y-%m-%d %H:00:00"
        while current <= end:
            buckets.append(current.strftime(fmt))
            current += delta

    elif group_by == "daily":
        current = current.replace(hour=0)
        delta = timedelta(days=1)
        fmt = "%Y-%m-%d"
        while current <= end:
            buckets.append(current.strftime(fmt))
            current += delta

    elif group_by == "weekly":
        current = current - timedelta(days=current.weekday())
        current = current.replace(hour=0)
        delta = timedelta(weeks=1)
        fmt = "%Y-%m-%d"
        while current <= end:
            buckets.append(current.strftime(fmt))
            current += delta

    elif group_by == "shifts":
        current = datetime(start.year, start.month, start.day)
        while current <= end:
            date_str = current.strftime("%Y-%m-%d")
            for shift in ["T1", "T2", "T3"]:
                buckets.append(f"{date_str} {shift}")
            current += timedelta(days=1)

    else:
        raise ValueError("Invalid group_by")

    return buckets