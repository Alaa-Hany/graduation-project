"""Tests for the analytics_service backward-compatibility shim.

The real ingestion/report logic is covered elsewhere; here we only verify the
module-level helper wrappers delegate to the shared ``analytics_service``
singleton with the expected arguments, and that the combined class exposes both
mixins' behaviour.
"""

import services.analytics_service as analytics_module
from services.analytics_ingestion_service import AnalyticsIngestionService
from services.analytics_report_service import AnalyticsReportService
from services.analytics_service import AnalyticsService, analytics_service


def _recorder(calls, return_value):
    def _fn(**kwargs):
        calls["args"] = kwargs
        return return_value

    return _fn


def test_combined_service_inherits_both_mixins():
    assert isinstance(analytics_service, AnalyticsIngestionService)
    assert isinstance(analytics_service, AnalyticsReportService)
    assert issubclass(AnalyticsService, AnalyticsIngestionService)
    assert issubclass(AnalyticsService, AnalyticsReportService)


def test_record_activity_event_delegates(monkeypatch):
    calls = {}
    monkeypatch.setattr(
        analytics_module.analytics_service,
        "record_activity_event",
        _recorder(calls, {"ok": True}),
    )
    result = analytics_module.record_activity_event(
        db="DB", parent="PARENT", payload="PAYLOAD"
    )
    assert result == {"ok": True}
    assert calls["args"] == {"db": "DB", "parent": "PARENT", "payload": "PAYLOAD"}


def test_record_session_log_delegates(monkeypatch):
    calls = {}
    monkeypatch.setattr(
        analytics_module.analytics_service,
        "record_session_log",
        _recorder(calls, {"ok": True}),
    )
    result = analytics_module.record_session_log(
        db="DB", parent="PARENT", payload="PAYLOAD"
    )
    assert result == {"ok": True}
    assert calls["args"] == {"db": "DB", "parent": "PARENT", "payload": "PAYLOAD"}


def test_build_basic_report_delegates(monkeypatch):
    calls = {}
    monkeypatch.setattr(
        analytics_module.analytics_service,
        "build_basic_report",
        _recorder(calls, {"report": "basic"}),
    )
    result = analytics_module.build_basic_report(db="DB", user="USER")
    assert result == {"report": "basic"}
    assert calls["args"] == {"db": "DB", "user": "USER"}


def test_build_advanced_report_delegates(monkeypatch):
    calls = {}
    monkeypatch.setattr(
        analytics_module.analytics_service,
        "build_advanced_report",
        _recorder(calls, {"report": "advanced"}),
    )
    result = analytics_module.build_advanced_report(db="DB", user="USER")
    assert result == {"report": "advanced"}
    assert calls["args"] == {"db": "DB", "user": "USER"}
