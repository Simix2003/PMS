import asyncio
from datetime import datetime
import logging

import os
import sys



sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import create_stop, get_mysql_connection
from service.controllers.plc import PLCConnection
from service.helpers.helpers import get_channel_config
from service.config.config import CHANNELS, PLC_DB_RANGES, debug
from service.helpers.buffer_plc_extract import extract_bool, extract_string, extract_int, extract_DT
from service.helpers.visual_helper import refresh_fermi_data

async def fermi_task(plc_connection: PLCConnection, ip: str, slot: int):
    print(f"[{ip}:{slot}] Starting fermi task.")

    # Find all stations connected to this PLC
    stations_to_monitor = []
    for line_name, stations in CHANNELS.items():
        for channel_id, config in stations.items():
            plc_info = config.get("plc")
            if not plc_info:
                continue

            if plc_info.get("ip") == ip and plc_info.get("slot", 0) == slot:
                stations_to_monitor.append((line_name, channel_id, config))

    if not stations_to_monitor:
        logging.warning(f"⚠️ No stations found for PLC {ip}:{slot}")
        return

    # Extract the unique clock_conf from first valid station
    clock_conf = None
    for _, _, paths in stations_to_monitor:
        clock_conf_candidate = paths.get("keepLive_fermi_PC")
        if clock_conf_candidate:
            clock_conf = clock_conf_candidate
            break

    if not clock_conf:
        logging.warning(f"⚠️ No keepLive_fermi_PC config found for PLC {ip}:{slot}")

    # Create state tracking per station
    prev_triggers = { (line, channel): False for (line, channel, _) in stations_to_monitor }

    # Create single PLC-wide clock state
    clock = False

    while True:
        try:
            if not plc_connection.connected or not plc_connection.is_connected():
                print(f"⚠️ PLC disconnected for {ip}:{slot} in Fermi_task, attempting reconnect...")
                await asyncio.to_thread(plc_connection.reconnect, retries=3, delay=5)
                await asyncio.sleep(10)
                continue

            for line_name, channel_id, paths in stations_to_monitor:
                trigger_conf = paths.get("dati_pronti_fermi")
                if not trigger_conf:
                    continue

                plc_key = (plc_connection.ip_address, plc_connection.slot)
                db = trigger_conf["db"]

                db_range = PLC_DB_RANGES.get(plc_key, {}).get(db)
                if not db_range:
                    logging.error(f"❌ No DB range defined for {plc_key} DB{db}")
                    continue

                start_byte = db_range["min"]
                size = db_range["max"] - db_range["min"] + 1

                buffer = await asyncio.to_thread(plc_connection.db_read, db, start_byte, size)

                trigger_value = extract_bool(buffer, trigger_conf["byte"], trigger_conf["bit"], start_byte)

                if trigger_value is None:
                    raise Exception("Trigger read returned None")

                if trigger_value != prev_triggers[(line_name, channel_id)]:
                    prev_triggers[(line_name, channel_id)] = trigger_value
                    await fermi_trigger_change(
                        plc_connection,
                        line_name,
                        channel_id,
                        trigger_value,
                        buffer,
                        start_byte
                    )

            # 🔧 WRITE CLOCK once per PLC cycle
            if clock_conf and not debug:
                new_clock = not clock
                clock = new_clock
                await asyncio.to_thread(
                    plc_connection.write_bool, 
                    clock_conf["db"], 
                    clock_conf["byte"], 
                    clock_conf["bit"], 
                    new_clock
                )

            await asyncio.sleep(1)

        except Exception as e:
            logging.error(f"[{ip}:{slot}] 🔴 Error in FERMI task: {str(e)}")
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
        data = await read_fermi_data(plc_connection, line_name, channel_id)
        
        # Salvare i dati su MySQL
        conn = get_mysql_connection()
        await insert_fermo_data(data, conn)

        try:
            zone = "AIN"  # TODO: derive dynamically from MySQL if needed

            timestamp = data["DataInizio"] if data and data.get("DataInizio") else datetime.now()
            refresh_fermi_data(zone, timestamp)

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
    channel_id: str
):
    full_id = f"{line_name}.{channel_id}"

    try:
        config = get_channel_config(line_name, channel_id)
        if config is None:
            logging.error(f"[{full_id}] ❌ Missing config for line/channel")
            return None

        # 1️⃣ Collect all DBs we need to read
        dbs_needed = set()
        fields = ["id_utente_fermi", "inizio_fermo", "fine_fermo", "evento_fermo", "stazione_fermo"]

        for field in fields:
            conf = config.get(field)
            if conf and "db" in conf:
                dbs_needed.add(conf["db"])

        # 2️⃣ Read all needed DBs
        buffers = {}
        for db in dbs_needed:
            plc_key = (plc_connection.ip_address, plc_connection.slot)
            db_range = PLC_DB_RANGES.get(plc_key, {}).get(db)
            if not db_range:
                logging.error(f"❌ No DB range defined for {plc_key} DB{db}")
                return None

            start_byte = db_range["min"]
            size = db_range["max"] - db_range["min"] + 1
            buffer = await asyncio.to_thread(plc_connection.db_read, db, start_byte, size)
            buffers[db] = (buffer, start_byte)

        # 3️⃣ Parse data from correct buffers
        data = {}

        # Id Utente
        id_utente_conf = config.get("id_utente_fermi")
        if id_utente_conf:
            buf, start = buffers[id_utente_conf["db"]]
            relative_byte = id_utente_conf["byte"] - start
            data["Id_Utente"] = extract_string(buf, relative_byte, id_utente_conf["length"], 0) or ""
        else:
            data["Id_Utente"] = ""

        # Data Inizio
        data_inizio_conf = config.get("inizio_fermo")
        if data_inizio_conf:
            buf, start = buffers[data_inizio_conf["db"]]
            relative_byte = data_inizio_conf["byte"] - start
            data["DataInizio"] = extract_DT(buf, relative_byte, 0)
        else:
            data["DataInizio"] = None

        # Data Fine
        data_fine_conf = config.get("fine_fermo")
        if data_fine_conf:
            buf, start = buffers[data_fine_conf["db"]]
            relative_byte = data_fine_conf["byte"] - start
            data["DataFine"] = extract_DT(buf, relative_byte, 0)
        else:
            data["DataFine"] = None

        # Evento Fermo
        evento_conf = config.get("evento_fermo")
        if evento_conf:
            buf, start = buffers[evento_conf["db"]]
            relative_byte = evento_conf["byte"] - start
            data["Evento_Fermo"] = extract_int(buf, relative_byte, 0)
        else:
            data["Evento_Fermo"] = 0

        # Stazione Fermo
        stazione_conf = config.get("stazione_fermo")
        if stazione_conf:
            buf, start = buffers[stazione_conf["db"]]
            relative_byte = stazione_conf["byte"] - start
            data["Stazione_Fermo"] = extract_int(buf, relative_byte, 0)
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
        reason = "Mancato Carico Particolari"
    elif data["Evento_Fermo"] == 8:
        reason = "Mancato Scarico"
    elif data["Evento_Fermo"] == 9:
        reason = "Mancato Carico"

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