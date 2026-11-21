from fastapi import APIRouter

from app.models import RecommendationRequest, RecommendationResponse
from app.services.recommendation_engine import recommend_outfits

router = APIRouter()


@router.post(
    "/v1/recommendations",
    response_model=RecommendationResponse,
    tags=["Recommendations"],
)
def create_recommendations(
    request: RecommendationRequest,
) -> RecommendationResponse:
    return recommend_outfits(request)
