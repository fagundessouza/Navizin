class_name ShipStatusModal
extends Control
## Ficha de equipamento do Galeão -- reconstruída nesta rodada em cima da
## nova arte `inventory_background.jpeg` (1600x900, fator de exibição 0.6)
## com Chroma Key de verdade no Viewport central (ver `BlueprintLayer`/
## `chroma_key.gdshader`) revelando a planta `galleon_blueprint.png` por
## trás. Coordenadas medidas na arte de origem com grade de calibração PIL
## (mesmo método de sempre) e convertidas pro fator 0.6.
##
## LEME SAIU DE VEZ (não só escondido): a nova arte não tem mais um
## caixilho pra ele -- consistente com a decisão já tomada antes de tirá-lo
## da Forja/Estaleiro "até ter arte" (STATE.md). `ItemDatabase` continua com
## a categoria `leme` registrada, só não tem slot nenhum pra equipar aqui.
##
## CANHÃO PRINCIPAL != grade de 20: a nova arte só tem 1 caixilho de canhão
## nos slots laterais + 1 box "Canhão Principal" maior embaixo à direita --
## os 2 mostram o MESMO dado (`ShipInventory.equipped_cannons[0]`), não uma
## 6ª peça de equipamento nova. A grade de 20 canhões inteira (preservada
## sem mudança nenhuma na lógica) virou um painel à parte
## (`CannonManagePanel`), aberto pelo botão "Gerenciar Canhões" -- a arte
## nova simplesmente não tem espaço pra mostrar as 20 de uma vez no painel
## principal.
##
## INVENTÁRIO DO NAVIO (18 slots, não 24): a arte entregue desenha uma
## grade de 3 linhas x 6 colunas = 18 caixas de caveira, não as "24 (4x6)"
## descritas no pedido -- contado caixa por caixa na imagem antes de
## escrever este número (mesma disciplina de "a grade de canhões também já
## foi descrita errado uma vez, usa o que tá desenhado"). Mostra os itens do
## Navio NÃO equipados (mesmo dado da aba "Itens do Navio" do `VaultModal`),
## só leitura (clicar não equipa -- equipar continua pelos 4 slots
## dedicados + grade de canhão). SEM DRAG & DROP: nenhum sistema de
## arrastar item existe em lugar nenhum do projeto ainda (equipar sempre
## foi clique -> `InventoryPickerSubmodal`) -- o pedido descreve "manter o
## Drag & Drop alinhado" como se já existisse; não foi inventado um sistema
## novo só pra esta grade, documentado aqui em vez de fingir que tem.
##
## MORAL DA TRIPULAÇÃO: sem sistema de moral nenhum no jogo -- em vez de
## inventar um contador novo sem ninguém por trás, a barra usa a fração de
## Marinheiros/Operários ATIVOS (`TavernHireSystem.is_contributing()`) sobre
## o total contratado: 100% cheia com a tripulação toda saudável/alimentada,
## cai de verdade se alguém ficar Ferido/Doente/sem Ração. Dado real
## reaproveitado, não um número solto.
##
## OFICIAIS (8 slots inline): mostra o retrato de `OfficerRoster` direto no
## painel principal (a arte nova desenha os 8 nichos aqui, não mais
## escondidos atrás de um botão de rodapé). Clicar em qualquer nicho ainda
## abre `CrewManagementSubmodal` (contratar/dispensar continua lá, junto
## com a grade de Marinheiros/Operários da Taverna) -- os slots inline aqui
## são iguais, só um atalho visual, não uma 2ª cópia da lógica de contratar.
##
## SUPRIMENTOS (4 slots): a arte já desenha o ícone de cada um (bolas de
## canhão/barris de pólvora/baú/cristal) -- não precisa de um ícone
## sobreposto, só o número por cima + tooltip. Mapeados em dado REAL já
## existente, não inventado pra essa barra: Bolas -> "Esfera de Ferro"
## (material real), Pólvora -> "Pólvora" (material real), Escambo -> "Ouro"
## (moeda de troca real), Talentos -> `CaptainAttributes.available_points`
## (o único "ponto pra gastar" que já existe no jogo -- mesmo número que o
## Painel de Admin usa pra "+5 Pontos de Atributo").
##
## RARIDADE: igual rodadas anteriores, `item_rarity_glow.gdshader` por cima
## de cada slot preenchido, escondido pra White/Green, aceso por raridade/
## Float/Refino pra Blue+.

signal opened
signal closed

const PANEL_SIZE: Vector2 = Vector2(960, 540)
const PICKER_WIDTH_ESTIMATE: float = 226.0
const PICKER_HEIGHT_ESTIMATE: float = 170.0

## 4 slots de peça (Leme removido -- sem caixilho na arte nova).
const CRAFT_SLOTS: Array[Dictionary] = [
	{"category": "vela", "label": "Vela", "cx": 90.0, "cy": 106.2, "w": 60.0, "h": 54.0},
	{"category": "proa", "label": "Proa", "cx": 90.0, "cy": 163.8, "w": 60.0, "h": 54.0},
	{"category": "casco", "label": "Casco", "cx": 438.0, "cy": 126.0, "w": 60.0, "h": 62.4},
	{"category": "relíquia_ebenruth", "label": "Relíquia de Ebenruth", "cx": 438.0, "cy": 205.2, "w": 60.0, "h": 72.0},
]

## Ícone pequeno na coluna esquerda + prévia grande no painel de Canhões e
## Suprimentos -- os 2 mostram `equipped_cannons[0]`, ver nota de classe.
const MASTER_CANNON_SMALL: Dictionary = {"cx": 90.0, "cy": 220.5, "w": 60.0, "h": 51.0}
const MASTER_CANNON_BIG: Dictionary = {"cx": 556.5, "cy": 372.6, "w": 130.0, "h": 82.0}

const GERENCIAR_CANHOES_BUTTON: Dictionary = {"cx": 556.5, "cy": 441.0, "w": 130.0, "h": 32.0}

