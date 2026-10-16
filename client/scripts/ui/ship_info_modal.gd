class_name ShipInfoModal
extends Control
## Overlay flutuante genérico reaproveitado pelos slots de Suprimentos da
## Ficha do Navio (Escambo -> "cargo", Bolas -> "ammo", Pólvora -> "supplies")
## -- mesmo padrão do `CrewManagementSubmodal` (abre por cima do
## `ShipStatusModal`, não fecha ele). `info_mode` decide o conteúdo:
## - "cargo": barra de peso (mesmo dado de `ShipStatusModal._weight_bar`) +
##   lista de peças equipadas que dão `cargo_bonus`.
## - "ammo": lista de Munição/Arpão fabricados (ícone + nome colorido pela
##   raridade), igual à lista do Cofre/Refino.
## - "supplies": Ração de Bordo -- NÃO é um sistema novo inventado pra essa
##   tela (pedido explícito, rodada "Suprimentos da Tripulação"); expõe dado
##   que `TavernHireSystem` já consome de verdade a cada
##   `FOOD_TICK_INTERVAL` (`_consume_food_tick()`), só que até agora sem
##   nenhuma UI pra ver o estoque/consumo. Mostra o estoque real, o consumo
##   por ciclo (soma do upkeep por Raça de cada Marinheiro contratado) e
##   quem está INATIVO agora por falta de ração -- mesmo `entry["active"]`
##   que já reduz a Moral (`ship_status_modal.gd._update_morale_bar()`), só
##   explicando o PORQUÊ em vez de um número sem contexto.
##
## MODO "log" REMOVIDO (faxina de resíduo -- `.clauderules` #1, "nunca
## deixe resíduo de código/sinais obsoletos"): existia pro antigo botão de
## rodapé "Diário de Navegação", que saiu de cena desde que o layout novo
## da Ficha do Navio não tem mais espaço/botão pra ele -- nada em lugar
## nenhum do projeto instanciava mais com `info_mode = "log"`, só ficava
## morto esperando. Sem sistema de missão/combate registrado pra preencher
## um diário de verdade ainda, então não foi dado um novo lar só pra manter
## o modo vivo -- quando esse sistema existir, um modo novo (ou este de
## volta) é barato de reconstruir.

signal opened
signal closed

@export var info_mode: String = "cargo"

@onready var _title: Label = $Margin/VBox/Header/Title
@onready var _content: VBoxContainer = $Margin/VBox/Content
@onready var _weight_bar: ProgressBar = $Margin/VBox/WeightBar

const ICON_FRAME_SIZE: float = 28.0
const ICON_BORDER_COLOR: Color = Color(0.78, 0.65, 0.38, 0.9)
const ITEM_SOFTENER_SHADER: Shader = preload("res://assets/shaders/ui_item_softener.gdshader")

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
		"supplies":
			_title.text = "Suprimentos da Tripulação"
	ShipInventory.changed.connect(_on_inventory_changed)
	TavernHireSystem.changed.connect(_on_inventory_changed)


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
	UIManager.animate_modal_open(self)
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
		"supplies":
			_refresh_supplies()


## Lista os equipados (navio + capitão) que dão `cargo_bonus` -- não repete
## o cálculo, só lê o mesmo `get_total_bonuses()` que `ship_base.gd` já usa
## pra saber o total, e identifica as PEÇAS individuais aqui pra mostrar de
## onde vem o bônus.
func _refresh_cargo() -> void:
	var total_label := Label.new()
	var bonuses: Dictionary = ShipInventory.get_total_bonuses()
	total_label.text = "Bônus de carga equipado: +%.0f" % bonuses["cargo_bonus"]
	total_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.76))
	_content.add_child(total_label)

	for slot in ShipInventory.SHIP_SLOTS:
		var instance_id: String = ShipInventory.equipped[slot]
		if instance_id == "":
			continue
		var entry: Dictionary = ShipInventory.crafted_items.get(instance_id, {})
		if entry.get("stats", {}).has("cargo_bonus"):
			_content.add_child(_build_item_row(instance_id, slot.capitalize()))


