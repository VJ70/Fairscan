from pydantic_settings import BaseSettings
from pydantic import field_validator
from typing import List


class Settings(BaseSettings):
    GCP_PROJECT: str = "fairscan-2026"
    GEMINI_API_KEY: str = ""
    VERTEX_AI_LOCATION: str = "asia-south1"
    FIREBASE_SERVICE_ACCOUNT: str = ""
    ALLOWED_ORIGINS: str = "http://localhost:3000,https://fairscan.web.app"
    MAX_FILE_SIZE_MB: int = 50
    BIGQUERY_DATASET: str = "fairscan_analytics"

    @property
    def allowed_origins_list(self) -> List[str]:
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",") if o.strip()]

    class Config:
        env_file = ".env"


settings = Settings()
