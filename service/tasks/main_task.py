import asyncio
from datetime import datetime
import logging

import os
import sys


sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection, insert_initial_production_data, update_production_final
from service.connections.temp_data import remove_temp_issues
from service.controllers.plc import PLCConnection
from service.helpers.helpers import get_channel_config
from service.config.config import PLC_DB_RANGES, debug
from service.routes.broadcast import broadcast
from service.state.global_state import passato_flags, trigger_timestamps, incomplete_productions
import service.state.global_state as global_state
from service.helpers.buffer_plc_extract import extract_bool, extract_string

async def background_task(plc_connection: PLCConnection, full_station_id: str):
    print(f"[{full_station_id}] Starting background task.")
    prev_trigger = False

    line_name, channel_id = full_station_id.split(".")

    while True:
        try:
            # Ensure connection is alive or try reconnect
            if not plc_connection.connected or not plc_connection.is_connected():
                print(f"⚠️ PLC disconnected for {full_station_id}, attempting reconnect...")
                await asyncio.to_thread(plc_connection.reconnect, retries=3, delay=5)
                await asyncio.sleep(10)
                continue  # Retry after delay

            paths = get_channel_config(line_name, channel_id)
            if not paths:
                logging.error(f"❌ Invalid line/channel: {line_name}.{channel_id}")
                await asyncio.sleep(1)
                continue  # Skip this cycle if config not found

            # Get full DB buffer once for this PLC
            plc_key = (plc_connection.ip_address, plc_connection.slot)
            db = paths["trigger"]["db"]  # assuming all signals use same DB

            db_range = PLC_DB_RANGES.get(plc_key, {}).get(db)
            if not db_range:
                logging.error(f"❌ No DB range defined for {plc_key} DB{db}")
                await asyncio.sleep(1)
                continue

            start_byte = db_range["min"]
            size = db_range["max"] - db_range["min"] + 1

            # Read full DB buffer
            buffer = await asyncio.to_thread(plc_connection.db_read, db, start_byte, size)

            trigger_conf = paths["trigger"]
            if debug:
                trigger_value = global_state.debug_triggers.get(full_station_id, False)
            else:
                #trigger_value = await asyncio.to_thread(
                #    plc_connection.read_bool,
                #    trigger_conf["db"], trigger_conf["byte"], trigger_conf["bit"]
                #)
                trigger_value = extract_bool(buffer, trigger_conf["byte"], trigger_conf["bit"], start_byte)

            if trigger_value is None:
                raise Exception("Trigger read returned None")

            if trigger_value != prev_trigger:
                prev_trigger = trigger_value
                await on_trigger_change(
                    plc_connection,
                    line_name,
                    channel_id,
                    trigger_value,
                    buffer,
                    start_byte
                )

            if not paths:
                logging.error(f"❌ Missing config for {line_name}.{channel_id}")
                await asyncio.sleep(1)
                continue  # Or return / skip, depending on context

            # Now you're safe to use it:
            fb_conf = paths["fine_buona"]
            fs_conf = paths["fine_scarto"]
            if debug:
                fine_buona = False
                fine_scarto = global_state.debug_triggers_fisici.get(full_station_id, False)
            else:
                #fine_buona = await asyncio.to_thread(plc_connection.read_bool, fb_conf["db"], fb_conf["byte"], fb_conf["bit"])
                #fine_scarto = await asyncio.to_thread(plc_connection.read_bool, fs_conf["db"], fs_conf["byte"], fs_conf["bit"])
                fine_buona = extract_bool(buffer, fb_conf["byte"], fb_conf["bit"], start_byte)
                fine_scarto = extract_bool(buffer, fs_conf["byte"], fs_conf["bit"], start_byte)



            if fine_buona is None or fine_scarto is None:
                raise Exception("Outcome read returned None")

            if (fine_buona or fine_scarto) and not passato_flags[full_station_id]:
                data_inizio = trigger_timestamps.get(full_station_id)
                result = await read_data(plc_connection, line_name, channel_id,
                                        richiesta_ok=fine_buona,
                                        richiesta_ko=fine_scarto,
                                        data_inizio=data_inizio, 
                                        buffer=buffer, 
                                        start_byte=start_byte,
                                        )
                
                # 🔍 Read current Id_Modulo again directly from PLC
                id_mod_conf = paths["id_modulo"]
                #current_id_modulo = global_state.debug_moduli.get(full_station_id) if debug else await asyncio.to_thread(
                #    plc_connection.read_string,
                #    id_mod_conf["db"], id_mod_conf["byte"], id_mod_conf["length"]
                #)
                current_id_modulo = extract_string(buffer, id_mod_conf["byte"], id_mod_conf["length"], start_byte)

                expected_id = global_state.expected_moduli.get(full_station_id)

                # 📝 Se c'è una discrepanza tra gli ID Modulo, salvala su file
                if expected_id and current_id_modulo and expected_id != current_id_modulo:
                    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    with open("plc_mismatches.txt", "a") as f:
                        f.write(f"[{now}] {full_station_id}\n")
                        f.write(f"  ⚠️ DISCREPANZA! Atteso: {expected_id}, Letto: {current_id_modulo}\n")
                        f.write(f"  Inizio Ciclo: {data_inizio}, Fine Ciclo: {datetime.now()}\n")
                        f.write(f"  fine_buona: {fine_buona}, fine_scarto: {fine_scarto}\n")
                        f.write("-" * 60 + "\n")

                if result:
                    passato_flags[full_station_id] = True
                    production_id = incomplete_productions.get(full_station_id)
                    if production_id:
                        conn = get_mysql_connection()
                        await update_production_final(production_id, result, channel_id, conn, fine_buona, fine_scarto)
                        ##############await asyncio.to_thread(plc_connection.write_bool, pezzo_conf["db"], pezzo_conf["byte"], pezzo_conf["bit"], False)
                        ##############await asyncio.to_thread(plc_connection.write_bool, fb_conf["db"], fb_conf["byte"], fb_conf["bit"], False)
                        ##############await asyncio.to_thread(plc_connection.write_bool, fs_conf["db"], fs_conf["byte"], fs_conf["bit"], False)
                        incomplete_productions.pop(full_station_id)
                    else:
                        logging.warning(f"⚠️ No initial production record found for {full_station_id}; skipping update.")
                    remove_temp_issues(line_name, channel_id, result.get("Id_Modulo"))

            await asyncio.sleep(1)

        except Exception as e:
            logging.error(f"[{full_station_id}] 🔴 Error in background task: {str(e)}")
            await asyncio.to_thread(plc_connection.reconnect, retries=3, delay=5)
            await asyncio.sleep(5)

