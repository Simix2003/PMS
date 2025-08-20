# service/helpers/visuals/update_snapshot.py
from datetime import datetime, timedelta
import asyncio
import logging
import os
import sys
import copy
from collections import defaultdict
from typing import Dict, Any, List, Optional
import json

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.helpers.visuals.compute import compute_zone_snapshot
from service.state import global_state
from service.connections.mysql import get_mysql_connection
from service.helpers.visuals.visual_helper import compute_yield, count_unique_ng_objects, count_unique_objects, count_unique_objects_r0, get_last_8h_bins, get_previous_shifts, get_shift_window, time_to_seconds
from service.config.config import ELL_VISUAL, ZONE_SOURCES
from service.routes.broadcast import broadcast_zone_update

logger = logging.getLogger(__name__)


def update_visual_data_on_new_module(
    zone: str,
    station_name: str,
    esito: int,
    ts: datetime,
    cycle_time: Optional[str] = None,
    reentered: bool = False,
    bufferIds: List[str] = [],
    object_id: Optional[str] = None
) -> None:
    if zone not in global_state.visual_data:
        global_state.visual_data[zone] = compute_zone_snapshot(zone, now=ts)
        return

    # ✅ Per-zone lock: does NOT block other zones or the line
    with global_state.zone_locks[zone]:
        current_shift_start, _ = get_shift_window(ts)
        data = global_state.visual_data[zone]
        cached_shift_start = data.get("__shift_start")

        if cached_shift_start != current_shift_start.isoformat():
            global_state.visual_data[zone] = compute_zone_snapshot(zone, now=ts)
            return

        if zone == "VPF":
            _update_snapshot_vpf(data, station_name, esito, ts, cycle_time, reentered)
        elif zone == "AIN":
            _update_snapshot_ain(data, station_name, esito, ts)
        elif zone == "ELL":
            if not ELL_VISUAL:
                return
            _update_snapshot_ell_new(data, station_name, esito, ts, cycle_time, bufferIds, object_id)
        elif zone == "STR":
            _update_snapshot_str(data, station_name, esito, ts)
        elif zone == "LMN":
            _update_snapshot_lmn(data, station_name, esito, ts)
        elif zone == "DELTAMAX":
            _update_snapshot_deltamax(data, station_name, esito, ts)
        else:
            logger.info(f"Unknown zone: {zone}")
            return

        try:
            payload = copy.deepcopy(data)
            try:
                loop = asyncio.get_running_loop()
            except RuntimeError:
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)

            if loop.is_running():
                loop.call_soon_threadsafe(
                    lambda: asyncio.create_task(
                        broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
                    )
                )
            else:
                loop.run_until_complete(
                    broadcast_zone_update(line_name="Linea2", zone=zone, payload=payload)
                )
                loop.close()
        except Exception as e:
            logger.warning(f"Could not schedule WebSocket update for {zone}: {e}")

def _update_snapshot_ain(
    data: dict,
    station_name: str,
    esito: int,
    ts: datetime
) -> None:
    cfg = ZONE_SOURCES["AIN"]

    current_shift_start, _ = get_shift_window(ts)
    current_shift_label = (
        "S1" if 6 <= current_shift_start.hour < 14 else
        "S2" if 14 <= current_shift_start.hour < 22 else
        "S3"
    )

    # 1. Update counters
    if station_name in cfg["station_1_in"]:
        data["station_1_in"] += 1
    elif station_name in cfg["station_2_in"]:
        data["station_2_in"] += 1

    if esito == 6:
        if station_name in cfg["station_1_out_ng"]:
            data["station_1_out_ng"] += 1
        elif station_name in cfg["station_2_out_ng"]:
            data["station_2_out_ng"] += 1

    # 2. Recompute yield
    s1_good = data["station_1_in"] - data["station_1_out_ng"]
    s2_good = data["station_2_in"] - data["station_2_out_ng"]
    data["station_1_yield"] = compute_yield(s1_good, data["station_1_out_ng"])
    data["station_2_yield"] = compute_yield(s2_good, data["station_2_out_ng"])

    # 3. Update shift throughput
    is_in_station = station_name in cfg["station_1_in"] or station_name in cfg["station_2_in"]
    is_qc_station = station_name in cfg["station_1_out_ng"] or station_name in cfg["station_2_out_ng"]

    for shift in data["shift_throughput"]:
        if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
            if is_in_station:
                shift["total"] += 1
            if esito == 6 and is_qc_station:
                shift["ng"] += 1
            break

    # 4. Update yield per shift
    def update_shift_yield(station_yield_shifts, is_relevant_station):
        if not is_relevant_station:
            return
        for shift in station_yield_shifts:
            if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
                if esito == 6:
                    shift["ng"] += 1
                else:
                    shift["good"] += 1
                shift["yield"] = compute_yield(shift["good"], shift["ng"])
                break

    update_shift_yield(data["station_1_yield_shifts"], station_name in cfg["station_1_out_ng"])
    update_shift_yield(data["station_2_yield_shifts"], station_name in cfg["station_2_out_ng"])

    # 5. Update hourly bins
    hour_start = ts.replace(minute=0, second=0, microsecond=0)
    hour_label = hour_start.strftime("%H:%M")

    def _touch_hourly(list_key: str):
        lst = data[list_key]
        for entry in lst:
            if entry["hour"] == hour_label:
                if list_key == "last_8h_throughput":
                    entry["total"] += 1
                    if esito == 6:
                        entry["ng"] += 1
                else:
                    if esito == 6:
                        entry["ng"] += 1
                    else:
                        entry["good"] += 1
                    entry["yield"] = compute_yield(entry["good"], entry["ng"])
                break
        else:
            new_entry: Dict[str, Any] = {
                "hour": hour_label,
                "start": hour_start.isoformat(),
                "end": (hour_start + timedelta(hours=1)).isoformat(),
            }
            if list_key == "last_8h_throughput":
                new_entry.update({"total": 1, "ng": 1 if esito == 6 else 0})
            else:
                new_entry.update({
                    "good": 0 if esito == 6 else 1,
                    "ng":   1 if esito == 6 else 0,
                })
                new_entry["yield"] = compute_yield(new_entry["good"], new_entry["ng"])
            lst.append(new_entry)
            lst[:] = lst[-8:]

    if is_in_station or (esito == 6 and is_qc_station):
        _touch_hourly("last_8h_throughput")

    if station_name in cfg["station_1_out_ng"]:
        _touch_hourly("station_1_yield_last_8h")
    elif station_name in cfg["station_2_out_ng"]:
        _touch_hourly("station_2_yield_last_8h")

