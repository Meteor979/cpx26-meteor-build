from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter

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

router = APIRouter(tags=["Recommendations"])


@router.post(
    "/v1/recommendations",
    response_model=RecommendationResponse,
)
def post_recommendations(
    request: RecommendationRequest,
) -> RecommendationResponse:
    return create_recommendations(request)


@router.post(
    "/v1/outfits/revise",
    response_model=OutfitRevisionResponse,
)
def post_outfit_revision(
    request: OutfitRevisionRequest,
) -> OutfitRevisionResponse:
    outfit = revise_outfit(request)
    return OutfitRevisionResponse(
        outfit=outfit,
        fallback_used=True,
        warning=RULE_WARNING,
        provider=RULE_PROVIDER,
        generated_at=datetime.now(timezone.utc),
        request_id=request.request_id or "req-%s" % uuid4().hex[:12],
    )
