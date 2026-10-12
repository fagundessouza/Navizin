class_name TortugaCityHub
extends Control
## Mapa geral de Tortuga: a ilustração inteira como fundo, com pontos de
## interação invisíveis (realçados só no hover) sobre os prédios certos.
##
## Estilo AQW/Swords and Sandals: esta tela é só o SELETOR de bairro, não o
## destino final. Clicar num prédio troca pra uma cena de praça 2D dedicada
## (`city_district_base.tscn`), não mais um popup de texto por cima do mapa.
##
## Cena própria (`res://scenes/cities/island_tortuga_hub.tscn`), não mais um
## overlay escondido dentro de `ocean_map.tscn`: `ocean_map.gd` troca para esta
## cena ao atracar (`get_tree().change_scene_to_file`), e sair daqui troca de
## volta para o oceano. O navio não existe enquanto esta cena está ativa --
## `GameManager` guarda a posição/casco/suprimento dele pra restaurar na volta.

const DESCRIPTIONS: Dictionary = {
	"Shipyard": "O esqueleto de um navio em construção. Compra e reparo de embarcações. Em construção.",
	"Forge": "O calor da forja nunca esfria. Armas e peças de canhão. Em construção.",
	"Tavern": "Rum, rumores e tripulação para contratar sob a caveira pintada na parede. Em construção.",
	"Apothecary": "Um brilho verde-pântano escapa pelas janelas. Poções e curas. Em construção.",
	"BountyBoard": "O obelisco da praça central, coberto de cartazes. Contratos e recompensas. Em construção.",
	"BlackMarket": "Tendas que não fazem perguntas. Comércio de itens raros. Em construção.",
	"GuildHall": "Bandeiras azuis tremulam sobre a mansão gótica. Sua guilda e sua frota. Em construção.",
	"Academy": "O farol no topo do penhasco guia os que estudam o mar. Em construção.",
}

const TITLES: Dictionary = {
	"Shipyard": "Estaleiro", "Forge": "Forja", "Tavern": "Taverna",
	"Apothecary": "Boticário", "BountyBoard": "Quadro de Recompensas",
	"BlackMarket": "Mercado Negro", "GuildHall": "Salão da Guilda", "Academy": "Academia",
}

func _ready() -> void:
	for button in $Hotspots.get_children():
		button.pressed.connect(_on_hotspot_pressed.bind(button.name))


## Em vez de abrir um popup sobre o mapa, entra na praça daquele bairro: uma
## cena própria com fundo panorâmico (`city_district_base.tscn`).
func _on_hotspot_pressed(location: String) -> void:
	GameManager.pending_district_title = TITLES.get(location, location)
	GameManager.pending_district_body = DESCRIPTIONS.get(location, "Em construção.")
	get_tree().change_scene_to_file("res://scenes/cities/city_district_base.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_return_to_ocean()
		get_viewport().set_input_as_handled()


## Troca de volta pra cena do oceano. `ocean_map.gd` reaplica o estado do navio
## salvo em `GameManager` (`saved_hull`/`saved_supply`/`saved_ship_position`) no
## próprio `_ready()`, lendo o que foi guardado ao entrar no porto.
func _return_to_ocean() -> void:
	get_tree().change_scene_to_file("res://scenes/world/ocean_map.tscn")
