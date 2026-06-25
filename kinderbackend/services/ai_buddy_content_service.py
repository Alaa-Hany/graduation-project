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


# This catalog MUST mirror the activities the child actually sees in the Flutter
# app (kinder_world_child_mode/lib/features/child_mode/learn/data/learn_catalog.dart).
# The AI buddy is told to recommend ONLY from this list, so anything that is not
# a real, openable in-app activity will make it suggest things the child cannot
# find. Keep the four category keys aligned with the app's learn routes
# (behavioral / educational / skillful / entertaining) and use the same names.
ACTIVITY_CATEGORIES: dict[str, ActivityCatalogCategory] = {
    "behavioral": {
        "title_en": "Behavioral",
        "title_ar": "السلوكي",
        "activities": [
            # Values
            {"title_en": "Giving", "title_ar": "العطاء", "slug": "behavior_giving"},
            {"title_en": "Respect", "title_ar": "الاحترام", "slug": "behavior_respect"},
            {"title_en": "Tolerance", "title_ar": "التسامح", "slug": "behavior_tolerance"},
            {"title_en": "Kindness", "title_ar": "اللطف", "slug": "behavior_kindness"},
            {"title_en": "Cooperation", "title_ar": "التعاون", "slug": "behavior_cooperation"},
            {
                "title_en": "Responsibility",
                "title_ar": "المسؤولية",
                "slug": "behavior_responsibility",
            },
            {"title_en": "Honesty", "title_ar": "الأمانة", "slug": "behavior_honesty"},
            {"title_en": "Patience", "title_ar": "الصبر", "slug": "behavior_patience"},
            {"title_en": "Courage", "title_ar": "الشجاعة", "slug": "behavior_courage"},
            {"title_en": "Gratitude", "title_ar": "الامتنان", "slug": "behavior_gratitude"},
            {"title_en": "Peace", "title_ar": "السلام", "slug": "behavior_peace"},
            {"title_en": "Love", "title_ar": "الحب", "slug": "behavior_love"},
            # Methods
            {"title_en": "Relaxation", "title_ar": "الاسترخاء", "slug": "method_relaxation"},
            {"title_en": "Imagination", "title_ar": "الخيال", "slug": "method_imagination"},
            {"title_en": "Meditation", "title_ar": "التأمل", "slug": "method_meditation"},
            {"title_en": "Art Expression", "title_ar": "التعبير الفني", "slug": "method_art"},
        ],
    },
    "educational": {
        "title_en": "Educational",
        "title_ar": "التعليمي",
        "activities": [
            {"title_en": "English", "title_ar": "الإنجليزية", "slug": "edu_english"},
            {"title_en": "Arabic", "title_ar": "العربية", "slug": "edu_arabic"},
            {"title_en": "Geography", "title_ar": "الجغرافيا", "slug": "edu_geography"},
            {"title_en": "History", "title_ar": "التاريخ", "slug": "edu_history"},
            {"title_en": "Science", "title_ar": "العلوم", "slug": "edu_science"},
            {"title_en": "Math", "title_ar": "الرياضيات", "slug": "edu_math"},
            {"title_en": "Animals", "title_ar": "الحيوانات", "slug": "edu_animals"},
            {"title_en": "Plants", "title_ar": "النباتات", "slug": "edu_plants"},
        ],
    },
    "skillful": {
        "title_en": "Skillful",
        "title_ar": "المهاري",
        "activities": [
            {"title_en": "Cooking", "title_ar": "الطبخ", "slug": "skill_cooking"},
            {"title_en": "Drawing", "title_ar": "الرسم", "slug": "skill_drawing"},
            {"title_en": "Coloring", "title_ar": "التلوين", "slug": "skill_coloring"},
            {"title_en": "Music", "title_ar": "الموسيقى", "slug": "skill_music"},
            {"title_en": "Singing", "title_ar": "الغناء", "slug": "skill_singing"},
            {"title_en": "Handcrafts", "title_ar": "الأشغال اليدوية", "slug": "skill_handcrafts"},
            {"title_en": "Sports", "title_ar": "الرياضة", "slug": "skill_sports"},
        ],
    },
    "entertaining": {
        "title_en": "Entertaining",
        "title_ar": "الترفيهي",
        "activities": [
            {"title_en": "Puppet Show", "title_ar": "عروض الدمى", "slug": "ent_puppet_show"},
            {"title_en": "Interactive Stories", "title_ar": "قصص تفاعلية", "slug": "ent_stories"},
            {"title_en": "Songs & Music", "title_ar": "أغاني وموسيقى", "slug": "ent_music"},
            {"title_en": "Funny Clips", "title_ar": "مقاطع مضحكة", "slug": "ent_clips"},
            {"title_en": "Brain Teasers", "title_ar": "ألغاز ذهنية", "slug": "ent_teasers"},
            {"title_en": "Games", "title_ar": "ألعاب", "slug": "ent_games"},
            {"title_en": "Cartoons", "title_ar": "رسوم متحركة", "slug": "ent_cartoons"},
        ],
    },
}


