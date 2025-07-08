import asyncio
from datetime import datetime
import logging

import os
import sys
from typing import Optional

from requests import get

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection, insert_defects, insert_initial_production_data, update_production_final
from service.connections.temp_data import remove_temp_issues
from service.controllers.plc import PLCConnection
from service.helpers.helpers import get_channel_config
from service.config.config import PLC_DB_RANGES, ZONE_SOURCES, debug
from service.routes.broadcast import broadcast
from service.state.global_state import passato_flags, trigger_timestamps, incomplete_productions
import service.state.global_state as global_state
from service.helpers.buffer_plc_extract import extract_bool, extract_s7_string, extract_string
from service.helpers.visual_helper import refresh_top_defects_qg2, refresh_top_defects_vpf, refresh_vpf_defects_data, update_visual_data_on_new_module
from service.routes.mbj_routes import parse_mbj_details

logger = logging.getLogger(__name__)

def get_zone_from_station(station: str) -> Optional[str]:
    for zone, cfg in ZONE_SOURCES.items():
        if station in (
            cfg.get("station_1_in", []) +
            cfg.get("station_2_in", []) +
            cfg.get("station_1_out_ng", []) +
            cfg.get("station_2_out_ng", [])
        ):
            return zone
    return None

async def background_task(plc_connection: PLCConnection, full_station_id: str):
    logger.info(f"[{full_station_id}] Starting background task.")
    prev_trigger = False

    line_name, channel_id = full_station_id.split(".")

    while True:
        try:
            # Ensure connection is alive or try reconnect
            if not plc_connection.connected or not plc_connection.is_connected():
                logger.warning(f"PLC disconnected for {full_station_id}, attempting reconnect...")
                await asyncio.to_thread(plc_connection.reconnect, retries=3, delay=5)
                await asyncio.sleep(10)
                continue  # Retry after delay

            paths = get_channel_config(line_name, channel_id)
            if not paths:
                logger.error(f"Invalid line/channel: {line_name}.{channel_id}")
                await asyncio.sleep(1)
                continue  # Skip this cycle if config not found

            # Get full DB buffer once for this PLC
            plc_key = (plc_connection.ip_address, plc_connection.slot)
            db = paths["trigger"]["db"]  # assuming all signals use same DB

            db_range = PLC_DB_RANGES.get(plc_key, {}).get(db)
            if not db_range:
                logger.error(f"No DB range defined for {plc_key} DB{db}")
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
                logger.error(f"Missing config for {line_name}.{channel_id}")
                await asyncio.sleep(1)
                continue  # Or return / skip, depending on context

            # Now you're safe to use it:
            fb_conf = paths["fine_buona"]
            fs_conf = paths["fine_scarto"]
            if debug:
                # fallback to trigger flag if specific G/NG not enabled
                force_ng = global_state.debug_trigger_NG.get(full_station_id, False)
                force_g  = global_state.debug_trigger_G.get(full_station_id, False)

                if force_g:
                    fine_buona = True
                    fine_scarto = False
                elif force_ng:
                    fine_buona = False
                    fine_scarto = True
                else:
                    fine_buona = False
                    fine_scarto = False
            else:
                #fine_buona = await asyncio.to_thread(plc_connection.read_bool, fb_conf["db"], fb_conf["byte"], fb_conf["bit"])
                #fine_scarto = await asyncio.to_thread(plc_connection.read_bool, fs_conf["db"], fs_conf["byte"], fs_conf["bit"])
                fine_buona = extract_bool(buffer, fb_conf["byte"], fb_conf["bit"], start_byte)
                fine_scarto = extract_bool(buffer, fs_conf["byte"], fs_conf["bit"], start_byte)

            if fine_buona is None or fine_scarto is None:
                raise Exception("Outcome read returned None")

            if (fine_buona or fine_scarto) and not passato_flags[full_station_id]:
                data_inizio = trigger_timestamps.get(full_station_id)
                bufferIds = []
                result = await read_data(plc_connection, line_name, channel_id,
                                        richiesta_ok=fine_buona,
                                        richiesta_ko=fine_scarto,
                                        data_inizio=data_inizio, 
                                        buffer=buffer, 
                                        start_byte=start_byte,
                                        )
                
                if result:
                    bufferIds = result.get("BufferIds_Rework", [])
                    passato_flags[full_station_id] = True
                    production_id = incomplete_productions.get(full_station_id)
                    
                    if production_id:
                        conn = get_mysql_connection()
                        success, final_esito, end_time = await update_production_final(
                            production_id, result, channel_id, conn, fine_buona, fine_scarto
                        )
                        if success and channel_id == "VPF01" and fine_scarto and result.get("Tipo_NG_VPF"):
                            await insert_defects(result, production_id, channel_id, line_name, cursor=conn.cursor(), from_vpf=True)
                            assert end_time and final_esito is not None
                            timestamp = end_time if isinstance(end_time, datetime) else datetime.fromisoformat(end_time)
                            
                            refresh_top_defects_vpf("AIN", timestamp)
                            refresh_vpf_defects_data(timestamp)
                        
                        if success and channel_id == "ELL01" and fine_scarto:
                            assert end_time and final_esito is not None
                            await insert_defects(result, production_id, channel_id, line_name, cursor=conn.cursor(), from_ell=True)
                        
                        if success and channel_id in ("AIN01", "AIN02") and fine_scarto and result.get("Tipo_NG_AIN"):
                            await insert_defects(result, production_id, channel_id, line_name, cursor=conn.cursor(), from_ain=True)

                        if success:
                            try:
                                zone = get_zone_from_station(channel_id)
                                assert end_time and final_esito is not None

                                timestamp = end_time if isinstance(end_time, datetime) else datetime.fromisoformat(end_time)
                                if channel_id == "VPF01":
                                    reentered = bool(result.get("Re_entered_from_m506", False))
                                elif channel_id == "ELL01":
                                    reentered = bool(result.get("Re_entered_from_m326", False))
                                else:
                                    reentered = False

                                if zone:
                                    update_visual_data_on_new_module(
                                        zone=zone,
                                        station_name=channel_id,
                                        esito=final_esito,
                                        ts=timestamp,
                                        cycle_time=result['Tempo_Ciclo'],
                                        reentered=reentered,
                                        bufferIds=bufferIds
                                    )

                                    if zone == "AIN" and fine_scarto:
                                        refresh_top_defects_qg2(zone, timestamp)

                                    logger.debug(f"Called update_visual_data_on_new_module ✅")
                                else:
                                    logger.warning(f"Unknown zone for station {channel_id} — skipping visual update")

                            except Exception as vis_err:
                                logger.warning(f"Could not update visual_data for {channel_id}: {vis_err}")

                            incomplete_productions.pop(full_station_id)

                            esito_conf = paths.get("esito_scarto_compilato")
                            pezzo_conf = paths["pezzo_salvato_su_DB_con_inizio_ciclo"]
                            
                            await asyncio.to_thread(plc_connection.write_bool, fb_conf["db"], fb_conf["byte"], fb_conf["bit"], False)
                            await asyncio.to_thread(plc_connection.write_bool, fs_conf["db"], fs_conf["byte"], fs_conf["bit"], False)
                            await asyncio.to_thread(plc_connection.write_bool, trigger_conf["db"], trigger_conf["byte"], trigger_conf["bit"], False)
                            await asyncio.to_thread(plc_connection.write_bool, pezzo_conf["db"], pezzo_conf["byte"], pezzo_conf["bit"], False)
                            if esito_conf:
                                await asyncio.to_thread(plc_connection.write_bool, esito_conf["db"], esito_conf["byte"], esito_conf["bit"], False)
                            
                        else:
                            logger.error(f"Failed to update production in DB, skipping visual update.")
                    else:
                        logger.warning(f"No initial production record found for {full_station_id}; skipping update.")
                    remove_temp_issues(line_name, channel_id, result.get("Id_Modulo"))

            await asyncio.sleep(1)

        except Exception as e:
            logger.error(f"[{full_station_id}], Error in background task: {str(e)}")
            await asyncio.to_thread(plc_connection.reconnect, retries=3, delay=5)
            await asyncio.sleep(5)

