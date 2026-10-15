class_name ShipStatusModal
extends Control
## Ficha de equipamento do Galeão: 5 slots de peça de craft (Vela, Casco,
## Leme, Proa, Relíquia de Ebenruth), uma grade de canhões, a barra de peso
## da carga e 4 botões de rodapé -- montados sobre a arte
## `galleon_warship_status_panel.png`, que já vem com a moldura e os '+'
## desenhados em cada slot; os botões daqui são só a área de clique.
##
## Coordenadas medidas na arte de origem (1536x864, grade de calibração +
## detecção de blob dourado pros centros da grade de canhão) e convertidas
## pra escala de exibição (960x540, fator 0.625) -- mesmo método de
## `captain_profile_modal.gd`.
##
## NOTA: o pedido original descrevia a grade de canhões como "24 (6x4)", mas
## a arte entregue só tem 20 (5x4) -- usado o que está desenhado, não o que
## foi descrito, pra não inventar uma 6ª coluna que não existe na imagem.
##
## Os 2 círculos grandes "+" nas pontas do rodapé e a bússola decorativa no
## topo do pergaminho (visíveis na arte) nunca tiveram botão nenhum por trás
## -- decorativos, sem função atribuída. Esta rodada veio o pedido explícito
## de escondê-los até que tenham dados de verdade (ver `DECORATIVE_MASKS`/
## `_build_decorative_masks()`): um véu escuro por cima, já que não dá pra
## apagar só aquele pedaço de um PNG já composto sem redesenhar a arte.
##
## EQUIPAR DE VERDADE: cada slot (os 5 de craft + os 20 de canhão) abre o
## `InventoryPickerSubmodal` em modo de equipamento -- ele já sabe ler
## `ShipInventory` sozinho, aqui só processamos `instance_selected` pra
## chamar `ShipInventory.equip_slot()`/`equip_cannon()` com o slot certo
## e atualizar o tooltip. `ShipInventory.changed` (equipar OU fabricar)
## também recalcula os atributos reais do navio via
## `ship_base.gd.recalc_equipment_bonuses()`, mostrados ao vivo em `_stats_label`.
##
## RARIDADE: cada slot ganha um `ColorRect` filho do tamanho dele com
## `item_rarity_glow.gdshader` -- escondido pra slot vazio ou White/Green
## (sem efeito nessas duas), aceso na cor da raridade pra Blue/Yellow/
## Orange (pulso) e com `lightning=true` pra Purple/Red (faíscas na borda).
## Tooltip também ganha o nome da raridade entre colchetes, já que
## `tooltip_text` é texto puro (sem cor) no Godot.
##
## REFINO: `ShipInventory.get_item_name()` já devolve o nome com o
## prefixo "[+N]" quando refinado, então nenhuma mudança extra precisou
## aqui pra isso aparecer no tooltip. O que SIM é calculado aqui é
## `_refine_boost_for()`, que só liga a partir de +10 (pedido explícito) e
## intensifica o shader de brilho/faísca -- a refinada +15 de uma Obra-Prima
## pulsa e faísca muito mais forte que a mesma peça recém-equipada em +0.

signal opened
signal closed

const PANEL_SIZE: Vector2 = Vector2(960, 540)
const PICKER_WIDTH_ESTIMATE: float = 226.0
const PICKER_HEIGHT_ESTIMATE: float = 170.0

const CRAFT_SLOTS: Array[Dictionary] = [
	{"category": "vela", "label": "Vela", "cx": 178.1, "cy": 115.6, "size": 50.0},
	{"category": "casco", "label": "Casco", "cx": 378.1, "cy": 115.6, "size": 50.0},
	{"category": "proa", "label": "Proa", "cx": 483.1, "cy": 196.9, "size": 50.0},
	{"category": "leme", "label": "Leme", "cx": 178.1, "cy": 333.1, "size": 50.0},
	{"category": "relíquia_ebenruth", "label": "Relíquia de Ebenruth", "cx": 460.6, "cy": 333.1, "size": 50.0},
]

const CANNON_COLS: Array[float] = [572.5, 630.0, 687.5, 743.8, 801.9]
const CANNON_ROWS: Array[float] = [115.0, 195.0, 275.0, 349.4]
const CANNON_SLOT_SIZE: float = 34.0

