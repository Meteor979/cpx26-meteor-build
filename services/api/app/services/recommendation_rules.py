from datetime import datetime, timezone
from itertools import product
from typing import Any, Dict, List, Optional, Tuple
from uuid import uuid4

from app.data.mock_data import PRESETS
from app.errors import ApiError
from app.models import (
    FormalityBand,
    GarmentSlot,
    Outfit,
    OutfitRevisionRequest,
    RecommendationGarment,
    RecommendationRequest,
    RecommendationResponse,
)
from app.services.text_ai import TextAIProvider, TextAIProviderError

RULE_PROVIDER = "rule_engine_mock"
RULE_WARNING = (
    "Deterministic local rules are in use; no live AI ranking "
    "was applied."
)
FORMALITY_TARGET: Dict[FormalityBand, float] = {
    FormalityBand.CASUAL: 2.0,
    FormalityBand.SMART_CASUAL: 3.0,
    FormalityBand.BUSINESS: 4.0,
    FormalityBand.FORMAL: 5.0,
}
REQUIRED_SLOTS: Tuple[GarmentSlot, ...] = (
    GarmentSlot.TOP,
    GarmentSlot.BOTTOM,
    GarmentSlot.SHOES,
)
OPEN_SHOE_CATEGORIES = {
    "flip-flop",
    "flip_flops",
    "sandal",
    "sandals",
    "slide",
    "slides",
}
NEUTRAL_COLORS = {
    "black",
    "white",
    "gray",
    "grey",
    "beige",
    "cream",
    "brown",
    "navy",
    "charcoal",
}
SLOT_LABELS: Dict[GarmentSlot, str] = {
    GarmentSlot.TOP: "top",
    GarmentSlot.BOTTOM: "bottom",
    GarmentSlot.OUTERWEAR: "outerwear",
    GarmentSlot.SHOES: "shoes",
    GarmentSlot.ACCESSORY: "accessory",
}


class Candidate:
    def __init__(
        self,
        garments: List[RecommendationGarment],
        score: float,
    ) -> None:
        self.garments = garments
        self.item_ids = [garment.id for garment in garments]
        self.score = score


def derive_formality_band(score: int) -> FormalityBand:
    if score <= 2:
        return FormalityBand.CASUAL
    if score == 3:
        return FormalityBand.SMART_CASUAL
    if score == 4:
        return FormalityBand.BUSINESS
    return FormalityBand.FORMAL


def _groups(
    garments: List[RecommendationGarment],
) -> Dict[GarmentSlot, List[RecommendationGarment]]:
    values: Dict[GarmentSlot, List[RecommendationGarment]] = {
        slot: [] for slot in GarmentSlot
    }
    for garment in garments:
        values[garment.slot].append(garment)
    return values


def _validate_unique_garment_ids(request: RecommendationRequest) -> None:
    seen: Dict[str, bool] = {}
    duplicate_ids: List[str] = []
    for garment in request.garments:
        if garment.id in seen and garment.id not in duplicate_ids:
            duplicate_ids.append(garment.id)
        seen[garment.id] = True
    if duplicate_ids:
        raise ApiError(
            422,
            "DUPLICATE_GARMENT_ID",
            "Garment IDs must be unique.",
            {"duplicate_ids": duplicate_ids},
        )


def _ensure_required_slots(
    garments: List[RecommendationGarment],
) -> Dict[GarmentSlot, List[RecommendationGarment]]:
    grouped = _groups(garments)
    missing_slots = [
        slot.value for slot in REQUIRED_SLOTS if not grouped[slot]
    ]
    if missing_slots:
        raise ApiError(
            422,
            "INSUFFICIENT_WARDROBE",
            "At least one top, one bottom, and one pair of shoes are required.",
            {"missing_slots": missing_slots},
        )
    return grouped


def _target_warmth(feels_like_c: float) -> int:
    if feels_like_c <= 5:
        return 5
    if feels_like_c <= 12:
        return 4
    if feels_like_c <= 18:
        return 3
    if feels_like_c <= 24:
        return 2
    return 1


