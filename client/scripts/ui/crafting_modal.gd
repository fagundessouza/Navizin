class_name CraftingModal
extends Control
## Interface de fabricação de uma estação (Forja Naval ou Estaleiro): uma
## aba por categoria de item daquela estação, cada aba uma lista de receitas
## reais -- nome, tier (se tiver), material exigido com "tenho/preciso"
## colorido (verde = dá pra fabricar, vermelho = falta) e um botão
## "Fabricar" que consome os materiais e manda o item pro Porão do Navio
## (`PlayerInventory.craft()`). Nenhum item naval é vendido pronto -- é
## sempre fabricado aqui, igual ao pedido original.
##
## `categories`/`category_labels` definem as abas, paralelas índice a
## índice -- a mesma cena serve pra Forja (`["armamento","municao"]`) e pro
## Estaleiro (`["vela","casco","proa","relíquia_ebenruth","leme"]`), só
## muda o que é passado na instância.

signal opened
signal closed

@export var panel_title: String = "Fabricação"
@export var station: String = "forja"
@export var categories: PackedStringArray = []
@export var category_labels: PackedStringArray = []

const OUTLINE_COLOR: Color = Color(0.03, 0.03, 0.04, 1.0)
const HOVER_COLOR: Color = Color(1.0, 0.92, 0.65, 1.0)
const NORMAL_FONT_COLOR: Color = Color(0.93, 0.9, 0.84, 1.0)
const OK_COLOR: Color = Color(0.6, 0.82, 0.5, 1.0)
const MISSING_COLOR: Color = Color(0.85, 0.4, 0.35, 1.0)
const ICON_FRAME_SIZE: float = 40.0
const ICON_BORDER_COLOR: Color = Color(0.78, 0.65, 0.38, 0.9)
const RARITY_GLOW_SHADER: Shader = preload("res://assets/shaders/item_rarity_glow.gdshader")
## Pulso ambiente dourado em toda miniatura de receita (não é uma raridade de
## verdade -- a receita ainda não foi fabricada, não rolou nada). Tier IV
## (o mais alto de cada categoria tierizada) ganha o efeito de faíscas, no
## espírito de "Lendário/Divino" pedido -- é o tier mais cobiçado da
## categoria, mesmo antes de qualquer raridade rolar.
const AMBIENT_GLOW_COLOR: Color = Color(0.9, 0.8, 0.5, 1.0)

@onready var _tabs_box: HBoxContainer = $Margin/VBox/Tabs
@onready var _pages_root: Control = $Margin/VBox/Pages
@onready var _tooltip_zoom: ItemTooltipZoom = $ItemTooltipZoom

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []


func _ready() -> void:
	visible = false
	$Margin/VBox/Header/Title.text = panel_title
	_style_button($Margin/VBox/Header/CloseButton)
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	_build_tabs()
	if categories.size() > 0:
		_select_tab(0)
	PlayerInventory.changed.connect(_on_inventory_changed)


func open() -> void:
	visible = true
	_rebuild_pages()
	opened.emit()


func close() -> void:
	visible = false
	closed.emit()


func _on_inventory_changed() -> void:
	if visible:
		_rebuild_pages()


func _build_tabs() -> void:
	for i in categories.size():
		var button := Button.new()
		button.text = category_labels[i] if i < category_labels.size() else categories[i]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_tab.bind(i))
		_style_button(button)
		_tabs_box.add_child(button)
		_tab_buttons.append(button)

		var page := ScrollContainer.new()
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		page.visible = false
		var list := VBoxContainer.new()
		list.name = "List"
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 8)
		page.add_child(list)

		_pages_root.add_child(page)
		_pages.append(page)


func _select_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].disabled = i == index


## Reconstrói as linhas de receita de TODAS as abas -- chamado ao abrir e
## toda vez que `PlayerInventory` muda (fabricar um item pode deixar outra
## receita inviável, se dividiu o mesmo material).
func _rebuild_pages() -> void:
	for i in categories.size():
		var list: VBoxContainer = _pages[i].get_node("List")
		for child in list.get_children():
			child.queue_free()
		var recipe_ids: Array[String] = ItemDatabase.get_recipes_for(station, categories[i])
		if recipe_ids.is_empty():
			var empty := Label.new()
			empty.text = "Nenhuma receita aqui ainda."
			empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
			list.add_child(empty)
			continue
		for item_id in recipe_ids:
			list.add_child(_build_recipe_row(item_id))


