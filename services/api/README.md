# WearWise Backend

Backend service for WearWise. The current milestone implements only the
contract-defined `GET /health` endpoint and does not call external AI, weather,
or search services.

## Requirements

- Python 3
- Windows PowerShell

## Setup and tests

```powershell
cd services/api
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m pytest -q
```

## Run locally

```powershell
python -m uvicorn app.main:app --reload --port 8000
```

In another terminal:

```powershell
curl.exe http://127.0.0.1:8000/health
```

OpenAPI documentation is available at <http://127.0.0.1:8000/docs>.

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

Do not commit `.env`, credentials, recordings, personal photos, or generated
build output.