## Grade de 20 (5x4) dentro do `CannonManagePanel` -- herdada sem mudança
## de coordenada nenhuma da versão anterior (ela tinha espaço próprio
## dedicado lá, não precisa recalibrar pra arte nova já que agora é um
## painel à parte).
const CANNON_COLS: Array[float] = [60.0, 155.0, 250.0, 345.0, 440.0]
const CANNON_ROWS: Array[float] = [40.0, 115.0, 190.0, 265.0]
const CANNON_SLOT_SIZE: float = 60.0

## Inventário do Navio: 18 slots (3 linhas x 6 colunas), ver nota de classe.
const INVENTORY_GRID_ORIGIN: Vector2 = Vector2(514.8, 90.0)
const INVENTORY_CELL_SIZE: Vector2 = Vector2(54.2, 46.4)
const INVENTORY_COLS: int = 6
const INVENTORY_ROWS: int = 3

## 8 nichos de Oficial (4 colunas x 2 linhas).
const OFFICER_COL_X: Array[float] = [111.6, 200.1, 288.9, 377.1]
const OFFICER_ROW: Array[Dictionary] = [
	{"cy": 333.6, "h": 44.4}, {"cy": 399.6, "h": 52.8},
]
const OFFICER_SLOT_W: float = 73.2

## 4 slots de Suprimentos (Bolas/Pólvora/Escambo/Talentos). "Bolas de Canhão"
## CORRIGIDO rodada anterior -- mostrava a contagem do material bruto "Esfera
## de Ferro" (ingrediente de receita, sempre tem 15 de estoque inicial
## mesmo sem ter fabricado munição nenhuma -- o "15 fixo sem sentido"
## relatado). Trocado pra contar MUNIÇÃO DE VERDADE já fabricada
## (`ShipInventory.crafted_items` categoria "municao"), zero até fabricar
## alguma de verdade na Forja.
##
## Suprimentos da Tripulação (rodada "sistemas reais de verdade", não mais
## um atalho pra Munição): o slot de barris agora abre uma tela PRÓPRIA
## (`ShipInfoModal.info_mode = "supplies"`) mostrando a Ração de Bordo --
## achado que `TavernHireSystem` já consumia esse material de verdade a
## cada ciclo (`_consume_food_tick()`, suspende o bônus do marinheiro sem
## ração, afeta a Moral) desde antes, só sem UI nenhuma pra ver. Não foi
## inventado sistema novo nenhum, só exposta a tela que faltava pro que já
## existia.
##
## RECALIBRADO (rodada seguinte, achado investigando o relato "número '5'
## vazando pra fora" via MCP -- não suposto): os `cx` abaixo eram da
## calibração ORIGINAL da arte, feita rodadas atrás, nunca reconferida pixel
## a pixel contra a fonte de verdade. Sampleando `inventory_background.jpeg`
## por cor (o brilho azul do cristal, a madeira do baú) achei que os 4
## ícones de verdade ficam bem mais JUNTOS do que a calibração antiga
## assumia -- centros reais a ~60px local de distância um do outro, não os
## ~76-84px que o código antigo usava. Com o espaçamento antigo largo
## demais, o 4º slot (Talentos) ficava ~100px à direita de onde o cristal
## está desenhado de verdade, caindo na moldura decorativa vazia ao lado --
## por isso o número "5" aparecia fora de qualquer caixa pintada. A correção
## de hitbox de 2 rodadas atrás (`_safe_supply_half_width()`) tratou o
## SINTOMA (encolheu a largura pra não encostar no vizinho) sem corrigir a
## causa (os centros já estavam errados desde o início) -- mantida aqui como
## rede de segurança, agora operando sobre dados corretos.
const SUPPLY_SLOTS: Array[Dictionary] = [
	{"key": "bolas", "cx": 646.5, "cy": 378.7, "material": "", "label": "Munições de Canhão"},
	{"key": "racao", "cx": 708.0, "cy": 378.7, "material": "Ração de Bordo", "label": "Suprimentos da Tripulação"},
	{"key": "escambo", "cx": 768.0, "cy": 378.7, "material": "Ouro", "label": "Mercadorias de Escambo"},
	{"key": "talentos", "cx": 825.9, "cy": 378.7, "material": "", "label": "Árvore de Talentos"},
]
## Largura/altura "ideal" medida na arte (recalibrado junto com os `cx`
## acima -- caixas reais têm ~59px de largura, não 78) -- `_safe_supply_half_width()`
## ainda encolhe isto quando o vizinho tá perto demais (ver nota em
## `_build_supply_slots()`), agora só como rede de segurança extra.
const SUPPLY_SLOT_SIZE: Vector2 = Vector2(58.0, 65.0)
## Folga mínima entre hitboxes vizinhas, pros botões nunca encostarem.
const SUPPLY_SLOT_GUTTER: float = 4.0

const PULSE_SCALE: Vector2 = Vector2(1.3, 1.3)
const GLOW_COLOR: Color = Color(1.4, 1.25, 0.8, 1.0)

const RARITY_GLOW_SHADER: Shader = preload("res://assets/shaders/item_rarity_glow.gdshader")
## Normal/Bom não ganham brilho -- só Excelente/Obra-Prima, como é convenção
## em ARPG (fabricação comum/boa não chama atenção, excelente em diante sim).
const GLOWING_RARITIES: Array[String] = ["blue", "gold"]

@onready var _slots_root: Control = $Slots
@onready var _picker: InventoryPickerSubmodal = $Picker
@onready var _tooltip_zoom: ItemTooltipZoom = $ItemTooltipZoom
## MIGRAÇÃO PRA INSTANCIAÇÃO EM RUNTIME (pedido explícito, reverte a decisão
## anterior desta mesma sessão de manter tudo no editor -- ver `.clauderules`
## e `UIManager._register_modal_scenes()`). `CrewManagementSubmodal`/
## `CargoModal`/`AmmoModal` não são mais filhos fixos do `.tscn`: saem do
## `ModalOverlay` (Control vazio, só reserva o espaço) na primeira vez que
## `_ready()` pede pelo `UIManager`, que cria, guarda e devolve a MESMA
## instância em pedidos seguintes -- o resto do arquivo (`_close_all_submodals()`,
## `.open()`/`.close()`) não muda nada, só QUEM cria o nó mudou.
@onready var _modal_overlay: Control = $ModalOverlay
var _crew_submodal: CrewManagementSubmodal
var _cargo_modal: ShipInfoModal
var _ammo_modal: ShipInfoModal
var _supplies_modal: ShipInfoModal
@onready var _weight_bar: ProgressBar = $WeightBar
@onready var _weight_label: Label = $WeightLabel
@onready var _morale_bar: ProgressBar = $MoraleBar
@onready var _stats_label: Label = $StatsPanel/StatsLabel
@onready var _cannon_panel: Control = $CannonManagePanel
@onready var _cannon_grid_root: Control = $CannonManagePanel/Panel/Margin/VBox/GridScroll/GridBg/GridRoot

