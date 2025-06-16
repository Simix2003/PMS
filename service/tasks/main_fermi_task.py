import asyncio
from datetime import datetime
import logging

import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import create_stop, get_mysql_connection
from service.controllers.plc import PLCConnection
from service.helpers.helpers import get_channel_config
from service.config.config import PLC_DB_RANGES, debug
from service.helpers.buffer_plc_extract import extract_bool, extract_string, extract_int, extract_DT

async def fermi_task(plc_connection: PLCConnection, full_station_id: str):
    print(f"[{full_station_id}] Starting fermi task.")
    prev_trigger = False
    clock = False

    line_name, channel_id = full_station_id.split(".")

    while True:
        try:
            # Ensure connection is alive or try reconnect
            if not plc_connection.connected or not plc_connection.is_connected():
                print(f"⚠️ PLC disconnected for {full_station_id} in Fermi_task, attempting reconnect...")
                await asyncio.to_thread(plc_connection.reconnect, retries=3, delay=5)
                await asyncio.sleep(10)
                continue

            paths = get_channel_config(line_name, channel_id)
            if not paths:
                logging.error(f"❌ FERMI Invalid line/channel: {line_name}.{channel_id}")
                await asyncio.sleep(1)
                continue

            trigger_conf = paths.get("dati_pronti_fermi")
            if not trigger_conf:
                logging.warning(f"⚠️ Missing 'dati_pronti_fermi' config for {full_station_id}")
                await asyncio.sleep(1)
                continue

            # Get full DB buffer once for this PLC
            plc_key = (plc_connection.ip_address, plc_connection.slot)
            db = trigger_conf["db"]

            db_range = PLC_DB_RANGES.get(plc_key, {}).get(db)
            if not db_range:
                logging.error(f"❌ No DB range defined for {plc_key} DB{db}")
                await asyncio.sleep(1)
                continue

            start_byte = db_range["min"]
            size = db_range["max"] - db_range["min"] + 1

            # Read full DB buffer
            buffer = await asyncio.to_thread(plc_connection.db_read, db, start_byte, size)

            # Validate if trigger exists
            trigger_value = extract_bool(buffer, trigger_conf["byte"], trigger_conf["bit"], start_byte)

            if trigger_value is None:
                raise Exception("Trigger read returned None")

            if trigger_value != prev_trigger:
                prev_trigger = trigger_value
                await fermi_trigger_change(
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

            #WRITE CLOCK
            clock_conf = paths.get("keepLive_fermi_PC")
            if clock_conf:
                newClock = not clock
                clock = newClock
                await asyncio.to_thread(plc_connection.write_bool, clock_conf["db"], clock_conf["byte"], clock_conf["bit"], newClock)
            
            await asyncio.sleep(1)

        except Exception as e:
            logging.error(f"[{full_station_id}] 🔴 Error in FERMI task: {str(e)}")
            await asyncio.to_thread(plc_connection.reconnect, retries=3, delay=5)
            await asyncio.sleep(5)

async def fermi_trigger_change(plc_connection: PLCConnection, line_name: str, channel_id: str, val, buffer: bytes | None = None, start_byte: int | None = None):
    if not isinstance(val, bool):
        return

    full_id = f"{line_name}.{channel_id}"
    paths = get_channel_config(line_name, channel_id)
    if not paths:
        print(f"❌ Config not found for {full_id}")
        return

    if val:
        print(f"🟢 Dati Pronti FERMI on {full_id} TRUE ...")
        # leggere i dati:
        data = await read_fermi_data(plc_connection, line_name, channel_id, buffer=buffer, start_byte=start_byte)
        print('Data read for Fermi: %s' % data)
        
        # Salvare i dati su MySQL
        conn = get_mysql_connection()
        print('will save in database')
        await insert_fermo_data(data, conn)

        try:
            zone = "AIN"  # TODO: derive dynamically from MySQL if needed
            #update_fermi_visual_data(
            #    zone=zone,
            #    station_name=channel_id,
            #    esito=final_esito,
            #    ts=timestamp
            #    )
            
            print('Will update visual Data')
            #print(f"📡 Called update_fermi_visual_data ✅")

        except Exception as vis_err:
            logging.warning(f"⚠️ Could not update FERMI_visual_data for {channel_id}: {vis_err}")
        
        # poi quando leggo scrivo Dati Letti fermi a TRUE
        dati_letti_conf = paths.get("dati_letti_fermi")
        if dati_letti_conf and not debug:
            await asyncio.to_thread(plc_connection.write_bool, dati_letti_conf["db"], dati_letti_conf["byte"], dati_letti_conf["bit"], True)

    else:
        print(f"🟢 Dati Pronti FERMI on {full_id} FALSE ...")
        # METTERE A ZERO DATI LETTI
        dati_letti_conf = paths.get("dati_letti_fermi")
        if dati_letti_conf and not debug:
            await asyncio.to_thread(plc_connection.write_bool, dati_letti_conf["db"], dati_letti_conf["byte"], dati_letti_conf["bit"], False)

async def read_fermi_data(
    plc_connection: PLCConnection,
    line_name: str,
    channel_id: str,
    buffer: bytes | None = None,
    start_byte: int | None = None
):
    full_id = f"{line_name}.{channel_id}"

    try:
        # Step 1: Validate buffer and start_byte
        if buffer is None or start_byte is None:
            logging.error(f"[{full_id}] ❌ Cannot proceed: buffer or start_byte is None")
            return None

        # Step 2: Load config
        config = get_channel_config(line_name, channel_id)
        if config is None:
            logging.error(f"[{full_id}] ❌ Missing config for line/channel")
            return None

        data = {}

        # Read Id_Utente
        id_utente_conf = config.get("id_utente_fermi")
        if id_utente_conf:
            data["Id_Utente"] = extract_string(buffer, id_utente_conf["byte"], id_utente_conf["length"], start_byte) or ""
        else:
            data["Id_Utente"] = ""

        data_inizio_conf = config.get("inizio_fermo")
        if data_inizio_conf:
            data["DataInizio"] = extract_DT(buffer, data_inizio_conf["byte"], start_byte)
        else:
            data["DataInizio"] = None

        data_fine_conf = config.get("fine_fermo")
        if data_fine_conf:
            data["DataFine"] = extract_DT(buffer, data_fine_conf["byte"], start_byte)
        else:
            data["DataFine"] = None

        evento_conf = config.get("evento_fermo")
        if evento_conf:
            data["Evento_Fermo"] = extract_int(buffer, evento_conf["byte"], start_byte)
        else:
            data["Evento_Fermo"] = 0

        stazione_conf = config.get("stazione_fermo")
        if stazione_conf:
            data["Stazione_Fermo"] = extract_int(buffer, stazione_conf["byte"], start_byte)
        else:
            data["Stazione_Fermo"] = 0

        return data

    except Exception as e:
        logging.error(f"[{full_id}] ❌ Error reading PLC data: {e}")
        print(f"[{full_id}] ❌ EXCEPTION in read_fermi_data: {e}")
        return None

async def insert_fermo_data(data, conn):
    reason = "Fermo Generico"
    if data["Evento_Fermo"] == 1:
        reason = "Cancelli Aperti"
    elif data["Evento_Fermo"] == 3:
        reason = "Anomalia"
    elif data["Evento_Fermo"] == 4:
        reason = "Ciclo non Automatico"
    elif data["Evento_Fermo"] == 6:
        reason = "Fuori Tempo Ciclo"
    elif data["Evento_Fermo"] == 7:
        reason = "Mancato Carico"
    elif data["Evento_Fermo"] == 8:
        reason = "Mancato Scarico"
    elif data["Evento_Fermo"] == 9:
        reason = "Carico Materiali"

    stop_id = create_stop(
            station_id = data["Stazione_Fermo"],
            start_time = data["DataInizio"],
            end_time = data["DataFine"],
            operator_id = data["Id_Utente"],
            stop_type = "STOP",
            reason = reason,
            status = "CLOSED",
            linked_production_id =None,
            conn = conn
        )
    
    print(f"Added FERMO stop_id={stop_id}")