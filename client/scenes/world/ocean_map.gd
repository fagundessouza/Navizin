extends Node2D
## Cena principal: mapa do oceano.
##
## Contém o mar (ColorRect com shader procedural), o navio do jogador e a
## câmera presa a ele. Mar e câmera são definidos em `ocean_map.tscn`.


func _ready() -> void:
	print("Navizin: mapa do oceano carregado.")
	_add_captain_light($World/Ship)
	_restore_ship_state()
	_wire_tortuga_dock()


## Se há estado salvo em `GameManager` (o navio acabou de sair da cena da cidade),
## reaplica posição, casco e suprimento no navio recém-instanciado, e limpa o que
## foi salvo -- senão um segundo retorno reaplicaria o mesmo estado de novo.
func _restore_ship_state() -> void:
	if GameManager.saved_hull < 0.0:
		return
	var ship: Node2D = $World/Ship
	ship.global_position = GameManager.saved_ship_position
	ship.hull = GameManager.saved_hull
	ship.supply = GameManager.saved_supply
	GameManager.clear_saved_ship_state()


## Liga o gatilho de porto de Tortuga: aviso quando o navio está no alcance,
## tecla de interação (F) troca para a cena da cidade (`scenes/cities/`).
func _wire_tortuga_dock() -> void:
	var dock: Area2D = $World/TortugaHub/DockingArea
	var prompt: Label = $HUD/InteractPrompt
	dock.ship_entered_range.connect(func(): prompt.visible = true)
	dock.ship_left_range.connect(func(): prompt.visible = false)
	dock.interact_requested.connect(_enter_tortuga)

	# Clicar na ilha entra direto na cidade, de onde o navio estiver (sem precisar
	# navegar até a baía primeiro).
	var hover: Area2D = $World/TortugaHub/HoverArea
	hover.clicked.connect(func():
		var ship: Node2D = get_tree().get_first_node_in_group("player_ship")
		if ship != null:
			_enter_tortuga(ship))


## Salva o estado do navio em `GameManager` e troca para a cena da cidade de
## Tortuga. O navio em si não sobrevive à troca -- só o que `GameManager` guarda.
func _enter_tortuga(ship: Node2D) -> void:
	GameManager.saved_ship_position = ship.global_position
	GameManager.saved_hull = ship.hull
	GameManager.saved_supply = ship.supply
	get_tree().change_scene_to_file("res://scenes/cities/island_tortuga_hub.tscn")


## Luz de visão do capitão: um halo quente e suave preso ao navio do jogador. A área
## perto do navio fica limpa, e a borda da tela escurece pela vinheta do mar.
func _add_captain_light(ship: Node2D) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var light := PointLight2D.new()
	light.texture = tex
	light.texture_scale = 5.0
	light.energy = 0.6
	light.color = Color(0.95, 0.97, 1.0, 1.0)
	light.blend_mode = Light2D.BLEND_MODE_ADD
	ship.add_child(light)
