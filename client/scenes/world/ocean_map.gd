extends Node2D
## Cena principal: mapa do oceano.
##
## Contém o mar (ColorRect com shader procedural), o navio do jogador e a
## câmera presa a ele. Mar e câmera são definidos em `ocean_map.tscn`.


func _ready() -> void:
	print("Navizin: mapa do oceano carregado.")
	_add_captain_light($World/Ship)
	_wire_tortuga_dock()


## Liga a doca de Tortuga à tela da cidade: atracar mostra a tela, pedir pra sair
## (E de novo, dentro da tela) esconde e libera o navio.
func _wire_tortuga_dock() -> void:
	var dock: Area2D = $World/TortugaHub/DockingArea
	var city: Control = $HUD/TortugaCityHub
	var game_hud: Control = $HUD/HUD
	dock.docked.connect(func(_ship):
		city.visible = true
		game_hud.visible = false)
	dock.undocked.connect(func():
		city.visible = false
		game_hud.visible = true)
	city.close_requested.connect(dock._undock)


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
