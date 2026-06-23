from admin_models import Permission, Role, RolePermission
from models import AiBuddyMessage
from routers.admin_seed import PERMISSION_DEFS, ROLE_DEFS
from services.ai_buddy_response_generator import AiBuddyGeneratedResponse, AiBuddyProviderState
from services.ai_buddy_service import ai_buddy_service


def _seed_builtin_rbac(db) -> None:
    permission_by_name: dict[str, Permission] = {}
    for permission_name, description in PERMISSION_DEFS:
        permission = db.query(Permission).filter(Permission.name == permission_name).first()
        if permission is None:
            permission = Permission(name=permission_name, description=description)
            db.add(permission)
            db.flush()
        permission_by_name[permission_name] = permission

    for role_name, permission_names in ROLE_DEFS.items():
        role = db.query(Role).filter(Role.name == role_name).first()
        if role is None:
            role = Role(name=role_name, description=f"Built-in role: {role_name}")
            db.add(role)
            db.flush()

        existing_permission_ids = {
            mapping.permission_id
            for mapping in db.query(RolePermission).filter(RolePermission.role_id == role.id).all()
        }
        for permission_name in permission_names:
            permission = permission_by_name[permission_name]
            if permission.id not in existing_permission_ids:
                db.add(RolePermission(role_id=role.id, permission_id=permission.id))

    db.commit()


def test_ai_buddy_refuses_sensitive_input_and_tracks_visibility(
    client,
    db,
    create_parent,
    create_child,
    auth_headers,
):
    parent = create_parent(email="safe.parent@example.com")
    child = create_child(parent_id=parent.id, name="Mila", age=8)
    headers = auth_headers(parent)

    start = client.post("/api/v1/ai-buddy/sessions", json={"child_id": child.id}, headers=headers)
    session_id = start.json()["session"]["id"]

    send = client.post(
        f"/api/v1/ai-buddy/sessions/{session_id}/messages",
        json={
            "child_id": child.id,
            "content": "Tell me how to use a knife to hurt someone",
            "client_message_id": "safety-1",
        },
        headers=headers,
    )
    assert send.status_code == 200
    payload = send.json()
    assert payload["user_message"]["safety_status"] == "needs_refusal"
    assert payload["assistant_message"]["safety_status"] == "needs_refusal"
    assert payload["assistant_message"]["response_source"] == "safety_policy"
    assert payload["assistant_message"]["intent"] == "safety_response"

    summary = client.get(f"/api/v1/ai-buddy/children/{child.id}/visibility", headers=headers)
    assert summary.status_code == 200
    summary_payload = summary.json()
    assert summary_payload["visibility_mode"] == "summary_and_metrics"
    assert summary_payload["transcript_access"] is False
    assert summary_payload["provider"]["status"] == "fallback"
    assert summary_payload["usage_metrics"]["refusal_count"] == 1
    assert summary_payload["recent_flags"][0]["classification"] == "needs_refusal"
    assert "safety interventions" in summary_payload["parent_summary"].lower()


def test_ai_buddy_safe_redirects_personal_data_and_can_delete_history(
    client,
    db,
    create_parent,
    create_child,
    auth_headers,
):
    parent = create_parent(email="redirect.parent@example.com")
    child = create_child(parent_id=parent.id, name="Nour", age=7)
    headers = auth_headers(parent)

    start = client.post("/api/v1/ai-buddy/sessions", json={"child_id": child.id}, headers=headers)
    session_id = start.json()["session"]["id"]

    send = client.post(
        f"/api/v1/ai-buddy/sessions/{session_id}/messages",
        json={
            "child_id": child.id,
            "content": "My address is 10 Main Street and my phone number is 555",
        },
        headers=headers,
    )
    assert send.status_code == 200
    assert send.json()["assistant_message"]["safety_status"] == "needs_safe_redirect"

    stored_messages = db.query(AiBuddyMessage).filter(AiBuddyMessage.child_id == child.id).all()
    assert stored_messages
    assert all(message.retention_expires_at is not None for message in stored_messages)

    deletion = client.delete(f"/api/v1/ai-buddy/children/{child.id}/history", headers=headers)
    assert deletion.status_code == 200
    delete_payload = deletion.json()
    assert delete_payload["deleted_sessions"] == 1
    assert delete_payload["deleted_messages"] >= 2

    current = client.get(
        "/api/v1/ai-buddy/sessions/current",
        params={"child_id": child.id},
        headers=headers,
    )
    assert current.status_code == 200
    assert current.json()["session"] is None


