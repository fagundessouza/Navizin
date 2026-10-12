class_name CityDistrictBase
extends Control
## Cena-modelo reutilizável pra um bairro/praça da cidade (taverna, forja,
## boticário...), no estilo AQW/Swords and Sandals: um fundo panorâmico 2D
## aberto, não mais um popup de texto sobre o mapa da ilha.
##
## Todos os bairros usam esta MESMA cena -- o que muda é o texto (e, quando a
## arte do Mesh AI existir, o fundo) configurado via `GameManager.pending_district_*`
## logo antes da troca de cena (`change_scene_to_file` não aceita parâmetro
## direto). `_ready()` lê o que foi deixado lá e se monta.
##
## Ainda sem personagem andando -- fica para quando o visual AQW/multiplayer
## entrar de verdade. `PlayerSpawnPoint` já existe pronto pra isso: é só
## instanciar o navio/avatar ali quando chegar a hora.

@onready var _title: Label = $Title
@onready var _body: Label = $Body


func _ready() -> void:
	_title.text = GameManager.pending_district_title
	_body.text = GameManager.pending_district_body
	$Buttons/BackToIsland.pressed.connect(_on_back_to_island)
	$Buttons/BackToSea.pressed.connect(_on_back_to_sea)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_to_island()
		get_viewport().set_input_as_handled()


## Volta pro mapa da ilha (um nível acima na hierarquia: oceano -> ilha -> bairro).
func _on_back_to_island() -> void:
	get_tree().change_scene_to_file("res://scenes/cities/island_tortuga_hub.tscn")


## Pula direto pro mar, sem passar pelo mapa da ilha. `ocean_map.gd` restaura o
## navio a partir do mesmo `GameManager` salvo quando se atracou -- esse estado
## não foi tocado desde então, então continua valendo aqui também.
func _on_back_to_sea() -> void:
	get_tree().change_scene_to_file("res://scenes/world/ocean_map.tscn")
