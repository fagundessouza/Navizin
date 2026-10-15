class_name RefinementModal
extends Control
## Painel de Refino da Forja Naval: lista os itens fabricados do jogador à
## esquerda (com miniatura + nome colorido pela raridade), detalhe de refino
## à direita -- nível atual, chance de sucesso pro próximo nível, barra de
## durabilidade (estilo BDO), custo em Pedra de Refino, opção de usar
## Pergaminho de Proteção (só relevante a partir de +8, onde existe risco de
## destruição) e o botão "Tentar Refino". `PlayerInventory.refine_instance()`
## faz o trabalho de verdade; este painel só monta a interface em cima do
## que ele já expõe (`can_refine()`, `get_refine_level()`, `get_durability()`,
## `get_item_rarity()`).
##
## Auto-seleciona o primeiro item fabricado ao abrir (se houver algum) --
## antes a tela de detalhe sempre nascia em branco ("Selecione um item à
## esquerda"), o que podia ler como "abriu vazio"/quebrado mesmo com itens
## na lista.

signal opened
signal closed

const OUTLINE_COLOR: Color = Color(0.03, 0.03, 0.04, 1.0)
const HOVER_COLOR: Color = Color(1.0, 0.92, 0.65, 1.0)
const NORMAL_FONT_COLOR: Color = Color(0.93, 0.9, 0.84, 1.0)
const OK_COLOR: Color = Color(0.6, 0.82, 0.5, 1.0)
const MISSING_COLOR: Color = Color(0.85, 0.4, 0.35, 1.0)
const ICON_FRAME_SIZE: float = 32.0
const ICON_BORDER_COLOR: Color = Color(0.78, 0.65, 0.38, 0.9)

@onready var _item_list: VBoxContainer = $Margin/VBox/HBox/Left/Scroll/List
@onready var _selected_name: Label = $Margin/VBox/HBox/Right/SelectedName
@onready var _durability_bar: ProgressBar = $Margin/VBox/HBox/Right/DurabilityBar
@onready var _durability_label: Label = $Margin/VBox/HBox/Right/DurabilityLabel
@onready var _chance_label: Label = $Margin/VBox/HBox/Right/ChanceLabel
@onready var _cost_label: Label = $Margin/VBox/HBox/Right/CostLabel
@onready var _protection_check: CheckBox = $Margin/VBox/HBox/Right/ProtectionCheck
@onready var _refine_button: Button = $Margin/VBox/HBox/Right/RefineButton
@onready var _result_label: Label = $Margin/VBox/HBox/Right/ResultLabel
@onready var _repair_label: Label = $Margin/VBox/HBox/Right/RepairLabel
@onready var _repair_button: Button = $Margin/VBox/HBox/Right/RepairButton

var _selected_instance_id: String = ""


func _ready() -> void:
	visible = false
	_style_button($Margin/VBox/Header/CloseButton)
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	_style_button(_refine_button)
	_refine_button.pressed.connect(_on_refine_pressed)
	_style_button(_repair_button)
	_repair_button.pressed.connect(_on_repair_pressed)
	_protection_check.toggled.connect(_on_protection_toggled)
	PlayerInventory.changed.connect(_on_inventory_changed)


func open() -> void:
	visible = true
	_result_label.text = ""
	_rebuild_item_list()
	opened.emit()


func close() -> void:
	visible = false
	closed.emit()


func _on_inventory_changed() -> void:
	if visible:
		_rebuild_item_list()
		_update_details()


func _rebuild_item_list() -> void:
	for child in _item_list.get_children():
		child.queue_free()
	if PlayerInventory.crafted_items.is_empty():
		var empty := Label.new()
		empty.text = "Nada fabricado ainda."
		empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
		_item_list.add_child(empty)
		if _selected_instance_id != "":
			_selected_instance_id = ""
			_update_details()
		return

	var still_exists: bool = false
	for instance_id in PlayerInventory.crafted_items:
		_item_list.add_child(_build_item_row(instance_id))
		if instance_id == _selected_instance_id:
			still_exists = true

	if not still_exists:
		# Auto-seleciona o primeiro da lista em vez de deixar o painel de
		# detalhe em branco -- primeira abertura, ou o item selecionado
		# sumiu (foi destruído, por exemplo).
		_selected_instance_id = PlayerInventory.crafted_items.keys()[0]
	_update_details()


func _build_item_row(instance_id: String) -> Control:
	var rarity: Dictionary = PlayerInventory.get_item_rarity(instance_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_make_icon_frame(PlayerInventory.get_item_icon(instance_id)))

	var button := Button.new()
	button.flat = true
	button.text = PlayerInventory.get_item_name(instance_id)
	CraftingManager.style_item_label(button, rarity)
	button.add_theme_color_override("font_hover_color", rarity["color"].lightened(0.3))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_item_row_pressed.bind(instance_id))
	row.add_child(button)
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


func _on_item_row_pressed(instance_id: String) -> void:
	_selected_instance_id = instance_id
	_result_label.text = ""
	_update_details()


## Ligado/desligado também muda a chance exibida? Não -- o pergaminho não
## altera a CHANCE de sucesso, só o que acontece se falhar (protege de
## regredir/destruir a partir de +8). Só precisa recalcular custo/estado do
## botão de novo.
func _on_protection_toggled(_pressed: bool) -> void:
	_update_details()


