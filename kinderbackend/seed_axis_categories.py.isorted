from __future__ import annotations

from collections import defaultdict

import admin_models  # noqa: F401  Ensures SQLAlchemy relationships resolve.
from core.time_utils import db_utc_now
from database import SessionLocal
from models import ContentCategory

CATEGORY_SEED = {
    "educational": [
        {
            "slug": "arabic",
            "title_en": "Arabic",
            "title_ar": "العربي",
            "description_en": "Arabic language lessons and videos",
            "description_ar": "دروس وفيديوهات اللغة العربية",
        },
        {
            "slug": "english",
            "title_en": "English",
            "title_ar": "الإنجليزي",
            "description_en": "English language lessons and videos",
            "description_ar": "دروس وفيديوهات اللغة الإنجليزية",
        },
        {
            "slug": "math",
            "title_en": "Math",
            "title_ar": "الرياضيات",
            "description_en": "Math lessons and activities for children",
            "description_ar": "دروس وأنشطة الرياضيات للأطفال",
        },
        {
            "slug": "science",
            "title_en": "Science",
            "title_ar": "العلوم",
            "description_en": "Science lessons and discovery videos",
            "description_ar": "دروس العلوم وفيديوهات الاكتشاف",
        },
        {
            "slug": "geography",
            "title_en": "Geography",
            "title_ar": "الجغرافيا",
            "description_en": "Geography lessons and world exploration videos",
            "description_ar": "دروس الجغرافيا وفيديوهات استكشاف العالم",
        },
        {
            "slug": "history",
            "title_en": "History",
            "title_ar": "التاريخ",
            "description_en": "History stories and educational videos",
            "description_ar": "قصص التاريخ والفيديوهات التعليمية",
        },
        {
            "slug": "animals",
            "title_en": "Animals",
            "title_ar": "الحيوانات",
            "description_en": "Animals lessons and discovery videos for children",
            "description_ar": "دروس وفيديوهات اكتشاف الحيوانات للأطفال",
        },
        {
            "slug": "plants",
            "title_en": "Plants",
            "title_ar": "النباتات",
            "description_en": "Plants lessons and nature discovery videos",
            "description_ar": "دروس النباتات وفيديوهات اكتشاف الطبيعة",
        },
    ],
    "skillful": [
        {
            "slug": "drawing",
            "title_en": "Drawing",
            "title_ar": "الرسم",
            "description_en": "Drawing lessons and creative activities",
            "description_ar": "دروس الرسم والأنشطة الإبداعية",
        },
        {
            "slug": "coloring",
            "title_en": "Coloring",
            "title_ar": "التلوين",
            "description_en": "Coloring practice and fun art activities",
            "description_ar": "تدريبات التلوين والأنشطة الفنية الممتعة",
        },
        {
            "slug": "music",
            "title_en": "Music",
            "title_ar": "الموسيقى",
            "description_en": "Music activities, rhythm, and simple songs",
            "description_ar": "أنشطة موسيقية وإيقاع وأغانٍ بسيطة",
        },
        {
            "slug": "singing",
            "title_en": "Singing",
            "title_ar": "الغناء",
            "description_en": "Singing activities, chants, and fun songs for children",
            "description_ar": "أنشطة غناء وأناشيد وأغاني ممتعة للأطفال",
        },
        {
            "slug": "crafts",
            "title_en": "Crafts",
            "title_ar": "الأعمال اليدوية",
            "description_en": "Handmade crafts and creative projects",
            "description_ar": "أعمال يدوية ومشروعات إبداعية",
        },
        {
            "slug": "cooking",
            "title_en": "Cooking",
            "title_ar": "الطبخ",
            "description_en": "Simple cooking skills and safe food activities",
            "description_ar": "مهارات طبخ بسيطة وأنشطة طعام آمنة",
        },
        {
            "slug": "sports",
            "title_en": "Sports",
            "title_ar": "الرياضة",
            "description_en": "Movement, exercise, and sports activities",
            "description_ar": "أنشطة الحركة والتمارين والرياضة",
        },
    ],
    "behavioral": [
        {
            "slug": "giving",
            "legacy_slugs": ["sharing"],
            "title_en": "Giving",
            "title_ar": "العطاء",
            "description_en": "Activities and videos about giving and sharing with others",
            "description_ar": "أنشطة وفيديوهات عن العطاء والمشاركة مع الآخرين",
        },
        {
            "slug": "honesty",
            "title_en": "Honesty",
            "title_ar": "الصدق",
            "description_en": "Lessons and stories about honesty",
            "description_ar": "دروس وقصص عن الصدق",
        },
        {
            "slug": "respect",
            "title_en": "Respect",
            "title_ar": "الاحترام",
            "description_en": "Videos and activities that teach respect",
            "description_ar": "فيديوهات وأنشطة تعلم الاحترام",
        },
        {
            "slug": "patience",
            "title_en": "Patience",
            "title_ar": "الصبر",
            "description_en": "Activities that help children learn patience",
            "description_ar": "أنشطة تساعد الطفل على تعلم الصبر",
        },
        {
            "slug": "kindness",
            "title_en": "Kindness",
            "title_ar": "اللطف",
            "description_en": "Content that encourages kindness and empathy",
            "description_ar": "محتوى يشجع اللطف والتعاطف",
        },
        {
            "slug": "responsibility",
            "title_en": "Responsibility",
            "title_ar": "المسؤولية",
            "description_en": "Lessons about responsibility and good habits",
            "description_ar": "دروس عن المسؤولية والعادات الجيدة",
        },
        {
            "slug": "tolerance",
            "title_en": "Tolerance",
            "title_ar": "التسامح",
            "description_en": "Content that teaches accepting differences and others",
            "description_ar": "محتوى يعلم تقبل الاختلاف والآخرين",
        },
        {
            "slug": "cooperation",
            "title_en": "Cooperation",
            "title_ar": "التعاون",
            "description_en": "Activities and stories about teamwork and cooperation",
            "description_ar": "أنشطة وقصص عن العمل الجماعي والتعاون",
        },
        {
            "slug": "courage",
            "title_en": "Courage",
            "title_ar": "الشجاعة",
            "description_en": "Videos and activities that build courage and confidence",
            "description_ar": "فيديوهات وأنشطة تبني الشجاعة والثقة",
        },
        {
            "slug": "gratitude",
            "title_en": "Gratitude",
            "title_ar": "الامتنان",
            "description_en": "Content that encourages thankfulness and appreciation",
            "description_ar": "محتوى يشجع الشكر والتقدير",
        },
        {
            "slug": "peace",
            "title_en": "Peace",
            "title_ar": "السلام",
            "description_en": "Activities about calmness, peace, and solving conflicts kindly",
            "description_ar": "أنشطة عن الهدوء والسلام وحل الخلاف بلطف",
        },
        {
            "slug": "love",
            "title_en": "Love",
            "title_ar": "الحب",
            "description_en": "Stories and videos about love, care, and family warmth",
            "description_ar": "قصص وفيديوهات عن الحب والاهتمام ودفء الأسرة",
        },
    ],
    "entertaining": [
        {
            "slug": "songs",
            "title_en": "Songs",
            "title_ar": "الأغاني",
            "description_en": "Fun songs and sing-along videos",
            "description_ar": "أغانٍ ممتعة وفيديوهات للغناء",
        },
        {
            "slug": "stories",
            "title_en": "Stories",
            "title_ar": "القصص",
            "description_en": "Short stories and storytelling videos",
            "description_ar": "قصص قصيرة وفيديوهات حكي",
        },
        {
            "slug": "cartoons",
            "title_en": "Cartoons",
            "title_ar": "الرسوم المتحركة",
            "description_en": "Entertaining cartoon videos for children",
            "description_ar": "فيديوهات رسوم متحركة ممتعة للأطفال",
        },
        {
            "slug": "games",
            "title_en": "Games",
            "title_ar": "الألعاب",
            "description_en": "Fun game-based content and playful activities",
            "description_ar": "محتوى ممتع قائم على الألعاب والأنشطة المرحة",
        },
        {
            "slug": "puppet-show",
            "title_en": "Puppet Show",
            "title_ar": "مسرح العرائس",
            "description_en": "Puppet shows and fun performance videos",
            "description_ar": "مسرح عرائس وفيديوهات عروض ممتعة",
        },
        {
            "slug": "interactive-fun",
            "title_en": "Interactive Fun",
            "title_ar": "المرح التفاعلي",
            "description_en": "Interactive entertainment and fun child activities",
            "description_ar": "ترفيه تفاعلي وأنشطة ممتعة للأطفال",
        },
    ],
}

