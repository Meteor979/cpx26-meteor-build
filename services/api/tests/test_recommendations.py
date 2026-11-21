import copy
import json
from pathlib import Path
from typing import Any, Dict

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)
ROOT_DIR = Path(__file__).resolve().parents[3]
SAMPLE_DATA = json.loads(
    (ROOT_DIR / "specs" / "examples" / "sample-data.json").read_text(
        encoding="utf-8"
    )
)


def recommendation_request(
    preset_id: str,
    occasion: str,
    formality: str,
) -> Dict[str, Any]:
    request = copy.deepcopy(
        SAMPLE_DATA["recommendation_example"]["request"]
    )
    request["request_id"] = f"req-{preset_id}-semantic-regression"
    request["preset_id"] = preset_id
    request["occasion"] = occasion
    request["formality"] = formality
    return request


def test_night_out_and_interview_rank_different_combinations() -> None:
    night_response = client.post(
        "/v1/recommendations",
        json=recommendation_request(
            preset_id="night-out",
            occasion="去夜店",
            formality="business",
        ),
    )
    interview_response = client.post(
        "/v1/recommendations",
        json=recommendation_request(
            preset_id="internship-interview",
            occasion="实习面试",
            formality="casual",
        ),
    )

    assert night_response.status_code == 200
    assert interview_response.status_code == 200

    night = night_response.json()
    interview = interview_response.json()
    night_first = night["outfits"][0]
    interview_first = interview["outfits"][0]

    assert set(night_first["item_ids"]) != set(interview_first["item_ids"])

    night_reasons = " ".join(night_first["reasons"])
    interview_reasons = " ".join(interview_first["reasons"])
    assert "夜间社交" in night_reasons
    assert "商务会面" in night_reasons
    assert "面试" in interview_reasons
    assert "正式表达" in interview_reasons


def test_recommendation_uses_preset_not_client_formality() -> None:
    body = client.post(
        "/v1/recommendations",
        json=recommendation_request(
            preset_id="night-out",
            occasion="去夜店",
            formality="business",
        ),
    ).json()

    first = body["outfits"][0]
    assert "夜间社交" in " ".join(first["reasons"])
    assert body["provider"] == "rule_engine_with_occasion_scoring"


def test_insufficient_wardrobe_returns_contract_error() -> None:
    request = recommendation_request(
        preset_id="night-out",
        occasion="去夜店",
        formality="casual",
    )
    request["garments"] = [
        garment
        for garment in request["garments"]
        if garment["slot"] != "shoes"
    ]

    response = client.post("/v1/recommendations", json=request)

    assert response.status_code == 422
    assert response.json()["code"] == "INSUFFICIENT_WARDROBE"
    assert response.json()["details"]["missing_slots"] == ["shoes"]


def test_recommendation_response_contains_no_local_photo_paths() -> None:
    response = client.post(
        "/v1/recommendations",
        json=recommendation_request(
            preset_id="night-out",
            occasion="去夜店",
            formality="casual",
        ),
    )
    serialized = json.dumps(response.json(), ensure_ascii=False).lower()

    assert "local_photo_path" not in serialized
    assert "photo_path" not in serialized
    assert "image_url" not in serialized
