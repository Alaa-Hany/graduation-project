from __future__ import annotations

from datetime import timedelta
from math import floor
from typing import Any

from sqlalchemy.orm import Session, joinedload

from core.time_utils import utc_now, utc_start_of_day, utc_today
from models import (
    ChildActivityEvent,
    ChildDailyActivitySummary,
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
        report_sections = self._advanced_report_sections(db=db, user=user)
        child_summaries = report_sections["child_summaries"]
        recent_sessions = report_sections["recent_sessions"]
        mood_counts = report_sections["mood_counts"]
        achievements = report_sections["achievements"]
        children = report_sections["children"]
        completion_rate = report_sections["completion_rate"]
        average_score = report_sections["average_score"]
        top_content_type = report_sections["top_content_type"]
        dominant_mood = self._dominant_mood(mood_counts)

        insights = self._rule_based_ai_insights(
            child_summaries=child_summaries,
            recent_sessions=recent_sessions,
            achievements=achievements,
            children=children,
            completion_rate=completion_rate,
            average_score=average_score,
            top_content_type=top_content_type,
            dominant_mood=dominant_mood,
        )

        if not insights:
            insights = self._baseline_ai_insights(
                child_summaries=child_summaries,
                children=children,
                recent_sessions=recent_sessions,
                top_content_type=top_content_type,
            )

        return {
            "insights": insights[:4],
            "summary": {
                "child_count": len(children),
                "completion_rate": completion_rate,
                "average_score": average_score,
                "top_content_type": top_content_type,
                "dominant_mood": dominant_mood,
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
        now = utc_now()
        notifications = self._smart_notifications_for_children(
            db=db,
            children=children,
            now=now,
        )
        if not notifications:
            notifications = self._baseline_smart_notifications(
                db=db,
                user=user,
                children=children,
                now=now,
            )
        return {
            "notifications": notifications[:8],
            "access_level": "smart",
            "data_source": "backend_rules",
        }

    def _advanced_report_sections(self, *, db: Session, user: User) -> dict[str, Any]:
        report = analytics_service.build_advanced_report(db=db, user=user, days=30)
        payload = dict(report.get("reports") or {})
        account_summary = dict(payload.get("account_summary") or {})
        return {
            "child_summaries": list(payload.get("child_summaries") or []),
            "recent_sessions": list(payload.get("recent_sessions") or []),
            "mood_counts": dict(payload.get("mood_counts") or {}),
            "achievements": dict(payload.get("achievements") or {}),
            "children": list(payload.get("children") or []),
            "completion_rate": float(
                payload.get("completion_rate") or account_summary.get("completion_rate") or 0.0
            ),
            "average_score": float(
                payload.get("average_score") or account_summary.get("average_score") or 0.0
            ),
            "top_content_type": payload.get("top_content_type"),
        }

    def _rule_based_ai_insights(
        self,
        *,
        child_summaries: list[dict[str, Any]],
        recent_sessions: list[dict[str, Any]],
        achievements: dict[str, Any],
        children: list[dict[str, Any]],
        completion_rate: float,
        average_score: float,
        top_content_type: Any,
        dominant_mood: str | None,
    ) -> list[dict[str, Any]]:
        if not children:
            return []

        insights: list[dict[str, Any]] = []
        self._append_inactivity_insight(insights=insights, child_summaries=child_summaries)
        self._append_completion_support_insight(
            insights=insights,
            completion_rate=completion_rate,
            recent_sessions=recent_sessions,
        )
        self._append_progress_insight(
            insights=insights,
            average_score=average_score,
            achievements=achievements,
        )
        self._append_mood_support_insight(insights=insights, dominant_mood=dominant_mood)
        self._append_content_affinity_insight(
            insights=insights,
            top_content_type=top_content_type,
        )
        return insights

    def _append_inactivity_insight(
        self,
        *,
        insights: list[dict[str, Any]],
        child_summaries: list[dict[str, Any]],
    ) -> None:
        inactive_children = [
            item["name"]
            for item in child_summaries
            if int(item.get("activities_completed_7d") or 0) == 0
            and int(item.get("screen_time_minutes_7d") or 0) == 0
        ]
        if not inactive_children:
            return
        insights.append(
            {
                "code": "inactivity_watch",
                "severity": "warning",
                "title": "Activity slowdown detected",
                "summary": f"{', '.join(inactive_children[:2])} had no recorded activity in the last 7 days.",
                "recommended_action": "Open a short lesson or story to restart engagement.",
            }
        )

    def _append_completion_support_insight(
        self,
        *,
        insights: list[dict[str, Any]],
        completion_rate: float,
        recent_sessions: list[dict[str, Any]],
    ) -> None:
        if completion_rate >= 0.55 or not recent_sessions:
            return
        insights.append(
            {
                "code": "completion_support",
                "severity": "medium",
                "title": "Completion rate needs support",
                "summary": f"Completion rate is {round(completion_rate * 100)}% across the last 30 days.",
                "recommended_action": "Favor shorter activities and repeat the strongest content type this week.",
            }
        )

    def _append_progress_insight(
        self,
        *,
        insights: list[dict[str, Any]],
        average_score: float,
        achievements: dict[str, Any],
    ) -> None:
        total_unlocked = int(achievements.get("total_unlocked") or 0)
        if average_score < 80 or total_unlocked <= 0:
            return
        insights.append(
            {
                "code": "strong_progress",
                "severity": "positive",
                "title": "Strong recent progress",
                "summary": f"Average score is {round(average_score)}% with {total_unlocked} unlocked achievements.",
                "recommended_action": "Keep the current routine and add one harder challenge.",
            }
        )

    def _append_mood_support_insight(
        self,
        *,
        insights: list[dict[str, Any]],
        dominant_mood: str | None,
    ) -> None:
        if dominant_mood not in {"sad", "tired"}:
            return
        insights.append(
            {
                "code": "mood_support",
                "severity": "warning",
                "title": "Mood trend needs a gentler pace",
                "summary": f"The most common recent mood is {dominant_mood}.",
                "recommended_action": "Try calmer activities and shorter sessions for the next few days.",
            }
        )

    def _append_content_affinity_insight(
        self,
        *,
        insights: list[dict[str, Any]],
        top_content_type: Any,
    ) -> None:
        if not top_content_type:
            return
        insights.append(
            {
                "code": "content_affinity",
                "severity": "info",
                "title": "Content preference detected",
                "summary": f"Recent activity leans toward {top_content_type}.",
                "recommended_action": "Use that content type as the first activity in the next session.",
            }
        )

    def _smart_notifications_for_children(
        self,
        *,
        db: Session,
        children: list[Any],
        now,
    ) -> list[dict[str, Any]]:
        notifications: list[dict[str, Any]] = []
        for child in children:
            notifications.extend(
                self._smart_notifications_for_child(
                    db=db,
                    child=child,
                    now=now,
                )
            )
        return self._sort_smart_notifications(notifications)

    def _smart_notifications_for_child(
        self,
        *,
        db: Session,
        child: Any,
        now,
    ) -> list[dict[str, Any]]:
        notifications: list[dict[str, Any]] = []
        self._append_inactivity_notification(
            notifications=notifications,
            db=db,
            child=child,
            now=now,
        )
        self._append_streak_notification(
            notifications=notifications,
            db=db,
            child=child,
            now=now,
        )
        self._append_mood_trend_notification(
            notifications=notifications,
            db=db,
            child=child,
            now=now,
        )
        self._append_lesson_milestone_notification(
            notifications=notifications,
            db=db,
            child=child,
            now=now,
        )
        return notifications

    def _append_inactivity_notification(
        self,
        *,
        notifications: list[dict[str, Any]],
        db: Session,
        child: Any,
        now,
    ) -> None:
        last_activity = self._last_activity_at(db=db, child_id=child.id)
        if last_activity is not None and last_activity > now - timedelta(days=3):
            return
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

    def _append_streak_notification(
        self,
        *,
        notifications: list[dict[str, Any]],
        db: Session,
        child: Any,
        now,
    ) -> None:
        streak = self._activity_streak_days(db=db, child_id=child.id)
        if streak not in {3, 7, 14}:
            return
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

    def _append_mood_trend_notification(
        self,
        *,
        notifications: list[dict[str, Any]],
        db: Session,
        child: Any,
        now,
    ) -> None:
        mood_counts = analytics_service._mood_counts(db=db, child_ids=[child.id], days=7)
        dominant_mood = self._dominant_mood(mood_counts)
        if dominant_mood not in {"sad", "tired"} or sum(mood_counts.values()) < 2:
            return
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

    def _append_lesson_milestone_notification(
        self,
        *,
        notifications: list[dict[str, Any]],
        db: Session,
        child: Any,
        now,
    ) -> None:
        lessons_7d = self._lessons_completed(db=db, child_id=child.id, days=7)
        if lessons_7d < 3:
            return
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

    def _sort_smart_notifications(
        self,
        notifications: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        notifications.sort(
            key=lambda item: (
                {"warning": 3, "critical": 4, "positive": 2, "info": 1}.get(
                    item.get("severity", "info"), 0
                ),
                item.get("created_at") or "",
            ),
            reverse=True,
        )
        return notifications

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
        distinct_titles = {
            str(item.get("title") or "").strip() for item in recent if item.get("title")
        }
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
            "status": "downloads enabled" if quota_mb > 0 else "not_available",
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
            .filter(
                SupportTicket.deleted_at.is_(None),
                SupportTicket.status.in_(("open", "in_progress", "resolved")),
            )
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
            "support_channels": (
                ["email", "chat", "phone"] if user_plan == PLAN_FAMILY_PLUS else ["email"]
            ),
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

    def _baseline_ai_insights(
        self,
        *,
        child_summaries: list[dict[str, Any]],
        children: list[dict[str, Any]],
        recent_sessions: list[dict[str, Any]],
        top_content_type: Any,
    ) -> list[dict[str, Any]]:
        if not children:
            return [
                {
                    "code": "setup_required",
                    "severity": "info",
                    "title": "Add a child profile to unlock insights",
                    "summary": "No child profiles are linked to this account yet.",
                    "recommended_action": "Create a child profile to start collecting learning and wellbeing data.",
                },
                {
                    "code": "insight_baseline_pending",
                    "severity": "info",
                    "title": "Insight baseline not established",
                    "summary": "The system needs at least one active child profile before it can detect progress trends.",
                    "recommended_action": "After adding a child profile, complete one guided session to generate the first insight snapshot.",
                },
            ]

        inactive_names = [
            item["name"]
            for item in child_summaries
            if int(item.get("activities_completed_7d") or 0) == 0
            and int(item.get("screen_time_minutes_7d") or 0) == 0
        ]
        if not recent_sessions and (inactive_names or not child_summaries):
            names_preview = ", ".join(inactive_names[:2]) or f"{len(children)} child profiles"
            return [
                {
                    "code": "activity_baseline_pending",
                    "severity": "info",
                    "title": "More activity is needed for personalized insights",
                    "summary": (
                        f"{names_preview} {'has' if len(children) == 1 else 'have'} no recorded sessions in the last 30 days."
                    ),
                    "recommended_action": "Start one lesson or story this week to establish a behavioral baseline.",
                },
                {
                    "code": "routine_seed",
                    "severity": "info",
                    "title": "Build a simple weekly routine",
                    "summary": "Consistent short sessions make future progress and mood trends more reliable.",
                    "recommended_action": "Aim for two short guided sessions on separate days before checking insights again.",
                },
            ]

        return [
            {
                "code": "healthy_routine_detected",
                "severity": "positive",
                "title": "No urgent insight flags right now",
                "summary": "Recent activity does not show a strong risk pattern that needs immediate action.",
                "recommended_action": (
                    f"Keep the current routine and review {top_content_type} progress again next week."
                    if top_content_type
                    else "Keep the current routine and add one more guided session this week."
                ),
            }
        ]

    def _baseline_smart_notifications(
        self,
        *,
        db: Session,
        user: User,
        children: list[Any],
        now,
    ) -> list[dict[str, Any]]:
        if not children:
            return [
                {
                    "id": f"smart-setup-{user.id}",
                    "type": "BEHAVIORAL_INSIGHT",
                    "severity": "info",
                    "message": "No child profiles are connected yet. Add one profile to start receiving smart alerts.",
                    "created_at": now.isoformat(),
                    "rule_key": "account_setup_required",
                }
            ]

        inactive_children = [
            child
            for child in children
            if (last_activity := self._last_activity_at(db=db, child_id=child.id)) is None
            or last_activity <= now - timedelta(days=3)
        ]
        if inactive_children:
            names_preview = ", ".join(child.name for child in inactive_children[:2])
            return [
                {
                    "id": f"smart-baseline-{user.id}",
                    "type": "BEHAVIORAL_INSIGHT",
                    "severity": "info",
                    "message": (
                        f"{names_preview} {'has' if len(inactive_children) == 1 else 'have'} no recent activity baseline yet. "
                        "Start one guided session to unlock smarter alerts."
                    ),
                    "created_at": now.isoformat(),
                    "rule_key": "activity_baseline_pending",
                }
            ]

        return [
            {
                "id": f"smart-stable-{user.id}",
                "type": "BEHAVIORAL_INSIGHT",
                "severity": "positive",
                "message": "No urgent smart alerts right now. Recent activity looks stable across your account.",
                "created_at": now.isoformat(),
                "rule_key": "stable_activity_window",
            }
        ]


premium_behavior_service = PremiumBehaviorService()
