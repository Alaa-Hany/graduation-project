"""Child development profile service.

Builds a parent-facing "strengths and growth" profile that scores a child across
four development domains using their in-app activity data, then adds an
AI-written narrative. This is deliberately framed as developmental strengths
and growth areas, NOT as a formal intelligence/IQ test.
"""

from __future__ import annotations

import logging
from collections import defaultdict
from datetime import timedelta

from fastapi import HTTPException
from sqlalchemy.orm import Session

from core.settings import settings
from core.time_utils import utc_now, utc_start_of_day, utc_today
from models import ChildActivityEvent, ChildProfile, User
from services.ai_providers.enhanced_ai_provider import enhanced_ai_provider

logger = logging.getLogger(__name__)

COMPLETION_EVENT_TYPES = ("activity_completed", "lesson_completed")

# The four development domains, with bilingual titles.
DOMAINS = (
    {"key": "cognitive", "title_en": "Cognitive & Learning", "title_ar": "المعرفي والتعليمي"},
    {"key": "language", "title_en": "Language", "title_ar": "اللغوي"},
    {"key": "creative", "title_en": "Creative & Skills", "title_ar": "المهاري والإبداعي"},
    {"key": "social", "title_en": "Social & Behavioral", "title_ar": "الاجتماعي والسلوكي"},
)

# Keywords (English + Arabic) used to map an activity to a domain when the app
# does not send an explicit "domain"/"category" in the event metadata.
_DOMAIN_KEYWORDS: dict[str, tuple[str, ...]] = {
    "cognitive": (
        "math",
        "number",
        "count",
        "shape",
        "science",
        "animal",
        "plant",
        "logic",
        "puzzle",
        "memory",
        "geography",
        "رياضيات",
        "عدد",
        "حساب",
        "شكل",
        "علوم",
        "حيوان",
        "نبات",
        "ذكاء",
        "ألغاز",
        "ذاكرة",
    ),
    "language": (
        "arabic",
        "english",
        "read",
        "story",
        "letter",
        "word",
        "spell",
        "language",
        "عربي",
        "إنجليزي",
        "لغة",
        "قراءة",
        "قصة",
        "حرف",
        "كلمة",
        "إملاء",
    ),
    "creative": (
        "draw",
        "color",
        "music",
        "art",
        "craft",
        "sing",
        "paint",
        "sport",
        "dance",
        "رسم",
        "تلوين",
        "موسيقى",
        "فن",
        "غناء",
        "رياضة",
        "حرف يدوية",
        "رقص",
    ),
    "social": (
        "kind",
        "share",
        "cooper",
        "honest",
        "respect",
        "patien",
        "friend",
        "help",
        "behav",
        "gratitude",
        "تعاون",
        "مشاركة",
        "صدق",
        "احترام",
        "صبر",
        "لطف",
        "سلوك",
        "صديق",
        "مساعدة",
        "امتنان",
    ),
}

_LEVELS = (
    (80, "advanced", "متميّز", "Advanced"),
    (60, "strong", "جيّد جدًا", "Strong"),
    (40, "developing", "نامٍ", "Developing"),
    (0, "emerging", "ناشئ", "Emerging"),
)