var _ship: Node2D = null
## category -> Button, pros 4 slots de peça única.
var _slot_buttons: Dictionary = {}
## category -> ColorRect (overlay de brilho), paralelo a `_slot_buttons`.
var _slot_glows: Dictionary = {}
## índice 0..19 -> Button, pra grade de canhão (dentro do CannonManagePanel).
var _cannon_buttons: Array[Button] = []
## índice 0..19 -> ColorRect (overlay de brilho), paralelo a `_cannon_buttons`.
var _cannon_glows: Array[ColorRect] = []
## Qual canhão (índice) o picker está servindo agora -- só importa quando
## `_picker._category == "armamento"`, já que aí um nome de categoria sozinho
## não diz QUAL dos 20 slots equipar. Também usado pelos 2 atalhos de
## "Canhão Principal" (sempre índice 0).
var _pending_cannon_index: int = -1
var _master_cannon_small: Button
var _master_cannon_small_glow: ColorRect
var _master_cannon_big: Button
var _master_cannon_big_glow: ColorRect
var _officer_buttons: Array[Button] = []
var _inventory_cells: Array[Control] = []
var _supply_buttons: Array[Button] = []
var _glow_phase_counter: int = 0


func _ready() -> void:
	visible = false
	_crew_submodal = UIManager.get_modal("crew_management", _modal_overlay, func(m): m.read_only = true) as CrewManagementSubmodal
	_cargo_modal = UIManager.get_modal("cargo", _modal_overlay) as ShipInfoModal
	_ammo_modal = UIManager.get_modal("ammo", _modal_overlay, func(m): m.info_mode = "ammo") as ShipInfoModal
	_supplies_modal = UIManager.get_modal("supplies", _modal_overlay, func(m): m.info_mode = "supplies") as ShipInfoModal
	$CloseButton.pressed.connect(close)
	$CannonManagePanel/Panel/Margin/VBox/Header/CloseButton.pressed.connect(_close_cannon_panel)
	_build_craft_slots()
	_build_master_cannon_shortcuts()
	_build_cannon_grid()
	_build_officer_slots()
	_build_inventory_grid()
	_build_supply_slots()
	_picker.instance_selected.connect(_on_instance_selected)
	ShipInventory.changed.connect(_refresh_slot_labels)
	TavernHireSystem.changed.connect(_update_morale_bar)
	CaptainAttributes.changed.connect(_on_attributes_changed)
	OfficerRoster.changed.connect(_refresh_officer_slots)
	_refresh_slot_labels()
	_update_morale_bar()
	# Legibilidade (pedido explícito -- fonte padrão do tema é decorativa,
	# ilegível em corpo pequeno). Só os rótulos construídos por código desta
	# cena -- os de `CannonManagePanel`/outras modais já são tratados onde
	# são montados.
	UIManager.apply_readable_font(_weight_label, 11)
	UIManager.apply_readable_font(_stats_label, 14)


func _process(_delta: float) -> void:
	if not visible:
		return
	if _ship == null:
		_ship = get_tree().get_first_node_in_group("player_ship") as Node2D
	_update_weight_bar()
	_update_stats_label()


func open() -> void:
	visible = true
	# Rede de segurança (não a causa raiz -- ver nota em `_build_supply_slots()`):
	# se QUALQUER slot reusado ficar preso numa escala de hover de uma sessão
	# anterior por algum motivo que escapou da correção acima, reabrir o
	# painel sempre garante estado limpo em vez de carregar a distorção
	# adiante.
	for button in _supply_buttons:
		button.scale = Vector2.ONE
	UIManager.animate_modal_open(self)
	_refresh_inventory_grid()
	_refresh_supply_slots()
	opened.emit()


func close() -> void:
	_picker.close()
	_close_all_submodals()
	visible = false
	closed.emit()


func _build_craft_slots() -> void:
	for data in CRAFT_SLOTS:
		var button := _make_slot_button(data["cx"], data["cy"], data["w"], data["h"], data["label"])
		var category: String = data["category"]
		button.pressed.connect(_on_slot_pressed.bind(button, category, data["label"]))
		button.mouse_entered.connect(_on_slot_hover.bind(button, func(): return ShipInventory.equipped.get(category, "")))
		button.mouse_exited.connect(_tooltip_zoom.hide_tooltip)
		_slot_buttons[category] = button
		_slot_glows[category] = _make_rarity_glow(button, _next_glow_phase())


