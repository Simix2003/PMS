import os
import sys
from unittest.mock import Mock
from threading import RLock

import pytest

# Ensure 'service' package is importable
sys.path.append(os.path.join(os.path.dirname(__file__), ".."))

from service.controllers import plc as plc_module
from service.controllers.plc import PLCConnection


class DummyClient:
    def __init__(self, connected=True, probe_fails=False, has_cpu=False):
        self._connected = connected
        self._probe_fails = probe_fails
        if has_cpu:
            self.get_cpu_state = self._get_cpu_state

    def get_connected(self):
        return self._connected

    def _get_cpu_state(self):
        if self._probe_fails:
            raise Exception("probe fail")
        return 0

    def db_read(self, db, start, size):
        if self._probe_fails:
            raise Exception("probe fail")
        return b"\x00" * size


def make_plc(client):
    plc = PLCConnection.__new__(PLCConnection)
    plc.lock = RLock()
    plc.client = client
    plc.ip_address = "1.2.3.4"
    return plc


def test_is_connected_true_probe_success(monkeypatch):
    monkeypatch.setattr(plc_module, "PROBE_DB", 1)
    monkeypatch.setattr(plc_module, "PROBE_OFFSET", 0)
    client = DummyClient(connected=True, probe_fails=False)
    plc = make_plc(client)
    assert plc.is_connected() is True


def test_is_connected_false_on_disconnected(monkeypatch):
    monkeypatch.setattr(plc_module, "PROBE_DB", 1)
    monkeypatch.setattr(plc_module, "PROBE_OFFSET", 0)
    client = DummyClient(connected=False)
    plc = make_plc(client)
    assert plc.is_connected() is False


def test_is_connected_false_on_probe_fail(monkeypatch, caplog):
    monkeypatch.setattr(plc_module, "PROBE_DB", 1)
    monkeypatch.setattr(plc_module, "PROBE_OFFSET", 0)
    client = DummyClient(connected=True, probe_fails=True)
    plc = make_plc(client)
    with caplog.at_level("ERROR"):
        assert plc.is_connected() is False
        assert any("liveness probe failed" in rec.message for rec in caplog.records)
