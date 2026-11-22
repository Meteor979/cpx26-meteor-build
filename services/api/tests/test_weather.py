import json
from pathlib import Path
from typing import Dict

from fastapi.testclient import TestClient

from app.main import app
from app.models import WeatherRequest
from app.services.weather import (
    WeatherProviderError,
    get_current_weather,
)

client = TestClient(app)


def _request() -> Dict[str, object]:
    return {
        "request_id": "req-weather-unit-001",
        "latitude": 31.23,
        "longitude": 121.47,
        "accuracy_m": 1200,
        "timezone": "Asia/Shanghai",
        "target_at": None,
    }


def test_weather_returns_mock_context() -> None:
    response = client.post("/v1/weather/current", json=_request())

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["source"] == "mock"
    assert body["cached"] is False
    assert body["request_id"] == "req-weather-unit-001"
    assert body["location_label"] == "Shanghai"
    assert body["weather"] == {
        "temperature_c": 16,
        "feels_like_c": 15,
        "condition": "partly_cloudy",
        "precipitation_probability": 0.2,
        "wind_speed_kph": 12,
    }


def test_weather_response_does_not_echo_coordinates() -> None:
    response = client.post("/v1/weather/current", json=_request())
    serialized = json.dumps(response.json()).lower()

    assert "latitude" not in serialized
    assert "longitude" not in serialized
    assert "31.23" not in serialized
    assert "121.47" not in serialized


def test_recommendation_weather_data_has_required_fields() -> None:
    response = client.post("/v1/weather/current", json=_request())
    body = response.json()

    assert set(body) >= {
        "status",
        "location_label",
        "weather",
        "observed_at",
        "timezone",
        "cached",
        "source",
        "warning",
        "request_id",
    }
    assert set(body["weather"]) >= {
        "temperature_c",
        "feels_like_c",
        "condition",
        "precipitation_probability",
    }


def test_unknown_location_gets_neutral_label() -> None:
    payload = _request()
    payload["latitude"] = 0
    payload["longitude"] = 0

    response = client.post("/v1/weather/current", json=payload)

    assert response.status_code == 200
    assert response.json()["location_label"] == "Demo location"


def test_weather_validates_latitude() -> None:
    payload = _request()
    payload["latitude"] = 91

    response = client.post("/v1/weather/current", json=payload)

    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


def test_weather_validates_longitude() -> None:
    payload = _request()
    payload["longitude"] = -181

    response = client.post("/v1/weather/current", json=payload)

    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


def test_weather_requires_request_id_and_timezone() -> None:
    missing_request_id = _request()
    del missing_request_id["request_id"]

    response = client.post(
        "/v1/weather/current",
        json=missing_request_id,
    )
    assert response.status_code == 422

    missing_timezone = _request()
    del missing_timezone["timezone"]

    response = client.post(
        "/v1/weather/current",
        json=missing_timezone,
    )
    assert response.status_code == 422


class FailingWeatherProvider:
    def current(self, request: WeatherRequest):
        raise WeatherProviderError("provider failed")


def test_provider_failure_returns_explicit_fallback() -> None:
    request = WeatherRequest(**_request())

    response = get_current_weather(
        request,
        provider=FailingWeatherProvider(),
    )

    assert response.status == "unavailable"
    assert response.weather is None
    assert response.source == "fallback"
    assert response.cached is False
    assert response.request_id == request.request_id
    assert response.warning


def test_weather_matches_sample_contract_shape() -> None:
    root = Path(__file__).resolve().parents[3]
    sample = json.loads(
        (root / "specs" / "examples" / "sample-data.json").read_text(
            encoding="utf-8"
        )
    )
    expected = sample["weather_example"]["response"]

    response = client.post("/v1/weather/current", json=_request())
    body = response.json()

    assert set(body) == set(expected)
    assert set(body["weather"]) == set(expected["weather"])