## 2 PRÉVIAS visuais (ícone pequeno na lateral + box grande no painel de
## Canhões e Suprimentos) do MESMO slot de canhão índice 0 -- ver nota de
## classe. SEM equipar direto daqui (pedido explícito -- "REMOVA qualquer
## duplicação de funcionalidade entre o slot Canhão Principal e a sub-janela
## Gerenciar Canhões"): antes clicar aqui abria o picker pro slot 0 na hora,
## um 2º caminho pra equipar cannon que não passava pela janela de
## gerenciamento. Agora os 2 só mostram o item (hover/tooltip) e, ao
## clicar, abrem `CannonManagePanel` -- "GERENCIAR CANHÕES" É a única porta
## de entrada pra equipar canhão, como pedido.
func _build_master_cannon_shortcuts() -> void:
	_master_cannon_small = _make_slot_button(MASTER_CANNON_SMALL["cx"], MASTER_CANNON_SMALL["cy"], MASTER_CANNON_SMALL["w"], MASTER_CANNON_SMALL["h"], "Canhão Principal")
	_master_cannon_small.pressed.connect(_open_cannon_panel)
	_master_cannon_small.mouse_entered.connect(_on_slot_hover.bind(_master_cannon_small, func(): return ShipInventory.equipped_cannons[0]))
	_master_cannon_small.mouse_exited.connect(_tooltip_zoom.hide_tooltip)
	UIManager.add_hover_pop(_master_cannon_small, "canhao_principal_mini")
	_master_cannon_small_glow = _make_rarity_glow(_master_cannon_small, _next_glow_phase())

	_master_cannon_big = _make_slot_button(MASTER_CANNON_BIG["cx"], MASTER_CANNON_BIG["cy"], MASTER_CANNON_BIG["w"], MASTER_CANNON_BIG["h"], "Canhão Principal")
	_master_cannon_big.pressed.connect(_open_cannon_panel)
	_master_cannon_big.mouse_entered.connect(_on_slot_hover.bind(_master_cannon_big, func(): return ShipInventory.equipped_cannons[0]))
	_master_cannon_big.mouse_exited.connect(_tooltip_zoom.hide_tooltip)
	UIManager.add_hover_pop(_master_cannon_big, "canhao_principal_preview")
	_master_cannon_big_glow = _make_rarity_glow(_master_cannon_big, _next_glow_phase())

	var manage_button := Button.new()
	manage_button.flat = true
	var w: float = GERENCIAR_CANHOES_BUTTON["w"]
	var h: float = GERENCIAR_CANHOES_BUTTON["h"]
	manage_button.custom_minimum_size = Vector2(w, h)
	manage_button.position = Vector2(GERENCIAR_CANHOES_BUTTON["cx"] - w / 2.0, GERENCIAR_CANHOES_BUTTON["cy"] - h / 2.0)
	manage_button.size = Vector2(w, h)
	manage_button.tooltip_text = "Gerenciar Canhões"
	manage_button.pressed.connect(_open_cannon_panel)
	UIManager.add_hover_pop(manage_button, "gerenciar_canhoes")
	_slots_root.add_child(manage_button)


func _open_cannon_panel() -> void:
	_close_all_submodals()
	_update_cannon_slot_capacity()
	_cannon_panel.visible = true
	_cannon_panel.move_to_front()
	UIManager.animate_modal_open(_cannon_panel.get_node("Panel"))


func _close_cannon_panel() -> void:
	_cannon_panel.visible = false


## Constrói sempre os `ShipInventory.CANNON_SLOT_COUNT` (20) slots possíveis
## -- o teto de verdade por navio (`ShipData.cannon_slot_capacity`) decide
## quantos ficam VISÍVEIS, não quantos EXISTEM (ver `_update_cannon_slot_capacity()`).
## Mais simples e seguro que criar/destruir Button em tempo de execução toda
## vez que o navio do jogador mudar, e `equipped_cannons` já é um array de
## tamanho fixo (20) por trás de qualquer jeito.
func _build_cannon_grid() -> void:
	var index: int = 0
	for row_y in CANNON_ROWS:
		for col_x in CANNON_COLS:
			var button := _make_slot_button_in(_cannon_grid_root, col_x, row_y, CANNON_SLOT_SIZE, CANNON_SLOT_SIZE, "Armamento")
			# Diferente de todo outro slot deste painel, `CannonManagePanel` não
			# senta sobre arte pintada com o caixilho já desenhado -- sem um
			# fundo próprio aqui, um slot vazio é um botão `flat` invisível (só
			# o equipado aparece, por causa do ícone+brilho). Achado rodando o
			# jogo de verdade: só o slot 0 (equipado) aparecia na captura.
			_apply_plain_slot_frame(button)
			var cannon_index: int = index
			button.pressed.connect(_on_cannon_pressed.bind(button, cannon_index))
			button.mouse_entered.connect(_on_slot_hover.bind(button, func(): return ShipInventory.equipped_cannons[cannon_index]))
			button.mouse_exited.connect(_tooltip_zoom.hide_tooltip)
			_cannon_buttons.append(button)
			_cannon_glows.append(_make_rarity_glow(button, _next_glow_phase()))
			index += 1
	_cannon_grid_root.custom_minimum_size = Vector2(CANNON_COLS[-1] + CANNON_SLOT_SIZE + 20.0, CANNON_ROWS[-1] + CANNON_SLOT_SIZE + 20.0)


## "A quantidade de slots deve corresponder à capacidade total do navio
## atual" (pedido explícito) -- `ShipData.cannon_slot_capacity`, campo novo
## separado de `cannon_count` (dano de combate). Esconde os slots além do
## teto em vez de escondê-los por `visible=false` de árvore (`_cannon_buttons`
## continua tendo 20 sempre -- só a VISIBILIDADE muda, nunca o array).
func _update_cannon_slot_capacity() -> void:
	var capacity: int = ShipInventory.CANNON_SLOT_COUNT
	if _ship != null and _ship.data != null:
		capacity = clampi(_ship.data.cannon_slot_capacity, 0, ShipInventory.CANNON_SLOT_COUNT)
	for i in _cannon_buttons.size():
		_cannon_buttons[i].visible = i < capacity


## 8 nichos inline (ver nota de classe) -- cada um mostra o retrato de
## `OfficerRoster.portrait_path(cargo)` quando contratado, ou fica vazio.
## Clicar em qualquer um abre `CrewManagementSubmodal` (onde contratar/
## dispensar/trocar de verdade acontece).
##
## CORREÇÃO (pedido explícito -- "atualizar a lista de Oficiais em tempo
## real, sem fechar/reabrir"): a versão anterior montava os 8 botões uma vez
## em `_ready()` e nunca mais tocava neles -- contratar um Oficial em
## `CrewManagementSubmodal` nunca refletia aqui até fechar e reabrir o
## painel inteiro. `OfficerRoster.changed` agora chama
## `_refresh_officer_slots()`, que troca o retrato/tooltip de cada nicho na
## hora.
func _build_officer_slots() -> void:
	for i in OfficerRoster.ROLES.size():
		if i >= OFFICER_COL_X.size() * OFFICER_ROW.size():
			break
		var col: int = i % OFFICER_COL_X.size()
		var row: int = i / OFFICER_COL_X.size()
		var cx: float = OFFICER_COL_X[col]
		var row_data: Dictionary = OFFICER_ROW[row]
		var role: String = OfficerRoster.ROLES[i]
		var button := _make_slot_button(cx, row_data["cy"], OFFICER_SLOT_W, row_data["h"], OfficerRoster.ROLE_NAMES[role])
		button.pressed.connect(func(): _close_all_submodals(); UIManager.open_modal(_crew_submodal))
		UIManager.add_hover_pop(button, "officer_%s" % role)
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.visible = false
		button.add_child(portrait)
		_officer_buttons.append(button)
	_refresh_officer_slots()


