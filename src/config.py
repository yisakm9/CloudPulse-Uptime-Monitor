# ──────────────────────────────────────────────────────────────
# CloudPulse — Application Configuration
# ──────────────────────────────────────────────────────────────

import os
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.
    Cloud Run injects these from the Terraform configuration
    and Secret Manager.
    """

    # ─── Application ──────────────────────────────────────────
    app_name: str = "CloudPulse"
    app_env: str = "development"
    debug: bool = False

    # ─── Database ─────────────────────────────────────────────
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "cloudpulse"
    db_user: str = "cloudpulse_user"
    db_password: str = ""

    # ─── Worker ───────────────────────────────────────────────
    check_interval_seconds: int = 300   # 5 minutes default
    check_timeout_seconds: int = 10     # HTTP request timeout
    max_concurrent_checks: int = 20     # Max parallel checks

    @property
    def database_url(self) -> str:
        """Construct the PostgreSQL connection string."""
        return (
            f"postgresql://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )

    class Config:
        env_file = ".env"
        case_sensitive = False


# Singleton settings instance
settings = Settings()
