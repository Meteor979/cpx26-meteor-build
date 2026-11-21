from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field


class ProviderStatus(BaseModel):
    name: str
    mode: str
    available: bool
    latency_ms: Optional[int] = Field(default=None, ge=0)


class HealthResponse(BaseModel):
    status: Literal["ok", "degraded", "down"]
    timestamp: datetime
    providers: List[ProviderStatus]