func _refresh_officer_slots() -> void:
	for i in _officer_buttons.size():
		var role: String = OfficerRoster.ROLES[i]
		var button: Button = _officer_buttons[i]
		var portrait: TextureRect = button.get_node("Portrait")
		var hired: bool = OfficerRoster.is_hired(role)
		portrait.visible = hired
		if hired:
			portrait.texture = load(OfficerRoster.portrait_path(role))
			button.tooltip_text = "%s\n%s" % [OfficerRoster.ROLE_NAMES[role], OfficerRoster.race_label(role)]
		else:
			portrait.texture = null
			button.tooltip_text = "%s (vago)" % OfficerRoster.ROLE_NAMES[role]


## Grade de leitura do Inventário do Navio (ver nota de classe -- 18 slots,
## sem drag & drop, clicar só mostra tooltip/zoom). Reconstruída toda vez
## que abre (`open()` chama `_refresh_inventory_grid()`) porque o conjunto
## de itens não-equipados muda a cada craft/equipar.
func _build_inventory_grid() -> void:
	for row in INVENTORY_ROWS:
		for col in INVENTORY_COLS:
			var x: float = INVENTORY_GRID_ORIGIN.x + col * INVENTORY_CELL_SIZE.x
			var y: float = INVENTORY_GRID_ORIGIN.y + row * INVENTORY_CELL_SIZE.y
			var cell := Button.new()
			cell.flat = true
			cell.custom_minimum_size = INVENTORY_CELL_SIZE
			cell.position = Vector2(x, y)
			cell.size = INVENTORY_CELL_SIZE
			cell.mouse_filter = Control.MOUSE_FILTER_PASS
			_slots_root.add_child(cell)
			_inventory_cells.append(cell)


func _refresh_inventory_grid() -> void:
	var unequipped: Array[Dictionary] = []
	var equipped_ids: Array = ShipInventory.equipped.values() + ShipInventory.equipped_cannons
	for instance_id in ShipInventory.crafted_items:
		if not equipped_ids.has(instance_id):
			unequipped.append(ShipInventory.crafted_items[instance_id])

	for i in _inventory_cells.size():
		var cell: Button = _inventory_cells[i]
		for child in cell.get_children():
			child.queue_free()
		cell.tooltip_text = ""
		if i >= unequipped.size():
			cell.remove_meta("instance_id")
			continue
		var entry: Dictionary = unequipped[i]
		var instance_id: String = entry["instance_id"]
		var icon_rect := TextureRect.new()
		icon_rect.texture = ShipInventory.get_item_icon(instance_id)
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon_rect)
		var rarity: Dictionary = ShipInventory.get_item_rarity(instance_id)
		cell.tooltip_text = "[%s] %s" % [rarity["name"], ShipInventory.get_item_name(instance_id)]
		cell.set_meta("instance_id", instance_id)
		if not cell.pressed.is_connected(_on_inventory_cell_pressed):
			cell.pressed.connect(_on_inventory_cell_pressed.bind(cell))
		if not cell.mouse_entered.is_connected(_on_inventory_cell_hover):
			cell.mouse_entered.connect(_on_inventory_cell_hover.bind(cell))
			cell.mouse_exited.connect(_tooltip_zoom.hide_tooltip)
			UIManager.add_hover_pop(cell, "inventory_cell_%d" % i)


func _on_inventory_cell_pressed(cell: Button) -> void:
	if cell.has_meta("instance_id"):
		_pulse(cell)


func _on_inventory_cell_hover(cell: Button) -> void:
	if not cell.has_meta("instance_id"):
		return
	_tooltip_zoom.show_for_instance(cell.get_meta("instance_id"), cell.position + Vector2(cell.size.x, 0), PANEL_SIZE)


## BUG REAL achado e corrigido nesta rodada ("Porão de Carga abrindo no
## lugar de Talentos" relatado): nenhum destes 4 handlers fechava os OUTROS
## sub-modais antes de abrir o seu -- clicar Escambo (abre Carga) e depois
## Talentos (abre a Ficha do Capitão) sem fechar o primeiro deixava os DOIS
## com `visible = true` ao mesmo tempo, empilhados; o que aparecia por cima
## dependia só de ordem de nó, então "cliquei em Talentos" podia continuar
## mostrando o Porão de Carga que nunca tinha sido fechado. Mesmo bug (e
## mesmo tipo de correção) já resolvido uma vez pros 4 botões de rodapé
## antigos (`_close_footer_submodals()`) -- agora `_close_all_submodals()`
## cobre TODOS os sub-modais que este painel pode abrir (incluindo
## `CannonManagePanel` e a Ficha do Capitão), chamado no INÍCIO de cada
## handler, não só os 3 antigos.
##
## Nomes de função explícitos por botão (pedido explícito), não mais um
## `match` genérico -- cada ícone de Suprimentos chama o handler com o nome
## certo.
##
## Pólvora -> `_supplies_modal` (rodada "Suprimentos da Tripulação"):
## expõe a Ração de Bordo que `TavernHireSystem` já consome de verdade (ver
## nota de classe em `ship_info_modal.gd`) -- não é mais um atalho pra tela
## de Munição.
##
## Escambo e Talentos CONTINUAM nas telas reais mais próximas (Porão de
## Carga, Ficha do Capitão): nenhum sistema de Árvore de Talentos existe
## ainda, e Escambo está no meio de virar um sistema de Permuta de verdade
## (rodada em andamento, ver `TradeManager`/`.project/STATE.md`) -- fica
## apontando pro Porão de Carga só até essa tela ficar pronta, não um stub
## fingido no lugar.
func _on_ammo_button_pressed() -> void:
	_close_all_submodals()
	UIManager.open_modal(_ammo_modal)


