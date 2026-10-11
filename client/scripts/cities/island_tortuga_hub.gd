class_name TortugaCityHub
extends Control
## Cena do porto de Tortuga: a ilustração inteira como fundo, com pontos de
## interação invisíveis (realçados só no hover) sobre os prédios certos.
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

@onready var _info: NinePatchRect = $InfoPanel


func _ready() -> void:
	for button in $Hotspots.get_children():
		button.pressed.connect(_on_hotspot_pressed.bind(button.name))


func _on_hotspot_pressed(location: String) -> void:
	_info.get_node("Title").text = TITLES.get(location, location)
	_info.get_node("Body").text = DESCRIPTIONS.get(location, "Em construção.")
	_info.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _info.visible:
		_info.visible = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not _info.visible:
		_return_to_ocean()
		get_viewport().set_input_as_handled()


## Troca de volta pra cena do oceano. `ocean_map.gd` reaplica o estado do navio
## salvo em `GameManager` (`saved_hull`/`saved_supply`/`saved_ship_position`) no
## próprio `_ready()`, lendo o que foi guardado ao entrar no porto.
func _return_to_ocean() -> void:
	get_tree().change_scene_to_file("res://scenes/world/ocean_map.tscn")