async def on_trigger_change(plc_connection: PLCConnection, line_name: str, channel_id: str, val, buffer: bytes | None = None, start_byte: int | None = None):
    if not isinstance(val, bool):
        return

    full_id = f"{line_name}.{channel_id}"
    paths = get_channel_config(line_name, channel_id)
    if not paths:
        print(f"❌ Config not found for {full_id}")
        return

    if val:
        print(f"🟡 Inizio Ciclo on {full_id} TRUE ...")
        trigger_timestamps.pop(full_id, None)

        # Write FALSE to esito_scarto_compilato.
        esito_conf = paths["esito_scarto_compilato"]
        await asyncio.to_thread(plc_connection.write_bool, esito_conf["db"], esito_conf["byte"], esito_conf["bit"], False)

        # Write FALSE to pezzo_salvato_su_DB_con_inizio_ciclo.
        pezzo_conf = paths["pezzo_salvato_su_DB_con_inizio_ciclo"]
        await asyncio.to_thread(plc_connection.write_bool, pezzo_conf["db"], pezzo_conf["byte"], pezzo_conf["bit"], False)

        # Read initial values.
        id_mod_conf = paths["id_modulo"]

        ###############################################################################################################################
        if debug:
            object_id = global_state.debug_moduli.get(full_id)
        else:
            #object_id = await asyncio.to_thread(plc_connection.read_string, id_mod_conf["db"], id_mod_conf["byte"], id_mod_conf["length"])
            object_id = extract_string(buffer, id_mod_conf["byte"], id_mod_conf["length"], start_byte)    
        ###############################################################################################################################

        str_conf = paths["stringatrice"]
        #values = [await asyncio.to_thread(plc_connection.read_bool, str_conf["db"], str_conf["byte"], i) for i in range(str_conf["length"])]
        values = [
            extract_bool(buffer, str_conf["byte"], i, start_byte)
            for i in range(str_conf["length"])
        ]

        if not any(values):
            values[0] = True
        stringatrice_index = values.index(True) + 1
        stringatrice = str(stringatrice_index)

        #issues_value = await asyncio.to_thread(plc_connection.read_bool, esito_conf["db"], esito_conf["byte"], esito_conf["bit"])
        issues_value = extract_bool(buffer, esito_conf["byte"], esito_conf["bit"], start_byte)
        issues_submitted = issues_value is True

        trigger_timestamps[full_id] = datetime.now()

        # Read the initial data from the PLC using read_data.
        data_inizio = trigger_timestamps[full_id]
        initial_data = await read_data(plc_connection, line_name, channel_id, richiesta_ok=False, richiesta_ko=False, data_inizio=data_inizio, buffer=buffer, start_byte=start_byte)
        
        escl_conf = paths.get("stazione_esclusa")
        if escl_conf:
            #esclusione_attiva = await asyncio.to_thread(
            #    plc_connection.read_bool, escl_conf["db"], escl_conf["byte"], escl_conf["bit"]
            #)
            esclusione_attiva = extract_bool(buffer, escl_conf["byte"], escl_conf["bit"], start_byte)
        else:
            esclusione_attiva = False


        esito = 4 if esclusione_attiva else 2
        conn = get_mysql_connection()
        prod_id = await insert_initial_production_data(initial_data, channel_id, conn, esito)
        if prod_id:
            incomplete_productions[full_id] = prod_id

        global_state.expected_moduli[full_id] = object_id

        # Write TRUE to pezzo_salvato_su_DB_con_inizio_ciclo.
        await asyncio.to_thread(plc_connection.write_bool, pezzo_conf["db"], pezzo_conf["byte"], pezzo_conf["bit"], True)

        await broadcast(line_name, channel_id, {
            "trigger": True,
            "objectId": object_id,
            "stringatrice": stringatrice,
            "outcome": None,
            "issuesSubmitted": issues_submitted
        })

    else:
        print(f"🟡 Inizio Ciclo on {full_id} FALSE ...")
        passato_flags[full_id] = False
        await broadcast(line_name, channel_id, {
            "trigger": False,
            "objectId": None,
            "stringatrice": None,
            "outcome": None,
            "issuesSubmitted": False
        })