def _color_harmony(garments: List[RecommendationGarment]) -> float:
    colors = [
        color.strip().lower()
        for garment in garments
        for color in garment.colors
        if color.strip()
    ]
    if len(set(colors)) <= 1:
        return 1.0
    neutral_count = sum(color in NEUTRAL_COLORS for color in colors)
    return round(min(0.7 + neutral_count / max(len(colors), 1) * 0.3, 1.0), 4)


def _score_candidate(
    garments: List[RecommendationGarment],
    request: RecommendationRequest,
) -> float:
    average_formality = sum(
        garment.formality_score for garment in garments
    ) / len(garments)
    average_warmth = sum(
        garment.warmth_score for garment in garments
    ) / len(garments)
    formality_fit = max(
        1.0 - abs(average_formality - FORMALITY_TARGET[request.formality]) / 4.0,
        0.0,
    )
    warmth_fit = max(
        1.0 - abs(average_warmth - _target_warmth(request.weather.feels_like_c)) / 4.0,
        0.0,
    )
    score = (
        0.55 * formality_fit
        + 0.30 * warmth_fit
        + 0.15 * _color_harmony(garments)
    )

    shoes = next(
        garment for garment in garments if garment.slot == GarmentSlot.SHOES
    )
    wet_weather = (
        request.weather.precipitation_probability >= 0.5
        or request.weather.condition in {"rain", "snow", "storm"}
    )
    if wet_weather and shoes.category.strip().lower() in OPEN_SHOE_CATEGORIES:
        score -= 0.12

    has_outerwear = any(
        garment.slot == GarmentSlot.OUTERWEAR for garment in garments
    )
    if request.weather.feels_like_c <= 12 and has_outerwear:
        score += 0.05
    if request.weather.feels_like_c >= 24 and has_outerwear:
        score -= 0.08

    return round(min(max(score, 0.0), 1.0), 4)


def _candidates(request: RecommendationRequest) -> List[Candidate]:
    _validate_unique_garment_ids(request)
    grouped = _ensure_required_slots(request.garments)
    outerwear_options: List[Optional[RecommendationGarment]] = [None]
    outerwear_needed = (
        request.weather.feels_like_c <= 12
        or request.weather.precipitation_probability >= 0.5
        or request.weather.condition in {"rain", "snow", "storm"}
    )
    if outerwear_needed:
        outerwear_options.extend(grouped[GarmentSlot.OUTERWEAR])

    result: List[Candidate] = []
    seen_ids: Dict[Tuple[str, ...], bool] = {}
    for top, bottom, shoes, outerwear in product(
        grouped[GarmentSlot.TOP],
        grouped[GarmentSlot.BOTTOM],
        grouped[GarmentSlot.SHOES],
        outerwear_options,
    ):
        garments = [top, bottom, shoes]
        if outerwear is not None:
            garments.append(outerwear)
        key = tuple(sorted(garment.id for garment in garments))
        if key in seen_ids or len(set(key)) != len(key):
            continue
        seen_ids[key] = True
        result.append(Candidate(garments, _score_candidate(garments, request)))

    result.sort(key=lambda candidate: (-candidate.score, candidate.item_ids))
    return result


def _color_relation(garments: List[RecommendationGarment]) -> str:
    colors = [
        color
        for garment in garments
        for color in garment.colors
        if color
    ]
    unique_colors = list(dict.fromkeys(colors))
    if len(unique_colors) == 1:
        return (
            "The recorded palette centers on %s, creating a clear "
            "single-tone relationship without relying on subtle color shifts."
            % unique_colors[0]
        )
    neutral_count = sum(
        color.strip().lower() in NEUTRAL_COLORS for color in unique_colors
    )
    if neutral_count:
        return (
            "The recorded colors are %s. Neutral tones provide a stable "
            "base, while light-dark contrast and labeled garment cards "
            "create visual separation."
            % ", ".join(unique_colors)
        )
    return (
        "The recorded colors are %s. Use the light-dark contrast and "
        "stable image frames to distinguish the layers."
        % ", ".join(unique_colors)
    )


def _tradeoff(garments: List[RecommendationGarment]) -> str:
    if any(garment.slot == GarmentSlot.OUTERWEAR for garment in garments):
        return (
            "An outer layer adds warmth and visual structure, "
            "but introduces one more dressing step."
        )
    return (
        "The local rule mock relies on confirmed labels and cannot judge "
        "fabric drape or personal preference."
    )


