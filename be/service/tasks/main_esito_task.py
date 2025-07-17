import asyncio
from datetime import datetime
import logging
import time
import os
import sys
from typing import Optional

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection, insert_defects, insert_initial_production_data, update_production_final
from service.connections.temp_data import remove_temp_issues
from service.controllers.plc import PLCConnection
from service.helpers.helpers import get_channel_config
from service.config.config import PLC_DB_RANGES, ZONE_SOURCES, debug
from service.routes.broadcast import broadcast
from service.state.global_state import (
    inizio_true_passato_flags,
    inizio_false_passato_flags,
    fine_true_passato_flags,
    fine_false_passato_flags,
    trigger_timestamps,
    incomplete_productions,
    plc_executor,
    db_write_queue,
)
import service.state.global_state as global_state
from service.helpers.buffer_plc_extract import extract_bool, extract_s7_string, extract_string
from service.helpers.visual_helper import refresh_top_defects_ell, refresh_top_defects_qg2, refresh_top_defects_vpf, refresh_vpf_defects_data, update_visual_data_on_new_module
from service.routes.mbj_routes import parse_mbj_details
from service.helpers.executor import run_in_thread
from service.helpers.ell_buffer import mirror_defects, mirror_production

logger = logging.getLogger(__name__)

TIMING_THRESHOLD = 0.400


def log_duration(msg: str, duration: float, threshold: float = TIMING_THRESHOLD) -> None:
    """Log duration at WARNING level if above threshold else DEBUG."""
    log_fn = logger.warning if duration > threshold else logger.debug
    log_fn(f"{msg} in {duration:.3f}s")

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

async def process_final_update(
    full_station_id: str,
    line_name: str,
    channel_id: str,
    production_id: int,
    result: dict,
    buffer: bytes,
    start_byte: int,
    fine_buona: bool,
    fine_scarto: bool,
    paths: dict,
) -> None:
    """Handle MySQL updates and visual refresh after sending PLC response."""
    t0 = time.perf_counter()
    try:
        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                t3 = time.perf_counter()
                success, final_esito, end_time = await run_in_thread(
                    update_production_final,
                    production_id,
                    result,
                    channel_id,
                    conn,
                    fine_buona,
                    fine_scarto,
                )
                #duration = time.perf_counter() - t3
                #log_duration(f"[{full_station_id}] update_production_final", duration)

        if success:
            async_tasks = []

            if channel_id == "ELL01" and fine_scarto and "MBJ_Defects" not in result:
                async def fetch_mbj():
                    mbj = await run_in_thread(parse_mbj_details, result.get("Id_Modulo"))
                    if mbj:
                        result["MBJ_Defects"] = mbj
                async_tasks.append(asyncio.create_task(fetch_mbj()))

            if channel_id == "VPF01" and fine_scarto and result.get("Tipo_NG_VPF"):
                async_tasks.append(
                    asyncio.create_task(
                        insert_defects_async(
                            result,
                            production_id,
                            channel_id,
                            line_name,
                            from_vpf=True,
                        )
                    )
                )
                timestamp = (
                    datetime.fromisoformat(end_time)
                    if not isinstance(end_time, datetime)
                    else end_time
                )
                async_tasks.append(asyncio.create_task(run_in_thread(refresh_top_defects_vpf, "AIN", timestamp)))
                async_tasks.append(asyncio.create_task(run_in_thread(refresh_vpf_defects_data, timestamp)))

            elif channel_id == "ELL01" and fine_scarto:
                async_tasks.append(
                    asyncio.create_task(
                        insert_defects_async(
                            result,
                            production_id,
                            channel_id,
                            line_name,
                            from_ell=True,
                        )
                    )
                )
                ell_defects = result.get("Defect_Rows")
                if ell_defects:
                    for d in ell_defects:
                        d["station_id"] = 9
                        d["category"] = "ELL"
                    async_tasks.append(asyncio.create_task(mirror_defects_async(ell_defects)))

            elif channel_id in ("AIN01", "AIN02") and fine_scarto and result.get("Tipo_NG_AIN"):
                async_tasks.append(
                    asyncio.create_task(
                        insert_defects_async(
                            result,
                            production_id,
                            channel_id,
                            line_name,
                            from_ain=True,
                        )
                    )
                )

            try:
                zone = get_zone_from_station(channel_id)
                timestamp = (
                    datetime.fromisoformat(end_time)
                    if not isinstance(end_time, datetime)
                    else end_time
                )
                reentered = result.get(
                    "Re_entered_from_m506" if channel_id == "VPF01" else "Re_entered_from_m326",
                    False,
                )
                id_mod_conf = paths["id_modulo"]
                if debug:
                    object_id = global_state.debug_moduli.get(full_station_id)
                else:
                    object_id = (
                        extract_string(buffer, id_mod_conf["byte"], id_mod_conf["length"], start_byte)
                        if id_mod_conf
                        else None
                    )
                bufferIds = result.get("BufferIds_Rework", [])
                if zone:
                    async_tasks.append(
                        asyncio.create_task(
                            run_in_thread(
                                update_visual_data_on_new_module,
                                zone=zone,
                                station_name=channel_id,
                                esito=final_esito,
                                ts=timestamp,
                                cycle_time=result["Tempo_Ciclo"],
                                reentered=bool(reentered),
                                bufferIds=bufferIds,
                                object_id=object_id,
                            )
                        )
                    )
                    if zone == "AIN" and fine_scarto:
                        async_tasks.append(asyncio.create_task(run_in_thread(refresh_top_defects_qg2, zone, timestamp)))
                        async_tasks.append(asyncio.create_task(run_in_thread(refresh_top_defects_ell, "ELL", timestamp)))
                    if zone == "ELL" and fine_scarto:
                        async_tasks.append(asyncio.create_task(run_in_thread(refresh_top_defects_ell, zone, timestamp)))
                else:
                    logger.debug(f"Unknown zone for {channel_id} — skipping visual update")
            except Exception as vis_err:  # pragma: no cover - best effort logging
                logger.warning(f"Could not update visual_data for {channel_id}: {vis_err}")

            if async_tasks:
                await asyncio.gather(*async_tasks)

    except Exception as e:
        logger.error(f"[{full_station_id}] Async final update failed: {e}")
    finally:
        incomplete_productions.pop(full_station_id, None)
        remove_temp_issues(line_name, channel_id, result.get("Id_Modulo"))
        #duration = time.perf_counter() - t0
        #log_duration(f"[{full_station_id}] Async final update done", duration)

