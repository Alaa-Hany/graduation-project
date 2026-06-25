from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field, replace
from typing import Iterable, Protocol

from core.settings import settings
from services.ai_buddy_content_service import ai_buddy_content_service
from services.ai_providers.enhanced_ai_provider import enhanced_ai_provider

logger = logging.getLogger(__name__)

_ARABIC_PATTERN = re.compile(r"[؀-ۿ]")


def _select_diverse_activities(activities: list[dict], *, limit: int = 16) -> list[dict]:
    """Pick a spread of activities across every category.

    The provider is only shown a slice of the catalog, and a plain ``[:limit]``
    would always surface the first category (e.g. only "Behavioral" items),
    making the buddy recommend the same narrow set every time. Round-robining
    across categories lets the model see options from every part of the app.
    """
    from collections import OrderedDict

    buckets: "OrderedDict[str, list[dict]]" = OrderedDict()
    for activity in activities:
        buckets.setdefault(activity.get("category", ""), []).append(activity)

    selected: list[dict] = []
    while len(selected) < limit and any(buckets.values()):
        for items in buckets.values():
            if items:
                selected.append(items.pop(0))
                if len(selected) >= limit:
                    break
    return selected


def _resolve_is_arabic(locale: str | None, *texts: str) -> bool:
    """Decide the reply language for AI Buddy.

    When the caller supplies the app's UI locale we honour it directly, so the
    buddy always answers in the language of the app the child is using. We only
    fall back to sniffing the message/name text when no locale is provided
    (older clients or internal callers that don't pass one).
    """
    if locale:
        return locale.strip().lower().startswith("ar")
    return any(bool(_ARABIC_PATTERN.search(text or "")) for text in texts)


@dataclass(slots=True)
class AiBuddyProviderState:
    configured: bool
    mode: str
    status: str
    reason: str | None = None
    provider_key: str | None = None
    model: str | None = None
    supports_activity_suggestions: bool = False


@dataclass(slots=True)
class AiBuddyGeneratedResponse:
    content: str
    intent: str
    response_source: str
    status: str
    safety_status: str
    provider_state: AiBuddyProviderState
    metadata_json: dict[str, object] = field(default_factory=dict)


class _AiBuddyBackend(Protocol):
    def provider_state(self) -> AiBuddyProviderState: ...

    def greeting(
        self,
        *,
        child_name: str | None = None,
        locale: str | None = None,
    ) -> AiBuddyGeneratedResponse: ...

    def generate(
        self,
        *,
        child_name: str | None,
        child_age: int | None,
        message: str,
        quick_action: str | None,
        recent_messages: Iterable[str],
        conversation_history: Iterable[dict] | None = None,
        locale: str | None = None,
    ) -> AiBuddyGeneratedResponse: ...


