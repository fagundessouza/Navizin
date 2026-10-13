# STATE — Navizin (checkpoint mestre)

> Arquivo de contexto. Ao iniciar uma sessão nova, diga **"Carregar checkpoint"** e leia só este arquivo.
> Ao final de cada sessão ou marco, diga **"Salvar checkpoint"** para atualizá-lo.

## Checkpoint atual (2026-10-13b) — branch `feature/town-hub-redesign`

**Barras de recurso do `ShipStatusModal` ligadas aos dados reais do navio/vento.**

- As 3 barras (carga, casco/blindagem, vento) na faixa de baixo do `galleon_ship_panel.png` eram só decorativas até este checkpoint -- agora leem `ship.supply`/`max_supply`, `ship.hull`/`max_hull` e `WindManager.wind_strength`, a mesma fonte que já alimenta a barra de HUD do canto inferior esquerdo (não é um segundo sistema de status, é o mesmo dado mostrado de novo aqui).
- Posição/tamanho de cada `ProgressBar` medido por amostragem de pixel no interior escuro de cada cápsula da arte (não eyeballed) -- ver cabeçalho de `ship_status_modal.gd` pro fator de conversão (0.625, igual ao resto do painel).
- `_process()` só atualiza as barras enquanto o painel está `visible` (o resto do tempo nem gasta o `get_first_node_in_group`), e resolve o navio uma vez só quando acha, igual ao padrão já usado em `hud_controller.gd._connect_ship()`.

**Verificado rodando o jogo de verdade:** forcei `hull=450`, `supply=300`, `wind_strength=1.2` e as 3 barras preencheram nas proporções certas (45%/30%/80%) -- confirmado por valor lido E por captura de tela.

---

## Checkpoint atual (2026-10-13a) — branch `feature/town-hub-redesign`

**Painéis de arte dedicados (Galeão + Ficha do Capitão Paperdoll), submodal de inventário reutilizável, sistema real de atributos sociais.**

- As imagens novas (`Meshy_AI_captain_paperdoll_panel.png`, `Meshy_AI_galleon_ship_panel.png`) não chegaram anexadas na mensagem (só citadas por nome) -- acharam-se em `~/Downloads/Tortuga/` depois que o usuário apontou a pasta. Essa pasta é o repositório-fonte de TODA a arte bruta usada nas últimas rodadas (inclusive `Meshy_AI_rpg_ui_asset_spritesheet.png`, a prancha original da extração de UI de rodadas anteriores) -- útil lembrar pra próxima vez que faltar uma imagem referenciada por nome.
- `image_ff5672.png` (os 3 brasões) também nunca existiu separado -- é a faixa inferior do próprio `captain_paperdoll_panel.png`, que já vem com Leão/Busto/Aperto-de-mãos prontos e com os `+` desenhados.
- **`CaptainProfileModal`/`ShipStatusModal` substituem os antigos `AccessoriesPanel`/`ShipPanel` genéricos (`CaptainPanel` de abas)** -- as duas artes já vêm com moldura, "+"  e emblemas pintados, então os scripts só posicionam BOTÕES TRANSPARENTES exatamente em cima do que já está desenhado (nenhum ícone extra desenhado por cima). Coordenadas de cada slot medidas com overlay de grade nas imagens de origem (1536x864), convertidas pra escala de exibição (960x540, fator 0.625) -- documentado no cabeçalho dos dois scripts pra não precisar remedir do zero se a arte mudar de tamanho.
- **`InventoryPickerSubmodal`** (novo, reutilizável): abre do lado do slot clicado (lado com mais espaço, calculado por slot -- direita/esquerda e cima/baixo), lista só os itens de `STUB_INVENTORY` filtrados pela categoria do slot (sem inventário de verdade ainda). Clique no item seleciona e fecha; clique fora (backdrop em tela cheia) também fecha. Selecionar um item atualiza o tooltip do slot com o nome escolhido -- prova o fluxo fim-a-fim mesmo sem dado real.
- **Pulso de clique**: todo slot '+' (6 do paperdoll + 3 especiais do navio + 20 da grade de armamento = 29 ao todo) ganha a mesma animação -- escala 1→1.35→1 + brilho instantâneo (`modulate`) via Tween, antes de abrir o submodal.
- **`CaptainAttributes` (novo autoload)**: `leadership`/`charisma`/`persuasion` + `available_points` (começa em 5, valor de demonstração). `spend(attr)` incrementa e emite `changed`; `captain_profile_modal.gd` escuta e atualiza o número embaixo de cada brasão e o "Pontos disponíveis" em tempo real.
- Grade de armamento do navio (5x4=20 slots) construída em loop a partir de duas listas de coordenadas, não 20 nós escritos à mão. As 3 barras de recurso (carga/blindagem/vento) na faixa de baixo do painel do navio ficaram só decorativas por ora -- dá pra ligar em `ship.supply`/`hull`/`WindManager` depois se quiser essa leitura ao vivo ali também (não pedido nesta rodada).
- "Habilidades Passivas" e "Tripulação" (abas do `ShipPanel` antigo) não têm mais lugar nessa tela nova de encaixe -- a arte não tem espaço de abas. Ficam pendentes de uma decisão futura sobre onde morar.

**Verificado rodando o jogo de verdade:** 12 checagens, todas passaram -- os 2 painéis abrem com a arte certa, clique num slot abre o picker na posição certa com a lista filtrada certa, selecionar um item atualiza o tooltip, clicar 3x no brasão do Leão sobe `leadership` pra 3 e `available_points` pra 2 com o texto atualizando ao vivo na tela.

---

## Checkpoint atual (2026-10-12h) — branch `feature/town-hub-redesign`

**Acabamento gótico/metalizado nos painéis (estilo MU Online/Diablo), hotbar refeita com slots fatiados, vazamento de ícones do menu corrigido.**

- **Hotbar** (`hotbar.tscn`): a faixa única `hotbar_strip.png` com 8 posições em offset fixo virou um `HBoxContainer` de 8 `TextureRect` usando `hotkey_slot_frame.png` (já extraído de rodada anterior) -- layout flui em vez de pixel hardcoded. `hud_controller.gd` parou de pré-carregar `hot_1..4.png` nos slots 1-4 (munição/rum/pistola/espada mockados); os 8 slots ficam vazios por padrão agora, só preenchidos quando existir equipamento de verdade.
- **Enfeites de nine-patch**: `nine_patch_skull_banner.png` (topo) e `nine_patch_anchor_seal.png` (base) são novos, recortados do mesmo `ui_45_353x178.png` da extração da prancha de pergaminho (2 rodadas atrás) que já tinha virado `nine_patch_corner_skull.png`/`edge_h`/`edge_v` -- esse pedaço específico da prancha é uma referência de caixa de diálogo completa com os dois enfeites prontos, só precisou recortar e isolar cada um.
- **`GothicPanelShader` (`assets/shaders/gothic_panel.gdshader`)**: opacidade de 85% no miolo escuro do quadro + brilho metálico pulsante na moldura ornamentada, com variação de tempo por célula (hash+seno) em vez de um pulso uniforme. Separar miolo de moldura por BRILHO do pixel (luma), não por posição/UV -- a primeira tentativa usando distância até a borda em UV vazou brilho borrado pelo painel inteiro, porque o `NinePatchRect` remapeia UV de um jeito não-linear pro 9-slice (corner fixo, borda esticada só num eixo, centro esticado nos dois). O miolo de `modal_frame_iron.png` é um chapado ~luma 0.055; a moldura entalhada nunca cai tão baixo assim (~0.11+) -- um corte de brilho separa os dois de forma confiável, pixel a pixel.
- **`TradeModal`/`CaptainPanel`/`LifeSkillsPanel` restruturados**: raiz trocou de `PanelContainer` com `StyleBoxTexture` pra `Control` simples com um `NinePatchRect` de verdade como fundo (irmão, não pai, do conteúdo) -- só assim dá pra aplicar o shader SÓ no fundo sem ele also afetar texto/botões por cima (um `material` num `PanelContainer` desce pra todos os filhos). Cada painel ganhou `SkullBanner`/`AnchorSeal` pendurados no topo/base, sobrepondo a moldura. `extends PanelContainer` virou `extends Control` nos 3 scripts -- nenhum deles usava API específica de `PanelContainer`, troca segura.
- **Vazamento de ícones do menu** (`system_menu_bar.tscn`): ícones reduzidos 20% (52px -> 42px, meio a meio com "reduza a escala em 20%"), painel/grid recalculados pro novo tamanho, `clip_contents = true` no `Frame` e no `Grid` pra garantir que nem o pulo de escala do hover ultrapasse a moldura.

