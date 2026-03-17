from __future__ import annotations

from collections import defaultdict
from datetime import timedelta
from math import floor
from typing import Any

from sqlalchemy.orm import Session, joinedload

from core.time_utils import utc_now, utc_today, utc_start_of_day
from models import (
    ChildActivityEvent,
    ChildDailyActivitySummary,
    ChildProfile,
    ChildSessionLog,
    ContentItem,
    Notification,
    SupportTicket,
    User,
)
from plan_service import PLAN_FAMILY_PLUS, PLAN_FREE, PLAN_PREMIUM, get_user_plan
from services.analytics_service import analytics_service

_DOWNLOAD_QUOTA_MB = {
    PLAN_PREMIUM: 500,
    PLAN_FAMILY_PLUS: 2000,
}

_DOWNLOAD_ITEM_LIMIT = {
    PLAN_PREMIUM: 25,
    PLAN_FAMILY_PLUS: 100,
}

_SUPPORT_SLA_HOURS = {
    "urgent": 2,
    "high": 6,
    "normal": 12,
    "low": 24,
}


class PremiumBehaviorService:
    def build_ai_insights(
        self,
        *,
        db: Session,
        user: User,
    ) -> dict[str, Any]:
        report = analytics_service.build_advanced_report(db=db, user=user, days=30)
        payload = dict(report.get("reports") or {})
        child_summaries = list(payload.get("child_summaries") or [])
        recent_sessions = list(payload.get("recent_sessions") or [])
        mood_counts = dict(payload.get("mood_counts") or {})
        achievements = dict(payload.get("achievements") or {})
        account_summary = dict(payload.get("account_summary") or {})
        children = list(payload.get("children") or [])

        insights: list[dict[str, Any]] = []
        completion_rate = float(payload.get("completion_rate") or account_summary.get("completion_rate") or 0.0)
        average_score = float(payload.get("average_score") or account_summary.get("average_score") or 0.0)
        top_content_type = payload.get("top_content_type")
        if children:
            inactive_children = [
                item["name"]
                for item in child_summaries
                if int(item.get("activities_completed_7d") or 0) == 0
                and int(item.get("screen_time_minutes_7d") or 0) == 0
            ]
            if inactive_children:
                insights.append(
                    {
                        "code": "inactivity_watch",
                        "severity": "warning",
                        "title": "Activity slowdown detected",
                        "summary": f"{', '.join(inactive_children[:2])} had no recorded activity in the last 7 days.",
                        "recommended_action": "Open a short lesson or story to restart engagement.",
                    }
                )
            if completion_rate < 0.55 and recent_sessions:
                insights.append(
                    {
                        "code": "completion_support",
                        "severity": "medium",
                        "title": "Completion rate needs support",
                        "summary": f"Completion rate is {round(completion_rate * 100)}% across the last 30 days.",
                        "recommended_action": "Favor shorter activities and repeat the strongest content type this week.",
                    }
                )
            if average_score >= 80 and int(achievements.get("total_unlocked") or 0) > 0:
                insights.append(
                    {
                        "code": "strong_progress",
                        "severity": "positive",
                        "title": "Strong recent progress",
                        "summary": f"Average score is {round(average_score)}% with {int(achievements.get('total_unlocked') or 0)} unlocked achievements.",
                        "recommended_action": "Keep the current routine and add one harder challenge.",
                    }
                )
            dominant_mood = self._dominant_mood(mood_counts)
            if dominant_mood in {"sad", "tired"}:
                insights.append(
                    {
                        "code": "mood_support",
                        "severity": "warning",
                        "title": "Mood trend needs a gentler pace",
                        "summary": f"The most common recent mood is {dominant_mood}.",
                        "recommended_action": "Try calmer activities and shorter sessions for the next few days.",
                    }
                )
            if top_content_type:
                insights.append(
                    {
                        "code": "content_affinity",
                        "severity": "info",
                        "title": "Content preference detected",
                        "summary": f"Recent activity leans toward {top_content_type}.",
                        "recommended_action": "Use that content type as the first activity in the next session.",
                    }
                )

        return {
            "insights": insights[:4],
            "summary": {
                "child_count": len(children),
                "completion_rate": completion_rate,
                "average_score": average_score,
                "top_content_type": top_content_type,
                "dominant_mood": self._dominant_mood(mood_counts),
            },
            "data_source": "backend_rules",
            "access_level": "premium",
        }

    def build_basic_notifications(
        self,
        *,
        db: Session,
        user: User,
    ) -> dict[str, Any]:
        notifications: list[dict[str, Any]] = []
        unread = (
            db.query(Notification)
            .filter(Notification.user_id == user.id, Notification.is_read.is_(False))
            .order_by(Notification.created_at.desc(), Notification.id.desc())
            .limit(3)
            .all()
        )
        notifications.extend(
            {
                "id": item.id,
                "type": item.type,
                "message": item.body,
                "priority": "high" if not item.is_read else "normal",
                "created_at": item.created_at.isoformat() if item.created_at else None,
            }
            for item in unread
        )

        children = analytics_service._children_for_parent(db, user.id)
        today = utc_today()
        for child in children[:2]:
            summary = (
                db.query(ChildDailyActivitySummary)
                .filter(
                    ChildDailyActivitySummary.child_id == child.id,
                    ChildDailyActivitySummary.summary_date == today,
                    ChildDailyActivitySummary.archived_at.is_(None),
                )
                .first()
            )
            if summary and int(summary.screen_time_minutes or 0) >= 60:
                notifications.append(
                    {
                        "id": f"screen-time-{child.id}",
                        "type": "SCREEN_TIME_LIMIT",
                        "message": f"{child.name} reached {int(summary.screen_time_minutes)} minutes of screen time today.",
                        "priority": "normal",
                        "created_at": utc_now().isoformat(),
                    }
                )
        return {
            "notifications": notifications[:5],
            "access_level": "basic",
            "data_source": "backend_rules",
        }

    def build_smart_notifications(
        self,
        *,
        db: Session,
        user: User,
    ) -> dict[str, Any]:
        children = analytics_service._children_for_parent(db, user.id)
        notifications: list[dict[str, Any]] = []
        now = utc_now()

        for child in children:
            last_activity = self._last_activity_at(db=db, child_id=child.id)
            if last_activity is None or last_activity <= now - timedelta(days=3):
                notifications.append(
                    {
                        "id": f"inactivity-{child.id}",
                        "type": "INACTIVITY_ALERT",
                        "severity": "warning",
                        "message": f"{child.name} has been inactive for at least 3 days.",
                        "child_id": child.id,
                        "created_at": now.isoformat(),
                        "rule_key": "inactivity_3d",
                    }
                )

            streak = self._activity_streak_days(db=db, child_id=child.id)
            if streak in {3, 7, 14}:
                notifications.append(
                    {
                        "id": f"streak-{child.id}-{streak}",
                        "type": "STREAK_MILESTONE",
                        "severity": "positive",
                        "message": f"{child.name} reached a {streak}-day activity streak.",
                        "child_id": child.id,
                        "created_at": now.isoformat(),
                        "rule_key": "activity_streak",
                    }
                )

            mood_counts = analytics_service._mood_counts(db=db, child_ids=[child.id], days=7)
            dominant_mood = self._dominant_mood(mood_counts)
            if dominant_mood in {"sad", "tired"} and sum(mood_counts.values()) >= 2:
                notifications.append(
                    {
                        "id": f"mood-{child.id}",
                        "type": "MOOD_TREND",
                        "severity": "warning",
                        "message": f"{child.name} has shown more {dominant_mood} moods recently.",
                        "child_id": child.id,
                        "created_at": now.isoformat(),
                        "rule_key": "mood_trend",
                    }
                )

            lessons_7d = self._lessons_completed(db=db, child_id=child.id, days=7)
            if lessons_7d >= 3:
                notifications.append(
                    {
                        "id": f"lessons-{child.id}",
                        "type": "LEARNING_MILESTONE",
                        "severity": "positive",
                        "message": f"{child.name} completed {lessons_7d} lessons in the last 7 days.",
                        "child_id": child.id,
                        "created_at": now.isoformat(),
                        "rule_key": "lesson_milestone",
                    }
                )

        notifications.sort(
            key=lambda item: (
                {"warning": 3, "critical": 4, "positive": 2, "info": 1}.get(item.get("severity", "info"), 0),
                item.get("created_at") or "",
            ),
            reverse=True,
        )
        return {
            "notifications": notifications[:8],
            "access_level": "smart",
            "data_source": "backend_rules",
        }

    def build_offline_downloads(
        self,
        *,
        db: Session,
        user: User,
    ) -> dict[str, Any]:
        plan = get_user_plan(user)
        quota_mb = _DOWNLOAD_QUOTA_MB.get(plan, 0)
        item_limit = _DOWNLOAD_ITEM_LIMIT.get(plan, 0)
        child_ids = [child.id for child in analytics_service._children_for_parent(db, user.id)]
        recent = analytics_service._recent_sessions(db=db, child_ids=child_ids, days=30, limit=100)
        distinct_titles = {str(item.get("title") or "").strip() for item in recent if item.get("title")}
        used_items = min(len(distinct_titles), item_limit)
        estimated_used_mb = min(quota_mb, used_items * 20)
        published_downloadable_items = (
            db.query(ContentItem)
            .filter(
                ContentItem.status == "published",
                ContentItem.deleted_at.is_(None),
                ContentItem.content_type.in_(("lesson", "story", "video", "activity")),
            )
            .count()
        )

        return {
            "status": "eligible" if quota_mb > 0 else "not_available",
            "quota_mb": quota_mb,
            "used_mb": estimated_used_mb,
            "remaining_mb": max(quota_mb - estimated_used_mb, 0),
            "download_limit_items": item_limit,
            "used_download_items": used_items,
            "remaining_download_items": max(item_limit - used_items, 0),
            "catalog_downloadable_items": published_downloadable_items,
            "data_source": "backend_rules",
            "eligibility_reason": (
                "Current plan allows offline downloads."
                if quota_mb > 0
                else "Current plan does not include offline downloads."
            ),
        }

    def build_priority_support(
        self,
        *,
        db: Session,
        user: User,
    ) -> dict[str, Any]:
        user_plan = get_user_plan(user)
        queue = self.rank_support_tickets(
            db.query(SupportTicket)
            .options(joinedload(SupportTicket.user), joinedload(SupportTicket.assigned_admin))
            .filter(SupportTicket.status.in_(("open", "in_progress", "resolved")))
            .all()
        )
        my_tickets = [item for item in queue if item["ticket"].user_id == user.id]
        highest_priority = my_tickets[0] if my_tickets else None
        return {
            "support_level": "priority" if user_plan == PLAN_FAMILY_PLUS else "standard",
            "response_time_hours": (
                _SUPPORT_SLA_HOURS.get(highest_priority["priority_level"], 12)
                if highest_priority is not None
                else 12
            ),
            "support_channels": ["email", "chat"] if user_plan == PLAN_FAMILY_PLUS else ["email"],
            "open_ticket_count": len(my_tickets),
            "highest_priority_ticket": (
                self._priority_payload(highest_priority, include_queue_position=True)
                if highest_priority is not None
                else None
            ),
            "tickets": [
                self._priority_payload(item, include_queue_position=True) for item in my_tickets[:5]
            ],
            "data_source": "backend_rules",
        }

    def rank_support_tickets(self, tickets: list[SupportTicket]) -> list[dict[str, Any]]:
        ranked = [self.support_priority_snapshot(ticket) for ticket in tickets]
        ranked.sort(
            key=lambda item: (
                item["priority_score"],
                item["ticket"].updated_at.isoformat() if item["ticket"].updated_at else "",
                item["ticket"].created_at.isoformat() if item["ticket"].created_at else "",
            ),
            reverse=True,
        )
        for index, item in enumerate(ranked, start=1):
            item["queue_position"] = index
        return ranked

    def _priority_payload(
        self,
        snapshot: dict[str, Any],
        *,
        include_queue_position: bool,
    ) -> dict[str, Any]:
        payload = {
            "ticket_id": snapshot["ticket"].id,
            "subject": snapshot["ticket"].subject,
            "status": snapshot["ticket"].status,
            "priority_level": snapshot["priority_level"],
            "priority_score": snapshot["priority_score"],
            "priority_reason": snapshot["priority_reason"],
        }
        if include_queue_position:
            payload["queue_position"] = snapshot.get("queue_position")
        return payload

    def support_priority_snapshot(self, ticket: SupportTicket) -> dict[str, Any]:
        user_plan = get_user_plan(ticket.user) if ticket.user is not None else PLAN_FREE
        score = 0
        reasons: list[str] = []

        if user_plan == PLAN_FAMILY_PLUS:
            score += 100
            reasons.append("Family Plus account")
        elif user_plan == PLAN_PREMIUM:
            score += 40
            reasons.append("Premium account")
        else:
            score += 10
            reasons.append("Free account")

        category_weights = {
            "billing_issue": 35,
            "technical_issue": 25,
            "child_content_issue": 20,
            "login_issue": 15,
            "general_inquiry": 5,
        }
        score += category_weights.get(ticket.category, 5)
        reasons.append(f"Category: {ticket.category}")

        if ticket.status == "open":
            score += 20
        elif ticket.status == "in_progress":
            score += 10

        if ticket.assigned_admin_id is None:
            score += 12
            reasons.append("Unassigned ticket")

        age_hours = max(
            int(((utc_now() - (ticket.created_at or utc_now())).total_seconds()) / 3600),
            0,
        )
        aging_bonus = min(floor(age_hours / 6) * 3, 24)
        if aging_bonus:
            score += aging_bonus
            reasons.append("Waiting in queue")

        reply_bonus = min(int(len(ticket.thread_messages or [])), 5)
        score += reply_bonus

        if score >= 135:
            level = "urgent"
        elif score >= 95:
            level = "high"
        elif score >= 55:
            level = "normal"
        else:
            level = "low"

        return {
            "ticket": ticket,
            "priority_level": level,
            "priority_score": score,
            "priority_reason": ", ".join(reasons),
        }

    def _last_activity_at(self, *, db: Session, child_id: int):
        session = (
            db.query(ChildSessionLog)
            .filter(
                ChildSessionLog.child_id == child_id,
                ChildSessionLog.archived_at.is_(None),
            )
            .order_by(ChildSessionLog.ended_at.desc(), ChildSessionLog.id.desc())
            .first()
        )
        event = (
            db.query(ChildActivityEvent)
            .filter(
                ChildActivityEvent.child_id == child_id,
                ChildActivityEvent.archived_at.is_(None),
            )
            .order_by(ChildActivityEvent.occurred_at.desc(), ChildActivityEvent.id.desc())
            .first()
        )
        candidates = [
            session.ended_at if session is not None else None,
            event.occurred_at if event is not None else None,
        ]
        return max([item for item in candidates if item is not None], default=None)

    def _activity_streak_days(self, *, db: Session, child_id: int) -> int:
        start_day = utc_today() - timedelta(days=14)
        summaries = (
            db.query(ChildDailyActivitySummary)
            .filter(
                ChildDailyActivitySummary.child_id == child_id,
                ChildDailyActivitySummary.summary_date >= start_day,
                ChildDailyActivitySummary.archived_at.is_(None),
            )
            .all()
        )
        active_days = {
            item.summary_date
            for item in summaries
            if any(
                int(getattr(item, field) or 0) > 0
                for field in (
                    "screen_time_minutes",
                    "activities_completed",
                    "lessons_completed",
                    "mood_entries",
                    "achievements_unlocked",
                    "ai_interactions_count",
                )
            )
        }
        streak = 0
        cursor = utc_today()
        while cursor in active_days:
            streak += 1
            cursor = cursor - timedelta(days=1)
        return streak

    def _lessons_completed(self, *, db: Session, child_id: int, days: int) -> int:
        start_dt = utc_start_of_day(utc_today() - timedelta(days=days - 1))
        return (
            db.query(ChildActivityEvent)
            .filter(
                ChildActivityEvent.child_id == child_id,
                ChildActivityEvent.event_type == "lesson_completed",
                ChildActivityEvent.occurred_at >= start_dt,
                ChildActivityEvent.archived_at.is_(None),
            )
            .count()
        )

    def _dominant_mood(self, mood_counts: dict[str, int]) -> str | None:
        if not mood_counts:
            return None
        return max(mood_counts.items(), key=lambda item: item[1])[0]


premium_behavior_service = PremiumBehaviorService()
