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
- `c99dcea` feat(client): tile the ocean with a repeating shader
- `fa8298b` feat(client): Q/E and mouse buttons for broadsides, sea-locked aim, juice
- `1c7522f` feat(client): light the ocean with relief, sun glints and vignette
- `64a19b4` feat(client): independent Q/E charges, continuous turning, float sway

## Rodada atual (Q/E, virada, balanço, iluminação)
- **Q e E independentes:** cada bordo tem carga própria. Q e E segurados juntos carregam os dois. Soltar dispara só aquele bordo. Um toque rápido dispara uma bordada com força mínima `TAP_MIN_POWER` (0.3). Antes, um toque disparava força 0.02, quase invisível, e E era ignorado enquanto Q estava segurado.
- **Virada contínua:** a vista acompanha o rumo real com atraso (`VISUAL_TURN_RATE` 5/s). A vista é uma mistura entre setores vizinhos, com a vista de cada múltiplo de 45° exata. A opacidade da camada de baixo é compensada, para o fundo não aparecer através das diagonais translúcidas. Passo máximo por quadro: 0.016.
- **Balanço de flutuação:** sobe e desce (`BOB_*`, 1.2 px), deriva lateral (1 px) e balanço leve (0.012 rad). Mais velocidade, mais balanço. A sombra fica no lugar e se afasta quando o navio sobe.
- **Mar iluminado:** a luminância do tile vira altura, e a inclinação dela vira normal. Um sol de canto sombreia as cristas, reflexos deslizam com a maré, uma segunda leitura em outra escala quebra a grade de repetição, e há vinheta. Seis leituras de textura por pixel, cerca de 0.32 ms por quadro.
- **Limite honesto:** a virada entre uma vista de lado e uma de cima ainda parece uma dupla exposição durante cerca de 0.4 s. Um giro de verdade pede quadros intermediários desenhados. Isso é próximo passo de arte.
- **Testes:** suíte `test_v3` com 11 verificações passa (toque, Q+E juntos, atraso da vista, mistura, virada sem corte, balanço, mar com iluminação).

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
- **Disparo:** bombordo é a tecla `Q` ou o botão esquerdo do mouse; estibordo é `E` ou o botão direito. Segurar carrega `shot_power` de 0 a 1, em `charge_time` (1.5 s). Soltar dispara. A carga cheia dispara sozinha, e é preciso soltar para armar de novo. **O lado vem da tecla ou do botão, e não da posição do cursor.**
- **Mira presa ao semiplano:** o cursor é limitado ao semiplano do bordo escolhido, entre a proa e a popa, com margem de 0.14 rad (~8°). Se o cursor estiver do outro lado, a mira vai para a borda mais próxima, perto da proa ou da popa.
- **Arco de mira:** pontos discretos (`ARC_DOT_RADIUS` 2.2, espaçamento 9 px) no alcance atual da carga, mais um arco mais discreto no `range_max`. Abertura (`spread_min` a `spread_max`) cresce com a força. Sem cone amarelo.
- **Bordada:** `cannon_count` projéteis (6) saem em sequência (`volley_interval`). A velocidade cresce com a força. `Cannonball` é uma esfera escura de ferro, com brilho e um halo fantasma, sem colisão ainda.
- **Fumaça de pólvora:** cada bordo tem um emissor (`SmokePort`, `SmokeStarboard`) que solta uma baforada cinza, pequena e transparente, no lado que atirou.
- **Recuo:** impulso oposto ao tiro, `recoil_strength` × força, amortecido por `recoil_damping`.
- **Tremor da câmera:** `shake_strength` × força, decai com `shake_decay`.
- **Esteira:** `GPUParticles2D` (`Wake`), sempre na popa, do lado oposto ao movimento, inclusive em ré. A intensidade cresce com a velocidade: impulso, opacidade e emissão.
- **Sombra do casco:** `Shadow`, um sprite preto com 30% de opacidade, deslocado 6 e 10 px no mundo. Não gira com o casco.
- **Mar:** `ocean_tile.png` (192×192) é a textura, em `client/assets/environment/`. O `Ocean` é um único `ColorRect` de 20000×20000, com `ocean.gdshader`. O shader lê o tile pela posição de mundo, então a repetição não tem limite, e a maré é um deslocamento lento com leve variação de brilho.
- **Tile com costura vertical:** a borda de cima e a de baixo do tile diferem mais do que pixels vizinhos (média 121 contra 76 dentro da imagem). A repetição horizontal está dentro do normal. Rolar a imagem não resolve, porque a descontinuidade só muda de lugar. Isso precisa de um tile regenerado ou de uma mistura nas bordas.
- **Sete direções:** o rumo escolhe o sprite (8 setores de 45°, `SECTORS`). O sprite não gira com o casco: o rumo aparece pela troca de vista. As diagonais de cima ficam com `modulate.a = 0.5`.
- **Teclas 1 a 4:** emitem `skill_triggered(skill_index)`. Ainda sem efeito, porque o sistema de habilidades não existe.
- **Sinais:** `primary_action_triggered(target)` e `broadside_fired(side, power)`.
- **Câmera:** a `Camera2D` é filha do navio do jogador, com suavização. A posição do cursor no mundo acompanha a câmera, e isso é o esperado.

## Validação
- **Godot 4.7.2 headless (`~/.local/bin/godot4`):**
  - Importação sem erros.
  - Cena principal roda sem erros.
  - Suíte de 35 verificações passa: sete direções e opacidade das diagonais, velas e inércia, carga de peso, lado da bateria pelo cursor, carga, disparo automático, bordada de 6 projéteis, recuo, tremor, velocidade pelo tipo de força, esteira, vento e NPC sem disparo.
- **Suíte de 35 verificações** passa no Godot 4.7.2 headless, cobrindo Q/E, botões do mouse, semiplano da mira, bordada, recuo, fumaça, carga cheia, esteira, sombra, diagonal e NPC.
- **Desempenho:** sem vsync, 0,32 ms por quadro com o mar em tela cheia e o navio em movimento (cerca de 3000 FPS, RX 6600, GL Compatibility). O teto de 60 FPS que aparece com vsync não é a medida real.
- **Gráfica:** capturas na tela real (`:0`). O mar repete sem quebra visível na escala 1×. O navio aparece nítido, o arco de mira aparece na carga e a fumaça sai do bordo que atirou.
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
1. Revisar o PR #6 (`feature/issue-4-ship-movement` para `dev`). Fecha a issue #4 no merge.
1a. Corrigir a costura vertical do `ocean_tile.png`: regenerar o tile com borda que case, ou misturar as bordas. Hoje a arte não é contínua na vertical.
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
- Mar: um quad com shader que lê o tile pela posição de mundo, em vez de `TileMapLayer` ou `Parallax2D`. Uma chamada de desenho, custo fixo, repetição sem limite. O shader procedural anterior saiu.
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
