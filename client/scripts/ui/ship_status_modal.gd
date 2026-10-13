class_name ShipStatusModal
extends Control
## Ficha de equipamento do navio: 3 slots especiais (velas, casco/blindagem,
## mastro de proa) e uma grade 5x4 de slots de armamento, montados sobre a
## arte `galleon_ship_panel.png` -- ela já vem com a moldura e os '+'
## desenhados em cada slot, os botões daqui são só a área de clique.
##
## Mesma lógica de coordenadas de `captain_profile_modal.gd`: centros
## medidos na arte de origem (1536x864), convertidos pra escala de exibição
## (960x540, fator 0.625). A grade de armamento é construída em loop a
## partir de `GRID_COLS`/`GRID_ROWS` em vez de 20 entradas escritas à mão.
##
## As 3 barras de recurso (carga/blindagem/vento) na faixa de baixo da arte
## ficam só decorativas por ora -- dá pra ligar em `ship.supply`/`hull` e
## `WindManager` depois, se quiser essa leitura ao vivo aqui também.

signal opened
signal closed

const PANEL_SIZE: Vector2 = Vector2(960, 540)
const PICKER_WIDTH_ESTIMATE: float = 226.0
const PICKER_HEIGHT_ESTIMATE: float = 170.0

const SPECIAL_SLOTS: Array[Dictionary] = [
	{"category": "velas", "label": "Velas", "cx": 96.9, "cy": 118.8, "size": 64.0},
	{"category": "casco", "label": "Casco / Blindagem", "cx": 483.1, "cy": 118.8, "size": 64.0},
	{"category": "mastro_proa", "label": "Mascarão de Proa", "cx": 507.5, "cy": 288.8, "size": 64.0},
]

const GRID_COLS: Array[float] = [640.0, 705.0, 770.0, 834.4, 898.8]
const GRID_ROWS: Array[float] = [117.5, 190.6, 262.5, 336.2]
const GRID_SLOT_SIZE: float = 48.0

const PULSE_SCALE: Vector2 = Vector2(1.3, 1.3)
const GLOW_COLOR: Color = Color(1.4, 1.25, 0.8, 1.0)

@onready var _slots_root: Control = $Slots
@onready var _picker: InventoryPickerSubmodal = $Picker


func _ready() -> void:
	visible = false
	$CloseButton.pressed.connect(close)
	_build_special_slots()
	_build_armament_grid()


func open() -> void:
	visible = true
	opened.emit()


func close() -> void:
	_picker.close()
	visible = false
	closed.emit()


func _build_special_slots() -> void:
	for data in SPECIAL_SLOTS:
		_add_slot(data["cx"], data["cy"], data["size"], data["category"], data["label"])


func _build_armament_grid() -> void:
	for row_y in GRID_ROWS:
		for col_x in GRID_COLS:
			_add_slot(col_x, row_y, GRID_SLOT_SIZE, "armamento", "Armamento")


func _add_slot(cx: float, cy: float, size: float, category: String, label: String) -> void:
	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(size, size)
	button.position = Vector2(cx - size / 2.0, cy - size / 2.0)
	button.size = Vector2(size, size)
	button.tooltip_text = label
	button.pressed.connect(_on_slot_pressed.bind(button, category, label))
	_slots_root.add_child(button)


func _on_slot_pressed(button: Button, category: String, label: String) -> void:
	_pulse(button)
	_open_picker_near(button, category, label)


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
