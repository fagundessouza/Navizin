class_name CityDistrictBase
extends Control
## Base pra um bairro/praça da cidade (taverna, forja, boticário...), no
## estilo AQW/Swords and Sandals: um fundo panorâmico 2D dedicado (interior ou
## cenário próprio daquele bairro), não mais um popup de texto sobre o mapa
## da ilha.
##
## Cada bairro é a sua PRÓPRIA cena em `scenes/cities/districts/`, herdando a
## estrutura comum (fundo, título, texto, botões). `district_title`/
## `district_body` são @export pra cada cena-filha preencher direto, sem
## precisar de estado global.
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
	_wire_shop()


## Abre o `TradeModal` IMEDIATAMENTE ao entrar no distrito -- nada de clicar
## num botão primeiro, só nos distritos que têm os dois nós (Mural de
## Recompensas e Guilda não são loja, não têm essa dupla). O botão continua
## ligado, pra reabrir o modal se o jogador fechar e quiser ver de novo.
##
## Enquanto o modal está aberto, esconde "Mapa da Ilha"/"Voltar ao Mar" e o
## próprio botão de abrir -- com o modal grande (principalmente o da Taverna,
## de 4 abas) eles ficavam sobrepostos/por baixo, clicáveis sem aparecer.
func _wire_shop() -> void:
	var button: Button = get_node_or_null("OpenShopButton")
	var modal: Control = get_node_or_null("TradeModal")
	if button == null or modal == null:
		return
	button.pressed.connect(modal.open)
	modal.opened.connect(_on_modal_opened.bind(button))
	modal.closed.connect(_on_modal_closed.bind(button))
	modal.open()


func _on_modal_opened(open_button: Button) -> void:
	$Buttons.visible = false
	open_button.visible = false


func _on_modal_closed(open_button: Button) -> void:
	$Buttons.visible = true
	open_button.visible = true


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
