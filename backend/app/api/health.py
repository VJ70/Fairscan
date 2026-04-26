from fastapi import APIRouter
from app.models.schemas import HealthResponse

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
async def health_check():
    return HealthResponse(status="ok", version="1.0.0")


@router.get("/")
async def root():
    return {
        "name": "FairScan API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
    }