def _update_snapshot_vpf(
    data: dict,
    station_name: str,
    esito: int,
    ts: datetime,
    cycle_time: Optional[str],
    reentered: bool = False
) -> None:
    cfg = ZONE_SOURCES["VPF"]

    current_shift_start, _ = get_shift_window(ts)
    current_shift_label = (
        "S1" if 6 <= current_shift_start.hour < 14 else
        "S2" if 14 <= current_shift_start.hour < 22 else
        "S3"
    )

    is_in_station = station_name in cfg["station_1_in"]
    is_qc_station = station_name in cfg["station_1_out_ng"]

    if reentered:
        data["station_1_re_entered"] += 1
        return  # ✅ skip all stats

    # 1) Counters
    if is_in_station:
        data["station_1_in"] += 1
    if esito == 6 and is_qc_station:
        data["station_1_out_ng"] += 1

    # 2) Recompute yield
    good = data["station_1_in"] - data["station_1_out_ng"]
    data["station_1_yield"] = compute_yield(good, data["station_1_out_ng"])

    # 3) Update shift yield (per-station)
    for shift in data["station_1_shifts"]:
        if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
            if esito == 6 and is_qc_station:
                shift["ng"] += 1
            elif is_in_station:
                shift["good"] += 1
            shift["yield"] = compute_yield(shift["good"], shift["ng"])
            break

    # 4) Hourly bins (yield + throughput)
    hour_start = ts.replace(minute=0, second=0, microsecond=0)
    hour_label = hour_start.strftime("%H:%M")

    def _touch_hourly(list_key: str):
        lst = data[list_key]
        for entry in lst:
            if entry["hour"] == hour_label:
                if list_key == "last_8h_throughput":
                    entry["total"] += 1
                    if esito == 6:
                        entry["ng"] += 1
                else:
                    if esito == 6:
                        entry["ng"] += 1
                    else:
                        entry["good"] += 1
                    entry["yield"] = compute_yield(entry["good"], entry["ng"])
                return

        # create new hour bin
        new_entry: dict = {
            "hour": hour_label,
            "start": hour_start.isoformat(),
            "end": (hour_start + timedelta(hours=1)).isoformat(),
        }
        if list_key == "last_8h_throughput":
            new_entry.update({
                "total": 1,
                "ng": 1 if esito == 6 else 0,
            })
        else:
            new_entry.update({
                "good": 0 if esito == 6 else 1,
                "ng":   1 if esito == 6 else 0,
            })
            new_entry["yield"] = compute_yield(new_entry["good"], new_entry["ng"])

        lst.append(new_entry)
        lst[:] = lst[-8:]  # keep last 8

    # Throughput: count any relevant event (in-station OR NG at QC)
    if is_in_station or (esito == 6 and is_qc_station):
        _touch_hourly("last_8h_throughput")

    # Yield 8h updates only when QC station reports (same as your original idea)
    if is_qc_station:
        _touch_hourly("station_1_yield_last_8h")

    # 5) Speed ratio
    if cycle_time:
        try:
            h, m, s = cycle_time.split(":")
            current_sec = int(h) * 3600 + int(m) * 60 + float(s)

            median_sec = (
                data["speed_ratio"][0]["medianSec"]
                if "speed_ratio" in data and isinstance(data["speed_ratio"], list) and data["speed_ratio"]
                else current_sec
            )

            data["speed_ratio"] = [{
                "medianSec": median_sec,
                "currentSec": current_sec
            }]

        except Exception as e:
            logger.warning(f"Failed to parse cycle_time '{cycle_time}': {e}")

