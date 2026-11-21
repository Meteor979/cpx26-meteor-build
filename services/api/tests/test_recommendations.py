import ast
import json
from copy import deepcopy
from pathlib import Path
from typing import Any, Dict, List
from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)
APP_DIR = Path(__file__).resolve().parents[1] / "app"


def _garment(
    slot: str,
    category: str,
    formality: int,
    warmth: int,
    colors: List[str],
) -> Dict[str, Any]:
    return {
        "id": str(uuid4()),
        "brand": "Rule Mock",
        "product_name": "%s sample" % category,
        "slot": slot,
        "category": category,
        "colors": colors,
        "pattern": "solid",
        "fit": "regular",
        "material": "cotton",
        "formality_score": formality,
        "warmth_score": warmth,
        "user_confirmed": True,
    }


def _payload() -> Dict[str, Any]:
    return {
        "request_id": str(uuid4()),
        "preset_id": "first-date",
        "occasion": "第一次约会",
        "weather": {
            "temperature_c": 16,
            "feels_like_c": 15,
            "condition": "partly_cloudy",
            "precipitation_probability": 0.2,
            "wind_speed_kph": 12,
        },
        "formality": "smart_casual",
        "garments": [
            _garment("top", "shirt", 3, 2, ["light_blue"]),
            _garment("top", "knitwear", 2, 4, ["cream"]),
            _garment("bottom", "jeans", 2, 3, ["dark_blue"]),
            _garment("bottom", "trousers", 3, 3, ["black"]),
            _garment("shoes", "sneakers", 2, 2, ["white"]),
            _garment("shoes", "loafers", 3, 2, ["brown"]),
            _garment("outerwear", "cardigan", 2, 3, ["beige"]),
        ],
    }


def _request_recommendations(payload: Dict[str, Any]):
    return client.post("/v1/recommendations", json=payload)


def test_recommendations_return_three_unique_valid_outfits() -> None:
    payload = _payload()
    response = _request_recommendations(payload)

    assert response.status_code == 200
    body = response.json()
    assert body["requested_count"] == 3
    assert body["result_count_reason"] == "three_available"
    assert body["fallback_used"] is True
    assert body["provider"] == "rule_engine_mock"
    assert body["warning"]
    assert len(body["outfits"]) == 3

    request_ids = {garment["id"] for garment in payload["garments"]}
    signatures = set()
    for outfit in body["outfits"]:
        assert outfit["source"] == "fallback"
        assert set(outfit["item_ids"]) <= request_ids
        assert len(outfit["item_ids"]) == len(set(outfit["item_ids"]))
        assert len(outfit["reasons"]) >= 3
        assert outfit["tradeoffs"]
        signatures.add(tuple(outfit["item_ids"]))
    assert len(signatures) == 3


def test_mild_weather_primary_outfit_uses_three_core_slots() -> None:
    payload = _payload()
    response = _request_recommendations(payload)

    assert response.status_code == 200
    first_ids = response.json()["outfits"][0]["item_ids"]
    garment_by_id = {
        garment["id"]: garment for garment in payload["garments"]
    }
    assert len(first_ids) == 3
    assert {garment_by_id[item_id]["slot"] for item_id in first_ids} == {
        "top",
        "bottom",
        "shoes",
    }


def test_missing_shoes_returns_insufficient_wardrobe() -> None:
    payload = _payload()
    payload["garments"] = [
        garment for garment in payload["garments"] if garment["slot"] != "shoes"
    ]

    response = _request_recommendations(payload)

    assert response.status_code == 422
    assert response.json()["code"] == "INSUFFICIENT_WARDROBE"
    assert response.json()["details"]["missing_slots"] == ["shoes"]


def test_unconfirmed_garment_returns_422() -> None:
    payload = _payload()
    payload["garments"][0]["user_confirmed"] = False

    response = _request_recommendations(payload)

    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


