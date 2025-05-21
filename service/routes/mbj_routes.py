from fastapi import APIRouter
from fastapi.responses import JSONResponse

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.helpers.mbj_xml import get_mbj_events_for_modulo, preload_xml_index

router = APIRouter()

@router.get("/api/mbj_events/{modulo_id}")
def get_mbj_details(modulo_id: str):
    events = get_mbj_events_for_modulo(modulo_id)
    if not events:
        return JSONResponse(status_code=404, content={"detail": "No MBJ data found"})
    return events[0]

@router.post("/api/reload_xml_index")
def reload_xml_index():
    preload_xml_index("C:/IX-Monitor/xml")
    return {"status": "ok"}
