class_name CaptainPanel
extends Control
## Painel do capitão sobre o próprio navio/progresso -- mesmo padrão de N
## abas construídas em código do `TradeModal` (`scripts/cities/trade_modal.gd`),
## mas sem o cabeçalho de saudação de NPC: aqui não tem balcão nem vendedor,
## é o próprio jogador olhando a ficha dele, aberto pela barra de menus do HUD.
##
## `tab_bodies` é o texto de cada aba (paralelo a `tabs`, índice a índice);
## sem dado real rastreado ainda, cada aba sem corpo próprio vira "Em breve.".

signal opened
signal closed

@export var panel_title: String = "Painel"
@export var tabs: PackedStringArray = ["Aba 1"]
@export var tab_bodies: PackedStringArray = []

@onready var _title: Label = $Margin/VBox/Header/Title
@onready var _tabs_box: HBoxContainer = $Margin/VBox/Tabs
@onready var _pages_root: Control = $Margin/VBox/Pages

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []

const OUTLINE_COLOR: Color = Color(0.03, 0.03, 0.04, 1.0)
const HOVER_COLOR: Color = Color(1.0, 0.92, 0.65, 1.0)
const NORMAL_FONT_COLOR: Color = Color(0.93, 0.9, 0.84, 1.0)


func _ready() -> void:
	visible = false
	_title.text = panel_title
	_style_button($Margin/VBox/Header/CloseButton)
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	_build_tabs()
	if tabs.size() > 0:
		_select_tab(0)


func open() -> void:
	visible = true
	opened.emit()


func close() -> void:
	visible = false
	closed.emit()


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

		var body := Label.new()
		body.text = tab_bodies[i] if i < tab_bodies.size() and tab_bodies[i] != "" else "Em breve."
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body.autowrap_mode = TextServer.AUTOWRAP_WORD
		body.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
		page.add_child(body)

		_pages_root.add_child(page)
		_pages.append(page)


func _select_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].disabled = i == index


## Mesmo contorno + destaque no hover usado em `trade_modal.gd` -- repetido
## aqui porque os dois componentes não compartilham uma base comum ainda.
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
