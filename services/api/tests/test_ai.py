from typing import Any, Dict

from app.models import (
    OccasionResolveRequest,
    RecommendationRequest,
)
from app.services.occasion_matcher import resolve_occasion
from app.services.recommendation_rules import (
    create_recommendations,
    revise_outfit,
)
from app.models import OutfitRevisionRequest
from app.services.text_ai import TextAIProviderError


class FakeTextAI:
    name = "fake-text-model"

    def __init__(self) -> None:
        self.calls = 0

    def complete_json(
        self,
        system_prompt: str,
        payload: Dict[str, Any],
        request_id: str,
    ) -> Dict[str, Any]:
        self.calls += 1

        if "query" in payload:
            return {
                "profile": {
                    "id": "generated-night-out",
                    "name": "Night out",
                    "description": "Expressive but practical for a social night.",
                    "aliases": ["night out"],
                    "target_formality": "casual",
                    "allowed_formality": ["casual", "smart_casual"],
                    "required_slots": ["top", "bottom", "shoes"],
                    "style_keywords": ["expressive", "social", "mobile"],
                    "avoid_rules": [
                        "Avoid a full business suit",
                        "Avoid stiff formal trousers",
                    ],
                    "explanation_guidelines": [
                        "Explain social tone",
                        "Explain movement and weather fit",
                    ],
                }
            }

        if "candidates" in payload:
            selected = payload["candidates"][:3]
            return {
                "outfits": [
                    {
                        "item_ids": candidate["item_ids"],
                        "title": "Social balance %s" % index,
                        "reasons": [
                            "The color and light-dark relationships stay clear.",
                            "The formality suits the requested social context.",
                            "The combination remains comfortable for movement.",
                        ],
                        "tradeoffs": [
                            "The wardrobe may lean more formal than an ideal night out."
                        ],
                    }
                    for index, candidate in enumerate(selected, start=1)
                ]
            }

        if "item_ids" in payload:
            return {
                "title": "Revised for the selected occasion",
                "reasons": [
                    "Only the selected slot changed.",
                    "The surrounding colors and formality remain consistent.",
                ],
                "tradeoffs": ["The replacement changes the outfit's social tone."],
            }

        raise AssertionError("Unexpected AI payload.")


class InvalidIdTextAI(FakeTextAI):
    def complete_json(
        self,
        system_prompt: str,
        payload: Dict[str, Any],
        request_id: str,
    ) -> Dict[str, Any]:
        self.calls += 1
        return {
            "outfits": [
                {
                    "item_ids": ["invented-garment"],
                    "title": "Invalid outfit",
                    "reasons": ["Invalid ID."],
                    "tradeoffs": ["Invalid."],
                }
            ]
        }


class InvalidOccasionTextAI(FakeTextAI):
    def complete_json(
        self,
        system_prompt: str,
        payload: Dict[str, Any],
        request_id: str,
    ) -> Dict[str, Any]:
        self.calls += 1
        return {
            "profile": {
                "id": "Invalid ID",
                "name": "",
                "aliases": [],
                "target_formality": "business",
                "allowed_formality": ["business"],
                "required_slots": [],
                "style_keywords": [],
                "avoid_rules": [],
                "explanation_guidelines": [],
            }
        }


class FailedTextAI(FakeTextAI):
    def complete_json(
        self,
        system_prompt: str,
        payload: Dict[str, Any],
        request_id: str,
    ) -> Dict[str, Any]:
        self.calls += 1
        raise TextAIProviderError("timeout")


def _recommendation_request() -> RecommendationRequest:
    return RecommendationRequest.model_validate(
        {
            "request_id": "req-ai-recommendation",
            "preset_id": "generated-night-out",
            "occasion": "night out",
            "weather": {
                "temperature_c": 16,
                "feels_like_c": 15,
                "condition": "partly_cloudy",
                "precipitation_probability": 0.2,
                "wind_speed_kph": 12,
            },
            "formality": "casual",
            "garments": [
                _garment("top-one", "top", "t_shirt", 1),
                _garment("top-two", "top", "polo", 3),
                _garment("bottom-one", "bottom", "jeans", 2),
                _garment("bottom-two", "bottom", "trousers", 3),
                _garment("shoes-one", "shoes", "sneakers", 2),
                _garment("shoes-two", "shoes", "loafers", 3),
            ],
        }
    )


