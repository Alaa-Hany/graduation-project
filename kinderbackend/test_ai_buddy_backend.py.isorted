from models import SystemSetting
from services.ai_buddy_response_generator import (
    AiBuddyGeneratedResponse,
    AiBuddyProviderState,
    AiBuddyResponseGenerator,
)
from services.ai_buddy_service import AiBuddyService


def test_ai_buddy_session_start_and_message_flow(
    client,
    db,
    create_parent,
    create_child,
    auth_headers,
):
    parent = create_parent(email="ai.parent@example.com")
    child = create_child(parent_id=parent.id, name="Lina", age=8)
    headers = auth_headers(parent)

    start = client.post(
        "/ai-buddy/sessions",
        json={"child_id": child.id},
        headers=headers,
    )
    assert start.status_code == 200
    start_payload = start.json()
    assert start_payload["session"]["child_id"] == child.id
    assert start_payload["provider"]["configured"] is False
    assert start_payload["provider"]["mode"] == "internal_fallback"
    assert len(start_payload["messages"]) == 1
    assert start_payload["messages"][0]["role"] == "assistant"

    session_id = start_payload["session"]["id"]
    send = client.post(
        f"/ai-buddy/sessions/{session_id}/messages",
        json={
            "child_id": child.id,
            "content": "Can you tell me a story?",
            "client_message_id": "msg-1",
        },
        headers=headers,
    )
    assert send.status_code == 200
    send_payload = send.json()
    assert send_payload["user_message"]["role"] == "child"
    assert send_payload["assistant_message"]["role"] == "assistant"
    assert send_payload["assistant_message"]["response_source"] == "internal_fallback"
    assert send_payload["provider"]["status"] == "fallback"

    current = client.get(
        "/ai-buddy/sessions/current",
        params={"child_id": child.id},
        headers=headers,
    )
    assert current.status_code == 200
    current_payload = current.json()
    assert current_payload["session"]["id"] == session_id
    assert len(current_payload["messages"]) == 3

    detail = client.get(f"/ai-buddy/sessions/{session_id}", headers=headers)
    assert detail.status_code == 200
    detail_payload = detail.json()
    assert detail_payload["messages"][-1]["role"] == "assistant"
    assert "story" in detail_payload["messages"][-1]["content"].lower()


def test_ai_buddy_child_session_can_chat_but_not_access_other_child(
    client,
    db,
    create_parent,
    create_child,
    auth_headers,
):
    parent = create_parent(email="ai.child.session@example.com")
    child = create_child(parent_id=parent.id, name="Lina", age=8)
    sibling = create_child(parent_id=parent.id, name="Omar", age=6)

    child_login = client.post(
        "/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
            "device_id": "tablet-a",
        },
    )
    assert child_login.status_code == 200
    child_headers = {
        "Authorization": f"Bearer {child_login.json()['session_token']}",
    }

    start = client.post(
        "/ai-buddy/sessions",
        json={"child_id": child.id},
        headers=child_headers,
    )
    assert start.status_code == 200
    session_id = start.json()["session"]["id"]

    send = client.post(
        f"/ai-buddy/sessions/{session_id}/messages",
        json={
            "child_id": child.id,
            "content": "Tell me a fun fact",
            "client_message_id": "child-msg-1",
        },
        headers=child_headers,
    )
    assert send.status_code == 200
    assert send.json()["assistant_message"]["role"] == "assistant"

    current = client.get(
        "/ai-buddy/sessions/current",
        params={"child_id": child.id},
        headers=child_headers,
    )
    assert current.status_code == 200
    assert current.json()["session"]["id"] == session_id

    sibling_attempt = client.get(
        "/ai-buddy/sessions/current",
        params={"child_id": sibling.id},
        headers=child_headers,
    )
    assert sibling_attempt.status_code == 403
    assert sibling_attempt.json()["detail"] == "Child session cannot access another child"

    parent_started_sibling = client.post(
        "/ai-buddy/sessions",
        json={"child_id": sibling.id},
        headers=auth_headers(parent),
    )
    assert parent_started_sibling.status_code == 200
    sibling_session_id = parent_started_sibling.json()["session"]["id"]

    forbidden_detail = client.get(
        f"/ai-buddy/sessions/{sibling_session_id}",
        headers=child_headers,
    )
    assert forbidden_detail.status_code == 404
    assert forbidden_detail.json()["detail"] == "AI Buddy session not found"


def test_ai_buddy_respects_system_disable_flag(
    client,
    db,
    create_parent,
    create_child,
    auth_headers,
):
    parent = create_parent(email="ai.disabled@example.com")
    child = create_child(parent_id=parent.id, name="Hana", age=7)
    setting = db.query(SystemSetting).filter(SystemSetting.key == "ai_buddy_enabled").first()
    if setting is None:
        setting = SystemSetting(key="ai_buddy_enabled", value_json=False)
        db.add(setting)
    else:
        setting.value_json = False
    db.commit()

    response = client.post(
        "/ai-buddy/sessions",
        json={"child_id": child.id},
        headers=auth_headers(parent),
    )
    assert response.status_code == 503
    detail = response.json()["detail"]
    assert detail["code"] == "AI_BUDDY_DISABLED"