**Verificado rodando o jogo de verdade:** hotbar com 8 slots vazios e framed; ícones do menu certinhos dentro da moldura sem vazar; painel do Navio com o brilho confinado só na moldura (não mais espalhado), enfeites de caveira/âncora visíveis e bem posicionados, texto legível sem o pulso por cima.

---

## Checkpoint atual (2026-10-12g) — branch `feature/town-hub-redesign`

**Barra de menus do HUD reestruturada: de 13 ícones soltos (a maioria sem função, só texto "Em construção") pra 6 botões com destino próprio.**

- `system_menu_bar.tscn`: grid reduzido de 3 linhas/13 ícones pra 1 linha/6 ícones (painel 342x184 → 342x68). Mapeamento final: Navio (galeão, reaproveitado de `pins/icon_shipyard.png`) / Diário de Bordo (pergaminho, novo recorte da prancha em `processed/hud/icon_scroll_missions.png`) / Ficha do Capitão (baú, ícone antigo já pronto com hover+pressed) / Life Skills (bússola, ícone antigo já pronto) / Salão das Frotas (bandeira do kraken, `processed/tab_banner_kraken.png` -- mais específica que o jolly_roger genérico que tinha antes) / Configurações (engrenagem, inalterado).
- Removidos como botão próprio: leme isolado, âncora avulsa, munição, tripulação solta, rum, mapa do mundo, reconhecimento, perfis/títulos, alertas soltos. Tripulação virou aba dentro do Navio; Alertas virou aba dentro do Diário de Bordo; o resto não tinha função clara o bastante pra manter ícone fixo. "Ancorar" (recolher vela) continua funcionando pela tecla N em `_unhandled_input`, só perdeu o botão -- não é mais ação rápida nesse grid, que virou só de janelas.
- `CaptainPanel` (`scripts/ui/captain_panel.gd` + `scenes/ui/captain_panel.tscn`, novo): mesmo padrão de N abas em código do `TradeModal`, mas sem o cabeçalho de saudação de NPC (não faz sentido o jogador "ser cumprimentado" na própria ficha). `tab_bodies` dá uma frase própria por aba em vez do "Em breve" genérico. Usado em 3 instâncias no `hud.tscn`: Navio (abas Casco/Peças, Habilidades Passivas, Tripulação), Diário de Bordo (abas Diário de Bordo, Histórico de Combate) e Ficha do Capitão (abas Brincos/Anéis/Colares/Cintos/Trajes).
- `LifeSkillsPanel` (`scripts/ui/life_skills_panel.gd` + `scenes/ui/life_skills_panel.tscn`, novo): interface de barras de proficiência estilo BDO/Albion -- 6 ofícios (Pesca, Coleta, Comércio, Navegação, Culinária, Alquimia), cada um com nome + barra + nível, construídos em código a partir de uma constante `SKILLS` com valores de demonstração (sem XP real rastreado ainda).
- Salão das Frotas e Configurações continuam na caixa de diálogo simples já existente (`DialogPanel`, só título+corpo) -- não precisavam de abas, e a Guilda já existe como distrito físico em Tortuga (esse botão é só um atalho informativo vindo do mar, não teleporta pro distrito).
- `hud_controller.gd` reescrito: `MENUS` virou dois dicionários (`SIMPLE_MENUS` pros 2 que usam o diálogo genérico, `DEDICATED_KEYS` pros 4 com painel próprio, resolvidos em `_dedicated_panels` no `_ready()`), um único fluxo de abrir/fechar (`_on_menu_pressed`/`_close_panel`) cobre os dois tipos. Removido o `_update_compass_body()` (texto de vento ao vivo) junto com o botão de bússola antigo, que não existe mais como "Rosa dos Ventos".

**Verificado rodando o jogo de verdade:** grid confirmado com exatamente 6 botões; os 4 painéis com aba abrem e fecham certo; os 2 diálogos simples mostram título/corpo certos; capturas de tela confirmam os 6 ícones legíveis e o layout dos painéis (abas do Navio, Ficha do Capitão com 5 abas, barras de Life Skills, diálogo da Guilda).

---

## Checkpoint atual (2026-10-12f) — branch `feature/town-hub-redesign`

**Pin da Feira de Suprimentos reposicionado, modal sem Comprar/Vender.**

- O pin estava no farol/torre do topo (posição herdada do antigo hotspot "Academy", nunca tinha sido revisada). Movido pra região das barracas/tendas de comércio no cais inferior, perto da água da baía -- conferido por amostragem (99% de pixel opaco na nova posição).
- `supply_market_district.tscn`: `action_buttons` vazio (tira Comprar/Vender, mesmo tratamento já dado à Taverna). Fundo confirmado correto (`dark_port.png` = `image_3560056b`, tendas com peixe seco e placa "The Black Tide" -- já estava certo desde a rodada anterior, só confirmado de novo). Sobreposição de botões já resolvida genericamente pelo fix do checkpoint anterior (`TradeModal.opened/closed`), nenhuma mudança extra precisou aqui.

**Verificado rodando o jogo de verdade:** hover no pin novo mostra tooltip "Feira de Suprimentos" na posição certa (barracas, não mais na torre); modal confirma 2 abas sem botões de ação e sem sobreposição com os botões de navegação.

---

## Checkpoint atual (2026-10-12e) — branch `feature/town-hub-redesign`

**Camadas de UI, reposição da Caverna do Tesouro (de verdade desta vez), e sistema de marcadores visuais no mapa da ilha.**

**1) Sobreposição de botões corrigida.** `TradeModal` ganhou sinais `opened`/`closed`; `city_district_base.gd._wire_shop()` escuta os dois e esconde `$Buttons` (Mapa da Ilha/Voltar ao Mar) + o próprio botão de abrir enquanto o modal está visível -- com o modal da Taverna (mais largo, 4 abas na época), esses botões ficavam atrás dele, clicáveis sem aparecer. Reaparecem ao fechar.

**2) Taverna: removido Comprar/Vender, tirada a aba Bebidas.** `action_buttons` vazio (nenhum botão de ação -- Tripulação/Procurados/Contratos não são venda simples, não fazem sentido com Comprar/Vender genérico). Ficaram só 3 abas: Tripulação, Quadro de Procurados, Contratos de Serviço. Modal um pouco mais estreito (720px → 600px) pra não sobrar espaço vazio com uma aba a menos.

**3) Caverna do Tesouro reposicionada de verdade.** A posição anterior (penhasco do farol, borda direita) tecnicamente tinha 80% de pixel opaco por baixo, mas o usuário via como "flutuando fora do terreno" -- olhando a ilha de novo com mais calma, achei uma fenda rochosa de verdade (penhascos escuros com onda batendo) bem abaixo da Feira de Suprimentos, que bate com a descrição "base inferior, abaixo dos cais da feira". Nova posição com 93% de pixel opaco por baixo (contra ~80% antes), verificado por amostragem antes de aplicar.

