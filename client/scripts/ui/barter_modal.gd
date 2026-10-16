class_name BarterModal
extends Control
## Comércio e Escambo (ver `BarterSystem`, autoload com todo o dado/regra
## real). Esta cena só CONSTRÓI a UI em cima do que o autoload já calcula --
## 3 abas:
## - "Processar": matéria-prima -> bem processado (`PROCESSING_RECIPES`).
## - "Permuta": cadeia de 5 níveis (`EXCHANGE_RECIPES`), agrupada por nível.
## - "Negociar": puzzle de barganha pros itens Nível 5
##   (`BarterSystem.start_negotiation()`/`propose_price()`).
##
## Mesmo padrão gótico de todo outro modal (`modal_frame_iron.png` +
## `gothic_panel.gdshader`, já com `axis_stretch_*` corrigido).

signal opened
signal closed

const TAB_NAMES: Array[String] = ["Processar", "Permuta", "Negociar"]
const TIER_NAMES: Dictionary = {1: "Nível 1", 2: "Nível 2", 3: "Nível 3", 4: "Nível 4", 5: "Nível 5"}

const OK_COLOR: Color = Color(0.6, 0.82, 0.5, 1.0)
const MISSING_COLOR: Color = Color(0.85, 0.4, 0.35, 1.0)
const NORMAL_COLOR: Color = Color(0.93, 0.9, 0.84, 1.0)
const DIM_COLOR: Color = Color(0.6, 0.58, 0.54, 1.0)

## Dicas de `BarterSystem.propose_price()` -> texto exibido (pedido
## explícito: NPC não revela o preço-alvo, só a direção/proximidade).
const HINT_TEXT: Dictionary = {
	"longe_abaixo": "O comerciante balança a cabeça: \"Muito baixo, nem perto.\"",
	"longe_acima": "O comerciante ri: \"Tá de brincadeira? Isso é caro demais.\"",
	"perto_abaixo": "O comerciante hesita: \"Quase lá... pode subir um pouco mais.\"",
	"perto_acima": "O comerciante hesita: \"Tá perto, mas ainda um pouco salgado.\"",
}

@onready var _tab_buttons: Array[Button] = [$Margin/VBox/Tabs/ProcessTab, $Margin/VBox/Tabs/ExchangeTab, $Margin/VBox/Tabs/NegotiateTab]
@onready var _pages: Array[Control] = [$Margin/VBox/Pages/ProcessScroll, $Margin/VBox/Pages/ExchangeScroll, $Margin/VBox/Pages/NegotiateScroll]
@onready var _process_list: VBoxContainer = $Margin/VBox/Pages/ProcessScroll/ProcessList
@onready var _exchange_list: VBoxContainer = $Margin/VBox/Pages/ExchangeScroll/ExchangeList
@onready var _negotiate_list: VBoxContainer = $Margin/VBox/Pages/NegotiateScroll/NegotiateList

var _current_tab: int = 0
## Última dica/resultado mostrado na aba Negociar -- só texto, não estado
## de jogo (`BarterSystem` é a única fonte de verdade pra isso).
var _last_negotiation_message: String = ""
## `BarterSystem` guarda a negociação como `Dictionary` interno, sem getter
## público pro item em si (só pelo retorno de `start_negotiation()`) --
## como a UI precisa mostrar "Negociando: X" mesmo depois de um refresh no
## meio da negociação (ex. `ShipInventory.changed` disparando), guarda o
## item da última chamada de `start_negotiation()` aqui.
var _negotiating_item: String = ""


func _ready() -> void:
	visible = false
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	for i in _tab_buttons.size():
		_tab_buttons[i].pressed.connect(_select_tab.bind(i))
	BarterSystem.changed.connect(_on_changed)
	ShipInventory.changed.connect(_on_changed)
	_select_tab(0)


func open() -> void:
	visible = true
	UIManager.animate_modal_open(self)
	_refresh()
	opened.emit()


func close() -> void:
	visible = false
	closed.emit()


func _on_changed() -> void:
	if visible:
		_refresh()


func _select_tab(index: int) -> void:
	_current_tab = index
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].disabled = i == index
	_refresh()


func _refresh() -> void:
	match _current_tab:
		0:
			_refresh_process()
		1:
			_refresh_exchange()
		2:
			_refresh_negotiate()


## "Processar": matéria-prima -> bem processado, 1 linha por receita.
func _refresh_process() -> void:
	for child in _process_list.get_children():
		child.queue_free()
	for recipe in BarterSystem.PROCESSING_RECIPES:
		_process_list.add_child(_build_recipe_row(
			"%s x%d" % [BarterSystem.RAW_MATERIALS[recipe["input"]]["name"], recipe["ratio_in"]],
			BarterSystem.quantity_of(BarterSystem.RAW_MATERIALS[recipe["input"]]["name"]),
			recipe["ratio_in"],
			"%s x%d" % [recipe["output"], recipe["qty_out"]],
			"Processar",
			BarterSystem.can_process_recipe(recipe),
			func(): BarterSystem.process(recipe)
		))


## "Permuta": cadeia de 5 níveis, um cabeçalho por nível + uma linha por
## receita daquele nível (`BarterSystem.exchange_recipes_for_tier()`).
func _refresh_exchange() -> void:
	for child in _exchange_list.get_children():
		child.queue_free()
	for tier in range(1, BarterSystem.MAX_TIER + 1):
		var header := Label.new()
		header.text = TIER_NAMES[tier]
		header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
		header.add_theme_font_size_override("font_size", 16)
		_exchange_list.add_child(header)
		for recipe in BarterSystem.exchange_recipes_for_tier(tier):
			_exchange_list.add_child(_build_recipe_row(
				"%s x%d" % [recipe["input"], recipe["ratio_in"]],
				BarterSystem.quantity_of(recipe["input"]),
				recipe["ratio_in"],
				"%s x%d" % [recipe["output"], recipe["qty_out"]],
				"Trocar",
				BarterSystem.can_exchange(recipe),
				func(): BarterSystem.exchange(recipe)
			))
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		_exchange_list.add_child(spacer)


