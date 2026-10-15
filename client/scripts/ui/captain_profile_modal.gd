class_name CaptainProfileModal
extends Control
## Ficha do Capitão: paperdoll de equipamento (6 slots '+') e os 3 brasões de
## atributo social (Liderança/Carisma/Persuasão), montados sobre a arte
## `captain_paperdoll_panel.png` -- ela já vem com a moldura entalhada e os
## '+' desenhados em cada slot, então os botões daqui são só a ÁREA DE
## CLIQUE sobre o que já está pintado, sem desenhar nada por cima.
##
## Coordenadas em `PAPERDOLL_SLOTS`/`EMBLEMS` são o centro de cada '+' na
## arte de origem (1536x864) já convertidas pra escala de exibição (960x540,
## fator 0.625) -- ver a sessão que mediu isso com overlay de grade antes de
## escrever aqui, pra não depender de "mais ou menos no meio do slot".
##
## EQUIPAR DE VERDADE: os 6 slots agora abrem o `InventoryPickerSubmodal`
## igual ao `ship_status_modal.gd` -- itens de verdade fabricados na Feira
## Comerciante, raridade colorida, brilho de raridade/refino no slot, tooltip
## com Float Value. `CaptainInventory.get_captain_bonuses()` alimenta
## `_stats_label`, mostrando Liderança/Dano Crítico de Abordagem/Velocidade
## Nodal/Penetração de Blindagem/Dano Elemental ao vivo -- sem sistema de
## combate ou navegação pra CONSUMIR esses números ainda (mesma situação do
## `cannon_damage_mult` do navio: o valor está certo, só não alimenta nada).

signal opened
signal closed

const PANEL_SIZE: Vector2 = Vector2(960, 540)
const PICKER_WIDTH_ESTIMATE: float = 226.0
const PICKER_HEIGHT_ESTIMATE: float = 170.0

const PAPERDOLL_SLOTS: Array[Dictionary] = [
	{"category": "brincos", "label": "Brincos", "cx": 232.5, "cy": 125.0, "size": 56.0},
	{"category": "colar", "label": "Colar", "cx": 232.5, "cy": 239.4, "size": 56.0},
	{"category": "anel", "label": "Anel", "cx": 232.5, "cy": 353.1, "size": 56.0},
	{"category": "cinto", "label": "Cinto", "cx": 728.1, "cy": 125.0, "size": 56.0},
	{"category": "trajes", "label": "Trajes", "cx": 728.1, "cy": 239.4, "size": 56.0},
	{"category": "secundaria", "label": "Equipamento Secundário", "cx": 728.1, "cy": 353.1, "size": 56.0},
]

const EMBLEMS: Array[Dictionary] = [
	{"attr": "leadership", "label": "Liderança / Comando", "cx": 296.9, "cy": 467.5, "size": 36.0},
	{"attr": "charisma", "label": "Carisma / Reputação", "cx": 478.1, "cy": 467.5, "size": 36.0},
	{"attr": "persuasion", "label": "Persuasão / Comércio", "cx": 661.2, "cy": 467.5, "size": 36.0},
]

const PULSE_SCALE: Vector2 = Vector2(1.35, 1.35)
const GLOW_COLOR: Color = Color(1.4, 1.25, 0.8, 1.0)

const RARITY_GLOW_SHADER: Shader = preload("res://assets/shaders/item_rarity_glow.gdshader")
const GLOWING_RARITIES: Array[String] = ["blue", "gold"]

@onready var _equip_slots: Control = $EquipSlots
@onready var _attr_buttons: Control = $AttributeButtons
@onready var _picker: InventoryPickerSubmodal = $Picker
@onready var _tooltip_zoom: ItemTooltipZoom = $ItemTooltipZoom
@onready var _points_label: Label = $PointsLabel
@onready var _stats_label: Label = $StatsLabel

var _attr_value_labels: Dictionary = {}
## category -> Button, pros 6 slots do paperdoll.
var _slot_buttons: Dictionary = {}
## category -> ColorRect (overlay de brilho), paralelo a `_slot_buttons`.
var _slot_glows: Dictionary = {}


