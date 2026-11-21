from datetime import datetime, timezone
from itertools import product
from typing import Dict, List, Optional, Tuple
from uuid import uuid4

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

RULE_PROVIDER = "rule_engine_mock"
RULE_WARNING = "当前为确定性规则 Mock，未调用真实 AI。"
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
    GarmentSlot.TOP: "上装",
    GarmentSlot.BOTTOM: "下装",
    GarmentSlot.OUTERWEAR: "外套",
    GarmentSlot.SHOES: "鞋",
    GarmentSlot.ACCESSORY: "配饰",
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
            "衣物 ID 不得重复。",
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
            "至少需要一件上装、一件下装和一双鞋。",
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
            "衣物记录以%s为主，单色关系清楚，不依赖细微色差区分层次"
            % unique_colors[0]
        )
    neutral_count = sum(
        color.strip().lower() in NEUTRAL_COLORS for color in unique_colors
    )
    if neutral_count:
        return (
            "衣物颜色记录为%s，其中中性色占比稳定，"
            "主要通过明暗差和有文字标签形成层次"
            % "、".join(unique_colors)
        )
    return (
        "衣物颜色记录为%s，建议通过明暗对比和稳定边框辨认层次"
        % "、".join(unique_colors)
    )


def _tradeoff(garments: List[RecommendationGarment]) -> str:
    if any(garment.slot == GarmentSlot.OUTERWEAR for garment in garments):
        return "增加外套能提升保暖和层次，但会多一个穿脱步骤。"
    return "规则 Mock 只能依据已确认标签，无法判断真实面料垂感和个人偏好。"


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
            "平均正式程度为 %.1f/5，对应 %s，目标场合为 %s。"
            % (average_formality, actual_band.value, request.formality.value)
        ),
        (
            "面向“%s”，体感 %.1f°C、降水概率 %.0f%%，"
            "当前组合优先兼顾场合适配和行动舒适度。"
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
        "清晰自然的规则方案",
        "温和协调的规则方案",
        "利落明确的规则方案",
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
) -> RecommendationResponse:
    candidates = _candidates(request)
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
                "base_item_ids 不得包含重复衣物 ID。",
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
            "base_item_ids 中存在未知衣物。",
            {"missing_item_ids": missing_base_ids},
        )

    replacement = garments_by_id.get(request.replacement_item_id)
    if replacement is None:
        raise ApiError(
            422,
            "UNKNOWN_ITEM_ID",
            "replacement_item_id 不存在于 garments。",
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
            "replacement_item_id 与基础搭配没有同槽位衣物。",
            {"replacement_slot": replacement.slot.value},
        )
    if len(slot_matches) > 1:
        raise ApiError(
            422,
            "AMBIGUOUS_REPLACEMENT_SLOT",
            "基础搭配中同一槽位存在多件衣物，无法确定替换目标。",
            {"slot": replacement.slot.value},
        )
    if slot_matches[0].id == replacement.id:
        raise ApiError(
            422,
            "INVALID_REVISION",
            "replacement_item_id 与当前槽位衣物相同。",
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
    return Outfit(
        id="rule-outfit-revised",
        item_ids=revised_ids,
        title="替换%s后的规则方案" % SLOT_LABELS[replacement.slot],
        reasons=_outfit_reasons(revised_garments, request),
        tradeoffs=[_tradeoff(revised_garments)],
        source="fallback",
        score=candidate.score,
    )
