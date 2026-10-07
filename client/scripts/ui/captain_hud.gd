class_name CaptainHUD
extends Control
## Interface do capitão, em camadas fixas:
## - Canto superior esquerdo: retrato do capitão e barra de casco.
## - Topo central: bússola, com a proa do navio e a seta do vento.
## - Canto superior direito: moldura do minimapa (o mundo é desenhado depois).
## - Embaixo, centro: painel de utilidades, com as teclas 1 a 4 de habilidades.
##
## Lê o navio do jogador (grupo `player_ship`) e o `WindManager`.

## Retrato do capitão. Quando vazio, mostra um espaço de moldura até a arte chegar.
@export var portrait: Texture2D

const PANEL_COLOR: Color = Color(0.04, 0.08, 0.13, 0.82)
const FRAME_COLOR: Color = Color(0.82, 0.7, 0.42, 0.95)
const TEXT_COLOR: Color = Color(0.95, 0.93, 0.86, 1.0)
const HULL_COLOR: Color = Color(0.78, 0.2, 0.18, 1.0)
const HULL_BG: Color = Color(0.12, 0.05, 0.05, 0.9)
const WIND_COLOR: Color = Color(1.0, 0.85, 0.45, 0.95)
const HEADING_COLOR: Color = Color(0.7, 0.9, 1.0, 0.95)
const SLOT_LABELS: Array[String] = ["1", "2", "3", "4"]

var _ship: Node2D = null
var _wind: Node = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wind = get_node("/root/WindManager")
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	if _ship == null:
		_ship = get_tree().get_first_node_in_group("player_ship") as Node2D
	queue_redraw()


func _draw() -> void:
	var vp: Vector2 = size
	_draw_portrait_panel(Vector2(16.0, 16.0))
	_draw_compass(Vector2(vp.x * 0.5, 16.0))
	_draw_minimap_frame(Vector2(vp.x - 16.0 - 150.0, 16.0))
	_draw_utility_panel(Vector2(vp.x * 0.5, vp.y - 16.0))


## Retrato e barra de casco.
func _draw_portrait_panel(pos: Vector2) -> void:
	var rect: Rect2 = Rect2(pos, Vector2(260.0, 96.0))
	draw_rect(rect, PANEL_COLOR)
	draw_rect(rect, FRAME_COLOR, false, 2.0)
	var frame: Rect2 = Rect2(pos + Vector2(8.0, 8.0), Vector2(80.0, 80.0))
	draw_rect(frame, Color(0.02, 0.04, 0.07, 1.0))
	draw_rect(frame, FRAME_COLOR, false, 2.0)
	if portrait != null:
		draw_texture_rect(portrait, frame.grow(-2.0), false)
	else:
		draw_string(ThemeDB.fallback_font, frame.position + Vector2(10.0, 46.0), "CAPITÃO", HORIZONTAL_ALIGNMENT_LEFT, 64, 12, TEXT_COLOR)

	var hull: float = 100.0
	var max_hull: float = 100.0
	if _ship != null:
		hull = _ship.get("hull")
		max_hull = _ship.get("max_hull")
	var ratio: float = clampf(hull / maxf(max_hull, 1.0), 0.0, 1.0)
	var bar: Rect2 = Rect2(pos + Vector2(100.0, 40.0), Vector2(148.0, 14.0))
	draw_string(ThemeDB.fallback_font, pos + Vector2(100.0, 32.0), "CASCO", HORIZONTAL_ALIGNMENT_LEFT, 120, 13, TEXT_COLOR)
	draw_rect(bar, HULL_BG)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), HULL_COLOR)
	draw_rect(bar, FRAME_COLOR, false, 1.0)
	draw_string(ThemeDB.fallback_font, pos + Vector2(100.0, 74.0), "%d / %d" % [int(hull), int(max_hull)], HORIZONTAL_ALIGNMENT_LEFT, 120, 12, TEXT_COLOR)


## Bússola: N/E/S/W, a proa do navio (agulha clara) e a seta do vento (dourada).
func _draw_compass(top_center: Vector2) -> void:
	var radius: float = 52.0
	var center: Vector2 = top_center + Vector2(0.0, radius + 4.0)
	draw_circle(center, radius, PANEL_COLOR)
	draw_arc(center, radius, 0.0, TAU, 48, FRAME_COLOR, 2.0)
	var letters: Array[String] = ["N", "E", "S", "W"]
	var dirs: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	for i in range(4):
		var p: Vector2 = center + dirs[i] * (radius - 12.0)
		draw_string(ThemeDB.fallback_font, p + Vector2(-5.0, 5.0), letters[i], HORIZONTAL_ALIGNMENT_LEFT, 12, 12, TEXT_COLOR)
	if _ship != null:
		var heading: Vector2 = Vector2.RIGHT.rotated(_ship.rotation)
		draw_line(center, center + heading * (radius - 20.0), HEADING_COLOR, 2.0)
	if _wind != null:
		var wdir: Vector2 = _wind.wind_direction
		var strength: float = _wind.wind_strength
		var tip: Vector2 = center + wdir * (radius - 18.0) * clampf(strength / 1.5, 0.3, 1.0)
		draw_line(center, tip, WIND_COLOR, 3.0)
		draw_colored_polygon(PackedVector2Array([tip, tip - wdir * 7.0 + wdir.orthogonal() * 4.0, tip - wdir * 7.0 - wdir.orthogonal() * 4.0]), WIND_COLOR)


## Moldura do minimapa: o mundo é desenhado dentro dela depois.
func _draw_minimap_frame(pos: Vector2) -> void:
	var rect: Rect2 = Rect2(pos, Vector2(150.0, 150.0))
	draw_rect(rect, PANEL_COLOR)
	draw_rect(rect, FRAME_COLOR, false, 2.0)
	draw_string(ThemeDB.fallback_font, pos + Vector2(8.0, 16.0), "MAPA", HORIZONTAL_ALIGNMENT_LEFT, 120, 12, TEXT_COLOR)


## Painel de utilidades: quatro habilidades (teclas 1 a 4) e quatro espaços de item.
func _draw_utility_panel(bottom_center: Vector2) -> void:
	var slot: float = 52.0
	var gap: float = 8.0
	var total: float = 12.0 + 4.0 * (slot + gap) + 12.0 + 4.0 * (slot + gap) - gap + 12.0
	var rect: Rect2 = Rect2(bottom_center - Vector2(total * 0.5, slot + 20.0), Vector2(total, slot + 20.0))
	draw_rect(rect, PANEL_COLOR)
	draw_rect(rect, FRAME_COLOR, false, 2.0)
	var x: float = rect.position.x + 12.0
	var y: float = rect.position.y + 10.0
	for i in range(4):
		var s: Rect2 = Rect2(Vector2(x, y), Vector2(slot, slot))
		draw_rect(s, Color(0.02, 0.04, 0.07, 1.0))
		draw_rect(s, FRAME_COLOR, false, 1.0)
		draw_string(ThemeDB.fallback_font, s.position + Vector2(4.0, 14.0), SLOT_LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, 12, 12, TEXT_COLOR)
		x += slot + gap
	x += 12.0
	for i in range(4):
		var s2: Rect2 = Rect2(Vector2(x, y), Vector2(slot, slot))
		draw_rect(s2, Color(0.02, 0.04, 0.07, 1.0))
		draw_rect(s2, FRAME_COLOR, false, 1.0)
		x += slot + gap