def _outfit_reasons(
    garments: List[RecommendationGarment],
    request: RecommendationRequest,
) -> List[str]:
    average_formality = sum(
        garment.formality_score for garment in garments
    ) / len(garments)
    actual_band = derive_formality_band(round(average_formality))
    return [
        _color_relation(garments),
        (
            "The average formality is %.1f/5, close to %s for a "
            "%s target."
            % (
                average_formality,
                actual_band.value,
                request.formality.value,
            )
        ),
        (
            "For “%s,” the combination balances occasion fit and movement "
            "at a feels-like temperature of %.1f°C with a %.0f%% "
            "chance of precipitation."
            % (
                request.occasion,
                request.weather.feels_like_c,
                request.weather.precipitation_probability * 100,
            )
        ),
    ]


def _to_outfit(
    candidate: Candidate,
    index: int,
    request: RecommendationRequest,
) -> Outfit:
    titles = (
        "Clear and natural",
        "Softly balanced",
        "Sharp and composed",
    )
    return Outfit(
        id="rule-outfit-%s" % chr(ord("a") + index),
        item_ids=candidate.item_ids,
        title=titles[index],
        reasons=_outfit_reasons(candidate.garments, request),
        tradeoffs=[_tradeoff(candidate.garments)],
        source="fallback",
        score=candidate.score,
    )


def create_recommendations(
    request: RecommendationRequest,
    ai_provider: Optional[TextAIProvider] = None,
) -> RecommendationResponse:
    candidates = _candidates(request)
    if ai_provider is not None:
        ai_outfits = _try_ai_outfits(
            request,
            candidates,
            ai_provider,
        )
        if ai_outfits is not None:
            return RecommendationResponse(
                outfits=ai_outfits,
                requested_count=3,
                result_count_reason=(
                    "three_available"
                    if len(ai_outfits) == 3
                    else "limited_candidates"
                ),
                fallback_used=False,
                warning=None,
                provider=ai_provider.name,
                generated_at=datetime.now(timezone.utc),
                request_id=request.request_id or "req-%s" % uuid4().hex[:12],
            )

    selected = candidates[:3]
    outfits = [
        _to_outfit(candidate, index, request)
        for index, candidate in enumerate(selected)
    ]
    return RecommendationResponse(
        outfits=outfits,
        requested_count=3,
        result_count_reason=(
            "three_available" if len(outfits) == 3 else "limited_candidates"
        ),
        fallback_used=True,
        warning=RULE_WARNING,
        provider=RULE_PROVIDER,
        generated_at=datetime.now(timezone.utc),
        request_id=request.request_id or "req-%s" % uuid4().hex[:12],
    )