def _update_snapshot_ell_new(
    data: dict,
    station_name: str,
    esito: int,
    ts: datetime,
    cycle_time: Optional[str],
    bufferIds: List[str] = [],
    object_id: Optional[str] = None,
    reentered: bool = False
    ) -> None:

    def _get_shift_label_and_start(ts_str: str):
        ts = datetime.fromisoformat(ts_str)
        shift_start, _ = get_shift_window(ts)
        label = (
            "S1" if 6 <= shift_start.hour < 14 else
            "S2" if 14 <= shift_start.hour < 22 else
            "S3"
        )
        return label, shift_start

    def _get_hour_label(ts_str: str) -> str:
        ts = datetime.fromisoformat(ts_str)
        return ts.replace(minute=0, second=0, microsecond=0).strftime("%H:%M")

    try:
        cfg = ZONE_SOURCES["ELL"]
        current_shift_start, _ = get_shift_window(ts)
        current_shift_label = (
            "S1" if 6 <= current_shift_start.hour < 14 else
            "S2" if 14 <= current_shift_start.hour < 22 else
            "S3"
        )

        # ———————————————————————————————————————————————————————————————
        # Safely wrap sets/dicts expected to be updated
        data["latest_esito"] = data.get("latest_esito", {})
        data["latest_ts"] = data.get("latest_ts", {})
        data["s1_ng_set"] = set(data.get("s1_ng_set", []))
        data["reworked_set"] = set(data.get("reworked_set", []))
        data["good_after_rework_set"] = set(data.get("good_after_rework_set", []))
        data["s2_entry_set"] = set(data.get("s2_entry_set", []))
        data["multi_entry_set"] = set(data.get("multi_entry_set", []))
        data["s1_success_set"] = set(data.get("s1_success_set", []))

        # Critical one: must be defaultdict(int) to avoid crash
        data["s1_entry_count"] = defaultdict(int, data.get("s1_entry_count", {}))

        # ———————————————————————————————————————————————————————————————

        # 1. Update Counters
        if not reentered:
            if station_name in cfg["station_1_in"]:
                data["station_1_in"] += 1
                data["station_1_r0_in"] += 1
            elif station_name in cfg["station_2_in"]:
                data["station_2_in"] += 1
                data["station_2_r0_in"] += 1
        
            if esito == 6:
                if station_name in cfg['station_qg_1']:
                    data["station_1_ng_qg2"] += 1
                    data["ng_tot"] += 1
                elif station_name in cfg['station_qg_2']:
                    data["station_1_ng_qg2"] += 1
                    data["ng_tot"] += 1
                elif station_name in cfg["station_1_out_ng"]:
                    data["station_1_r0_ng"] += 1
                    data["station_1_out_ng"] += 1
                    data["ng_tot"] += 1
                elif station_name in cfg["station_2_out_ng"]:
                    data["station_2_r0_ng"] += 1
                    data["station_2_out_ng"] += 1
        
        if reentered:
            if esito == 1:
                if station_name in cfg["station_1_out_ng"]:
                    data["station_1_out_ng"] -= 1
                    data["ng_tot"] -= 1

        # 1a. Track “distinct modules that hit NG at station 1”:
        if station_name in cfg["station_2_in"] and esito == 5:
            data["reworked_set"].add(object_id)

        # 1c. Track “of those, who then passed at ELL”:
        if station_name in cfg["station_1_in"] and esito != 6:
            if object_id in data["reworked_set"]:
                data["good_after_rework_set"].add(object_id)

        # When passing station_1_in
        if station_name in cfg["station_1_in"] and object_id:
            data["s1_entry_count"][object_id] += 1
            if data["s1_entry_count"][object_id] > 1:
                data["multi_entry_set"].add(object_id)

        if object_id in data["multi_entry_set"] and esito == 1:
            data["s1_success_set"].add(object_id)

        if station_name in cfg["station_2_in"]:
            if object_id:
                data["s2_entry_set"].add(object_id)

        # 2 Yield
        # FPY = good on first pass / total first-pass
        s1_good_r0 = data["station_1_r0_in"] - data["station_1_r0_ng"]
        data["FPY_yield"] = compute_yield(s1_good_r0, data["station_1_r0_ng"])

        #RWK = Good after being Reworked / total in

        # Always track latest esito for RWK calculation
        if station_name in cfg["station_1_in"] + cfg["station_1_out_ng"]:
            data["latest_esito"][object_id] = esito
            data["latest_ts"][object_id] = ts.isoformat()

        final_statuses = [
            es for oid, es in data["latest_esito"].items()
            if oid in data["latest_ts"] and _get_shift_label_and_start(data["latest_ts"][oid]) == (current_shift_label, current_shift_start)
        ]

        final_good = sum(1 for es in final_statuses if es != 6)
        final_ng   = sum(1 for es in final_statuses if es == 6)

        data["RWK_yield"] = compute_yield(final_good, final_ng)

        # ———————————————————————————————————————————————————————————————
        # Gauge 1: re-entries / station_2_in
        denom = len(data["s2_entry_set"])
        num_multi = len(data["multi_entry_set"])
        data["value_gauge_1"] = round((num_multi / denom) * 100, 2) if denom else 0.0

        # Gauge 2: multi-entry modules that ended in esito=1 / multi-entry
        num_success = len(data["s1_success_set"])
        data["value_gauge_2"] = round((num_success / num_multi) * 100, 2) if num_multi else 0.0
        # ———————————————————————————————————————————————————————————————

        # 5 Update Throughput
        def update_shift_throughput(thr_data):
            is_in_station = station_name in cfg["station_1_in"] or station_name in cfg["station_2_in"]
            is_ell_station = station_name in cfg["station_1_out_ng"]
            is_scrap_station = station_name in cfg["station_2_out_ng"]

            for shift in thr_data:
                if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
                    if is_in_station:
                        shift["total"] += 1
                    if esito == 6 and is_ell_station:
                        shift["ng"] += 1
                    if esito == 6 and is_scrap_station:
                        shift["scrap"] += 1
                    break

        update_shift_throughput(data["shift_throughput"])

        # 6 Update shift yields
        def update_shift_yield_fpy(fpy_shift_data, is_r0_at_s1: bool):
            if not is_r0_at_s1:
                return
            for shift in fpy_shift_data:
                if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
                    if esito == 6:
                        shift["ng"] += 1
                    else:
                        shift["good"] += 1
                    shift["yield"] = compute_yield(shift["good"], shift["ng"])
                    break

        def update_shift_yield_rwk(rwk_shift_data, station_name: str, object_id: Optional[str], esito: int):
            if object_id is None:
                return
            # Track latest esito by object_id globally
            latest_esito = data["latest_esito"]
            latest_esito[object_id] = esito

            # Recompute good/ng per shift
            for shift in rwk_shift_data:
                start_ts = shift["start"]
                if shift["label"] == current_shift_label and start_ts == current_shift_start.isoformat():
                    latest_ts = data["latest_ts"]
                    latest_esito = data["latest_esito"]

                    relevant = [
                        oid for oid in latest_ts
                        if _get_shift_label_and_start(latest_ts[oid]) == (current_shift_label, current_shift_start)
                    ]

                    final_good = sum(1 for oid in relevant if latest_esito.get(oid) != 6)
                    final_ng   = len(relevant) - final_good

                    shift["good"] = final_good
                    shift["ng"] = final_ng
                    shift["yield"] = compute_yield(final_good, final_ng)
                    break

        # Update per-shift FPY
        update_shift_yield_fpy(
            data["FPY_yield_shifts"],
            not reentered and station_name in cfg["station_1_out_ng"]
        )

        # Update per-shift RWK
        update_shift_yield_rwk(
            data["RWK_yield_shifts"],
            station_name,
            object_id,
            esito
        )

        # 7 Update hourly bins
        hour_start = ts.replace(minute=0, second=0, microsecond=0)
        hour_label = hour_start.strftime("%H:%M")

        def _touch_hourly_fpy():
            if not reentered and station_name in cfg["station_1_out_ng"]:
                lst = data["FPY_yield_last_8h"]
                for entry in lst:
                    if entry["hour"] == hour_label:
                        if esito == 6:
                            entry["ng"] += 1
                        else:
                            entry["good"] += 1
                        entry["yield"] = compute_yield(entry["good"], entry["ng"])
                        break
                else:
                    data["FPY_yield_last_8h"].append({
                        "hour": hour_label,
                        "start": hour_start.isoformat(),
                        "end": (hour_start + timedelta(hours=1)).isoformat(),
                        "good": 0 if esito == 6 else 1,
                        "ng": 1 if esito == 6 else 0,
                        "yield": compute_yield(0 if esito == 6 else 1, 1 if esito == 6 else 0)
                    })
                    data["FPY_yield_last_8h"][:] = data["FPY_yield_last_8h"][-8:]

        def _touch_hourly_rwk():
            if object_id is None:
                return
            # always update RWK using latest_esito
            lst = data["RWK_yield_last_8h"]

            latest_ts = data["latest_ts"]
            latest_esito = data["latest_esito"]

            relevant = [
                oid for oid in latest_ts
                if _get_hour_label(latest_ts[oid]) == hour_label
            ]

            final_good = sum(1 for oid in relevant if latest_esito.get(oid) != 6)
            final_ng   = len(relevant) - final_good

            yield_val = compute_yield(final_good, final_ng)

            for entry in lst:
                if entry["hour"] == hour_label:
                    entry["good"] = final_good
                    entry["ng"] = final_ng
                    entry["yield"] = yield_val
                    break
            else:
                data["RWK_yield_last_8h"].append({
                    "hour": hour_label,
                    "start": hour_start.isoformat(),
                    "end": (hour_start + timedelta(hours=1)).isoformat(),
                    "good": final_good,
                    "ng": final_ng,
                    "yield": yield_val
                })
                data["RWK_yield_last_8h"][:] = data["RWK_yield_last_8h"][-8:]

        def _touch_hourly_throughput():
            is_in_station = station_name in cfg["station_1_in"] or station_name in cfg["station_2_in"]
            is_ell_station = station_name in cfg["station_1_out_ng"]
            is_scrap_station = station_name in cfg["station_2_out_ng"]

            if not (is_in_station or (esito == 6 and (is_ell_station or is_scrap_station))):
                return

            lst = data["last_8h_throughput"]
            for entry in lst:
                if entry["hour"] == hour_label:
                    if is_in_station:
                        entry["total"] += 1
                    if esito == 6 and is_ell_station:
                        entry["ng"] += 1
                    if esito == 6 and is_scrap_station:
                        entry["scrap"] += 1
                    break
            else:
                lst.append({
                    "hour": hour_label,
                    "start": hour_start.isoformat(),
                    "end": (hour_start + timedelta(hours=1)).isoformat(),
                    "total": 1 if is_in_station else 0,
                    "ng": 1 if esito == 6 and is_ell_station else 0,
                    "scrap": 1 if esito == 6 and is_scrap_station else 0
                })
                lst[:] = lst[-8:]

        _touch_hourly_fpy()
        _touch_hourly_rwk()
        _touch_hourly_throughput()

        # ===================== 4. Buffer‑ID defect trace  =====================
        if bufferIds:
            with get_mysql_connection() as conn:
                with conn.cursor() as cursor:
                    bufferIds = [b.strip() for b in bufferIds if b and b.strip()]
                    if bufferIds:
                        placeholders = ",".join(["%s"] * len(bufferIds))
                        cursor.execute(
                            f"""
                            SELECT 
                            o.id_modulo,
                            COALESCE(p.id, 0) AS production_id,
                            SUM(p.station_id = 3) AS rwk_count,
                            COALESCE(
                                JSON_ARRAYAGG(
                                    JSON_OBJECT(
                                        'defect_id', od.defect_id,
                                        'defect_type',
                                            CASE 
                                                WHEN od.defect_id = 1 THEN od.defect_type
                                                ELSE COALESCE(d.category, 'Sconosciuto')
                                            END,
                                        'extra_data', IFNULL(od.extra_data,'')
                                    )
                                ),
                                JSON_ARRAY()
                            ) AS defects
                        FROM objects o
                        LEFT JOIN productions p
                            ON p.object_id = o.id
                        AND p.esito = 6
                        LEFT JOIN object_defects od 
                            ON od.production_id = p.id
                        LEFT JOIN defects d 
                            ON d.id = od.defect_id
                        WHERE o.id_modulo IN ({placeholders})
                        GROUP BY o.id_modulo, p.id;
                            """,
                            bufferIds,
                        )
                        data["bufferDefectSummary"] = [
                            {
                                "object_id": row["id_modulo"],
                                "production_id": row["production_id"],
                                "rework_count": int(row["rwk_count"] or 0),
                                "defects": json.loads(row["defects"]) if row["defects"] else [],
                            }
                            for row in cursor.fetchall()
                        ]
        elif station_name == "ELL01":
            data["bufferDefectSummary"] = []

    except Exception:
        logger.exception("Error in _update_snapshot_ell_new()")
        raise

