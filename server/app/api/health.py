"""Rota de saúde: confirma que a API está no ar. Usada por balanceadores e monitoramento."""

from fastapi import APIRouter

router = APIRouter(tags=["saúde"])


@router.get("/health", summary="Estado da API")
def health() -> dict[str, str]:
    """Retorna `{"status": "ok"}` enquanto o processo estiver respondendo."""
    return {"status": "ok"}
