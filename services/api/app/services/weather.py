from dataclasses import dataclass
from datetime import datetime, timezone
from math import asin, cos, radians, sin, sqrt
from typing import List, Optional, Protocol, Tuple

from app.models import (
    WeatherData,
    WeatherRequest,
    WeatherResponse,
)


@dataclass(frozen=True)
class WeatherSnapshot:
    location_label: str
    weather: WeatherData
    observed_at: datetime


class WeatherProviderError(Exception):
    """Raised when a weather provider cannot return usable data."""


class WeatherProvider(Protocol):
    def current(self, request: WeatherRequest) -> WeatherSnapshot:
        ...


class MockWeatherProvider:
    def current(self, request: WeatherRequest) -> WeatherSnapshot:
        return WeatherSnapshot(
            location_label=_nearest_location_label(
                request.latitude,
                request.longitude,
            ),
            weather=WeatherData(
                temperature_c=16,
                feels_like_c=15,
                condition="partly_cloudy",
                precipitation_probability=0.2,
                wind_speed_kph=12,
            ),
            observed_at=datetime.now(timezone.utc),
        )


KNOWN_LOCATIONS: List[Tuple[str, float, float]] = [
    ("Shanghai", 31.23, 121.47),
    ("Suzhou", 31.30, 120.62),
    ("Kunshan", 31.39, 120.98),
    ("Beijing", 39.90, 116.40),
    ("Shenzhen", 22.54, 114.06),
    ("Guangzhou", 23.13, 113.26),
    ("Hangzhou", 30.27, 120.15),
    ("Nanjing", 32.06, 118.80),
]

MAX_LOCATION_LABEL_DISTANCE_KM = 120.0


def _haversine_km(
    latitude_a: float,
    longitude_a: float,
    latitude_b: float,
    longitude_b: float,
) -> float:
    earth_radius_km = 6371.0
    lat_a = radians(latitude_a)
    lat_b = radians(latitude_b)
    delta_lat = radians(latitude_b - latitude_a)
    delta_lon = radians(longitude_b - longitude_a)
    value = (
        sin(delta_lat / 2) ** 2
        + cos(lat_a) * cos(lat_b) * sin(delta_lon / 2) ** 2
    )
    return 2 * earth_radius_km * asin(sqrt(value))


def _nearest_location_label(latitude: float, longitude: float) -> str:
    nearest = min(
        KNOWN_LOCATIONS,
        key=lambda item: _haversine_km(
            latitude,
            longitude,
            item[1],
            item[2],
        ),
    )
    distance = _haversine_km(latitude, longitude, nearest[1], nearest[2])
    if distance <= MAX_LOCATION_LABEL_DISTANCE_KM:
        return nearest[0]
    return "Demo location"


def get_current_weather(
    request: WeatherRequest,
    provider: Optional[WeatherProvider] = None,
) -> WeatherResponse:
    active_provider = provider or MockWeatherProvider()
    try:
        snapshot = active_provider.current(request)
    except WeatherProviderError:
        return WeatherResponse(
            status="unavailable",
            location_label=None,
            weather=None,
            observed_at=None,
            timezone=request.timezone,
            cached=False,
            source="fallback",
            warning="Weather data is unavailable. Use demo weather to continue.",
            request_id=request.request_id,
        )

    return WeatherResponse(
        status="ok",
        location_label=snapshot.location_label,
        weather=snapshot.weather,
        observed_at=snapshot.observed_at,
        timezone=request.timezone,
        cached=False,
        source="mock",
        warning="Demo weather is in use; no live weather provider is configured.",
        request_id=request.request_id,
    )