## Uma linha genérica "tenho X/preciso de Y -> produz Z" + botão de ação --
## reaproveitada por Processar e Permuta (mesmo formato, fonte de dado
## diferente).
func _build_recipe_row(input_text: String, have: int, need: int, output_text: String, action_label: String, can_act: bool, action: Callable) -> Control:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.55)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var input_label := Label.new()
	input_label.text = "%s (tenho %d)" % [input_text, have]
	input_label.add_theme_color_override("font_color", OK_COLOR if have >= need else MISSING_COLOR)
	input_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(input_label)

	var arrow := Label.new()
	arrow.text = "->"
	arrow.add_theme_color_override("font_color", DIM_COLOR)
	hbox.add_child(arrow)

	var output_label := Label.new()
	output_label.text = output_text
	output_label.add_theme_color_override("font_color", NORMAL_COLOR)
	output_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(output_label)

	var action_button := Button.new()
	action_button.text = action_label
	action_button.disabled = not can_act
	action_button.custom_minimum_size = Vector2(100, 0)
	action_button.pressed.connect(action)
	hbox.add_child(action_button)

	return row


## "Negociar": sem negociação ativa, lista os itens Nível 5 em estoque pra
## escolher qual levar à mesa; com uma ativa, mostra o puzzle (paciência/
## tentativas restantes, campo de preço, dica do último lance).
func _refresh_negotiate() -> void:
	for child in _negotiate_list.get_children():
		child.queue_free()

	if not BarterSystem.negotiation_active():
		_last_negotiation_message = ""
		var intro := Label.new()
		intro.text = "Escolha um item Nível 5 pra levar à mesa de negociação com o comércio da cidade."
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD
		intro.add_theme_color_override("font_color", DIM_COLOR)
		_negotiate_list.add_child(intro)

		var any_item := false
		for item_name in BarterSystem.tier5_items():
			var qty: int = BarterSystem.quantity_of(item_name)
			if qty <= 0:
				continue
			any_item = true
			var row := PanelContainer.new()
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.08, 0.07, 0.06, 0.55)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			style.content_margin_left = 8
			style.content_margin_right = 8
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			row.add_theme_stylebox_override("panel", style)
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 10)
			row.add_child(hbox)
			var label := Label.new()
			label.text = "%s (tenho %d)" % [item_name, qty]
			label.add_theme_color_override("font_color", NORMAL_COLOR)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(label)
			var start_button := Button.new()
			start_button.text = "Negociar"
			start_button.pressed.connect(_on_start_negotiation.bind(item_name))
			hbox.add_child(start_button)
			_negotiate_list.add_child(row)
		if not any_item:
			var empty := Label.new()
			empty.text = "Nenhum item Nível 5 em estoque ainda -- troque a cadeia de Permuta até chegar lá."
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD
			empty.add_theme_color_override("font_color", DIM_COLOR)
			_negotiate_list.add_child(empty)
		return

	_build_active_negotiation_ui()


func _on_start_negotiation(item_name: String) -> void:
	var result: Dictionary = BarterSystem.start_negotiation(item_name)
	if not result.is_empty():
		_negotiating_item = item_name
	_last_negotiation_message = ""


func _build_active_negotiation_ui() -> void:
	var status := Label.new()
	status.text = "Negociando: %s" % _negotiation_item_name()
	status.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	status.add_theme_font_size_override("font_size", 16)
	_negotiate_list.add_child(status)

	if _last_negotiation_message != "":
		var msg := Label.new()
		msg.text = _last_negotiation_message
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD
		msg.add_theme_color_override("font_color", NORMAL_COLOR)
		_negotiate_list.add_child(msg)

	var spin := SpinBox.new()
	spin.name = "PriceSpin"
	spin.min_value = 1
	spin.max_value = 500
	spin.step = 1
	spin.value = 100
	_negotiate_list.add_child(spin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	_negotiate_list.add_child(hbox)

	var propose_button := Button.new()
	propose_button.text = "Propor Preço"
	propose_button.pressed.connect(_on_propose_price.bind(spin))
	hbox.add_child(propose_button)

	var cancel_button := Button.new()
	cancel_button.text = "Desistir (mantém o item)"
	cancel_button.pressed.connect(_on_cancel_negotiation)
	hbox.add_child(cancel_button)


func _negotiation_item_name() -> String:
	return _negotiating_item


func _on_propose_price(spin: SpinBox) -> void:
	var result: Dictionary = BarterSystem.propose_price(int(spin.value))
	match result.get("outcome", ""):
		"deal":
			_last_negotiation_message = "Negócio fechado! +%d Ouro." % result["gold_gained"]
			_negotiating_item = ""
		"walked_away":
			_last_negotiation_message = "O comerciante perdeu a paciência e saiu da mesa."
			_negotiating_item = ""
		"hint":
			_last_negotiation_message = HINT_TEXT.get(result["hint"], "")
	_refresh()


func _on_cancel_negotiation() -> void:
	BarterSystem.cancel_negotiation()
	_negotiating_item = ""
	_last_negotiation_message = ""
	_refresh()
