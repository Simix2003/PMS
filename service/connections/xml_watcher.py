# service/tasks/xml_watcher.py

from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import logging
import asyncio

import os
import sys

# Extend Python path for module resolution
sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from service.config.config import XML_FOLDER_PATH
from service.tasks.new_xml import handle_new_xml_file

logger = logging.getLogger("PMS")

on_new_file = lambda filepath: handle_new_xml_file(filepath)

class XMLFileHandler(FileSystemEventHandler):
    def __init__(self, on_new_file):
        super().__init__()
        self.on_new_file = on_new_file

    def on_created(self, event):
        if not event.is_directory and event.src_path.endswith('.xml'): # type: ignore
            self.on_new_file(event.src_path)

async def watch_folder_for_new_xml():
    """Uses watchdog to react to new XML files in real-time."""
    event_handler = XMLFileHandler(on_new_file)
    observer = Observer()
    observer.schedule(event_handler, XML_FOLDER_PATH, recursive=False)

    # Start the observer in a background thread
    await asyncio.to_thread(observer.start)
    logger.info(f"👀 Watching folder (non-polling): {XML_FOLDER_PATH}")

    try:
        while True:
            await asyncio.sleep(1)  # Keep the coroutine alive
    finally:
        observer.stop()
        await asyncio.to_thread(observer.join)
