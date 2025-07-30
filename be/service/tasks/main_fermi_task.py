import asyncio
from datetime import datetime
import logging

import os
import sys

logger = logging.getLogger(__name__)

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import create_stop, get_mysql_connection
from service.controllers.plc import PLCConnection
from service.helpers.helpers import get_channel_config
from service.config.config import CHANNELS, PLC_DB_RANGES, debug
from service.helpers.buffer_plc_extract import extract_bool, extract_string, extract_int, extract_DT
from service.helpers.visual_helper import refresh_fermi_data
from service.state.global_state import db_write_queue, plc_executor
from service.helpers.executor import run_in_thread


async def fermi_task(plc_connection: PLCConnection, ip: str, slot: int):
    logger.debug(f"[{ip}:{slot}] Starting fermi task.")

    # Find all stations connected to this PLC
    stations_to_monitor = [
        (line_name, channel_id, config)
        for line_name, stations in CHANNELS.items()
        for channel_id, config in stations.items()
        if config.get("plc", {}).get("ip") == ip and config["plc"].get("slot", 0) == slot
    ]

    if not stations_to_monitor:
        logger.warning(f"⚠️ No stations found for PLC {ip}:{slot}")
        return

    # Use trigger and clock config from the first station
    ref_station = stations_to_monitor[0]
    trigger_conf = ref_station[2].get("dati_pronti_fermi")
    clock_conf = ref_station[2].get("keepLive_fermi_PC")

    if not trigger_conf:
        logger.warning(f"⚠️ No dati_pronti_fermi config for PLC {ip}:{slot}")
        return
    if not clock_conf:
        logger.warning(f"⚠️ No keepLive_fermi_PC config for PLC {ip}:{slot}")

    # Single trigger and clock state
    prev_trigger = False
    clock = False

    plc_key = (plc_connection.ip_address, plc_connection.slot)
    db = trigger_conf["db"]
    db_range = PLC_DB_RANGES.get(plc_key, {}).get(db)
    if not db_range:
        logger.error(f"❌ No DB range defined for {plc_key} DB{db}")
        return

    start_byte = db_range["min"]
    size = db_range["max"] - db_range["min"] + 1

    while True:
        try:
            if not plc_connection.connected or not plc_connection.is_connected():
                #logger.warning(f"PLC disconnected for {ip}:{slot}, Skipping Fermi")
                continue

            # Read trigger buffer once
            buffer = await asyncio.get_event_loop().run_in_executor(
                plc_executor,
                plc_connection.db_read,
                db,
                start_byte,
                size,
            )
            trigger_value = extract_bool(buffer, trigger_conf["byte"], trigger_conf["bit"], start_byte)

            if trigger_value is None:
                raise Exception("Trigger read returned None")

            # Only handle change
            if trigger_value != prev_trigger:
                prev_trigger = trigger_value

                # Use representative station info
                line_name, channel_id, _ = ref_station
                await fermi_trigger_change(plc_connection, line_name, channel_id, trigger_value)

            # Write PLC-wide clock toggle
            # if clock_conf and not debug:
            # clock = not clock
            # await asyncio.to_thread(
            #    plc_connection.write_bool,
            #    clock_conf["db"], clock_conf["byte"], clock_conf["bit"], clock
            # )

            await asyncio.sleep(1)

        except Exception as e:
            logger.error(f"[{ip}:{slot}] 🔴 Error in fermi_task: {e}")


async def fermi_trigger_change(
    plc_connection: PLCConnection,
    line_name: str,
    channel_id: str,
    val
):
    if not isinstance(val, bool):
        return

    full_id = f"{line_name}.{channel_id}"
    paths = get_channel_config(line_name, channel_id)
    if not paths:
        logger.warning(f"Config not found for {full_id}")
        return

    if val:
        logger.debug(f"Dati Pronti FERMI on {full_id} TRUE ...")
        # leggere i dati:
        data = await read_fermi_data(plc_connection, line_name, channel_id)

        # Queue DB write + visual refresh
        asyncio.create_task(db_write_queue.enqueue(process_fermo_update, data))

        # poi quando leggo scrivo Dati Letti fermi a TRUE
        dati_letti_conf = paths.get("dati_letti_fermi")
        if dati_letti_conf and not debug:
            await asyncio.get_event_loop().run_in_executor(
                plc_executor,
                plc_connection.write_bool,
                dati_letti_conf["db"],
                dati_letti_conf["byte"],
                dati_letti_conf["bit"],
                True,
            )

    else:
        logger.debug(f"Dati Pronti FERMI on {full_id} FALSE ...")
        # METTERE A ZERO DATI LETTI
        dati_letti_conf = paths.get("dati_letti_fermi")
        if dati_letti_conf and not debug:
            await asyncio.get_event_loop().run_in_executor(
                plc_executor,
                plc_connection.write_bool,
                dati_letti_conf["db"],
                dati_letti_conf["byte"],
                dati_letti_conf["bit"],
                False,
            )


async def read_fermi_data(plc_connection: PLCConnection, line_name: str, channel_id: str):
    full_id = f"{line_name}.{channel_id}"

    try:
        config = get_channel_config(line_name, channel_id)
        if config is None:
            logger.error(f"[{full_id}], Missing config for line/channel")
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
                logger.error(f"No DB range defined for {plc_key} DB{db}")
                return None

            start_byte = db_range["min"]
            size = db_range["max"] - db_range["min"] + 1
            buffer = await asyncio.get_event_loop().run_in_executor(
                plc_executor,
                plc_connection.db_read,
                db,
                start_byte,
                size,
            )
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
        logger.error(f"[{full_id}] Error reading PLC data: {e}")
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

    stop_id = await run_in_thread(
        create_stop,
        station_id=data["Stazione_Fermo"],
        start_time=data["DataInizio"],
        end_time=data["DataFine"],
        operator_id=data["Id_Utente"],
        stop_type="STOP",
        reason=reason,
        status="CLOSED",
        linked_production_id=None,
        conn=conn,
    )

    logger.debug(f"Added FERMO stop_id={stop_id}")


async def process_fermo_update(data):
    """Background task: insert stop data and refresh visuals."""
    try:
        with get_mysql_connection() as conn:
            await insert_fermo_data(data, conn)

        ts = data.get("DataInizio") or datetime.now()
        await run_in_thread(refresh_fermi_data, "AIN", ts)
        await run_in_thread(refresh_fermi_data, "ELL", ts)
    except Exception as e:  # pragma: no cover - best effort logging
        logger.warning(f"process_fermo_update failed: {e}")
