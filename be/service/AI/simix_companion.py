import logging

logger = logging.getLogger(__name__)

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.state import global_state
from service.helpers.visual_helper import load_targets

ZONES = ["AIN"]

def detect_yield_drop(zone: str, threshold: float = 0.07):
    try:
        snapshot = global_state.visual_data[zone]
        targets = load_targets()
        target_yield = targets.get("yield_target", 90) / 100  # convert to 0.X

        alerts = []

        # Detect station yield drops
        for key in snapshot:
            if key.endswith("_yield") and not key.startswith("__"):
                st_name = key.replace("_yield", "")
                current_yield = snapshot[key]
                shift_history = snapshot.get(f"{st_name}_yield_shifts", [])
                if not shift_history:
                    continue

                # Calculate avg of past 3 shift yields
                shift_avg = sum(shift["yield"] for shift in shift_history) / len(shift_history)

                # Compare with both reference values
                diff_target = target_yield - current_yield
                diff_shift = shift_avg - current_yield

                if diff_target > threshold or diff_shift > threshold:
                    alerts.append({
                        "station": st_name,
                        "current": round(current_yield * 100, 1),
                        "target": round(target_yield * 100, 1),
                        "shift_avg": round(shift_avg * 100, 1),
                        "drop": round(max(diff_target, diff_shift) * 100, 1)
                    })

        return alerts

    except Exception as e:
        logger.exception(f"detect_yield_drop() FAILED for zone={zone}: {e}")
        return []

def detect_anomalous_cycle_times(zone: str, min_threshold: float = 5.0):
    try:
        snapshot = global_state.visual_data[zone]
        results = []

        if "speed_ratio" in snapshot:
            for entry in snapshot["speed_ratio"]:
                current = entry.get("currentSec", 0)
                median = entry.get("medianSec", 0)
                if current == 0 or median == 0:
                    continue

                # Anomalia se current << median o < soglia assoluta
                if current < min_threshold or current < 0.6 * median:
                    results.append({
                        "zone": zone,
                        "median": round(median, 1),
                        "current": round(current, 1),
                        "ratio": round(current / median, 2),
                        "type": "too_fast"
                    })

                elif current > 1.8 * median:
                    results.append({
                        "zone": zone,
                        "median": round(median, 1),
                        "current": round(current, 1),
                        "ratio": round(current / median, 2),
                        "type": "too_slow"
                    })

        return results

    except Exception as e:
        logger.exception(f"detect_anomalous_cycle_times() FAILED for zone={zone}: {e}")
        return []

def run_simix_check():
    for zone in ZONES:
        yield_alerts = detect_yield_drop(zone)
        for alert in yield_alerts:
            print(f"⚠️ Yield drop in {zone} → {alert}")

        anomalies = detect_anomalous_cycle_times(zone)
        for anomaly in anomalies:
            print(f"⚠️ Anomaly in {zone} → {anomaly}")

