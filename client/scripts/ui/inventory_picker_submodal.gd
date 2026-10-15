class_name InventoryPickerSubmodal
extends Control
## Submodal suspenso que abre do lado de um slot '+' (equipamento do capitão
## ou do navio) listando os itens de verdade, fabricados e ainda não
## equipados em lugar nenhum (`get_unequipped_for_category()`), compatíveis
## com aquela categoria. Selecionar emite `instance_selected` e EQUIPA de
## fato.
##
## Cobre tanto os slots do Galeão (vela/casco/leme/proa/relíquia_ebenruth/
## armamento) quanto os do Capitão (brincos/colar/anel/cinto/trajes/
## secundaria) -- roteado pra `ShipInventory`/`CaptainInventory` conforme a
## categoria (`_inventory_for()`), já que os dois inventários foram
## separados em autoloads distintos nesta rodada (antes eram um só,
## `player_inventory.gd`).
##
## Cada linha mostra o ícone do item (`PanelContainer` com borda gótica +
## `TextureRect`) ao lado do nome colorido pela raridade -- "exibir a
## miniatura da arte do item" pedido explicitamente.
##
## Um `Backdrop` cobrindo a tela inteira fecha o submodal ao clicar fora,
## atrás da caixa -- padrão comum de popup/context-menu.

signal instance_selected(category: String, instance_id: String)

const ICON_FRAME_SIZE: float = 32.0
const ICON_BORDER_COLOR: Color = Color(0.78, 0.65, 0.38, 0.9)
const ITEM_SOFTENER_SHADER: Shader = preload("res://assets/shaders/ui_item_softener.gdshader")

@onready var _backdrop: Control = $Backdrop
@onready var _box: PanelContainer = $Box
@onready var _title: Label = $Box/Margin/VBox/Title
@onready var _list: VBoxContainer = $Box/Margin/VBox/List

var _category: String = ""


## `local_pos` já é no espaço do painel-pai (o slot resolve isso antes de
## chamar). A caixa nasce ali e cresce pra baixo/direita; quem usa isso em
## painéis estreitos pode querer checar se não estoura a borda -- não é um
## problema aqui porque todos os slots ficam numa faixa central confortável.
func _ready() -> void:
	visible = false
	_backdrop.gui_input.connect(_on_backdrop_input)


## Roteia pra `ShipInventory` ou `CaptainInventory` conforme a categoria do
## slot -- os dois têm a mesma API pública (`get_unequipped_for_category`/
## `get_item_rarity`/etc.), então um picker genérico só precisa saber qual
## dono perguntar, não reimplementar nada diferente pra cada um.
func _inventory_for(category: String) -> Node:
	return CaptainInventory if ItemDatabase.is_captain_category(category) else ShipInventory


func open_at(local_pos: Vector2, category: String, label: String) -> void:
	_category = category
	_title.text = label
	for child in _list.get_children():
		child.queue_free()

	var entries: Array[Dictionary] = _inventory_for(category).get_unequipped_for_category(category)
	for entry in entries:
		_list.add_child(_build_row(entry["instance_id"]))

	if entries.is_empty():
		var empty := Label.new()
		empty.text = "Nada fabricado ainda."
		empty.add_theme_color_override("font_color", Color(0.65, 0.6, 0.55))
		empty.add_theme_font_size_override("font_size", 13)
		_list.add_child(empty)

	_box.position = local_pos
	visible = true


func _build_row(instance_id: String) -> Control:
	var inv: Node = _inventory_for(_category)
	var rarity: Dictionary = inv.get_item_rarity(instance_id)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_make_icon_frame(inv.get_item_icon(instance_id)))

	var button := Button.new()
	button.text = "[%s] %s" % [rarity["name"], inv.get_item_name(instance_id)]
	button.tooltip_text = inv.get_float_tooltip_line(instance_id)
	CraftingManager.style_item_label(button, rarity)
	button.add_theme_color_override("font_hover_color", rarity["color"].lightened(0.3))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_instance_pressed.bind(instance_id))
	row.add_child(button)

	return row


## Miniatura com borda gótica: um quadrado escuro com contorno dourado ao
## redor do ícone do item -- mesma paleta usada em outros frames pequenos do
## projeto (barra de menu do HUD, submodal em si).
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


func close() -> void:
	visible = false


func _on_instance_pressed(instance_id: String) -> void:
	instance_selected.emit(_category, instance_id)
	close()


func _on_backdrop_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		close()
