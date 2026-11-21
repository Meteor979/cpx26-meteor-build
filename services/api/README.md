# WearWise Backend

Backend service for WearWise. The current milestone implements health, occasion
context, rule-based recommendation, and outfit revision with deterministic Mock
data. It does not call external AI, weather, or search services.

## Requirements

- Python 3.9+
- Windows PowerShell
- macOS/Linux shell

## Windows setup and tests

```powershell
cd services/api
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m pytest -q
```

## macOS/Linux setup and tests

```bash
cd services/api
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python -m pytest -q
```

## Run locally on Windows

```powershell
python -m uvicorn app.main:app --reload --port 8000
```

In another terminal:

```powershell
curl.exe http://127.0.0.1:8000/health
```

## Run locally on macOS/Linux

```bash
python -m uvicorn app.main:app --reload --port 8000
curl http://127.0.0.1:8000/health
```

OpenAPI documentation is available at <http://127.0.0.1:8000/docs>.

## Python compatibility

The backend supports Python 3.9 and newer. Do not use Python 3.10-only syntax
such as `X | None`, `int | None`, or union expressions in public models. Use
`Optional`, `List`, `Dict`, and `Tuple` from `typing` instead. Recreate the
virtual environment after changing the Python version.

## Current endpoint

`GET /health` returns:

```json
{
  "status": "ok",
  "timestamp": "2026-11-21T10:00:00Z",
  "providers": []
}
```

The response schema follows [`specs/openapi.yaml`](../../specs/openapi.yaml).
No API keys or `.env` file are required for this milestone.

## Context Mock endpoints

```powershell
curl.exe -i "http://127.0.0.1:8000/v1/presets?limit=4"

curl.exe -i -X POST "http://127.0.0.1:8000/v1/occasions/resolve" `
  -H "Content-Type: application/json" `
  -d '{"query":"第一次约会","locale":"zh-CN"}'
```

The presets endpoint returns the four fixed policies from
`specs/examples/sample-data.json`. The occasion resolver performs local
normalization, exact name/alias matching, and deterministic keyword matching.
Unknown queries receive a low-confidence fixed fallback.

## Recommendation Mock endpoints

```powershell
curl.exe -i -X POST "http://127.0.0.1:8000/v1/recommendations" `
  -H "Content-Type: application/json" `
  --data-binary "@examples/recommendation-rule-request.json"

curl.exe -i -X POST "http://127.0.0.1:8000/v1/outfits/revise" `
  -H "Content-Type: application/json" `
  --data-binary "@examples/outfit-revision-rule-request.json"
```

The recommendation endpoints return deterministic rules with
`provider=rule_engine_mock`, `fallback_used=true`, and an explicit warning. They
return only stable garment IDs and never include local photo paths or image URLs.

Do not commit `.env`, credentials, recordings, personal photos, or generated
build output.