def revise_outfit(
    request: OutfitRevisionRequest,
    ai_provider: Optional[TextAIProvider] = None,
) -> Outfit:
    _validate_unique_garment_ids(request)
    _ensure_required_slots(request.garments)
    garments_by_id: Dict[str, RecommendationGarment] = {
        garment.id: garment for garment in request.garments
    }

    seen_base: Dict[str, bool] = {}
    for item_id in request.base_item_ids:
        if item_id in seen_base:
            raise ApiError(
                422,
                "DUPLICATE_BASE_ITEM_ID",
                "base_item_ids must not contain duplicate garment IDs.",
                {"duplicate_ids": [item_id]},
            )
        seen_base[item_id] = True

    missing_base_ids = [
        item_id for item_id in request.base_item_ids if item_id not in garments_by_id
    ]
    if missing_base_ids:
        raise ApiError(
            422,
            "UNKNOWN_ITEM_ID",
            "base_item_ids contains an unknown garment.",
            {"missing_item_ids": missing_base_ids},
        )

    replacement = garments_by_id.get(request.replacement_item_id)
    if replacement is None:
        raise ApiError(
            422,
            "UNKNOWN_ITEM_ID",
            "replacement_item_id is not present in garments.",
            {"missing_item_ids": [request.replacement_item_id]},
        )

    base_garments = [garments_by_id[item_id] for item_id in request.base_item_ids]
    _ensure_required_slots(base_garments)
    slot_matches = [
        garment for garment in base_garments if garment.slot == replacement.slot
    ]
    if not slot_matches:
        raise ApiError(
            422,
            "SLOT_MISMATCH",
            "replacement_item_id has no matching slot in the base outfit.",
            {"replacement_slot": replacement.slot.value},
        )
    if len(slot_matches) > 1:
        raise ApiError(
            422,
            "AMBIGUOUS_REPLACEMENT_SLOT",
            (
                "The base outfit contains multiple garments in the replacement "
                "slot, so the target is ambiguous."
            ),
            {"slot": replacement.slot.value},
        )
    if slot_matches[0].id == replacement.id:
        raise ApiError(
            422,
            "INVALID_REVISION",
            "replacement_item_id already matches the current slot garment.",
            {"item_id": replacement.id},
        )

    revised_ids = [
        replacement.id if item_id == slot_matches[0].id else item_id
        for item_id in request.base_item_ids
    ]
    revised_garments = [garments_by_id[item_id] for item_id in revised_ids]
    _ensure_required_slots(revised_garments)

    candidate = Candidate(
        garments=revised_garments,
        score=_score_candidate(revised_garments, request),
    )
    local_outfit = Outfit(
        id="rule-outfit-revised",
        item_ids=revised_ids,
        title="Revised %s selection" % SLOT_LABELS[replacement.slot],
        reasons=_outfit_reasons(revised_garments, request),
        tradeoffs=[_tradeoff(revised_garments)],
        source="fallback",
        score=candidate.score,
    )

    if ai_provider is None:
        return local_outfit

    generated = _try_ai_revision(
        request,
        local_outfit,
        revised_garments,
        ai_provider,
    )
    return generated or local_outfit


AI_RECOMMENDATION_SYSTEM_PROMPT = """
You rank legal outfit candidates for a person with color-vision deficiency or
low vision. Return one JSON object and no markdown.
You may select only items from the supplied candidates. Never invent item IDs,
duplicate a garment, alter weather, or add fields.
Return up to three different outfits in display order.
The occasion must materially affect ranking. Do not default unfamiliar social
events to business. Use English for all title, reasons, and tradeoffs.
Each outfit must contain one top, one bottom, one pair of shoes, and optionally
one outerwear item. Write concise, concrete explanations that mention color or
light-dark relationships, formality, occasion fit, and one tradeoff.
The JSON shape must be:
{"outfits":[{"item_ids":["..."],"title":"...","reasons":["..."],"tradeoffs":["..."]}]}
Do not include commentary outside JSON.
""".strip()


AI_REVISION_SYSTEM_PROMPT = """
You write replacement copy for one already-valid outfit.
Return one JSON object and no markdown:
{"title":"...","reasons":["..."],"tradeoffs":["..."]}
You must not add or change item IDs. Use natural English.
Explain the same-slot replacement, the unchanged surrounding garments,
formality, color relationship, and one tradeoff.
Do not include commentary outside JSON.
""".strip()


def _candidate_garment_payload(
    garments: List[RecommendationGarment],
) -> List[Dict[str, Any]]:
    return [
        {
            "id": garment.id,
            "slot": garment.slot.value,
            "category": garment.category,
            "colors": garment.colors,
            "pattern": garment.pattern,
            "fit": garment.fit,
            "material": garment.material,
            "formality_score": garment.formality_score,
            "warmth_score": garment.warmth_score,
        }
        for garment in garments
    ]