class _InternalFallbackAiBuddyBackend:
    _default_reason = (
        "AI Buddy is running in safe fallback mode. " "No external AI provider is configured yet."
    )

    # Pools of canned content rotated by the conversation's reply count so the
    # safe fallback does not repeat the same story/fact/game every time.
    _STORIES_EN = (
        "Here is a tiny story: A brave little star felt scared of the dark sky, "
        "but it kept shining until other stars joined in. Soon the whole sky looked friendly.",
        "Here is a tiny story: A small turtle wanted to win a race. He went slow and steady, "
        "never gave up, and crossed the line with a big proud smile.",
        "Here is a tiny story: A little cloud was sad it could not play. Then it rained gently, "
        "and flowers grew everywhere. The cloud learned its gift made the world bloom.",
        "Here is a tiny story: A tiny ant found a crumb too big to carry. She asked her friends, "
        "and together they moved it home. Helping each other made the job easy and fun.",
        "Here is a tiny story: A shy little bird was afraid to sing. One morning it tried one note, "
        "then another, and the whole garden smiled. Trying a little was all it took.",
        "Here is a tiny story: A puppy lost its favorite ball. Instead of crying, it looked carefully "
        "everywhere and found it under a leaf. Staying calm helped it solve the puzzle.",
        "Here is a tiny story: Two friends both wanted the same swing. They decided to take turns, "
        "and ended up laughing together. Sharing turned a problem into fun.",
        "Here is a tiny story: A little seed was buried in the dark soil and felt alone. It kept "
        "growing day by day until it became a tall sunflower reaching the warm sun.",
    )
    _STORIES_AR = (
        "قصة قصيرة: كان نجم صغير يخاف من الظلام، لكنه ظل يلمع حتى اجتمعت حوله نجوم أخرى، "
        "فصار الليل جميلًا ومطمئنًا.",
        "قصة قصيرة: أرادت سلحفاة صغيرة أن تفوز في السباق. مشت بهدوء وثبات ولم تستسلم، "
        "ووصلت إلى خط النهاية وهي فخورة وسعيدة.",
        "قصة قصيرة: حزنت سحابة صغيرة لأنها لا تستطيع اللعب، ثم أمطرت بلطف فنمت الزهور في كل مكان، "
        "وتعلمت أن هديتها تجعل العالم أجمل.",
        "قصة قصيرة: وجدت نملة صغيرة كسرة كبيرة لا تقدر على حملها، فنادت أصدقاءها وحملوها معًا إلى البيت، "
        "وتعلموا أن التعاون يجعل العمل سهلًا وممتعًا.",
        "قصة قصيرة: كان عصفور صغير خجولًا يخاف أن يغرّد، فجرّب نغمة واحدة ثم أخرى حتى ابتسمت الحديقة كلها، "
        "وتعلّم أن المحاولة الصغيرة تكفي.",
        "قصة قصيرة: أضاع جرو كرته المفضلة، لكنه بدل أن يبكي بحث بهدوء في كل مكان فوجدها تحت ورقة شجر، "
        "وتعلّم أن الهدوء يساعده على حلّ المشكلة.",
        "قصة قصيرة: أراد صديقان اللعب على نفس الأرجوحة، فاتفقا أن يتناوبا، وانتهى بهما الأمر يضحكان معًا، "
        "فحوّلت المشاركة المشكلة إلى متعة.",
        "قصة قصيرة: كانت بذرة صغيرة مدفونة في التراب تشعر بالوحدة، لكنها ظلت تنمو يومًا بعد يوم "
        "حتى صارت زهرة عبّاد شمس طويلة تعانق الشمس الدافئة.",
    )
    _FACTS_EN = (
        "Fun fact: octopuses have three hearts.",
        "Fun fact: a group of flamingos is called a flamboyance.",
        "Fun fact: honey never spoils — it can last for thousands of years.",
        "Fun fact: butterflies taste with their feet.",
        "Fun fact: a baby kangaroo is as small as a jellybean when it is born.",
        "Fun fact: the Sun is so big that about one million Earths could fit inside it.",
        "Fun fact: snails can sleep for up to three years if the weather is dry.",
        "Fun fact: a bolt of lightning is about five times hotter than the surface of the Sun.",
    )
    _FACTS_AR = (
        "معلومة لطيفة: للأخطبوط ثلاثة قلوب.",
        "معلومة لطيفة: قلب الجمبري موجود في رأسه.",
        "معلومة لطيفة: العسل لا يفسد أبدًا، وقد يبقى صالحًا لآلاف السنين.",
        "معلومة لطيفة: الفراشة تتذوق الطعام بأقدامها.",
        "معلومة لطيفة: صغير الكنغر عند ولادته بحجم حبة الفول الصغيرة.",
        "معلومة لطيفة: الشمس كبيرة جدًا حتى إنه يمكن أن تتسع لمليون كوكب مثل الأرض.",
        "معلومة لطيفة: يستطيع الحلزون أن ينام إلى ثلاث سنوات إذا كان الجو جافًا.",
        "معلومة لطيفة: البرق أسخن من سطح الشمس بنحو خمس مرات.",
    )
    _GAMES_EN = (
        "here is a simple game: find one red thing, one blue thing, and one soft thing. "
        "When you finish, tell me what you found.",
        "here is a simple game: clap once for every animal you can name in ten seconds. Ready, go!",
        "here is a simple game: look around and find three things that are round. "
        "Which one is your favorite?",
        "here is a simple game: hop on one foot and count how high you can go. Tell me your number!",
        "here is a simple game: think of an animal and make its sound. I will try to guess it!",
        "here is a simple game: find something that starts with the same letter as your name. "
        "What did you pick?",
        "here is a simple game: name three things you can see that are green. Go!",
        "here is a simple game: stand up and stretch tall like a tree, then curl up small like a "
        "seed. How many times can you do it?",
    )
    _GAMES_AR = (
        "لعبة سريعة: ابحث عن شيء أحمر وشيء أزرق وشيء ناعم، وعندما تنتهي أخبرني ماذا وجدت.",
        "لعبة سريعة: صفّق مرة لكل حيوان تعرف اسمه خلال عشر ثوانٍ. استعد، هيا!",
        "لعبة سريعة: انظر حولك وابحث عن ثلاثة أشياء دائرية. أيها يعجبك أكثر؟",
        "لعبة سريعة: اقفز على قدم واحدة وعُدّ كم مرة تقدر. أخبرني الرقم!",
        "لعبة سريعة: فكّر في حيوان وقلّد صوته، وأنا سأحاول تخمينه!",
        "لعبة سريعة: ابحث عن شيء يبدأ بأول حرف من اسمك. ماذا اخترت؟",
        "لعبة سريعة: سمِّ ثلاثة أشياء خضراء تراها حولك. هيا!",
        "لعبة سريعة: قف ومُدّ جسمك عاليًا مثل الشجرة، ثم انكمش صغيرًا مثل البذرة. كم مرة تقدر تكررها؟",
    )

    def __init__(self, *, content_service=ai_buddy_content_service) -> None:
        self._content_service = content_service

    def provider_state(self) -> AiBuddyProviderState:
        return AiBuddyProviderState(
            configured=False,
            mode="internal_fallback",
            status="fallback",
            reason=self._default_reason,
            provider_key="internal",
            model=None,
            supports_activity_suggestions=True,
        )

    def greeting(
        self,
        *,
        child_name: str | None = None,
        locale: str | None = None,
    ) -> AiBuddyGeneratedResponse:
        name = (child_name or "").strip()
        is_arabic = _resolve_is_arabic(locale, name)
        if is_arabic:
            if name:
                content = (
                    f"مرحبًا {name}! أنا رفيقك التعليمي في الوضع الآمن. "
                    "اطلب مني فكرة درس أو لعبة ممتعة أو قصة قصيرة."
                )
            else:
                content = (
                    "مرحبًا! أنا رفيقك التعليمي في الوضع الآمن. "
                    "اطلب مني فكرة درس أو لعبة ممتعة أو قصة قصيرة."
                )
        elif name:
            content = (
                f"Hello {name}! I am your learning buddy in safe mode. "
                "Ask me for a lesson idea, a fun game, or a short story."
            )
        else:
            content = (
                "Hello! I am your learning buddy in safe mode. "
                "Ask me for a lesson idea, a fun game, or a short story."
            )
        return AiBuddyGeneratedResponse(
            content=content,
            intent="greeting",
            response_source="internal_fallback",
            status="completed",
            safety_status="allowed",
            provider_state=self.provider_state(),
            metadata_json={
                "generation_mode": "greeting",
                "experience_mode": "fallback_only",
            },
        )

    def generate(
        self,
        *,
        child_name: str | None,
        child_age: int | None,
        message: str,
        quick_action: str | None,
        recent_messages: Iterable[str],
        conversation_history: Iterable[dict] | None = None,
        locale: str | None = None,
    ) -> AiBuddyGeneratedResponse:
        normalized = message.strip()
        normalized_lower = normalized.lower()
        is_arabic = _resolve_is_arabic(locale, normalized)
        intent = quick_action or self._infer_intent(normalized_lower)
        content = self._build_response(
            child_name=child_name,
            child_age=child_age,
            message=normalized,
            intent=intent,
            is_arabic=is_arabic,
            recent_messages=recent_messages,
            conversation_history=conversation_history,
        )
        return AiBuddyGeneratedResponse(
            content=content,
            intent=intent,
            response_source="internal_fallback",
            status="completed",
            safety_status="allowed",
            provider_state=self.provider_state(),
            metadata_json={
                "generation_mode": "internal_fallback",
                "experience_mode": "fallback_only",
                "language": "ar" if is_arabic else "en",
                "recent_turns_used": min(sum(1 for _ in recent_messages), 6),
            },
        )

    def with_reason(
        self,
        response: AiBuddyGeneratedResponse,
        *,
        reason: str | None,
    ) -> AiBuddyGeneratedResponse:
        if not reason:
            return response
        provider_state = replace(response.provider_state, reason=reason)
        metadata_json = dict(response.metadata_json)
        metadata_json["fallback_reason"] = reason
        return AiBuddyGeneratedResponse(
            content=response.content,
            intent=response.intent,
            response_source=response.response_source,
            status=response.status,
            safety_status=response.safety_status,
            provider_state=provider_state,
            metadata_json=metadata_json,
        )

    def _infer_intent(self, lowered: str) -> str:
        if any(token in lowered for token in ("math", "number", "count")):
            return "recommend_lesson"
        if any(token in lowered for token in ("story", "read", "adventure")):
            return "tell_story"
        if any(token in lowered for token in ("game", "play", "fun")):
            return "suggest_game"
        if any(token in lowered for token in ("sad", "upset", "angry", "tired")):
            return "motivation"
        if any(token in lowered for token in ("fact", "why", "how")):
            return "fun_fact"
        return "general_help"

    def _build_response(
        self,
        *,
        child_name: str | None,
        child_age: int | None,
        message: str,
        intent: str,
        is_arabic: bool,
        recent_messages: Iterable[str],
        conversation_history: Iterable[dict] | None = None,
    ) -> str:
        variant = self._rotation_index(conversation_history)
        if is_arabic:
            return self._build_arabic_response(
                child_name=child_name,
                child_age=child_age,
                intent=intent,
                message=message,
                variant=variant,
            )
        return self._build_english_response(
            child_name=child_name,
            child_age=child_age,
            intent=intent,
            message=message,
            recent_messages=recent_messages,
            variant=variant,
        )

    def _rotation_index(self, conversation_history: Iterable[dict] | None) -> int:
        """How many buddy replies came before this one.

        Used to rotate canned stories/facts/games so the safe fallback does not
        repeat the same story every time within a session.
        """
        if not conversation_history:
            return 0
        return sum(1 for item in conversation_history if (item or {}).get("role") == "assistant")

    def _build_english_response(
        self,
        *,
        child_name: str | None,
        child_age: int | None,
        intent: str,
        message: str,
        recent_messages: Iterable[str],
        variant: int = 0,
    ) -> str:
        prefix = f"{child_name}, " if child_name else ""
        activity = self._recommended_activity(intent=intent, child_age=child_age)
        lesson = self._recommended_lesson(variant)
        if intent == "recommend_lesson":
            if lesson is not None:
                return (
                    f"{prefix}let's try the \"{lesson['title_en']}\" lesson in {lesson['subject']}. "
                    "When you finish, tell me one new thing you learned!"
                )
            if activity is not None:
                return (
                    f"{prefix}let's try the {activity['title_en']} activity in the "
                    f"{activity['category_title_en']} section. After that, count five things around you "
                    "and tell me which one is the biggest."
                )
            return (
                f"{prefix}let's try a short lesson challenge: count five things around you, "
                "then tell me which one is the biggest."
            )
        if intent == "suggest_game":
            if activity is not None:
                return (
                    f"{prefix}you could open the {activity['title_en']} activity in the "
                    f"{activity['category_title_en']} section, then come back and tell me your favorite part."
                )
            return f"{prefix}{self._pick(self._GAMES_EN, variant)}"
        if intent == "tell_story":
            return self._pick(self._STORIES_EN, variant)
        if intent == "fun_fact":
            fact = self._pick(self._FACTS_EN, variant)
            if activity is not None:
                return (
                    f"{fact} "
                    f"If you want, we can also explore the {activity['title_en']} activity in the app."
                )
            return f"{fact} If you want, I can give you another fact about animals or space."
        if intent == "motivation":
            return (
                f"{prefix}it is okay to feel tired or sad sometimes. Take one deep breath, wiggle your shoulders, "
                "and try one small step. I can stay with you and help."
            )
        if any("?" in item for item in recent_messages):
            if activity is not None:
                return (
                    f"{prefix}I can help with that. We could try the {activity['title_en']} activity, "
                    "or I can tell you a story, suggest a game, or share a fun fact."
                )
            return f"{prefix}I can help with that. Tell me if you want a lesson idea, a game, a story, or a fun fact."
        return (
            f'{prefix}I heard you say: "{message[:80]}". '
            "I can help with learning, stories, games, and kind encouragement."
        )

    @staticmethod
    def _pick(pool: tuple[str, ...], variant: int) -> str:
        """Rotate through a pool so repeated requests get different content."""
        if not pool:
            return ""
        return pool[variant % len(pool)]

    def _recommended_activity(
        self,
        *,
        intent: str,
        child_age: int | None,
    ) -> dict[str, str] | None:
        activities = self._content_service.get_activities_for_age(child_age or 0)
        if not activities:
            return None
        category_map = {
            "recommend_lesson": "educational",
            "suggest_game": "entertainment",
            "fun_fact": "educational",
        }
        preferred_category = category_map.get(intent)
        if preferred_category:
            for activity in activities:
                if activity["category"] == preferred_category:
                    return activity
        return activities[0]

    def _recommended_lesson(self, variant: int) -> dict[str, str] | None:
        """Pick a real, openable lesson to recommend by name, rotating by turn."""
        get_lessons = getattr(self._content_service, "get_featured_lessons", None)
        lessons = list(get_lessons()) if callable(get_lessons) else []
        if not lessons:
            return None
        return lessons[variant % len(lessons)]

    def _build_arabic_response(
        self,
        *,
        child_name: str | None,
        child_age: int | None,
        intent: str,
        message: str,
        variant: int = 0,
    ) -> str:
        prefix = f"{child_name}، " if child_name else ""
        activity = self._recommended_activity(intent=intent, child_age=child_age)
        lesson = self._recommended_lesson(variant)
        # The catalog is Arabic-first, but be defensive: fall back to the English
        # label if an Arabic title is missing so we never raise on a stray entry.
        act_title = ""
        act_section = ""
        if activity is not None:
            act_title = activity.get("title_ar") or activity.get("title_en") or ""
            act_section = (
                activity.get("category_title_ar") or activity.get("category_title_en") or ""
            )
        has_activity = bool(act_title)
        if intent == "recommend_lesson":
            if lesson is not None:
                lesson_title = lesson.get("title_ar") or lesson.get("title_en") or ""
                lesson_subject = lesson.get("subject_ar") or lesson.get("subject") or ""
                return (
                    f'{prefix}لنجرّب درس "{lesson_title}" في {lesson_subject}. '
                    "وبعد ما تخلّص، قُل لي معلومة جديدة اتعلمتها!"
                )
            return (
                f"{prefix}لنجرّب درسًا قصيرًا وممتعًا. عُدّ خمسة أشياء حولك، ثم أخبرني أيها أكبر."
            )
        if intent == "suggest_game":
            if has_activity:
                return (
                    f'{prefix}ممكن تفتح نشاط "{act_title}" في قسم '
                    f"{act_section}، وبعدها ترجع تقول لي أكتر حاجة عجبتك فيه."
                )
            return f"{prefix}{self._pick(self._GAMES_AR, variant)}"
        if intent == "tell_story":
            story = self._pick(self._STORIES_AR, variant)
            if has_activity:
                return (
                    f'{story} ولو حابب قصص أكتر، تقدر تفتح "{act_title}" في قسم '
                    f"{act_section}. في رأيك إيه اللي حصل بعد كده؟"
                )
            return story
        if intent == "fun_fact":
            fact = self._pick(self._FACTS_AR, variant)
            if has_activity:
                return (
                    f'{fact} ولو حابب تعرف أكتر، تقدر تجرّب "{act_title}" في قسم ' f"{act_section}."
                )
            return f"{fact} إذا أردت، أقول لك معلومة أخرى عن الحيوانات أو الفضاء."
        if intent == "motivation":
            return (
                f"{prefix}من الطبيعي أن تشعر بالتعب أحيانًا. "
                "خذ نفسًا عميقًا، ثم جرّب خطوة صغيرة، وأنا سأساعدك."
            )
        if has_activity:
            return (
                f'{prefix}أنا هنا لمساعدتك. ممكن نجرّب نشاط "{act_title}" في قسم '
                f"{act_section}، أو أحكي لك قصة أو أقترح لعبة أو معلومة ممتعة."
            )
        return (
            f"{prefix}أنا هنا لمساعدتك. "
            "يمكنني أن أقترح درسًا أو لعبة أو قصة قصيرة أو معلومة ممتعة."
        )


