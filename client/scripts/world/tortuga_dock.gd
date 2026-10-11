class_name TortugaDock
extends Area2D
## Gatilho de porto na baía de Tortuga: cobre o canal de água da baía interna.
##
## Não troca de tela sozinho -- só rastreia se o navio está no alcance e emite
## sinais. Quem decide o que fazer com isso (mostrar aviso, trocar de cena) é
## `ocean_map.gd`, pra este script não conhecer HUD nem caminho de cena nenhum.

signal ship_entered_range
signal ship_left_range
## Pedido de entrar no porto: tecla de interação apertada com o navio no alcance.
signal interact_requested(ship: Node2D)

var _ship_in_range: Node2D = null


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
		ship_entered_range.emit()


func _on_area_exited(area: Area2D) -> void:
	if area.get_parent() == _ship_in_range:
		_ship_in_range = null
		ship_left_range.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _ship_in_range == null or not event.is_action_pressed("interact"):
		return
	interact_requested.emit(_ship_in_range)
	get_viewport().set_input_as_handled()
