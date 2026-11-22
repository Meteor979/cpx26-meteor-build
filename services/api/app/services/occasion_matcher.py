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
from app.services.text_ai import TextAIProvider, TextAIProviderError

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
        name="General occasion strategy",
        aliases=[query_alias],
        description=(
            "No confident local match was found. Use a clean, "
            "natural general strategy."
        ),
        target_formality=target,
        allowed_formality=FORMALITY_NEIGHBORS[target],
        required_slots=["top", "bottom", "shoes"],
        style_keywords=["clean", "natural", "approachable"],
        avoid_rules=[
            "Avoid excessive formality",
            "Avoid overly complex colors and patterns",
        ],
        explanation_guidelines=[
            "Explain whether the formality suits the occasion",
            "Explain the color relationship and overall tone",
            "State that a general fallback strategy is in use",
        ],
        source="fallback",
        version=PRESET_VERSION,
        generated_at=datetime.fromisoformat(FALLBACK_GENERATED_AT),
    )


def resolve_occasion(
    request: OccasionResolveRequest,
    ai_provider: Optional[TextAIProvider] = None,
) -> OccasionResolveResponse:
    normalized_query = normalize_query(request.query)
    if not normalized_query:
        raise ApiError(
            422,
            "VALIDATION_ERROR",
            "Request fields do not match the API contract.",
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

    if ai_provider is not None:
        generated = _try_ai_profile(request, ai_provider)
        if generated is not None:
            return OccasionResolveResponse(
                query=request.query,
                profile=generated,
                match_type="generated",
                confidence=0.72,
                cached=False,
                alternatives=[],
                warning=(
                    "Generated by AI. Review the suggested formality "
                    "before continuing."
                ),
                request_id=request.request_id,
            )

    return OccasionResolveResponse(
        query=request.query,
        profile=_fallback_profile(request),
        match_type="fallback",
        confidence=0.35,
        cached=False,
        alternatives=[],
        warning=(
            "No confident local occasion match was found. "
            "A general fallback strategy is in use."
        ),
        request_id=request.request_id,
    )


AI_OCCASION_SYSTEM_PROMPT = """
You resolve an occasion description into a wearable outfit policy.
Return one JSON object and no markdown.
Infer social context rather than defaulting unfamiliar social events to business.
All user-facing strings, including name, description, style_keywords, avoid_rules,
and explanation_guidelines, must be natural English.
The JSON object must contain exactly these fields:
id, name, description, aliases, target_formality, allowed_formality,
required_slots, style_keywords, avoid_rules, explanation_guidelines.
formality values are casual, smart_casual, business, or formal.
required_slots may contain top, bottom, outerwear, shoes, or accessory.
Always require top, bottom, and shoes.
Use a short lowercase hyphenated id beginning with generated-.
Do not return reasoning or commentary outside JSON.
""".strip()


def _try_ai_profile(
    request: OccasionResolveRequest,
    ai_provider: TextAIProvider,
) -> Optional[OccasionPreset]:
    try:
        result = ai_provider.complete_json(
            system_prompt=AI_OCCASION_SYSTEM_PROMPT,
            payload={
                "query": request.query,
                "locale": request.locale,
                "formality_hint": (
                    request.formality_hint.value
                    if request.formality_hint is not None
                    else None
                ),
            },
            request_id=request.request_id or "occasion-unmatched",
        )
        raw_profile = result.get("profile", result)
        if not isinstance(raw_profile, dict):
            return None
        payload = dict(raw_profile)
        payload["source"] = "generated"
        payload["version"] = 1
        payload["generated_at"] = datetime.now(timezone.utc)
        profile = OccasionPreset.model_validate(payload)
    except (
        TextAIProviderError,
        TypeError,
        ValueError,
    ):
        return None

    if "top" not in profile.required_slots or "bottom" not in profile.required_slots:
        return None
    if "shoes" not in profile.required_slots:
        return None
    if profile.target_formality not in profile.allowed_formality:
        return None
    if not profile.style_keywords or not profile.avoid_rules:
        return None
    return profile
