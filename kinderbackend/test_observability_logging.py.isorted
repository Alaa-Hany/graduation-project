from __future__ import annotations

import logging
from io import StringIO

from core.logging_utils import RequestContextFilter, StructuredFormatter, log_with_context
from core.request_context import reset_request_id, set_request_id
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


def test_structured_formatter_includes_request_id_and_extra_fields() -> None:
    stream = StringIO()
    handler = logging.StreamHandler(stream)
    handler.addFilter(RequestContextFilter())
    handler.setFormatter(
        StructuredFormatter("%(levelname)s %(name)s request_id=%(request_id)s %(message)s")
    )

    logger = logging.getLogger("test.structured.logging")
    logger.handlers = [handler]
    logger.setLevel(logging.INFO)
    logger.propagate = False

    token = set_request_id("req-structured-123")
    try:
        log_with_context(
            logger,
            logging.INFO,
            "structured_log_example",
            event="structured_log_example",
            category="test",
            path="/health",
            status_code=200,
            outcome="ok",
        )
    finally:
        reset_request_id(token)
        logger.handlers.clear()

    rendered = stream.getvalue()
    assert "request_id=req-structured-123" in rendered
    assert "event=structured_log_example" in rendered
    assert "path=/health" in rendered
    assert "status_code=200" in rendered
    assert "outcome=ok" in rendered


def test_request_middleware_logs_correlated_fields(caplog, client) -> None:
    caplog.set_level(logging.INFO)

    response = client.get("/health", headers={"X-Request-ID": "req-middleware-123"})

    assert response.status_code == 200
    request_logs = [
        record
        for record in caplog.records
        if record.name == "core.request_id_middleware"
        and record.getMessage() == "http_request_completed"
    ]
    assert request_logs
    record = request_logs[-1]
    assert record.request_id == "req-middleware-123"
    assert record.method == "GET"
    assert record.path == "/health"
    assert record.route == "/health"
    assert record.status_code == 200
    assert record.outcome == "completed"