**4) `DistrictPin.tscn`/`.gd` (novo componente): os 8 hotspots invisíveis (`TextureButton` só visível no hover) viraram marcadores SEMPRE visíveis.** Ícone gótico próprio por distrito (do mesmo recorte da prancha de pergaminho da rodada anterior, seção "Core Icons" -- navio pro Estaleiro, bala de canhão pra Forja, caveira pra Taverna, pergaminho pro Boticário, medalhão pro Marketplace, bússola pra Caverna do Tesouro, leme pra Guilda, livro-âncora pra Feira), com aumento de escala + brilho dourado no hover, e uma etiqueta (reaproveita o `dialogue_box_bg.png` da rodada anterior) mostrando nome + função do distrito. Clique emite `pressed(district_id)` direto -- `island_tortuga_hub.gd` simplificou a conexão (não precisa mais de `.bind()`).

**Verificado rodando o jogo de verdade:** captura do mapa da ilha confirma os 8 pins visíveis e a Caverna do Tesouro com o hover mostrando o tooltip certo, na rocha; captura da Taverna confirma 3 abas sem Comprar/Vender e sem os botões de navegação sobrepostos. 8 checagens no total, todas passaram.

**Nota lateral:** o `ocean_map.tscn` tinha mudanças do próprio usuário no editor (barris removidos, postes de amarração reposicionados) -- mantidas como estavam, não revertidas.

---

## Checkpoint atual (2026-10-12d) — branch `feature/town-hub-redesign`

**Bug reportado (Baú/Feira "sumidos") investigado, não reproduzido.** Testei os dois hotspots do zero (posição, clique, cena, modal) rodando o jogo de verdade -- tudo funcionou. Provável causa: cache do editor do usuário não recarregando as cenas depois das últimas mudanças. Reportado, não corrigido (nada pra corrigir no código).

**Prancha de UI processada (`Meshy_AI_rpg_ui_asset_spritesheet.png`, achada em `~/Downloads/Tortuga/`).** Fundo de pergaminho, não preto puro -- precisou de técnica nova de recorte.

- **`scripts/extract_parchment_ui_assets.py`** (utilitário salvo no repo, não descartável como os scripts de sessão anteriores): classifica cada pixel por matiz+saturação+valor (HSV) em vez de limiar de luminância -- o pergaminho tem vinheta e textura de grão, a claridade sozinha varia demais (testado: 45 a 210) pra um limiar único funcionar. Dois modos: `fatia` (um recorte manual) e `prancha` (separa automaticamente cada peça isolada, mesma técnica de componentes conectados dos kits anteriores).
- **11 peças em `assets/ui/processed/`:** `nine_patch_corner_skull.png`, `nine_patch_edge_h.png`/`edge_v.png`, `icon_settings.png`, `icon_ammo_sheet.png` (seção inteira, não peça por peça), `hotkey_slot_frame.png`, `dialogue_box_bg.png` (com o texto de exemplo "Dialogue text line 1..." apagado à mão -- vinha desenhado na própria prancha, ia aparecer por baixo do texto real), `portrait_avatar_frame.png` (moldura vazia, sem rosto fixo -- diferente da antiga `portrait_frame.png`), `tab_banner_kraken/swords/anchor.png`.
- **`modal_frame_iron.png`** (nova, montada com Python a partir das peças): os 4 cantos de caveira espelhados pra cada esquina + bordas de ferro repetidas + preenchimento escuro no centro -- compõe a moldura que o `NinePatchRect`/`StyleBoxTexture` pedido realmente precisa (uma textura montada, não peças soltas -- `StyleBoxTexture` fatia UMA textura em 3x3, não combina arquivos separados).

**`TradeModal` atualizado:** moldura nova (`modal_frame_iron.png`), retrato novo (`portrait_avatar_frame.png`), e a saudação do NPC agora mora dentro de uma mini caixa de diálogo (`dialogue_box_bg.png`) em vez de só texto solto. **Bug pego e corrigido na hora:** a caixa de diálogo nova inflou a altura mínima do modal além do espaço fixo reservado, e ele passou pra fora da tela (visível só testando rodando o jogo, não ia aparecer numa checagem de compilação). Corrigido aumentando a altura do painel (420px → 520px) e apertando as margens da caixinha de diálogo.

**Botão de Configurações:** adicionado na barra de sistema do HUD (`system_menu_bar.tscn`), 13º ícone -- a grade de 6 colunas ganhou uma 3ª linha (painel cresceu de 118 pra 184px de altura, sem colidir com bússola/minimapa/hotbar). Ligado em `hud_controller.gd` pelo mesmo dicionário genérico que já cobria os outros 12 (tecla O, "em construção").

**Verificado rodando o jogo de verdade:** captura do HUD confirma o botão novo sem sobreposição; captura do modal da Forja confirma a moldura/retrato/caixa de diálogo cabendo na tela depois da correção de altura.

---

## Checkpoint atual (2026-10-12c) — branch `feature/town-hub-redesign`

**Abertura direta do modal + saudação por reputação + moldura metalizada.**

- **Sem clique extra:** `city_district_base.gd._wire_shop()` agora chama `modal.open()` direto no `_ready()`, além de ligar o botão -- entrar no distrito já mostra a loja/estação aberta, sem precisar clicar em "Abrir X" primeiro. O botão continua existindo, só que agora é pra REABRIR se o jogador fechar o modal e quiser ver de novo.
- **`scripts/autoload/reputation_manager.gd`** (novo autoload, stub explícito): `player_title`/`reputation_tier` fixos por ora (sem XP/progressão de verdade), `get_greeting()` devolve uma frase de saudação variando por título ("Grumete" → "Flagelo dos Sete Mares"). `TradeModal` chama isso toda vez que abre.
- **Faixa de saudação no topo do modal:** retrato (`portrait_frame.png`, já existia no projeto) + `GreetingLabel` dinâmico. **Limitação de stub assumida:** o retrato é o mesmo pirata genérico em todo distrito (Taverna, Boticário, Ferreiro...) -- não tem arte de NPC por local ainda, só o placeholder.
- **Moldura metalizada de verdade:** `dialog_panel.png` (também já existia, nunca tinha sido reaproveitado num modal de distrito) virou o `StyleBoxTexture` do `TradeModal` -- caveira com véu de morcego no topo, âncora embaixo, cantos de metal ornamentados. Botões (abas + ação + fechar) ganharam contorno escuro no texto e um leve brilho/aumento de cor no hover via tween, tudo aplicado em código já que os botões são criados dinamicamente.
- **Verificado rodando o jogo de verdade:** entrar no Boticário já mostra o modal aberto, com a saudação certa ("Ah, Capitão! Sempre um prazer fazer negócio.") e a moldura nova -- fechar e reabrir pelo botão também confirmado funcionando.

---

## Checkpoint atual (2026-10-12b) — branch `feature/town-hub-redesign`

**Desfeita uma confusão de 2 rodadas atrás: Feira de Suprimentos e Caverna do Tesouro viraram o mesmo hotspot sem querer.**

No checkpoint `2026-10-11f`, troquei o título de `treasure_vault_district.tscn` pra "Feira de Suprimentos" sem perceber que isso colidia com o conceito que já existia em `market_bazaar_district.tscn` ("Mercado Feirante de Tortuga"). O pedido desta rodada deixou isso explícito ao pedir os dois como coisas separadas, com arquivos de cena diferentes.

