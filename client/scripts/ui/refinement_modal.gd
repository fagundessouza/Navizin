class_name RefinementModal
extends Control
## Painel de Refino da Forja Naval: lista os itens fabricados do jogador à
## esquerda, detalhe de refino à direita -- nível atual, chance de sucesso
## pro próximo nível, custo em Pedra de Refino, opção de usar Pergaminho de
## Proteção (só relevante a partir de +8, onde existe risco de destruição) e
## o botão "Tentar Refino". `PlayerInventory.refine_instance()` faz o
## trabalho de verdade; este painel só monta a interface em cima do que ele
## já expõe (`can_refine()`, `get_refine_level()`, `get_item_rarity()`).

signal opened
signal closed

const OUTLINE_COLOR: Color = Color(0.03, 0.03, 0.04, 1.0)
const HOVER_COLOR: Color = Color(1.0, 0.92, 0.65, 1.0)
const NORMAL_FONT_COLOR: Color = Color(0.93, 0.9, 0.84, 1.0)
const OK_COLOR: Color = Color(0.6, 0.82, 0.5, 1.0)
const MISSING_COLOR: Color = Color(0.85, 0.4, 0.35, 1.0)

@onready var _item_list: VBoxContainer = $Margin/VBox/HBox/Left/Scroll/List
@onready var _selected_name: Label = $Margin/VBox/HBox/Right/SelectedName
@onready var _chance_label: Label = $Margin/VBox/HBox/Right/ChanceLabel
@onready var _cost_label: Label = $Margin/VBox/HBox/Right/CostLabel
@onready var _protection_check: CheckBox = $Margin/VBox/HBox/Right/ProtectionCheck
@onready var _refine_button: Button = $Margin/VBox/HBox/Right/RefineButton
@onready var _result_label: Label = $Margin/VBox/HBox/Right/ResultLabel

var _selected_instance_id: String = ""


func _ready() -> void:
	visible = false
	_style_button($Margin/VBox/Header/CloseButton)
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	_style_button(_refine_button)
	_refine_button.pressed.connect(_on_refine_pressed)
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
		var rarity: Dictionary = PlayerInventory.get_item_rarity(instance_id)
		var row := Button.new()
		row.flat = true
		row.text = PlayerInventory.get_item_name(instance_id)
		row.add_theme_color_override("font_color", rarity["color"])
		row.add_theme_color_override("font_hover_color", rarity["color"].lightened(0.3))
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(_on_item_row_pressed.bind(instance_id))
		_item_list.add_child(row)
		if instance_id == _selected_instance_id:
			still_exists = true

	if not still_exists:
		_selected_instance_id = ""
	_update_details()


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
		_chance_label.text = ""
		_cost_label.text = ""
		_protection_check.disabled = true
		_protection_check.button_pressed = false
		_refine_button.disabled = true
		return

	var instance_id: String = _selected_instance_id
	var level: int = PlayerInventory.get_refine_level(instance_id)
	var rarity: Dictionary = PlayerInventory.get_item_rarity(instance_id)
	_selected_name.text = PlayerInventory.get_item_name(instance_id)
	_selected_name.add_theme_color_override("font_color", rarity["color"])

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
