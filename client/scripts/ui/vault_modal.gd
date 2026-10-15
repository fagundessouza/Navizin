class_name VaultModal
extends Control
## Cofre/Banco da Caverna do Tesouro: ficha de leitura dos recursos do
## jogador -- 3 abas, Materiais (`ShipInventory.materials`, incluindo Pedra
## de Refino/Pergaminho de Proteção/Kit de Reparo), Itens do Navio
## (`ShipInventory.crafted_items` -- destruível, some se o navio afundar) e
## Itens do Capitão (`CaptainInventory.crafted_items` -- permanente). 3
## abas em vez de 2 porque os dois inventários viraram autoloads separados
## nesta rodada (antes eram um só, `player_inventory.gd`, com "Itens
## Fabricados" mostrando os dois juntos sem distinção). Só mostra, não
## transfere nem gasta nada ainda -- é um extrato, não um banco funcional
## de depósito/saque.
##
## GRADE DE ÍCONES + ZOOM: ícone recortado (`ItemDatabase.get_material_icon()`
## pra material bruto, desenhado do zero já que não existe arte de material
## em nenhuma prancha), quantidade/nome, e zoom ao passar o mouse
## (`ItemTooltipZoom`).
##
## PAGINAÇÃO: mesma técnica de `crafting_modal.gd` (6-8 por página, aqui
## generoso em colunas então cabe mais por ser `GridContainer`).

signal opened
signal closed

const OUTLINE_COLOR: Color = Color(0.03, 0.03, 0.04, 1.0)
const HOVER_COLOR: Color = Color(1.0, 0.92, 0.65, 1.0)
const NORMAL_FONT_COLOR: Color = Color(0.93, 0.9, 0.84, 1.0)
const ICON_FRAME_SIZE: float = 40.0
const ICON_BORDER_COLOR: Color = Color(0.78, 0.65, 0.38, 0.9)
const ITEM_SOFTENER_SHADER: Shader = preload("res://assets/shaders/ui_item_softener.gdshader")
const GRID_COLUMNS: int = 6
const PAGE_SIZE: int = 18

@onready var _tabs_box: HBoxContainer = $Margin/VBox/Tabs
@onready var _materials_grid: GridContainer = $Margin/VBox/Pages/Materials/Grid
@onready var _ship_items_grid: GridContainer = $Margin/VBox/Pages/ShipItems/Grid
@onready var _captain_items_grid: GridContainer = $Margin/VBox/Pages/CaptainItems/Grid
@onready var _tooltip_zoom: ItemTooltipZoom = $ItemTooltipZoom

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _grids: Array[GridContainer] = []
var _page_index: Array[int] = [0, 0, 0]


func _ready() -> void:
	visible = false
	_style_button($Margin/VBox/Header/CloseButton)
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	_tab_buttons = [$Margin/VBox/Tabs/MaterialsTab, $Margin/VBox/Tabs/ShipItemsTab, $Margin/VBox/Tabs/CaptainItemsTab]
	_pages = [$Margin/VBox/Pages/Materials, $Margin/VBox/Pages/ShipItems, $Margin/VBox/Pages/CaptainItems]
	_grids = [_materials_grid, _ship_items_grid, _captain_items_grid]
	for grid in _grids:
		grid.columns = GRID_COLUMNS
	for i in _tab_buttons.size():
		_style_button(_tab_buttons[i])
		_tab_buttons[i].pressed.connect(_select_tab.bind(i))
	for i in _pages.size():
		var prev: Button = _pages[i].get_node("Pager/Prev")
		var next: Button = _pages[i].get_node("Pager/Next")
		_style_button(prev)
		_style_button(next)
		prev.pressed.connect(_on_page_nav.bind(i, -1))
		next.pressed.connect(_on_page_nav.bind(i, 1))
	_select_tab(0)
	ShipInventory.changed.connect(_on_inventory_changed)
	CaptainInventory.changed.connect(_on_inventory_changed)


func open() -> void:
	visible = true
	UIManager.animate_modal_open(self)
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


func _entries_for_tab(tab_index: int) -> Array:
	match tab_index:
		0:
			var names: Array = ShipInventory.materials.keys()
			names.sort()
			return names
		1:
			return ShipInventory.crafted_items.keys()
		_:
			return CaptainInventory.crafted_items.keys()


func _on_page_nav(tab_index: int, delta: int) -> void:
	var page_count: int = _page_count(_entries_for_tab(tab_index).size())
	_page_index[tab_index] = clampi(_page_index[tab_index] + delta, 0, page_count - 1)
	_rebuild()