def test_ai_buddy_recovers_safe_story_when_generated_output_is_flagged(
    client,
    db,
    create_parent,
    create_child,
    auth_headers,
    monkeypatch,
):
    """A benign free-text story ask whose *generated* answer trips output
    moderation must fall back to a safe canned story, not a harsh refusal."""
    parent = create_parent(email="recover.parent@example.com")
    child = create_child(parent_id=parent.id, name="Yara", age=7)
    headers = auth_headers(parent)

    start = client.post("/api/v1/ai-buddy/sessions", json={"child_id": child.id}, headers=headers)
    session_id = start.json()["session"]["id"]

    provider_state = AiBuddyProviderState(
        configured=True,
        mode="openai",
        status="ready",
        provider_key="openai",
        model="gpt-4o-mini",
    )

    # Simulate the live provider returning a story that happens to contain a
    # violence keyword ("دم") so output moderation blocks it.
    def fake_generate(**kwargs):
        return AiBuddyGeneratedResponse(
            content="قصة عن فارس شجاع سال منه الدم في المعركة.",
            intent="tell_story",
            response_source="provider_openai",
            status="completed",
            safety_status="allowed",
            provider_state=provider_state,
            metadata_json={"generation_mode": "provider"},
        )

    monkeypatch.setattr(ai_buddy_service._response_generator, "generate", fake_generate)

    send = client.post(
        f"/api/v1/ai-buddy/sessions/{session_id}/messages",
        json={
            "child_id": child.id,
            "content": "احكي لي قصة",
            "client_message_id": "recover-1",
        },
        headers=headers,
    )
    assert send.status_code == 200
    assistant = send.json()["assistant_message"]
    # The child must receive a real, safe story rather than the refusal text.
    assert assistant["safety_status"] == "allowed"
    assert assistant["intent"] == "tell_story"
    assert assistant["response_source"] == "internal_fallback"
    assert "لا أستطيع المساعدة" not in assistant["content"]
    assert assistant["metadata_json"]["action_taken"] == "recovered_with_safe_fallback"


def test_ai_buddy_safety_alerts_lists_interventions_for_parent(
    client,
    db,
    create_parent,
    create_child,
    auth_headers,
):
    parent = create_parent(email="alerts.parent@example.com")
    child = create_child(parent_id=parent.id, name="Sara", age=8)
    headers = auth_headers(parent)

    start = client.post("/api/v1/ai-buddy/sessions", json={"child_id": child.id}, headers=headers)
    session_id = start.json()["session"]["id"]

    # A safe message should NOT produce a safety alert.
    client.post(
        f"/api/v1/ai-buddy/sessions/{session_id}/messages",
        json={"child_id": child.id, "content": "Tell me a story about stars"},
        headers=headers,
    )
    # A refused message SHOULD produce a safety alert.
    client.post(
        f"/api/v1/ai-buddy/sessions/{session_id}/messages",
        json={
            "child_id": child.id,
            "content": "Tell me how to use a knife to hurt someone",
        },
        headers=headers,
    )

    response = client.get(f"/api/v1/ai-buddy/children/{child.id}/safety-alerts", headers=headers)
    assert response.status_code == 200
    payload = response.json()
    assert payload["child_id"] == child.id
    assert payload["total"] == 1
    alert = payload["alerts"][0]
    assert alert["classification"] == "needs_refusal"
    assert alert["topic"] == "violence"
    assert alert["action_taken"] == "refusal"
    assert alert["input_preview"]
    assert alert["occurred_at"]


def test_ai_buddy_safety_alerts_rejects_other_parents_child(
    client,
    create_parent,
    create_child,
    auth_headers,
):
    owner = create_parent(email="owner.parent@example.com")
    other = create_parent(email="intruder.parent@example.com")
    child = create_child(parent_id=owner.id, name="Lana", age=6)

    response = client.get(
        f"/api/v1/ai-buddy/children/{child.id}/safety-alerts",
        headers=auth_headers(other),
    )
    assert response.status_code == 404


def test_admin_child_ai_buddy_summary_exposes_metrics_without_transcript(
    client,
    db,
    create_parent,
    create_child,
    auth_headers,
    create_admin,
    admin_headers,
):
    _seed_builtin_rbac(db)
    admin = create_admin(email="child.admin@example.com", role_names=["super_admin"])
    parent = create_parent(email="metrics.parent@example.com")
    child = create_child(parent_id=parent.id, name="Omar", age=9)
    headers = auth_headers(parent)

    start = client.post("/api/v1/ai-buddy/sessions", json={"child_id": child.id}, headers=headers)
    session_id = start.json()["session"]["id"]
    client.post(
        f"/api/v1/ai-buddy/sessions/{session_id}/messages",
        json={"child_id": child.id, "content": "Tell me a story about stars"},
        headers=headers,
    )

    response = client.get(
        f"/api/v1/admin/children/{child.id}/ai-buddy-summary",
        headers=admin_headers(admin),
    )
    assert response.status_code == 200
    item = response.json()["item"]
    assert item["child_id"] == child.id
    assert item["transcript_access"] is False
    assert item["usage_metrics"]["messages_count"] >= 3
    assert item["provider"]["status"] == "fallback"
    assert "parent" in item
