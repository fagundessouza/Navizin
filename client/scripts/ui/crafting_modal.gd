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
## índice -- a mesma cena serve pra Forja/Estaleiro/Feira, só muda o que é
## passado na instância.
##
## JANELA ÚNICA POR ESTAÇÃO (pedido explícito -- "elimine os botões
## redundantes, uma única janela com abas"): cada entrada de `categories`
## pode juntar MAIS DE UMA categoria numa aba só, separadas por vírgula (ex:
## `"casco,proa"` vira a aba "Cascos e Proas" do Estaleiro) -- ver
## `_categories_for_tab()`. `category_stations` é opcional e paralela a
## `categories`: se uma entrada vier vazia, a aba usa `station` (o padrão de
## sempre); se vier preenchida, essa aba busca receita de OUTRA estação (ex:
## a aba "Suprimentos de Bordo" da Feira mostra Munição/Arpão, que são
## receitas de "forja", mesmo a Feira sendo `station = "feira"` pras outras
## abas) -- uma janela só pode juntar conteúdo que hoje vive em estações
## diferentes sem fingir que ele virou tudo uma coisa só.
##
## Botão "Refinar Equipamento" no cabeçalho (`$Margin/VBox/Header/RefineButton`)
## abre `$RefinementModal` (filho desta cena) -- refino deixou de ter botão
## próprio no distrito, mora dentro da mesma janela da estação agora.

signal opened
signal closed

@export var panel_title: String = "Fabricação"
@export var station: String = "forja"
@export var categories: PackedStringArray = []
@export var category_labels: PackedStringArray = []
@export var category_stations: PackedStringArray = []
## Esconde o botão "Refinar Equipamento" do cabeçalho pra estações que não
## fabricam nada refinável por enquanto (nenhuma até agora, mas a opção
## existe pra não forçar o botão em toda instância).
@export var show_refine_button: bool = true

@onready var _refinement_modal: RefinementModal = $RefinementModal

const OUTLINE_COLOR: Color = Color(0.03, 0.03, 0.04, 1.0)
const HOVER_COLOR: Color = Color(1.0, 0.92, 0.65, 1.0)
const NORMAL_FONT_COLOR: Color = Color(0.93, 0.9, 0.84, 1.0)
const OK_COLOR: Color = Color(0.6, 0.82, 0.5, 1.0)
const MISSING_COLOR: Color = Color(0.85, 0.4, 0.35, 1.0)
const ICON_FRAME_SIZE: float = 40.0
const ICON_BORDER_COLOR: Color = Color(0.78, 0.65, 0.38, 0.9)
const ITEM_SOFTENER_SHADER: Shader = preload("res://assets/shaders/ui_item_softener.gdshader")

## Itens por página -- "6 a 8 itens por página" pedido explicitamente; 6
## cobre a lista sem precisar de `ScrollContainer` pra nenhuma categoria
## atual.
const PAGE_SIZE: int = 6

@onready var _tabs_box: HBoxContainer = $Margin/VBox/Tabs
@onready var _pages_root: Control = $Margin/VBox/Pages
@onready var _tooltip_zoom: ItemTooltipZoom = $ItemTooltipZoom

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
## Página atual por aba (índice paralelo a `categories`) -- cada aba lembra
## sua própria página ao trocar de aba e voltar, em vez de sempre reiniciar
## na primeira.
var _page_index: Array[int] = []


func _ready() -> void:
	visible = false
	$Margin/VBox/Header/Title.text = panel_title
	_style_button($Margin/VBox/Header/CloseButton)
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	var refine_button: Button = $Margin/VBox/Header/RefineButton
	refine_button.visible = show_refine_button
	if show_refine_button:
		_style_button(refine_button)
		refine_button.pressed.connect(_refinement_modal.open)
	_build_tabs()
	if categories.size() > 0:
		_select_tab(0)
	# Escuta os dois -- uma instância de CraftingModal só mostra categorias de
	# UM lado (Forja/Estaleiro = navio, Feira = capitão), mas ouvir os dois é
	# barato e evita ter que decidir qual delas importa aqui.
	ShipInventory.changed.connect(_on_inventory_changed)
	CaptainInventory.changed.connect(_on_inventory_changed)


func open() -> void:
	visible = true
	UIManager.animate_modal_open(self)
	_rebuild_pages()
	opened.emit()


func close() -> void:
	_refinement_modal.close()
	visible = false
	closed.emit()


## "casco,proa" -> ["casco", "proa"] -- junta MAIS DE UMA categoria numa
## aba só (ver nota de classe).
func _categories_for_tab(index: int) -> Array[String]:
	var raw: String = categories[index]
	var result: Array[String] = []
	for part in raw.split(","):
		result.append(part.strip_edges())
	return result


func _station_for_tab(index: int) -> String:
	if index < category_stations.size() and category_stations[index] != "":
		return category_stations[index]
	return station


