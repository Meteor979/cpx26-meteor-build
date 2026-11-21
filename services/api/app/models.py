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