func _refresh_ammo() -> void:
	var found: bool = false
	for instance_id in ShipInventory.crafted_items:
		var item_id: String = ShipInventory.crafted_items[instance_id]["item_id"]
		var category: String = ItemDatabase.get_item(item_id).get("category", "")
		if category == "municao" or category == "arpao":
			found = true
			_content.add_child(_build_item_row(instance_id, ""))
	if not found:
		var empty := Label.new()
		empty.text = "Nenhuma munição ou arpão fabricado ainda."
		empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
		_content.add_child(empty)


## Ver nota de classe -- expõe o consumo de Ração de Bordo que
## `TavernHireSystem._consume_food_tick()` já roda de verdade a cada
## `FOOD_TICK_INTERVAL`, sem nenhuma UI pra ver o estoque/consumo até agora.
func _refresh_supplies() -> void:
	var stock: float = ShipInventory.materials.get(TavernHireSystem.FOOD_MATERIAL, 0)
	var stock_label := Label.new()
	stock_label.text = "%s: %d" % [TavernHireSystem.FOOD_MATERIAL, int(stock)]
	stock_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	_content.add_child(stock_label)

	var upkeep_total: float = 0.0
	for entry in TavernHireSystem.hired:
		upkeep_total += TavernHireSystem.food_upkeep_for(entry)
	var upkeep_label := Label.new()
	upkeep_label.text = "Consumo da tripulação atual: %.1f a cada %ds" % [upkeep_total, int(TavernHireSystem.FOOD_TICK_INTERVAL)]
	upkeep_label.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
	_content.add_child(upkeep_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_content.add_child(spacer)

	# Mesmo `entry["active"]` que já reduz `TavernHireSystem.is_contributing()`
	# (e portanto a barra de Moral) -- aqui só explica o PORQUÊ em vez de
	# deixar o jogador adivinhar por que a Moral caiu.
	var inactive: Array = []
	for entry in TavernHireSystem.hired:
		if not entry.get("active", true):
			inactive.append(entry)
	if TavernHireSystem.hired.is_empty():
		var none_label := Label.new()
		none_label.text = "Nenhum Marinheiro/Operário contratado ainda."
		none_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
		_content.add_child(none_label)
	elif inactive.is_empty():
		var ok_label := Label.new()
		ok_label.text = "Toda a tripulação está abastecida."
		ok_label.add_theme_color_override("font_color", Color(0.6, 0.82, 0.5))
		_content.add_child(ok_label)
	else:
		var warn_label := Label.new()
		warn_label.text = "Sem ração -- bônus suspenso de %d marinheiro(s):" % inactive.size()
		warn_label.add_theme_color_override("font_color", Color(0.85, 0.4, 0.35))
		_content.add_child(warn_label)
		for entry in inactive:
			var row := Label.new()
			row.text = "- %s (%s)" % [entry["name"], TavernHireSystem.RACE_NAMES[entry["race"]]]
			row.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
			_content.add_child(row)

	# GAP REAL, documentado em vez de fingido: `Ração de Bordo` não tem
	# receita de fabricação em lugar nenhum do projeto (só seedada uma vez,
	# `TavernHireSystem.FOOD_STARTER_QTY`) -- "Culinária" em
	# `life_skills_panel.gd` é só um valor de demonstração, sem estação nem
	# receita de verdade por trás ainda. Sem fabricar uma estação de
	# Culinária inteira só pra esta tela, o jogador precisa saber que o
	# estoque é finito até esse sistema existir, em vez de pensar que sumiu
	# por bug.
	if stock <= 0:
		var gap_spacer := Control.new()
		gap_spacer.custom_minimum_size = Vector2(0, 8)
		_content.add_child(gap_spacer)
		var gap_label := Label.new()
		gap_label.text = "Sem receita de fabricação pra Ração de Bordo ainda -- o estoque inicial é finito até existir uma estação de Culinária de verdade."
		gap_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		gap_label.add_theme_color_override("font_color", Color(0.55, 0.52, 0.46))
		_content.add_child(gap_label)


func _build_item_row(instance_id: String, prefix: String) -> Control:
	var rarity: Dictionary = ShipInventory.get_item_rarity(instance_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_make_icon_frame(ShipInventory.get_item_icon(instance_id)))

	var label := Label.new()
	var name_text: String = ShipInventory.get_item_name(instance_id)
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
	icon_rect.material = ShaderMaterial.new()
	icon_rect.material.shader = ITEM_SOFTENER_SHADER
	frame.add_child(icon_rect)
	return frame
