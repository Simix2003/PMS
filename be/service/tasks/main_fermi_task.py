import asyncio
import logging
import os
import sys
import functools
from datetime import datetime

logger = logging.getLogger(__name__)

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import create_stop, get_mysql_connection
from service.controllers.plc import PLCConnection
from service.helpers.helpers import get_channel_config
from service.config.config import CHANNELS, PLC_DB_RANGES, debug
from service.helpers.buffer_plc_extract import extract_string, extract_int, extract_DT
from service.helpers.visuals.visual_helper import refresh_fermi_data
from service.state.global_state import db_write_queue, plc_read_executor, plc_write_executor
from service.helpers.executor import run_in_thread

async def fermi_task(plc_connection: PLCConnection, ip: str, slot: int):
    logger.debug(f"[{ip}:{slot}] Starting fermi task.")

    stations_to_monitor = [
        (line_name, channel_id, cfg)
        for line_name, stations in CHANNELS.items()
        for channel_id, cfg in stations.items()
        if cfg.get("plc", {}).get("ip") == ip and cfg["plc"].get("slot", 0) == slot
    ]

    if not stations_to_monitor:
        logger.warning(f"No stations found for PLC {ip}:{slot}")
        return

    ref_station = stations_to_monitor[0]
    trigger_conf = ref_station[2].get("dati_pronti_fermi")
    if not trigger_conf:
        logger.warning(f"No dati_pronti_fermi config for PLC {ip}:{slot}")
        return

    prev_trigger = False
    plc_key = (plc_connection.ip_address, plc_connection.slot)
    db = trigger_conf["db"]
    db_range = PLC_DB_RANGES.get(plc_key, {}).get(db)
    if not db_range:
        logger.error(f"No DB range defined for {plc_key} DB{db}")
        return

    while True:
        try:
            if not plc_connection.connected:
                await asyncio.sleep(1)
                continue

            trigger_value = await asyncio.get_event_loop().run_in_executor(
                plc_read_executor,
                plc_connection.read_bool,
                db,
                trigger_conf["byte"],
                trigger_conf["bit"],
            )

            if trigger_value != prev_trigger:
                prev_trigger = trigger_value
                line_name, channel_id, _ = ref_station
                await fermi_trigger_change(plc_connection, line_name, channel_id, trigger_value)

            await asyncio.sleep(0.1)
        except Exception as e:
            logger.error(f"[{ip}:{slot}] Error in fermi_task: {e}")

async def fermi_trigger_change(plc_connection: PLCConnection, line_name: str, channel_id: str, val: bool):
    if not val:
        paths = get_channel_config(line_name, channel_id)
        dati_letti_conf = paths.get("dati_letti_fermi") if paths else None
        if dati_letti_conf and not debug:
            current_byte = await asyncio.get_event_loop().run_in_executor(
                plc_read_executor,
                plc_connection.read_byte,
                dati_letti_conf["db"],
                dati_letti_conf["byte"],
            ) or 0
            await asyncio.get_event_loop().run_in_executor(
                plc_write_executor,
                functools.partial(
                    plc_connection.write_bool,
                    dati_letti_conf["db"],
                    dati_letti_conf["byte"],
                    dati_letti_conf["bit"],
                    False,
                    current_byte=current_byte
                )
            )
        return

    paths = get_channel_config(line_name, channel_id)
    data = await read_fermi_data(plc_connection, line_name, channel_id)
    asyncio.create_task(db_write_queue.enqueue(process_fermo_update, data))

    dati_letti_conf = paths.get("dati_letti_fermi") if paths else None
    if dati_letti_conf and not debug:
        current_byte = await asyncio.get_event_loop().run_in_executor(
            plc_read_executor,
            plc_connection.read_byte,
            dati_letti_conf["db"],
            dati_letti_conf["byte"],
        ) or 0
        await asyncio.get_event_loop().run_in_executor(
            plc_write_executor,
            functools.partial(
                plc_connection.write_bool,
                dati_letti_conf["db"],
                dati_letti_conf["byte"],
                dati_letti_conf["bit"],
                True,
                current_byte=current_byte
            )
        )

async def read_fermi_data(plc_connection: PLCConnection, line_name: str, channel_id: str):
    full_id = f"{line_name}.{channel_id}"
    config = get_channel_config(line_name, channel_id)
    if config is None:
        logger.error(f"[{full_id}] Missing config for line/channel")
        return None

    dbs_needed = {
        config[field]["db"]
        for field in ["id_utente_fermi", "inizio_fermo", "fine_fermo", "evento_fermo", "stazione_fermo"]
        if config.get(field)
    }

    buffers = {}
    for db in dbs_needed:
        plc_key = (plc_connection.ip_address, plc_connection.slot)
        db_range = PLC_DB_RANGES.get(plc_key, {}).get(db)
        if not db_range:
            logger.error(f"No DB range defined for {plc_key} DB{db}")
            return None
        start = db_range["min"]
        size = db_range["max"] - start + 1
        buf = await asyncio.get_event_loop().run_in_executor(
            plc_read_executor,
            plc_connection.db_read,
            db, start, size
        )
        buffers[db] = (buf, start)

    data = {}
    id_conf = config.get("id_utente_fermi")
    if id_conf:
        buf, start = buffers[id_conf["db"]]
        off = id_conf["byte"] - start
        data["Id_Utente"] = extract_string(buf, off, id_conf["length"], 0) or ""
    else:
        data["Id_Utente"] = ""

    def get_dt_field(field, extractor, default):
        conf = config.get(field)
        if conf:
            buf, start = buffers[conf["db"]]
            off = conf["byte"] - start
            return extractor(buf, off, 0)
        return default

    data["DataInizio"] = get_dt_field("inizio_fermo", extract_DT, None)
    data["DataFine"]   = get_dt_field("fine_fermo", extract_DT, None)
    data["Evento_Fermo"]   = get_dt_field("evento_fermo", extract_int, 0)
    data["Stazione_Fermo"] = get_dt_field("stazione_fermo", extract_int, 0)

    return data

async def insert_fermo_data(data, conn):
    reason_map = {
        1: "Cancelli Aperti",
        3: "Anomalia",
        4: "Ciclo non Automatico",
        6: "Fuori Tempo Ciclo",
        7: "Mancato Carico Particolari",
        8: "Mancato Scarico",
        9: "Mancato Carico",
    }
    reason = reason_map.get(data.get("Evento_Fermo"), "Fermo Generico")
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
    try:
        with get_mysql_connection() as conn:
            await insert_fermo_data(data, conn)
        ts = data.get("DataInizio") or datetime.now()
        await run_in_thread(refresh_fermi_data, "AIN", ts)
        await run_in_thread(refresh_fermi_data, "ELL", ts)
    except Exception as e:
        logger.warning(f"process_fermo_update failed: {e}")
