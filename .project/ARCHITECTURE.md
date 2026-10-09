# ARCHITECTURE — Navizin

MMORPG 2D/2.5D naval em pixel art, Godot 4 no cliente e FastAPI no servidor.

## Visão geral

```
 ┌──────────────┐   HTTP/WebSocket    ┌──────────────────┐
 │ client/      │ ──────────────────▶ │ server/ (FastAPI)│
 │ Godot 4      │                     │ API + regras     │
 └──────────────┘                     └───────┬──────────┘
        ▲                                     │
        │ sprites (URL)                       ├──▶ PostgreSQL  (dados persistentes, Alembic)
        │                                     ├──▶ Redis       (sessão, cache, filas)
 ┌──────┴───────┐                             ├──▶ Qdrant      (futuro: RAG / lore de NPCs)
 │ MinIO (S3)   │◀──── pipeline de assets     └──▶ n8n         (automações)
 └──────────────┘
        ▲
        │ telemetria
 ┌──────┴────────────────────────────┐
 │ Jaeger (traces) · Prometheus      │──▶ Grafana
 └───────────────────────────────────┘
```

## Módulos do repositório
| Caminho | Responsabilidade |
|---|---|
| `client/` | Projeto Godot: cenas, scripts, assets. |
| `client/scripts/autoload/` | Singletons globais (`GameManager`, `NetworkClient`). |
| `server/app/api/` | Rotas HTTP. Só valida entrada e chama serviços. |
| `server/app/services/` | Regras de negócio. Não conhece HTTP. |
| `server/app/models/` | Modelos ORM e schemas. |
| `server/app/core/` | Configuração, conexões e utilidades transversais. |
| `server/alembic/` | Migrations do PostgreSQL. |
| `infra/` | Configs de Prometheus, Grafana e Jaeger. |
| `scripts/` | Automações locais (criação de issues e labels no GitHub). |

## Fluxo de dados (exemplo: mover um navio)
1. Cliente Godot envia a intenção de movimento ao `NetworkClient`.
2. A API valida a entrada (`api/`) e chama o serviço de movimento (`services/`).
3. O serviço lê o estado da sessão no Redis e grava o resultado no PostgreSQL.
4. O estado é devolvido ao cliente e o trace é enviado ao Jaeger.

## Cliente: cenas do mundo (navegação vs. cidade)
Separação estrita, decidida em 2026-10-09 (detalhes e estado da migração em `STATE.md`):
- `ocean_map.tscn` — só navegação e física do oceano. Não acumula props/ilustração de cidade.
- Ao atracar, o jogo transiciona para uma cena dedicada por porto (ex. `TownHub.tscn`), e não um overlay de `Control` sobre o mapa do oceano. O navio "entra" no porto e some da cena do oceano.
- A cena de cidade carrega a ilustração interativa com hotspots clicáveis e placas (estilo Seafight/MonsterGame), abrindo modais de mercado/taverna/estaleiro por hotspot.
- Motivo: evitar que `ocean_map.tscn` vire um despejo de todo elemento gráfico de toda ilha/cidade do jogo.

## Convenções
- Python: tipagem completa, Ruff e pytest. Camadas `api → services → models`, sem atalhos.
- GDScript: tipagem estática (`var x: int`), um script por classe, sinais em vez de referências diretas.
- Commits: Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`).