- **Posição do hotspot da Caverna do Tesouro ajustada.** O pedido queria ele "no recanto rochoso da base, abaixo do cais e da feira" -- conferi a arte da ilha e não existe nenhuma boca de caverna literalmente desenhada em lugar nenhum (a ilha não tem esse detalhe pintado). Usei o ponto mais rochoso e dramático disponível (penhasco com cachoeira, perto do farol, canto direito) em vez de inventar uma posição sem base visual.
- **`treasure_vault_district.tscn` voltou a ser só a Caverna do Tesouro:** título "Caverna do Tesouro e Contrabando", abas do modal de volta pra "Itens Recuperados"/"Contrabando". Fundo continua `market_cavern.png` (nunca mudou, estava certo desde o início).
- **`market_bazaar_district.tscn` → renomeado pra `supply_market_district.tscn`**, essa sim a Feira de Suprimentos de verdade: fundo trocado de `harbor_background.png` (genérico) pra `dark_port.png` (o porto com a banca de peixe seco e a placa "The Black Tide" -- a imagem `image_3560056b`, que ESTAVA certa desde quando identifiquei pela primeira vez, só nunca tinha sido usada em lugar nenhum porque ficou órfã depois de trocas anteriores). Ganhou modal próprio agora (não tinha nenhum): abas "Alimentos e Bebidas"/"Suprimentos de Bordo".
- Hotspot/nó renomeado de "MarketBazaar" pra "SupplyMarket" em `island_tortuga_hub.tscn` e no dicionário `DISTRICT_SCENES`.

**Verificado rodando o jogo de verdade:** Caverna do Tesouro e Feira de Suprimentos abertos separadamente, título/abas/fundo corretos em cada um, sem mais sobreposição de conceito.

---

## Checkpoint atual (2026-10-12) — branch `feature/town-hub-redesign`

**Reestruturação de nomes pra refletir as mecânicas futuras (Marketplace estilo BDO, Crafting estilo Albion, Contratos estilo Prospectors) + modal generalizado pra N abas.**

**Conflito real encontrado e resolvido sem adivinhar:** o pedido descrevia dois destinos diferentes pro mesmo ponto físico do mapa -- "Praça Central (antes Mural de Recompensas)" devia virar "Mercado Central/Marketplace" (item 1, com especificação completa de abas em outro lugar do pedido), e separadamente "Praça Central/Estátua" devia virar "Distrito de Profissões e Treinamento" (sem nenhum detalhe em lugar nenhum do documento). Conferi a posição da estátua na arte da ilha (recorte visual) contra as coordenadas do hotspot "Mural de Recompensas" -- é o MESMO lugar. Não existe hotspot livre pra um 9º distrito. Implementei o Marketplace (instrução concreta e detalhada) e **deixei "Distrito de Profissões e Treinamento" de fora** -- não inventei um nono ponto no mapa sem base nem na arte nem no texto.

**`TradeModal` generalizado** (`scripts/cities/trade_modal.gd` + `scenes/ui/trade_modal.tscn`): de 2 abas fixas (`Tab1`/`Tab2` na cena) pra N abas construídas em código a partir de `@export tabs: PackedStringArray`, com `action_buttons` configurável (1 ou 2 botões) e `resource_hint` opcional (linha de texto, ex. lista de materiais). Mesmo componente agora serve loja simples (Comprar/Vender), estação de crafting (só Fabricar + lista de materiais) e marketplace (Nova Ordem) -- só muda a configuração por instância, não o código.

**Renomeações aplicadas:**
- `bounty_board_district.tscn` → **renomeado o arquivo** pra `marketplace_district.tscn` ("Mercado Central / Marketplace", abas "Ordens de Pré-Compra"/"Ordens de Pré-Venda", botão "Nova Ordem"). O quadro de procurados que dava nome a esse hotspot mudou de endereço.
- `tavern_district.tscn`: ganhou 2 abas a mais (agora 4: Bebidas, Tripulação, Quadro de Procurados, Contratos de Serviço) -- é pra cá que o antigo mural de recompensas se mudou. Modal alargado (560px → 720px) pra caber as 4 sem apertar.
- `treasure_vault_district.tscn`: "Baú do Tesouro e Contrabando" → "Feira de Suprimentos" (comida/bebida/suprimentos). **Descompasso temático que ficou em aberto:** o fundo continua sendo a caverna de baús de ouro -- combinava com "tesouro", não combina tão bem com "feira de suprimentos". Sem arte nova pra isso, mantive o fundo e só troquei o texto.
- `blacksmith_district.tscn`: "Forja e Ferreiro Naval" → "Forja Naval", virou estação de crafting (abas "Armas e Armaduras do Capitão"/"Pólvora e Munição", botão único "Fabricar", `resource_hint` com a escala de materiais completa: Madeira · Ferro · Aço · Prata · Ouro · Pérola · Obsidiana · Adamantina · Diamante).
- `shipyard_district.tscn`: "Estaleiro e Reparos" → "Estaleiro", crafting (abas "Velas"/"Cascos e Proas", só "Fabricar").
- `apothecary_district.tscn`: crafting (abas "Poções e Elixires"/"Remédios da Tripulação", só "Fabricar").
- `captains_guild_district.tscn`: "Salão da Guilda dos Capitães" → "Salão das Frotas" (só texto, sem modal -- não é loja nem crafting).
- `market_bazaar_district.tscn`: não mencionado no pedido, mantido como está.
- Tooltips dos hotspots em `island_tortuga_hub.tscn` e o dicionário `DISTRICT_SCENES` em `island_tortuga_hub.gd` atualizados pra bater.

**Verificado rodando o jogo de verdade:** Marketplace, Taverna (4 abas) e Forja (botão Fabricar + dica de materiais) abertos e capturados -- título, abas e layout corretos nos três, sem overlap mesmo com 4 abas.

**Pendências novas:** "Distrito de Profissões e Treinamento" sem local nem especificação; descompasso de arte na Feira de Suprimentos; nenhuma lógica de receita/preço/inventário em lugar nenhum (toda a reestruturação foi só taxonomia + UI).

---

## Checkpoint atual (2026-10-11g) — branch `feature/town-hub-redesign`

**Fundo cinza, 2 artes dedicadas novas, e sistema de modal de comércio reutilizável.**

- **Cinza nas bordas:** `rendering/environment/defaults/default_clear_color` em `project.godot` virou preto puro. `island_tortuga_hub.tscn` ganhou um `ColorRect` preto atrás da arte (`BlackBackdrop`) e uma vinheta de verdade (`assets/shaders/vignette.gdshader`, escurece progressivamente até os cantos, não é só um tingimento plano como o `Vignette` que já existia). A causa mais provável não era nenhum mismatch de proporção (a arte já é 16:9 igual o viewport) -- é letterboxing quando a janela do jogador não fica exatamente 16:9. As três camadas resolvem isso em qualquer proporção de janela.
- **Boticário e Ferreiro ganharam arte dedicada de verdade:** antes o Boticário dividia fundo com a Guilda dos Capitães (mesmo arquivo). Agora usa `apothecary_lab_v2.png` (caldeirão borbulhando verde, frascos roxos/verdes, crânios) e o Ferreiro usa `blacksmith_forge.png` (forja ao ar livre com vulcão ativo ao fundo), achados em `~/Downloads/` com nome próprio -- não mais um `image_<uuid>.png` genérico. A Guilda continua usando o estúdio gótico sozinha agora (Boticário não compartilha mais).
- **`scenes/ui/trade_modal.tscn` + `scripts/cities/trade_modal.gd`** (novo, reutilizável): painel modal centralizado, 2 abas configuráveis por `@export`, cada uma com um placeholder "Em breve" e botões Comprar/Vender -- sem lógica de inventário ainda, só a estrutura. `city_district_base.gd._wire_shop()` liga um botão "Abrir Loja" ao modal SE a cena tiver os dois nós (`OpenShopButton` + `TradeModal`); se não tiver, não faz nada -- não quebra as cenas sem loja.
- **Aplicado em 6 dos 8 distritos** (Taverna, Ferreiro, Estaleiro, Boticário, Baú do Tesouro, Mercado Feirante), cada um com abas temáticas (ex. Ferreiro: "Canhões"/"Blindagem do Casco"; Boticário: "Poções de Cura"/"Elixires Raros"). **Deliberadamente sem modal:** Mural de Recompensas e Guilda dos Capitães -- não são loja (quadro de contratos e salão de reputação/frota), forçar Comprar/Vender ali não faria sentido. Pode ganhar sua própria UI (não de comércio) depois.
- **Verificado rodando o jogo de verdade:** captura da ilha confirma vinheta sem cinza nenhum; abrir a Forja mostra o modal com título/abas corretos, troca de aba funciona, fechar esconde de novo -- 7 checagens, todas passaram.

