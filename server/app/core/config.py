"""Configuração da aplicação.

Os valores vêm de variáveis de ambiente (ou do arquivo `.env` na raiz do projeto).
Nunca escreva segredos neste arquivo: ele é versionado.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Todas as configurações do servidor, tipadas e com valores padrão seguros para dev."""

    model_config = SettingsConfigDict(env_file="../.env", extra="ignore")

    app_name: str = "Navizin API"
    environment: str = "development"
    database_url: str = "postgresql+psycopg://navizin:navizin_dev@localhost:5432/navizin"
    redis_url: str = "redis://localhost:6379/0"


@lru_cache
def get_settings() -> Settings:
    """Retorna uma única instância de Settings (cacheada para não reler o arquivo a cada chamada)."""
    return Settings()
