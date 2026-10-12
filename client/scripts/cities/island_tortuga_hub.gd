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

## Qual cena de bairro cada hotspot abre. Cada uma é uma cena própria em
## `scenes/cities/districts/`, com seu título/texto/prédio já embutidos --
## não precisa mais passar texto por `GameManager`.
##
## "BountyBoard" (nome do nó, histórico) agora abre o Mercado Central /
## Marketplace -- o quadro de procurados que dava nome a esse hotspot mudou de
## endereço, virou uma aba dentro da Taverna (ver `tavern_district.tscn`).
## "SupplyMarket" (antigo "MarketBazaar") é a Feira de Suprimentos de verdade,
## com arte própria agora -- "TreasureVault" voltou a ser só a Caverna do
## Tesouro (as duas tinham ficado misturadas numa rodada anterior).
const DISTRICT_SCENES: Dictionary = {
	"Shipyard": "res://scenes/cities/districts/shipyard_district.tscn",
	"Forge": "res://scenes/cities/districts/blacksmith_district.tscn",
	"Tavern": "res://scenes/cities/districts/tavern_district.tscn",
	"Apothecary": "res://scenes/cities/districts/apothecary_district.tscn",
	"BountyBoard": "res://scenes/cities/districts/marketplace_district.tscn",
	"TreasureVault": "res://scenes/cities/districts/treasure_vault_district.tscn",
	"GuildHall": "res://scenes/cities/districts/captains_guild_district.tscn",
	"SupplyMarket": "res://scenes/cities/districts/supply_market_district.tscn",
}
const FALLBACK_SCENE: String = "res://scenes/cities/city_district_base.tscn"


func _ready() -> void:
	for pin in $Hotspots.get_children():
		pin.pressed.connect(_on_hotspot_pressed)


## Em vez de abrir um popup sobre o mapa, entra na praça daquele bairro: uma
## cena própria com fundo panorâmico e o prédio em cima.
func _on_hotspot_pressed(location: String) -> void:
	SceneTransitionManager.change_scene(DISTRICT_SCENES.get(location, FALLBACK_SCENE))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	# Consome o evento ANTES de trocar de cena: o mesmo bug de `tortuga_dock.gd`
	# (`get_viewport()` podendo vir nulo se chamado depois do `change_scene_to_file`).
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	_return_to_ocean()


## Troca de volta pra cena do oceano. `ocean_map.gd` reaplica o estado do navio
## salvo em `GameManager` (`saved_hull`/`saved_supply`/`saved_ship_position`) no
## próprio `_ready()`, lendo o que foi guardado ao entrar no porto.
func _return_to_ocean() -> void:
	SceneTransitionManager.change_scene("res://scenes/world/ocean_map.tscn")