---

## Checkpoint atual (2026-10-11f) — branch `feature/town-hub-redesign`

**Reorganização de nomes/fundos, taxonomia dos distritos virou 8.**

- `shipyard_district.tscn`: fundo trocado pra um interior dedicado (galpão com casco de navio em construção + forja ao fundo), em vez de compartilhar o porto escuro com a forja.
- `captains_guild_district.tscn`: fundo trocado pro estúdio gótico com mesa de navegação/mapas/globos/candelabros -- **é o MESMO arquivo já usado em `apothecary_district.tscn`** (a descrição pedida bateu exatamente com essa imagem, e não achei nenhuma outra nova depois de conferir a pasta de novo). Os dois distritos compartilham o visual por ora; se quiser uma arte exclusiva pro Boticário, precisa gerar uma nova.
- `supply_market_district.tscn` renomeada pra `treasure_vault_district.tscn` ("Baú do Tesouro e Contrabando"), mesmo fundo de caverna com baús de ouro.
- **Distrito novo:** `market_bazaar_district.tscn` ("Mercado Feirante de Tortuga"). Sem imagem dedicada pedida -- usei o `harbor_background.png` genérico (cais/porto), que já serve bem pra barracas de feira ao ar livre. Não havia hotspot livre no mapa da ilha pra um 8º destino, então reaproveitei o antigo hotspot "Academy" (sem conteúdo próprio) -- renomeado pra "MarketBazaar" no `.tscn` e no dicionário do script. O hotspot "BlackMarket" virou "TreasureVault" do mesmo jeito.
- `bounty_board_district.tscn`: só troca de título, pra "Mural de Recompensas e Contratos" (mesmo fundo de fogueira na praia).
- Tooltips dos hotspots em `island_tortuga_hub.tscn` atualizados pra bater com os títulos novos.

**8 distritos agora:** Taverna, Forja, Estaleiro, Boticário, Mural de Recompensas, Baú do Tesouro, Guilda dos Capitães, Mercado Feirante -- todos num dicionário nome→cena em `island_tortuga_hub.gd` (`DISTRICT_SCENES`).

**Verificado rodando o jogo de ponta a ponta:** mar → F → mapa → Baú do Tesouro (confere fundo + título) → volta ao mapa → Mercado Feirante (confere fundo + título) → volta ao mapa → Guilda (confere fundo + título) → Voltar ao Mar → oceano. Os 6 passos passaram, capturas conferidas visualmente.

---

## Checkpoint atual (2026-10-11e) — branch `feature/town-hub-redesign`

**Fundos dedicados por distrito, prédio isolado removido.** O checkpoint anterior (2026-10-11d) empilhava o Sprite2D do prédio (fundo preto extraído) sobre o `Tortuga Harbor Background` genérico, repetido nos 7 distritos. O usuário pediu fundos panorâmicos ÚNICOS por distrito -- de novo, achados em `~/Downloads/Tortuga/` sem aviso (9 imagens novas, timestamp de minutos depois do checkpoint anterior), conferidos antes de assumir.

- `tavern_district.tscn` → interior da taverna, lareira acesa, mesas de madeira.
- `apothecary_district.tscn` → laboratório gótico, frascos de água-viva bioluminescente, candelabros, lua pela janela.
- `supply_market_district.tscn` → caverna de tesouro/contrabando sob a ilha, baús abertos, doca interna.
- `blacksmith_district.tscn` e `shipyard_district.tscn` → compartilham o mesmo fundo (porto escuro "The Black Tide", pontes suspensas entre penhascos, barcos).
- `bounty_board_district.tscn` e `captains_guild_district.tscn` → compartilham o mesmo fundo (vila costeira, fogueira na praia, palmeiras).
- Removido de todas: o nó `Building` (Sprite2D do prédio isolado + `BuildingFX` + colisão de hover). `scripts/cities/building_fx.gd` ficou sem nenhuma cena usando -- deletado (código morto de verdade, não só arquivo de asset parado).
- Os 7 PNGs de prédio isolado (`assets/sprites/environment/districts/*.png`, sem a subpasta `interiors/`) continuam no projeto, só sem uso em cena nenhuma por ora -- não apaguei esses (são arte, não código; podem servir pra outra coisa, tipo ícone do hotspot no mapa da ilha).
- Fundos novos ficam em `assets/sprites/environment/districts/interiors/`.
- **Verificado rodando o jogo de verdade:** capturas de taverna, boticário e mercado confirmam tela cheia sem sobreposição, título/texto/botões legíveis por cima.

**Também vieram na mesma leva (não usados ainda):** uma vista interna do estaleiro/forja combinados (pode servir pra um distrito futuro ou substituir o fundo compartilhado atual), e 3 pranchas de retrato de NPC (ferreiro, capitão, taverneiro -- cada uma com 3 expressões) para quando existir sistema de diálogo com retrato.

---

## Checkpoint atual (2026-10-11d) — branch `feature/town-hub-redesign`

**7 distritos de Tortuga, com arte de verdade, transição com nevoeiro e navio sumindo ao atracar.**

O usuário gerou a arte que faltava (achada em `~/Downloads/Tortuga/`, não documentada por ele, só encontrada conferindo a pasta antes de assumir que não existia): os 7 prédios dos distritos (isolados em fundo preto, mesma convenção de extração de sempre) e um fundo panorâmico `Tortuga Harbor Background.png` (1536×864, mesma proporção 16:9 do jogo) que serve de cenário comum pra todos os distritos -- exatamente o que o prompt do checkpoint anterior (`ART_PROMPTS.md`) pedia.

**`scenes/cities/districts/`** (7 cenas, uma por distrito):
- `tavern_district.tscn`, `blacksmith_district.tscn`, `shipyard_district.tscn`, `apothecary_district.tscn`, `bounty_board_district.tscn`, `captains_guild_district.tscn`, `supply_market_district.tscn`.
- Cada uma: fundo panorâmico comum + o prédio daquele distrito (`Sprite2D`) por cima + `BuildingFX` (luz piscando, partícula temática, hover) + título/texto próprios (`@export district_title/body` em `city_district_base.gd`, sem mais precisar de `GameManager` como intermediário -- cada distrito agora é uma cena de verdade, não uma genérica reconfigurada).
- "Academy" (sem arte própria ainda) cai na cena genérica `city_district_base.tscn`, que ganhou seu próprio `district_title`/`body` fixos como fallback.
- `island_tortuga_hub.gd`: `_on_hotspot_pressed` troca o dicionário antigo de título/descrição por um dicionário direto nome→caminho de cena (`DISTRICT_SCENES`).

**`scripts/cities/building_fx.gd`** (novo, reutilizável): `PointLight2D` piscando (tween em loop), `GPUParticles2D` temática (`ParticleKind`: SMOKE/SPARKS/MIST/NONE) e leve aumento de escala no hover -- um `BuildingFX` (`Area2D`) por prédio, filho do `Sprite2D` (assim luz/partícula herdam a escala do prédio automaticamente, sem precisar converter unidade).