func _on_supplies_button_pressed() -> void:
	_close_all_submodals()
	UIManager.open_modal(_supplies_modal)


func _on_trade_button_pressed() -> void:
	_close_all_submodals()
	UIManager.open_modal(_cargo_modal)


func _on_talents_button_pressed() -> void:
	_close_all_submodals()
	var captain_modal: Control = get_tree().get_first_node_in_group("captain_profile_modal")
	if captain_modal != null:
		UIManager.open_modal(captain_modal)


func _supply_slot_action(key: String) -> Callable:
	match key:
		"bolas":
			return _on_ammo_button_pressed
		"racao":
			return _on_supplies_button_pressed
		"escambo":
			return _on_trade_button_pressed
		"talentos":
			return _on_talents_button_pressed
		_:
			return func(): pass


## Fecha TODO sub-modal que este painel pode abrir -- chamado no início de
## cada handler de abertura (ver nota acima), pra nunca ter 2 empilhados ao
## mesmo tempo.
func _close_all_submodals() -> void:
	UIManager.close_modal(_cargo_modal)
	UIManager.close_modal(_ammo_modal)
	UIManager.close_modal(_supplies_modal)
	UIManager.close_modal(_crew_submodal)
	_close_cannon_panel()
	var captain_modal: Control = get_tree().get_first_node_in_group("captain_profile_modal")
	if captain_modal != null:
		UIManager.close_modal(captain_modal)


## Encolhe a hitbox de um slot de Suprimentos se o vizinho estiver perto
## demais pra caber a largura "ideal" (`SUPPLY_SLOT_SIZE.x`) + a folga
## mínima dos dois lados. CAUSA RAIZ do bug relatado nesta rodada ("hover no
## 2º slot mostra tooltip do 1º/4º, parecem colidir"): a arte tem os 4
## ícones com espaçamento IRREGULAR entre centros (83.6/83.5/75.5px, não uma
## grade uniforme), e a largura fixa de 78px cabia nos 2 primeiros vãos mas
## invadia a do vizinho em ~2.5px no vão Escambo-Talentos (só 75.5px) --
## naquela faixa invadida, QUALQUER clique/hover ficava ambíguo entre os
## dois botões (o de cima na ordem de inserção dos nós ganhava, por isso o
## sintoma relatado troca os dois). Calculado por vão em vez de um número
## fixo pra nunca mais depender de recalibrar à mão se a arte mudar nos
## próximos ícones.
func _safe_supply_half_width(index: int) -> float:
	var half: float = SUPPLY_SLOT_SIZE.x / 2.0
	var cx: float = SUPPLY_SLOTS[index]["cx"]
	if index > 0:
		var left_gap: float = cx - SUPPLY_SLOTS[index - 1]["cx"]
		half = minf(half, left_gap / 2.0 - SUPPLY_SLOT_GUTTER / 2.0)
	if index < SUPPLY_SLOTS.size() - 1:
		var right_gap: float = SUPPLY_SLOTS[index + 1]["cx"] - cx
		half = minf(half, right_gap / 2.0 - SUPPLY_SLOT_GUTTER / 2.0)
	return half


## 4 slots de Suprimentos -- a arte já desenha o ícone de cada um, só soma
## um Label de quantidade por cima + tooltip (ver nota de classe pro
## mapeamento de cada um a um dado real). Isolados dentro de um `SupplySlots`
## Control dedicado (pedido explícito -- "insira os 4 slots dentro de um
## container"), cada botão com hitbox calculada por `_safe_supply_half_width()`
## pra NUNCA encostar na do vizinho, e `mouse_filter = MOUSE_FILTER_STOP`
## explícito (já era o padrão de `Button`, mas declarado aqui sem depender
## de default implícito).
func _build_supply_slots() -> void:
	var container := Control.new()
	container.name = "SupplySlots"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left: float = SUPPLY_SLOTS[0]["cx"] - SUPPLY_SLOT_SIZE.x / 2.0
	var right: float = SUPPLY_SLOTS[-1]["cx"] + SUPPLY_SLOT_SIZE.x / 2.0
	var top: float = SUPPLY_SLOTS[0]["cy"] - SUPPLY_SLOT_SIZE.y / 2.0
	container.position = Vector2(left, top)
	container.size = Vector2(right - left, SUPPLY_SLOT_SIZE.y)
	_slots_root.add_child(container)

	for i in SUPPLY_SLOTS.size():
		var data: Dictionary = SUPPLY_SLOTS[i]
		var half_w: float = _safe_supply_half_width(i)
		var w: float = half_w * 2.0
		var button := Button.new()
		button.flat = true
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.custom_minimum_size = Vector2(w, SUPPLY_SLOT_SIZE.y)
		button.position = Vector2(data["cx"] - half_w - container.position.x, 0.0)
		button.size = Vector2(w, SUPPLY_SLOT_SIZE.y)
		button.tooltip_text = data["label"]
		button.pressed.connect(_supply_slot_action(data["key"]))
		container.add_child(button)
		# SEM `UIManager.add_hover_pop()` aqui de propósito (causa raiz real de
		# dois bugs relatados -- "número vazando pra fora do quadro" e "mouse
		# pula o 2º slot"): escala no Godot também aumenta a HITBOX de clique
		# do Control, não só o visual. Nesta fileira especificamente os slots
		# têm só 4-8px de folga entre vizinhos (`_safe_supply_half_width()`)
		# -- um pop de 1.08x nessa margem apertada é o bastante pra invadir o
		# vizinho, e se o `mouse_exited` não disparar a tempo (achado restando
		# preso em escala 1.08 num teste ao vivo via MCP, bem depois do mouse
		# ter saído) o botão fica permanentemente maior, empurrando o próprio
		# Label de quantidade pra fora da caixa pintada na arte -- exatamente
		# o "5 flutuando" relatado. Mantém só a etiqueta de debug (F3) sem o
		# `mouse_entered`/`mouse_exited` que causa o resto.
		button.set_meta(AdminManager.DEBUG_ID_META, "supply_%s" % data["key"])
		_supply_buttons.append(button)

		var qty_label := Label.new()
		qty_label.name = "Qty"
		qty_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		qty_label.offset_top = -18
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6, 1.0))
		qty_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		qty_label.add_theme_constant_override("shadow_offset_x", 1)
		qty_label.add_theme_constant_override("shadow_offset_y", 1)
		UIManager.apply_readable_font(qty_label, 13)
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(qty_label)