async def process_mirror_production(row: dict) -> None:
    """Background task to mirror production into the ELL buffer."""
    try:
        with get_mysql_connection() as conn:
            await run_in_thread(mirror_production, row, conn)
    except Exception as e:  # pragma: no cover - best effort logging
        logger.warning(f"process_mirror_production failed: {e}")

async def insert_defects_async(*args, **kwargs) -> None:
    """Wrapper to run insert_defects in thread with its own connection."""
    try:
        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                await run_in_thread(
                    insert_defects,
                    *args,
                    cursor=cursor,
                    **kwargs,
                )
    except Exception as e:
        logger.warning(f"insert_defects_async failed: {e}")

async def mirror_defects_async(rows):
    try:
        with get_mysql_connection() as conn:
            await run_in_thread(mirror_defects, rows, conn)
    except Exception as e:
        logger.warning(f"mirror_defects_async failed: {e}")

async def process_initial_production(
    full_station_id: str,
    channel_id: str,
    initial_data: dict,
    esito: int,
    object_id: str,
) -> None:
    """Background task to insert initial production and mirror if needed."""
    try:
        with get_mysql_connection() as conn:
            prod_id = await run_in_thread(
                insert_initial_production_data,
                initial_data,
                channel_id,
                conn,
                esito,
            )
        if prod_id:
            incomplete_productions[full_station_id] = prod_id
            logger.debug(
                f"[{full_station_id}] ✅ Inserted production record: prod_id={prod_id}"
            )
            if channel_id in ("ELL01", "RMI01") and initial_data:
                await process_mirror_production(
                    {
                        "id": prod_id,
                        "object_id": object_id,
                        "station_id": 9 if channel_id == "ELL01" else 3,
                        "start_time": initial_data.get("DataInizio"),
                        "end_time": None,
                        "esito": esito,
                    }
                )
        else:
            logger.warning(
                f"[{full_station_id}] ⚠️ No prod_id returned from insert_initial_production_data (object_id={object_id})"
            )
    except Exception as e:  # pragma: no cover - best effort logging
        logger.exception(
            f"[{full_station_id}] Exception during insert_initial_production_data: {e}"
        )

