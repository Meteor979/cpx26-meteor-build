import re
import unicodedata
from datetime import datetime
from difflib import SequenceMatcher
from typing import Dict, List, Optional, Tuple

from app.data.mock_data import (
    FALLBACK_GENERATED_AT,
    PRESET_GENERATED_AT,
    PRESETS,
    PRESET_VERSION,
)
from app.errors import ApiError
from app.models import (
    FormalityBand,
    OccasionPreset,
    OccasionResolveRequest,
    OccasionResolveResponse,
    PresetListResponse,
)

PRESET_MODELS: List[OccasionPreset] = [
    OccasionPreset.model_validate(item) for item in PRESETS
]
SEMANTIC_THRESHOLD = 0.62
FORMALITY_NEIGHBORS: Dict[FormalityBand, List[FormalityBand]] = {
    FormalityBand.CASUAL: [FormalityBand.CASUAL, FormalityBand.SMART_CASUAL],
    FormalityBand.SMART_CASUAL: [
        FormalityBand.CASUAL,
        FormalityBand.SMART_CASUAL,
        FormalityBand.BUSINESS,
    ],
    FormalityBand.BUSINESS: [
        FormalityBand.SMART_CASUAL,
        FormalityBand.BUSINESS,
        FormalityBand.FORMAL,
    ],
    FormalityBand.FORMAL: [FormalityBand.BUSINESS, FormalityBand.FORMAL],
}


def normalize_query(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value).strip().casefold()
    return re.sub(r"[\W_]+", "", normalized, flags=re.UNICODE)


def _normalized_values(preset: OccasionPreset) -> List[str]:
    return [
        normalize_query(value)
        for value in [preset.name] + preset.aliases
    ]


def _semantic_score(query: str, preset: OccasionPreset) -> float:
    values = _normalized_values(preset)
    scores: List[float] = []
    for value in values:
        if not value:
            continue
        if value in query or query in value:
            scores.append(0.86)
        scores.append(SequenceMatcher(None, query, value).ratio())

    for keyword in preset.style_keywords:
        normalized_keyword = normalize_query(keyword)
        if normalized_keyword and (
            normalized_keyword in query or query in normalized_keyword
        ):
            scores.append(0.84)

    return max(scores, default=0.0)


def _matches_filter(query: str, preset: OccasionPreset) -> bool:
    if not query:
        return False
    if any(query in value for value in _normalized_values(preset)):
        return True
    return any(
        query in normalize_query(keyword)
        or normalize_query(keyword) in query
        for keyword in preset.style_keywords
    )


def list_presets(
    query: Optional[str],
    limit: int,
) -> PresetListResponse:
    normalized_query = normalize_query(query) if query else ""
    presets = (
        [preset for preset in PRESET_MODELS if _matches_filter(normalized_query, preset)]
        if normalized_query
        else list(PRESET_MODELS)
    )
    return PresetListResponse(
        version=PRESET_VERSION,
        cached=True,
        generated_at=datetime.fromisoformat(PRESET_GENERATED_AT),
        presets=presets[:limit],
    )


def _exact_preset(query: str) -> Optional[OccasionPreset]:
    for preset in PRESET_MODELS:
        if query in _normalized_values(preset):
            return preset
    return None


def _best_semantic_preset(
    query: str,
) -> Tuple[Optional[OccasionPreset], float]:
    scored = [
        (preset, _semantic_score(query, preset))
        for preset in PRESET_MODELS
    ]
    scored.sort(key=lambda item: (-item[1], item[0].id))
    if not scored or scored[0][1] < SEMANTIC_THRESHOLD:
        return None, 0.0
    return scored[0]


def _fallback_profile(
    request: OccasionResolveRequest,
) -> OccasionPreset:
    target = request.formality_hint or FormalityBand.SMART_CASUAL
    query_alias = request.query.strip()
    return OccasionPreset(
        id="fallback-general-occasion",
        name="通用场合策略",
        aliases=[query_alias],
        description="未找到明确的本地场合匹配，使用整洁自然的通用策略。",
        target_formality=target,
        allowed_formality=FORMALITY_NEIGHBORS[target],
        required_slots=["top", "bottom", "shoes"],
        style_keywords=["整洁", "自然", "可接近"],
        avoid_rules=["避免过度正式", "避免颜色和图案过度复杂"],
        explanation_guidelines=[
            "解释正式程度是否适合当前场合",
            "解释颜色关系与整体气质",
            "说明当前使用通用备用策略",
        ],
        source="fallback",
        version=PRESET_VERSION,
        generated_at=datetime.fromisoformat(FALLBACK_GENERATED_AT),
    )


def resolve_occasion(
    request: OccasionResolveRequest,
) -> OccasionResolveResponse:
    normalized_query = normalize_query(request.query)
    if not normalized_query:
        raise ApiError(
            422,
            "VALIDATION_ERROR",
            "请求字段不符合接口契约。",
            {"field": "query"},
        )

    exact = _exact_preset(normalized_query)
    if exact is not None:
        alternatives = [preset for preset in PRESET_MODELS if preset.id != exact.id]
        return OccasionResolveResponse(
            query=request.query,
            profile=exact,
            match_type="exact_preset",
            confidence=1.0,
            cached=True,
            alternatives=alternatives[:3],
            warning=None,
            request_id=request.request_id,
        )

    semantic, score = _best_semantic_preset(normalized_query)
    if semantic is not None:
        alternatives = [preset for preset in PRESET_MODELS if preset.id != semantic.id]
        return OccasionResolveResponse(
            query=request.query,
            profile=semantic,
            match_type="semantic_match",
            confidence=round(min(max(score, 0.7), 0.88), 2),
            cached=True,
            alternatives=alternatives[:3],
            warning=None,
            request_id=request.request_id,
        )

    return OccasionResolveResponse(
        query=request.query,
        profile=_fallback_profile(request),
        match_type="fallback",
        confidence=0.35,
        cached=False,
        alternatives=[],
        warning="未找到明确的本地场合匹配，已使用通用备用策略。",
        request_id=request.request_id,
    )
