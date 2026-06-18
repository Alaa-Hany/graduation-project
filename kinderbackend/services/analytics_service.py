"""Backward-compatibility shim.

All logic has been extracted into:
  - AnalyticsIngestionService  (services/analytics_ingestion_service.py)
  - AnalyticsReportService     (services/analytics_report_service.py)

Existing callers that import ``analytics_service`` or the module-level
helper functions continue to work without changes.
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from models import User
from services.analytics_ingestion_service import (
    COMPLETION_EVENT_TYPES,
    TRACKED_EVENT_TYPES,
    AnalyticsIngestionService,
)
from services.analytics_report_service import AnalyticsReportService

__all__ = [
    "AnalyticsIngestionService",
    "AnalyticsReportService",
    "AnalyticsService",
    "analytics_service",
    "TRACKED_EVENT_TYPES",
    "COMPLETION_EVENT_TYPES",
    "record_activity_event",
    "record_session_log",
    "build_basic_report",
    "build_advanced_report",
]


class AnalyticsService(AnalyticsIngestionService, AnalyticsReportService):
    """Combined service kept for backward compatibility.

    Prefer using AnalyticsIngestionService or AnalyticsReportService directly
    in new code.
    """


analytics_service = AnalyticsService()


def record_activity_event(*, db: Session, parent: User, payload) -> dict:
    return analytics_service.record_activity_event(db=db, parent=parent, payload=payload)


def record_session_log(*, db: Session, parent: User, payload) -> dict:
    return analytics_service.record_session_log(db=db, parent=parent, payload=payload)


def build_basic_report(*, db: Session, user: User) -> dict:
    return analytics_service.build_basic_report(db=db, user=user)


def build_advanced_report(*, db: Session, user: User) -> dict:
    return analytics_service.build_advanced_report(db=db, user=user)