def _try_ai_outfits(
    request: RecommendationRequest,
    candidates: List[Candidate],
    ai_provider: TextAIProvider,
) -> Optional[List[Outfit]]:
    payload = {
        "occasion": request.occasion,
        "preset_id": request.preset_id,
        "preset_context": _preset_context(request.preset_id),
        "formality": request.formality.value,
        "weather": request.weather.model_dump(mode="json"),
        "candidates": [
            {
                "item_ids": candidate.item_ids,
                "garments": _candidate_garment_payload(candidate.garments),
                "rule_score": candidate.score,
            }
            for candidate in candidates[:8]
        ],
    }
    try:
        result = ai_provider.complete_json(
            system_prompt=AI_RECOMMENDATION_SYSTEM_PROMPT,
            payload=payload,
            request_id=request.request_id or "recommendations",
        )
        raw_outfits = result.get("outfits")
        if not isinstance(raw_outfits, list) or not 1 <= len(raw_outfits) <= 3:
            return None

        by_items = {
            frozenset(candidate.item_ids): candidate
            for candidate in candidates
        }
        seen_signatures: Dict[frozenset, bool] = {}
        outfits: List[Outfit] = []
        for index, raw in enumerate(raw_outfits):
            if not isinstance(raw, dict):
                return None
            item_ids = raw.get("item_ids")
            title = raw.get("title")
            reasons = raw.get("reasons")
            tradeoffs = raw.get("tradeoffs")
            if (
                not isinstance(item_ids, list)
                or not item_ids
                or not all(isinstance(item, str) for item in item_ids)
                or len(item_ids) != len(set(item_ids))
                or not isinstance(title, str)
                or not title.strip()
                or len(title) > 100
                or not isinstance(reasons, list)
                or not 1 <= len(reasons) <= 4
                or not all(isinstance(reason, str) and reason.strip() for reason in reasons)
                or not isinstance(tradeoffs, list)
                or len(tradeoffs) > 3
                or not all(isinstance(tradeoff, str) and tradeoff.strip() for tradeoff in tradeoffs)
            ):
                return None

            signature = frozenset(item_ids)
            candidate = by_items.get(signature)
            if candidate is None or signature in seen_signatures:
                return None
            seen_signatures[signature] = True
            outfits.append(
                Outfit(
                    id="ai-outfit-%s" % chr(ord("a") + index),
                    item_ids=list(item_ids),
                    title=title.strip(),
                    reasons=[reason.strip() for reason in reasons],
                    tradeoffs=[tradeoff.strip() for tradeoff in tradeoffs],
                    source="remote_api",
                    score=candidate.score,
                )
            )
        return outfits
    except (
        TextAIProviderError,
        TypeError,
        ValueError,
    ):
        return None


def _try_ai_revision(
    request: OutfitRevisionRequest,
    local_outfit: Outfit,
    revised_garments: List[RecommendationGarment],
    ai_provider: TextAIProvider,
) -> Optional[Outfit]:
    try:
        result = ai_provider.complete_json(
            system_prompt=AI_REVISION_SYSTEM_PROMPT,
            payload={
                "occasion": request.occasion,
                "preset_id": request.preset_id,
                "preset_context": _preset_context(request.preset_id),
                "formality": request.formality.value,
                "weather": request.weather.model_dump(mode="json"),
                "item_ids": local_outfit.item_ids,
                "garments": _candidate_garment_payload(revised_garments),
            },
            request_id=request.request_id or "revision",
        )
        title = result.get("title")
        reasons = result.get("reasons")
        tradeoffs = result.get("tradeoffs")
        if (
            not isinstance(title, str)
            or not title.strip()
            or len(title) > 100
            or not isinstance(reasons, list)
            or not 1 <= len(reasons) <= 4
            or not all(isinstance(reason, str) and reason.strip() for reason in reasons)
            or not isinstance(tradeoffs, list)
            or len(tradeoffs) > 3
            or not all(isinstance(tradeoff, str) and tradeoff.strip() for tradeoff in tradeoffs)
        ):
            return None
        return Outfit(
            id=local_outfit.id,
            item_ids=local_outfit.item_ids,
            title=title.strip(),
            reasons=[reason.strip() for reason in reasons],
            tradeoffs=[tradeoff.strip() for tradeoff in tradeoffs],
            source="remote_api",
            score=local_outfit.score,
        )
    except (
        TextAIProviderError,
        TypeError,
        ValueError,
    ):
        return None


def _preset_context(preset_id: Optional[str]) -> Optional[Dict[str, Any]]:
    if not preset_id:
        return None
    for preset in PRESETS:
        if preset.get("id") == preset_id:
            return {
                "name": preset.get("name"),
                "description": preset.get("description"),
                "target_formality": preset.get("target_formality"),
                "allowed_formality": preset.get("allowed_formality"),
                "style_keywords": preset.get("style_keywords"),
                "avoid_rules": preset.get("avoid_rules"),
            }
    return None
