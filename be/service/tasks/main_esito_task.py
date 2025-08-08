import asyncio
from datetime import datetime
import logging
from threading import Thread
import time
import os
import sys
from typing import Any

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection, insert_defects, insert_initial_production_data, update_production_final, insert_str_data
from service.connections.temp_data import remove_temp_issues
from service.controllers.plc import PLCConnection
from service.helpers.helpers import get_channel_config
from service.config.config import PLC_DB_RANGES, debug
from service.routes.broadcast import broadcast
from service.state.global_state import (
    get_zones_from_station,
    inizio_true_passato_flags,
    inizio_false_passato_flags,
    fine_true_passato_flags,
    fine_false_passato_flags,
    trigger_timestamps,
    incomplete_productions,
    plc_read_executor,
    plc_write_executor,
    db_write_queue,
    db_range_cache,

)
import service.state.global_state as global_state
from service.helpers.buffer_plc_extract import extract_bool, extract_s7_string, extract_string, extract_swapped_int, extract_int
from service.helpers.visual_helper import refresh_top_defects_ell, refresh_top_defects_qg2, refresh_top_defects_vpf, refresh_vpf_defects_data, update_visual_data_on_new_module
from service.routes.mbj_routes import parse_mbj_details
from service.helpers.executor import run_in_thread
from service.helpers.ell_buffer import mirror_defects, mirror_ell_production

logger = logging.getLogger(__name__)

TIMING_THRESHOLD = 3.0

def log_duration(msg: str, duration: float, plc_connection: PLCConnection, full_station_id: str, threshold: float = TIMING_THRESHOLD) -> None:
    """Log duration at WARNING level if above threshold else DEBUG."""
    log_fn = logger.warning if duration > threshold else logger.debug
    log_fn(f"{msg} in {duration:.3f}s")

    if duration > threshold:
        # prevent reconnect storm
        if not getattr(plc_connection, '_reconnect_in_progress', False):
            plc_connection._reconnect_in_progress = True
            plc_connection.reconnect_once_now(
                reason=f"{msg} took {duration:.2f}s on {full_station_id}"
            )

            # clear the flag after some time to allow future reconnects
            Thread(target=_reset_reconnect_flag_later, args=(plc_connection,), daemon=True).start()

def _reset_reconnect_flag_later(plc_connection: PLCConnection, delay: float = 30.0):
    """Avoid reconnect storms by resetting the in-progress flag after delay."""
    time.sleep(delay)
    plc_connection._reconnect_in_progress = False

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
    #if channel_id == "RMI01":
    #    logger.info(f"[{full_station_id}] process_final_update start")
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
                #if channel_id == "RMI01":
                #    logger.info(
                #        f"[{full_station_id}] update_production_final took {time.perf_counter() - t3:.3f}s"
                #    )

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
            #Step: Insert STR visual snapshot if STR station and EndCycle
            elif channel_id.startswith("STR"):
                try:
                    str_data = {
                        "cell_G": result.get("cell_G", 0),
                        "cell_NG": result.get("cell_NG", 0),
                        "string_G": result.get("string_G", 0),
                        "string_NG": result.get("string_NG", 0),
                    }
            
                    station_id = result.get("station_id", None)

                    timestamp = (
                        datetime.fromisoformat(end_time)
                        if not isinstance(end_time, datetime)
                        else end_time
                    )
                    asyncio.create_task(
                        insert_str_data_async(
                            str_data,
                            station_id,
                            timestamp,
                            line_name,
                        )
                    )
                except Exception as e:
                    logger.error(f"[{full_station_id}] Failed to insert STR snapshot: {e}")
            try:

                zones = get_zones_from_station(channel_id)
                timestamp = (
                    datetime.fromisoformat(end_time)
                    if not isinstance(end_time, datetime)
                    else end_time
                )
                reentered = result.get(
                    "Re_entered_from_m506" if channel_id == "VPF01" else "Re_entered_from_m326",
                    False,
                )

                # Support multi-PLC fields: prefer id_modulo_end
                id_mod_key = "id_modulo_end"
                id_mod_conf = paths.get(id_mod_key) or paths.get("id_modulo")
                if debug:
                    object_id = global_state.debug_moduli.get(full_station_id)
                elif id_mod_conf:
                    object_id = extract_string(
                        buffer,
                        id_mod_conf["byte"],
                        id_mod_conf.get("length", 0),
                        start_byte
                    )
                else:
                    logger.warning(f"[{full_station_id}] Missing config for {id_mod_key}")
                    object_id = None

                bufferIds = result.get("BufferIds_Rework", [])
                for zone in zones:
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

            print('Completed modulo: %s on station %s' % (result.get("Id_Modulo"), full_station_id))

    except Exception as e:
        logger.error(f"[{full_station_id}] Async final update failed: {e}")
    finally:
        #if channel_id == "RMI01":
        #    logger.info(
        #        f"[{full_station_id}] process_final_update took {time.perf_counter() - t0:.3f}s"
        #    )
        incomplete_productions.pop(full_station_id, None)
        remove_temp_issues(line_name, channel_id, result.get("Id_Modulo"))

