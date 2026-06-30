from app import create_app


def make_client():
    app = create_app()
    app.config.update(TESTING=True)
    return app.test_client()


def test_health_returns_200():
    client = make_client()
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "healthy"


def test_index_reports_version():
    client = make_client()
    response = client.get("/")
    body = response.get_json()
    assert response.status_code == 200
    assert "version" in body
    assert "served_by" in body