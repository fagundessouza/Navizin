class_name MinimapHUD
extends Control
## Minimapa dinâmico: uma câmera num SubViewport que divide o World2D com o jogo, então
## o que aparece aqui (mar, ilhas) é o mundo de verdade, visto de muito longe. A câmera
## segue `ship.global_position` a cada quadro. Uma seta fixa, desenhada por cima, marca
## o navio e gira com o rumo dele.

const MARKER_CENTER: Vector2 = Vector2(85.0, 105.0)
const MARKER_COLOR: Color = Color(1.0, 0.85, 0.3, 1.0)

@onready var _viewport: SubViewport = $ViewportHolder/World
@onready var _camera: Camera2D = $ViewportHolder/World/MinimapCamera

var _ship: Node2D = null
var _world_shared: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if _ship == null:
		_ship = get_tree().get_first_node_in_group("player_ship") as Node2D
		return
	if not _world_shared:
		# Mesmo World2D do jogo: o SubViewport passa a renderizar o mar e as ilhas de verdade.
		_viewport.world_2d = _ship.get_viewport().world_2d
		_world_shared = true
	_camera.global_position = _ship.global_position
	queue_redraw()


func _draw() -> void:
	var heading: float = 0.0 if _ship == null else _ship.rotation
	var tip: Vector2 = MARKER_CENTER + Vector2(9.0, 0.0).rotated(heading)
	var left: Vector2 = MARKER_CENTER + Vector2(-5.0, 5.0).rotated(heading)
	var right: Vector2 = MARKER_CENTER + Vector2(-5.0, -5.0).rotated(heading)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), MARKER_COLOR)
	draw_circle(MARKER_CENTER, 2.0, Color(1, 1, 1, 0.6))