**`scripts/autoload/scene_transition_manager.gd`** (novo autoload, "nevoeiro da morte"): cobre a tela de bruma escura (shader `fog_transition.gdshader`, reaproveita o ruído da névoa do oceano) antes de QUALQUER troca de cena do jogo (oceano↔ilha↔distrito), e desfaz depois. `ocean_map.gd._enter_tortuga()` também esconde o casco (`visible=false`, `set_physics_process(false)`) antes de disparar a troca, simulando o navio ancorando.

**Armadilha real encontrada e evitada:** a primeira versão usava `create_tween()` + `await tween.finished` encadeado por cima do `change_scene_to_file()` -- o tween criado DEPOIS da troca de cena nunca emitia `finished` (trava indefinida, confirmada esperando 90s de verdade rodando o jogo). Reescrito como máquina de estados em `_process(delta)`, sem Tween nenhum: resolve de vez, e é o padrão mais robusto pra gerenciador de transição em autoload de qualquer forma.

**Verificado de ponta a ponta rodando o jogo de verdade** (autoload de teste temporário, removido depois): mar → F → mapa da ilha → clica "Forja" → `BlacksmithDistrict` com título certo, `BuildingFX` com luz piscando confirmada → "Voltar ao Mar" → `OceanMap` com o navio visível e processando física de novo. Captura da forja rodando mostra o brilho da fornalha por cima da arte (luz ADD visível), composição coesa com o fundo do porto.

**Pendente:**
- As outras 5 cenas de distrito (Estaleiro, Boticário, Quadro de Procurados, Guilda dos Capitães, Mercado de Suprimentos) seguem o mesmo padrão já validado, mas só passaram por checagem de compilação (headless), não teste dinâmico individual -- risco baixo dado que a estrutura é idêntica, mas vale conferir no editor.
- NPCs dentro de cada distrito (`NpcHotspots`, vazio) e o personagem/avatar andando continuam fora de escopo, como combinado.
- Também veio na mesma pasta (`~/Downloads/Tortuga/`) um tileset de penhasco/costa e uma torre-farol -- não usados nesta rodada (fora do pedido), mas disponíveis pra quando a seção 2 do checkpoint de 2026-10-09 (redesenho visual da ilha com `TileMapLayer`) for retomada.

---

## Checkpoint atual (2026-10-11c) — branch `feature/town-hub-redesign`

**Hierarquia de 3 níveis, estilo AQW/Swords and Sandals, implementada:**

```
OceanMap ──(F na baía)──> IslandTortugaHub ──(clica no prédio)──> CityDistrictBase
   ▲                        (mapa/seletor               (praça 2D daquele bairro,
   └────("Voltar ao Mar")       de bairro)                reaproveitável p/ todos)
```

- `IslandTortugaHub` deixou de ser o destino final -- agora é só o SELETOR de
  bairro. Clicar num hotspot não abre mais popup de texto: troca de cena pra
  `scenes/cities/city_district_base.tscn`.
- `city_district_base.tscn`/`.gd`: cena única e reutilizável pra qualquer
  bairro (Taverna, Forja, Boticário...). Não existem 8 cenas quase-idênticas --
  `GameManager.pending_district_title/body` carrega qual bairro foi clicado
  (setado antes do `change_scene_to_file`, já que ele não aceita parâmetro
  direto) e a cena se configura no próprio `_ready()`.
- Fundo da praça por enquanto é um `ColorRect` escuro liso -- ainda sem a arte
  panorâmica do Mesh AI (prompt já existe em `ART_PROMPTS.md`, só falta gerar
  e trocar o placeholder).
- Botões "Mapa da Ilha" (volta pro seletor) e "Voltar ao Mar" (pula direto pro
  oceano, sem passar pela ilha -- `ocean_map.gd` restaura o navio do mesmo
  jeito, o estado salvo não foi tocado).
- `PlayerSpawnPoint` (`Node2D` vazio) já existe na cena-modelo, parado, pronto
  pra quando o personagem andando estilo AQW (e multiplayer) entrar -- combinado
  explicitamente com o usuário que fica estático por enquanto.
- **Verificado rodando o jogo de ponta a ponta** (autoload temporário, mesma
  técnica do checkpoint anterior): mar → F → mapa da ilha → clica "Taverna" →
  praça com título/texto certos → "Voltar ao Mar" → navio restaurado (casco,
  suprimento e posição) direto no oceano, pulando o mapa da ilha. Os 6 passos
  do teste passaram.

**Pendente:** arte panorâmica real por bairro (Mesh AI), NPCs/hotspots dentro
de cada praça, e o personagem/avatar andando (explicitamente adiado pelo
usuário -- "podemos manter estático assim mesmo... futuramente a gente já
deixa preparado").

---

## Checkpoint atual (2026-10-11b) — branch `feature/town-hub-redesign`

Três correções pontuais sobre o checkpoint anterior (mesmo dia, rodada seguinte):

**1) Crash corrigido:** "Cannot call method 'set_input_as_handled' on a null value" em `tortuga_dock.gd:42`. Causa provável: `interact_requested.emit()` dispara `ocean_map.gd._enter_tortuga()` → `change_scene_to_file()` antes de `get_viewport().set_input_as_handled()` rodar na mesma função -- arriscado mesmo com a troca de cena sendo deferida pelo Godot. Corrigido invertendo a ordem (consome o input ANTES de emitir) e com checagem de nulo explícita. Também zera `_ship_in_range` antes do emit, pra uma segunda tecla F não disparar `change_scene_to_file` de novo enquanto a primeira troca ainda não aconteceu. `ocean_map.gd._enter_tortuga` agora confere o retorno de `change_scene_to_file` e loga erro se falhar, em vez de falhar silencioso.

**2) Aviso "Pressione F" reposicionado:** estava embaixo, sobrepondo a hotbar. Movido pro topo-centro, logo abaixo da bússola (`anchor` topo em vez de embaixo), com sombra no texto pra legibilidade contra o mar.

**3) Ilha de Tortuga: escala e posição refeitas.** Problema: ilha pequena demais, dava pra circular em poucos segundos, sem sensação de lugar de verdade. Mudanças em `ocean_map.tscn`/`island_tortuga_hub.tscn`:
- Escala da ilha: `0.45` → `1.0` (~2,2× maior). Todos os polígonos de colisão (`TortugaBody`) escalam junto automaticamente, por serem filhos do mesmo nó raiz.
- Posição: `(1803, -414)` → `(1200, -3700)`. A ponta norte da ilha agora fica em y≈-4102, além do `world_bounds` (-4000) -- a massa de terra literalmente "vaza" o limite navegável do mapa, como pedido.
- Doca/letreiro/postes/barris (filhos diretos de `World`, não escalam com a ilha) recalculados pra nova posição e escala (fator ×2,22), mantendo a mesma proporção visual dentro da baía.
- **Verificado de verdade rodando o jogo** (não só compilação): captura ampla confirma a ilha preenchendo boa parte do enquadramento; teste de colisão (navio em `sail=FULL` tentando atravessar o flanco oeste por 4s de jogo) andou só ~122 unidades antes de parar -- bem menos que os ~480 que percorreria livre, confirmando que o casco bate e para na rocha, não atravessa.
- **Achado técnico de harness:** `godot4 --script` (SceneTree customizado) não inicializa autoloads -- qualquer cena que referencie `GameManager` etc. falha a compilar nesse modo. Contornado registrando um autoload temporário (`scripts/_tmp_test_runner.gd`, removido depois do teste, não versionado) que roda dentro do boot normal do jogo (`--rendering-method gl_compatibility`, sem `--headless`, que precisa de uma janela real pra capturar `get_texture()`).

---

## Checkpoint atual (2026-10-11) — branch `feature/town-hub-redesign`