async def background_task(plc_connection: PLCConnection, full_station_id: str):
    logger.debug(f"[{full_station_id}] Starting background task.")

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
                await asyncio.sleep(0.5)
                continue  # Skip this cycle if config not found

            # Get full DB buffer once for this PLC
            plc_key = (plc_connection.ip_address, plc_connection.slot)
            db = paths["trigger"]["db"]  # assuming all signals use same DB

            db_range = PLC_DB_RANGES.get(plc_key, {}).get(db)
            if not db_range:
                logger.error(f"No DB range defined for {plc_key} DB{db}")
                await asyncio.sleep(0.5)
                continue

            start_byte = db_range["min"]
            size = db_range["max"] - db_range["min"] + 1

            # Read full DB buffer
            timer_0 = time.perf_counter()
            buffer = await asyncio.get_event_loop().run_in_executor(
                plc_executor, plc_connection.db_read, db, start_byte, size
            )
            timer_1 = time.perf_counter()

            trigger_conf = paths["trigger"]
            if debug:
                trigger_value = global_state.debug_triggers.get(full_station_id, False)
            else:
                trigger_value = extract_bool(buffer, trigger_conf["byte"], trigger_conf["bit"], start_byte)

            if trigger_value is None:
                raise Exception("Trigger read returned None")
            
            if not trigger_value:
                inizio_true_passato_flags[full_station_id] = False
                if not inizio_false_passato_flags[full_station_id]:
                    logger.debug(f"Inizio Ciclo on {full_station_id} FALSE ...")
                    inizio_false_passato_flags[full_station_id] = True
                    await broadcast(line_name, channel_id, {
                        "trigger": False,
                        "objectId": None,
                        "stringatrice": None,
                        "outcome": None,
                        "issuesSubmitted": False
                    })

            if trigger_value and not inizio_true_passato_flags[full_station_id]:
                inizio_true_passato_flags[full_station_id] = True
                inizio_false_passato_flags[full_station_id] = False
                trigger_timestamp = time.perf_counter()
                asyncio.create_task(
                    on_trigger_change(
                        plc_connection,
                        line_name,
                        channel_id,
                        trigger_value,
                        buffer,
                        start_byte,
                        trigger_timestamp
                    )
                )

            if not paths:
                logger.error(f"Missing config for {line_name}.{channel_id}")
                await asyncio.sleep(0.5)
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
                fine_buona = extract_bool(buffer, fb_conf["byte"], fb_conf["bit"], start_byte)
                fine_scarto = extract_bool(buffer, fs_conf["byte"], fs_conf["bit"], start_byte)

            if fine_buona is None or fine_scarto is None:
                raise Exception("Outcome read returned None")
            
            if not fine_buona and not fine_scarto:
                fine_true_passato_flags[full_station_id] = False
                if not fine_false_passato_flags[full_station_id]:
                    fine_false_passato_flags[full_station_id] = True
                    logger.debug(f"Fine Ciclo on {full_station_id} FALSE ...")
                

            if (fine_buona or fine_scarto) and not fine_true_passato_flags[full_station_id]:
                fine_true_passato_flags[full_station_id] = True
                fine_false_passato_flags[full_station_id] = False
                asyncio.create_task(handle_end_cycle(
                    plc_connection,
                    line_name,
                    channel_id,
                    buffer,
                    start_byte,
                    fine_buona,
                    fine_scarto,
                    paths,
                    trigger_timestamps.get(full_station_id)
                ))


            await asyncio.sleep(0.5)

        except Exception as e:
            logger.error(f"[{full_station_id}], Error in background task: {str(e)}")
            await asyncio.to_thread(plc_connection.reconnect, retries=3, delay=5)
            await asyncio.sleep(5)