async def process_mirror_ell_production(row: dict) -> None:
    """Background task to mirror production into the ELL buffer."""
    try:
        with get_mysql_connection() as conn:
            await run_in_thread(mirror_ell_production, row, conn)
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

async def insert_str_data_async(*args, **kwargs) -> None:
    """Wrapper to run insert_str_data in thread with its own connection."""
    try:
        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                await run_in_thread(
                    insert_str_data,
                    *args,
                    cursor=cursor,
                    **kwargs,
                )
    except Exception as e:
        logger.warning(f"insert_str_data_async failed: {e}")

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
            #if channel_id in ("ELL01", "RMI01") and initial_data:
            #    await process_mirror_ell_production(
            #        {
            #            "id": prod_id,
            #            "object_id": object_id,
            #            "station_id": 9 if channel_id == "ELL01" else 3,
            #            "start_time": initial_data.get("DataInizio"),
            #            "end_time": None,
            #            "esito": esito,
            #        }
            #    )
        else:
            logger.warning(
                f"[{full_station_id}] ⚠️ No prod_id returned from insert_initial_production_data (object_id={object_id})"
            )
    except Exception as e:  # pragma: no cover - best effort logging
        logger.exception(
            f"[{full_station_id}] Exception during insert_initial_production_data: {e}"
        )

