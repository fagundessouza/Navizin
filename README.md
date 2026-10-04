# Navizin

MMORPG 2D/2.5D com temática naval, em pixel art. Cliente em **Godot 4**, servidor em **FastAPI**.

## Pré-requisitos
- Podman e podman-compose (ou Docker Compose)
- Python 3.12+
- Godot 4.x (para o cliente)
- Make

## Subir o ambiente em um comando

```bash
make up              # cria o .env e sobe PostgreSQL, Redis, MinIO, Jaeger e Prometheus
make server-install  # cria a venv e instala as dependências da API
make server-run      # sobe a API em http://localhost:8000
```

Serviços após `make up`:

| Serviço    | Endereço                | Uso                         |
|------------|-------------------------|-----------------------------|
| PostgreSQL | localhost:5432          | banco de dados              |
| Redis      | localhost:6379          | cache e sessão              |
| MinIO API  | localhost:9000          | armazenamento S3            |
| MinIO UI   | http://localhost:9001   | console do MinIO            |
| Jaeger UI  | http://localhost:16686  | traces                      |
| Prometheus | http://localhost:9090   | métricas                    |

Verificar a API: `curl http://localhost:8000/health`.

## Estrutura
```
client/     Projeto Godot 4 (cena, scripts, assets)
server/     API FastAPI, migrations e testes
infra/      Configurações de Prometheus, Grafana e Jaeger
scripts/    Automações do GitHub (issues, labels, projeto)
.project/   Contexto do projeto (STATE, ARCHITECTURE, SPRITE_PIPELINE)
```

Detalhes da arquitetura em [`.project/ARCHITECTURE.md`](.project/ARCHITECTURE.md).
Pipeline de sprites em [`.project/SPRITE_PIPELINE.md`](.project/SPRITE_PIPELINE.md).

## Testes
```bash
make server-test
```

## Fluxo de trabalho
Usamos **GitFlow**: `main` (produção), `develop` (integração), `feature/*`, `release/*`, `hotfix/*`.
Commits seguem Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`).