async def handle_end_cycle(
    plc_connection: PLCConnection,
    line_name: str,
    channel_id: str,
    buffer: bytes,
    start_byte: int,
    fine_buona: bool,
    fine_scarto: bool,
    paths: dict,
    data_inizio: datetime | None,
):
    """Process end-cycle logic in a background task."""
    full_station_id = f"{line_name}.{channel_id}"

    t_plc_detect = time.perf_counter()
    t0 = time.perf_counter()

    logger.debug(f"Fine Ciclo on {full_station_id} TRUE ...")

    read_task = asyncio.create_task(
        read_data(
            plc_connection,
            line_name,
            channel_id,
            richiesta_ok=fine_buona,
            richiesta_ko=fine_scarto,
            data_inizio=data_inizio,
            buffer=buffer,
            start_byte=start_byte,
            is_EndCycle=True,
        )
    )

    esito_conf = paths.get("esito_scarto_compilato")
    pezzo_archivia_conf = paths["pezzo_archiviato"]
    t11 = time.perf_counter()
    await asyncio.get_event_loop().run_in_executor(
        plc_executor,
        plc_connection.write_bool,
        pezzo_archivia_conf["db"],
        pezzo_archivia_conf["byte"],
        pezzo_archivia_conf["bit"],
        True,
    )
    if esito_conf:
        await asyncio.get_event_loop().run_in_executor(
            plc_executor,
            plc_connection.write_bool,
            esito_conf["db"],
            esito_conf["byte"],
            esito_conf["bit"],
            False,
        )
    t_write_end = time.perf_counter()
    log_duration(f"[{full_station_id}] from PLC TRUE to write_bool(TRUE)", t_write_end - t_plc_detect)

    timer_0 = time.perf_counter()
    result = await read_task
    timer_1 = time.perf_counter()
    logger.debug(f"[{full_station_id}] read_data", timer_1 - timer_0)

    if result:
        production_id = incomplete_productions.get(full_station_id)

        if production_id:
            asyncio.create_task(
                db_write_queue.enqueue(
                    process_final_update,
                    full_station_id,
                    line_name,
                    channel_id,
                    production_id,
                    result,
                    buffer,
                    start_byte,
                    fine_buona,
                    fine_scarto,
                    paths,
                )
            )
        else:
            logger.warning(
                f"[{full_station_id}] Module was not found in incomplete productions. Wrote archivio bit anyway."
            )

    #duration = time.perf_counter() - t0
    #log_duration(f"[{full_station_id}] Total Fine Ciclo processing", duration)

def get_executor_status(executor):
    active_threads = sum(1 for t in executor._threads if t.is_alive())
    queue_size = executor._work_queue.qsize()
    max_workers = executor._max_workers
    return {
        "max_workers": max_workers,
        "active_threads": active_threads,
        "queue_size": queue_size,
        "free_threads": max_workers - active_threads,
    }