class _EnhancedAiBuddyBackend:
    def __init__(
        self,
        *,
        provider=enhanced_ai_provider,
        content_service=ai_buddy_content_service,
    ) -> None:
        self._provider = provider
        self._content_service = content_service

    def provider_state(self) -> AiBuddyProviderState:
        provider_key = "openai" if settings.ai_provider_mode == "openai" else "external"
        if settings.ai_provider_mode == "fallback":
            return AiBuddyProviderState(
                configured=False,
                mode="internal_fallback",
                status="fallback",
                reason=None,
                provider_key="internal",
                model=None,
                supports_activity_suggestions=True,
            )
        if not self._provider.is_configured():
            return AiBuddyProviderState(
                configured=False,
                mode=provider_key,
                status="unavailable",
                reason="AI provider mode is enabled but the provider API key is missing.",
                provider_key=provider_key,
                model=settings.ai_model,
                supports_activity_suggestions=True,
            )
        try:
            self._provider.ensure_runtime_ready()
        except RuntimeError as exc:
            return AiBuddyProviderState(
                configured=False,
                mode=provider_key,
                status="unavailable",
                reason=str(exc),
                provider_key=provider_key,
                model=settings.ai_model,
                supports_activity_suggestions=True,
            )
        return AiBuddyProviderState(
            configured=True,
            mode=provider_key,
            status="ready",
            reason=None,
            provider_key=provider_key,
            model=settings.ai_model,
            supports_activity_suggestions=True,
        )

    def greeting(
        self,
        *,
        child_name: str | None = None,
        locale: str | None = None,
    ) -> AiBuddyGeneratedResponse:
        # The greeting is formulaic ("Hi, ask me for a story/game/lesson"), so we
        # template it locally instead of spending a live API call on every new
        # session. That makes opening the buddy instant and removes a network
        # failure point at the exact moment the child arrives; the provider is
        # still used for every real reply afterwards.
        is_arabic = _resolve_is_arabic(locale, child_name or "")
        content = self._build_greeting(child_name=child_name, is_arabic=is_arabic)
        provider_state = self.provider_state()
        return AiBuddyGeneratedResponse(
            content=content,
            intent="greeting",
            response_source=f"provider_{provider_state.provider_key or provider_state.mode}",
            status="completed",
            safety_status="allowed",
            provider_state=provider_state,
            metadata_json={
                "generation_mode": "templated_greeting",
                "provider_key": provider_state.provider_key,
                "model": provider_state.model,
            },
        )

    @staticmethod
    def _build_greeting(*, child_name: str | None, is_arabic: bool) -> str:
        name = (child_name or "").strip()
        if is_arabic:
            who = f"مرحبًا {name}! " if name else "مرحبًا! "
            return f"{who}أنا رفيقك كيندر. اطلب مني قصة قصيرة أو لعبة ممتعة أو فكرة درس!"
        who = f"Hi {name}! " if name else "Hi there! "
        return (
            f"{who}I'm Kinder, your buddy. Ask me for a short story, a fun game, or a lesson idea!"
        )

    def generate(
        self,
        *,
        child_name: str | None,
        child_age: int | None,
        message: str,
        quick_action: str | None,
        recent_messages: Iterable[str],
        conversation_history: Iterable[dict] | None = None,
        locale: str | None = None,
    ) -> AiBuddyGeneratedResponse:
        is_arabic = _resolve_is_arabic(locale, message)
        activities = self._content_service.get_activities_for_age(child_age or 0)
        activities = _select_diverse_activities(activities)
        get_lessons = getattr(self._content_service, "get_featured_lessons", None)
        featured_lessons = list(get_lessons()) if callable(get_lessons) else []
        generated = self._provider.generate(
            child_name=child_name,
            message=message,
            quick_action=quick_action,
            recent_messages=list(recent_messages),
            conversation_history=list(conversation_history) if conversation_history else None,
            is_arabic=is_arabic,
            child_age=child_age,
            available_activities=[
                {
                    "title_en": activity.get("title_en", ""),
                    "title_ar": activity.get("title_ar", ""),
                    "slug": activity.get("slug", ""),
                    "category": activity.get("category", ""),
                    "category_title_en": activity.get("category_title_en", ""),
                }
                for activity in activities
            ],
            featured_lessons=featured_lessons,
        )
        provider_state = self.provider_state()
        return AiBuddyGeneratedResponse(
            content=generated.content,
            intent=generated.intent,
            response_source=f"provider_{provider_state.provider_key or provider_state.mode}",
            status="completed",
            safety_status="allowed",
            provider_state=replace(provider_state, model=generated.model),
            metadata_json={
                "generation_mode": "provider",
                "provider_key": provider_state.provider_key,
                "model": generated.model,
                "tokens_used": generated.tokens_used,
                "finish_reason": generated.finish_reason,
                "suggested_activities": generated.suggested_activities,
                "available_activity_slugs": [activity["slug"] for activity in activities],
            },
        )


