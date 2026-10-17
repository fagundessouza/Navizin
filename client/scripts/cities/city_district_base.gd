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

## PONTO DE EXTENSÃO DOCUMENTADO, NÃO IMPLEMENTADO (visão descrita pelo
## usuário, fora do escopo desta rodada -- só a unificação do fluxo de
## abertura foi pedida/confirmada aqui): a Taverna deve ganhar no futuro um
## 3º botão/estação -- um Mural de Contratos -- com (a) contratos de
## recompensa postados sobre NPCs/alvos, e (b) encomendas jogador-pra-jogador
## (ex.: "pago X Ouro por unidade de Madeira de Carvalho entregue") que
## qualquer outro jogador pode aceitar e cumprir. O preço/oferta de cada
## encomenda é POR CIDADE (estilo Albion Online -- mercados locais, não um
## preço global entre ilhas), o que also significa que quando as outras
## ilhas existirem, cada uma terá seu próprio Mural independente. Esse 3º
## botão se encaixa direto no `_wired`/`_finalize_entry_flow()` acima sem
## mudar a lógica de menu rápido (ela já lida com N estações, não só 2) --
## só precisa de um novo modal_id registrado em `UIManager` e um sistema de
## dados (contratos por cidade, não um dicionário global) quando for a hora
## de construir isso de verdade.

@onready var _title: Label = $Title
@onready var _body: Label = $Body
@onready var _modal_overlay: Control = $ModalOverlay

## Quantos modais de distrito estão abertos agora -- os botões de navegação
## só reaparecem quando chega a 0.
var _open_modal_count: int = 0

## Cada `_wire_modal()` bem-sucedido entra aqui -- usado por
## `_finalize_entry_flow()` pra decidir como entrar na praça (ver abaixo).
var _wired: Array[Dictionary] = []

## "menu" quando a praça tem 2+ estações (só a Taverna hoje) -- nesse modo o
## botão isolado original fica escondido pra sempre, substituído por
## `_quick_menu`. "single"/"none" mantêm o botão original como estava.
var _entry_mode: String = "none"
var _quick_menu: Control = null


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
	_finalize_entry_flow()


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
	_wired.append({"button": button, "modal": modal})


## ENTRADA DIRETA (pedido explícito -- "o clique na construção deve abrir
## IMEDIATAMENTE o modal centralizado", sem a etapa de ver um botão isolado
## primeiro). Decide como entrar na praça de acordo com quantas estações reais
## ela tem:
## - 0 (praças "Em construção": Salão das Frotas; ou com botão ainda não
##   religado a modal nenhum: Mercado Central) -- nada muda, continua só o
##   cenário + navegação.
## - 1 (Forja/Estaleiro/Boticário/Feira de Suprimentos/Caverna do Tesouro) --
##   abre a estação direto, sem clique nenhum. O botão original continua
##   escondido enquanto ela estiver aberta e volta a aparecer se o jogador
##   fechar (reentrada manual), exatamente como já funcionava -- só a ESPERA
##   do primeiro clique que foi embora.
## - 2+ (só a Taverna hoje: Tripulação + Oficiais) -- os 2 botões isolados no
##   canto saem de cena pra sempre, substituídos por `_quick_menu`: as mesmas
##   2 opções reais, centralizadas, pra escolher qual estação abrir.
func _finalize_entry_flow() -> void:
	if _wired.is_empty():
		return
	if _wired.size() == 1:
		_entry_mode = "single"
		UIManager.open_modal(_wired[0]["modal"])
		return
	_entry_mode = "menu"
	for entry in _wired:
		(entry["button"] as Button).visible = false
	# `_build_quick_menu()` PRIMEIRO, só depois `close()`: `close()` dispara
	# `closed` -> `_on_modal_closed()` na hora (síncrono), que já tenta mexer
	# em `_quick_menu` -- achado rodando de verdade via MCP (`Invalid
	# assignment... base object of type 'Nil'`), fechar antes de construir o
	# menu lia `_quick_menu` ainda nulo.
	_build_quick_menu()
	for entry in _wired:
		# Vários modais (ex. `CrewCardModal`) nascem com `visible = true` no
		# próprio `_ready()` -- sem este `close()`, as 2 estações da Taverna
		# apareciam abertas por baixo do menu rápido assim que a praça
		# carregava, nunca escondidas de fato.
		(entry["modal"] as Control).close()


func _build_quick_menu() -> void:
	_quick_menu = VBoxContainer.new()
	_quick_menu.add_theme_constant_override("separation", 10)
	for entry in _wired:
		var option := Button.new()
		option.text = (entry["button"] as Button).text
		option.custom_minimum_size = Vector2(240, 48)
		option.pressed.connect(UIManager.open_modal.bind(entry["modal"]))
		_quick_menu.add_child(option)
	add_child(_quick_menu)
	_quick_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)


func _on_modal_opened(open_button: Button) -> void:
	_open_modal_count += 1
	$Buttons.visible = false
	if _entry_mode == "menu" and _quick_menu != null:
		_quick_menu.visible = false
	elif _entry_mode != "menu":
		open_button.visible = false


func _on_modal_closed(open_button: Button) -> void:
	_open_modal_count = maxi(0, _open_modal_count - 1)
	if _open_modal_count == 0:
		$Buttons.visible = true
		if _entry_mode == "menu" and _quick_menu != null:
			_quick_menu.visible = true
		else:
			open_button.visible = true


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
