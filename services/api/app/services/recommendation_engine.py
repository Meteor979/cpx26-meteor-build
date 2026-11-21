from datetime import datetime, timezone
from itertools import product
from typing import Dict, List, Optional, Sequence, Tuple

from app.errors import ApiError
from app.models import (
    FormalityBand,
    GarmentSlot,
    OccasionPreset,
    OccasionResolveRequest,
    Outfit,
    RecommendationGarment,
    RecommendationRequest,
    RecommendationResponse,
)
from app.services.occasion_matcher import PRESET_MODELS, resolve_occasion

FORMALITY_SCORE: Dict[FormalityBand, float] = {
    FormalityBand.CASUAL: 2,
    FormalityBand.SMART_CASUAL: 3,
    FormalityBand.BUSINESS: 4,
    FormalityBand.FORMAL: 5,
}


def _preset_for_request(request: RecommendationRequest) -> OccasionPreset:
    if request.preset_id:
        matched = next(
            (preset for preset in PRESET_MODELS if preset.id == request.preset_id),
            None,
        )
        if matched:
            return matched

    return resolve_occasion(
        OccasionResolveRequest(
            request_id=request.request_id,
            query=request.occasion,
            formality_hint=request.formality,
        )
    ).profile


def _style_score(
    preset: OccasionPreset,
    items: Sequence[RecommendationGarment],
) -> float:
    target = FORMALITY_SCORE[preset.target_formality]
    average = sum(item.formality_score for item in items) / len(items)
    score = 6 - abs(average - target) * 2
    colors = {color.lower() for item in items for color in item.colors}
    categories = {item.category.lower() for item in items}

    if preset.id == "night-out":
        for item in items:
            if item.formality_score <= 2:
                score += 1.4
            elif item.formality_score >= 4:
                score -= 2.2
        score += 1.1 if "sneakers" in categories else 0
        score += 0.7 if {"t_shirt", "knitwear"} & categories else 0
        score -= 1.5 if "blazer" in categories else 0
        score += min(0.8, max(0, len(colors) - 1) * 0.4)
    elif preset.id in {"internship-interview", "club-speech"}:
        score += sum(0.75 for item in items if item.formality_score >= 3)
        score += (
            1.2
            if {"trousers", "shirt", "loafers", "blazer"} & categories
            else 0
        )
        score -= 0.8 if "sneakers" in categories else 0
    elif preset.target_formality == FormalityBand.CASUAL:
        score += sum(0.4 for item in items if item.formality_score <= 2)
    elif preset.target_formality in {
        FormalityBand.BUSINESS,
        FormalityBand.FORMAL,
    }:
        score += sum(0.4 for item in items if item.formality_score >= 3)

    return round(score, 4)


def _title_for(preset: OccasionPreset) -> str:
    titles = {
        "night-out": "轻松，有个人表达",
        "internship-interview": "清晰，可信",
        "club-speech": "专业但不过度正式",
        "first-date": "自然，容易接近",
        "salon-performance": "有层次，便于行动",
    }
    return titles.get(preset.id, f"{preset.name}搭配")


def _reasons_for(
    preset: OccasionPreset,
    items: Sequence[RecommendationGarment],
) -> Tuple[List[str], List[str]]:
    by_slot = {item.slot: item for item in items}
    top = by_slot[GarmentSlot.TOP]
    bottom = by_slot[GarmentSlot.BOTTOM]
    shoes = by_slot[GarmentSlot.SHOES]
    top_name = top.product_name or top.category
    bottom_name = bottom.product_name or bottom.category
    shoes_name = shoes.product_name or shoes.category

    if preset.id == "night-out":
        reasons = [
            "整体正式度更接近夜间社交，不会像商务会面。",
            f"{top_name}与{bottom_name}保留轻松感，也形成清楚的个人轮廓。",
            f"{shoes_name}方便走动，同时不会把造型拉回全套正装。",
        ]
        tradeoffs = ["如果单品本身偏商务，夜间社交感会相应减弱。"]
    elif preset.id in {"internship-interview", "club-speech"}:
        reasons = [
            "整体正式度更适合正式表达和面试场景。",
            f"{top_name}与{bottom_name}形成清楚、可靠的上下装结构。",
            f"{shoes_name}不会削弱专业感，也便于走动和沟通。",
        ]
        tradeoffs = ["整体更正式，不适合非常随意的夜间社交。"]
    else:
        keywords = "、".join(preset.style_keywords[:3])
        reasons = [
            f"整体围绕{preset.name}的{keywords}展开。",
            f"{top_name}与{bottom_name}的正式度接近当前场合。",
            f"{shoes_name}与本地衣柜中的其他照片保持完整组合。",
        ]
        tradeoffs = ["当前由后端规则排序，未调用真实生成式 AI。"]

    return reasons, tradeoffs


def _candidate_items(
    garments: List[RecommendationGarment],
) -> List[Tuple[RecommendationGarment, ...]]:
    grouped: Dict[GarmentSlot, List[RecommendationGarment]] = {
        slot: [item for item in garments if item.slot == slot]
        for slot in GarmentSlot
    }
    required = [GarmentSlot.TOP, GarmentSlot.BOTTOM, GarmentSlot.SHOES]
    missing = [slot.value for slot in required if not grouped[slot]]
    if missing:
        raise ApiError(
            422,
            "INSUFFICIENT_WARDROBE",
            "至少需要一件上装、一件下装和一双鞋。",
            {"missing_slots": missing},
        )

    outerwear_options: List[Optional[RecommendationGarment]] = [None]
    outerwear_options.extend(grouped[GarmentSlot.OUTERWEAR])

    combinations: List[Tuple[RecommendationGarment, ...]] = []
    seen: set = set()
    for top, bottom, shoes, outerwear in product(
        grouped[GarmentSlot.TOP],
        grouped[GarmentSlot.BOTTOM],
        grouped[GarmentSlot.SHOES],
        outerwear_options,
    ):
        items = [top, bottom, shoes]
        if outerwear is not None:
            items.append(outerwear)
        ids = tuple(item.id for item in items)
        if ids not in seen:
            seen.add(ids)
            combinations.append(tuple(items))
    return combinations


def recommend_outfits(
    request: RecommendationRequest,
) -> RecommendationResponse:
    preset = _preset_for_request(request)
    scored = [
        (_style_score(preset, items), items)
        for items in _candidate_items(request.garments)
    ]
    scored.sort(key=lambda item: (-item[0], tuple(g.id for g in item[1])))
    selected = scored[:3]

    outfits: List[Outfit] = []
    for index, (score, items) in enumerate(selected):
        reasons, tradeoffs = _reasons_for(preset, items)
        item_ids = [item.id for item in items]
        outfits.append(
            Outfit(
                id=f"{preset.id}-{index + 1}-{'-'.join(value[:4] for value in item_ids)}",
                item_ids=item_ids,
                title=_title_for(preset),
                reasons=reasons,
                tradeoffs=tradeoffs,
                source="fallback" if preset.id.startswith("fallback") else "remote_api",
                score=score,
            )
        )

    count_reason = (
        "three_available"
        if len(outfits) >= 3
        else "limited_candidates"
    )
    warning = (
        None
        if len(outfits) >= 3
        else "当前衣柜可组成的搭配少于三套。"
    )
    return RecommendationResponse(
        outfits=outfits,
        requested_count=3,
        result_count_reason=count_reason,
        fallback_used=preset.id.startswith("fallback"),
        warning=warning,
        provider="rule_engine_with_occasion_scoring",
        generated_at=datetime.now(timezone.utc),
        request_id=request.request_id,
    )