class AiBuddyResponseGenerator:
    def __init__(
        self,
        *,
        fallback_backend: _AiBuddyBackend | None = None,
        provider_backend: _AiBuddyBackend | None = None,
    ) -> None:
        self._fallback_backend = fallback_backend or _InternalFallbackAiBuddyBackend()
        self._provider_backend = provider_backend or _EnhancedAiBuddyBackend()

    def provider_state(self) -> AiBuddyProviderState:
        provider_state = self._provider_backend.provider_state()
        if provider_state.status == "ready":
            state = provider_state
        else:
            fallback_state = self._fallback_backend.provider_state()
            state = (
                replace(fallback_state, reason=provider_state.reason)
                if provider_state.reason
                else fallback_state
            )
        logger.info(
            "ai_provider_state configured=%s mode=%s status=%s provider_key=%s model=%s",
            state.configured,
            state.mode,
            state.status,
            state.provider_key,
            state.model,
        )
        return state

    def greeting(
        self,
        *,
        child_name: str | None = None,
        locale: str | None = None,
    ) -> AiBuddyGeneratedResponse:
        response = self._run_with_fallback(
            lambda backend: backend.greeting(child_name=child_name, locale=locale)
        )
        logger.info(
            "ai_buddy_greeting response_source=%s safety_status=%s provider=%s",
            response.response_source,
            response.safety_status,
            response.provider_state.provider_key or response.provider_state.mode,
        )
        return response

    def generate(
        self,
        *,
        child_name: str | None,
        child_age: int | None = None,
        message: str,
        quick_action: str | None,
        recent_messages: Iterable[str],
        conversation_history: Iterable[dict] | None = None,
        locale: str | None = None,
    ) -> AiBuddyGeneratedResponse:
        response = self._run_with_fallback(
            lambda backend: backend.generate(
                child_name=child_name,
                child_age=child_age,
                message=message,
                quick_action=quick_action,
                recent_messages=recent_messages,
                conversation_history=conversation_history,
                locale=locale,
            )
        )
        logger.info(
            "ai_buddy_generate intent=%s response_source=%s safety_status=%s provider=%s",
            response.intent,
            response.response_source,
            response.safety_status,
            response.provider_state.provider_key or response.provider_state.mode,
        )
        return response

    def fallback_generate(
        self,
        *,
        child_name: str | None,
        child_age: int | None = None,
        message: str,
        quick_action: str | None,
        recent_messages: Iterable[str],
        reason: str | None = None,
        locale: str | None = None,
    ) -> AiBuddyGeneratedResponse:
        response = self._fallback_backend.generate(
            child_name=child_name,
            child_age=child_age,
            message=message,
            quick_action=quick_action,
            recent_messages=recent_messages,
            locale=locale,
        )
        if isinstance(self._fallback_backend, _InternalFallbackAiBuddyBackend):
            response = self._fallback_backend.with_reason(response, reason=reason)
        logger.info(
            "ai_buddy_fallback_generate intent=%s response_source=%s safety_status=%s provider=%s",
            response.intent,
            response.response_source,
            response.safety_status,
            response.provider_state.provider_key or response.provider_state.mode,
        )
        return response

    def _run_with_fallback(
        self,
        operation,
    ) -> AiBuddyGeneratedResponse:
        provider_state = self._provider_backend.provider_state()
        if provider_state.status == "ready":
            try:
                return operation(self._provider_backend)
            except Exception as exc:
                logger.warning(
                    "ai_buddy_provider_failed provider=%s error=%s",
                    provider_state.provider_key or provider_state.mode,
                    str(exc),
                )
                fallback = operation(self._fallback_backend)
                reason = (
                    f"Live AI provider was unavailable for this request. "
                    f"Using safe fallback mode instead: {type(exc).__name__}."
                )
                if isinstance(self._fallback_backend, _InternalFallbackAiBuddyBackend):
                    return self._fallback_backend.with_reason(fallback, reason=reason)
                return fallback
        fallback = operation(self._fallback_backend)
        if isinstance(self._fallback_backend, _InternalFallbackAiBuddyBackend):
            return self._fallback_backend.with_reason(fallback, reason=provider_state.reason)
        return fallback


ai_buddy_response_generator = AiBuddyResponseGenerator()
