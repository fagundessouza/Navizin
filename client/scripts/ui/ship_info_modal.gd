class_name ShipInfoModal
extends Control
## Overlay flutuante genérico pros 3 botões do rodapé do Galeão que ainda não
## tinham destino (Porão de Carga/Munição/Diário de Navegação) -- mesmo
## padrão do `CrewManagementSubmodal` (abre por cima do `ShipStatusModal`,
## não fecha ele). `info_mode` decide o conteúdo:
## - "cargo": barra de peso (mesmo dado de `ShipStatusModal._weight_bar`) +
##   lista de peças equipadas que dão `cargo_bonus`.
## - "ammo": lista de Munição/Arpão fabricados (ícone + nome colorido pela
##   raridade), igual à lista do Cofre/Refino.
## - "log": placeholder -- sem sistema de missões/combate registrado ainda
##   pra preencher um diário de verdade.

signal opened
signal closed

@export var info_mode: String = "cargo"

@onready var _title: Label = $Margin/VBox/Header/Title
@onready var _content: VBoxContainer = $Margin/VBox/Content
@onready var _weight_bar: ProgressBar = $Margin/VBox/WeightBar

const ICON_FRAME_SIZE: float = 28.0
const ICON_BORDER_COLOR: Color = Color(0.78, 0.65, 0.38, 0.9)

var _ship: Node2D = null


func _ready() -> void:
	visible = false
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	_weight_bar.visible = info_mode == "cargo"
	match info_mode:
		"cargo":
			_title.text = "Porão de Carga"
		"ammo":
			_title.text = "Munição e Arpões"
		"log":
			_title.text = "Diário de Navegação"
	PlayerInventory.changed.connect(_on_inventory_changed)


func _process(_delta: float) -> void:
	if not visible or info_mode != "cargo":
		return
	if _ship == null:
		_ship = get_tree().get_first_node_in_group("player_ship") as Node2D
		return
	if _ship.data != null:
		_weight_bar.max_value = _ship.data.max_cargo
		_weight_bar.value = _ship.data.cargo_weight


func open() -> void:
	visible = true
	_refresh()
	opened.emit()


func close() -> void:
	visible = false
	closed.emit()


func _on_inventory_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	for child in _content.get_children():
		child.queue_free()
	match info_mode:
		"cargo":
			_refresh_cargo()
		"ammo":
			_refresh_ammo()
		"log":
			_refresh_log()


## Lista os equipados (navio + capitão) que dão `cargo_bonus` -- não repete
## o cálculo, só lê o mesmo `get_total_bonuses()` que `ship_base.gd` já usa
## pra saber o total, e identifica as PEÇAS individuais aqui pra mostrar de
## onde vem o bônus.
func _refresh_cargo() -> void:
	var total_label := Label.new()
	var bonuses: Dictionary = PlayerInventory.get_total_bonuses()
	total_label.text = "Bônus de carga equipado: +%.0f" % bonuses["cargo_bonus"]
	total_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.76))
	_content.add_child(total_label)

	for slot in PlayerInventory.SHIP_SLOTS:
		var instance_id: String = PlayerInventory.equipped[slot]
		if instance_id == "":
			continue
		var entry: Dictionary = PlayerInventory.crafted_items.get(instance_id, {})
		if entry.get("stats", {}).has("cargo_bonus"):
			_content.add_child(_build_item_row(instance_id, slot.capitalize()))


func _refresh_ammo() -> void:
	var found: bool = false
	for instance_id in PlayerInventory.crafted_items:
		var item_id: String = PlayerInventory.crafted_items[instance_id]["item_id"]
		var category: String = ItemDatabase.get_item(item_id).get("category", "")
		if category == "municao" or category == "arpao":
			found = true
			_content.add_child(_build_item_row(instance_id, ""))
	if not found:
		var empty := Label.new()
		empty.text = "Nenhuma munição ou arpão fabricado ainda."
		empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
		_content.add_child(empty)


func _refresh_log() -> void:
	var label := Label.new()
	label.text = "Sem registros de combate ou missão ainda -- o Diário de Navegação preenche sozinho conforme o Sea Hunt e os contratos da Taverna forem jogados."
	label.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content.add_child(label)


func _build_item_row(instance_id: String, prefix: String) -> Control:
	var rarity: Dictionary = PlayerInventory.get_item_rarity(instance_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_make_icon_frame(PlayerInventory.get_item_icon(instance_id)))

	var label := Label.new()
	var name_text: String = PlayerInventory.get_item_name(instance_id)
	label.text = "%s: %s" % [prefix, name_text] if prefix != "" else name_text
	CraftingManager.style_item_label(label, rarity)
	row.add_child(label)
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
	frame.add_theme_stylebox_override("panel", style)

	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(icon_rect)
	return frame
