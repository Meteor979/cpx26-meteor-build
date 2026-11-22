from typing import Optional

from fastapi import APIRouter, Depends, Query, Response

from app.data.mock_data import PRESET_VERSION
from app.models import (
    OccasionResolveRequest,
    OccasionResolveResponse,
    PresetListResponse,
)
from app.services.occasion_matcher import list_presets, resolve_occasion
from app.services.text_ai import get_text_ai_provider

router = APIRouter()


@router.get(
    "/v1/presets",
    response_model=PresetListResponse,
    responses={304: {"description": "Preset version has not changed"}},
    tags=["Presets"],
)
def get_presets(
    version: Optional[int] = Query(default=None, ge=1),
    q: Optional[str] = Query(default=None, min_length=1, max_length=120),
    limit: int = Query(default=8, ge=1, le=20),
) -> PresetListResponse:
    if version == PRESET_VERSION:
        return Response(status_code=304)
    return list_presets(q, limit)


@router.post(
    "/v1/occasions/resolve",
    response_model=OccasionResolveResponse,
    tags=["Occasions"],
)
def post_occasion_resolve(
    request: OccasionResolveRequest,
    ai_provider=Depends(get_text_ai_provider),
) -> OccasionResolveResponse:
    return resolve_occasion(request, ai_provider=ai_provider)
