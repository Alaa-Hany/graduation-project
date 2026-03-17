def test_health_endpoints(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"

    resp = client.get("/health/db")
    assert resp.status_code == 200
    db_data = resp.json()
    assert db_data["status"] == "ok"

    resp = client.get("/health/ready")
    assert resp.status_code == 200
    ready = resp.json()
    assert ready["status"] == "ok"
