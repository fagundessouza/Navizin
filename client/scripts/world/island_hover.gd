class_name IslandHover
extends Area2D
## Realce ao passar o mouse por cima da ilha: liga um brilho neon amarelo pulsando ao
## redor da silhueta (não clareia a arte em si), como um convite a clicar. Clicar com o
## botão esquerdo entra direto na cidade (emite `clicked`; quem decide o que fazer com
## isso é a cena, não este script).

signal clicked

@export var glow_path: NodePath

const PULSE_PERIOD: float = 0.6
const PULSE_MIN: float = 0.35
const PULSE_MAX: float = 1.0

var _tween: Tween = null
var _glow: CanvasItem


func _ready() -> void:
	_glow = get_node(glow_path)
	_glow.visible = false
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)


func _on_mouse_entered() -> void:
	_glow.visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_loops()
	_tween.tween_property(_glow, "modulate:a", PULSE_MAX, PULSE_PERIOD * 0.5)
	_tween.tween_property(_glow, "modulate:a", PULSE_MIN, PULSE_PERIOD * 0.5)


func _on_mouse_exited() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_glow.visible = false


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
