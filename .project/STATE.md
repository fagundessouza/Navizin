# STATE — Navizin (checkpoint mestre)

> Arquivo de contexto. Ao iniciar uma sessão nova, diga **"Carregar checkpoint"** e leia só este arquivo.
> Ao final de cada sessão ou marco, diga **"Salvar checkpoint"** para atualizá-lo.

## Módulo atual
Módulo 1 (movimentação, vento/maré, inércia, visual do navio e disparo lateral com carga de força) implementado na branch `feature/issue-4-ship-movement`. A issue #4 é coberta por esse trabalho. Aguardando PR para `dev`.

## Branch de trabalho atual
`feature/issue-4-ship-movement`, criada a partir de `dev`.

Commits, em ordem:
- `ac3c353` feat(client): add ship movement with acceleration, drag and smooth turning
- `a6436db` feat(client): make the map's ship player-controlled
- `b42e3f9` docs: update STATE checkpoint for issue #4 ship movement
- `6dfb99f` feat(client): add input actions for sails, skills and primary click
- `bef463f` feat(client): hybrid mouse aim, naval sail levels and skill signals
- `9f177e4` docs: save STATE checkpoint for hybrid ship control
- `92be1c7` feat(client): add seven-direction Dutchman sprites, drop old sheet
- `a5bca63` feat(client): add ShipData, broadside charge, recoil, shake and wake
- `73e5b01` chore(client): enable 2D pixel snap; keep editor-saved project file

## Sprite do Holandês Voador
- Fonte: `client/assets/sprites/ships/holandes_voador/holandes_voador_directions.png` (600×400). É uma folha 4×2 com 8 vistas e rótulos de texto. A vista "Fundo" foi removida.
- Recortes finais em `client/assets/sprites/ships/holandes_voador/dirs/`: `front`, `back`, `left`, `right`, `top`, `top_left`, `top_right`. Todos em canvas 176×178, com pivô no centro.
- Proa: `left` aponta para a direita; `right` aponta para a esquerda; as diagonais de cima foram medidas pelo perfil de largura da proa (`top_left` aponta para baixo-direita, `top_right` para baixo-esquerda).
- Filtro: Nearest no `Sprite2D` e no projeto (`default_texture_filter=0`). Pixel snap ligado em `project.godot`.
- Alfa: o fundo é 0. O navio tem alfa 254 em quase todos os pixels, quase opaco. Não foi necessário binarizar.
- Não versionado: `holandes_voador_base.png` (cópia da imagem de 600×600, sem uso desde a troca para 7 direções). Pode ser removido.
- Removidos do repositório: `holandes_voador_sheet.png` (6 frames 960×160) e seu `.import`. Não foi decisão da IA: o arquivo foi apagado no working tree antes da troca. A cena já não o usa.

## Controle e disparo do navio do jogador
Lógica em `client/scripts/entities/ship_base.gd`, dados em `client/scripts/resources/ship_data.gd` (`ShipData`, com instância em `client/data/ship_holandes_voador.tres`).

- **Mira:** a proa segue o ponteiro do mouse com suavização (`aim_responsiveness`, `turn_acceleration`). Zona morta de `aim_deadzone`. **O leme trava enquanto o botão de tiro está segurado**, para que o cursor possa ir para um dos lados do casco.
- **Velas:** `W`/`Cima` sobe e `S`/`Baixo` desce, em 4 níveis: ré, parado, meia e cheia. A velocidade tem inércia. Velocidades: `max_speed` 120, `half_speed` 60, `reverse_speed` 40.
- **Carga de peso:** `cargo_weight` reduz a velocidade máxima até a metade.
- **Vento e maré:** `ambient_flow` (definido em `ocean_map.gd`, 14, 5) empurra o navio com `wind_influence` 0.15.
- **Disparo:** segurar o botão esquerdo carrega `shot_power` de 0 a 1, em `charge_time` (1.5 s). O lado vem da posição do cursor em relação ao casco: esquerda = bombordo, direita = estibordo. Soltar dispara. A carga cheia dispara sozinha, e é preciso soltar para armar de novo.
- **Arco de mira:** alcance (`range_min` a `range_max`) e abertura (`spread_min` a `spread_max`) crescem com a força.
- **Bordada:** `cannon_count` projéteis (6) saem em sequência (`volley_interval`). A velocidade cresce com a força. Projéteis são `Cannonball`, placeholder sem colisão.
- **Recuo:** impulso oposto ao tiro, `recoil_strength` × força, amortecido por `recoil_damping`.
- **Tremor da câmera:** `shake_strength` × força, decai com `shake_decay`.
- **Esteira:** `GPUParticles2D` (`Wake`), sempre na popa. Fica no lado oposto ao movimento, inclusive em ré.
- **Sete direções:** o rumo escolhe o sprite (8 setores de 45°, `SECTORS`). O sprite não gira com o casco: o rumo aparece pela troca de vista. As diagonais de cima ficam com `modulate.a = 0.5`.
- **Teclas 1 a 4:** emitem `skill_triggered(skill_index)`. Ainda sem efeito, porque o sistema de habilidades não existe.
- **Sinais:** `primary_action_triggered(target)` e `broadside_fired(side, power)`.
- **Câmera:** a `Camera2D` é filha do navio do jogador, com suavização. A posição do cursor no mundo acompanha a câmera, e isso é o esperado.