async def on_trigger_change(
    plc_connection: PLCConnection,
    line_name: str,
    channel_id: str,
    val,
    buffer: bytes | None = None,
    start_byte: int | None = None,
    trigger_timestamp: float | None = None
):
    if not isinstance(val, bool):
        return

    full_id = f"{line_name}.{channel_id}"
    paths = get_channel_config(line_name, channel_id)
    if not paths:
        logger.warning(f"Config not found for {full_id}")
        return

    t_trigger_seen = trigger_timestamp or time.perf_counter()
    durations = {}

    logger.debug(f"Inizio Ciclo on {full_id} TRUE ...")
    trigger_timestamps.pop(full_id, None)

    esito_conf = paths.get("esito_scarto_compilato")
    pezzo_conf = paths["pezzo_salvato_su_DB_con_inizio_ciclo"]

    # Reset flags
    #t0 = time.perf_counter()
    #if esito_conf:
        #logger.debug(f"[{full_id}] Checking PLC executor before resetting esito flag...")
        #logger.info(f"[{full_id}] EXECUTOR STATUS: {get_executor_status(plc_executor)}")
        #await asyncio.get_event_loop().run_in_executor(
        #    plc_executor, plc_connection.write_bool,
        #    esito_conf["db"], esito_conf["byte"], esito_conf["bit"], False
        #)
    #logger.debug(f"[{full_id}] Checking PLC executor before resetting pezzo flag...")
    #logger.info(f"[{full_id}] EXECUTOR STATUS: {get_executor_status(plc_executor)}")
    #await asyncio.get_event_loop().run_in_executor(
    #    plc_executor, plc_connection.write_bool,
    #    pezzo_conf["db"], pezzo_conf["byte"], pezzo_conf["bit"], False
    #)
    #t1 = time.perf_counter()
    #durations["reset_flags"] = t1 - t0

    # Extract object_id + stringatrice + issues_submitted
    if debug:
        object_id = global_state.debug_moduli.get(full_id)
    else:
        id_mod_conf = paths["id_modulo"]
        object_id = extract_string(buffer, id_mod_conf["byte"], id_mod_conf["length"], start_byte)

    if "STR" not in channel_id:
        str_conf = paths.get("stringatrice")
        values = [
            extract_bool(buffer, str_conf["byte"], i, start_byte)
            for i in range(str_conf["length"])
        ]
        if not any(values):
            values[0] = True
    else:
        idx = int(channel_id.replace("STR", "")) - 1
        values = [False] * 5
        if 0 <= idx < len(values):
            values[idx] = True

    stringatrice_index = values.index(True) + 1
    stringatrice = str(stringatrice_index)

    issues_submitted = extract_bool(buffer, esito_conf["byte"], esito_conf["bit"], start_byte) if esito_conf else False

    # Timestamp
    trigger_timestamps[full_id] = datetime.now()
    data_inizio = trigger_timestamps[full_id]

    # Read data
    initial_data = await read_data(
        plc_connection, line_name, channel_id,
        richiesta_ok=False, richiesta_ko=False,
        data_inizio=data_inizio, buffer=buffer,
        start_byte=start_byte, is_EndCycle=False
    )

    # Determine esito
    escl_conf = paths.get("stazione_esclusa")
    esclusione_attiva = extract_bool(buffer, escl_conf["byte"], escl_conf["bit"], start_byte) if escl_conf else False
    esito = 4 if esclusione_attiva else 2

    # Enqueue + expected_moduli update
    logger.debug(f"[{full_id}] Starting initial production insert for object_id={object_id}")
    asyncio.create_task(db_write_queue.enqueue(
        process_initial_production, full_id, channel_id, initial_data, esito, object_id
    ))
    global_state.expected_moduli[full_id] = object_id
    logger.debug(f"[{full_id}] expected_moduli updated with object_id={object_id}")

    # Write TRUE
    t10 = time.perf_counter()
    if not debug:
        t_pre = time.perf_counter()
        await asyncio.get_event_loop().run_in_executor(
            plc_executor, plc_connection.write_bool,
            pezzo_conf["db"], pezzo_conf["byte"], pezzo_conf["bit"], True
        )
        t_post = time.perf_counter()

        durations["executor_queue"] = t_pre - t10
        durations["write_TRUE"] = t_post - t_pre
        durations["write_total"] = t_post - t10  # queue + write

        if durations["write_total"] > 0.5:
            logger.warning(f"[{full_id}] ⏱ write_TRUE={durations['write_TRUE']:.3f}s | queue={durations['executor_queue']:.3f}s | total={durations['write_total']:.3f}s")

    # Final duration from trigger
    total_duration = t_post - t_trigger_seen
    #logger.info(f"[{full_id}] Da Inizio Ciclo a True a PLC write(TRUE) = {total_duration}")

    if total_duration > TIMING_THRESHOLD:
        for name, dur in durations.items():
            logger.info(f"[{full_id}] step: {name:<25} → {dur:.3f}s")
        sum_steps = sum(durations.values())
        logger.info(f"[{full_id}] ⏱ total steps sum = {sum_steps:.3f}s | total duration = {total_duration:.3f}s")

    # Broadcast
    await broadcast(line_name, channel_id, {
        "trigger": True,
        "objectId": object_id,
        "stringatrice": stringatrice,
        "outcome": None,
        "issuesSubmitted": issues_submitted
    })