func _ready() -> void:
	visible = false
	$CloseButton.pressed.connect(close)
	_picker.instance_selected.connect(_on_instance_selected)
	CaptainAttributes.changed.connect(_refresh_attributes)
	CaptainInventory.changed.connect(_refresh_slots)
	_build_equip_slots()
	_build_attribute_buttons()
	_refresh_attributes()
	_refresh_slots()


func open() -> void:
	visible = true
	opened.emit()


func close() -> void:
	_picker.close()
	visible = false
	closed.emit()


func _build_equip_slots() -> void:
	for data in PAPERDOLL_SLOTS:
		var size: float = data["size"]
		var category: String = data["category"]
		var button := Button.new()
		button.flat = true
		button.custom_minimum_size = Vector2(size, size)
		button.position = Vector2(data["cx"] - size / 2.0, data["cy"] - size / 2.0)
		button.size = Vector2(size, size)
		button.tooltip_text = data["label"]
		button.pressed.connect(_on_slot_pressed.bind(button, category, data["label"]))
		button.mouse_entered.connect(_on_slot_hover.bind(button, category))
		button.mouse_exited.connect(_tooltip_zoom.hide_tooltip)
		_equip_slots.add_child(button)
		_slot_buttons[category] = button
		_slot_glows[category] = _make_rarity_glow(button, _next_glow_phase())


## Zoom de alta resolução no item equipado -- mesmo pedido de
## `ship_status_modal.gd` ("no craft ou inventário"). Slot vazio não mostra
## nada.
func _on_slot_hover(button: Button, category: String) -> void:
	var instance_id: String = CaptainInventory.equipped_captain.get(category, "")
	if instance_id == "":
		return
	_tooltip_zoom.show_for_instance(instance_id, button.position + Vector2(button.size.x, 0), PANEL_SIZE)


## Fase inicial do pulso de cada slot (só 6, mas mantém o padrão de
## `ship_status_modal.gd` -- mesmo poucos slots não deveriam piscar em
## uníssono).
var _glow_phase_counter: int = 0
func _next_glow_phase() -> float:
	_glow_phase_counter += 1
	return fmod(float(_glow_phase_counter) * 0.37, TAU)


## Overlay de brilho de raridade -- mesma técnica de `ship_status_modal.gd`
## (um `ColorRect` do tamanho do slot, filho dele, com
## `item_rarity_glow.gdshader`).
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


