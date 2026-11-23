from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends

from app.models import (
    OutfitRevisionRequest,
    OutfitRevisionResponse,
    RecommendationRequest,
    RecommendationResponse,
)
from app.services.recommendation_rules import (
    RULE_PROVIDER,
    RULE_WARNING,
    create_recommendations,
    revise_outfit,
)
from app.services.text_ai import get_text_ai_provider

router = APIRouter(tags=["Recommendations"])


@router.post(
    "/v1/recommendations",
    response_model=RecommendationResponse,
)
def post_recommendations(
    request: RecommendationRequest,
    ai_provider=Depends(get_text_ai_provider),
) -> RecommendationResponse:
    return create_recommendations(request, ai_provider=ai_provider)


@router.post(
    "/v1/outfits/revise",
    response_model=OutfitRevisionResponse,
)
def post_outfit_revision(
    request: OutfitRevisionRequest,
    ai_provider=Depends(get_text_ai_provider),
) -> OutfitRevisionResponse:
    outfit = revise_outfit(request, ai_provider=ai_provider)
    used_remote_ai = outfit.source == "remote_api" and ai_provider is not None
    return OutfitRevisionResponse(
        outfit=outfit,
        fallback_used=not used_remote_ai,
        warning=None if used_remote_ai else RULE_WARNING,
        provider=ai_provider.name if used_remote_ai else RULE_PROVIDER,
        generated_at=datetime.now(timezone.utc),
        request_id=request.request_id or "req-%s" % uuid4().hex[:12],
    )