## Talentos (4º slot de Suprimentos) lê `CaptainAttributes.available_points`
## direto -- sem isto, gastar/ganhar pontos na Ficha do Capitão não
## atualizava o número aqui até o painel fechar e reabrir.
func _on_attributes_changed() -> void:
	if visible:
		_refresh_supply_slots()


func _refresh_supply_slots() -> void:
	for i in SUPPLY_SLOTS.size():
		var data: Dictionary = SUPPLY_SLOTS[i]
		var button: Button = _supply_buttons[i]
		var qty_label: Label = button.get_node("Qty")
		var qty: int
		match data["key"]:
			"talentos":
				qty = CaptainAttributes.available_points
			"bolas":
				qty = _count_crafted_by_category("municao")
			_:
				qty = int(ShipInventory.materials.get(data["material"], 0))
		qty_label.text = str(qty)


func _count_crafted_by_category(category: String) -> int:
	var count: int = 0
	for instance_id in ShipInventory.crafted_items:
		var item_id: String = ShipInventory.crafted_items[instance_id]["item_id"]
		if ItemDatabase.get_item(item_id).get("category", "") == category:
			count += 1
	return count


## Fração de Marinheiros/Operários ATIVOS sobre o total contratado -- ver
## nota de classe. Sem tripulação nenhuma contratada ainda, mostra cheia
## (nada puxando o moral pra baixo porque não tem ninguém pra avaliar).
func _update_morale_bar() -> void:
	if TavernHireSystem.hired.is_empty():
		_morale_bar.value = 1.0
		return
	var active: int = 0
	for entry in TavernHireSystem.hired:
		if TavernHireSystem.is_contributing(entry):
			active += 1
	_morale_bar.value = float(active) / float(TavernHireSystem.hired.size())


## Zoom de alta resolução no item equipado -- pedido explícito ("ao passar o
## mouse sobre qualquer ícone de item no craft ou inventário"). Slot vazio
## não mostra nada (sem item fabricado pra dar zoom). O getter é uma lambda
## porque o instance_id equipado pode mudar entre um hover e outro, sem
## precisar reconectar o sinal toda vez que `ShipInventory` muda.
func _on_slot_hover(button: Button, get_instance_id: Callable) -> void:
	var instance_id: String = get_instance_id.call()
	if instance_id == "":
		return
	var local_pos: Vector2 = button.position
	_tooltip_zoom.show_for_instance(instance_id, local_pos + Vector2(button.size.x, 0), PANEL_SIZE)


## Fase inicial do pulso de cada slot, pra uma grade de 20 canhões não piscar
## toda em uníssono -- 0.37 é só um passo irracional-o-bastante pra não
## alinhar período nenhum dentro de 25 slots.
func _next_glow_phase() -> float:
	_glow_phase_counter += 1
	return fmod(float(_glow_phase_counter) * 0.37, TAU)


func _make_slot_button(cx: float, cy: float, w: float, h: float, label: String) -> Button:
	return _make_slot_button_in(_slots_root, cx, cy, w, h, label)


