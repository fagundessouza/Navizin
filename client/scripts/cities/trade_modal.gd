class_name TradeModal
extends Control
## Modal de interação reutilizável pra qualquer distrito: retrato + saudação
## dinâmica do NPC no topo (via `ReputationManager`), N abas configuráveis
## (construídas em código a partir de `tabs`, não fixas em cena) e até 2
## botões de ação por baixo (`action_buttons`) -- "Comprar"/"Vender" numa
## loja, só "Fabricar" numa estação de crafting, "Nova Ordem" no Marketplace.
## Cada aba é um placeholder "Em breve" por ora; `resource_hint` é uma linha
## opcional de texto (ex. a lista de materiais do Ferreiro).
##
## Mesmo componente serve Taverna, Ferreiro, Estaleiro, Boticário, Marketplace
## e Feira de Suprimentos -- só a configuração muda por cena. Sem lógica de
## inventário, receita ou preço ainda: é a estrutura, pronta pra receber isso.
##
## Abre direto ao entrar no distrito (`city_district_base.gd._wire_shop`),
## sem caixa de diálogo intermediária -- ver essa saudação já É a transição.

## Pra quem precisa reagir à abertura/fechamento (ex. `city_district_base.gd`
## escondendo os botões de navegação por baixo, que ficavam sobrepostos).
signal opened
signal closed

@export var shop_title: String = "Loja"
@export var tabs: PackedStringArray = ["Categoria 1", "Categoria 2"]
@export var action_buttons: PackedStringArray = ["Comprar", "Vender"]
@export_multiline var resource_hint: String = ""
@export var npc_name: String = ""

@onready var _title: Label = $Margin/VBox/Header/Title
@onready var _greeting_label: Label = $Margin/VBox/Greeting/Texts/GreetingLabel
@onready var _tabs_box: HBoxContainer = $Margin/VBox/Tabs
@onready var _pages_root: Control = $Margin/VBox/Pages

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []

const OUTLINE_COLOR: Color = Color(0.03, 0.03, 0.04, 1.0)
const HOVER_COLOR: Color = Color(1.0, 0.92, 0.65, 1.0)
const NORMAL_FONT_COLOR: Color = Color(0.93, 0.9, 0.84, 1.0)


func _ready() -> void:
	visible = false
	_title.text = shop_title
	_greeting_label.text = ReputationManager.get_greeting(npc_name)
	_style_button($Margin/VBox/Header/CloseButton)
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	_build_tabs()
	if tabs.size() > 0:
		_select_tab(0)


func open() -> void:
	visible = true
	_greeting_label.text = ReputationManager.get_greeting(npc_name)
	opened.emit()


func close() -> void:
	visible = false
	closed.emit()


## Monta os botões de aba e as páginas em código: cada distrito define um
## número diferente de abas (2 na maioria, 4 na Taverna), então não dá pra
## deixar isso fixo na cena-modelo.
func _build_tabs() -> void:
	for i in tabs.size():
		var tab_name: String = tabs[i]

		var button := Button.new()
		button.text = tab_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_tab.bind(i))
		_style_button(button)
		_tabs_box.add_child(button)
		_tab_buttons.append(button)

		var page := VBoxContainer.new()
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		page.add_theme_constant_override("separation", 10)
		page.visible = false

		var placeholder := Label.new()
		placeholder.text = "Em breve."
		placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
		page.add_child(placeholder)

		if resource_hint != "":
			var hint := Label.new()
			hint.text = resource_hint
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD
			hint.add_theme_color_override("font_color", Color(0.76, 0.7, 0.5))
			hint.add_theme_font_size_override("font_size", 13)
			page.add_child(hint)

		if action_buttons.size() > 0:
			var actions := HBoxContainer.new()
			actions.alignment = BoxContainer.ALIGNMENT_CENTER
			actions.add_theme_constant_override("separation", 10)
			for action_text in action_buttons:
				var action_btn := Button.new()
				action_btn.text = action_text
				action_btn.custom_minimum_size = Vector2(120, 0)
				_style_button(action_btn)
				actions.add_child(action_btn)
			page.add_child(actions)

		_pages_root.add_child(page)
		_pages.append(page)


func _select_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].disabled = i == index


## Contorno escuro (legível em qualquer fundo) + cor de destaque no hover,
## pra não depender só do estado "disabled" do tema padrão pra dar contraste.
func _style_button(button: Button) -> void:
	button.add_theme_color_override("font_color", NORMAL_FONT_COLOR)
	button.add_theme_color_override("font_hover_color", HOVER_COLOR)
	button.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	button.add_theme_constant_override("outline_size", 3)
	button.mouse_entered.connect(_on_button_hover.bind(button, true))
	button.mouse_exited.connect(_on_button_hover.bind(button, false))


func _on_button_hover(button: Button, hovering: bool) -> void:
	var tw := create_tween()
	tw.tween_property(button, "modulate", Color(1.15, 1.1, 0.95) if hovering else Color.WHITE, 0.1)
