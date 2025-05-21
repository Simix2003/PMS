from fastapi import APIRouter, BackgroundTasks, Body, HTTPException
from fastapi.responses import JSONResponse, FileResponse
from typing import List, Dict
import logging, os, sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.helpers.export import EXPORT_DIR, clean_old_exports, export_full_excel
from service.config.settings import load_settings
from service.connections.mysql import get_mysql_connection

router = APIRouter()

# ---------------------------------------------------------------------------
#  EXPORT END‑POINT – NOW TAKES object_ids  (id_modulo strings OR object.id int)
# ---------------------------------------------------------------------------
@router.post("/api/export_objects")
def export_objects(background_tasks: BackgroundTasks, data: dict = Body(...)):
    object_ids: List[str] = data.get("object_ids", [])
    filters: List[Dict] = data.get("filters", [])

    if not object_ids:
        return {"status": "ok", "filename": None}

    conn = get_mysql_connection()
    if not conn:
        return JSONResponse(status_code=500,
                            content={"error": "MySQL connection not available"})

    try:
        export_data = {
            "filters": filters,
            "objects": [],
            "productions": [],
            "stations": [],
            "production_lines": [],
            "object_defects": [],
        }

        settings = load_settings()
        export_data["min_cycle_threshold"] = settings.get("min_cycle_threshold", 3.0)

        with conn.cursor() as cursor:
            # ---- Reference tables ----
            cursor.execute("SELECT * FROM stations")
            export_data["stations"] = cursor.fetchall()

            cursor.execute("SELECT * FROM production_lines")
            export_data["production_lines"] = cursor.fetchall()

            # ---- 1. OBJECTS ----
            modulo_ids = [oid for oid in object_ids if not str(oid).isdigit()]
            int_ids = [int(oid) for oid in object_ids if str(oid).isdigit()]

            clauses = []
            params = []

            if int_ids:
                fmt = ",".join(["%s"] * len(int_ids))
                clauses.append(f"id IN ({fmt})")
                params.extend(int_ids)

            if modulo_ids:
                fmt = ",".join(["%s"] * len(modulo_ids))
                clauses.append(f"id_modulo IN ({fmt})")
                params.extend(modulo_ids)

            where_clause = " OR ".join(clauses)

            cursor.execute(
                f"SELECT * FROM objects WHERE {where_clause}",
                tuple(params),
            )
            objects = cursor.fetchall()
            if not objects:
                return {"status": "ok", "filename": None}

            export_data["objects"] = objects
            export_data["id_moduli"] = [o["id_modulo"] for o in objects]
            object_pk_ids = [o["id"] for o in objects]

            # ---- 2. PRODUCTIONS ----
            fmt = ",".join(["%s"] * len(object_pk_ids))
            cursor.execute(
                f"SELECT * FROM productions WHERE object_id IN ({fmt})",
                tuple(object_pk_ids),
            )
            productions = cursor.fetchall()
            export_data["productions"] = productions

            # ---- 3. DEFECTS ----
            production_pk_ids = [p["id"] for p in productions]
            if production_pk_ids:
                fmt = ",".join(["%s"] * len(production_pk_ids))
                cursor.execute(
                    f"""
                    SELECT od.*, d.category
                    FROM object_defects od
                    JOIN defects d ON od.defect_id = d.id
                    WHERE od.production_id IN ({fmt})
                    """,
                    tuple(production_pk_ids),
                )
                defects = cursor.fetchall()
            else:
                defects = []

            # ---- 4. Apply defect filters if present ----
            for f in filters:
                if f.get("type") == "Difetto":
                    raw_value = f.get("value", "").lower()

                    value = raw_value.split(">")[0].strip()  # Prendi solo "Macchie ECA"

                    filtered = []
                    for d in defects:
                        category = d.get("category", "").lower()
                        if value in category:
                            filtered.append(d)

                    defects = filtered

            export_data["object_defects"] = defects

    except Exception as e:
        logging.error(f"❌ Error during export: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})

    # ---- Final export ----
    filename = export_full_excel(export_data)
    background_tasks.add_task(clean_old_exports, max_age_hours=2)

    return {"status": "ok", "filename": filename}


# ---------------------------------------------------------------------------
#  Download
# ---------------------------------------------------------------------------
@router.get("/api/download_export/{filename}")
def download_export(filename: str):
    filepath = os.path.join(EXPORT_DIR, filename)
    if os.path.exists(filepath):
        return FileResponse(
            filepath,
            filename=filename,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
    raise HTTPException(status_code=404, detail="File not found")
