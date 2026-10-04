# STATE — Navizin (checkpoint mestre)

> Arquivo de contexto. Ao iniciar uma sessão nova, diga **"Carregar checkpoint"** e leia só este arquivo.
> Ao final de cada sessão ou marco, diga **"Salvar checkpoint"** para atualizá-lo.

## Módulo atual
Setup inicial concluído: GitFlow no GitHub, labels, Kanban com issues iniciais e primeira cena do cliente (mar + navio + câmera), validada no Godot 4.7.2.

## Última ação executada
- Primeiro commit em `develop`: `feat: initial repository structure, architecture docs and stack setup` (`7dd3b91`).
- Branches reestruturadas para o padrão enxuto: `develop` renomeada para `dev` (local e remota, `develop` apagada no `origin`), definida como branch padrão do GitHub. `main` segue em `7dd3b91`, a base inicial, e só deve receber merges de `dev` quando houver uma versão para produção. CI (`.github/workflows/ci.yml`) e README atualizados para `dev`.
- Sprites do **Holandês Voador** validados: 6 frames 160×160 RGBA, sheet 960×160 idêntico aos frames, sem resíduo de chroma key (verde máximo 177 de 255). Fundo transparente.
- Cliente Godot:
  - `client/assets/shaders/ocean.gdshader`: mar procedural em coordenadas de mundo (sem costura, sem textura).
  - `client/scenes/world/ocean_map.tscn`: `Ocean` (ColorRect 20000×20000 com o shader) + `Ship` (instância de `ship_base.tscn`) + `Camera2D` filha do navio com `position_smoothing_enabled = true`.
  - `client/scenes/entities/ship_base.tscn`: `ShipBase` (Node2D) com `Sprite2D` apontando para o spritesheet do Holandês Voador.
  - `client/scripts/entities/ship_base.gd`: anima as velas (`hframes = frame_count`, troca de frame por `animation_fps`).
- **Validado no Godot 4.7.2** (`~/.local/bin/godot4`): importação sem erros, cena principal roda sem erros/avisos, `ocean_map.tscn` instancia com o sprite (6 frames, sheet 960×160) e a câmera com suavização ligada.
- GitHub: `gh` autenticado (conta `fagundessouza`, protocolo SSH, escopo `project`).
  - Labels `epic`, `feature`, `asset`, `infra` e `bug` aplicadas via `scripts/gh_setup.sh`.
  - Projeto Kanban **Navizin** (nº 4, https://github.com/users/fagundessouza/projects/4), vinculado ao repositório.
  - Issues iniciais no projeto: #1 EPIC Navegação e mar, #2 EPIC Pipeline de sprites, #3 EPIC Infraestrutura local, #4 Movimentação básica do navio do jogador, #5 Gerar direções do Holandês Voador (8 sentidos).
- Estrutura de assets conferida: `assets/sprites/{ships,environment,ui}`, `assets/shaders`, `assets/audio`, `assets/fonts`.

## Próximos passos imediatos
1. Implementar a issue #4: movimentação do navio do jogador (script de movimento sobre `ship_base.gd`, câmera já presa ao navio).
2. Instalar **Podman**, **podman-compose** e subir a infraestrutura com `make up`, validando as portas 5432, 6379, 9000/9001, 16686 e 9090 (issue #3).
3. Criar a primeira migration do Alembic (`server/alembic`), também na issue #3.
4. Gerar as direções do Holandês Voador (issue #5).

## Decisões de arquitetura tomadas
- Cliente: Godot 4.x (GDScript). C# fica para casos de performance comprovados.
- Backend: FastAPI + SQLAlchemy/Alembic, PostgreSQL 16, Redis 7.
- Assets: MinIO (S3) como fonte; o repositório guarda só os sprites finais usados pelo cliente.
- Containers com Podman/podman-compose; o `docker-compose.yml` é compatível com ambos.
- Pipeline de sprites: SDXL (`pixel-art-xl`), VAE em fp32, UNet em fp8, 768 px, pixelização 768 → 192 → 768 e redução final para 160 px com vizinho mais próximo.
- Mar: shader procedural em vez de TileMap ou textura, porque é contínuo em qualquer tamanho de tela e não precisa de asset.
- Câmera: `Camera2D` fica como filha do navio do jogador no mapa, e não dentro de `ship_base.tscn`, para que NPCs não ganhem câmera.
- Git (fluxo enxuto): `main` é produção; `dev` é integração e branch padrão de trabalho; `feature/*` saem de `dev` e voltam para `dev`; `hotfix/*` saem de `main` e voltam para `main` e `dev`. Sem `release/*` por enquanto.

## Comandos pendentes
- `sudo apt install podman podman-compose` (não instalado nesta máquina).
- Godot 4.7.2 em `~/.local/bin/godot4` (fora do PATH padrão; o `project.godot` declara 4.3).

## Issues / cards em andamento
- Projeto Kanban criado. Nenhum card em andamento ainda: todas as 5 issues iniciais estão no backlog.
