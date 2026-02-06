import importlib
import sys
from pathlib import Path

import pytest


REPO_ROOT = Path(__file__).resolve().parents[1]
APP_PATH = REPO_ROOT / "app"
sys.path.insert(0, str(APP_PATH))
app_module = importlib.import_module("app")
flask_app = app_module.app


@pytest.fixture(autouse=True)
def reset_app_state():
    """Reset in-memory store between tests for determinism."""
    # Access module-level globals via the Flask app's module namespace.
    items = getattr(app_module, "items", None)
    if items is not None:
        items.clear()
    if hasattr(app_module, "next_id"):
        setattr(app_module, "next_id", 1)
    yield
    if items is not None:
        items.clear()
    if hasattr(app_module, "next_id"):
        setattr(app_module, "next_id", 1)


@pytest.fixture
def client():
    flask_app.config.update(TESTING=True)
    with flask_app.test_client() as client:
        yield client


def test_index_returns_health(client):
    response = client.get("/")
    assert response.status_code == 200
    body = response.get_json()
    assert body == {"service": "aiClipx-trial", "status": "ok"}


def test_create_and_list_items(client):
    post_resp = client.post("/items", json={"name": "demo"})
    assert post_resp.status_code == 201
    created = post_resp.get_json()
    assert created["id"] == 1
    assert created["name"] == "demo"

    list_resp = client.get("/items")
    assert list_resp.status_code == 200
    items = list_resp.get_json()["items"]
    assert len(items) == 1
    assert items[0]["name"] == "demo"


def test_create_item_validation(client):
    response = client.post("/items", json={})
    assert response.status_code == 400
    body = response.get_json()
    assert body["error"] == "name is required"
