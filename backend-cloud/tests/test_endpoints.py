"""Smoke tests for the two image endpoints."""
import base64
import json
from io import BytesIO

import pytest
from django.test import Client
from PIL import Image


def _make_png_b64(size=(120, 80), color=(255, 0, 0)) -> str:
    img = Image.new("RGB", size, color)
    buf = BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


@pytest.fixture
def client():
    return Client()


def test_health(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "ok"


def test_get_resolution_returns_size(client):
    b64 = _make_png_b64(size=(200, 150))
    res = client.post(
        "/get/resolution",
        data=json.dumps({"image": b64}),
        content_type="application/json",
    )
    assert res.status_code == 200
    payload = res.json()
    assert payload["width"] == 200
    assert payload["height"] == 150
    assert payload["resolution"] == "200x150"


def test_get_resolution_accepts_data_url(client):
    b64 = _make_png_b64(size=(64, 64))
    res = client.post(
        "/get/resolution",
        data=json.dumps({"image": f"data:image/png;base64,{b64}"}),
        content_type="application/json",
    )
    assert res.status_code == 200
    assert res.json()["width"] == 64


def test_get_resolution_rejects_garbage(client):
    res = client.post(
        "/get/resolution",
        data=json.dumps({"image": "not-base64!!"}),
        content_type="application/json",
    )
    assert res.status_code == 400


def test_convert_grayscale_returns_image(client):
    b64 = _make_png_b64(size=(40, 40), color=(10, 200, 30))
    res = client.post(
        "/convert/grayscale",
        data=json.dumps({"image": b64}),
        content_type="application/json",
    )
    assert res.status_code == 200
    payload = res.json()
    assert payload["image"].startswith("data:image/png;base64,")
    raw = base64.b64decode(payload["image"].split(",", 1)[1])
    gray = Image.open(BytesIO(raw))
    assert gray.mode == "L"
    assert gray.size == (40, 40)
