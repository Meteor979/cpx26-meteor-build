from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ProviderStatus(BaseModel):
    name: str
    mode: str
    available: bool
    latency_ms: int | None = Field(default=None, ge=0)


class HealthResponse(BaseModel):
    status: Literal["ok", "degraded", "down"]
    timestamp: datetime
    providers: list[ProviderStatus]