def test_ai_buddy_generator_uses_provider_backend_when_ready() -> None:
    class ReadyProviderBackend:
        def provider_state(self) -> AiBuddyProviderState:
            return AiBuddyProviderState(
                configured=True,
                mode="openai",
                status="ready",
                reason=None,
                provider_key="openai",
                model="gpt-4o-mini",
                supports_activity_suggestions=True,
            )

        def greeting(self, *, child_name: str | None = None) -> AiBuddyGeneratedResponse:
            return AiBuddyGeneratedResponse(
                content=f"Hello {child_name or 'friend'} from provider!",
                intent="greeting",
                response_source="provider_openai",
                status="completed",
                safety_status="allowed",
                provider_state=self.provider_state(),
                metadata_json={"model": "gpt-4o-mini"},
            )

        def generate(
            self,
            *,
            child_name: str | None,
            child_age: int | None,
            message: str,
            quick_action: str | None,
            recent_messages,
        ) -> AiBuddyGeneratedResponse:
            return AiBuddyGeneratedResponse(
                content=f"Provider reply to: {message}",
                intent=quick_action or "general_help",
                response_source="provider_openai",
                status="completed",
                safety_status="allowed",
                provider_state=self.provider_state(),
                metadata_json={"child_age": child_age},
            )

    generator = AiBuddyResponseGenerator(provider_backend=ReadyProviderBackend())

    response = generator.generate(
        child_name="Lina",
        child_age=8,
        message="Can you help me learn numbers?",
        quick_action="recommend_lesson",
        recent_messages=["Hi"],
    )

    assert response.response_source == "provider_openai"
    assert response.provider_state.status == "ready"
    assert response.provider_state.provider_key == "openai"
    assert response.metadata_json["child_age"] == 8


def test_ai_buddy_generator_falls_back_when_provider_backend_fails() -> None:
    class FailingProviderBackend:
        def provider_state(self) -> AiBuddyProviderState:
            return AiBuddyProviderState(
                configured=True,
                mode="openai",
                status="ready",
                reason=None,
                provider_key="openai",
                model="gpt-4o-mini",
                supports_activity_suggestions=True,
            )

        def greeting(self, *, child_name: str | None = None) -> AiBuddyGeneratedResponse:
            raise RuntimeError("provider offline")

        def generate(
            self,
            *,
            child_name: str | None,
            child_age: int | None,
            message: str,
            quick_action: str | None,
            recent_messages,
        ) -> AiBuddyGeneratedResponse:
            raise RuntimeError("provider offline")

    generator = AiBuddyResponseGenerator(provider_backend=FailingProviderBackend())

    response = generator.generate(
        child_name="Lina",
        child_age=8,
        message="Tell me a story",
        quick_action="tell_story",
        recent_messages=["Hello"],
    )

    assert response.response_source == "internal_fallback"
    assert response.provider_state.status == "fallback"
    assert "Live AI provider was unavailable" in (response.provider_state.reason or "")
    assert "fallback_reason" in response.metadata_json


def test_ai_buddy_service_recovers_safe_story_when_provider_output_is_blocked(
    db,
    create_parent,
    create_child,
) -> None:
    class UnsafeStoryProviderBackend:
        def provider_state(self) -> AiBuddyProviderState:
            return AiBuddyProviderState(
                configured=True,
                mode="openai",
                status="ready",
                reason=None,
                provider_key="openai",
                model="gpt-4o-mini",
                supports_activity_suggestions=True,
            )

        def greeting(self, *, child_name: str | None = None) -> AiBuddyGeneratedResponse:
            return AiBuddyGeneratedResponse(
                content=f"Hello {child_name or 'friend'}!",
                intent="greeting",
                response_source="provider_openai",
                status="completed",
                safety_status="allowed",
                provider_state=self.provider_state(),
                metadata_json={"model": "gpt-4o-mini"},
            )

        def generate(
            self,
            *,
            child_name: str | None,
            child_age: int | None,
            message: str,
            quick_action: str | None,
            recent_messages,
        ) -> AiBuddyGeneratedResponse:
            return AiBuddyGeneratedResponse(
                content="Here is a story about a knife.",
                intent=quick_action or "general_help",
                response_source="provider_openai",
                status="completed",
                safety_status="allowed",
                provider_state=self.provider_state(),
                metadata_json={"model": "gpt-4o-mini"},
            )

    parent = create_parent(email="recover.parent@example.com")
    child = create_child(parent_id=parent.id, name="Lina", age=8)
    generator = AiBuddyResponseGenerator(provider_backend=UnsafeStoryProviderBackend())
    service = AiBuddyService(response_generator=generator)

    conversation = service.start_session(db=db, parent=parent, child_id=child.id)
    session_id = conversation["session"]["id"]

    payload = service.send_message(
        db=db,
        parent=parent,
        session_id=session_id,
        child_id=child.id,
        content="Tell me a story",
        quick_action="tell_story",
    )

    assistant = payload["assistant_message"]
    assert assistant["response_source"] == "internal_fallback"
    assert assistant["safety_status"] == "allowed"
    assert "story" in assistant["content"].lower()
    assert assistant["intent"] == "tell_story"
    assert assistant["metadata_json"]["action_taken"] == "recovered_with_safe_fallback"
