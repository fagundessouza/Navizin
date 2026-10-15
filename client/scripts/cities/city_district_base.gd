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
## JANELA ÚNICA POR ESTAÇÃO (pedido explícito desta rodada -- "elimine os
## botões redundantes"): até a rodada passada, Forja/Estaleiro/Feira/
## Boticário/Caverna tinham 2-3 botões cada (`OpenShopButton` abrindo uma
## `TradeModal` que nunca teve conteúdo de verdade -- toda aba dela sempre
## foi um placeholder "Em breve" -- mais `OpenCraftingButton`/
## `OpenRefinementButton` pras janelas reais). `TradeModal` foi removida de
## todo distrito que tinha uma estação de verdade por trás: não sobrou
## nenhuma categoria "loja" com conteúdo nenhum pra justificar o botão a
## mais, e o Refino passou a morar DENTRO do `CraftingModal`
## (`RefineButton` no cabeçalho dele), não mais um botão separado aqui. Só
## sobrou `OpenCraftingButton`/`OpenVaultButton`, um por distrito -- mais
## `OpenCrewButton`/`CrewCardModal` na Taverna (rodada seguinte, roleta de
## Marinheiros), que `_wire_modal()` também tenta em todo distrito mas só
## encontra onde o par de nós existe de verdade.
##
## BRILHO DE ESTAÇÃO REMOVIDO (pedido explícito -- "elimine a iluminação
## amarela borrada"): a rodada anterior botava um `ColorRect` com
## `station_highlight.gdshader` atrás de cada botão pra "destacar a
## estação". Removido de vez -- com 1 botão só por distrito (bem maior que
## antes, por padrão), não precisa mais de um brilho adicional chamando
## atenção pra ele.
##
## Ainda sem personagem andando -- fica para quando o visual AQW/multiplayer
## entrar de verdade. `PlayerSpawnPoint` já existe pronto pra isso: é só
## instanciar o navio/avatar ali quando chegar a hora.

@export var district_title: String = ""
@export_multiline var district_body: String = ""

@onready var _title: Label = $Title
@onready var _body: Label = $Body

## Quantos modais de distrito estão abertos agora -- os botões de navegação
## só reaparecem quando chega a 0.
var _open_modal_count: int = 0


func _ready() -> void:
	_title.text = district_title
	_body.text = district_body
	$Buttons/BackToIsland.pressed.connect(_on_back_to_island)
	$Buttons/BackToSea.pressed.connect(_on_back_to_sea)
	_wire_modal("OpenCraftingButton", "CraftingModal")
	_wire_modal("OpenVaultButton", "VaultModal")
	_wire_modal("OpenCrewButton", "CrewCardModal")


## Liga o botão "Abrir X" (um só por distrito agora) ao modal filho, se os
## dois nós existirem.
##
## Passa por `UIManager.open_modal()` em vez de chamar `modal.open` direto --
## ele fecha qualquer outro modal urbano que já estivesse aberto antes e
## traz este pra frente.
##
## Enquanto o modal está aberto, esconde "Mapa da Ilha"/"Voltar ao Mar" e o
## botão de abrir dele -- com os modais grandes (principalmente o de
## Fabricação, bem cheio) eles ficavam sobrepostos/por baixo, clicáveis sem
## aparecer.
func _wire_modal(button_name: String, modal_name: String) -> void:
	var button: Button = get_node_or_null(button_name)
	var modal: Control = get_node_or_null(modal_name)
	if button == null or modal == null:
		return
	button.pressed.connect(UIManager.open_modal.bind(modal))
	modal.opened.connect(_on_modal_opened.bind(button))
	modal.closed.connect(_on_modal_closed.bind(button))


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