**Arquitetura multi-cena: IMPLEMENTADA (parte de código) nesta rodada.** A diretiva do checkpoint anterior (2026-10-09) foi executada:
- `ocean_map.tscn` só cuida de navegação/física. Não existe mais overlay de cidade escondido dentro dele.
- Atracar troca de cena de verdade (`get_tree().change_scene_to_file`) para `res://scenes/cities/island_tortuga_hub.tscn` — o navio é descarregado junto com `ocean_map.tscn`, não "congela escondido" como antes.
- `GameManager` (autoload) guarda `saved_ship_position`/`saved_hull`/`saved_supply` na saída e `ocean_map.gd._restore_ship_state()` reaplica no `_ready()` seguinte, com `-1.0` como sentinela de "nada salvo".
- Interação por tecla **F** (ação `interact`, `project.godot`), substituindo o **E** hardcoded de antes (E já era `broadside_starboard`, um atalho sobrecarregado). `tortuga_dock.gd` foi reescrito: não guarda mais estado de "atracado/desatracado" — só emite `ship_entered_range`/`ship_left_range` (liga um aviso "Pressione F para atracar" no HUD) e `interact_requested(ship)`. Quem decide o que fazer é `ocean_map.gd`.
- Clicar na ilha (mecânica já existente, brilho neon no hover) continua funcionando — aciona o mesmo `_enter_tortuga()`.
- **Conflito de tecla achado e corrigido:** F já era o atalho do menu "Frota e Guilda" no HUD (`hud_controller.gd`). Trocado para **G** (mnemônico: Guilda), já que esse menu ainda está "em construção" e F passou a ser o principal (atracar).
- Cena da cidade relocada de `scenes/ui/tortuga_city_hub.tscn` (overlay) para `scenes/cities/island_tortuga_hub.tscn` (cena própria, script em `scripts/cities/`). Mantidos os 8 hotspots (`TextureButton` com hover+diálogo) já existentes — não foram reescritos como `Area2D`/`CityHubHotspot.gd` conforme um pedido mais recente sugeriu; o padrão existente (hover com textura + tooltip + diálogo "em construção") já cobria a mesma função e troquei de cena em vez de descartar esse trabalho. Se o padrão `Area2D` específico for mesmo necessário (ex.: pra ganhar movimento de câmera dentro da cidade depois), fica pra avaliar com o usuário.
- **Verificação:** compilação headless completa sem erros; teste unitário isolado de `tortuga_dock.gd` (4 casos: entra no alcance, interage com F, sai do alcance, não interage sem navio por perto) passa. A ponte MCP ficou instável durante a sessão (provável efeito colateral de eu ter editado o arquivo de registro dela manualmente enquanto o jogo real tentava se re-registrar) e não deu pra fazer o teste dinâmico completo ao vivo (F dentro do jogo rodando) — recomendo o usuário testar manualmente no editor antes de considerar fechado.

**Pendente da diretiva de arquitetura:**
- Seção 2 (redesenho visual: ilha maciça com baía em C/U via `TileMapLayer_Islands`, farol na entrada) **não implementada** — depende do tileset de penhasco/costa novo, que ainda não existe. Prompts prontos pra gerar no Meshy AI em `.project/ART_PROMPTS.md`.
- Seção 1 (fundo panorâmico sem prédios embutidos) também depende de gerar a arte nova — prompt também em `ART_PROMPTS.md`.
- A doca/letreiro/postes/barris adicionados no checkpoint anterior continuam em `ocean_map.tscn` (mundo aberto, baía), não na cena da cidade — fazem sentido lá (são a chegada física), a cena da cidade é o que se vê depois de entrar.

---

## Checkpoint anterior (2026-10-09) — branch nova `feature/town-hub-redesign`, a partir de `feature/issue-4-ship-movement`

**Diretiva de arquitetura:** o mapa do oceano não vai mais acumular elementos gráficos e props de cidade dentro da mesma cena. Mudança para arquitetura multi-cena -- **executada no checkpoint seguinte (2026-10-11), ver acima.**

**Feito nesta rodada**
- **Respingo da proa corrigido:** usava um decalque em V (`BOW_WAVE_TEXTURE`) desenhado para visão lateral só, girado por código — contra as 8 vistas pintadas à mão do navio, continuava "parecendo de lado" em qualquer ângulo que não fosse o perfil puro. Trocado pelo mesmo ponto redondo já usado na esteira de popa (`WAKE_DOT_TEXTURE`): redondo não tem ângulo errado possível. Diagnosticado ao vivo via Godot MCP Toolkit (leitura de propriedades do navio rodando, screenshots do runtime) nos ângulos 0°/45°/90°.
- **Tortuga "colada":** ganhou sombra de contato (`GroundShadow`, gradiente radial) e espuma viva na costa (`ShoreFoam`, partículas em anel aditivo) — a ilustração pintada continua sendo o terreno, mas a água ao redor dela agora reage.
- **Baía de Tortuga ganhou doca de verdade:** extraídas peças de duas pranchas de referência (`Meshy_AI_port_buildings_kit.png`, `Meshy_AI_nautical_props_kit.png`, achadas em `~/Downloads/`, nunca importadas) via um extrator de componentes conectados escrito em Python puro (sem numpy disponível no ambiente) — ferramenta em `/tmp` da sessão, não versionada, mas reaproveitável (gerou ~90 peças isoladas, só ~5 usadas até agora: doca, letreiro "TAVERN/DOCKS/SHIPYARD/MARKET", 2 postes de amarração, barris). Peças importadas em `client/assets/sprites/environment/islands/tortuga_kit/`, posicionadas como filhos diretos de `World` em `ocean_map.tscn` (não dentro de `TortugaHub`) para herdar o `y_sort_enabled` que já existia em `World` e ordenar corretamente contra o navio. Doca tem colisão (`StaticBody2D`).
- Uma tentativa de taverna + torre extraídas do mesmo kit foi revertida: a ilustração original já tem prédios pintados ali, e as peças novas só se perdiam no meio sem ganho visual.
- **Godot MCP Toolkit reconectado** (ferramenta de desenvolvimento, não faz parte do jogo): o bug era a ponte MCP resolvendo o projeto pela chave `/home/lucas/navizin` (raiz do repo) enquanto o editor real registra `/home/lucas/navizin/client` (onde fica o `project.godot`). Corrigido duplicando a entrada no registro (`~/.local/share/godot-mcp-toolkit/projects.json`). **Não commitar** `.mcp.json`, `addons/godot_mcp_toolkit/` nem a seção `[editor_plugins]`/autoload `MCPRuntimeServer` do `project.godot` — são tooling local, não parte do jogo versionado.

**Pendências**
1. Implementar a arquitetura multi-cena descrita acima (`TownHub.tscn` + transição de cena a partir do atracamento).
2. Migrar `TortugaCityHub` (overlay `Control`) e os novos props da baía (doca/letreiro/postes/barris) para dentro da nova `TownHub.tscn`, se fizer sentido no novo fluxo.
3. As outras 3 ilhas do plano original (Ilha das Cavernas, Vilarejo Pirata, Fortificação) e obstáculos de rocha no meio do oceano continuam fora de escopo, aguardando a arquitetura multi-cena estar pronta.

---

## Checkpoint anterior (2026-10-07) — branch `feature/issue-4-ship-movement`, PR #6 para `dev`

**Último commit:** `23dcdbe` (mystic orb bars, Cinzel labels, retrato +25%).

**Módulo atual:** HUD do capitão e física de navegação. A issue #4 segue no PR #6.