async def read_data(
    plc_connection: PLCConnection,
    line_name: str,
    channel_id: str,
    richiesta_ko: bool,
    richiesta_ok: bool,
    data_inizio: datetime | None,
    buffer: bytes | None = None,
    start_byte: int | None = None
):
    full_id = f"{line_name}.{channel_id}"

    try:
        # Step 1: Validate buffer and start_byte
        if buffer is None or start_byte is None:
            logging.error(f"[{full_id}] ❌ Cannot proceed: buffer or start_byte is None")
            return None

        # Step 2: Validate data_inizio
        if data_inizio is None or not isinstance(data_inizio, datetime):
            logging.warning(f"[{full_id}] ⚠️ data_inizio was None or invalid; using current time instead")
            data_inizio = datetime.now()

        # Step 3: Load config
        config = get_channel_config(line_name, channel_id)
        if config is None:
            logging.error(f"[{full_id}] ❌ Missing config for line/channel")
            return None

        data = {}

        # Step 4: Read Id_Modulo
        id_mod_conf = config["id_modulo"]
        if debug:
            data["Id_Modulo"] = global_state.debug_moduli.get(full_id) or ""
        else:
            data["Id_Modulo"] = extract_string(buffer, id_mod_conf["byte"], id_mod_conf["length"], start_byte) or ""
        if not data["Id_Modulo"]:
            logging.warning(f"[{full_id}] ⚠️ Id_Modulo is empty or unreadable")

        # Step 5: Read Id_Utente
        id_utente_conf = config["id_utente"]
        data["Id_Utente"] = extract_string(buffer, id_utente_conf["byte"], id_utente_conf["length"], start_byte) or ""

        # Step 6: Timestamps
        data["DataInizio"] = data_inizio
        data["DataFine"] = datetime.now()
        tempo_ciclo = data["DataFine"] - data_inizio
        data["Tempo_Ciclo"] = str(tempo_ciclo)

        # Step 7: Linea flags
        data["Linea_in_Lavorazione"] = [
            line_name == "Linea1",
            line_name == "Linea2",
            line_name == "Linea3",
            line_name == "Linea4",
            line_name == "Linea5"
        ]

        # Step 8: Read Stringatrice flags
        str_conf = config["stringatrice"]
        values = [
            extract_bool(buffer, str_conf["byte"], i, start_byte)
            for i in range(str_conf["length"])
        ]
        if not any(values):
            values[0] = True  # Default fallback
        data["Lavorazione_Eseguita_Su_Stringatrice"] = values

        # Step 9: Set KO flag
        data["Compilato_Su_Ipad_Scarto_Presente"] = richiesta_ko

        return data

    except Exception as e:
        logging.error(f"[{full_id}] ❌ Error reading PLC data: {e}")
        print(f"[{full_id}] ❌ EXCEPTION in read_data: {e}")
        return None

def make_status_callback(full_station_id: str):
    async def callback(status):
        try:
            line_name, channel_id = full_station_id.split(".")
            await broadcast(line_name, channel_id, {"plc_status": status})
        except Exception as e:
            logging.error(f"❌ Failed to send PLC status for {full_station_id}: {e}")
    return callback