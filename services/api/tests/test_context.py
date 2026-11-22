import json
from pathlib import Path
from typing import Any, Dict

from fastapi.testclient import TestClient

from app.data.mock_data import SEMANTIC_PROFILES
from app.main import app

client = TestClient(app)
ROOT_DIR = Path(__file__).resolve().parents[3]
SAMPLE_DATA = json.loads(
    (ROOT_DIR / "specs" / "examples" / "sample-data.json").read_text(
        encoding="utf-8"
    )
)


def test_presets_return_fixed_sample_data() -> None:
    response = client.get("/v1/presets", params={"limit": 20})

    assert response.status_code == 200
    assert response.json() == SAMPLE_DATA["presets"]


def test_semantic_profiles_match_sample_data() -> None:
    assert SEMANTIC_PROFILES == SAMPLE_DATA["semantic_profiles"]


def test_presets_filter_by_query() -> None:
    response = client.get("/v1/presets", params={"q": "演讲", "limit": 4})

    assert response.status_code == 200
    assert [preset["id"] for preset in response.json()["presets"]] == [
        "club-speech"
    ]


def test_presets_limit() -> None:
    response = client.get("/v1/presets", params={"limit": 2})

    assert response.status_code == 200
    assert len(response.json()["presets"]) == 2


def test_presets_version_not_modified() -> None:
    response = client.get("/v1/presets", params={"version": 3})

    assert response.status_code == 304
    assert response.content == b""


def test_exact_name_resolves_to_club_speech() -> None:
    response = client.post(
        "/v1/occasions/resolve",
        json={"request_id": "req-context-001", "query": "社团演讲"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["profile"]["id"] == "club-speech"
    assert body["match_type"] == "exact_preset"
    assert body["confidence"] == 1.0
    assert body["request_id"] == "req-context-001"


def test_alias_resolves_to_first_date() -> None:
    response = client.post(
        "/v1/occasions/resolve",
        json={"query": "第一次约会", "locale": "zh-CN"},
    )

    assert response.status_code == 200
    assert response.json()["profile"]["id"] == "first-date"
    assert response.json()["match_type"] == "exact_preset"


def test_club_alias_resolves_to_club_speech() -> None:
    response = client.post(
        "/v1/occasions/resolve",
        json={"query": "社团汇报"},
    )

    assert response.status_code == 200
    assert response.json()["profile"]["id"] == "club-speech"
    assert response.json()["match_type"] == "exact_preset"


def test_keyword_match_returns_semantic_result() -> None:
    response = client.post(
        "/v1/occasions/resolve",
        json={"query": "准备社团演讲比赛"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["profile"]["id"] == "club-speech"
    assert body["match_type"] == "semantic_match"
    assert 0.7 <= body["confidence"] <= 0.88


def test_night_out_wins_over_business_formality_hint() -> None:
    response = client.post(
        "/v1/occasions/resolve",
        json={
            "query": "去夜店",
            "formality_hint": "business",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["profile"]["id"] == "night-out"
    assert body["profile"]["target_formality"] == "casual"
    assert body["match_type"] in {"exact_preset", "semantic_match"}


def test_night_out_is_semantic_profile_not_public_preset() -> None:
    response = client.get("/v1/presets")

    assert response.status_code == 200
    assert "night-out" not in {
        preset["id"] for preset in response.json()["presets"]
    }


def test_internship_interview_remains_business() -> None:
    response = client.post(
        "/v1/occasions/resolve",
        json={"query": "实习面试"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["profile"]["id"] == "internship-interview"
    assert body["profile"]["target_formality"] == "business"


def test_unknown_query_returns_low_confidence_fallback() -> None:
    response = client.post(
        "/v1/occasions/resolve",
        json={"query": "不认识的表达"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["match_type"] == "fallback"
    assert body["profile"]["source"] == "fallback"
    assert body["confidence"] < 0.9
    assert body["warning"]
    assert body["alternatives"] == []


def test_empty_query_returns_contract_error() -> None:
    response = client.post(
        "/v1/occasions/resolve",
        json={"request_id": "req-empty-001", "query": ""},
    )

    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"
    assert response.json()["request_id"] == "req-empty-001"


def test_whitespace_query_returns_contract_error() -> None:
    response = client.post(
        "/v1/occasions/resolve",
        json={"query": "   "},
    )

    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"
    assert response.json()["details"]["field"] == "query"


def test_context_responses_do_not_contain_local_photo_data() -> None:
    response = client.get("/v1/presets")
    body: Dict[str, Any] = response.json()
    serialized = json.dumps(body, ensure_ascii=False).lower()

    assert "local_photo_path" not in serialized
    assert "photo_path" not in serialized
    assert "image_url" not in serialized