**Feito nesta rodada**
- **Escala e vento:** navio em `SPRITE_SCALE` 0.62 (~2.3× o anterior), câmera em zoom 1.3, autoload `WindManager` (direção e força por ruído, sinal `wind_changed`), física com produto escalar (+35% a favor, até -50% contra, deriva lateral também de través).
- **Esteira e proa:** esteira escalada ao galeão; `BowWave` (respingo da proa que empurra a água para os lados).
- **HUD (`scenes/ui/hud.tscn`):** bloco do capitão no canto inferior esquerdo (80% de escala, 16 px de margem), com retrato (+25%) e três barras empilhadas: casco (caveira), suprimentos (barril, consome ao navegar) e vento (rosa). Bússola em código no topo central, a 65% de alfa, só letras cardinais. Minimapa no canto superior direito com a moldura completa. Hotbar 1 a 8 a 50% de escala, com ícones, quantidade e recarga circular (slot 1 = bordada). Barra de menus com 12 botões, hover 1.05, som de clique e atalhos (L, N, B, C, F, R, M, T, I, P, V, K).
- **Tipografia:** Cinzel Bold (OFL) nos rótulos das barras, creme `#F3E5AB`, sombra 1×2 preta. Pirata One (OFL) como fonte padrão do tema (`assets/ui/theme_navizin.tres`).
- **Barras com efeito de orbe:** `assets/shaders/mystic_bar.gdshader` (gradiente líquido, brilho no topo que pulsa, varredura de luz), mascarado pelo alfa da textura da barra.
- **Física do giro:** o leme só gira o casco com velocidade. Parado (abaixo de 1 px/s) a taxa é zero. A curva cresce com a velocidade até `turn_speed`. Função `steering_rate` testada com 6 casos.
- **Dano e suprimento:** `ship_base.gd` emite `hull_changed`, tem `apply_damage()`, `supply`/`max_supply` (1000) e `broadside_ratio()`. Regeneração em ilha (`regen_supply`) existe, mas ainda não há ilhas no mapa.

**Pendências deste checkpoint**
1. Conferir no jogo o tamanho do bloco do capitão, da hotbar e do menu, e a intensidade do brilho/varredura das barras.
2. Janelas do menu (Leme, Munição, Tripulação, Frota, Consumíveis, Mapa, Reconhecimento, Inventário, Perfis) estão com texto "Em construção". Só Rosa dos ventos e Ancorar funcionam.
3. Moldura preta das barras continua com o peso original: reduzir exige repintar a arte.
4. Arte que o usuário citou (`image_f1dae2.png`, `image_f1d64c.png`, `image_f23843.jpg`) não foi encontrada no computador. Usei as barras do kit `464ad6b5…`.
5. Gatilhos de vício: recusados. Não serão implementados.
6. Mundo sem ilhas: o `Terrain` (TileMapLayer) está vazio, à espera dos tilesets do ComfyUI em `assets/sprites/environment/islands/`.
7. Ícone 12 da barra de menus (caveira com ossos) está como "Alertas", em construção.

**Ficheiros de UI novos desta rodada:** `assets/ui/` (frames, bars, icons, theme), `assets/fonts/` (Pirata One, Cinzel), `assets/audio/ui_click.wav`, `scenes/ui/` (hud, captain_status, compass_hud, minimap_hud, hotbar, system_menu_bar, dialog_panel), `scripts/ui/` (hud_controller, compass_tape).

---

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

## Rodada de correções (ghosting, canhões, cooldown, trilhos)
- **Uma vista por vez:** a mistura entre vistas saiu. Ao mudar de setor, a vista atual escurece e a nova clareia (`DIP_SPEED` 9/s). Não há mais `SpriteBlend` nem `ShadowBlend`. A troca só acontece com a imagem quase apagada.
- **Canhões:** `PortCannons` e `StarboardCannons` com três `Marker2D` cada (x = -30, 0, 30; y = ∓10). Os tiros e a fumaça saem do convés (`DECK_OFFSET` = (0, 22) em tela), e não do centro do sprite.
- **Por que os tiros de bombordo cruzam as velas:** a física é de cima e a arte é de lado. O lado de bombordo aponta para cima na tela, por cima das velas. Os projéteis agora passam por trás do navio (`move_child`). A correção definitiva é arte de casco de cima ou de três quartos.
- **Cooldown por bateria:** 2.5 s (`broadside_cooldown` em `ShipData`), independente para cada bordo. Bloqueia o início da carga e o disparo.
- **Mira em trilhos:** faixas paralelas azuis translúcidas (`RAIL_COLOR`, alfa 0.35), perpendiculares ao bordo, uma por canhão, crescendo com a carga. Substituem o arco pontilhado. Limpam ao soltar.
- **Disparo:** segurar só mira. Soltar dispara. Toque rápido ainda dispara a força mínima (`TAP_MIN_POWER` 0.3). Isso é um conflito com o pedido "só dispara ao soltar", que fica em aberto.
- **Leme:** já suavizado com `lerp_angle` na vista (`VISUAL_TURN_RATE`) e com aceleração angular. Mantido.
- **Testes:** suíte `test_v4` com 13 verificações passa (segurar sem disparar, Q+E juntos, cooldown por bateria, origem no convés, uma vista visível, troca sem corte, atraso da vista).

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

## Regras de disparo (sistema anterior restaurado)
- **Mira e disparo:** segurar Q ou o botão esquerdo carrega a bateria de bombordo. Segurar E ou o botão direito carrega a de estibordo. Soltar dispara. A mira começa curta e se estende até o alcance máximo.
- **Mira:** a proa segue o ponteiro quando nenhuma bateria está carregando. Ao carregar, o leme trava, e o lado da bateria vem da posição do cursor em relação ao casco.
- **Cooldown:** independente por bateria (`broadside_cooldown` 2.5 s).
- **Cor da mira:** laranja-avermelhada (`RAIL_COLOR`), para contrastar com o mar escuro.
- **Projétil:** raio 5 px, contorno escuro, borda em brasa e rastro de fumaça amarelada.
- **Limite do mar:** `world_bounds` (padrão 8000×8000 centrado na origem). O navio para na borda.
- **Testes:** suíte `test_v4` com 13 verificações passa.

## Checkpoint (fim da sessão de hoje) — PR #6 em `feature/issue-4-ship-movement`
Estado atual do navio e pendências para amanhã.

**Pronto e validado pelo usuário**
- Movimentação, leme, inércia, mira e disparo (Q/E e botão do mouse), cooldown por bateria, limite do mar.
- Tiros e faixas de mira alinhados à lateral, proporcionais ao casco (canhões em ±25 px, meio-casco 50 px).
- Tabela de direções em `DIR_ENTRIES` (lista ordenada por ângulo), com espelhamento para a metade esquerda.
- Sequências 8 → 8,5 → 9 → 9,5 e 7 → 7,5 → 8 aprovadas; 6,5, 3,5 (frame 13 espelhado), 1,5 e 1,75 aprovados.
- Frames de cabeça para baixo (33,75° e 191,25°) removidos.

**Pendências**
1. **Névoa/espuma atrás do casco:** sai com aparência de quadrado estranho fora do navio. Revisar o `_wake` (textura `_puff`, escala e área) ou trocar por outro efeito. Respingo com gotas pequenas foi testado e rejeitado (parece falha de tela).
2. **Transição entre 6 e 8 (337,5° e 348,75°):** não há frame lateral inclinado para cima sem ficar de cabeça para baixo. Precisa de arte nova ou fica parada.
3. **Frame de 33,75° (entre 6 e 3):** foi removido por estar de cabeça para baixo; falta a animação "depois do 6" para o lado de baixo.
4. **Conferir no jogo** a orientação de 3,5 e 1,5 (frame 13) e os frames espelhados da metade esquerda.
5. **Fumaça dos canhões:** saindo da linha do casco; conferir se está no lugar certo nas direções.

**Commits recentes:** `6fc3c08` (reverte o respingo), `2131758` (remove frames de cabeça para baixo), `d06a7e7` e `a8c9a06` (espuma na popa e na linha d'água).

