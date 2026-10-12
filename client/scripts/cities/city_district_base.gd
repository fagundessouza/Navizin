class_name CityDistrictBase
extends Control
## Base pra um bairro/praça da cidade (taverna, forja, boticário...), no
## estilo AQW/Swords and Sandals: um fundo panorâmico 2D aberto com o prédio
## daquele bairro em cima, não mais um popup de texto sobre o mapa da ilha.
##
## Cada bairro é a sua PRÓPRIA cena em `scenes/cities/districts/`, herdando a
## estrutura comum (fundo, título, texto, botões) e só adicionando o Sprite2D
## do prédio + `BuildingFX`. `district_title`/`district_body` são @export pra
## cada cena-filha preencher direto, sem precisar de estado global.
##
## Ainda sem personagem andando -- fica para quando o visual AQW/multiplayer
## entrar de verdade. `PlayerSpawnPoint` já existe pronto pra isso: é só
## instanciar o navio/avatar ali quando chegar a hora.

@export var district_title: String = ""
@export_multiline var district_body: String = ""

@onready var _title: Label = $Title
@onready var _body: Label = $Body


func _ready() -> void:
	_title.text = district_title
	_body.text = district_body
	$Buttons/BackToIsland.pressed.connect(_on_back_to_island)
	$Buttons/BackToSea.pressed.connect(_on_back_to_sea)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Mesma ordem seca de `tortuga_dock.gd`/`island_tortuga_hub.gd`: consumir o
	# evento ANTES de trocar de cena, nunca depois.
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	_on_back_to_island()


## Volta pro mapa da ilha (um nível acima na hierarquia: oceano -> ilha -> bairro).
func _on_back_to_island() -> void:
	SceneTransitionManager.change_scene("res://scenes/cities/island_tortuga_hub.tscn")


## Pula direto pro mar, sem passar pelo mapa da ilha. `ocean_map.gd` restaura o
## navio a partir do mesmo `GameManager` salvo quando se atracou -- esse estado
## não foi tocado desde então, então continua valendo aqui também.
func _on_back_to_sea() -> void:
	SceneTransitionManager.change_scene("res://scenes/world/ocean_map.tscn")