MANAGED_AXES = {"behavioral", "educational"}


def main() -> None:
    db = SessionLocal()
    created = 0
    updated = 0
    try:
        for axis_key, items in CATEGORY_SEED.items():
            for item in items:
                candidate_slugs = [item["slug"], *(item.get("legacy_slugs") or [])]
                category = (
                    db.query(ContentCategory)
                    .filter(ContentCategory.slug.in_(candidate_slugs))
                    .first()
                )
                if category is None:
                    category = ContentCategory(
                        axis_key=axis_key,
                        slug=item["slug"],
                        title_en=item["title_en"],
                        title_ar=item["title_ar"],
                        description_en=item["description_en"],
                        description_ar=item["description_ar"],
                    )
                    db.add(category)
                    created += 1
                else:
                    category.axis_key = axis_key
                    category.slug = item["slug"]
                    category.title_en = item["title_en"]
                    category.title_ar = item["title_ar"]
                    category.description_en = item["description_en"]
                    category.description_ar = item["description_ar"]
                    category.deleted_at = None
                    updated += 1

        allowed_slugs_by_axis = {
            axis_key: {item["slug"] for item in items}
            for axis_key, items in CATEGORY_SEED.items()
            if axis_key in MANAGED_AXES
        }
        managed_categories = (
            db.query(ContentCategory)
            .filter(
                ContentCategory.deleted_at.is_(None),
                ContentCategory.axis_key.in_(MANAGED_AXES),
            )
            .all()
        )
        for category in managed_categories:
            allowed_slugs = allowed_slugs_by_axis.get(category.axis_key, set())
            if category.slug in allowed_slugs:
                continue
            active_content_count = len(
                [item for item in (category.contents or []) if item.deleted_at is None]
            )
            active_quiz_count = len(
                [item for item in (category.quizzes or []) if item.deleted_at is None]
            )
            if active_content_count == 0 and active_quiz_count == 0:
                category.deleted_at = db_utc_now()

        db.commit()

        grouped: dict[str, list[str]] = defaultdict(list)
        categories = (
            db.query(ContentCategory)
            .filter(ContentCategory.deleted_at.is_(None))
            .order_by(ContentCategory.axis_key.asc(), ContentCategory.title_en.asc())
            .all()
        )
        for category in categories:
            grouped[category.axis_key].append(category.title_en)

        print(f"[OK] created={created} updated={updated} total_active={len(categories)}")
        for axis_key, titles in grouped.items():
            print(f"- {axis_key}: {', '.join(titles)}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
