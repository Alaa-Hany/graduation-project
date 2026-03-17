from __future__ import annotations

import logging

from services.ai_buddy_moderation import ai_buddy_moderation_service
from services.ai_buddy_response_generator import ai_buddy_response_generator


def test_ai_logging_emits_records(caplog):
    caplog.set_level(logging.INFO)
    ai_buddy_response_generator.provider_state()
    ai_buddy_response_generator.greeting()
    ai_buddy_response_generator.generate(
        child_name=None,
        message="Tell me a story",
        quick_action=None,
        recent_messages=[],
    )
    ai_buddy_moderation_service.moderate_input(text="hello")
    ai_buddy_moderation_service.moderate_output(text="a safe reply")

    messages = [record.getMessage() for record in caplog.records]
    assert any("ai_provider_state" in msg for msg in messages)
    assert any("ai_buddy_greeting" in msg for msg in messages)
    assert any("ai_buddy_generate" in msg for msg in messages)
    assert any("ai_buddy_moderation_input" in msg for msg in messages)
    assert any("ai_buddy_moderation_output" in msg for msg in messages)
