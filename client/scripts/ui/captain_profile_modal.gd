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
	{"category": "grimorio", "label": "Grimório", "cx": 728.1, "cy": 353.1, "size": 56.0},
]

const EMBLEMS: Array[Dictionary] = [
	{"attr": "leadership", "label": "Liderança / Comando", "cx": 296.9, "cy": 467.5, "size": 36.0},
	{"attr": "charisma", "label": "Carisma / Reputação", "cx": 478.1, "cy": 467.5, "size": 36.0},
	{"attr": "persuasion", "label": "Persuasão / Comércio", "cx": 661.2, "cy": 467.5, "size": 36.0},
]

const PULSE_SCALE: Vector2 = Vector2(1.35, 1.35)
const GLOW_COLOR: Color = Color(1.4, 1.25, 0.8, 1.0)

@onready var _equip_slots: Control = $EquipSlots
@onready var _attr_buttons: Control = $AttributeButtons
@onready var _picker: InventoryPickerSubmodal = $Picker
@onready var _points_label: Label = $PointsLabel

var _attr_value_labels: Dictionary = {}


func _ready() -> void:
	visible = false
	$CloseButton.pressed.connect(close)
	_picker.item_selected.connect(_on_item_selected)
	CaptainAttributes.changed.connect(_refresh_attributes)
	_build_equip_slots()
	_build_attribute_buttons()
	_refresh_attributes()


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
		var button := Button.new()
		button.flat = true
		button.custom_minimum_size = Vector2(size, size)
		button.position = Vector2(data["cx"] - size / 2.0, data["cy"] - size / 2.0)
		button.size = Vector2(size, size)
		button.tooltip_text = data["label"]
		button.pressed.connect(_on_slot_pressed.bind(button, data["category"], data["label"]))
		_equip_slots.add_child(button)


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


func _on_item_selected(category: String, item_name: String) -> void:
	for button in _equip_slots.get_children():
		if button.tooltip_text.begins_with(_label_for(category)):
			button.tooltip_text = "%s\n%s" % [_label_for(category), item_name]
			return


func _label_for(category: String) -> String:
	for data in PAPERDOLL_SLOTS:
		if data["category"] == category:
			return data["label"]
	return category


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
