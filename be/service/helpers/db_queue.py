import asyncio
import logging

logger = logging.getLogger(__name__)

class DBWriteQueue:
    """Asyncio-based queue with graceful shutdown and retry logic for DB writes."""

    def __init__(self, max_retries: int = 3, timeout: float = 5.0) -> None:
        self.queue: asyncio.Queue = asyncio.Queue()
        self.worker_task: asyncio.Task | None = None
        self._shutdown = asyncio.Event()
        self.max_retries = max_retries
        self.timeout = timeout

    def start(self) -> None:
        """Start background worker task."""
        if not self.worker_task:
            self.worker_task = asyncio.create_task(self._worker())

    async def enqueue(self, func, *args, **kwargs) -> None:
        """Add a coroutine function to the queue."""
        await self.queue.put((func, args, kwargs))

    async def shutdown(self) -> None:
        """Stop accepting new tasks and wait for queue to drain."""
        self._shutdown.set()
        await self.queue.join()  # Wait for all tasks to finish
        if self.worker_task:
            self.worker_task.cancel()
            try:
                await self.worker_task
            except asyncio.CancelledError:
                pass

    async def _worker(self) -> None:
        while not self._shutdown.is_set():
            try:
                func, args, kwargs = await asyncio.wait_for(self.queue.get(), timeout=1)
            except asyncio.TimeoutError:
                continue  # Allows checking for shutdown periodically
            try:
                for attempt in range(1, self.max_retries + 1):
                    try:
                        await asyncio.wait_for(func(*args, **kwargs), timeout=self.timeout)
                        break  # Success
                    except asyncio.TimeoutError:
                        logger.warning(f"Task timed out (attempt {attempt}): {func.__name__}")
                    except Exception as e:
                        logger.warning(f"Task failed (attempt {attempt}): {e}")
                        await asyncio.sleep(1)
                else:
                    logger.error(f"Task permanently failed after {self.max_retries} attempts: {func.__name__}")
            except Exception as e:
                logger.error(f"Unexpected DB queue error: {e}")
            finally:
                self.queue.task_done()
