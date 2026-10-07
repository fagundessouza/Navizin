class_name WindHUD
extends Control
## Biruta de vento: um disco escuro com uma seta que aponta para onde o vento sopra.
## Lê `WindManager` a cada quadro, então acompanha a direção e a força em tempo real.

var _wind: Node = null

const RING_COLOR: Color = Color(0.05, 0.1, 0.16, 0.8)
const RING_EDGE: Color = Color(0.8, 0.9, 1.0, 0.6)
const ARROW_COLOR: Color = Color(1.0, 0.85, 0.45, 0.95)
const ARROW_LENGTH: float = 30.0


func _ready() -> void:
	_wind = get_node("/root/WindManager")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 2.0
	draw_circle(center, radius, RING_COLOR)
	draw_arc(center, radius, 0.0, TAU, 32, RING_EDGE, 1.0)

	var dir: Vector2 = _wind.wind_direction
	var strength: float = _wind.wind_strength
	var tip: Vector2 = center + dir * ARROW_LENGTH * strength
	var side: Vector2 = dir.orthogonal() * 5.0
	var tail: Vector2 = center - dir * ARROW_LENGTH * 0.4
	draw_line(tail, tip, ARROW_COLOR, 2.0)
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 8.0 + side, tip - dir * 8.0 - side]), ARROW_COLOR)
