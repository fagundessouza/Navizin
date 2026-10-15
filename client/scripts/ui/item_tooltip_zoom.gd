class_name ItemTooltipZoom
extends Control
## Tooltip flutuante com zoom de alta resolução, estilo Diablo IV/Albion:
## ícone ampliado, nome colorido pela raridade, Float, prefixo de refino
## "[+N]", durabilidade e a lista de atributos do item. Instanciado como
## FILHO de cada modal que precisa dele (CraftingModal, InventoryPickerSubmodal,
## ShipStatusModal, CaptainProfileModal) -- não é autoload/overlay global,
## porque cada um desses já é sua própria árvore de cena; um filho por modal
## é mais simples que um singleton cross-scene pra um tooltip que só aparece
## enquanto aquele modal já está aberto.
##
## Dois modos:
## - `show_for_instance(instance_id, anchor_pos)`: item de verdade já
##   fabricado -- raridade, Float, refino e durabilidade vêm de
##   `PlayerInventory`.
## - `show_for_recipe(item_id, anchor_pos)`: receita ainda não fabricada (um
##   card do `CraftingModal`) -- sem raridade/Float/refino/durabilidade pra
##   mostrar ainda, só nome-base, ícone e os atributos-base do tier.

const STAT_LABELS: Dictionary = {
	"hull_bonus": "Casco", "cargo_bonus": "Carga", "speed_bonus": "Velocidade",
	"damage_mult_bonus": "Dano", "leadership_bonus": "Liderança",
	"boarding_crit_bonus": "Crítico de Abordagem", "node_speed_bonus": "Velocidade Nodal",
	"armor_pen_bonus": "Penetração de Blindagem", "elemental_damage_bonus": "Dano Elemental",
}
## Esses 4 são fração (0.15 = +15%); o resto é número cru (+200, +0.3x...).
const PERCENT_STATS: Array[String] = ["damage_mult_bonus", "boarding_crit_bonus", "armor_pen_bonus", "elemental_damage_bonus"]

const BOX_SIZE: Vector2 = Vector2(210, 260)
const ICON_ZOOM_SIZE: float = 96.0

@onready var _box: PanelContainer = $Box
@onready var _icon_rect: TextureRect = $Box/Margin/VBox/IconFrame/Icon
@onready var _name_label: Label = $Box/Margin/VBox/NameLabel
@onready var _float_label: Label = $Box/Margin/VBox/FloatLabel
@onready var _durability_bar: ProgressBar = $Box/Margin/VBox/DurabilityBar
@onready var _durability_label: Label = $Box/Margin/VBox/DurabilityLabel
@onready var _stats_list: VBoxContainer = $Box/Margin/VBox/StatsList


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `anchor_pos` e `parent_size` são no espaço LOCAL de quem chama (o mesmo
## espaço que `InventoryPickerSubmodal.open_at()` já usa) -- abre pro lado
## com mais espaço, igual ao submodal de inventário, pra nunca estourar a
## borda do painel-pai.
func show_for_instance(instance_id: String, anchor_pos: Vector2, parent_size: Vector2) -> void:
	if instance_id == "" or not PlayerInventory.crafted_items.has(instance_id):
		return
	var rarity: Dictionary = PlayerInventory.get_item_rarity(instance_id)
	_icon_rect.texture = PlayerInventory.get_item_icon(instance_id)
	_name_label.text = PlayerInventory.get_item_name(instance_id)
	CraftingManager.style_item_label(_name_label, rarity)

	var float_value: float = PlayerInventory.get_float_value(instance_id)
	_float_label.visible = true
	_float_label.text = "Float: %.3f (%s)" % [float_value, CraftingManager.float_label(float_value)]

	_durability_bar.visible = true
	_durability_label.visible = true
	var durability: float = PlayerInventory.get_durability(instance_id)
	var max_durability: float = PlayerInventory.get_max_durability(instance_id)
	_durability_bar.max_value = max_durability
	_durability_bar.value = durability
	_style_durability_bar(durability / max_durability)
	_durability_label.text = "Durabilidade: %d/%d" % [int(durability), int(max_durability)]
	if max_durability < PlayerInventory.MAX_DURABILITY:
		_durability_label.text += " (teto reduzido)"

	var entry: Dictionary = PlayerInventory.crafted_items[instance_id]
	_build_stats(entry.get("stats", {}), EnchantmentManager.stat_multiplier_for(entry.get("refine_level", 0)))
	_position_near(anchor_pos, parent_size)
	visible = true


func show_for_recipe(item_id: String, anchor_pos: Vector2, parent_size: Vector2) -> void:
	var item: Dictionary = ItemDatabase.get_item(item_id)
	if item.is_empty():
		return
	_icon_rect.texture = item.get("icon")
	_name_label.text = item.get("name", item_id)
	CraftingManager.style_item_label(_name_label, {"color": Color(0.93, 0.9, 0.84)})

	_float_label.visible = false
	_durability_bar.visible = false
	_durability_label.visible = false

	_build_stats(item.get("stats", {}), 1.0)
	_position_near(anchor_pos, parent_size)
	visible = true


## Material bruto (Caverna do Tesouro): não existe no catálogo de
## `ItemDatabase.ITEMS` (materiais não são "itens", só entradas em
## `PlayerInventory.materials`), então não tem raridade/stats pra mostrar --
## só o ícone, nome e quanto tem guardado.
func show_for_material(material_name: String, quantity: int, anchor_pos: Vector2, parent_size: Vector2) -> void:
	_icon_rect.texture = ItemDatabase.get_material_icon(material_name)
	_name_label.text = material_name
	CraftingManager.style_item_label(_name_label, {"color": Color(0.85, 0.8, 0.72)})

	_float_label.visible = false
	_durability_bar.visible = false
	_durability_label.visible = false

	_build_stats({}, 1.0)
	for child in _stats_list.get_children():
		child.queue_free()
	var qty_label := Label.new()
	qty_label.text = "Quantidade: %d" % quantity
	qty_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4))
	qty_label.add_theme_font_size_override("font_size", 13)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_list.add_child(qty_label)

	_position_near(anchor_pos, parent_size)
	visible = true