def test_duplicate_garment_id_returns_422() -> None:
    payload = _payload()
    payload["garments"].append(deepcopy(payload["garments"][0]))

    response = _request_recommendations(payload)

    assert response.status_code == 422
    assert response.json()["code"] == "DUPLICATE_GARMENT_ID"


def test_limited_candidates_return_limited_reason() -> None:
    payload = _payload()
    payload["garments"] = [
        _garment("top", "shirt", 3, 2, ["light_blue"]),
        _garment("bottom", "trousers", 3, 3, ["black"]),
        _garment("shoes", "loafers", 3, 2, ["brown"]),
    ]

    response = _request_recommendations(payload)

    assert response.status_code == 200
    assert len(response.json()["outfits"]) == 1
    assert response.json()["result_count_reason"] == "limited_candidates"


def test_recommendations_do_not_include_photo_fields() -> None:
    response = _request_recommendations(_payload())
    serialized = response.text.lower()

    assert "photo_path" not in serialized
    assert "local_photo_path" not in serialized
    assert "image_url" not in serialized
    assert "base64" not in serialized


def _revision_payload() -> Dict[str, Any]:
    payload = _payload()
    recommendation = _request_recommendations(payload).json()
    base_ids = recommendation["outfits"][0]["item_ids"]
    garment_by_id = {garment["id"]: garment for garment in payload["garments"]}
    replacement = next(
        garment
        for garment in payload["garments"]
        if garment["slot"] == "shoes" and garment["id"] not in base_ids
    )
    return {
        **{key: payload[key] for key in ("request_id", "preset_id", "occasion")},
        "weather": payload["weather"],
        "formality": payload["formality"],
        "garments": payload["garments"],
        "base_item_ids": base_ids,
        "replacement_item_id": replacement["id"],
    }


def test_revision_changes_only_shoes_and_returns_complete_structure() -> None:
    payload = _revision_payload()
    before = deepcopy(payload["base_item_ids"])
    garment_by_id = {garment["id"]: garment for garment in payload["garments"]}

    response = client.post("/v1/outfits/revise", json=payload)

    assert response.status_code == 200
    body = response.json()
    assert body["fallback_used"] is True
    assert body["warning"]
    assert body["provider"] == "rule_engine_mock"
    assert body["generated_at"]
    assert body["request_id"] == payload["request_id"]
    outfit = body["outfit"]
    assert set(outfit) >= {
        "id",
        "item_ids",
        "title",
        "reasons",
        "tradeoffs",
        "source",
        "score",
    }

    before_by_slot = {
        garment_by_id[item_id]["slot"]: item_id for item_id in before
    }
    after_by_slot = {
        garment_by_id[item_id]["slot"]: item_id
        for item_id in outfit["item_ids"]
    }
    assert after_by_slot["top"] == before_by_slot["top"]
    assert after_by_slot["bottom"] == before_by_slot["bottom"]
    assert after_by_slot["shoes"] != before_by_slot["shoes"]
    changed_ids = set(before) ^ set(outfit["item_ids"])
    assert changed_ids == {
        before_by_slot["shoes"],
        payload["replacement_item_id"],
    }


def test_revision_rejects_different_slot() -> None:
    payload = _revision_payload()
    accessory = _garment("accessory", "watch", 3, 1, ["black"])
    payload["garments"].append(accessory)
    payload["replacement_item_id"] = accessory["id"]

    response = client.post("/v1/outfits/revise", json=payload)

    assert response.status_code == 422
    assert response.json()["code"] == "SLOT_MISMATCH"


def test_revision_rejects_unknown_replacement() -> None:
    payload = _revision_payload()
    payload["replacement_item_id"] = str(uuid4())

    response = client.post("/v1/outfits/revise", json=payload)

    assert response.status_code == 422
    assert response.json()["code"] == "UNKNOWN_ITEM_ID"


def test_python_39_syntax_check() -> None:
    for source_file in APP_DIR.rglob("*.py"):
        ast.parse(
            source_file.read_text(encoding="utf-8"),
            filename=str(source_file),
            feature_version=(3, 9),
        )
