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
## Os 2 círculos grandes "+" nas pontas do rodapé (visíveis na arte) não
## entraram na lista do pedido (5 slots + grade + barra + 4 botões) e ficaram
## de fora por ora -- decorativos, sem função atribuída.
##
## EQUIPAR DE VERDADE: cada slot (os 5 de craft + os 20 de canhão) abre o
## `InventoryPickerSubmodal` em modo de equipamento -- ele já sabe ler
## `PlayerInventory` sozinho, aqui só processamos `instance_selected` pra
## chamar `PlayerInventory.equip_slot()`/`equip_cannon()` com o slot certo
## e atualizar o tooltip. `PlayerInventory.changed` (equipar OU fabricar)
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
## REFINO: `PlayerInventory.get_item_name()` já devolve o nome com o
## prefixo "[+N]" quando refinado, então nenhuma mudança extra precisou
## aqui pra isso aparecer no tooltip. O que SIM é calculado aqui é
## `_refine_boost_for()`, que só liga a partir de +10 (pedido explícito) e
## intensifica o shader de brilho/faísca -- a refinada +15 de um Divino
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
const CREW_BUTTON_INDEX: int = 2

const PULSE_SCALE: Vector2 = Vector2(1.3, 1.3)
const GLOW_COLOR: Color = Color(1.4, 1.25, 0.8, 1.0)

const RARITY_GLOW_SHADER: Shader = preload("res://assets/shaders/item_rarity_glow.gdshader")
## White/Green não ganham brilho -- só a partir de Raro (Blue) pra cima, como
## é convenção em ARPG (item comum/bom não chama atenção, raro em diante sim).
const GLOWING_RARITIES: Array[String] = ["blue", "yellow", "orange", "purple", "red"]

@onready var _slots_root: Control = $Slots
@onready var _footer_root: Control = $Footer
@onready var _picker: InventoryPickerSubmodal = $Picker
@onready var _crew_submodal: CrewManagementSubmodal = $CrewManagementSubmodal
@onready var _weight_bar: ProgressBar = $WeightBar
@onready var _stats_label: Label = $StatsLabel

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


func _ready() -> void:
	visible = false
	$CloseButton.pressed.connect(close)
	_build_craft_slots()
	_build_cannon_grid()
	_build_footer_buttons()
	_picker.instance_selected.connect(_on_instance_selected)
	PlayerInventory.changed.connect(_refresh_slot_labels)
	_refresh_slot_labels()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _ship == null:
		_ship = get_tree().get_first_node_in_group("player_ship") as Node2D
	_update_weight_bar()
	_update_stats_label()


func open() -> void:
	visible = true
	opened.emit()


func close() -> void:
	_picker.close()
	_crew_submodal.close()
	visible = false
	closed.emit()


func _build_craft_slots() -> void:
	for data in CRAFT_SLOTS:
		var button := _make_slot_button(data["cx"], data["cy"], data["size"], data["label"])
		button.pressed.connect(_on_slot_pressed.bind(button, data["category"], data["label"]))
		_slot_buttons[data["category"]] = button
		_slot_glows[data["category"]] = _make_rarity_glow(button)


func _build_cannon_grid() -> void:
	var index: int = 0
	for row_y in CANNON_ROWS:
		for col_x in CANNON_COLS:
			var button := _make_slot_button(col_x, row_y, CANNON_SLOT_SIZE, "Armamento")
			button.pressed.connect(_on_cannon_pressed.bind(button, index))
			_cannon_buttons.append(button)
			_cannon_glows.append(_make_rarity_glow(button))
			index += 1


func _make_slot_button(cx: float, cy: float, size: float, label: String) -> Button:
	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(size, size)
	button.position = Vector2(cx - size / 2.0, cy - size / 2.0)
	button.size = Vector2(size, size)
	button.tooltip_text = label
	_slots_root.add_child(button)
	return button


## Overlay de brilho de raridade: um `ColorRect` do tamanho exato do slot,
## filho dele (segue posição/escala do pulso de clique de graça), ignorando
## mouse pra nunca roubar o clique do botão por baixo. Começa escondido --
## `_refresh_slots()` decide se/como aparece.
func _make_rarity_glow(button: Button) -> ColorRect:
	var glow := ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.color = Color.WHITE
	glow.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = RARITY_GLOW_SHADER
	glow.material = mat
	button.add_child(glow)
	return glow


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
		if i == CREW_BUTTON_INDEX:
			button.pressed.connect(_on_crew_button_pressed.bind(button))
		else:
			button.pressed.connect(_pulse.bind(button))
		_footer_root.add_child(button)


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
			PlayerInventory.equip_cannon(_pending_cannon_index, instance_id)
		_pending_cannon_index = -1
	else:
		PlayerInventory.equip_slot(category, instance_id)


## Reescreve o tooltip de cada slot (nome do item + raridade entre
## colchetes, já que `tooltip_text` não aceita cor) e liga/desliga o brilho
## de raridade -- chamado em `_ready()` e toda vez que `PlayerInventory.changed`
## dispara, pra refletir equipar/fabricar/trocar.
func _refresh_slot_labels() -> void:
	for data in CRAFT_SLOTS:
		var category: String = data["category"]
		var instance_id: String = PlayerInventory.equipped.get(category, "")
		_refresh_one_slot(_slot_buttons[category], _slot_glows[category], instance_id, data["label"])

	for i in _cannon_buttons.size():
		var instance_id: String = PlayerInventory.equipped_cannons[i]
		_refresh_one_slot(_cannon_buttons[i], _cannon_glows[i], instance_id, "Armamento (slot %d)" % (i + 1))


func _refresh_one_slot(button: Button, glow: ColorRect, instance_id: String, empty_label: String) -> void:
	var item_name: String = PlayerInventory.get_item_name(instance_id)
	if item_name == "":
		button.tooltip_text = empty_label
		glow.visible = false
		return

	var rarity: Dictionary = PlayerInventory.get_item_rarity(instance_id)
	button.tooltip_text = "%s\n[%s] %s" % [empty_label, rarity["name"], item_name]

	if GLOWING_RARITIES.has(rarity["id"]):
		glow.visible = true
		var mat: ShaderMaterial = glow.material
		mat.set_shader_parameter("rarity_color", rarity["color"])
		mat.set_shader_parameter("lightning", rarity["lightning"])
		mat.set_shader_parameter("refine_boost", _refine_boost_for(PlayerInventory.get_refine_level(instance_id)))
	else:
		glow.visible = false


## +10 pra cima intensifica as faíscas (pedido explícito) -- 0 até +9, sobe
## em rampa de +10 a +15 até o teto de 2.0 que o shader aceita.
func _refine_boost_for(refine_level: int) -> float:
	return clampf(float(refine_level - 9) / 6.0, 0.0, 1.0) * 2.0


## Abre a Tripulação como um overlay flutuante sobre a própria ficha do
## navio -- não fecha este painel, só sobrepõe (mesmo padrão do submodal de
## inventário: um popup por cima, não uma troca de tela).
func _on_crew_button_pressed(button: Button) -> void:
	_pulse(button)
	_crew_submodal.open()


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