func hide_tooltip() -> void:
	visible = false


## Verde cheia -> amarelo pela metade -> vermelho crítica, mesmo padrão
## "BDO-style" que o resto do projeto já usa pra durabilidade -- um
## `ProgressBar` sem estilo próprio usa o cinza padrão do tema do Godot, que
## não comunica "está quebrando" igual uma cor que muda com o desgaste.
func _style_durability_bar(ratio: float) -> void:
	var color: Color
	if ratio > 0.5:
		color = Color(0.55, 0.78, 0.35).lerp(Color(0.85, 0.75, 0.25), 1.0 - (ratio - 0.5) * 2.0)
	else:
		color = Color(0.85, 0.75, 0.25).lerp(Color(0.82, 0.25, 0.2), 1.0 - ratio * 2.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	_durability_bar.add_theme_stylebox_override("fill", fill)


func _build_stats(stats: Dictionary, mult: float) -> void:
	for child in _stats_list.get_children():
		child.queue_free()
	if stats.is_empty():
		var none_label := Label.new()
		none_label.text = "Sem atributos."
		none_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
		none_label.add_theme_font_size_override("font_size", 12)
		_stats_list.add_child(none_label)
		return
	for key in stats:
		var label := Label.new()
		var value: float = stats[key] * mult
		var stat_name: String = STAT_LABELS.get(key, key)
		if PERCENT_STATS.has(key):
			label.text = "%s: +%.0f%%" % [stat_name, value * 100.0]
		else:
			label.text = "%s: +%.0f" % [stat_name, value]
		label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.7))
		label.add_theme_font_size_override("font_size", 13)
		_stats_list.add_child(label)


## Mesma lógica de "abre pro lado com mais espaço" de
## `InventoryPickerSubmodal`/`ship_status_modal.gd` -- só que aqui também
## considera a altura, já que esse tooltip é mais alto que largo.
func _position_near(anchor_pos: Vector2, parent_size: Vector2) -> void:
	var pos: Vector2 = anchor_pos
	if pos.x + BOX_SIZE.x > parent_size.x:
		pos.x = anchor_pos.x - BOX_SIZE.x - 12.0
	else:
		pos.x += 12.0
	if pos.y + BOX_SIZE.y > parent_size.y:
		pos.y = parent_size.y - BOX_SIZE.y - 8.0
	pos.y = maxf(pos.y, 4.0)
	_box.position = pos