const FOOTER_BUTTONS: Array[Dictionary] = [
	{"label": "Porão de Carga", "cx": 281.3, "cy": 436.3},
	{"label": "Munição", "cx": 346.9, "cy": 436.3},
	{"label": "Tripulação", "cx": 415.6, "cy": 436.3},
	{"label": "Diário de Navegação", "cx": 484.4, "cy": 436.3},
]
const FOOTER_BUTTON_SIZE: float = 46.0

const PULSE_SCALE: Vector2 = Vector2(1.3, 1.3)
const GLOW_COLOR: Color = Color(1.4, 1.25, 0.8, 1.0)

const RARITY_GLOW_SHADER: Shader = preload("res://assets/shaders/item_rarity_glow.gdshader")
## Normal/Bom não ganham brilho -- só Excelente/Obra-Prima, como é convenção
## em ARPG (fabricação comum/boa não chama atenção, excelente em diante sim).
const GLOWING_RARITIES: Array[String] = ["blue", "gold"]

@onready var _slots_root: Control = $Slots
@onready var _footer_root: Control = $Footer
@onready var _picker: InventoryPickerSubmodal = $Picker
@onready var _tooltip_zoom: ItemTooltipZoom = $ItemTooltipZoom
@onready var _crew_submodal: CrewManagementSubmodal = $CrewManagementSubmodal
@onready var _cargo_modal: ShipInfoModal = $CargoModal
@onready var _ammo_modal: ShipInfoModal = $AmmoModal
@onready var _log_modal: ShipInfoModal = $LogModal
@onready var _weight_bar: ProgressBar = $WeightBar
@onready var _weight_label: Label = $WeightLabel
@onready var _stats_label: Label = $StatsPanel/StatsLabel

var _ship: Node2D = null
## category -> Button, pros 5 slots de peça única.
var _slot_buttons: Dictionary = {}
## category -> ColorRect (overlay de brilho), paralelo a `_slot_buttons`.
var _slot_glows: Dictionary = {}
## índice 0..19 -> Button, pra grade de canhão.
var _cannon_buttons: Array[Button] = []
## índice 0..19 -> ColorRect (overlay de brilho), paralelo a `_cannon_buttons`.
var _cannon_glows: Array[ColorRect] = []
## Qual canhão (índice) o picker está servindo agora -- só importa quando
## `_picker._category == "armamento"`, já que aí um nome de categoria sozinho
## não diz QUAL dos 20 slots equipar.
var _pending_cannon_index: int = -1


## Círculos grandes com "+" nas pontas do rodapé e a bússola decorativa no
## topo do pergaminho -- pintados na própria arte de fundo
## (`galleon_warship_status_panel.png`), sem botão nenhum por trás (nunca
## tiveram, ver nota de classe). Pedido explícito desta rodada: "oculte até
## que tenham dados associados" -- como não dá pra apagar só um pedaço de um
## PNG já composto sem redesenhar a arte inteira, a correção é visual: um
## véu escuro semi-transparente por cima de cada um, pra parar de ler como
## botão clicável que não faz nada. Coordenadas medidas na arte de origem
## (1536x864) com o mesmo método de grade dos slots, convertidas pro mesmo
## fator de exibição (0.625).
const DECORATIVE_MASKS: Array[Dictionary] = [
	{"cx": 190.6, "cy": 450.0, "radius": 53.1},  # círculo grande esquerdo
	{"cx": 778.1, "cy": 450.0, "radius": 53.1},  # círculo grande direito
	{"cx": 478.1, "cy": 93.75, "radius": 25.0},  # bússola decorativa no topo
]
const DECORATIVE_MASK_COLOR: Color = Color(0.03, 0.02, 0.02, 0.55)


func _ready() -> void:
	visible = false
	$CloseButton.pressed.connect(close)
	_build_craft_slots()
	_build_cannon_grid()
	_build_footer_buttons()
	_build_decorative_masks()
	_picker.instance_selected.connect(_on_instance_selected)
	ShipInventory.changed.connect(_refresh_slot_labels)
	_refresh_slot_labels()


func _build_decorative_masks() -> void:
	for data in DECORATIVE_MASKS:
		var radius: float = data["radius"]
		var mask := Panel.new()
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mask.position = Vector2(data["cx"] - radius, data["cy"] - radius)
		mask.size = Vector2(radius * 2.0, radius * 2.0)
		var style := StyleBoxFlat.new()
		style.bg_color = DECORATIVE_MASK_COLOR
		style.corner_radius_top_left = int(radius)
		style.corner_radius_top_right = int(radius)
		style.corner_radius_bottom_left = int(radius)
		style.corner_radius_bottom_right = int(radius)
		mask.add_theme_stylebox_override("panel", style)
		_slots_root.add_child(mask)


