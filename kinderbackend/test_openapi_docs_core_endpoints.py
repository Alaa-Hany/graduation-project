from __future__ import annotations


def test_openapi_core_routes_include_high_value_metadata(client) -> None:
    response = client.get("/openapi.json")

    assert response.status_code == 200
    schema = response.json()
    paths = schema["paths"]

    login_operation = paths["/auth/login"]["post"]
    login_schema_ref = login_operation["requestBody"]["content"]["application/json"]["schema"][
        "$ref"
    ]
    assert login_operation["summary"] == "Parent Login"
    assert "two-factor authentication" in login_operation["description"].lower()
    assert login_schema_ref.endswith("/LoginIn")

    me_operation = paths["/auth/me"]["get"]
    me_response_ref = me_operation["responses"]["200"]["content"]["application/json"]["schema"][
        "$ref"
    ]
    assert me_operation["summary"] == "Get Current Parent"
    assert me_response_ref.endswith("/CurrentUserResponse")

    select_operation = paths["/subscription/select"]["post"]
    select_request_ref = select_operation["requestBody"]["content"]["application/json"]["schema"][
        "$ref"
    ]
    select_response_ref = select_operation["responses"]["200"]["content"]["application/json"][
        "schema"
    ]["$ref"]
    assert select_operation["summary"] == "Select Subscription Plan"
    assert "checkout" in select_operation["description"].lower()
    assert select_request_ref.endswith("/SubscriptionSelectRequest")
    assert select_response_ref.endswith("/SubscriptionSelectResponse")

    support_operation = paths["/support/tickets/{ticket_id}/reply"]["post"]
    support_response_ref = support_operation["responses"]["200"]["content"]["application/json"][
        "schema"
    ]["$ref"]
    assert support_operation["summary"] == "Reply To Support Ticket"
    assert "thread" in support_operation["description"].lower()
    assert support_response_ref.endswith("/SupportTicketMutationResponse")

    notifications_operation = paths["/notifications"]["get"]
    notifications_response_ref = notifications_operation["responses"]["200"]["content"][
        "application/json"
    ]["schema"]["$ref"]
    assert notifications_operation["summary"] == "List Notifications"
    assert "unread count" in notifications_operation["description"].lower()
    assert notifications_response_ref.endswith("/NotificationListResponse")


def test_openapi_component_examples_cover_core_request_and_response_shapes(client) -> None:
    response = client.get("/openapi.json")

    assert response.status_code == 200
    components = response.json()["components"]["schemas"]

    refresh_example = components["RefreshIn"]["example"]
    assert refresh_example["refresh_token"]

    subscription_select_examples = components["SubscriptionSelectRequest"]["examples"]
    assert subscription_select_examples[0]["plan_id"] == "PREMIUM"
    assert subscription_select_examples[1]["session_id"] == "cs_test_12345"

    support_example = components["SupportRequest"]["example"]
    assert support_example["category"] == "billing_issue"

    notification_example = components["NotificationListResponse"]["example"]
    assert notification_example["summary"]["unread_count"] == 3
