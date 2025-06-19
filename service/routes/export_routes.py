from fastapi import APIRouter, BackgroundTasks, Body, HTTPException
from fastapi.responses import JSONResponse, FileResponse
from typing import List, Dict
import logging, os, sys, asyncio

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.helpers.export import EXPORT_DIR, clean_old_exports, export_full_excel
from service.routes.broadcast import broadcast_export_progress
from service.config.settings import load_settings
from service.connections.mysql import get_mysql_connection

router = APIRouter()

# ---------------------------------------------------------------------------
#  EXPORT END-POINT – ACCETTA:
#    • modulo_ids     → id_modulo (stringhe) oppure objects.id (int)
#    • production_ids → productions.id (int) quando full_history=False
# ---------------------------------------------------------------------------
@router.post("/api/export_objects")
def export_objects(background_tasks: BackgroundTasks, data: dict = Body(...)):
    # ----------- 1. DATI IN ARRIVO -------------------------------------------------
    filters: List[Dict] = data.get("filters", [])
    object_ids:  List[str] = data.get("modulo_ids", [])        # sempre passati
    production_ids_raw       = data.get("production_ids", [])  # solo se full_history=False
    full_history: bool       = data.get("fullHistory", False)
    progress_id: str | None  = data.get("progressId")

    def send_progress(step: str):
        if not progress_id:
            return
        try:
            loop = asyncio.get_running_loop()
            loop.call_soon_threadsafe(
                lambda: asyncio.create_task(
                    broadcast_export_progress(progress_id, {"step": step})
                )
            )
        except Exception as e:
            logging.warning(f"⚠️ Could not broadcast export progress: {e}")

    # elimina stringhe vuote e deduplica
    object_ids   = [oid for oid in object_ids if str(oid).strip()]
    # cast a int sicuro
    production_ids = [int(pid) for pid in production_ids_raw if str(pid).isdigit()]

    # ───────────────────────────────────────────────────────────────────────────────
    #  Se non abbiamo i parametri minimi richiesti, usciamo subito
    # ───────────────────────────────────────────────────────────────────────────────
    if full_history and not object_ids:
        return {"status": "ok", "filename": None}
    if not full_history and not production_ids:
        return {"status": "ok", "filename": None}

    send_progress("db_connect")

    # ----------- 2. DB CONNECTION --------------------------------------------------
    conn = get_mysql_connection()
    if not conn:
        return JSONResponse(status_code=500,
                            content={"error": "MySQL connection not available"})

    try:
        export_data = {
            "filters":          filters,
            "objects":          [],
            "productions":      [],
            "stations":         [],
            "production_lines": [],
            "object_defects":   [],
        }

        # ▶ impostazioni globali
        settings = load_settings()
        export_data["min_cycle_threshold"] = settings.get("min_cycle_threshold", 3.0)
        export_data["export_mbj_image"] = settings.get("export_mbj_image", True)
        export_data["mbj_fields"] = settings.get("mbj_fields", {})

        with conn.cursor() as cursor:
            # -------- Reference tables ----------
            cursor.execute("SELECT * FROM stations")
            export_data["stations"] = cursor.fetchall()

            cursor.execute("SELECT * FROM production_lines")
            export_data["production_lines"] = cursor.fetchall()

            # -------- 3. OBJECTS -----------------------------------------------------
            modulo_ids = [oid for oid in object_ids if not str(oid).isdigit()]
            int_obj_ids = [int(oid) for oid in object_ids if str(oid).isdigit()]

            clauses, params = [], []
            if int_obj_ids:
                fmt = ",".join(["%s"] * len(int_obj_ids))
                clauses.append(f"id IN ({fmt})")
                params.extend(int_obj_ids)

            if modulo_ids:
                fmt = ",".join(["%s"] * len(modulo_ids))
                clauses.append(f"id_modulo IN ({fmt})")
                params.extend(modulo_ids)

            if clauses:                       # se empty non filtriamo
                where_clause = " OR ".join(clauses)
                cursor.execute(f"SELECT * FROM objects WHERE {where_clause}", tuple(params))
            else:
                cursor.execute("SELECT * FROM objects")   # caso limite

            objects = cursor.fetchall()
            if not objects:
                return {"status": "ok", "filename": None}

            send_progress("objects")

            export_data["objects"]   = objects
            export_data["id_moduli"] = [o["id_modulo"] for o in objects]
            object_pk_ids            = [o["id"] for o in objects]

            # -------- 4. PRODUCTIONS -------------------------------------------------
            productions: List[Dict] = []

            if full_history:
                # 🔵 TUTTA la storia: prendi tutte le produzioni di quei moduli
                if object_pk_ids:
                    fmt = ",".join(["%s"] * len(object_pk_ids))
                    cursor.execute(
                        f"SELECT * FROM productions WHERE object_id IN ({fmt}) ORDER BY object_id, end_time",
                        tuple(object_pk_ids),
                    )
                    productions = list(cursor.fetchall())


            else:
                # 🟢 Solo le righe production_ids che appartengono ai moduli selezionati
                if production_ids and object_pk_ids:
                    fmt_ids  = ",".join(["%s"] * len(production_ids))
                    fmt_objs = ",".join(["%s"] * len(object_pk_ids))
                    cursor.execute(
                        f"""
                        SELECT * FROM productions
                        WHERE id IN ({fmt_ids})
                        AND object_id IN ({fmt_objs})
                        ORDER BY object_id, end_time
                        """,
                        tuple(production_ids) + tuple(object_pk_ids),
                    )

                    productions = list(cursor.fetchall())


                    # se abbiamo trovato produzioni, ricarichiamo gli oggetti esatti (optional)
                    object_pk_ids = list({p["object_id"] for p in productions})
                    if object_pk_ids:
                        fmt = ",".join(["%s"] * len(object_pk_ids))
                        cursor.execute(
                            f"SELECT * FROM objects WHERE id IN ({fmt})",
                            tuple(object_pk_ids),
                        )
                        export_data["objects"]   = cursor.fetchall()
                        export_data["id_moduli"] = [o["id_modulo"] for o in export_data["objects"]]

            export_data["productions"] = productions

            send_progress("productions")

            # -------- 5. DEFECTS -----------------------------------------------------
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

            # ---- 6. Applica filtro Difetto (se presente) ---------------
            for f in filters:
                if f.get("type") == "Difetto":
                    requested = f.get("value", "").split(">")[0].strip().lower()
                    defects = [d for d in defects if requested in d.get("category", "").lower()]

            export_data["object_defects"] = defects

            send_progress("defects")

    except Exception as e:
        logging.error(f"❌ Error during export: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})

    # -------- 7. GENERA EXCEL & PULIZIA -------------------------------------------
    send_progress("excel")
    filename = export_full_excel(export_data, progress_callback=send_progress)
    background_tasks.add_task(clean_old_exports, max_age_hours=2)

    send_progress("done")

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