func _build_attribute_buttons() -> void:
	for data in EMBLEMS:
		var size: float = data["size"]
		var button := Button.new()
		button.flat = true
		button.custom_minimum_size = Vector2(size, size)
		button.position = Vector2(data["cx"] - size / 2.0, data["cy"] - size / 2.0)
		button.size = Vector2(size, size)
		button.tooltip_text = "+1 %s" % data["label"]
		button.pressed.connect(_on_attribute_pressed.bind(button, data["attr"]))
		_attr_buttons.add_child(button)

		var value_label := Label.new()
		value_label.position = Vector2(data["cx"] - 30.0, data["cy"] + size / 2.0 + 4.0)
		value_label.size = Vector2(60.0, 20.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
		value_label.add_theme_font_size_override("font_size", 14)
		_attr_buttons.add_child(value_label)
		_attr_value_labels[data["attr"]] = value_label


func _on_slot_pressed(button: Button, category: String, label: String) -> void:
	_pulse(button)
	_open_picker_near(button, category, label)


func _on_attribute_pressed(button: Button, attr: String) -> void:
	if CaptainAttributes.spend(attr):
		_pulse(button)


func _on_instance_selected(category: String, instance_id: String) -> void:
	CaptainInventory.equip_captain_slot(category, instance_id)


## Reescreve o tooltip de cada slot (nome + raridade + Float) e liga/desliga
## o brilho de raridade/refino -- chamado em `_ready()` e toda vez que
## `CaptainInventory.changed` dispara. Também atualiza `_stats_label` com os
## 5 atributos reais do capitão.
func _refresh_slots() -> void:
	for data in PAPERDOLL_SLOTS:
		var category: String = data["category"]
		var instance_id: String = CaptainInventory.equipped_captain.get(category, "")
		_refresh_one_slot(_slot_buttons[category], _slot_glows[category], instance_id, data["label"])
	_update_stats_label()


func _refresh_one_slot(button: Button, glow: ColorRect, instance_id: String, empty_label: String) -> void:
	var item_name: String = CaptainInventory.get_item_name(instance_id)
	if item_name == "":
		button.tooltip_text = empty_label
		glow.visible = false
		return

	var rarity: Dictionary = CaptainInventory.get_item_rarity(instance_id)
	var float_line: String = CaptainInventory.get_float_tooltip_line(instance_id)
	button.tooltip_text = "%s\n[%s] %s\n%s" % [empty_label, rarity["name"], item_name, float_line]

	var refine_level: int = CaptainInventory.get_refine_level(instance_id)
	var float_value: float = CaptainInventory.get_float_value(instance_id)
	var aura_mode: int = _aura_mode_for(instance_id, rarity, float_value, refine_level)
	# Brilho aparece se a RARIDADE já pedia (Blue+) OU se o Float/Refino
	# sozinho já rendeu uma aura -- um item White com Float 0.99 não devia
	# ficar sem brilho nenhum só porque a raridade não ajudou.
	if GLOWING_RARITIES.has(rarity["id"]) or aura_mode != 0:
		glow.visible = true
		var mat: ShaderMaterial = glow.material
		mat.set_shader_parameter("rarity_color", rarity["color"])
		mat.set_shader_parameter("aura_mode", aura_mode)
		mat.set_shader_parameter("refine_boost", clampf(float(refine_level - 9) / 6.0, 0.0, 1.0) * 2.0)
	else:
		glow.visible = false


## Mesma regra de prioridade de `ship_status_modal.gd` -- duplicada em vez de
## compartilhada porque os dois componentes não têm uma base comum ainda
## (Equipamento Secundário -- ex-"grimorio" -- é o único slot do Capitão
## "místico" o bastante pra entrar na checagem rúnica; os outros 5 nunca
## disparam esse modo).
func _aura_mode_for(instance_id: String, rarity: Dictionary, float_value: float, refine_level: int) -> int:
	var item_id: String = CaptainInventory.crafted_items.get(instance_id, {}).get("item_id", "")
	var category: String = ItemDatabase.get_item(item_id).get("category", "")
	var default_aura: int = rarity.get("default_aura", 0)
	if category == "secundaria" and (float_value >= 0.90 or refine_level >= 10):
		return 3  # AURA_RUNIC
	if float_value >= 0.95:
		return 2  # AURA_DARK_FIRE
	if refine_level >= 10:
		return default_aura if default_aura != 0 else 1
	if default_aura != 0:
		return default_aura
	return 0  # AURA_NONE


func _update_stats_label() -> void:
	var bonuses: Dictionary = CaptainInventory.get_captain_bonuses()
	_stats_label.text = "Liderança: +%.0f   Crítico de Abordagem: +%.0f%%   Veloc. Nodal: +%.0f   Penetração: +%.0f%%   Dano Elemental: +%.0f%%" % [
		bonuses["leadership_bonus"],
		bonuses["boarding_crit_bonus"] * 100.0,
		bonuses["node_speed_bonus"],
		bonuses["armor_pen_bonus"] * 100.0,
		bonuses["elemental_damage_bonus"] * 100.0,
	]


func _refresh_attributes() -> void:
	for attr in _attr_value_labels:
		_attr_value_labels[attr].text = str(CaptainAttributes.get_value(attr))
	_points_label.text = "Pontos disponíveis: %d" % CaptainAttributes.available_points


## Brilho instantâneo + pulso de escala no botão clicado -- feedback de que
## o clique "pegou" antes mesmo do submodal (ou do ponto gasto) aparecer.
func _pulse(button: Button) -> void:
	button.pivot_offset = button.size * 0.5
	var tw := create_tween()
	tw.tween_property(button, "scale", PULSE_SCALE, 0.08)
	tw.parallel().tween_property(button, "modulate", GLOW_COLOR, 0.08)
	tw.tween_property(button, "scale", Vector2.ONE, 0.14)
	tw.parallel().tween_property(button, "modulate", Color.WHITE, 0.14)


## Abre o submodal do lado com mais espaço sobrando -- os slots da coluna
## direita e os brasões (perto da borda inferior) estourariam o painel se o
## submodal sempre abrisse pra baixo-direita feito um tooltip comum.
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
