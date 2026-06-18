from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta
from math import floor
from typing import Iterable

from fastapi import HTTPException
from sqlalchemy import case, func
from sqlalchemy.orm import Session

from core.time_utils import utc_start_of_day, utc_today
from models import (
    ChildActivityEvent,
    ChildProfile,
    ChildSessionLog,
    Notification,
    PaymentMethod,
    SupportTicket,
    User,
)

COMPLETION_EVENT_TYPES = {"activity_completed", "lesson_completed"}
TRACKED_EVENT_TYPES = {
    "activity_completed",
    "lesson_completed",
    "mood_entry",
    "achievement_unlocked",
}


class AnalyticsReportService:
    @staticmethod
    def _start_of_day(day: date) -> datetime:
        return utc_start_of_day(day)

    def _children_for_parent(self, db: Session, parent_id: int) -> list[ChildProfile]:
        return (
            db.query(ChildProfile)
            .filter(
                ChildProfile.parent_id == parent_id,
                ChildProfile.deleted_at.is_(None),
            )
            .order_by(ChildProfile.created_at.desc(), ChildProfile.id.desc())
            .all()
        )

    def _children_for_report(
        self,
        *,
        db: Session,
        user: User,
        child_id: int | None = None,
    ) -> list[ChildProfile]:
        children = self._children_for_parent(db, user.id)
        if child_id is None:
            return children
        for child in children:
            if child.id == child_id:
                return [child]
        raise HTTPException(status_code=404, detail="Child not found")

    @staticmethod
    def _serialize_child(child: ChildProfile) -> dict:
        return {
            "id": child.id,
            "name": child.name,
            "age": child.age,
            "avatar": child.avatar,
            "is_active": child.is_active,
            "created_at": child.created_at.isoformat() if child.created_at else None,
            "updated_at": child.updated_at.isoformat() if child.updated_at else None,
        }

    @staticmethod
    def _daily_points_template(days: int) -> list[dict]:
        today = utc_today()
        points = []
        for offset in range(days - 1, -1, -1):
            day = today - timedelta(days=offset)
            points.append(
                {
                    "date": day.isoformat(),
                    "screen_time_minutes": 0,
                    "activities_completed": 0,
                    "lessons_completed": 0,
                    "data_available": False,
                }
            )
        return points

    def _aggregate_daily_points(
        self,
        *,
        db: Session,
        child_ids: Iterable[int],
        days: int,
    ) -> tuple[list[dict], dict]:
        child_ids = list(child_ids)
        points = self._daily_points_template(days)
        if not child_ids:
            return points, {"has_sessions": False, "has_events": False}

        point_by_date = {item["date"]: item for item in points}
        start_day = utc_today() - timedelta(days=days - 1)
        start_dt = self._start_of_day(start_day)

        # --- screen time: SUM(duration_seconds) grouped by calendar day ---
        session_rows = (
            db.query(
                func.date(ChildSessionLog.started_at).label("day"),
                func.sum(ChildSessionLog.duration_seconds).label("total_seconds"),
            )
            .filter(
                ChildSessionLog.child_id.in_(child_ids),
                ChildSessionLog.started_at >= start_dt,
                ChildSessionLog.archived_at.is_(None),
            )
            .group_by(func.date(ChildSessionLog.started_at))
            .all()
        )
        has_sessions = bool(session_rows)
        for row in session_rows:
            # func.date() returns a str in SQLite, a date object in PostgreSQL
            day_str = row.day if isinstance(row.day, str) else row.day.isoformat()
            if day_str in point_by_date:
                item = point_by_date[day_str]
                item["screen_time_minutes"] += floor((row.total_seconds or 0) / 60)
                item["data_available"] = True

        # --- activity/lesson counts: conditional COUNT grouped by calendar day ---
        # COUNT(CASE WHEN condition THEN 1 END) ignores NULL → counts matching rows only.
        event_rows = (
            db.query(
                func.date(ChildActivityEvent.occurred_at).label("day"),
                func.count(
                    case((ChildActivityEvent.event_type.in_(COMPLETION_EVENT_TYPES), 1))
                ).label("activities"),
                func.count(case((ChildActivityEvent.event_type == "lesson_completed", 1))).label(
                    "lessons"
                ),
            )
            .filter(
                ChildActivityEvent.child_id.in_(child_ids),
                ChildActivityEvent.occurred_at >= start_dt,
                ChildActivityEvent.archived_at.is_(None),
                ChildActivityEvent.event_type.in_(COMPLETION_EVENT_TYPES),
            )
            .group_by(func.date(ChildActivityEvent.occurred_at))
            .all()
        )
        has_events = bool(event_rows)
        for row in event_rows:
            day_str = row.day if isinstance(row.day, str) else row.day.isoformat()
            if day_str not in point_by_date:
                continue
            item = point_by_date[day_str]
            item["activities_completed"] += row.activities or 0
            item["lessons_completed"] += row.lessons or 0
            item["data_available"] = True

        return points, {"has_sessions": has_sessions, "has_events": has_events}

    def _score_summary(
        self,
        *,
        db: Session,
        child_ids: list[int],
        days: int,
    ) -> dict[str, float | int]:
        if not child_ids:
            return {
                "average_score": 0.0,
                "completed_count": 0,
                "total_count": 0,
                "completion_rate": 0.0,
            }
        start_dt = self._start_of_day(utc_today() - timedelta(days=days - 1))
        events = (
            db.query(ChildActivityEvent)
            .filter(
                ChildActivityEvent.child_id.in_(child_ids),
                ChildActivityEvent.occurred_at >= start_dt,
                ChildActivityEvent.archived_at.is_(None),
                ChildActivityEvent.event_type.in_(("activity_completed", "lesson_completed")),
            )
            .all()
        )
        scores: list[int] = []
        for event in events:
            metadata = event.metadata_json or {}
            raw_score = metadata.get("score")
            try:
                if raw_score is not None:
                    scores.append(int(raw_score))
            except (TypeError, ValueError):
                continue
        total_count = len(events)
        completed_count = sum(
            1
            for event in events
            if (event.metadata_json or {}).get("completion_status", "completed") == "completed"
        )
        average_score = round(sum(scores) / len(scores), 2) if scores else 0.0
        completion_rate = round(completed_count / total_count, 4) if total_count else 0.0
        return {
            "average_score": average_score,
            "completed_count": completed_count,
            "total_count": total_count,
            "completion_rate": completion_rate,
        }

    def _recent_sessions(
        self,
        *,
        db: Session,
        child_ids: list[int],
        days: int,
        limit: int = 5,
    ) -> list[dict]:
        if not child_ids:
            return []
        start_dt = self._start_of_day(utc_today() - timedelta(days=days - 1))
        events = (
            db.query(ChildActivityEvent)
            .filter(
                ChildActivityEvent.child_id.in_(child_ids),
                ChildActivityEvent.occurred_at >= start_dt,
                ChildActivityEvent.archived_at.is_(None),
                ChildActivityEvent.event_type.in_(("activity_completed", "lesson_completed")),
            )
            .order_by(ChildActivityEvent.occurred_at.desc(), ChildActivityEvent.id.desc())
            .all()
        )
        sessions: list[dict] = []
        for event in events[:limit]:
            metadata = event.metadata_json or {}
            sessions.append(
                {
                    "title": event.activity_name or event.lesson_id or event.event_type,
                    "content_type": (
                        metadata.get("content_type")
                        or ("lessons" if event.event_type == "lesson_completed" else "activities")
                    ),
                    "score": int(metadata.get("score") or 0),
                    "duration_minutes": max(int((event.duration_seconds or 0) / 60), 0),
                    "completed_at": event.occurred_at.isoformat() if event.occurred_at else None,
                    "completion_status": metadata.get("completion_status", "completed"),
                }
            )
        return sessions

    def _mood_counts(
        self,
        *,
        db: Session,
        child_ids: list[int],
        days: int,
    ) -> dict[str, int]:
        if not child_ids:
            return {}
        start_dt = self._start_of_day(utc_today() - timedelta(days=days - 1))
        events = (
            db.query(ChildActivityEvent)
            .filter(
                ChildActivityEvent.child_id.in_(child_ids),
                ChildActivityEvent.event_type == "mood_entry",
                ChildActivityEvent.occurred_at >= start_dt,
                ChildActivityEvent.archived_at.is_(None),
            )
            .all()
        )
        counts: dict[str, int] = defaultdict(int)
        for event in events:
            metadata = event.metadata_json or {}
            mood_label = metadata.get("mood_label")
            if not mood_label and event.mood_value is not None:
                mood_label = {
                    5: "happy",
                    4: "excited",
                    3: "calm",
                    2: "tired",
                    1: "sad",
                }.get(int(event.mood_value), "calm")
            if mood_label:
                counts[str(mood_label)] += 1
        return dict(counts)

    def _top_content_type(
        self,
        *,
        db: Session,
        child_ids: list[int],
        days: int,
    ) -> str | None:
        recent = self._recent_sessions(db=db, child_ids=child_ids, days=days, limit=100)
        if not recent:
            return None
        counts: dict[str, int] = defaultdict(int)
        for item in recent:
            counts[str(item["content_type"])] += 1
        return max(counts.items(), key=lambda item: item[1])[0]

    def _mood_trend(self, *, db: Session, child_ids: list[int], days: int = 14) -> list[dict]:
        if not child_ids:
            return []
        start_dt = self._start_of_day(utc_today() - timedelta(days=days - 1))
        events = (
            db.query(ChildActivityEvent)
            .filter(
                ChildActivityEvent.child_id.in_(child_ids),
                ChildActivityEvent.event_type == "mood_entry",
                ChildActivityEvent.occurred_at >= start_dt,
                ChildActivityEvent.mood_value.is_not(None),
                ChildActivityEvent.archived_at.is_(None),
            )
            .all()
        )
        by_day: dict[str, list[int]] = defaultdict(list)
        for event in events:
            by_day[event.occurred_at.date().isoformat()].append(int(event.mood_value))
        points = []
        for day_key in sorted(by_day.keys()):
            values = by_day[day_key]
            points.append(
                {
                    "date": day_key,
                    "avg_mood": round(sum(values) / len(values), 2),
                    "entries": len(values),
                }
            )
        return points

    def _achievements(
        self,
        *,
        db: Session,
        child_ids: list[int],
        limit: int = 10,
    ) -> tuple[int, list[dict]]:
        if not child_ids:
            return 0, []
        rows = (
            db.query(ChildActivityEvent)
            .filter(
                ChildActivityEvent.child_id.in_(child_ids),
                ChildActivityEvent.event_type == "achievement_unlocked",
                ChildActivityEvent.archived_at.is_(None),
            )
            .order_by(ChildActivityEvent.occurred_at.desc(), ChildActivityEvent.id.desc())
            .all()
        )
        recent = []
        for event in rows[:limit]:
            recent.append(
                {
                    "child_id": event.child_id,
                    "achievement_key": event.achievement_key,
                    "activity_name": event.activity_name,
                    "occurred_at": event.occurred_at.isoformat() if event.occurred_at else None,
                }
            )
        return len(rows), recent

    def _child_summaries(
        self,
        *,
        db: Session,
        children: list[ChildProfile],
        days: int = 7,
    ) -> list[dict]:
        if not children:
            return []
        start_dt = self._start_of_day(utc_today() - timedelta(days=days - 1))
        child_ids = [child.id for child in children]

        # --- screen time: SUM(duration_seconds) per child ---
        session_rows = (
            db.query(
                ChildSessionLog.child_id,
                func.sum(ChildSessionLog.duration_seconds).label("total_seconds"),
            )
            .filter(
                ChildSessionLog.child_id.in_(child_ids),
                ChildSessionLog.started_at >= start_dt,
                ChildSessionLog.archived_at.is_(None),
            )
            .group_by(ChildSessionLog.child_id)
            .all()
        )
        session_minutes: dict[int, int] = {
            row.child_id: floor((row.total_seconds or 0) / 60) for row in session_rows
        }

        # --- event counts: four conditional COUNTs in one query, grouped per child ---
        # TRACKED_EVENT_TYPES covers all four buckets; the WHERE pre-filter eliminates
        # untracked event types before the GROUP BY.
        event_rows = (
            db.query(
                ChildActivityEvent.child_id,
                func.count(
                    case((ChildActivityEvent.event_type.in_(COMPLETION_EVENT_TYPES), 1))
                ).label("activities"),
                func.count(case((ChildActivityEvent.event_type == "lesson_completed", 1))).label(
                    "lessons"
                ),
                func.count(case((ChildActivityEvent.event_type == "mood_entry", 1))).label("moods"),
                func.count(
                    case((ChildActivityEvent.event_type == "achievement_unlocked", 1))
                ).label("achievements"),
            )
            .filter(
                ChildActivityEvent.child_id.in_(child_ids),
                ChildActivityEvent.occurred_at >= start_dt,
                ChildActivityEvent.archived_at.is_(None),
                ChildActivityEvent.event_type.in_(TRACKED_EVENT_TYPES),
            )
            .group_by(ChildActivityEvent.child_id)
            .all()
        )
        event_stats: dict[int, tuple] = {row.child_id: row for row in event_rows}

        summaries = []
        for child in children:
            row = event_stats.get(child.id)
            summaries.append(
                {
                    "child_id": child.id,
                    "name": child.name,
                    "screen_time_minutes_7d": session_minutes.get(child.id, 0),
                    "activities_completed_7d": (row.activities or 0) if row else 0,
                    "lessons_completed_7d": (row.lessons or 0) if row else 0,
                    "mood_entries_7d": (row.moods or 0) if row else 0,
                    "achievements_7d": (row.achievements or 0) if row else 0,
                }
            )
        return summaries

    def build_basic_report(
        self,
        *,
        db: Session,
        user: User,
        child_id: int | None = None,
        days: int = 7,
    ) -> dict:
        children = self._children_for_report(db=db, user=user, child_id=child_id)
        child_ids = [child.id for child in children]
        daily_points, presence = self._aggregate_daily_points(
            db=db,
            child_ids=child_ids,
            days=days,
        )
        score_summary = self._score_summary(db=db, child_ids=child_ids, days=days)
        recent_sessions = self._recent_sessions(db=db, child_ids=child_ids, days=days, limit=5)
        child_summaries = self._child_summaries(db=db, children=children, days=min(days, 7))

        unread_notifications = (
            db.query(Notification)
            .filter(Notification.user_id == user.id, Notification.is_read.is_(False))
            .count()
        )
        open_support_tickets = (
            db.query(SupportTicket)
            .filter(
                SupportTicket.user_id == user.id,
                SupportTicket.deleted_at.is_(None),
                SupportTicket.status.in_(("open", "in_progress")),
            )
            .count()
        )
        payment_methods = db.query(PaymentMethod).filter(PaymentMethod.user_id == user.id).count()

        summary = {
            "child_count": len(children),
            "active_child_count": sum(1 for child in children if child.is_active),
            "unread_notifications": unread_notifications,
            "open_support_tickets": open_support_tickets,
            "payment_methods_count": payment_methods,
            f"screen_time_minutes_{days}d": sum(
                item["screen_time_minutes"] for item in daily_points
            ),
            f"activities_completed_{days}d": sum(
                item["activities_completed"] for item in daily_points
            ),
            f"lessons_completed_{days}d": sum(item["lessons_completed"] for item in daily_points),
            "average_score": score_summary["average_score"],
            "completion_rate": score_summary["completion_rate"],
        }

        data_availability = {
            "child_profiles": bool(children),
            "screen_time": presence["has_sessions"],
            "activities": presence["has_events"],
            "lessons": any(item["lessons_completed"] > 0 for item in daily_points),
            "mood_trends": bool(self._mood_trend(db=db, child_ids=child_ids, days=7)),
            "achievements": self._achievements(db=db, child_ids=child_ids)[0] > 0,
        }

        return {
            "reports": daily_points,
            "summary": summary,
            "child_summary": child_summaries[0] if child_summaries else None,
            "child_summaries": child_summaries,
            "children": [self._serialize_child(child) for child in children],
            "recent_sessions": recent_sessions,
            "data_availability": data_availability,
            "data_source": "backend_analytics",
            "access_level": "basic",
            "selected_child_id": child_id,
        }

    def build_advanced_report(
        self,
        *,
        db: Session,
        user: User,
        child_id: int | None = None,
        days: int = 30,
    ) -> dict:
        children = self._children_for_report(db=db, user=user, child_id=child_id)
        child_ids = [child.id for child in children]
        daily_points, presence = self._aggregate_daily_points(
            db=db,
            child_ids=child_ids,
            days=days,
        )
        newest_child = children[0] if children else None

        age_distribution = {
            "5_6": sum(1 for child in children if (child.age or 0) in (5, 6)),
            "7_9": sum(1 for child in children if 7 <= (child.age or 0) <= 9),
            "10_12": sum(1 for child in children if 10 <= (child.age or 0) <= 12),
            "unknown": sum(1 for child in children if child.age is None),
        }
        mood_trends = self._mood_trend(db=db, child_ids=child_ids, days=days)
        mood_counts = self._mood_counts(db=db, child_ids=child_ids, days=days)
        achievement_count, recent_achievements = self._achievements(
            db=db,
            child_ids=child_ids,
            limit=10,
        )
        child_summaries = self._child_summaries(db=db, children=children, days=7)
        score_summary = self._score_summary(db=db, child_ids=child_ids, days=days)
        recent_sessions = self._recent_sessions(db=db, child_ids=child_ids, days=days, limit=5)

        data_availability = {
            "child_profiles": bool(children),
            "screen_time": presence["has_sessions"],
            "activities": presence["has_events"],
            "lessons": any(item["lessons_completed"] > 0 for item in daily_points),
            "mood_trends": bool(mood_trends),
            "achievements": achievement_count > 0,
        }

        insight_notes = []
        if not presence["has_sessions"]:
            insight_notes.append("No screen-time sessions recorded yet.")
        if not presence["has_events"]:
            insight_notes.append("No activity events recorded yet.")
        if not insight_notes:
            insight_notes.append("Insights are generated from recorded child activity events.")

        comparison = {
            "status": (
                "available"
                if presence["has_events"] or presence["has_sessions"]
                else "not_available"
            ),
            "reason": (
                "Built from backend-stored analytics events and session logs."
                if presence["has_events"] or presence["has_sessions"]
                else "No activity/session data has been recorded yet."
            ),
        }

        return {
            "reports": {
                "daily_overview": daily_points,
                "children": [self._serialize_child(child) for child in children],
                "account_summary": {
                    "child_count": len(children),
                    "active_child_count": sum(1 for child in children if child.is_active),
                    "newest_child_created_at": (
                        newest_child.created_at.isoformat()
                        if newest_child and newest_child.created_at
                        else None
                    ),
                    f"screen_time_minutes_{days}d": sum(
                        item["screen_time_minutes"] for item in daily_points
                    ),
                    f"activities_completed_{days}d": sum(
                        item["activities_completed"] for item in daily_points
                    ),
                    f"lessons_completed_{days}d": sum(
                        item["lessons_completed"] for item in daily_points
                    ),
                    "average_score": score_summary["average_score"],
                    "completion_rate": score_summary["completion_rate"],
                },
                "age_distribution": age_distribution,
                "data_availability": data_availability,
                "insight_notes": insight_notes,
                "comparison": comparison,
                "mood_trends": mood_trends,
                "mood_counts": mood_counts,
                "average_score": score_summary["average_score"],
                "completion_rate": score_summary["completion_rate"],
                "top_content_type": self._top_content_type(
                    db=db,
                    child_ids=child_ids,
                    days=days,
                ),
                "achievements": {
                    "total_unlocked": achievement_count,
                    "recent_unlocks": recent_achievements,
                },
                "recent_sessions": recent_sessions,
                "child_summaries": child_summaries,
                "data_source": "backend_analytics",
            },
            "access_level": "advanced",
            "data_source": "backend_analytics",
            "selected_child_id": child_id,
        }