func _update_details() -> void:
	if _selected_instance_id == "" or not PlayerInventory.crafted_items.has(_selected_instance_id):
		_selected_name.text = "Selecione um item à esquerda."
		_selected_name.remove_theme_color_override("font_color")
		_durability_bar.value = 0.0
		_durability_label.text = ""
		_chance_label.text = ""
		_cost_label.text = ""
		_protection_check.disabled = true
		_protection_check.button_pressed = false
		_refine_button.disabled = true
		_repair_label.text = ""
		_repair_button.disabled = true
		return

	var instance_id: String = _selected_instance_id
	var level: int = PlayerInventory.get_refine_level(instance_id)
	var rarity: Dictionary = PlayerInventory.get_item_rarity(instance_id)
	_selected_name.text = PlayerInventory.get_item_name(instance_id)
	CraftingManager.style_item_label(_selected_name, rarity)

	var durability: float = PlayerInventory.get_durability(instance_id)
	var max_durability: float = PlayerInventory.get_max_durability(instance_id)
	_durability_bar.max_value = max_durability
	_durability_bar.value = durability
	_durability_label.text = "Durabilidade: %d/%d" % [int(durability), int(max_durability)]
	_update_repair_section(instance_id, max_durability)

	if level >= EnchantmentManager.MAX_LEVEL:
		_chance_label.text = "Nível máximo (+15) já alcançado."
		_cost_label.text = ""
		_protection_check.disabled = true
		_refine_button.disabled = true
		return

	var target_level: int = level + 1
	var rate: float = EnchantmentManager.success_rate_for(target_level)
	_chance_label.text = "Refinar pra +%d: %.0f%% de chance" % [target_level, rate]

	# Pergaminho só importa a partir de +8 (onde existe risco de destruição
	## de verdade) -- abaixo disso, falhar só regride 1 nível sem motivo pra
	# gastar pergaminho.
	var protection_matters: bool = target_level >= 8
	_protection_check.disabled = not protection_matters
	if not protection_matters:
		_protection_check.button_pressed = false
	var use_protection: bool = protection_matters and _protection_check.button_pressed

	var stone_cost: int = PlayerInventory.refine_stone_cost(target_level)
	var stone_have: int = PlayerInventory.materials.get(PlayerInventory.REFINE_STONE, 0)
	var scroll_have: int = PlayerInventory.materials.get(PlayerInventory.PROTECTION_SCROLL, 0)

	var cost_text: String = "Custo: %dx Pedra de Refino (tem %d)" % [stone_cost, stone_have]
	if protection_matters:
		cost_text += "\nPergaminho de Proteção: tem %d" % scroll_have
	_cost_label.text = cost_text

	_refine_button.disabled = not PlayerInventory.can_refine(instance_id, use_protection)


## Oficina de Manutenção: "recuperar a durabilidade máxima" pedido
## explícito -- repõe o TETO (não só a barra atual) de volta a 100, por um
## custo em Kit de Reparo. Fica aqui dentro do painel de Refino (mesma
## estação, "Forja Naval -- Refino") em vez de um 3º botão/distrito
## dedicado -- é a mesma bancada, só outro tipo de trabalho nela.
func _update_repair_section(instance_id: String, max_durability: float) -> void:
	if max_durability >= PlayerInventory.MAX_DURABILITY:
		_repair_label.text = "Durabilidade máxima intacta (100/100)."
		_repair_button.disabled = true
		return
	var kit_have: int = PlayerInventory.materials.get(PlayerInventory.REPAIR_KIT, 0)
	_repair_label.text = "Teto reduzido por falhas de refino. Reparar: %dx Kit de Reparo (tem %d)" % [PlayerInventory.REPAIR_KIT_COST, kit_have]
	_repair_button.disabled = not PlayerInventory.can_repair(instance_id)


func _on_repair_pressed() -> void:
	if _selected_instance_id == "":
		return
	if PlayerInventory.repair_max_durability(_selected_instance_id):
		_result_label.text = "Durabilidade máxima restaurada."
		_result_label.add_theme_color_override("font_color", OK_COLOR)


func _on_refine_pressed() -> void:
	if _selected_instance_id == "":
		return
	var level: int = PlayerInventory.get_refine_level(_selected_instance_id)
	var use_protection: bool = level + 1 >= 8 and _protection_check.button_pressed
	var result: Dictionary = PlayerInventory.refine_instance(_selected_instance_id, use_protection)
	_show_result(result)
	if result["destroyed"]:
		_selected_instance_id = ""
	_rebuild_item_list()


func _show_result(result: Dictionary) -> void:
	match result["outcome"]:
		"success":
			_result_label.text = "Sucesso! Agora está em +%d." % result["new_level"]
			_result_label.add_theme_color_override("font_color", OK_COLOR)
		"fail_regress":
			_result_label.text = "Falhou -- regrediu pra +%d." % result["new_level"]
			_result_label.add_theme_color_override("font_color", MISSING_COLOR)
		"fail_protected":
			_result_label.text = "Falhou, mas o pergaminho segurou -- continua em +%d." % result["new_level"]
			_result_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4, 1.0))
		"fail_reset":
			_result_label.text = "Falhou feio -- o item voltou pra +0."
			_result_label.add_theme_color_override("font_color", MISSING_COLOR)
		"fail_destroyed":
			_result_label.text = "O item foi DESTRUÍDO."
			_result_label.add_theme_color_override("font_color", MISSING_COLOR)
		"max_level":
			_result_label.text = "Já está no nível máximo."
		_:
			_result_label.text = "Não deu pra tentar (falta material)."
			_result_label.add_theme_color_override("font_color", MISSING_COLOR)


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
