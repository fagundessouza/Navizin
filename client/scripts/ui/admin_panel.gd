class_name AdminPanel
extends Control
## Painel de Admin/Debug (F3, `AdminManager`) -- estilo "Admin Menu" do
## FiveM: 4 abas construídas por código (mesmo padrão de `CrafingModal`/
## `CrewCardModal`, nada aqui precisa de layout fixo no editor) + o
## checkbox do overlay de IDs no cabeçalho, sempre visível independente da
## aba aberta.
##
## Fica fora do sistema de "um modal urbano por vez" (`UIManager.open_modal`)
## de propósito -- é uma ferramenta de DESENVOLVEDOR, deve poder ficar aberta
## por cima de qualquer outra coisa (craft, taverna, mar) sem fechar nada.

signal opened
signal closed

const QUICK_GOLD: int = 1000
const QUICK_SILVER: int = 1000
const QUICK_ATTR_POINTS: int = 5
const NORMAL_FONT_COLOR: Color = Color(0.93, 0.9, 0.84, 1.0)
const WARN_COLOR: Color = Color(0.85, 0.55, 0.3, 1.0)
const OK_COLOR: Color = Color(0.55, 0.8, 0.5, 1.0)

@onready var _close_button: Button = $Margin/VBox/Header/CloseButton
@onready var _debug_ids_check: CheckButton = $Margin/VBox/Header/DebugIdsCheck
@onready var _tabs: TabContainer = $Margin/VBox/Tabs

var _search_edit: LineEdit
var _results_list: VBoxContainer
var _quantity_spin: SpinBox
var _selected_item_id: String = ""
var _spawn_feedback: Label

var _crew_list: VBoxContainer
var _scenario_feedback: Label
var _spritesheet_preview: TextureRect
var _spritesheet_label: Label


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(close)
	_debug_ids_check.button_pressed = AdminManager.show_debug_ids
	_debug_ids_check.toggled.connect(func(pressed: bool): AdminManager.show_debug_ids = pressed)
	_build_item_tab()
	_build_economy_tab()
	_build_crew_tab()
	_build_scenario_tab()
	TavernHireSystem.changed.connect(_refresh_crew_list)


func open() -> void:
	visible = true
	UIManager.animate_modal_open(self)
	_refresh_item_results()
	_refresh_crew_list()
	opened.emit()


func close() -> void:
	visible = false
	closed.emit()


# ---------------------------------------------------------------------------
# ABA 1: Inventário & Itens (Item Spawner)
# ---------------------------------------------------------------------------

func _build_item_tab() -> void:
	var root := VBoxContainer.new()
	root.name = "Itens"
	root.add_theme_constant_override("separation", 8)
	_tabs.add_child(root)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Buscar por ID ou nome..."
	_search_edit.text_changed.connect(func(_t): _refresh_item_results())
	root.add_child(_search_edit)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 260)
	root.add_child(scroll)

	_results_list = VBoxContainer.new()
	_results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_results_list)

	var spawn_row := HBoxContainer.new()
	spawn_row.add_theme_constant_override("separation", 10)
	root.add_child(spawn_row)

	var qty_label := Label.new()
	qty_label.text = "Qtd:"
	qty_label.add_theme_color_override("font_color", NORMAL_FONT_COLOR)
	spawn_row.add_child(qty_label)

	_quantity_spin = SpinBox.new()
	_quantity_spin.min_value = 1
	_quantity_spin.max_value = 99
	_quantity_spin.value = 1
	spawn_row.add_child(_quantity_spin)

	var spawn_button := Button.new()
	spawn_button.text = "Spawnar no Inventário"
	spawn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_button.pressed.connect(_on_spawn_pressed)
	spawn_row.add_child(spawn_button)

	_spawn_feedback = Label.new()
	_spawn_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spawn_feedback.add_theme_font_size_override("font_size", 12)
	root.add_child(_spawn_feedback)

	_refresh_item_results()


