class_name IslandHover
extends Area2D
## Realce ao passar o mouse por cima da ilha: pisca suavemente, como um convite a
## interagir (mesmo a interação de verdade sendo "navegue até a baía e aperte E",
## não um clique). Não faz nada sozinho; só avisa.

@export var target_path: NodePath

const BLINK_PERIOD: float = 0.9
const BLINK_MIN: float = 0.82
const BLINK_MAX: float = 1.22

var _tween: Tween = null
var target: CanvasItem


func _ready() -> void:
	target = get_node(target_path)
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_loops()
	_tween.tween_property(target, "modulate", Color(BLINK_MAX, BLINK_MAX, BLINK_MAX, 1.0), BLINK_PERIOD * 0.5)
	_tween.tween_property(target, "modulate", Color(BLINK_MIN, BLINK_MIN, BLINK_MIN, 1.0), BLINK_PERIOD * 0.5)


func _on_mouse_exited() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	target.modulate = Color.WHITE
