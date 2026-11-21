from fastapi import FastAPI

from app.routers import system

app = FastAPI(
    title="WearWise API",
    version="0.4.0",
    description="WearWise backend service.",
)
app.include_router(system.router)