def _garment(
    item_id: str,
    slot: str,
    category: str,
    formality: int,
) -> Dict[str, Any]:
    return {
        "id": item_id,
        "brand": None,
        "product_name": item_id,
        "slot": slot,
        "category": category,
        "colors": ["neutral"],
        "pattern": "solid",
        "fit": "regular",
        "material": "cotton",
        "formality_score": formality,
        "warmth_score": 2,
        "user_confirmed": True,
    }


def test_local_exact_occasion_does_not_call_ai() -> None:
    ai = FakeTextAI()
    request = OccasionResolveRequest(
        request_id="req-local",
        query="第一次约会",
    )

    result = resolve_occasion(request, ai_provider=ai)

    assert result.profile.id == "first-date"
    assert ai.calls == 0


def test_unknown_occasion_uses_validated_ai_profile() -> None:
    ai = FakeTextAI()
    request = OccasionResolveRequest(
        request_id="req-ai-occasion",
        query="low-key neighborhood makers gathering",
        locale="en-US",
    )

    result = resolve_occasion(request, ai_provider=ai)

    assert ai.calls == 1
    assert result.match_type == "generated"
    assert result.profile.id == "generated-night-out"
    assert result.profile.source == "generated"
    assert result.profile.target_formality.value == "casual"
    assert result.warning


def test_invalid_ai_occasion_profile_uses_fallback() -> None:
    ai = InvalidOccasionTextAI()
    request = OccasionResolveRequest(
        request_id="req-invalid-ai",
        query="unfamiliar social activity",
    )

    result = resolve_occasion(request, ai_provider=ai)

    assert ai.calls == 1
    assert result.match_type == "fallback"
    assert result.profile.source == "fallback"
    assert result.warning


def test_ai_provider_error_uses_local_fallback() -> None:
    ai = FailedTextAI()
    request = OccasionResolveRequest(
        request_id="req-ai-error",
        query="unfamiliar social activity",
    )

    result = resolve_occasion(request, ai_provider=ai)

    assert ai.calls == 1
    assert result.match_type == "fallback"
    assert result.profile.source == "fallback"


def test_ai_recommendations_are_limited_to_rule_candidates() -> None:
    ai = FakeTextAI()
    request = _recommendation_request()

    result = create_recommendations(request, ai_provider=ai)
    all_request_ids = {garment.id for garment in request.garments}

    assert ai.calls == 1
    assert result.fallback_used is False
    assert result.provider == "fake-text-model"
    assert 1 <= len(result.outfits) <= 3
    for outfit in result.outfits:
        assert outfit.source == "remote_api"
        assert set(outfit.item_ids) <= all_request_ids
        assert len(outfit.item_ids) == len(set(outfit.item_ids))


def test_invented_ai_item_id_falls_back_to_rules() -> None:
    ai = InvalidIdTextAI()
    request = _recommendation_request()

    result = create_recommendations(request, ai_provider=ai)

    assert ai.calls == 1
    assert result.fallback_used is True
    assert result.provider == "rule_engine_mock"
    assert all(
        outfit.source == "fallback"
        for outfit in result.outfits
    )


def test_ai_revision_keeps_rule_generated_item_ids() -> None:
    ai = FakeTextAI()
    request = _recommendation_request()
    rule_result = create_recommendations(request)
    base_ids = rule_result.outfits[0].item_ids
    garment_by_id = {garment.id: garment for garment in request.garments}
    replacement = next(
        garment
        for garment in request.garments
        if garment.slot.value == "shoes"
        and garment.id not in base_ids
    )
    revision_request = OutfitRevisionRequest(
        **request.model_dump(),
        base_item_ids=base_ids,
        replacement_item_id=replacement.id,
    )

    revised = revise_outfit(revision_request, ai_provider=ai)

    assert revised.source == "remote_api"
    assert revised.title == "Revised for the selected occasion"
    before_by_slot = {
        garment_by_id[item_id].slot: item_id
        for item_id in base_ids
    }
    after_by_slot = {
        garment_by_id[item_id].slot: item_id
        for item_id in revised.item_ids
    }
    assert after_by_slot["top"] == before_by_slot["top"]
    assert after_by_slot["bottom"] == before_by_slot["bottom"]
    assert after_by_slot["shoes"] == replacement.id
