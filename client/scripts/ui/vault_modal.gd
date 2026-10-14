class_name VaultModal
extends Control
## Cofre/Banco da Caverna do Tesouro: ficha de leitura dos recursos do
## jogador -- 2 abas, Materiais (tudo em `PlayerInventory.materials`,
## incluindo Pedra de Refino/Pergaminho de Proteção) e Itens Fabricados
## (tudo em `PlayerInventory.crafted_items`, com ícone, nome colorido pela
## raridade e o prefixo de refino). Só mostra, não transfere nem gasta nada
## ainda -- é um extrato, não um banco funcional de depósito/saque.

signal opened
signal closed

const OUTLINE_COLOR: Color = Color(0.03, 0.03, 0.04, 1.0)
const HOVER_COLOR: Color = Color(1.0, 0.92, 0.65, 1.0)
const NORMAL_FONT_COLOR: Color = Color(0.93, 0.9, 0.84, 1.0)
const ICON_FRAME_SIZE: float = 32.0
const ICON_BORDER_COLOR: Color = Color(0.78, 0.65, 0.38, 0.9)

@onready var _tabs_box: HBoxContainer = $Margin/VBox/Tabs
@onready var _materials_list: VBoxContainer = $Margin/VBox/Pages/Materials/List
@onready var _items_list: VBoxContainer = $Margin/VBox/Pages/Items/List

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []


func _ready() -> void:
	visible = false
	_style_button($Margin/VBox/Header/CloseButton)
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	_tab_buttons = [$Margin/VBox/Tabs/MaterialsTab, $Margin/VBox/Tabs/ItemsTab]
	_pages = [$Margin/VBox/Pages/Materials, $Margin/VBox/Pages/Items]
	for i in _tab_buttons.size():
		_style_button(_tab_buttons[i])
		_tab_buttons[i].pressed.connect(_select_tab.bind(i))
	_select_tab(0)
	PlayerInventory.changed.connect(_on_inventory_changed)


func open() -> void:
	visible = true
	_rebuild()
	opened.emit()


func close() -> void:
	visible = false
	closed.emit()


func _on_inventory_changed() -> void:
	if visible:
		_rebuild()


func _select_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].disabled = i == index


func _rebuild() -> void:
	for child in _materials_list.get_children():
		child.queue_free()
	var names: Array = PlayerInventory.materials.keys()
	names.sort()
	for material_name in names:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = material_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", NORMAL_FONT_COLOR)
		row.add_child(name_label)
		var qty_label := Label.new()
		qty_label.text = str(PlayerInventory.materials[material_name])
		qty_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4))
		row.add_child(qty_label)
		_materials_list.add_child(row)

	for child in _items_list.get_children():
		child.queue_free()
	if PlayerInventory.crafted_items.is_empty():
		var empty := Label.new()
		empty.text = "Nenhum item fabricado guardado ainda."
		empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
		_items_list.add_child(empty)
	else:
		for instance_id in PlayerInventory.crafted_items:
			_items_list.add_child(_build_item_row(instance_id))


func _build_item_row(instance_id: String) -> Control:
	var rarity: Dictionary = PlayerInventory.get_item_rarity(instance_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_make_icon_frame(PlayerInventory.get_item_icon(instance_id)))

	var name_label := Label.new()
	name_label.text = PlayerInventory.get_item_name(instance_id)
	name_label.tooltip_text = PlayerInventory.get_float_tooltip_line(instance_id)
	name_label.add_theme_color_override("font_color", rarity["color"])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	return row


func _make_icon_frame(icon: Texture2D) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(ICON_FRAME_SIZE, ICON_FRAME_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.04, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = ICON_BORDER_COLOR
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	frame.add_theme_stylebox_override("panel", style)

	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(icon_rect)
	return frame


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
