extends Node
## Singleton de estado global do jogo.
##
## Guarda o que é compartilhado entre cenas: sessão, configurações e
## o navio do jogador. Não contém lógica de rede (isso fica em NetworkClient).
##
## Acesso em qualquer script: `GameManager.<membro>`.

## Emitido quando o estado do jogador muda, para a UI reagir sem acoplamento.
@warning_ignore("unused_signal")
signal player_state_changed(state: Dictionary)

## Identificador do jogador logado, vazio enquanto não há sessão.
var player_id: String = ""

## Estado do navio preservado na troca de cena oceano -> porto -> oceano (cada
## transição descarrega a cena anterior, então o navio não sobrevive sozinho).
## -1 significa "nada salvo"; `ocean_map.gd` aplica só quando >= 0 e depois reseta.
var saved_hull: float = -1.0
var saved_supply: float = -1.0
var saved_ship_position: Vector2 = Vector2.ZERO


func clear_saved_ship_state() -> void:
	saved_hull = -1.0
	saved_supply = -1.0


## Qual bairro foi clicado no mapa da ilha (`island_tortuga_hub.gd`), lido por
## `city_district_base.gd` no próprio `_ready()` pra se configurar -- não dá pra
## passar parâmetro direto num `change_scene_to_file`, então viaja por aqui.
var pending_district_title: String = ""
var pending_district_body: String = ""


func _ready() -> void:
	# Ponto de inicialização: carregar configurações locais, se houver.
	pass