async def background_task(
    plc_connections: list[PLCConnection],  # Accepts 1 or 2 connections
    full_station_id: str
):
    logger.debug(f"[{full_station_id}] Starting background task.")

    line_name, channel_id = full_station_id.split(".")

    # Unpack PLC connections
    if len(plc_connections) == 1:
        trigger_conn = end_conn = plc_connections[0]
    elif len(plc_connections) == 2:
        trigger_conn, end_conn = plc_connections
    else:
        logger.error(f"[{full_station_id}] Invalid number of PLC connections passed: {len(plc_connections)}")
        return

    while True:
        try:
            # Ensure both connections are alive
            if not trigger_conn.connected or not trigger_conn.is_connected():
                await asyncio.sleep(0.5)
                continue
            if end_conn is not trigger_conn and (not end_conn.connected or not end_conn.is_connected()):
                await asyncio.sleep(0.5)
                continue

            paths = get_channel_config(line_name, channel_id)
            if not paths:
                logger.error(f"Invalid line/channel: {line_name}.{channel_id}")
                await asyncio.sleep(0.5)
                continue

            # ───────────────── Trigger Read ─────────────────
            trigger_conf = paths["trigger"]
            trigger_db = trigger_conf["db"]
            trigger_key = f"{full_station_id}_TRIG_DB{trigger_db}"
            plc_key = (trigger_conn.ip_address, trigger_conn.slot)

            if trigger_key not in db_range_cache:
                raw = PLC_DB_RANGES.get(plc_key, {}).get(trigger_db)
                if not raw:
                    logger.error(f"No DB range defined for {plc_key} DB{trigger_db}")
                    await asyncio.sleep(0.5)
                    continue
                db_range_cache[trigger_key] = (raw["min"], raw["max"])

            trig_start, trig_end = db_range_cache[trigger_key]
            trig_size = trig_end - trig_start + 1

            buffer_trigger = await asyncio.get_event_loop().run_in_executor(
                plc_read_executor, trigger_conn.db_read, trigger_db, trig_start, trig_size
            )

            if debug:
                trigger_value = global_state.debug_triggers.get(full_station_id, False)
            else:
                trigger_value = extract_bool(buffer_trigger, trigger_conf["byte"], trigger_conf["bit"], trig_start)

            if trigger_value is None:
                raise Exception("Trigger read returned None")

            if not trigger_value:
                inizio_true_passato_flags[full_station_id] = False
                if not inizio_false_passato_flags[full_station_id]:
                    inizio_false_passato_flags[full_station_id] = True
                    await broadcast(line_name, channel_id, {
                        "trigger": False,
                        "objectId": None,
                        "stringatrice": None,
                        "outcome": None,
                        "issuesSubmitted": False
                    })

            if trigger_value:
                if not inizio_true_passato_flags[full_station_id]:
                    inizio_true_passato_flags[full_station_id] = True
                    inizio_false_passato_flags[full_station_id] = False
                    trigger_timestamp = time.perf_counter()
                    asyncio.create_task(
                        on_trigger_change(
                            trigger_conn,
                            line_name,
                            channel_id,
                            trigger_value,
                            buffer_trigger,
                            trig_start,
                            trigger_timestamp
                        )
                    )
                else:
                    logger.debug(f"[{full_station_id}] Trigger TRUE but already handled.")

            # ───────────────── EndCycle Read ─────────────────
            fb_conf = paths["fine_buona"]
            fs_conf = paths["fine_scarto"]
            end_db = fb_conf["db"]  # assumes both use the same DB
            end_key = f"{full_station_id}_END_DB{end_db}"
            plc_key_end = (end_conn.ip_address, end_conn.slot)

            if end_key not in db_range_cache:
                raw = PLC_DB_RANGES.get(plc_key_end, {}).get(end_db)
                if not raw:
                    logger.error(f"No DB range defined for {plc_key_end} DB{end_db}")
                    await asyncio.sleep(0.5)
                    continue
                db_range_cache[end_key] = (raw["min"], raw["max"])

            end_start, end_end = db_range_cache[end_key]
            end_size = end_end - end_start + 1

            buffer_end = await asyncio.get_event_loop().run_in_executor(
                plc_read_executor, end_conn.db_read, end_db, end_start, end_size
            )
            plc_connections[0].is_connected()

            if debug:
                force_ng = global_state.debug_trigger_NG.get(full_station_id, False)
                force_g = global_state.debug_trigger_G.get(full_station_id, False)
                fine_buona = force_g
                fine_scarto = force_ng
            else:
                fine_buona = extract_bool(buffer_end, fb_conf["byte"], fb_conf["bit"], end_start)
                fine_scarto = extract_bool(buffer_end, fs_conf["byte"], fs_conf["bit"], end_start)

            if fine_buona is None or fine_scarto is None:
                raise Exception("Outcome read returned None")

            if not fine_buona and not fine_scarto:
                fine_true_passato_flags[full_station_id] = False
                if not fine_false_passato_flags[full_station_id]:
                    fine_false_passato_flags[full_station_id] = True

            if (fine_buona or fine_scarto) and not fine_true_passato_flags[full_station_id]:
                fine_true_passato_flags[full_station_id] = True
                fine_false_passato_flags[full_station_id] = False
                asyncio.create_task(handle_end_cycle(
                    end_conn,
                    line_name,
                    channel_id,
                    buffer_end,
                    end_start,
                    fine_buona,
                    fine_scarto,
                    paths,
                    trigger_timestamps.get(full_station_id)
                ))

            await asyncio.sleep(0.5)

        except Exception as e:
            logger.error(f"[{full_station_id}], Error in background task: {str(e)}")

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
    #if channel_id == "RMI01":
    #    logger.info(
    #        f"[{full_station_id}] EndCycle start: fine_buona={fine_buona}, fine_scarto={fine_scarto}"
    #    )
    #if full_station_id =="Linea2.ELL01":
        #logger.info(f"Fine Ciclo on {full_station_id} TRUE ...")

    esito_conf = paths.get("esito_scarto_compilato")
    pezzo_archivia_conf = paths["pezzo_archiviato"]
    timer_0 = time.perf_counter()
    
    result = await read_data(
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
    timer_1 = time.perf_counter()
    logger.debug(f"[{full_station_id}] read_data", timer_1 - timer_0)
    #if channel_id == "RMI01":
    #    logger.info(
    #        f"[{full_station_id}] read_data took {timer_1 - timer_0:.3f}s"
    #    )
    
    t11 = time.perf_counter()
    queue_size_arch = get_executor_status(plc_write_executor)["queue_size"]

    # estrai arch_byte sicuro
    idx_arch = pezzo_archivia_conf["byte"] - start_byte
    if 0 <= idx_arch < len(buffer):
        arch_byte = buffer[idx_arch]
    else:
        logger.warning(f"[{full_station_id}] arch_byte fuori range, default a 0")
        arch_byte = 0

    t_write_start = time.perf_counter()  # timer iniziale
    # scrivi archivio TRUE
    future_arch = plc_write_executor.submit(
        plc_connection.write_bool,
        pezzo_archivia_conf["db"],
        pezzo_archivia_conf["byte"],
        pezzo_archivia_conf["bit"],
        True,
        current_byte=arch_byte,
    )
    await asyncio.wrap_future(future_arch)
    t_write_done = time.perf_counter()
    duration_arch = t_write_done - t_write_start
    log_duration(
        f"[{full_station_id}] archivio TRUE (queue_size={queue_size_arch})",
        duration_arch,
        plc_connection,
        full_station_id,
    )
    #if channel_id == "RMI01":
    #    logger.info(
    #        f"[{full_station_id}] archivio TRUE took {duration_arch:.3f}s (queue_size={queue_size_arch})"
    #    )

    if esito_conf:
        # estrai esito_byte sicuro
        idx_esito = esito_conf["byte"] - start_byte
        if 0 <= idx_esito < len(buffer):
            esito_byte = buffer[idx_esito]
        else:
            logger.warning(f"[{full_station_id}] esito_byte fuori range, default a 0")
            esito_byte = 0

        # scrivi esito FALSE
        future_esito = plc_write_executor.submit(
            plc_connection.write_bool,
            esito_conf["db"],
            esito_conf["byte"],
            esito_conf["bit"],
            False,
            current_byte=esito_byte,
        )
        await asyncio.wrap_future(future_esito)
    t_write_end = time.perf_counter()
    total_plc_write = t_write_end - t_plc_detect
    log_duration(
        f"[{full_station_id}] from PLC TRUE to write_bool(TRUE)",
        total_plc_write,
        plc_connection,
        full_station_id,
    )
    #if channel_id == "RMI01":
    #    logger.info(
    #        f"[{full_station_id}] PLC write sequence took {total_plc_write:.3f}s"
    #    )

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
                f"[{full_station_id}] {result['Id_Modulo']} Module was not found in incomplete productions. Wrote archivio bit anyway."
            )

    duration_total = time.perf_counter() - t0
    #print(f"[{full_station_id}] handle_end_cycle completed in {duration_total:.3f}s")

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

    # Timestamp bookkeeping
    t_trigger_seen = trigger_timestamp or time.perf_counter()
    trigger_timestamps.pop(full_id, None)

    # ─── Prepare configs ───
    # id_modulo: prefer "id_modulo_start", fallback to "id_modulo"
    id_mod_key = "id_modulo_start"
    id_mod_conf = paths.get(id_mod_key) or paths.get("id_modulo")
    # stringatrice: prefer "stringatrice_start", fallback to "stringatrice"
    str_key = "stringatrice_start"
    str_conf = paths.get(str_key) or paths.get("stringatrice")
    # issues_submitted bit
    esito_conf = paths.get("esito_scarto_compilato")
    # write-TRUE bit
    pezzo_conf = paths["pezzo_salvato_su_DB_con_inizio_ciclo"]

    # ─── Extract object_id ───
    if debug:
        object_id = global_state.debug_moduli.get(full_id)
    elif id_mod_conf:
        object_id = extract_string(
            buffer,
            id_mod_conf["byte"],
            id_mod_conf["length"],
            start_byte
        )
    else:
        logger.warning(f"[{full_id}] Missing config for {id_mod_key}")
        object_id = ""

    # ─── Extract stringatrice index ───
    if str_conf and "length" in str_conf:
        values = [
            extract_bool(buffer, str_conf["byte"], i, start_byte)
            for i in range(str_conf["length"])
        ]
        if not any(values):
            values[0] = True
    else:
        # legacy fallback: if no config, all False
        values = [False] * 5
        idx = int(channel_id.replace("STR", "")) - 1
        if 0 <= idx < len(values):
            values[idx] = True

    stringatrice = str(values.index(True) + 1) if any(values) else "1"

    # ─── Extract issues_submitted ───
    issues_submitted = False
    if esito_conf:
        issues_submitted = extract_bool(
            buffer,
            esito_conf["byte"],
            esito_conf["bit"],
            start_byte
        )

    # ─── Mark start time ───
    trigger_timestamps[full_id] = datetime.now()
    data_inizio = trigger_timestamps[full_id]

    # ─── Read initial data (StartCycle) ───
    initial_data = await read_data(
        plc_connection,
        line_name,
        channel_id,
        richiesta_ok=False,
        richiesta_ko=False,
        data_inizio=data_inizio,
        buffer=buffer,
        start_byte=start_byte,
        is_EndCycle=False
    )

    # ─── Determine esito (excluded vs OK) ───
    escl_conf = paths.get("stazione_esclusa")
    esclusione_attiva = False
    if escl_conf:
        esclusione_attiva = extract_bool(
            buffer,
            escl_conf["byte"],
            escl_conf["bit"],
            start_byte
        )
    esito = 4 if esclusione_attiva else 2

    # ─── Enqueue initial insert & update expected_moduli ───
    logger.debug(f"[{full_id}] Starting initial production insert for object_id={object_id}")
    asyncio.create_task(db_write_queue.enqueue(
        process_initial_production,
        full_id,
        channel_id,
        initial_data,
        esito,
        object_id
    ))
    global_state.expected_moduli[full_id] = object_id
    logger.debug(f"[{full_id}] expected_moduli updated with object_id={object_id}")

    # ─── Write TRUE back to PLC ───
    if not debug:
        t0 = time.perf_counter()
        queue_size = get_executor_status(plc_write_executor)["queue_size"]

        pezzo_byte = None
        if buffer is not None and start_byte is not None:
            idx = pezzo_conf["byte"] - start_byte
            if 0 <= idx < len(buffer):
                pezzo_byte = buffer[idx]

        fut = plc_write_executor.submit(
            plc_connection.write_bool,
            pezzo_conf["db"],
            pezzo_conf["byte"],
            pezzo_conf["bit"],
            True,
            current_byte=pezzo_byte,
        )
        await asyncio.wrap_future(fut)
        t1 = time.perf_counter()
        delay = t1 - t0
        logger.debug(
            f"[{full_id}] ⏱ write_TRUE={delay:.3f}s | queue_size={queue_size}"
        )

    # ─── Broadcast to frontend ───
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

        data: dict[str, Any] = {}

        # ─── Step 4: Read Id_Modulo (start vs end) ───
        key_mod = "id_modulo_end" if is_EndCycle else "id_modulo_start"
        id_mod_conf = config.get(key_mod) or config.get("id_modulo")
        debug_id = global_state.debug_moduli.get(full_id) if debug else None

        if debug_id:
            data["Id_Modulo"] = debug_id
        elif id_mod_conf:
            try:
                data["Id_Modulo"] = extract_string(
                    buffer,
                    id_mod_conf["byte"],
                    id_mod_conf["length"],
                    start_byte
                ) or ""
            except Exception as e:
                logger.error(f"[{full_id}], Exception reading Id_Modulo: {e}")
                data["Id_Modulo"] = ""
        else:
            logger.warning(f"[{full_id}], Missing config for {key_mod}")
            data["Id_Modulo"] = ""

        if not data["Id_Modulo"]:
            logger.warning(f"[{full_id}], Id_Modulo is empty or unreadable")

        # ─── Step 5: Read Id_Utente (start vs end) ───
        key_utente = "id_utente_end" if is_EndCycle else "id_utente_start"
        id_utente_conf = config.get(key_utente) or config.get("id_utente")
        if id_utente_conf:
            data["Id_Utente"] = extract_string(
                buffer,
                id_utente_conf["byte"],
                id_utente_conf["length"],
                start_byte
            ) or ""
        else:
            logger.warning(f"[{full_id}], Missing config for {key_utente}")
            data["Id_Utente"] = ""

        # Always record the start timestamp
        data["DataInizio"] = data_inizio

        # ─── Step 7: Linea flags ───
        data["Linea_in_Lavorazione"] = [
            line_name == f"Linea{i}" for i in range(1, 6)
        ]

        # ─── Step 8: Stringatrice logic (start vs end) ───
        if "STR" not in channel_id:
            key_str = "stringatrice_end" if is_EndCycle else "stringatrice_start"
            str_conf = config.get(key_str) or config.get("stringatrice")
            if str_conf:
                values = [
                    extract_bool(buffer, str_conf["byte"], i, start_byte)
                    for i in range(str_conf["length"])
                ]
                if not any(values):
                    values[0] = True
                data["Lavorazione_Eseguita_Su_Stringatrice"] = values
            else:
                data["Lavorazione_Eseguita_Su_Stringatrice"] = []
                logger.warning(f"[{full_id}], Missing config for {key_str}")
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
        data["Tempo_Ciclo"] = str(data["DataFine"] - data["DataInizio"])

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
            raw = await asyncio.get_event_loop().run_in_executor(
                plc_read_executor, plc_connection.db_read, db, base, count * slen
            )
            rwk_vals = [extract_s7_string(raw, i * slen) for i in range(count)]
            #print('RWK_VALS:', rwk_vals)
        elif debug:
            rwk_vals = ["3SBHBGHC25620697", "3SBHBGHC25614686", "3SBHBGHC25620697"]

        data["BufferIds_Rework"] = rwk_vals
        
        STR_STATION_MAP = {
            "STR01": 4,
            "STR02": 5,
            "STR03": 6,
            "STR04": 7,
            "STR05": 8,
        }

        STR_OFFSETS = [46, 48, 50, 52]  # Bytes for cell_G, cell_NG, string_G, string_NG

        # Step 14: STR Visual Snapshot Insert (only for STR stations)
        if channel_id.startswith("STR"):
            try:
                # Read 4 integers directly from the current DB buffer
                data["cell_G"]    = extract_int(buffer, STR_OFFSETS[0], start_byte)
                data["cell_NG"]   = extract_int(buffer, STR_OFFSETS[1], start_byte)
                data["string_NG"]  = extract_int(buffer, STR_OFFSETS[2], start_byte)
                data["string_G"] = extract_int(buffer, STR_OFFSETS[3], start_byte)

                # Map channel_id to station_id
                station_id = STR_STATION_MAP.get(channel_id)
                if station_id is None:
                    raise ValueError(f"Unknown STR channel_id: {channel_id}")

                data["station_id"] = station_id

                logger.debug(
                    f"[{full_id}], STR snapshot read: "
                    f"cell_G={data['cell_G']}, cell_NG={data['cell_NG']}, "
                    f"string_G={data['string_G']}, string_NG={data['string_NG']} "
                    f"for station_id={station_id}"
                )
            except Exception as e:
                logger.error(f"[{full_id}], Failed to read STR snapshot: {e}")

        return data

    except Exception as e:
        logger.error(f"[{full_id}], Error reading PLC data: {e}")
        return None