async def on_trigger_change(plc_connection: PLCConnection, line_name: str, channel_id: str, val, buffer: bytes | None = None, start_byte: int | None = None):
    if not isinstance(val, bool):
        return

    full_id = f"{line_name}.{channel_id}"
    paths = get_channel_config(line_name, channel_id)
    if not paths:
        logger.warning(f"Config not found for {full_id}")
        return

    if val:
        logger.info(f"Inizio Ciclo on {full_id} TRUE ...")
        trigger_timestamps.pop(full_id, None)

        # Write FALSE to esito_scarto_compilato.
        esito_conf = paths.get("esito_scarto_compilato")
        if esito_conf:
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
        if esito_conf:
            issues_value = extract_bool(buffer, esito_conf["byte"], esito_conf["bit"], start_byte)
            issues_submitted = issues_value is True
        else:
            issues_submitted = False

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
        if not debug:
            await asyncio.to_thread(plc_connection.write_bool, pezzo_conf["db"], pezzo_conf["byte"], pezzo_conf["bit"], True)

        await broadcast(line_name, channel_id, {
            "trigger": True,
            "objectId": object_id,
            "stringatrice": stringatrice,
            "outcome": None,
            "issuesSubmitted": issues_submitted
        })

    else:
        logger.debug(f"Inizio Ciclo on {full_id} FALSE ...")
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
            logger.error(f"[{full_id}], Cannot proceed: buffer or start_byte is None")
            return None

        # Step 2: Validate data_inizio
        if data_inizio is None or not isinstance(data_inizio, datetime):
            logger.warning(f"[{full_id}], data_inizio was None or invalid; using current time instead")
            data_inizio = datetime.now()

        # Step 3: Load config
        config = get_channel_config(line_name, channel_id)
        if config is None:
            logger.error(f"[{full_id}], Missing config for line/channel")
            return None

        data = {}

        # Step 4: Read Id_Modulo
        id_mod_conf = config["id_modulo"]
        if debug:
            data["Id_Modulo"] = global_state.debug_moduli.get(full_id) or ""
        else:
            data["Id_Modulo"] = extract_string(buffer, id_mod_conf["byte"], id_mod_conf["length"], start_byte) or ""
        if not data["Id_Modulo"]:
            logger.warning(f"[{full_id}], Id_Modulo is empty or unreadable")

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

        # Step 9: Read Defect NG for VPF BYTE48
        vpf_values_1 = []
        vpf_conf = config.get("difetti_vpf_1")
        if vpf_conf and richiesta_ko and channel_id == "VPF01":
            vpf_values_1 = [
                extract_bool(buffer, vpf_conf["byte"], i, start_byte)
                for i in range(vpf_conf["length"])
            ]

        # Step 10: Read Defect NG for VPF BYTE49
        vpf_values_2 = []
        vpf_conf = config.get("difetti_vpf_2")
        if vpf_conf and richiesta_ko and channel_id == "VPF01":
            vpf_values_2 = [
                extract_bool(buffer, vpf_conf["byte"], i, start_byte)
                for i in range(vpf_conf["length"])
            ]

        # ✅ COMBINE VPF DEFECTS
        combined_vpf_values = vpf_values_1 + vpf_values_2
        if combined_vpf_values:
            data["Tipo_NG_VPF"] = combined_vpf_values
            logger.debug(f"[{full_id}], VPF Defect flags: {combined_vpf_values}")
        
        # Get the re-entered flag for VPF
        re_entered_conf506 = config.get("re_entered_from_m506")
        if re_entered_conf506 and channel_id == "VPF01":
            reentered = extract_bool(buffer, re_entered_conf506["byte"], re_entered_conf506["bit"], start_byte)
            data["Re_entered_from_m506"] = reentered

        # Get the re-entered flag for ELL
        re_entered_conf326 = config.get("re_entered_from_m326")
        if re_entered_conf326 and channel_id == "ELL01":
            reentered = extract_bool(buffer, re_entered_conf326["byte"], re_entered_conf326["bit"], start_byte)
            data["Re_entered_from_m326"] = reentered

        # Override with debug flag if present
        if debug:
            full_station_id = f"{line_name}.{channel_id}"
            reentrydebug = global_state.reentryDebug.get(full_station_id)
            if reentrydebug is not None:
                data["Re_entered_from_m326"] = reentrydebug

        # Step 11: Read Defect NG for AIN                
        ain_conf = config.get("difetti_ain")
        if ain_conf and richiesta_ko and channel_id in ("AIN01", "AIN02"):
            all_ain_values = [
                extract_bool(buffer, ain_conf["byte"], i, start_byte)
                for i in range(ain_conf["length"])
            ]
            # Take only 4th and 5th bits (index 3 and 4)
            data["Tipo_NG_AIN"] = all_ain_values[3:5]
            logger.debug(f"[{full_id}], AIN Defect flags (bit 4 & 5): {data['Tipo_NG_AIN']}")


        # Step 12: Set NG flag
        data["Compilato_Su_Ipad_Scarto_Presente"] = richiesta_ko

        if channel_id == "ELL01" and richiesta_ko:
            mbj_details = parse_mbj_details(data["Id_Modulo"])
            if mbj_details:
                data['MBJ_Defects'] = mbj_details
            else:
                logger.debug(f"[{full_id}] No MBJ XML found for {data['Id_Modulo']} — continuing without it")

        # Step 13: Read the BufferIds for Rework (array of 21 strings)
        rwk_id = config.get("reWorkBufferIds")
        values = []

        if rwk_id and not debug:
            db_number = rwk_id["db"]
            base_byte = rwk_id["byte"]
            num_strings = rwk_id["length"]
            string_len = rwk_id.get("string_length", 20)
            string_size = string_len + 2  # fixed size for S7 STRING[20]

            total_bytes = num_strings * string_size

            # ✅ Read the correct DB block directly
            rwk_buffer = await asyncio.to_thread(plc_connection.db_read, db_number, base_byte, total_bytes)

            values = [
                extract_s7_string(rwk_buffer, i * string_size)
                for i in range(num_strings)
            ]
        elif debug:
            values = ["3SBHBGHC25620697", "3SBHBGHC25614686", "3SBHBGHC25620697"]

        data["BufferIds_Rework"] = values

        return data

    except Exception as e:
        logger.error(f"[{full_id}], Error reading PLC data: {e}")
        return None

def make_status_callback(full_station_id: str):
    async def callback(status):
        try:
            line_name, channel_id = full_station_id.split(".")
            await broadcast(line_name, channel_id, {"plc_status": status})
        except Exception as e:
            logger.error(f"Failed to send PLC status for {full_station_id}: {e}")
    return callback