## Validação
- **Godot 4.7.2 headless (`~/.local/bin/godot4`):**
  - Importação sem erros.
  - Cena principal roda sem erros.
  - Suíte de 35 verificações passa: sete direções e opacidade das diagonais, velas e inércia, carga de peso, lado da bateria pelo cursor, carga, disparo automático, bordada de 6 projéteis, recuo, tremor, velocidade pelo tipo de força, esteira, vento e NPC sem disparo.
- **Gráfica:** capturas feitas na tela real (`:0`, GL Compatibility, RX 6600). A vista lateral aparece nítida, e a diagonal de cima aparece com opacidade reduzida e arco de mira.
- Os testes e capturas ficam no scratchpad da sessão, fora do repositório.

## Decisões de design e pontos em aberto
- **Leme travado durante a carga:** a proa seguir o cursor sempre deixaria o cursor à frente, e o lado nunca seria definido. Por isso o leme trava com o botão segurado.
- **Mapeamento de direção pelo rumo:** a vista `top` (proa para cima) não é escolhida pelo rumo. Fica disponível para uso manual, como um modo de mapa. A issue #5 fala em 8 sentidos, mas o sprite tem 7 vistas.
- **Diagonais espelhadas:** as duas diagonais de cima usam o sprite espelhado nos dois eixos (rotação de 180°). Isso não tem custo de arte, mas não é exatamente a vista de cima do outro lado. Vale revisar com a arte.
- **Física:** a velocidade usa `move_toward`, e não `lerp` exponencial. O efeito é parecido, e o teste já cobre.
- **Sinal `primary_action_triggered`:** agora é emitido ao disparar a bordada, e não ao clicar.
- **Projeto no editor:** o Godot 4.7.2 reescreveu o `project.godot` ao abrir. As ações de entrada e as configurações foram mantidas.
- **Vento:** o efeito é um deslocamento constante. Não altera a velocidade de vela, como um vento de popa faria.

## Próximos passos imediatos
1. Subir `feature/issue-4-ship-movement` para `origin` e abrir o PR para `dev`. Fecha a issue #4 no merge.
2. Atualizar a issue #5 para 7 vistas, e não 8 sentidos.
3. Remover ou versionar `holandes_voador_base.png`.
4. Instalar **Podman**, **podman-compose** e subir a infraestrutura com `make up`, validando as portas 5432, 6379, 9000/9001, 16686 e 9090 (issue #3).
5. Criar a primeira migration do Alembic (`server/alembic`), também na issue #3.

## Decisões de arquitetura tomadas
- Cliente: Godot 4.x (GDScript). C# fica para casos de performance comprovados.
- Backend: FastAPI + SQLAlchemy/Alembic, PostgreSQL 16, Redis 7.
- Assets: MinIO (S3) como fonte; o repositório guarda só os sprites finais usados pelo cliente.
- Containers com Podman/podman-compose; o `docker-compose.yml` é compatível com ambos.
- Pipeline de sprites: SDXL (`pixel-art-xl`), VAE em fp32, UNet em fp8, 768 px, pixelização 768 → 192 → 768 e redução final para 160 px com vizinho mais próximo.
- Mar: shader procedural em vez de TileMap ou textura, porque é contínuo em qualquer tamanho de tela e não precisa de asset.
- Câmera: `Camera2D` fica como filha do navio do jogador no mapa, e não dentro de `ship_base.tscn`, para que NPCs não ganhem câmera.
- Atributos de navio em `ShipData` (Resource `.tres`), e não em exports soltos na classe.
- Git (fluxo enxuto): `main` é produção; `dev` é integração e branch padrão de trabalho; `feature/*` saem de `dev` e voltam para `dev`; `hotfix/*` saem de `main` e voltam para `main` e `dev`. Sem `release/*` por enquanto.

## Comandos pendentes
- `sudo apt install podman podman-compose` (não instalado nesta máquina).
- Godot 4.7.2 em `~/.local/bin/godot4` (fora do PATH padrão; o `project.godot` declara 4.3).

## Issues / cards
- Projeto Kanban **Navizin** (nº 4): https://github.com/users/fagundessouza/projects/4
- #1 EPIC Navegação e mar
- #2 EPIC Pipeline de sprites
- #3 EPIC Infraestrutura local
- #4 Movimentação básica do navio do jogador: implementada nesta branch, aguardando PR
- #5 Gerar direções do Holandês Voador: 7 vistas já existem, falta revisão da arte