class ChildDevelopmentService:
    def _resolve_child(self, *, db: Session, user: User, child_id: int) -> ChildProfile:
        child = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.id == child_id,
                ChildProfile.parent_id == user.id,
                ChildProfile.deleted_at.is_(None),
            )
            .one_or_none()
        )
        if child is None:
            raise HTTPException(status_code=404, detail="Child not found")
        return child

    @staticmethod
    def _classify_domain(event: ChildActivityEvent) -> str | None:
        metadata = event.metadata_json or {}
        # 1) Explicit domain from the app wins.
        explicit = str(metadata.get("domain") or "").strip().lower()
        if explicit in _DOMAIN_KEYWORDS:
            return explicit
        # 2) Otherwise match keywords against category + activity name + lesson id.
        haystack = " ".join(
            str(value).lower()
            for value in (
                metadata.get("category"),
                metadata.get("content_type"),
                event.activity_name,
                event.lesson_id,
            )
            if value
        )
        for domain_key, keywords in _DOMAIN_KEYWORDS.items():
            if any(keyword in haystack for keyword in keywords):
                return domain_key
        return None

    @staticmethod
    def _level_for_score(score: float) -> tuple[str, str, str]:
        for threshold, key, label_ar, label_en in _LEVELS:
            if score >= threshold:
                return key, label_ar, label_en
        return "emerging", "ناشئ", "Emerging"

    def _domain_scores(
        self, *, events: list[ChildActivityEvent], mood_values: list[int]
    ) -> dict[str, dict]:
        buckets: dict[str, list[ChildActivityEvent]] = defaultdict(list)
        for event in events:
            domain = self._classify_domain(event)
            if domain:
                buckets[domain].append(event)

        results: dict[str, dict] = {}
        for domain in DOMAINS:
            key = domain["key"]
            domain_events = buckets.get(key, [])
            scores: list[int] = []
            completed = 0
            for event in domain_events:
                metadata = event.metadata_json or {}
                raw_score = metadata.get("score")
                try:
                    if raw_score is not None:
                        scores.append(max(0, min(int(raw_score), 100)))
                except (TypeError, ValueError):
                    pass
                if metadata.get("completion_status", "completed") == "completed":
                    completed += 1

            total = len(domain_events)
            completion_rate = round(completed / total, 4) if total else 0.0
            avg_score = round(sum(scores) / len(scores), 1) if scores else None
            data_points = total

            # Performance = average score when available, else completion as a proxy.
            performance: float | None
            if avg_score is not None:
                performance = avg_score
            elif total:
                performance = completion_rate * 100
            else:
                performance = None

            # Social domain also reflects emotional positivity from mood entries.
            if key == "social" and mood_values:
                mood_positivity = (sum(mood_values) / len(mood_values)) / 5 * 100
                performance = (
                    round((performance + mood_positivity) / 2, 1)
                    if performance is not None
                    else round(mood_positivity, 1)
                )
                data_points += len(mood_values)

            if data_points == 0 or performance is None:
                confidence = "insufficient"
                score = None
                level_key = level_ar = level_en = None
            else:
                confidence = "high" if data_points >= 5 else "medium"
                score = int(round(performance))
                level_key, level_ar, level_en = self._level_for_score(score)

            results[key] = {
                "key": key,
                "title_en": domain["title_en"],
                "title_ar": domain["title_ar"],
                "score": score,
                "level": level_key,
                "level_label_ar": level_ar,
                "level_label_en": level_en,
                "confidence": confidence,
                "stats": {
                    "activities_count": total,
                    "average_score": avg_score,
                    "completion_rate": completion_rate,
                    "data_points": data_points,
                },
            }
        return results

    def _build_ai_prompt(self, *, child: ChildProfile, domains: list[dict], language: str) -> str:
        lines = [
            f"Child name: {child.name or 'the child'}",
            f"Child age: {child.age if child.age is not None else 'unknown'}",
            "Development areas (score out of 100, with supporting data):",
        ]
        for domain in domains:
            title = domain["title_ar"] if language == "ar" else domain["title_en"]
            stats = domain["stats"]
            if domain["score"] is None:
                lines.append(f"- {title}: not enough data yet ({stats['data_points']} data points)")
            else:
                lines.append(
                    f"- {title}: {domain['score']}/100 "
                    f"({stats['activities_count']} activities, "
                    f"avg score {stats['average_score']}, "
                    f"completion {round(stats['completion_rate'] * 100)}%)"
                )
        lines.append(
            "Write a short, warm summary for the parent: highlight strengths, "
            "give a gentle growth tip, and suggest 2-3 app activities."
        )
        return "\n".join(lines)

    def _ai_narrative(self, *, child: ChildProfile, domains: list[dict], language: str) -> dict:
        prompt = self._build_ai_prompt(child=child, domains=domains, language=language)
        provider_available = (
            settings.ai_provider_mode != "fallback" and enhanced_ai_provider.is_configured()
        )
        if provider_available:
            try:
                enhanced_ai_provider.ensure_runtime_ready()
                generated = enhanced_ai_provider.generate_development_summary(
                    prompt=prompt, is_arabic=(language == "ar")
                )
                if generated.content.strip():
                    return {
                        "language": language,
                        "source": "ai",
                        "summary": generated.content.strip(),
                        "model": generated.model,
                    }
            except Exception as exc:  # noqa: BLE001 - never fail the report on AI errors
                logger.warning("development_summary_ai_failed error=%s", str(exc))

        return {
            "language": language,
            "source": "fallback",
            "summary": self._fallback_summary(child=child, domains=domains, language=language),
            "model": None,
        }

    @staticmethod
    def _fallback_summary(*, child: ChildProfile, domains: list[dict], language: str) -> str:
        scored = [d for d in domains if d["score"] is not None]
        name = child.name or ("طفلك" if language == "ar" else "your child")
        if not scored:
            if language == "ar":
                return (
                    f"لا توجد بيانات كافية بعد لتقييم مجالات {name}. "
                    "شجّعه على تجربة أنشطة متنوعة في التطبيق وسيظهر التقرير قريبًا."
                )
            return (
                f"There isn't enough activity data yet to summarize {name}'s areas. "
                "Encourage a few varied activities in the app and the report will fill in."
            )
        top = max(scored, key=lambda d: d["score"])
        focus = min(scored, key=lambda d: d["score"])
        if language == "ar":
            return (
                f"أظهر {name} قوة واضحة في المجال {top['title_ar']}. "
                f"يمكن دعم المجال {focus['title_ar']} بمزيد من الأنشطة الممتعة في التطبيق. "
                "جرّبوا نشاطًا جديدًا كل يوم لمتابعة التقدم."
            )
        return (
            f"{name} shows clear strength in the {top['title_en']} area. "
            f"The {focus['title_en']} area can grow with a few more fun activities in the app. "
            "Try one new activity each day to keep progress going."
        )

    def build_development_profile(
        self,
        *,
        db: Session,
        user: User,
        child_id: int,
        days: int = 30,
        language: str = "ar",
    ) -> dict:
        language = "ar" if str(language).lower().startswith("ar") else "en"
        child = self._resolve_child(db=db, user=user, child_id=child_id)
        start_dt = utc_start_of_day(utc_today() - timedelta(days=days - 1))

        completion_events = (
            db.query(ChildActivityEvent)
            .filter(
                ChildActivityEvent.child_id == child.id,
                ChildActivityEvent.occurred_at >= start_dt,
                ChildActivityEvent.archived_at.is_(None),
                ChildActivityEvent.event_type.in_(COMPLETION_EVENT_TYPES),
            )
            .all()
        )
        mood_rows = (
            db.query(ChildActivityEvent.mood_value)
            .filter(
                ChildActivityEvent.child_id == child.id,
                ChildActivityEvent.event_type == "mood_entry",
                ChildActivityEvent.occurred_at >= start_dt,
                ChildActivityEvent.archived_at.is_(None),
                ChildActivityEvent.mood_value.is_not(None),
            )
            .all()
        )
        mood_values = [int(row[0]) for row in mood_rows]

        domain_map = self._domain_scores(events=completion_events, mood_values=mood_values)
        domains = [domain_map[domain["key"]] for domain in DOMAINS]

        scored = [d for d in domains if d["score"] is not None]
        overall = {
            "average_score": (
                int(round(sum(d["score"] for d in scored) / len(scored))) if scored else None
            ),
            "top_domain": (max(scored, key=lambda d: d["score"])["key"] if scored else None),
            "focus_domain": (min(scored, key=lambda d: d["score"])["key"] if scored else None),
            "domains_with_data": len(scored),
            "total_activities": len(completion_events),
        }

        narrative = self._ai_narrative(child=child, domains=domains, language=language)

        return {
            "child": {"id": child.id, "name": child.name, "age": child.age},
            "window_days": days,
            "generated_at": utc_now().isoformat(),
            "framing": "strengths_and_growth",
            "disclaimer": {
                "ar": (
                    "هذه المؤشرات تعكس مجالات قوة الطفل ونموه بناءً على نشاطه داخل التطبيق فقط، "
                    "وليست اختبار ذكاء رسميًا أو تشخيصًا. استخدمها للتشجيع ومتابعة التقدم."
                ),
                "en": (
                    "These indicators reflect the child's strengths and growth areas based only on "
                    "in-app activity. They are not a formal intelligence test or diagnosis."
                ),
            },
            "domains": domains,
            "overall": overall,
            "narrative": narrative,
            "data_source": "backend_analytics+ai",
            "access_level": "advanced",
            "selected_child_id": child_id,
        }


child_development_service = ChildDevelopmentService()
