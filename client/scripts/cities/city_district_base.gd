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

## Quantos modais de distrito estão abertos agora -- os botões de navegação
## só reaparecem quando chega a 0. Mais de um pode ficar aberto ao mesmo
## tempo (ex: TradeModal auto-aberto + CraftingModal que o jogador abriu
## por cima), então não dá pra só alternar um bool no abrir/fechar de cada um.
var _open_modal_count: int = 0


func _ready() -> void:
	_title.text = district_title
	_body.text = district_body
	$Buttons/BackToIsland.pressed.connect(_on_back_to_island)
	$Buttons/BackToSea.pressed.connect(_on_back_to_sea)
	_wire_modal("OpenShopButton", "TradeModal", true)
	_wire_modal("OpenCraftingButton", "CraftingModal", false)
	_wire_modal("OpenRefinementButton", "RefinementModal", false)


## Liga um botão "Abrir X" a um modal filho, se os dois nós existirem --
## Mural de Recompensas e Guilda não são loja, não têm essa dupla; Taverna/
## Boticário/Feira têm só o par de loja; Forja/Estaleiro têm os dois pares
## (loja antiga + fabricação nova). `auto_open` abre o modal já ao entrar no
## distrito (só faz sentido pro TradeModal -- CraftingModal fica fechado até
## o jogador clicar, senão a tela entra com 2 janelas por cima uma da outra).
##
## Enquanto QUALQUER modal está aberto, esconde "Mapa da Ilha"/"Voltar ao
## Mar" e o botão de abrir dele -- com os modais grandes (principalmente o
## de Fabricação, bem cheio) eles ficavam sobrepostos/por baixo, clicáveis
## sem aparecer.
func _wire_modal(button_name: String, modal_name: String, auto_open: bool) -> void:
	var button: Button = get_node_or_null(button_name)
	var modal: Control = get_node_or_null(modal_name)
	if button == null or modal == null:
		return
	button.pressed.connect(modal.open)
	modal.opened.connect(_on_modal_opened.bind(button))
	modal.closed.connect(_on_modal_closed.bind(button))
	if auto_open:
		modal.open()


func _on_modal_opened(open_button: Button) -> void:
	_open_modal_count += 1
	$Buttons.visible = false
	open_button.visible = false


func _on_modal_closed(open_button: Button) -> void:
	_open_modal_count = maxi(0, _open_modal_count - 1)
	open_button.visible = true
	if _open_modal_count == 0:
		$Buttons.visible = true


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
