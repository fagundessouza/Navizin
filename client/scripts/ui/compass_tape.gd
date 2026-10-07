class_name CompassTape
extends Control
## Bússola minimalista: só a faixa de letras cardeais (N, NE, E ... NW), desenhada em
## código. Cada letra aparece uma única vez, então não há a repetição da arte antiga.

## Rumo do navio em graus: 0 = Norte, cresce no sentido horário.
var heading: float = 0.0:
	set(value):
		heading = value
		queue_redraw()

const PX_PER_DEG: float = 2.2
const LETTERS: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const TICK_STEP: int = 15


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var w: float = size.x
	var h: float = size.y
	var cx: float = w * 0.5
	var color: Color = Color(0.95, 0.9, 0.75, 1.0)
	# k é múltiplo de 3 nas letras (45°) e nos traços a cada 15°.
	for k in range(-24, 25):
		var deg: float = float(k * TICK_STEP)
		var d: float = fposmod(deg - heading + 180.0, 360.0) - 180.0
		var x: float = cx + d * PX_PER_DEG
		if absf(x - cx) > cx:
			continue
		if k % 3 == 0:
			var index: int = posmod(k / 3, 8)
			draw_string(font, Vector2(x, h * 0.72), LETTERS[index], HORIZONTAL_ALIGNMENT_CENTER, -1, 17, color)
		else:
			draw_line(Vector2(x, h * 0.5), Vector2(x, h * 0.66), color, 1.0)
	# Ponteiro fixo da proa, no centro.
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 6.0, 0.0), Vector2(cx + 6.0, 0.0), Vector2(cx, 9.0)]), Color(0.95, 0.8, 0.42, 1.0))
