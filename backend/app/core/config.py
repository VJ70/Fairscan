from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    GCP_PROJECT: str = "fairscan-2026"
    GEMINI_API_KEY: str = ""
    VERTEX_AI_LOCATION: str = "asia-south1"
    FIREBASE_SERVICE_ACCOUNT: str = ""
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000", "https://fairscan.web.app"]
    MAX_FILE_SIZE_MB: int = 50
    BIGQUERY_DATASET: str = "fairscan_analytics"

    class Config:
        env_file = ".env"


settings = Settings()
