# service/routes/issue_routes.py

from fastapi import APIRouter, HTTPException, Request, Query
from fastapi.responses import JSONResponse
import asyncio
import logging

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.temp_data import load_temp_data, save_temp_data
from service.connections.mysql import get_mysql_connection, insert_defects, update_esito, check_stringatrice_warnings
from service.helpers.helpers import get_channel_config
from service.state.global_state import plc_connections, incomplete_productions
from service.config.settings import load_settings
from service.config.config import ISSUE_TREE

router = APIRouter()

def get_current_settings():
    return load_settings()

@router.post("/api/set_issues")
async def set_issues(request: Request):
    data = await request.json()
    line_name = data.get("line_name")
    channel_id = data.get("channel_id")
    object_id = data.get("object_id")
    issues = data.get("issues", [])

    if not line_name or not channel_id or not object_id or not issues:
        return JSONResponse(status_code=400, content={"error": "Missing data"})

    full_id = f"{line_name}.{channel_id}"

    existing_data = load_temp_data()
    existing_data.append({
        "line_name": line_name,
        "channel_id": channel_id,
        "object_id": object_id,
        "issues": issues
    })
    save_temp_data(existing_data)

    plc_connection = plc_connections.get(full_id)
    if not plc_connection:
        return JSONResponse(status_code=404, content={"error": f"No PLC connection for {full_id}."})

    paths = get_channel_config(line_name, channel_id)
    if not paths or "esito_scarto_compilato" not in paths:
        return JSONResponse(status_code=404, content={"error": "esito_scarto_compilato not found in mapping"})

    production_id = incomplete_productions.get(full_id)
    if production_id:
        try:
            conn = get_mysql_connection()
            cursor = conn.cursor()

            result = {
                "Id_Modulo": object_id,
                "Compilato_Su_Ipad_Scarto_Presente": True,
                "issues": issues
            }

            await insert_defects(result, production_id, channel_id, line_name, cursor=cursor)
            await update_esito(6, production_id, cursor=cursor, connection=conn)
            conn.commit()
            cursor.close()

            await check_stringatrice_warnings(line_name, conn, get_current_settings())

        except Exception as e:
            get_mysql_connection().rollback()  # ✅ Ensures it's valid even in error path
            logging.error(f"❌ Error inserting defects early for {full_id}: {e}")

    target = paths["esito_scarto_compilato"]
    await asyncio.to_thread(plc_connection.write_bool, target["db"], target["byte"], target["bit"], True)

    return {"status": "ok"}

@router.get("/api/get_issues")
async def get_selected_issues(line_name: str, channel_id: str, object_id: str):
    if not line_name or not channel_id or not object_id:
        return JSONResponse(status_code=400, content={"error": "Missing line_name, channel_id, or object_id"})

    temp_data = load_temp_data()
    matching_entry = next(
        (entry for entry in temp_data
         if entry.get("line_name") == line_name and
            entry.get("channel_id") == channel_id and
            entry.get("object_id") == object_id),
        None
    )
    return {"selected_issues": matching_entry["issues"]} if matching_entry else {"selected_issues": []}

@router.get("/api/issues/{line_name}/{channel_id}")
async def get_issue_tree(
    line_name: str,
    channel_id: str,
    path: str = Query("Dati.Esito.Esito_Scarto.Difetti")
):
    config = get_channel_config(line_name, channel_id)
    if not config:
        return JSONResponse(status_code=404, content={"error": "Invalid line or channel"})

    current_node = ISSUE_TREE
    if path:
        for part in path.split("."):
            current_node = current_node.get(part)
            if current_node is None:
                return JSONResponse(status_code=404, content={"error": f"Path '{path}' not found"})

    items = []
    for name, child in current_node.items():
        item_type = "folder" if child else "leaf"
        items.append({"name": name, "type": item_type})

    return {"items": items}

@router.get("/api/issues/for_object")
async def get_issues_for_object(id_modulo: str):
    try:
        conn = get_mysql_connection
        with conn.cursor() as cursor:
            # 1. Trova l'object_id
            cursor.execute("SELECT id FROM objects WHERE id_modulo = %s", (id_modulo,))
            obj = cursor.fetchone()
            if not obj:
                raise HTTPException(status_code=404, detail="Oggetto non trovato.")

            object_id = obj["id"]
            print('ObjectId: %s' % object_id)

            # 2. Trova l'ultima production associata
            cursor.execute("""
                SELECT id FROM productions 
                WHERE object_id = %s 
                ORDER BY end_time DESC 
                LIMIT 1
            """, (object_id,))
            prod = cursor.fetchone()
            if not prod:
                return []

            production_id = prod["id"]
            print('ProductionId: %s' % production_id)

            # 3. Estrai i difetti associati
            cursor.execute("""
                SELECT d.category, od.defect_type, od.i_ribbon, od.stringa, 
                       od.ribbon_lato, od.s_ribbon, od.extra_data
                FROM object_defects od
                JOIN defects d ON od.defect_id = d.id
                WHERE od.production_id = %s
            """, (production_id,))

            defects = cursor.fetchall()
            print(f'defects: {defects}')
            issue_paths = []

            for row in defects:
                cat = row["category"]

                if cat == "Generali":
                    if row["defect_type"]:
                        issue_paths.append(f"Dati.Esito.Esito_Scarto.Difetti.Generali.{row['defect_type']}")

                elif cat == "Altro":
                    if row["extra_data"]:
                        issue_paths.append(f"Dati.Esito.Esito_Scarto.Difetti.Altro: {row['extra_data']}")

                elif cat == "Saldatura":
                    issue_paths.append(
                        f"Dati.Esito.Esito_Scarto.Difetti.Saldatura.Stringa[{row['stringa']}].Pin[{row['s_ribbon']}].{row['ribbon_lato']}"
                    )

                elif cat == "Disallineamento":
                    if row["stringa"]:
                        issue_paths.append(f"Dati.Esito.Esito_Scarto.Difetti.Disallineamento.Stringa[{row['stringa']}]")
                    elif row["i_ribbon"] and row["ribbon_lato"]:
                        issue_paths.append(
                            f"Dati.Esito.Esito_Scarto.Difetti.Disallineamento.Ribbon[{row['i_ribbon']}].{row['ribbon_lato']}"
                        )

                elif cat == "Mancanza Ribbon":
                    issue_paths.append(
                        f"Dati.Esito.Esito_Scarto.Difetti.Mancanza Ribbon.Ribbon[{row['i_ribbon']}].{row['ribbon_lato']}"
                    )

                elif cat == "I_Ribbon Leadwire":
                    issue_paths.append(
                        f"Dati.Esito.Esito_Scarto.Difetti.I_Ribbon Leadwire.Ribbon[{row['i_ribbon']}].{row['ribbon_lato']}"
                    )

                elif cat in ["Macchie ECA", "Celle Rotte", "Lunghezza String Ribbon", "Graffio su Cella"]:
                    issue_paths.append(
                        f"Dati.Esito.Esito_Scarto.Difetti.{cat}.Stringa[{row['stringa']}]"
                    )
            
            print('Issue Paths: %s' % issue_paths)
            return issue_paths

    except Exception as e:
        logging.error(f"❌ Errore nel recupero dei difetti per id_modulo={id_modulo}: {e}")
        raise HTTPException(status_code=500, detail="Errore nel server.")
