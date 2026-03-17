from models import SystemSetting


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