## Recipe ids de TODAS as categorias daquela aba, de TODAS as estações
## envolvidas, ordenados -- uma aba pode juntar categorias que vêm de
## estações diferentes (`_station_for_tab()`), mas aqui dentro quem chama só
## vê uma lista única.
func _recipe_ids_for_tab(index: int) -> Array[String]:
	var result: Array[String] = []
	for category in _categories_for_tab(index):
		result.append_array(ItemDatabase.get_recipes_for(_station_for_tab(index), category))
	result.sort()
	return result


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

		var page := VBoxContainer.new()
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		page.visible = false
		page.add_theme_constant_override("separation", 8)
		var list := VBoxContainer.new()
		list.name = "List"
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 8)
		page.add_child(list)

		page.add_child(_build_pager(i))

		_pages_root.add_child(page)
		_pages.append(page)
		_page_index.append(0)


## Barra "< Anterior | página X de Y | Próxima >" no rodapé de cada aba --
## pedido explícito, no lugar de listas compridas rolando pra sempre.
func _build_pager(category_index: int) -> HBoxContainer:
	var pager := HBoxContainer.new()
	pager.name = "Pager"
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 16)

	var prev_button := Button.new()
	prev_button.name = "Prev"
	prev_button.text = "< Anterior"
	prev_button.pressed.connect(_on_page_nav.bind(category_index, -1))
	_style_button(prev_button)
	pager.add_child(prev_button)

	var page_label := Label.new()
	page_label.name = "PageLabel"
	page_label.add_theme_color_override("font_color", NORMAL_FONT_COLOR)
	pager.add_child(page_label)

	var next_button := Button.new()
	next_button.name = "Next"
	next_button.text = "Próxima >"
	next_button.pressed.connect(_on_page_nav.bind(category_index, 1))
	_style_button(next_button)
	pager.add_child(next_button)

	return pager


func _on_page_nav(category_index: int, delta: int) -> void:
	var recipe_ids: Array[String] = _recipe_ids_for_tab(category_index)
	var page_count: int = _page_count(recipe_ids.size())
	_page_index[category_index] = clampi(_page_index[category_index] + delta, 0, page_count - 1)
	_rebuild_pages()


func _page_count(total_items: int) -> int:
	return maxi(1, ceili(float(total_items) / float(PAGE_SIZE)))


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
		var recipe_ids: Array[String] = _recipe_ids_for_tab(i)
		var pager: HBoxContainer = _pages[i].get_node("Pager")
		if recipe_ids.is_empty():
			var empty := Label.new()
			empty.text = "Nenhuma receita aqui ainda."
			empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
			list.add_child(empty)
			pager.visible = false
			continue

		var page_count: int = _page_count(recipe_ids.size())
		_page_index[i] = clampi(_page_index[i], 0, page_count - 1)
		var start: int = _page_index[i] * PAGE_SIZE
		var end: int = mini(start + PAGE_SIZE, recipe_ids.size())
		for item_id in recipe_ids.slice(start, end):
			list.add_child(_build_recipe_row(item_id))

		pager.visible = page_count > 1
		if pager.visible:
			pager.get_node("PageLabel").text = "Página %d de %d" % [_page_index[i] + 1, page_count]
			pager.get_node("Prev").disabled = _page_index[i] == 0
			pager.get_node("Next").disabled = _page_index[i] >= page_count - 1


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
	var icon_frame := _make_icon_frame(item.get("icon"))
	icon_frame.mouse_entered.connect(_on_icon_hover.bind(icon_frame, item_id))
	icon_frame.mouse_exited.connect(_tooltip_zoom.hide_tooltip)
	UIManager.add_hover_pop(icon_frame)
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
	CraftingManager.style_item_label(name_label, {"color": Color(0.95, 0.85, 0.55)})
	name_label.add_theme_font_size_override("font_size", 15)
	header.add_child(name_label)

	# Materiais brutos vivem só em `ShipInventory` mesmo pra receita do
	# Capitão (ver nota em `captain_inventory.gd` -- o porão é físico, é um
	# só, não tem um estoque separado "do Capitão").
	var can_craft: bool = ShipInventory.has_materials_for(item_id)

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
		var have: int = ShipInventory.materials.get(material_name, 0)
		var mat_label := Label.new()
		mat_label.text = "%s %d/%d" % [material_name, have, needed]
		mat_label.add_theme_font_size_override("font_size", 12)
		mat_label.add_theme_color_override("font_color", OK_COLOR if have >= needed else MISSING_COLOR)
		materials_box.add_child(mat_label)

	return row


## Miniatura com borda gótica ao lado do nome da receita -- "exibir a
## miniatura da arte do item" pedido explicitamente. `icon` vem nulo pros
## poucos itens sem arte dedicada ainda; `TextureRect` com textura nula só
## fica em branco dentro da moldura, sem quebrar nada.
##
## SEM BRILHO AQUI (removido nesta rodada): isto é uma RECEITA, não um item
## fabricado -- não existe Qualidade de Craft nenhuma rolada ainda pra
## justificar um brilho de raridade. O pulso âmbar que ficava ligado em todo
## card de Tier IV, raridade nenhuma por trás, era exatamente a "luz/spray
## amarelo desposicionado poluindo a modal" pedida pra remover -- borda
## estática simples até o jogador realmente fabricar o item.
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


func _on_craft_pressed(item_id: String) -> void:
	var category: String = ItemDatabase.get_item(item_id).get("category", "")
	if ItemDatabase.is_captain_category(category):
		CaptainInventory.craft(item_id)
	else:
		ShipInventory.craft(item_id)


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
