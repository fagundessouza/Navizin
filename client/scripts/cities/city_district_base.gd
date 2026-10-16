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
## `OpenCrewButton`/`CrewCardModal` e `OpenOfficersButton`/`OfficersModal`
## na Taverna (roleta de Marinheiros/Operários + contratação de Oficiais,
## que `_wire_modal()` também tenta em todo distrito mas só encontra onde o
## par de nós existe de verdade). Oficial só se contrata aqui agora -- a
## instância de `CrewManagementSubmodal` que a Ficha do Navio abre é
## `read_only = true` (pedido explícito, "não deveria permitir contratar
## sem ir na Taverna").
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

## MIGRAÇÃO PRA INSTANCIAÇÃO EM RUNTIME (pedido explícito, reverte a decisão
## anterior desta sessão -- ver `.clauderules`/checkpoint): `CraftingModal`/
## `VaultModal`/`CrewCardModal`/`CrewManagementSubmodal` não são mais filhos
## fixos de cada `.tscn` de distrito. Como os 4 distritos de Fabricação
## (Forja/Estaleiro/Boticário/Feira) usam o MESMO `CraftingModal` com config
## DIFERENTE cada um (antes definida direto no nó filho do `.tscn`, que não
## existe mais), esses campos substituem aquilo -- cada cena de distrito
## preenche só os que usa, os outros ficam vazios/default e `_wire_modal()`
## só aplica a config quando o botão correspondente existir de verdade.
@export_group("Fabricação (CraftingModal)")
@export var crafting_panel_title: String = ""
@export var crafting_station: String = ""
@export var crafting_categories: PackedStringArray = []
@export var crafting_category_labels: PackedStringArray = []
@export var crafting_category_stations: PackedStringArray = []

## Só a Taverna usa isto hoje ("Contratar Oficiais" -- `read_only = false`,
## diferente da instância somente-consulta que a Ficha do Navio abre).
@export_group("Oficiais (CrewManagementSubmodal)")
@export var officers_read_only: bool = false
@export var officers_show_sailors_section: bool = true

@onready var _title: Label = $Title
@onready var _body: Label = $Body
@onready var _modal_overlay: Control = $ModalOverlay

## Quantos modais de distrito estão abertos agora -- os botões de navegação
## só reaparecem quando chega a 0.
var _open_modal_count: int = 0


func _ready() -> void:
	_title.text = district_title
	_body.text = district_body
	$Buttons/BackToIsland.pressed.connect(_on_back_to_island)
	$Buttons/BackToSea.pressed.connect(_on_back_to_sea)
	_wire_modal("OpenCraftingButton", "crafting", func(m):
		m.panel_title = crafting_panel_title
		m.station = crafting_station
		m.categories = crafting_categories
		m.category_labels = crafting_category_labels
		m.category_stations = crafting_category_stations)
	_wire_modal("OpenVaultButton", "vault")
	_wire_modal("OpenCrewButton", "crew_card")
	_wire_modal("OpenOfficersButton", "crew_management", func(m):
		m.read_only = officers_read_only
		m.show_sailors_section = officers_show_sailors_section)


## Liga o botão "Abrir X" (um só por distrito agora) ao modal, instanciado
## em runtime pelo `UIManager` na primeira vez que o botão existir (muitos
## distritos não têm um ou outro -- `get_node_or_null` continua sendo o
## guard, só que agora só checa o BOTÃO, não mais um nó de modal que não
## existe mais na cena).
##
## Passa por `UIManager.open_modal()` em vez de chamar `modal.open` direto --
## ele fecha qualquer outro modal urbano que já estivesse aberto antes e
## traz este pra frente.
##
## Enquanto o modal está aberto, esconde "Mapa da Ilha"/"Voltar ao Mar" e o
## botão de abrir dele -- com os modais grandes (principalmente o de
## Fabricação, bem cheio) eles ficavam sobrepostos/por baixo, clicáveis sem
## aparecer.
func _wire_modal(button_name: String, modal_id: String, configure: Callable = Callable()) -> void:
	var button: Button = get_node_or_null(button_name)
	if button == null:
		return
	var modal: Control = UIManager.get_modal(modal_id, _modal_overlay, configure)
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
	# Achado migrando pra `UIManager` (pedido explícito desta rodada): com
	# um modal de distrito aberto, ESC agora também é o atalho de
	# `UIManager._unhandled_input()` pra fechar o modal no topo -- sem este
	# guard, os dois ouviam o MESMO ui_cancel, e dependendo da ordem de
	# processamento (`_unhandled_input` roda dos nós mais profundos pros
	# mais rasos, autoload incluso) o distrito podia navegar de volta pra
	# ilha ANTES do modal ter a chance de só fechar. `_open_modal_count` já
	# era rastreado (ver `_on_modal_opened`/`_on_modal_closed`) -- com um
	# modal aberto, este handler não faz nada e deixa o `UIManager` cuidar.
	if _open_modal_count > 0:
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
