import asyncio
import logging
from datetime import datetime, timedelta, time as dt_time
from fastapi import BackgroundTasks

import os, sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection
from service.config.settings import load_settings
from service.routes.export_routes import export_objects

logger = logging.getLogger("PMS")


def _run_export(start_dt: datetime, end_dt: datetime):
    conn = get_mysql_connection()
    with conn.cursor() as cursor:
        cursor.execute(
            """
            SELECT p.id AS production_id, o.id_modulo
            FROM productions p
            JOIN objects o ON p.object_id = o.id
            WHERE p.end_time >= %s AND p.end_time <= %s
            """,
            (start_dt, end_dt),
        )
        rows = cursor.fetchall()

    if not rows:
        logger.info("Daily export: no data found for %s - %s", start_dt, end_dt)
        return

    production_ids = [row["production_id"] for row in rows]
    modulo_ids = [row["id_modulo"] for row in rows]

    settings = load_settings()
    full_history = settings.get("always_export_history", False)

    data = {
        "filters": [],
        "production_ids": production_ids,
        "modulo_ids": modulo_ids,
        "fullHistory": full_history,
        "progressId": None,
    }

    result = export_objects(BackgroundTasks(), data)
    filename = result.get("filename") if isinstance(result, dict) else None
    if filename:
        logger.info("Daily export generated %s", filename)
    else:
        logger.info("Daily export completed with no file")


async def daily_export_loop():
    while True:
        now = datetime.now()
        next_run = datetime.combine(now.date(), dt_time(hour=6))
        if now >= next_run:
            next_run += timedelta(days=1)
        await asyncio.sleep((next_run - now).total_seconds())

        start_dt = next_run - timedelta(days=1)
        end_dt = next_run - timedelta(seconds=1)

        logger.info(
            "Starting scheduled export for range %s - %s", start_dt, end_dt
        )
        try:
            await asyncio.to_thread(_run_export, start_dt, end_dt)
        except Exception as e:
            logger.error("Scheduled export failed: %s", e)
        await asyncio.sleep(1)