## Filtra `ItemDatabase.ITEMS` por id OU nome (case-insensitive) -- lista
## achatada, os mesmos itens que todo CraftingModal do jogo já usa, não uma
## base paralela só pro admin.
func _refresh_item_results() -> void:
	for child in _results_list.get_children():
		child.queue_free()
	var query: String = _search_edit.text.to_lower()
	var matches: Array = []
	for item_id in ItemDatabase.ITEMS:
		var item: Dictionary = ItemDatabase.ITEMS[item_id]
		if query == "" or item_id.to_lower().contains(query) or String(item.get("name", "")).to_lower().contains(query):
			matches.append(item_id)
	matches.sort()
	for item_id in matches.slice(0, 60):
		_results_list.add_child(_build_result_row(item_id))
	if matches.is_empty():
		var empty := Label.new()
		empty.text = "Nada encontrado."
		empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
		_results_list.add_child(empty)


func _build_result_row(item_id: String) -> Button:
	var item: Dictionary = ItemDatabase.get_item(item_id)
	var row := Button.new()
	row.flat = not (_selected_item_id == item_id)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.text = "%s  [%s]" % [item.get("name", item_id), item_id]
	row.pressed.connect(func():
		_selected_item_id = item_id
		_refresh_item_results())
	return row


func _on_spawn_pressed() -> void:
	if _selected_item_id == "":
		_spawn_feedback.text = "Selecione um item na lista primeiro."
		_spawn_feedback.add_theme_color_override("font_color", WARN_COLOR)
		return
	var item: Dictionary = ItemDatabase.get_item(_selected_item_id)
	var inv: Node = CaptainInventory if ItemDatabase.is_captain_category(item.get("category", "")) else ShipInventory
	var recipe: Dictionary = ItemDatabase.get_recipe(_selected_item_id)
	# Admin sempre tem o material -- completa o que faltar antes de fabricar
	# pela função de craft REAL (mesmo rolo de qualidade/Float que o jogo
	# normal usa), em vez de duplicar a montagem de item aqui.
	for material_name in recipe.get("materials", {}):
		var needed: int = recipe["materials"][material_name] * int(_quantity_spin.value)
		if ShipInventory.materials.get(material_name, 0) < needed:
			ShipInventory.materials[material_name] = needed

	var spawned: int = 0
	for i in int(_quantity_spin.value):
		if inv.craft(_selected_item_id) != "":
			spawned += 1
	_spawn_feedback.text = "%dx %s adicionado ao inventário %s." % [spawned, item.get("name", _selected_item_id), "do Capitão" if inv == CaptainInventory else "do Navio"]
	_spawn_feedback.add_theme_color_override("font_color", OK_COLOR)


# ---------------------------------------------------------------------------
# ABA 2: Moedas & Recursos (Economy)
# ---------------------------------------------------------------------------

func _build_economy_tab() -> void:
	var root := VBoxContainer.new()
	root.name = "Economia"
	root.add_theme_constant_override("separation", 10)
	_tabs.add_child(root)

	_add_economy_button(root, "+%d Ouro" % QUICK_GOLD, func():
		ShipInventory.materials["Ouro"] = ShipInventory.materials.get("Ouro", 0) + QUICK_GOLD)
	_add_economy_button(root, "+%d Prata" % QUICK_SILVER, func():
		ShipInventory.materials["Prata"] = ShipInventory.materials.get("Prata", 0) + QUICK_SILVER)
	_add_economy_button(root, "+%d Pontos de Atributo do Capitão" % QUICK_ATTR_POINTS, func():
		CaptainAttributes.available_points += QUICK_ATTR_POINTS
		CaptainAttributes.changed.emit())
	_add_economy_button(root, "Reparo Instantâneo do Casco", func():
		var ship: Node2D = get_tree().get_first_node_in_group("player_ship") as Node2D
		if ship != null and ship.has_method("repair_full"):
			ship.repair_full())

	var note := Label.new()
	note.text = "\"Pontos de Atributo\" é o número real que já existe pra Liderança/Carisma/Persuasão -- não há XP/nível de capitão separado no jogo ainda."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
	root.add_child(note)