async def read_data(
    plc_connection: PLCConnection,
    line_name: str,
    channel_id: str,
    richiesta_ko: bool,
    richiesta_ok: bool,
    data_inizio: datetime | None,
    buffer: bytes | None = None,
    start_byte: int | None = None,
    is_EndCycle: bool = True
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

        # Always record the start timestamp
        data["DataInizio"] = data_inizio

        # Step 7: Linea flags
        data["Linea_in_Lavorazione"] = [
            line_name == "Linea1",
            line_name == "Linea2",
            line_name == "Linea3",
            line_name == "Linea4",
            line_name == "Linea5"
        ]

        # Step 8: Stringatrice logic
        if "STR" not in channel_id:
            str_conf = config.get("stringatrice")
            values = [
                extract_bool(buffer, str_conf["byte"], i, start_byte)
                for i in range(str_conf["length"])
            ]
            if not any(values):
                values[0] = True
            data["Lavorazione_Eseguita_Su_Stringatrice"] = values
        else:
            idx = int(channel_id.replace("STR", "")) - 1
            values = [False] * 5
            if 0 <= idx < len(values):
                values[idx] = True
            data["Lavorazione_Eseguita_Su_Stringatrice"] = values

        # Early exit for StartCycle: skip heavy reads
        if not is_EndCycle:
            return data

        # ==== EndCycle: all remaining steps ====

        # Step 6: Timestamps & cycle time
        data["DataFine"] = datetime.now()
        tempo_ciclo = data["DataFine"] - data_inizio
        data["Tempo_Ciclo"] = str(tempo_ciclo)

        # Step 9: Read VPF defects (BYTE48)
        vpf_values_1 = []
        vpf_conf = config.get("difetti_vpf_1")
        if vpf_conf and richiesta_ko and channel_id == "VPF01":
            vpf_values_1 = [
                extract_bool(buffer, vpf_conf["byte"], i, start_byte)
                for i in range(vpf_conf["length"])
            ]

        # Step 10: Read VPF defects (BYTE49)
        vpf_values_2 = []
        vpf_conf = config.get("difetti_vpf_2")
        if vpf_conf and richiesta_ko and channel_id == "VPF01":
            vpf_values_2 = [
                extract_bool(buffer, vpf_conf["byte"], i, start_byte)
                for i in range(vpf_conf["length"])
            ]

        # Combine VPF defects
        combined = vpf_values_1 + vpf_values_2
        if combined:
            data["Tipo_NG_VPF"] = combined
            logger.debug(f"[{full_id}], VPF Defect flags: {combined}")

        # Re-entered flags for VPF and ELL
        conf506 = config.get("re_entered_from_m506")
        if conf506 and channel_id == "VPF01":
            data["Re_entered_from_m506"] = extract_bool(buffer, conf506["byte"], conf506["bit"], start_byte)

        conf326 = config.get("re_entered_from_m326")
        if conf326 and channel_id == "ELL01":
            data["Re_entered_from_m326"] = extract_bool(buffer, conf326["byte"], conf326["bit"], start_byte)

        if debug:
            dbg = global_state.reentryDebug.get(full_id)
            if dbg is not None:
                data["Re_entered_from_m326"] = dbg

        # Step 11: AIN defects
        ain_conf = config.get("difetti_ain")
        if ain_conf and richiesta_ko and channel_id in ("AIN01", "AIN02"):
            bits = [
                extract_bool(buffer, ain_conf["byte"], i, start_byte)
                for i in range(ain_conf["length"])
            ]
            data["Tipo_NG_AIN"] = bits[3:5]
            logger.debug(f"[{full_id}], AIN Defect flags: {data['Tipo_NG_AIN']}")

        # Step 12: NG flag
        data["Compilato_Su_Ipad_Scarto_Presente"] = richiesta_ko


        # Step 13: Rework buffer IDs
        rwk_conf = config.get("reWorkBufferIds")
        rwk_vals: list[str] = []
        if rwk_conf and not debug:
            db, base = rwk_conf["db"], rwk_conf["byte"]
            count = rwk_conf["length"]
            slen = rwk_conf.get("string_length", 20) + 2
            raw = await asyncio.to_thread(plc_connection.db_read, db, base, count * slen)
            rwk_vals = [extract_s7_string(raw, i * slen) for i in range(count)]
        elif debug:
            rwk_vals = ["3SBHBGHC25620697", "3SBHBGHC25614686", "3SBHBGHC25620697"]

        data["BufferIds_Rework"] = rwk_vals

        return data

    except Exception as e:
        logger.error(f"[{full_id}], Error reading PLC data: {e}")
        return None
