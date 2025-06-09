import asyncio
import logging
from datetime import datetime
import os
import sys

# Extend Python path for module resolution
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.utils.visual_summary_logic import compute_and_store_visual_summary

logger = logging.getLogger("VisualSummary")

async def visual_summary_background_task():
    while True:
        try:
            logger.info("🔄 Computing and storing visual summary")
            await compute_and_store_visual_summary()
            logger.info("✅ Visual summary updated at %s", datetime.now())
        except Exception as e:
            logger.error(f"❌ Failed to update visual summary: {e}")
        
        await asyncio.sleep(1800)  # 30 minutes
        #await asyncio.sleep(30)  # 1 minute
