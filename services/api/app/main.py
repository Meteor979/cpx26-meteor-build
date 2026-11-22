import json
from typing import Any, Optional

from fastapi import FastAPI
from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.errors import ApiError
from app.routers import context, recommendations, system, weather

app = FastAPI(
    title="WearWise API",
    version="0.4.0",
    description="WearWise backend service.",
)
app.include_router(system.router)
app.include_router(context.router)
app.include_router(recommendations.router)
app.include_router(weather.router)


def _request_id_from_body(body: Any) -> Optional[str]:
    if isinstance(body, dict) and isinstance(body.get("request_id"), str):
        return body["request_id"]
    return None


@app.exception_handler(ApiError)
async def handle_api_error(_: Request, exc: ApiError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "code": exc.code,
            "message": exc.message,
            "details": exc.details,
        },
    )


@app.exception_handler(RequestValidationError)
async def handle_validation_error(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    try:
        body = json.loads(await request.body())
    except (UnicodeDecodeError, json.JSONDecodeError):
        body = None

    errors = [
        {
            "field": ".".join(str(part) for part in error["loc"]),
            "message": error["msg"],
            "type": error["type"],
        }
        for error in exc.errors()
    ]
    return JSONResponse(
        status_code=422,
        content={
            "code": "VALIDATION_ERROR",
            "message": "Request fields do not match the API contract.",
            "request_id": _request_id_from_body(body),
            "details": {"errors": errors},
        },
    )
