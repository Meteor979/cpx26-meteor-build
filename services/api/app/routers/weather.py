from fastapi import APIRouter

from app.models import WeatherRequest, WeatherResponse
from app.services.weather import get_current_weather

router = APIRouter(tags=["Weather"])


@router.post(
    "/v1/weather/current",
    response_model=WeatherResponse,
)
def post_current_weather(request: WeatherRequest) -> WeatherResponse:
    return get_current_weather(request)
