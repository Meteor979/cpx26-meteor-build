from datetime import datetime
from enum import Enum
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


class FormalityBand(str, Enum):
    CASUAL = "casual"
    SMART_CASUAL = "smart_casual"
    BUSINESS = "business"
    FORMAL = "formal"


class GarmentSlot(str, Enum):
    TOP = "top"
    BOTTOM = "bottom"
    OUTERWEAR = "outerwear"
    SHOES = "shoes"
    ACCESSORY = "accessory"


class ProviderStatus(BaseModel):
    name: str
    mode: str
    available: bool
    latency_ms: Optional[int] = Field(default=None, ge=0)


class HealthResponse(BaseModel):
    status: Literal["ok", "degraded", "down"]
    timestamp: datetime
    providers: List[ProviderStatus]


class OccasionPreset(BaseModel):
    id: str = Field(pattern=r"^[a-z0-9-]+$")
    name: str = Field(min_length=1)
    aliases: List[str] = Field(min_length=1)
    description: Optional[str] = None
    target_formality: FormalityBand
    allowed_formality: List[FormalityBand] = Field(min_length=1)
    required_slots: List[GarmentSlot] = Field(min_length=1)
    style_keywords: List[str]
    avoid_rules: List[str]
    explanation_guidelines: List[str]
    source: Literal["precomputed", "bundled", "generated", "fallback"]
    version: int = Field(ge=1)
    generated_at: Optional[datetime] = None


class PresetListResponse(BaseModel):
    version: int = Field(ge=1)
    cached: bool
    generated_at: Optional[datetime] = None
    presets: List[OccasionPreset]


class OccasionResolveRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    request_id: Optional[str] = Field(default=None, min_length=1, max_length=128)
    query: str = Field(min_length=1, max_length=240)
    locale: str = "zh-CN"
    formality_hint: Optional[FormalityBand] = None


class OccasionResolveResponse(BaseModel):
    query: str
    profile: OccasionPreset
    match_type: Literal["exact_preset", "semantic_match", "generated", "fallback"]
    confidence: float = Field(ge=0, le=1)
    cached: bool
    alternatives: List[OccasionPreset] = Field(max_length=5)
    warning: Optional[str] = None
    request_id: Optional[str] = None


class WeatherData(BaseModel):
    model_config = ConfigDict(extra="forbid")

    temperature_c: float = Field(ge=-60, le=60)
    feels_like_c: float = Field(ge=-70, le=70)
    condition: Literal[
        "clear",
        "partly_cloudy",
        "cloudy",
        "rain",
        "snow",
        "storm",
        "fog",
        "unknown",
    ]
    precipitation_probability: float = Field(ge=0, le=1)
    wind_speed_kph: Optional[float] = Field(default=None, ge=0)


class RecommendationGarment(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(min_length=1)
    brand: Optional[str] = None
    product_name: Optional[str] = None
    slot: GarmentSlot
    category: str = Field(min_length=1)
    colors: List[str] = Field(min_length=1)
    pattern: Optional[str] = None
    fit: Optional[str] = None
    material: Optional[str] = None
    formality_score: int = Field(ge=1, le=5)
    warmth_score: int = Field(ge=1, le=5)
    user_confirmed: Literal[True]


class RecommendationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    request_id: Optional[str] = Field(default=None, min_length=1, max_length=128)
    preset_id: Optional[str] = None
    occasion: str = Field(min_length=1)
    weather: WeatherData
    formality: FormalityBand
    garments: List[RecommendationGarment] = Field(min_length=1)


class OutfitRevisionRequest(RecommendationRequest):
    base_item_ids: List[str] = Field(min_length=2)
    replacement_item_id: str = Field(min_length=1)


class Outfit(BaseModel):
    id: str
    item_ids: List[str] = Field(min_length=2)
    title: str
    reasons: List[str] = Field(min_length=1)
    tradeoffs: List[str]
    source: Literal["mock", "remote_api", "fallback"]
    score: Optional[float] = None


class RecommendationResponse(BaseModel):
    outfits: List[Outfit] = Field(min_length=1, max_length=3)
    requested_count: Literal[3] = 3
    result_count_reason: Literal[
        "three_available",
        "limited_candidates",
        "fallback_degraded",
    ]
    fallback_used: bool
    warning: Optional[str]
    provider: Optional[str] = None
    generated_at: datetime
    request_id: Optional[str] = None


class OutfitRevisionResponse(BaseModel):
    outfit: Outfit
    fallback_used: bool
    warning: Optional[str]
    provider: Optional[str] = None
    generated_at: datetime
    request_id: Optional[str] = None