## Fundo/borda simples pra um slot que não tem caixilho pintado por trás
## (só `CannonManagePanel` precisa disso -- todo o resto do painel principal
## já senta em cima da arte nova, que já desenha a moldura de cada nicho).
func _apply_plain_slot_frame(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.4, 0.22, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	button.flat = false
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _make_slot_button_in(parent: Control, cx: float, cy: float, w: float, h: float, label: String) -> Button:
	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(w, h)
	button.position = Vector2(cx - w / 2.0, cy - h / 2.0)
	button.size = Vector2(w, h)
	button.tooltip_text = label
	parent.add_child(button)
	UIManager.add_hover_pop(button, label)
	return button


## Overlay de brilho de raridade: um `ColorRect` do tamanho exato do slot,
## filho dele (segue posição/escala do pulso de clique de graça), ignorando
## mouse pra nunca roubar o clique do botão por baixo. Começa escondido --
## `_refresh_slots()` decide se/como aparece.
func _make_rarity_glow(button: Button, phase: float) -> ColorRect:
	var glow := ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.color = Color.WHITE
	glow.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = RARITY_GLOW_SHADER
	mat.set_shader_parameter("phase_offset", phase)
	glow.material = mat
	button.add_child(glow)
	return glow


func _on_slot_pressed(button: Button, category: String, label: String) -> void:
	_pending_cannon_index = -1
	_pulse(button)
	_open_picker_near(button, category, label)


func _on_cannon_pressed(button: Button, index: int) -> void:
	_pending_cannon_index = index
	_pulse(button)
	_open_picker_near(button, "armamento", "Armamento (slot %d)" % (index + 1))


func _on_instance_selected(category: String, instance_id: String) -> void:
	if category == "armamento":
		if _pending_cannon_index >= 0:
			ShipInventory.equip_cannon(_pending_cannon_index, instance_id)
		_pending_cannon_index = -1
	else:
		ShipInventory.equip_slot(category, instance_id)


## Reescreve o tooltip de cada slot (nome do item + raridade entre
## colchetes, já que `tooltip_text` não aceita cor) e liga/desliga o brilho
## de raridade -- chamado em `_ready()` e toda vez que `ShipInventory.changed`
## dispara, pra refletir equipar/fabricar/trocar.
func _refresh_slot_labels() -> void:
	for data in CRAFT_SLOTS:
		var category: String = data["category"]
		var instance_id: String = ShipInventory.equipped.get(category, "")
		_refresh_one_slot(_slot_buttons[category], _slot_glows[category], instance_id, data["label"])

	var master_id: String = ShipInventory.equipped_cannons[0]
	_refresh_one_slot(_master_cannon_small, _master_cannon_small_glow, master_id, "Canhão Principal")
	_refresh_one_slot(_master_cannon_big, _master_cannon_big_glow, master_id, "Canhão Principal")

	for i in _cannon_buttons.size():
		var instance_id: String = ShipInventory.equipped_cannons[i]
		_refresh_one_slot(_cannon_buttons[i], _cannon_glows[i], instance_id, "Armamento (slot %d)" % (i + 1))

	if visible:
		_refresh_inventory_grid()
		_refresh_supply_slots()


func _refresh_one_slot(button: Button, glow: ColorRect, instance_id: String, empty_label: String) -> void:
	var item_name: String = ShipInventory.get_item_name(instance_id)
	if item_name == "":
		button.tooltip_text = empty_label
		glow.visible = false
		return

	var rarity: Dictionary = ShipInventory.get_item_rarity(instance_id)
	var float_line: String = ShipInventory.get_float_tooltip_line(instance_id)
	button.tooltip_text = "%s\n[%s] %s\n%s" % [empty_label, rarity["name"], item_name, float_line]

	var refine_level: int = ShipInventory.get_refine_level(instance_id)
	var float_value: float = ShipInventory.get_float_value(instance_id)
	var aura_mode: int = _aura_mode_for(instance_id, rarity, float_value, refine_level)
	# Brilho aparece se a RARIDADE já pedia (Blue+) OU se o Float/Refino
	# sozinho já rendeu uma aura -- um item White com Float 0.99 não devia
	# ficar sem brilho nenhum só porque a raridade não ajudou.
	if GLOWING_RARITIES.has(rarity["id"]) or aura_mode != 0:
		glow.visible = true
		var mat: ShaderMaterial = glow.material
		mat.set_shader_parameter("rarity_color", rarity["color"])
		mat.set_shader_parameter("aura_mode", aura_mode)
		mat.set_shader_parameter("refine_boost", _refine_boost_for(refine_level))
	else:
		glow.visible = false


## Prioridade: Relíquia/Equipamento Secundário com Float ou Refino alto ->
## rúnico (o tipo de item manda); senão Float quase Perfeito (>=0.95) ->
## fogo sombrio; senão Refino >= +10 OU a qualidade já pedia faísca
## (Excelente/Obra-Prima) -> elétrico; senão nada além do pulso comum.
func _aura_mode_for(instance_id: String, rarity: Dictionary, float_value: float, refine_level: int) -> int:
	var item_id: String = ShipInventory.crafted_items.get(instance_id, {}).get("item_id", "")
	var category: String = ItemDatabase.get_item(item_id).get("category", "")
	var is_mystic: bool = category == "relíquia_ebenruth" or category == "secundaria"
	var default_aura: int = rarity.get("default_aura", 0)
	if is_mystic and (float_value >= 0.90 or refine_level >= 10):
		return 3  # AURA_RUNIC
	if float_value >= 0.95:
		return 2  # AURA_DARK_FIRE
	if refine_level >= 10:
		return default_aura if default_aura != 0 else 1  # a raridade escolhe (Lendário/Divino), senão elétrico genérico
	if default_aura != 0:
		return default_aura
	return 0  # AURA_NONE


## +10 pra cima intensifica as faíscas (pedido explícito) -- 0 até +9, sobe
## em rampa de +10 a +15 até o teto de 2.0 que o shader aceita.
func _refine_boost_for(refine_level: int) -> float:
	return clampf(float(refine_level - 9) / 6.0, 0.0, 1.0) * 2.0


func _pulse(button: Button) -> void:
	button.pivot_offset = button.size * 0.5
	var tw := create_tween()
	tw.tween_property(button, "scale", PULSE_SCALE, 0.08)
	tw.parallel().tween_property(button, "modulate", GLOW_COLOR, 0.08)
	tw.tween_property(button, "scale", Vector2.ONE, 0.14)
	tw.parallel().tween_property(button, "modulate", Color.WHITE, 0.14)


func _open_picker_near(button: Button, category: String, label: String) -> void:
	var pos: Vector2 = button.position
	var size: Vector2 = button.size
	var open_x: float
	if pos.x + size.x / 2.0 > PANEL_SIZE.x / 2.0:
		open_x = pos.x - PICKER_WIDTH_ESTIMATE - 8.0
	else:
		open_x = pos.x + size.x + 8.0
	var open_y: float = pos.y
	if open_y + PICKER_HEIGHT_ESTIMATE > PANEL_SIZE.y - 10.0:
		open_y = PANEL_SIZE.y - PICKER_HEIGHT_ESTIMATE - 10.0
	_picker.open_at(Vector2(open_x, open_y), category, label)


## `ShipData.cargo_weight`/`max_cargo` -- mesmo dado que já reduz a
## velocidade máxima do navio em `effective_max_factor()`, não um número
## novo inventado só pra essa barra.
func _update_weight_bar() -> void:
	if _ship == null or _ship.data == null:
		return
	var data: ShipData = _ship.data
	_weight_bar.max_value = data.max_cargo
	_weight_bar.value = data.cargo_weight
	_weight_label.text = "Peso: %d/%d" % [int(data.cargo_weight), int(data.max_cargo)]


## Os 4 atributos reais recalculados por `ship_base.gd.recalc_equipment_bonuses()`
## -- não é um resumo cosmético, são os valores que o navio está usando de
## verdade pra velocidade/casco/carga (o dano só não tem onde ser testado em
## combate ainda, mas o número já é o que um sistema de dano usaria).
func _update_stats_label() -> void:
	if _ship == null:
		return
	_stats_label.text = "Dano: %.2fx   Velocidade: %d px/s   Casco Máx: %d   Carga Máx: %d" % [
		_ship.cannon_damage_mult,
		int(_ship.data.max_speed),
		int(_ship.max_hull),
		int(_ship.data.max_cargo),
	]
