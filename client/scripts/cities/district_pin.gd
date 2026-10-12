class_name DistrictPin
extends Control
## Marcador visual de um distrito no mapa de Tortuga: ícone sempre visível
## (não mais invisível até o hover, como os `TextureButton` antigos), com
## brilho mais forte, leve aumento de escala e uma etiqueta com nome + função
## quando o mouse passa por cima. Clicar emite `pressed` com `district_id` --
## quem decide pra qual cena ir é `island_tortuga_hub.gd`, este componente só
## marca e identifica o lugar no mapa.

signal pressed(district_id: String)

@export var district_id: String = ""
@export var district_name: String = ""
@export var district_function: String = ""
@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			_icon.texture = value

const HOVER_SCALE: Vector2 = Vector2(1.22, 1.22)
const HOVER_TINT: Color = Color(1.35, 1.22, 0.85, 1.0)

@onready var _icon: TextureRect = $Icon
@onready var _tooltip: PanelContainer = $Tooltip
@onready var _tooltip_name: Label = $Tooltip/VBox/NameLabel
@onready var _tooltip_function: Label = $Tooltip/VBox/FunctionLabel

var _tween: Tween


func _ready() -> void:
	_icon.texture = icon
	_icon.pivot_offset = _icon.size / 2.0
	_tooltip_name.text = district_name
	_tooltip_function.text = district_function
	_tooltip.visible = false
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	gui_input.connect(_on_gui_input)


func _on_hover() -> void:
	_tooltip.visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_icon, "scale", HOVER_SCALE, 0.12)
	_tween.tween_property(_icon, "modulate", HOVER_TINT, 0.12)


func _on_unhover() -> void:
	_tooltip.visible = false
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_icon, "scale", Vector2.ONE, 0.12)
	_tween.tween_property(_icon, "modulate", Color.WHITE, 0.12)


func _on_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(district_id)
