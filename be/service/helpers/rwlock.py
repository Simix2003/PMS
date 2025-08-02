from threading import Condition, Lock
from contextlib import contextmanager


class ReadWriteLock:
    """A simple reader-writer lock allowing concurrent reads."""

    def __init__(self) -> None:
        self._lock = Lock()
        self._read_ready = Condition(self._lock)
        self._readers = 0
        self._writer = False

    def acquire_read(self) -> None:
        with self._lock:
            while self._writer:
                self._read_ready.wait()
            self._readers += 1

    def release_read(self) -> None:
        with self._lock:
            self._readers -= 1
            if self._readers == 0:
                self._read_ready.notify_all()

    def acquire_write(self) -> None:
        with self._lock:
            while self._writer or self._readers > 0:
                self._read_ready.wait()
            self._writer = True

    def release_write(self) -> None:
        with self._lock:
            self._writer = False
            self._read_ready.notify_all()

    @contextmanager
    def read_lock(self):
        self.acquire_read()
        try:
            yield
        finally:
            self.release_read()

    @contextmanager
    def write_lock(self):
        self.acquire_write()
        try:
            yield
        finally:
            self.release_write()
