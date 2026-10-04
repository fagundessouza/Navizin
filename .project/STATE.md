# STATE — Navizin (checkpoint mestre)

> Arquivo de contexto. Ao iniciar uma sessão nova, diga **"Carregar checkpoint"** e leia só este arquivo.
> Ao final de cada sessão ou marco, diga **"Salvar checkpoint"** para atualizá-lo.

## Módulo atual
Setup inicial do repositório (estrutura, infra local e pipeline de sprites).

## Última ação executada
- Estrutura de diretórios e arquivos base criada em `~/navizin`.
- Sprites do **Holandês Voador** (spritesheet 6 frames 160×160 + frames individuais) copiados para `client/assets/sprites/ships/holandes_voador/`.
- Git inicializado localmente (sem commits).

## Próximos passos imediatos
1. Instalar **Podman**, **podman-compose** e **gh** (exigem sudo; ver seção "Comandos pendentes").
2. Subir a infraestrutura com `make up` e validar as portas 5432, 6379, 9000/9001, 16686 e 9090.
3. Criar a primeira migration do Alembic (`server/alembic`).
4. Abrir `client/` no Godot 4 e validar o `project.godot`.
5. Criar as issues iniciais (EPIC de navegação, EPIC de pipeline de sprites) com `scripts/gh_setup.sh`, após confirmação.

## Decisões de arquitetura tomadas
- Cliente: Godot 4.x (GDScript). C# fica para casos de performance comprovados.
- Backend: FastAPI + SQLAlchemy/Alembic, PostgreSQL 16, Redis 7.
- Assets: MinIO (S3) como fonte; o repositório guarda só os sprites finais usados pelo cliente.
- Containers com Podman/podman-compose; o `docker-compose.yml` é compatível com ambos.
- Pipeline de sprites: SDXL (`pixel-art-xl`), VAE em fp32, UNet em fp8, 768 px, pixelização 768 → 192 → 768 e redução final para 160 px com vizinho mais próximo.
- Git: GitFlow (`main`, `develop`, `feature/*`, `release/*`, `hotfix/*`).

## Comandos pendentes
- `sudo apt install podman podman-compose` (não instalado nesta máquina).
- Instalar `gh` e rodar `gh auth login`.
- Instalar Godot 4.x.

## Issue / card em andamento
- Nenhuma issue criada ainda no GitHub.