func _build_recipe_row(item_id: String) -> Control:
	var item: Dictionary = ItemDatabase.get_item(item_id)
	var recipe: Dictionary = ItemDatabase.get_recipe(item_id)

	var row := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.07, 0.06, 0.55)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.corner_radius_bottom_right = 4
	row_style.content_margin_left = 10
	row_style.content_margin_right = 10
	row_style.content_margin_top = 6
	row_style.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", row_style)

	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	row.add_child(outer)
	var icon_frame := _make_icon_frame(item.get("icon"), item.get("tier", 0), item_id)
	icon_frame.mouse_entered.connect(_on_icon_hover.bind(icon_frame, item_id))
	icon_frame.mouse_exited.connect(_tooltip_zoom.hide_tooltip)
	outer.add_child(icon_frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var name_label := Label.new()
	var display_name: String = item.get("name", item_id)
	name_label.text = display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	name_label.add_theme_font_size_override("font_size", 15)
	header.add_child(name_label)

	var can_craft: bool = PlayerInventory.has_materials_for(item_id)

	var craft_button := Button.new()
	craft_button.text = "Fabricar"
	craft_button.disabled = not can_craft
	craft_button.pressed.connect(_on_craft_pressed.bind(item_id))
	_style_button(craft_button)
	header.add_child(craft_button)

	var materials_box := HBoxContainer.new()
	materials_box.add_theme_constant_override("separation", 14)
	vbox.add_child(materials_box)

	var materials: Dictionary = recipe["materials"]
	for material_name in materials:
		var needed: int = materials[material_name]
		var have: int = PlayerInventory.materials.get(material_name, 0)
		var mat_label := Label.new()
		mat_label.text = "%s %d/%d" % [material_name, have, needed]
		mat_label.add_theme_font_size_override("font_size", 12)
		mat_label.add_theme_color_override("font_color", OK_COLOR if have >= needed else MISSING_COLOR)
		materials_box.add_child(mat_label)

	return row


## Miniatura com borda gótica ao lado do nome da receita -- "exibir a
## miniatura da arte do item" pedido explicitamente. `icon` vem nulo pros
## poucos itens sem arte dedicada ainda; `TextureRect` com textura nula só
## fica em branco dentro da moldura, sem quebrar nada. A borda usa
## `item_rarity_glow.gdshader` ativo (pedido explícito), com faíscas pro
## Tier IV de cada categoria.
func _make_icon_frame(icon: Texture2D, tier: int, item_id: String) -> PanelContainer:
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

	var glow := ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = RARITY_GLOW_SHADER
	mat.set_shader_parameter("rarity_color", AMBIENT_GLOW_COLOR)
	mat.set_shader_parameter("aura_mode", 1 if tier >= 4 else 0)
	mat.set_shader_parameter("intensity", 0.7)
	# Fase por hash do item_id (não um contador) -- determinístico mesmo
	# depois de `_rebuild_pages()` recriar a linha do zero, e já evita todo
	# card pulsando junto sem precisar guardar estado entre reconstruções.
	mat.set_shader_parameter("phase_offset", fmod(float(item_id.hash() % 1000) * 0.37, TAU))
	glow.material = mat
	frame.add_child(glow)
	return frame


func _on_craft_pressed(item_id: String) -> void:
	PlayerInventory.craft(item_id)


## Hover zoom na miniatura da receita -- pedido explícito ("ao passar o
## mouse sobre qualquer ícone de item no craft"). É sempre `show_for_recipe`
## aqui (nunca `show_for_instance`): um card de receita ainda não foi
## fabricado, não tem raridade/Float/refino/durabilidade pra mostrar.
func _on_icon_hover(icon_frame: PanelContainer, item_id: String) -> void:
	# `icon_frame.position` é relativo ao pai IMEDIATO dele (um HBoxContainer
	# lá dentro da lista rolável), não ao `CraftingModal` -- converte por
	# posição global, já que `_tooltip_zoom` é filho direto daqui, no mesmo
	# espaço que `global_position - global_position` resolve certo.
	var local_pos: Vector2 = icon_frame.global_position - global_position + Vector2(icon_frame.size.x, 0)
	_tooltip_zoom.show_for_recipe(item_id, local_pos, size)


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