func _page_count(total_items: int) -> int:
	return maxi(1, ceili(float(total_items) / float(PAGE_SIZE)))


func _rebuild() -> void:
	_rebuild_grid_page(0, _materials_grid, _entries_for_tab(0), func(name: String) -> Control: return _build_material_cell(name))
	_rebuild_grid_page(1, _ship_items_grid, _entries_for_tab(1), func(iid: String) -> Control: return _build_item_cell(iid, ShipInventory))
	_rebuild_grid_page(2, _captain_items_grid, _entries_for_tab(2), func(iid: String) -> Control: return _build_item_cell(iid, CaptainInventory))


## Fatiador de página genérico pras 3 abas -- cada uma só difere no builder
## de célula (`cell_builder`), tudo o resto (clamping de página, slice,
## texto/estado do pager) é idêntico.
func _rebuild_grid_page(tab_index: int, grid: GridContainer, entries: Array, cell_builder: Callable) -> void:
	for child in grid.get_children():
		child.queue_free()

	var pager: HBoxContainer = _pages[tab_index].get_node("Pager")
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "Nada guardado ainda."
		empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
		grid.add_child(empty)
		pager.visible = false
		return

	var page_count: int = _page_count(entries.size())
	_page_index[tab_index] = clampi(_page_index[tab_index], 0, page_count - 1)
	var start: int = _page_index[tab_index] * PAGE_SIZE
	var end: int = mini(start + PAGE_SIZE, entries.size())
	for entry in entries.slice(start, end):
		grid.add_child(cell_builder.call(entry))

	pager.visible = page_count > 1
	if pager.visible:
		pager.get_node("PageLabel").text = "Página %d de %d" % [_page_index[tab_index] + 1, page_count]
		pager.get_node("Prev").disabled = _page_index[tab_index] == 0
		pager.get_node("Next").disabled = _page_index[tab_index] >= page_count - 1


## Uma célula da grade de Materiais: ícone + quantidade embaixo, com hover
## zoom (modo "recipe-like" simplificado -- materiais não são um item de
## `ItemDatabase`, não tem receita/raridade, só ícone e nome, então monta um
## dicionário mínimo pro tooltip em vez de reusar `show_for_recipe`).
func _build_material_cell(material_name: String) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.custom_minimum_size = Vector2(ICON_FRAME_SIZE + 8, 0)

	var frame := _make_icon_frame(ItemDatabase.get_material_icon(material_name))
	frame.mouse_entered.connect(_on_material_hover.bind(frame, material_name))
	frame.mouse_exited.connect(_tooltip_zoom.hide_tooltip)
	UIManager.add_hover_pop(frame, material_name)
	cell.add_child(frame)

	var qty_label := Label.new()
	qty_label.text = str(ShipInventory.materials[material_name])
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4))
	qty_label.add_theme_font_size_override("font_size", 13)
	cell.add_child(qty_label)
	return cell


func _on_material_hover(frame: Control, material_name: String) -> void:
	var local_pos: Vector2 = frame.global_position - global_position + Vector2(frame.size.x, 0)
	_tooltip_zoom.show_for_material(material_name, ShipInventory.materials[material_name], local_pos, size)


func _build_item_cell(instance_id: String, inv: Node) -> Control:
	var rarity: Dictionary = inv.get_item_rarity(instance_id)
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.custom_minimum_size = Vector2(ICON_FRAME_SIZE + 8, 0)

	var frame := _make_icon_frame(inv.get_item_icon(instance_id))
	frame.mouse_entered.connect(_on_item_hover.bind(frame, instance_id))
	frame.mouse_exited.connect(_tooltip_zoom.hide_tooltip)
	UIManager.add_hover_pop(frame, instance_id)
	cell.add_child(frame)

	var name_label := Label.new()
	name_label.text = inv.get_item_name(instance_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CraftingManager.style_item_label(name_label, rarity)
	name_label.add_theme_font_size_override("font_size", 11)
	cell.add_child(name_label)
	return cell


func _on_item_hover(frame: Control, instance_id: String) -> void:
	var local_pos: Vector2 = frame.global_position - global_position + Vector2(frame.size.x, 0)
	_tooltip_zoom.show_for_instance(instance_id, local_pos, size)


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
	icon_rect.material = ShaderMaterial.new()
	icon_rect.material.shader = ITEM_SOFTENER_SHADER
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
