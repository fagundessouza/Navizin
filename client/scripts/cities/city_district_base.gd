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

const STATION_GLOW_SHADER: Shader = preload("res://assets/shaders/station_highlight.gdshader")
const STATION_GLOW_MARGIN: float = 2.6

@onready var _title: Label = $Title
@onready var _body: Label = $Body

var _glow_phase_counter: int = 0
## Button -> ColorRect do brilho dele -- precisa pra esconder/mostrar o
## brilho JUNTO com o botão (ver bug corrigido em `_add_station_glow`).
var _station_glows: Dictionary = {}

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
	_wire_modal("OpenVaultButton", "VaultModal", false)


## Liga um botão "Abrir X" a um modal filho, se os dois nós existirem --
## Mural de Recompensas e Guilda não são loja, não têm essa dupla; Taverna/
## Boticário/Feira têm só o par de loja; Forja/Estaleiro têm os dois pares
## (loja antiga + fabricação nova). `auto_open` abre o modal já ao entrar no
## distrito (só faz sentido pro TradeModal -- CraftingModal fica fechado até
## o jogador clicar, senão a tela entra com 2 janelas por cima uma da outra).
##
## Passa por `UIManager.open_modal()` em vez de chamar `modal.open` direto --
## ele fecha qualquer outro modal urbano que já estivesse aberto antes
## (Loja/Fabricar/Refinar não deveriam empilhar) e traz este pra frente.
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
	_add_station_glow(button)
	button.pressed.connect(UIManager.open_modal.bind(modal))
	modal.opened.connect(_on_modal_opened.bind(button))
	modal.closed.connect(_on_modal_closed.bind(button))
	if auto_open:
		UIManager.open_modal(modal)


## Luz quente pulsando atrás do botão -- "destaque visual às estações" pedido
## explicitamente, igual pros 8 bairros de uma vez (genérico aqui na base, em
## vez de editar cada `.tscn` individualmente). Fica ATRÁS do botão
## (`move_to_front()` no botão depois de inserido) e um pouco maior que ele
## (`STATION_GLOW_MARGIN`), com `mouse_filter = IGNORE` pra não roubar o
## clique. Ver nota no shader sobre por que isso não é Lit 2D de verdade.
func _add_station_glow(button: Button) -> void:
	var glow := ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.color = Color.WHITE
	var grow_x: float = button.size.x * (STATION_GLOW_MARGIN - 1.0) * 0.5
	var grow_y: float = button.size.y * (STATION_GLOW_MARGIN - 1.0) * 0.5
	glow.position = button.position - Vector2(grow_x, grow_y)
	glow.size = button.size * STATION_GLOW_MARGIN
	var mat := ShaderMaterial.new()
	mat.shader = STATION_GLOW_SHADER
	_glow_phase_counter += 1
	mat.set_shader_parameter("phase_offset", fmod(float(_glow_phase_counter) * 1.73, TAU))
	glow.material = mat
	button.get_parent().add_child(glow)
	glow.z_index = button.z_index
	button.move_to_front()
	_station_glows[button] = glow


## BUG ACHADO E CORRIGIDO NESTA RODADA ("remova qualquer luz amarela
## desposicionada poluindo as modais"): esconder `open_button` ao abrir o
## modal NUNCA escondia o brilho dele (nó irmão separado, sem relação de
## visibilidade) -- o brilho quente ficava aceso e visível flutuando sem
## botão embaixo, inclusive por cima/ao redor de modais que não cobrem a
## tela inteira. Agora o brilho segue a visibilidade do próprio botão.
func _on_modal_opened(open_button: Button) -> void:
	_open_modal_count += 1
	$Buttons.visible = false
	open_button.visible = false
	var glow: ColorRect = _station_glows.get(open_button)
	if glow != null:
		glow.visible = false


func _on_modal_closed(open_button: Button) -> void:
	_open_modal_count = maxi(0, _open_modal_count - 1)
	open_button.visible = true
	var glow: ColorRect = _station_glows.get(open_button)
	if glow != null:
		glow.visible = true
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
