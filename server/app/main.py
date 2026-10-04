"""Ponto de entrada da API FastAPI.

Execute em desenvolvimento com `make server-run` (ou `uvicorn app.main:app --reload`).
"""

from fastapi import FastAPI

from app.api import health
from app.core.config import get_settings

settings = get_settings()

app = FastAPI(title=settings.app_name, version="0.1.0")
app.include_router(health.router)