# Real lessons the child can actually open inside the app. This MUST mirror the
# Flutter lesson catalog
# (kinder_world_child_mode/lib/features/child_mode/learn/data/lesson_catalog.dart)
# so the AI buddy can recommend a concrete lesson BY NAME ("try the Counting
# Numbers 1-10 lesson") instead of only naming a section. Anything listed here
# must be a real, openable lesson.
FEATURED_LESSONS: list[dict[str, str]] = [
    # Math
    {
        "id": "math_01",
        "title_en": "Counting Numbers 1-10",
        "title_ar": "العدّ من ١ إلى ١٠",
        "subject": "Math",
        "subject_ar": "الرياضيات",
    },
    {
        "id": "math_02",
        "title_en": "Addition Basics",
        "title_ar": "أساسيات الجمع",
        "subject": "Math",
        "subject_ar": "الرياضيات",
    },
    {
        "id": "math_03",
        "title_en": "Shapes and Patterns",
        "title_ar": "الأشكال والأنماط",
        "subject": "Math",
        "subject_ar": "الرياضيات",
    },
    # Science
    {
        "id": "sci_01",
        "title_en": "Parts of a Plant",
        "title_ar": "أجزاء النبات",
        "subject": "Science",
        "subject_ar": "العلوم",
    },
    {
        "id": "sci_02",
        "title_en": "Weather and Seasons",
        "title_ar": "الطقس والفصول",
        "subject": "Science",
        "subject_ar": "العلوم",
    },
    {
        "id": "sci_03",
        "title_en": "Animal Habitats",
        "title_ar": "بيوت الحيوانات",
        "subject": "Science",
        "subject_ar": "العلوم",
    },
    # Reading
    {
        "id": "read_01",
        "title_en": "Alphabet Fun",
        "title_ar": "متعة الحروف",
        "subject": "Reading",
        "subject_ar": "القراءة",
    },
    {
        "id": "read_02",
        "title_en": "Short Vowel Sounds",
        "title_ar": "أصوات الحروف المتحركة",
        "subject": "Reading",
        "subject_ar": "القراءة",
    },
    {
        "id": "read_03",
        "title_en": "Simple Words",
        "title_ar": "كلمات بسيطة",
        "subject": "Reading",
        "subject_ar": "القراءة",
    },
    # History
    {
        "id": "history_01",
        "title_en": "Yesterday and Today",
        "title_ar": "الأمس واليوم",
        "subject": "History",
        "subject_ar": "التاريخ",
    },
    {
        "id": "history_02",
        "title_en": "Helpers from the Past",
        "title_ar": "مساعدون من الماضي",
        "subject": "History",
        "subject_ar": "التاريخ",
    },
    # Geography
    {
        "id": "geography_01",
        "title_en": "Maps Around Us",
        "title_ar": "الخرائط من حولنا",
        "subject": "Geography",
        "subject_ar": "الجغرافيا",
    },
    {
        "id": "geography_02",
        "title_en": "Land and Water",
        "title_ar": "اليابسة والماء",
        "subject": "Geography",
        "subject_ar": "الجغرافيا",
    },
]


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

    def get_featured_lessons(self) -> list[dict[str, str]]:
        """Real, openable lessons the buddy may recommend by name."""
        return list(FEATURED_LESSONS)


ai_buddy_content_service = AiBuddyContentService()