func _process(_delta: float) -> void:
	if not visible:
		return
	if _ship == null:
		_ship = get_tree().get_first_node_in_group("player_ship") as Node2D
	_update_weight_bar()
	_update_stats_label()


func open() -> void:
	visible = true
	UIManager.animate_modal_open(self)
	opened.emit()


func close() -> void:
	_picker.close()
	_crew_submodal.close()
	_cargo_modal.close()
	_ammo_modal.close()
	_log_modal.close()
	visible = false
	closed.emit()


func _build_craft_slots() -> void:
	for data in CRAFT_SLOTS:
		var button := _make_slot_button(data["cx"], data["cy"], data["size"], data["label"])
		var category: String = data["category"]
		button.pressed.connect(_on_slot_pressed.bind(button, category, data["label"]))
		button.mouse_entered.connect(_on_slot_hover.bind(button, func(): return ShipInventory.equipped.get(category, "")))
		button.mouse_exited.connect(_tooltip_zoom.hide_tooltip)
		_slot_buttons[category] = button
		_slot_glows[category] = _make_rarity_glow(button, _next_glow_phase())


func _build_cannon_grid() -> void:
	var index: int = 0
	for row_y in CANNON_ROWS:
		for col_x in CANNON_COLS:
			var button := _make_slot_button(col_x, row_y, CANNON_SLOT_SIZE, "Armamento")
			var cannon_index: int = index
			button.pressed.connect(_on_cannon_pressed.bind(button, cannon_index))
			button.mouse_entered.connect(_on_slot_hover.bind(button, func(): return ShipInventory.equipped_cannons[cannon_index]))
			button.mouse_exited.connect(_tooltip_zoom.hide_tooltip)
			_cannon_buttons.append(button)
			_cannon_glows.append(_make_rarity_glow(button, _next_glow_phase()))
			index += 1


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
var _glow_phase_counter: int = 0
func _next_glow_phase() -> float:
	_glow_phase_counter += 1
	return fmod(float(_glow_phase_counter) * 0.37, TAU)


func _make_slot_button(cx: float, cy: float, size: float, label: String) -> Button:
	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(size, size)
	button.position = Vector2(cx - size / 2.0, cy - size / 2.0)
	button.size = Vector2(size, size)
	button.tooltip_text = label
	_slots_root.add_child(button)
	UIManager.add_hover_pop(button)
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


## Os 4 destinos na mesma ordem de `FOOTER_BUTTONS` -- "destravamento dos
## botões" pedido explicitamente: até esta rodada só o de Tripulação (índice
## 2) abria algo, os outros 3 só pulsavam sem acontecer nada ao clicar.
func _footer_destination(index: int, button: Button) -> Callable:
	match index:
		0:
			return _cargo_modal.open
		1:
			return _ammo_modal.open
		2:
			return _crew_submodal.open
		_:
			return _log_modal.open


func _build_footer_buttons() -> void:
	for i in FOOTER_BUTTONS.size():
		var data: Dictionary = FOOTER_BUTTONS[i]
		var size: float = FOOTER_BUTTON_SIZE
		var button := Button.new()
		button.flat = true
		button.custom_minimum_size = Vector2(size, size)
		button.position = Vector2(data["cx"] - size / 2.0, data["cy"] - size / 2.0)
		button.size = Vector2(size, size)
		button.tooltip_text = data["label"]
		button.pressed.connect(_on_footer_pressed.bind(button, i))
		_footer_root.add_child(button)


## Os 4 submodais de rodapé são independentes um do outro (não passam pelo
## `UIManager`, que é só pros modais do Town Hub) -- sem isso, clicar Carga
## depois Munição depois Log deixava os 3 abertos ao mesmo tempo, empilhados
## por cima um do outro (achado rodando o jogo de verdade nesta rodada).
func _close_footer_submodals() -> void:
	_cargo_modal.close()
	_ammo_modal.close()
	_crew_submodal.close()
	_log_modal.close()


func _on_footer_pressed(button: Button, index: int) -> void:
	_pulse(button)
	_close_footer_submodals()
	_footer_destination(index, button).call()


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

	for i in _cannon_buttons.size():
		var instance_id: String = ShipInventory.equipped_cannons[i]
		_refresh_one_slot(_cannon_buttons[i], _cannon_glows[i], instance_id, "Armamento (slot %d)" % (i + 1))


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
