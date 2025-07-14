import asyncio
import logging

logger = logging.getLogger(__name__)

class DBWriteQueue:
    """Simple asyncio-based queue for DB write operations."""

    def __init__(self) -> None:
        self.queue: asyncio.Queue = asyncio.Queue()
        self.worker_task: asyncio.Task | None = None

    def start(self) -> None:
        """Start background worker task."""
        if not self.worker_task:
            self.worker_task = asyncio.create_task(self._worker())

    async def enqueue(self, func, *args, **kwargs) -> None:
        """Add a coroutine function to the queue."""
        await self.queue.put((func, args, kwargs))

    async def _worker(self) -> None:
        while True:
            func, args, kwargs = await self.queue.get()
            try:
                await func(*args, **kwargs)
            except Exception as e:  # pragma: no cover - best effort logging
                logger.error(f"DB write task failed: {e}")
            finally:
                self.queue.task_done()