func _add_economy_button(root: VBoxContainer, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(action)
	root.add_child(button)


# ---------------------------------------------------------------------------
# ABA 3: Tripulação & Tropas (Crew Debug)
# ---------------------------------------------------------------------------

func _build_crew_tab() -> void:
	var root := VBoxContainer.new()
	root.name = "Tripulação"
	root.add_theme_constant_override("separation", 10)
	_tabs.add_child(root)

	var add_label := Label.new()
	add_label.text = "Adicionar Marinheiro (sem custo de Energia/Ouro, ignora o teto de vagas):"
	add_label.add_theme_font_size_override("font_size", 12)
	add_label.add_theme_color_override("font_color", NORMAL_FONT_COLOR)
	root.add_child(add_label)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	root.add_child(add_row)
	_add_crew_button(add_row, "Humano", TavernHireSystem.Race.HUMAN)
	_add_crew_button(add_row, "Goblin", TavernHireSystem.Race.GOBLIN)
	_add_crew_button(add_row, "Goblin Puro", TavernHireSystem.Race.GOBLIN_PURE)
	_add_crew_button(add_row, "Anão", TavernHireSystem.Race.DWARF)
	_add_crew_button(add_row, "Morto-Vivo", TavernHireSystem.Race.UNDEAD)

	var status_label := Label.new()
	status_label.text = "Definir estado de saúde de TODOS os marinheiros contratados:"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", NORMAL_FONT_COLOR)
	root.add_child(status_label)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	root.add_child(status_row)
	_add_status_button(status_row, TavernHireSystem.STATUS_READY)
	_add_status_button(status_row, TavernHireSystem.STATUS_WOUNDED)
	_add_status_button(status_row, TavernHireSystem.STATUS_SICK)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 160)
	root.add_child(scroll)

	_crew_list = VBoxContainer.new()
	_crew_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crew_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_crew_list)


func _add_crew_button(row: HBoxContainer, label: String, race: TavernHireSystem.Race) -> void:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Graduação "Hábil" (índice 1) como padrão -- nem o piso nem o teto,
	# dá pra ver bônus de verdade sem já nascer no topo da escada.
	button.pressed.connect(func(): TavernHireSystem.force_add(race, 1))
	row.add_child(button)


func _add_status_button(row: HBoxContainer, status: String) -> void:
	var button := Button.new()
	button.text = TavernHireSystem.STATUS_NAMES[status]
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func(): TavernHireSystem.set_status("", status))
	row.add_child(button)


func _refresh_crew_list() -> void:
	if _crew_list == null:
		return
	for child in _crew_list.get_children():
		child.queue_free()
	if TavernHireSystem.hired.is_empty():
		var empty := Label.new()
		empty.text = "Nenhum marinheiro contratado ainda."
		empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
		_crew_list.add_child(empty)
		return
	for entry in TavernHireSystem.hired:
		var row := Label.new()
		var status_name: String = TavernHireSystem.STATUS_NAMES.get(entry.get("status", ""), "?")
		row.text = "%s -- %s [%s] -- %s" % [entry["name"], TavernHireSystem.RACE_NAMES[entry["race"]], TavernHireSystem.QUALITIES[entry["quality_index"]]["name"], status_name]
		row.add_theme_font_size_override("font_size", 12)
		row.add_theme_color_override("font_color", OK_COLOR if TavernHireSystem.is_contributing(entry) else WARN_COLOR)
		_crew_list.add_child(row)


# ---------------------------------------------------------------------------
# ABA 4: Testes de Cena (Scenarios)
# ---------------------------------------------------------------------------

