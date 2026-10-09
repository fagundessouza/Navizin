class_name TortugaDock
extends Area2D
## Doca de Tortuga: cobre o canal de água da baía interna. Quando o casco do navio
## entra na área e o jogador aperta E, a navegação congela e a tela da cidade abre.
## Apertar E de novo (já na tela da cidade) desatraca e devolve o navio.

signal docked(ship: Node2D)
signal undocked

var _ship_in_range: Node2D = null
var _docked: bool = false


func _ready() -> void:
	monitoring = true
	# O casco do navio é uma Area2D (HullArea), não um corpo físico: detecta por área,
	# não por corpo.
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	var ship: Node2D = area.get_parent() as Node2D
	if ship != null and ship.is_in_group("player_ship"):
		_ship_in_range = ship


func _on_area_exited(area: Area2D) -> void:
	if area.get_parent() == _ship_in_range:
		_ship_in_range = null


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_E:
		return
	if _docked:
		_undock()
	elif _ship_in_range != null:
		_dock()
	else:
		return
	# Consome o evento: sem isto, a mesma tecla também chega à tela da cidade que
	# acabou de abrir (ou fechar) neste mesmo despacho, e ela reage de novo --
	# atraca e desatraca no mesmo aperto de E.
	get_viewport().set_input_as_handled()


func _dock() -> void:
	_docked = true
	# Congela a navegação: zera a vela e a velocidade, sem tirar o jogador do mapa.
	if "sail" in _ship_in_range:
		_ship_in_range.sail = 0  # Sail.STOPPED
	_ship_in_range.speed = 0.0
	_ship_in_range.set_physics_process(false)
	docked.emit(_ship_in_range)


func _undock() -> void:
	_docked = false
	if _ship_in_range != null:
		_ship_in_range.set_physics_process(true)
	undocked.emit()
