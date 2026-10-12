class_name TradeModal
extends PanelContainer
## Modal de interação reutilizável pra qualquer distrito: título, N abas
## configuráveis (construídas em código a partir de `tabs`, não fixas em
## cena) e até 2 botões de ação por baixo (`action_buttons`) -- "Comprar"/
## "Vender" numa loja, só "Fabricar" numa estação de crafting, "Nova Ordem"
## no Marketplace. Cada aba é um placeholder "Em breve" por ora; `resource_hint`
## é uma linha opcional de texto (ex. a lista de materiais do Ferreiro).
##
## Mesmo componente serve Taverna, Ferreiro, Estaleiro, Boticário, Marketplace
## e Mercado Feirante -- só a configuração muda por cena. Sem lógica de
## inventário, receita ou preço ainda: é a estrutura, pronta pra receber isso.

@export var shop_title: String = "Loja"
@export var tabs: PackedStringArray = ["Categoria 1", "Categoria 2"]
@export var action_buttons: PackedStringArray = ["Comprar", "Vender"]
@export_multiline var resource_hint: String = ""

@onready var _title: Label = $Margin/VBox/Header/Title
@onready var _tabs_box: HBoxContainer = $Margin/VBox/Tabs
@onready var _pages_root: Control = $Margin/VBox/Pages

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []


func _ready() -> void:
	visible = false
	_title.text = shop_title
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	_build_tabs()
	if tabs.size() > 0:
		_select_tab(0)


func open() -> void:
	visible = true


func close() -> void:
	visible = false


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
				actions.add_child(action_btn)
			page.add_child(actions)

		_pages_root.add_child(page)
		_pages.append(page)


func _select_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].disabled = i == index