func _build_scenario_tab() -> void:
	var root := VBoxContainer.new()
	root.name = "Cenas"
	root.add_theme_constant_override("separation", 10)
	_tabs.add_child(root)

	var boarding_button := Button.new()
	boarding_button.text = "Forçar Início da Batalha de Abordagem"
	boarding_button.pressed.connect(_on_force_boarding)
	root.add_child(boarding_button)

	_scenario_feedback = Label.new()
	_scenario_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scenario_feedback.add_theme_font_size_override("font_size", 12)
	root.add_child(_scenario_feedback)

	root.add_child(HSeparator.new())

	var sprite_label := Label.new()
	sprite_label.text = "Spritesheets de Tropas de Abordagem:"
	sprite_label.add_theme_color_override("font_color", NORMAL_FONT_COLOR)
	root.add_child(sprite_label)

	var sprite_row := HBoxContainer.new()
	sprite_row.add_theme_constant_override("separation", 8)
	root.add_child(sprite_row)

	var melee_button := Button.new()
	melee_button.text = "Testar Spritesheet Melee"
	melee_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	melee_button.pressed.connect(func(): _preview_spritesheet("res://assets/sprites/troops/melee_troop.png", "Melee"))
	sprite_row.add_child(melee_button)

	var ranged_button := Button.new()
	ranged_button.text = "Testar Spritesheet Ranged"
	ranged_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ranged_button.pressed.connect(func(): _preview_spritesheet("res://assets/sprites/troops/ranged_troop.png", "Ranged"))
	sprite_row.add_child(ranged_button)

	_spritesheet_label = Label.new()
	_spritesheet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spritesheet_label.add_theme_font_size_override("font_size", 12)
	root.add_child(_spritesheet_label)

	_spritesheet_preview = TextureRect.new()
	_spritesheet_preview.custom_minimum_size = Vector2(0, 120)
	_spritesheet_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_spritesheet_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(_spritesheet_preview)


## Sem navio inimigo de verdade ainda (ver `boarding_manager.gd`) -- monta um
## `pending` sintético com a potência REAL do navio do jogador (mesma conta
## de `BoardingManager._attacker_power()`) contra um alvo de teste fixo, só
## pra exercitar a troca de cena/UI de batalha sem precisar de um NPC.
func _on_force_boarding() -> void:
	var ship: Node2D = get_tree().get_first_node_in_group("player_ship") as Node2D
	if ship == null:
		_scenario_feedback.text = "Sem navio do jogador na cena atual -- entre no mar primeiro."
		_scenario_feedback.add_theme_color_override("font_color", WARN_COLOR)
		return
	GameManager.saved_ship_position = ship.global_position
	GameManager.saved_hull = ship.hull
	GameManager.saved_supply = ship.supply
	var leadership_attr: int = CaptainAttributes.leadership
	var leadership_gear: float = CaptainInventory.get_captain_bonuses().get("leadership_bonus", 0.0)
	var leadership_officer: float = OfficerRoster.get_officer_bonuses().get("leadership_bonus", 0.0)
	var cannon_mult: float = ship.cannon_damage_mult if ("cannon_damage_mult" in ship) else 1.0
	var attacker_power: float = 1.0 + leadership_attr * 0.04 + (leadership_gear + leadership_officer) * 0.015 + (cannon_mult - 1.0) * 0.5
	BoardingManager.pending = {
		"attacker_power": attacker_power,
		"defender_power": 1.0,
		"reversal_chance": 0.0,
		"target_name": "Alvo de Teste (Admin)",
	}
	BoardingManager.boarding_started.emit()
	close()
	SceneTransitionManager.change_scene("res://scenes/combat/boarding_battle_scene.tscn")


## Nenhum spritesheet de tropa Melee/Ranged chegou em
## `~/Downloads/Tortuga/` até esta rodada -- em vez de inventar uma imagem
## pra "funcionar", o botão carrega o caminho esperado de verdade e avisa
## claramente quando não encontra nada, pronto pra mostrar a arte real no
## dia em que ela existir.
func _preview_spritesheet(path: String, label: String) -> void:
	if not ResourceLoader.exists(path):
		_spritesheet_preview.texture = null
		_spritesheet_label.text = "Spritesheet %s não encontrado -- aguardando arte em %s." % [label, path]
		_spritesheet_label.add_theme_color_override("font_color", WARN_COLOR)
		return
	_spritesheet_preview.texture = load(path)
	_spritesheet_label.text = "Spritesheet %s carregado de %s." % [label, path]
	_spritesheet_label.add_theme_color_override("font_color", OK_COLOR)
