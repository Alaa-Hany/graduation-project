"""
AI Buddy Content Service - App activities and suggestions
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import TypedDict

logger = logging.getLogger(__name__)


class ActivityCatalogEntry(TypedDict):
    title_en: str
    title_ar: str
    slug: str


class ActivityCatalogCategory(TypedDict):
    title_en: str
    title_ar: str
    activities: list[ActivityCatalogEntry]


class ActivitySuggestionPayload(ActivityCatalogEntry):
    category: str
    category_title_en: str
    category_title_ar: str


ACTIVITY_CATEGORIES: dict[str, ActivityCatalogCategory] = {
    "educational": {
        "title_en": "Educational",
        "title_ar": "تعليمي",
        "activities": [
            {"title_en": "Math", "title_ar": "رياضيات", "slug": "edu_math"},
            {"title_en": "Arabic", "title_ar": "عربي", "slug": "edu_arabic"},
            {"title_en": "English", "title_ar": "إنجليزي", "slug": "edu_english"},
            {"title_en": "Science - Animals", "title_ar": "علوم - حيوانات", "slug": "edu_animals"},
            {"title_en": "Science - Plants", "title_ar": "علوم - نباتات", "slug": "edu_plants"},
        ],
    },
    "skillful": {
        "title_en": "Skill Building",
        "title_ar": "مهارات",
        "activities": [
            {"title_en": "Drawing", "title_ar": "رسم", "slug": "skill_drawing"},
            {"title_en": "Coloring", "title_ar": "تلوين", "slug": "skill_coloring"},
            {"title_en": "Music", "title_ar": "موسيقى", "slug": "skill_music"},
            {"title_en": "Sports", "title_ar": "رياضة", "slug": "skill_sports"},
        ],
    },
    "entertainment": {
        "title_en": "Entertainment",
        "title_ar": "ترفيه",
        "activities": [
            {"title_en": "Games", "title_ar": "ألعاب", "slug": "ent_games"},
            {"title_en": "Stories", "title_ar": "قصص", "slug": "ent_stories"},
        ],
    },
}


@dataclass(slots=True)
class ActivitySuggestion:
    title_en: str
    title_ar: str
    slug: str
    category: str
    category_title_en: str
    category_title_ar: str


class AiBuddyContentService:
    def get_all_activities(self) -> list[ActivitySuggestionPayload]:
        activities: list[ActivitySuggestionPayload] = []
        for category_key, category_data in ACTIVITY_CATEGORIES.items():
            for activity in category_data["activities"]:
                activities.append(
                    {
                        "title_en": activity["title_en"],
                        "title_ar": activity["title_ar"],
                        "slug": activity["slug"],
                        "category": category_key,
                        "category_title_en": category_data["title_en"],
                        "category_title_ar": category_data["title_ar"],
                    }
                )
        return activities

    def get_activities_for_age(self, age: int) -> list[ActivitySuggestionPayload]:
        _ = age
        return self.get_all_activities()

    def get_activities_by_category(self, category: str) -> list[ActivitySuggestionPayload]:
        all_activities = self.get_all_activities()
        return [activity for activity in all_activities if activity["category"] == category]


ai_buddy_content_service = AiBuddyContentService()