def _update_snapshot_str(
    data: dict,
    station_name: str,
    esito: int,         # kept for signature compatibility; no longer used to gate NG adds
    ts: datetime
) -> None:
    """
    Incrementally update the in-memory STR snapshot using per-module deltas
    from str_visual_snapshot. PLC resets counters after each module, so we
    sum the deltas manually instead of fixed +1 increments.
    Matches the full aggregation logic from _compute_snapshot_str().

    Updated to treat Cell NG as String-equivalent NG (cell_ngs = cell_NG // 10)
    in both totals (IN) and NG counts, so yield reflects cells too.
    """
    cfg = ZONE_SOURCES["STR"]
    current_shift_start, _ = get_shift_window(ts)
    hour = ts.hour

    # Determine current shift label (S1/S2/S3)
    if 6 <= hour < 14:
        current_shift_label = "S1"
    elif 14 <= hour < 22:
        current_shift_label = "S2"
    else:
        current_shift_label = "S3"

    # Station name → station_id
    station_map = {"STR01": 4, "STR02": 5, "STR03": 6, "STR04": 7, "STR05": 8}
    st_id = station_map.get(station_name)
    if not st_id:
        return

    # Fetch latest per-module deltas from DB
    cell_g = cell_ng = string_g = string_ng = 0
    try:
        with get_mysql_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT cell_G, cell_NG, string_G, string_NG
                    FROM str_visual_snapshot
                    WHERE station_id=%s
                    ORDER BY timestamp DESC
                    LIMIT 1
                """, (st_id,))
                row = cursor.fetchone()
                if row:
                    cell_g    = row.get("cell_G")    or 0
                    cell_ng   = row.get("cell_NG")   or 0
                    string_g  = row.get("string_G")  or 0
                    string_ng = row.get("string_NG") or 0
    except Exception as e:
        logger.warning(f"STR snapshot DB read failed for {station_name}: {e}")

    # Convert cell-level NG into string-equivalent NG
    cell_ngs = int(cell_ng / 10)

    # Totals per module
    total_processed = string_g + string_ng + cell_ngs
    total_ng        = string_ng + cell_ngs
    # good strings are only the actual OK strings
    total_good      = string_g

    # Update per-station totals (IN and OUT_NG)
    for i in range(1, 6):
        in_key  = f"station_{i}_in"
        out_key = f"station_{i}_out_ng"
        if in_key not in data:
            data[in_key] = 0
        if out_key not in data:
            data[out_key] = 0
        if station_name in cfg[in_key]:
            data[in_key] += total_processed
        if station_name in cfg[out_key]:
            data[out_key] += total_ng

    # Update yields per station (yield = good / (good + ng) = (in - ng) / in)
    for i in range(1, 6):
        good_i = data.get(f"station_{i}_in", 0) - data.get(f"station_{i}_out_ng", 0)
        ng_i   = data.get(f"station_{i}_out_ng", 0)
        data[f"station_{i}_yield"] = compute_yield(good_i, ng_i)

    # Flags for membership (not gating by esito anymore)
    is_in_station = any(station_name in cfg[f"station_{i}_in"] for i in range(1, 6))
    is_ng_station = any(station_name in cfg[f"station_{i}_out_ng"] for i in range(1, 6))

    # Update shift throughput (total and NG across STR)
    for shift in data.get("shift_throughput", []):
        if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
            if is_in_station:
                shift["total"] += total_processed
            if is_ng_station and total_ng:
                shift["ng"] += total_ng
            break

    # Update STR aggregate yield (all 5 stations)
    for shift in data.get("str_yield_shifts", []):
        if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
            shift["good"]  += total_good
            shift["ng"]    += total_ng
            shift["scrap"]  = shift.get("scrap", 0) + cell_ngs
            shift["yield"]  = compute_yield(shift["good"], shift["ng"])
            break

    # Update Overall yield (same numbers as STR aggregate for now)
    for shift in data.get("overall_yield_shifts", []):
        if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
            shift["good"] += total_good
            shift["ng"]   += total_ng
            shift["yield"] = compute_yield(shift["good"], shift["ng"])
            break

    # Hourly bins (rolling last 8 hours) for both STR and Overall (identical)
    hour_start = ts.replace(minute=0, second=0, microsecond=0)
    hour_label = hour_start.strftime("%H:%M")

    def touch(list_key: str, add_good: int, add_ng: int):
        lst = data.get(list_key, [])
        for entry in lst:
            if entry["hour"] == hour_label:
                entry["good"]  += add_good
                entry["ng"]    += add_ng
                entry["yield"]  = compute_yield(entry["good"], entry["ng"])
                break
        else:
            new_entry = {
                "hour":  hour_label,
                "start": hour_start.isoformat(),
                "end":   (hour_start + timedelta(hours=1)).isoformat(),
                "good":  add_good,
                "ng":    add_ng,
            }
            new_entry["yield"] = compute_yield(new_entry["good"], new_entry["ng"])
            lst.append(new_entry)
        data[list_key] = lst[-8:]  # keep last 8 bins

    if is_in_station and total_processed:
        # include cell NG in NG for bins
        touch("str_yield_last_8h",      total_good, total_ng)
        touch("overall_yield_last_8h",  total_good, total_ng)

    # Per-station hourly throughput
    per_station_key = "hourly_throughput_per_station"
    station_idx = list(station_map).index(station_name) + 1  # STR01 → 1, ... STR05 → 5

    if per_station_key not in data:
        data[per_station_key] = {i: [] for i in range(1, 6)}  # 1–5

    station_bins = data[per_station_key][station_idx]
    for entry in station_bins:
        if entry["hour"] == hour_label:
            entry["ok"] += total_good
            entry["ng"] += total_ng
            break
    else:
        station_bins.append({
            "hour":  hour_label,
            "start": hour_start.isoformat(),
            "end":   (hour_start + timedelta(hours=1)).isoformat(),
            "ok":    total_good,
            "ng":    total_ng,
        })
    data[per_station_key][station_idx] = station_bins[-8:]  # Keep only last 8

def _update_snapshot_lmn(
    data: dict,
    station_name: str,
    esito: int,
    ts: datetime
) -> None:
    """
    Incrementally update the LMN zone snapshot in-memory, based on a single new
    production event at `station_name` with outcome `esito` and timestamp `ts`.

    It updates:
      - per-station totals (in / out_ng) and yields
      - current shift throughput (total, ng)
      - last 8h throughput bars
      - last 8h yields per station

    NOTE: 'fermi_data' and 'top_defects_*' are recomputed in full in _compute_snapshot_lmn().
    """
    cfg = ZONE_SOURCES["LMN"]

    # --- Current shift label + boundaries (for matching the correct shift bucket)
    current_shift_start, _ = get_shift_window(ts)
    current_shift_label = (
        "S1" if 6 <= current_shift_start.hour < 14 else
        "S2" if 14 <= current_shift_start.hour < 22 else
        "S3"
    )

    # --- 1) Update counters (station_1_in / station_2_in, station_1_out_ng / station_2_out_ng)
    if station_name in cfg["station_1_in"]:
        data["station_1_in"] += 1
    elif station_name in cfg["station_2_in"]:
        data["station_2_in"] += 1

    if esito == 6:
        if station_name in cfg["station_1_out_ng"]:
            data["station_1_out_ng"] += 1
        elif station_name in cfg["station_2_out_ng"]:
            data["station_2_out_ng"] += 1

    # --- 2) Recompute yields
    s1_good = data["station_1_in"] - data["station_1_out_ng"]
    s2_good = data["station_2_in"] - data["station_2_out_ng"]
    data["station_1_yield"] = compute_yield(s1_good, data["station_1_out_ng"])
    data["station_2_yield"] = compute_yield(s2_good, data["station_2_out_ng"])

    # --- 3) Update shift throughput (sum of both IN stations; NG from QC stations only)
    is_in_station = station_name in cfg["station_1_in"] or station_name in cfg["station_2_in"]
    is_qc_station = station_name in cfg["station_1_out_ng"] or station_name in cfg["station_2_out_ng"]

    for shift in data["shift_throughput"]:
        if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
            if is_in_station:
                shift["total"] += 1
            if esito == 6 and is_qc_station:
                shift["ng"] += 1
            break

    # --- 4) Update yield per shift (each station's QC contributes to its own series)
    def _update_shift_yield(station_yield_shifts: list[dict], relevant: bool) -> None:
        if not relevant:
            return
        for shift in station_yield_shifts:
            if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
                if esito == 6:
                    shift["ng"] += 1
                else:
                    shift["good"] += 1
                shift["yield"] = compute_yield(shift["good"], shift["ng"])
                break

    _update_shift_yield(data["station_1_yield_shifts"], station_name in cfg["station_1_out_ng"])
    _update_shift_yield(data["station_2_yield_shifts"], station_name in cfg["station_2_out_ng"])

    # --- 5) Update hourly bins (last_8h_throughput + per-station last_8h yields)
    hour_start = ts.replace(minute=0, second=0, microsecond=0)
    hour_label = hour_start.strftime("%H:%M")

    def _touch_hourly(list_key: str) -> None:
        lst = data[list_key]
        for entry in lst:
            if entry["hour"] == hour_label:
                if list_key == "last_8h_throughput":
                    entry["total"] += 1 if is_in_station else entry["total"]
                    if esito == 6 and is_qc_station:
                        entry["ng"] += 1
                else:
                    if esito == 6:
                        entry["ng"] += 1
                    else:
                        entry["good"] += 1
                    entry["yield"] = compute_yield(entry["good"], entry["ng"])
                break
        else:
            # Create a new hour entry
            new_entry: Dict[str, Any] = {
                "hour": hour_label,
                "start": hour_start.isoformat(),
                "end": (hour_start + timedelta(hours=1)).isoformat(),
            }
            if list_key == "last_8h_throughput":
                new_entry.update({
                    "total": 1 if is_in_station else 0,
                    "ng": 1 if (esito == 6 and is_qc_station) else 0
                })
            else:
                new_entry.update({
                    "good": 0 if esito == 6 else 1,
                    "ng":   1 if esito == 6 else 0,
                })
                new_entry["yield"] = compute_yield(new_entry["good"], new_entry["ng"])
            lst.append(new_entry)
            # Keep only the last 8 bins
            lst[:] = lst[-8:]

    # Throughput only changes if we got an IN event or an NG at a QC station
    if is_in_station or (esito == 6 and is_qc_station):
        _touch_hourly("last_8h_throughput")

    # Per-station hourly yields are driven by their QC stations
    if station_name in cfg["station_1_out_ng"]:
        _touch_hourly("station_1_yield_last_8h")
    elif station_name in cfg["station_2_out_ng"]:
        _touch_hourly("station_2_yield_last_8h")

def _update_snapshot_deltamax(
    data: dict,
    station_name: str,
    esito: int,
    ts: datetime,
    bufferIds: List[str] = [],
    object_id: Optional[str] = None,
    reentered: bool = False
    ) -> None:

    def _get_shift_label_and_start(ts_str: str):
        ts = datetime.fromisoformat(ts_str)
        shift_start, _ = get_shift_window(ts)
        label = (
            "S1" if 6 <= shift_start.hour < 14 else
            "S2" if 14 <= shift_start.hour < 22 else
            "S3"
        )
        return label, shift_start

    def _get_hour_label(ts_str: str) -> str:
        ts = datetime.fromisoformat(ts_str)
        return ts.replace(minute=0, second=0, microsecond=0).strftime("%H:%M")

    try:
        cfg = ZONE_SOURCES["DELTAMAX"]
        current_shift_start, _ = get_shift_window(ts)
        current_shift_label = (
            "S1" if 6 <= current_shift_start.hour < 14 else
            "S2" if 14 <= current_shift_start.hour < 22 else
            "S3"
        )

        # ———————————————————————————————————————————————————————————————
        # Safely wrap sets/dicts expected to be updated
        data["latest_esito"] = data.get("latest_esito", {})
        data["latest_ts"] = data.get("latest_ts", {})
        data["s1_ng_set"] = set(data.get("s1_ng_set", []))
        data["reworked_set"] = set(data.get("reworked_set", []))
        data["good_after_rework_set"] = set(data.get("good_after_rework_set", []))
        data["s2_entry_set"] = set(data.get("s2_entry_set", []))
        data["multi_entry_set"] = set(data.get("multi_entry_set", []))
        data["s1_success_set"] = set(data.get("s1_success_set", []))

        # Critical one: must be defaultdict(int) to avoid crash
        data["s1_entry_count"] = defaultdict(int, data.get("s1_entry_count", {}))

        # ———————————————————————————————————————————————————————————————

        # 1. Update Counters
        if not reentered:
            if station_name in cfg["station_1_in"]:
                data["station_1_in"] += 1
                data["station_1_r0_in"] += 1
            elif station_name in cfg["station_2_in"]:
                data["station_2_in"] += 1
                data["station_2_r0_in"] += 1
        
            if esito == 6:
                if station_name in cfg['station_qg_1']:
                    data["station_1_ng_qg2"] += 1
                    data["ng_tot"] += 1
                elif station_name in cfg['station_qg_2']:
                    data["station_1_ng_qg2"] += 1
                    data["ng_tot"] += 1
                elif station_name in cfg["station_1_out_ng"]:
                    data["station_1_r0_ng"] += 1
                    data["station_1_out_ng"] += 1
                    data["ng_tot"] += 1
                elif station_name in cfg["station_2_out_ng"]:
                    data["station_2_r0_ng"] += 1
                    data["station_2_out_ng"] += 1
        
        if reentered:
            if esito == 1:
                if station_name in cfg["station_1_out_ng"]:
                    data["station_1_out_ng"] -= 1
                    data["ng_tot"] -= 1

        # 1a. Track “distinct modules that hit NG at station 1”:
        if station_name in cfg["station_2_in"] and esito == 5:
            data["reworked_set"].add(object_id)

        # 1c. Track “of those, who then passed at ELL”:
        if station_name in cfg["station_1_in"] and esito != 6:
            if object_id in data["reworked_set"]:
                data["good_after_rework_set"].add(object_id)

        # When passing station_1_in
        if station_name in cfg["station_1_in"] and object_id:
            data["s1_entry_count"][object_id] += 1
            if data["s1_entry_count"][object_id] > 1:
                data["multi_entry_set"].add(object_id)

        if object_id in data["multi_entry_set"] and esito == 1:
            data["s1_success_set"].add(object_id)

        if station_name in cfg["station_2_in"]:
            if object_id:
                data["s2_entry_set"].add(object_id)

        # 2 Yield
        # FPY = good on first pass / total first-pass
        s1_good_r0 = data["station_1_r0_in"] - data["station_1_r0_ng"]
        data["FPY_yield"] = compute_yield(s1_good_r0, data["station_1_r0_ng"])

        #RWK = Good after being Reworked / total in

        # Always track latest esito for RWK calculation
        if station_name in cfg["station_1_in"] + cfg["station_1_out_ng"]:
            data["latest_esito"][object_id] = esito
            data["latest_ts"][object_id] = ts.isoformat()

        final_statuses = [
            es for oid, es in data["latest_esito"].items()
            if oid in data["latest_ts"] and _get_shift_label_and_start(data["latest_ts"][oid]) == (current_shift_label, current_shift_start)
        ]

        final_good = sum(1 for es in final_statuses if es != 6)
        final_ng   = sum(1 for es in final_statuses if es == 6)

        data["RWK_yield"] = compute_yield(final_good, final_ng)

        # ———————————————————————————————————————————————————————————————
        # Gauge 1: re-entries / station_2_in
        denom = len(data["s2_entry_set"])
        num_multi = len(data["multi_entry_set"])
        data["value_gauge_1"] = round((num_multi / denom) * 100, 2) if denom else 0.0

        # Gauge 2: multi-entry modules that ended in esito=1 / multi-entry
        num_success = len(data["s1_success_set"])
        data["value_gauge_2"] = round((num_success / num_multi) * 100, 2) if num_multi else 0.0
        # ———————————————————————————————————————————————————————————————

        # 5 Update Throughput
        def update_shift_throughput(thr_data):
            is_in_station = station_name in cfg["station_1_in"] or station_name in cfg["station_2_in"]
            is_ell_station = station_name in cfg["station_1_out_ng"]
            is_scrap_station = station_name in cfg["station_2_out_ng"]

            for shift in thr_data:
                if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
                    if is_in_station:
                        shift["total"] += 1
                    if esito == 6 and is_ell_station:
                        shift["ng"] += 1
                    if esito == 6 and is_scrap_station:
                        shift["scrap"] += 1
                    break

        update_shift_throughput(data["shift_throughput"])

        # 6 Update shift yields
        def update_shift_yield_fpy(fpy_shift_data, is_r0_at_s1: bool):
            if not is_r0_at_s1:
                return
            for shift in fpy_shift_data:
                if shift["label"] == current_shift_label and shift["start"] == current_shift_start.isoformat():
                    if esito == 6:
                        shift["ng"] += 1
                    else:
                        shift["good"] += 1
                    shift["yield"] = compute_yield(shift["good"], shift["ng"])
                    break

        def update_shift_yield_rwk(rwk_shift_data, station_name: str, object_id: Optional[str], esito: int):
            if object_id is None:
                return
            # Track latest esito by object_id globally
            latest_esito = data["latest_esito"]
            latest_esito[object_id] = esito

            # Recompute good/ng per shift
            for shift in rwk_shift_data:
                start_ts = shift["start"]
                if shift["label"] == current_shift_label and start_ts == current_shift_start.isoformat():
                    latest_ts = data["latest_ts"]
                    latest_esito = data["latest_esito"]

                    relevant = [
                        oid for oid in latest_ts
                        if _get_shift_label_and_start(latest_ts[oid]) == (current_shift_label, current_shift_start)
                    ]

                    final_good = sum(1 for oid in relevant if latest_esito.get(oid) != 6)
                    final_ng   = len(relevant) - final_good

                    shift["good"] = final_good
                    shift["ng"] = final_ng
                    shift["yield"] = compute_yield(final_good, final_ng)
                    break

        # Update per-shift FPY
        update_shift_yield_fpy(
            data["FPY_yield_shifts"],
            not reentered and station_name in cfg["station_1_out_ng"]
        )

        # Update per-shift RWK
        update_shift_yield_rwk(
            data["RWK_yield_shifts"],
            station_name,
            object_id,
            esito
        )

        # 7 Update hourly bins
        hour_start = ts.replace(minute=0, second=0, microsecond=0)
        hour_label = hour_start.strftime("%H:%M")

        def _touch_hourly_fpy():
            if not reentered and station_name in cfg["station_1_out_ng"]:
                lst = data["FPY_yield_last_8h"]
                for entry in lst:
                    if entry["hour"] == hour_label:
                        if esito == 6:
                            entry["ng"] += 1
                        else:
                            entry["good"] += 1
                        entry["yield"] = compute_yield(entry["good"], entry["ng"])
                        break
                else:
                    data["FPY_yield_last_8h"].append({
                        "hour": hour_label,
                        "start": hour_start.isoformat(),
                        "end": (hour_start + timedelta(hours=1)).isoformat(),
                        "good": 0 if esito == 6 else 1,
                        "ng": 1 if esito == 6 else 0,
                        "yield": compute_yield(0 if esito == 6 else 1, 1 if esito == 6 else 0)
                    })
                    data["FPY_yield_last_8h"][:] = data["FPY_yield_last_8h"][-8:]

        def _touch_hourly_rwk():
            if object_id is None:
                return
            # always update RWK using latest_esito
            lst = data["RWK_yield_last_8h"]

            latest_ts = data["latest_ts"]
            latest_esito = data["latest_esito"]

            relevant = [
                oid for oid in latest_ts
                if _get_hour_label(latest_ts[oid]) == hour_label
            ]

            final_good = sum(1 for oid in relevant if latest_esito.get(oid) != 6)
            final_ng   = len(relevant) - final_good

            yield_val = compute_yield(final_good, final_ng)

            for entry in lst:
                if entry["hour"] == hour_label:
                    entry["good"] = final_good
                    entry["ng"] = final_ng
                    entry["yield"] = yield_val
                    break
            else:
                data["RWK_yield_last_8h"].append({
                    "hour": hour_label,
                    "start": hour_start.isoformat(),
                    "end": (hour_start + timedelta(hours=1)).isoformat(),
                    "good": final_good,
                    "ng": final_ng,
                    "yield": yield_val
                })
                data["RWK_yield_last_8h"][:] = data["RWK_yield_last_8h"][-8:]

        def _touch_hourly_throughput():
            is_in_station = station_name in cfg["station_1_in"] or station_name in cfg["station_2_in"]
            is_ell_station = station_name in cfg["station_1_out_ng"]
            is_scrap_station = station_name in cfg["station_2_out_ng"]

            if not (is_in_station or (esito == 6 and (is_ell_station or is_scrap_station))):
                return

            lst = data["last_8h_throughput"]
            for entry in lst:
                if entry["hour"] == hour_label:
                    if is_in_station:
                        entry["total"] += 1
                    if esito == 6 and is_ell_station:
                        entry["ng"] += 1
                    if esito == 6 and is_scrap_station:
                        entry["scrap"] += 1
                    break
            else:
                lst.append({
                    "hour": hour_label,
                    "start": hour_start.isoformat(),
                    "end": (hour_start + timedelta(hours=1)).isoformat(),
                    "total": 1 if is_in_station else 0,
                    "ng": 1 if esito == 6 and is_ell_station else 0,
                    "scrap": 1 if esito == 6 and is_scrap_station else 0
                })
                lst[:] = lst[-8:]

        _touch_hourly_fpy()
        _touch_hourly_rwk()
        _touch_hourly_throughput()

        # ===================== 4. Buffer‑ID defect trace  =====================
        if bufferIds:
            with get_mysql_connection() as conn:
                with conn.cursor() as cursor:
                    bufferIds = [b.strip() for b in bufferIds if b and b.strip()]
                    if bufferIds:
                        placeholders = ",".join(["%s"] * len(bufferIds))
                        cursor.execute(
                            f"""
                            SELECT 
                            o.id_modulo,
                            COALESCE(p.id, 0) AS production_id,
                            SUM(p.station_id = 40) AS rwk_count,
                            COALESCE(
                                JSON_ARRAYAGG(
                                    JSON_OBJECT(
                                        'defect_id', od.defect_id,
                                        'defect_type',
                                            CASE 
                                                WHEN od.defect_id = 1 THEN od.defect_type
                                                ELSE COALESCE(d.category, 'Sconosciuto')
                                            END,
                                        'extra_data', IFNULL(od.extra_data,'')
                                    )
                                ),
                                JSON_ARRAY()
                            ) AS defects
                        FROM objects o
                        LEFT JOIN productions p
                            ON p.object_id = o.id
                        AND p.esito = 6
                        LEFT JOIN object_defects od 
                            ON od.production_id = p.id
                        LEFT JOIN defects d 
                            ON d.id = od.defect_id
                        WHERE o.id_modulo IN ({placeholders})
                        GROUP BY o.id_modulo, p.id;
                            """,
                            bufferIds,
                        )
                        data["bufferDefectSummary"] = [
                            {
                                "object_id": row["id_modulo"],
                                "production_id": row["production_id"],
                                "rework_count": int(row["rwk_count"] or 0),
                                "defects": json.loads(row["defects"]) if row["defects"] else [],
                            }
                            for row in cursor.fetchall()
                        ]

    except Exception:
        logger.exception("Error in _update_snapshot_DELTAMAX()")
        raise
