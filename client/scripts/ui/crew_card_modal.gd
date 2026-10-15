class_name CrewCardModal
extends Control
## Painel de Marinheiros/Operários (`TavernHireSystem`): roleta de
## contratação no topo + grade de CARDS visuais dos já contratados embaixo
## -- substitui a antiga barra de texto seca "Tropas: 0/40" que
## `CrewManagementSubmodal` mostrava (aquela barra nunca teve contratação de
## verdade por trás, só o teto).
##
## REUTILIZADO EM 2 LUGARES, mesma cena/script os dois: instanciado como
## estação própria na Taverna (`tavern_district.tscn`, segue o contrato
## padrão de modal -- `open()`/`close()`/`opened`/`closed`, igual
## `CraftingModal`/`VaultModal`) E embutido dentro de
## `CrewManagementSubmodal` como seção permanente (nunca chama o próprio
## `open()`/`close()` lá -- a visibilidade geral é do submodal pai; aqui só
## escuta `TavernHireSystem.changed` e atualiza sozinho, então funciona nos
## dois contextos sem precisar saber qual é.
##
## RETRATOS: cada marinheiro sorteia Raça E Profissão (`TavernHireSystem.
## _make_entry()`, profissão só pra variar o visual -- não vira Oficial de
## verdade) e grava o caminho de retrato na própria entrada
## (`entry["portrait_path"]`, mesma prancha de 32 arquivos que
## `OfficerRoster` usa pros 8 cargos), já resolvido na hora da rolagem.

signal opened
signal closed

## `false` quando embutido dentro de outro modal já com moldura própria
## (`CrewManagementSubmodal`) -- evita duas molduras góticas aninhadas.
## Mesmo padrão de `CraftingModal.show_refine_button` pro `RefinementModal`
## embutido.
@export var show_own_chrome: bool = true

const CARD_SIZE: Vector2 = Vector2(150, 190)
const PORTRAIT_SIZE: float = 96.0
const ROULETTE_SPIN_TIME: float = 0.9
const ROULETTE_TICK_TIME: float = 0.06
const RARITY_GLOW_SHADER: Shader = preload("res://assets/shaders/item_rarity_glow.gdshader")

const NORMAL_FONT_COLOR: Color = Color(0.93, 0.9, 0.84, 1.0)
const INACTIVE_COLOR: Color = Color(0.65, 0.35, 0.3, 1.0)
const ACTIVE_COLOR: Color = Color(0.55, 0.78, 0.5, 1.0)

@onready var _energy_label: Label = $Margin/VBox/SubHeader/EnergyLabel
@onready var _capacity_label: Label = $Margin/VBox/Header/CapacityLabel
@onready var _roll_button: Button = $Margin/VBox/SubHeader/RollButton
@onready var _roulette_label: Label = $Margin/VBox/RouletteLabel
@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid

var _rng := RandomNumberGenerator.new()
var _rolling: bool = false
var _glow_phase_counter: int = 0


func _ready() -> void:
	visible = true
	_rng.randomize()
	_roulette_label.text = ""
	if not show_own_chrome:
		$Frame.visible = false
		$SkullBanner.visible = false
		$Margin/VBox/Header/CloseButton.visible = false
	else:
		$Margin/VBox/Header/CloseButton.pressed.connect(close)
	_roll_button.pressed.connect(_on_roll_pressed)
	TavernHireSystem.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if visible:
		_energy_label.text = "Energia: %d/%d" % [TavernHireSystem.energy, TavernHireSystem.MAX_ENERGY]


## Pra uso como modal independente (Taverna) -- quando embutido dentro de
## `CrewManagementSubmodal`, ninguém chama isto, a visibilidade é do pai.
func open() -> void:
	visible = true
	UIManager.animate_modal_open(self)
	_refresh()
	opened.emit()


func close() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	_capacity_label.text = "Marinheiros: %d/%d" % [TavernHireSystem.hired.size(), TavernHireSystem.max_sailors()]
	_roll_button.disabled = _rolling or not TavernHireSystem.can_roll()
	_roll_button.text = "Rolar Marinheiro (%dx Energia, %dx Ouro)" % [TavernHireSystem.ROLL_ENERGY_COST, TavernHireSystem.ROLL_GOLD_COST]

	for child in _grid.get_children():
		child.queue_free()
	for entry in TavernHireSystem.hired:
		_grid.add_child(_build_card(entry))


func _on_roll_pressed() -> void:
	if _rolling or not TavernHireSystem.can_roll():
		return
	_rolling = true
	_roll_button.disabled = true
	await _play_roulette()
	var entry: Dictionary = TavernHireSystem.roll_sailor()
	_rolling = false
	if entry.is_empty():
		_roulette_label.text = "Não foi possível rolar."
		# `roll_sailor()` só emite `changed` (que reativa o botão via
		# `_refresh()`) quando a rolagem DÁ CERTO -- sem isto aqui, um
		# `can_roll()` que virou falso DURANTE o giro (energia/ouro/vaga
		# mudou nesse meio-tempo) deixava o botão travado desabilitado pra
		# sempre, já que nada mais chamaria `_refresh()` depois.
		_refresh()
		return
	var quality: Dictionary = TavernHireSystem.QUALITIES[entry["quality_index"]]
	_roulette_label.text = "%s -- %s [%s]!" % [entry["name"], TavernHireSystem.RACE_NAMES[entry["race"]], quality["name"]]
	_roulette_label.add_theme_color_override("font_color", quality["color"])
	_pulse(_roulette_label)


## Giro rápido da "roleta": alterna textos de Raça+Graduação aleatórios por
## `ROULETTE_SPIN_TIME` segundos antes do resultado de verdade aparecer --
## dá a leitura de "roleta rodando" sem precisar de uma faixa giratória de
## sprites de verdade (nenhuma arte desse tipo foi pedida/entregue).
func _play_roulette() -> void:
	var races: Array = TavernHireSystem.RACE_NAMES.values()
	var qualities: Array = TavernHireSystem.QUALITIES
	var elapsed: float = 0.0
	while elapsed < ROULETTE_SPIN_TIME:
		var race_name: String = races[_rng.randi() % races.size()]
		var quality: Dictionary = qualities[_rng.randi() % qualities.size()]
		_roulette_label.text = "%s [%s]..." % [race_name, quality["name"]]
		_roulette_label.add_theme_color_override("font_color", quality["color"])
		await get_tree().create_timer(ROULETTE_TICK_TIME).timeout
		elapsed += ROULETTE_TICK_TIME


func _build_card(entry: Dictionary) -> Control:
	var quality: Dictionary = TavernHireSystem.QUALITIES[entry["quality_index"]]
	var active: bool = TavernHireSystem.is_contributing(entry)

	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = quality["color"] if active else Color(0.4, 0.2, 0.18, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	UIManager.add_hover_pop(card, entry["id"])

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var portrait_wrap := Control.new()
	portrait_wrap.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	vbox.add_child(portrait_wrap)

	var portrait := TextureRect.new()
	portrait.texture = load(entry["portrait_path"])
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.modulate = Color(1, 1, 1, 1) if active else Color(0.5, 0.5, 0.5, 1.0)
	portrait_wrap.add_child(portrait)

	if quality["aura"] != 0 or active:
		var glow := ColorRect.new()
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow.color = Color.WHITE
		var mat := ShaderMaterial.new()
		mat.shader = RARITY_GLOW_SHADER
		mat.set_shader_parameter("rarity_color", quality["color"])
		mat.set_shader_parameter("aura_mode", quality["aura"] if active else 0)
		mat.set_shader_parameter("refine_boost", 0.0)
		mat.set_shader_parameter("phase_offset", _next_glow_phase())
		glow.material = mat
		portrait_wrap.add_child(glow)

	var name_label := Label.new()
	name_label.text = entry["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CraftingManager.style_item_label(name_label, {"color": quality["color"]})
	name_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(name_label)

	var race_label := Label.new()
	race_label.text = "%s, %s -- %s" % [TavernHireSystem.RACE_NAMES[entry["race"]], OfficerRoster.ROLE_NAMES[entry["profession"]], quality["name"]]
	race_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	race_label.add_theme_font_size_override("font_size", 10)
	race_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.6))
	vbox.add_child(race_label)

	var status_label := Label.new()
	status_label.text = _status_text(entry, active)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", ACTIVE_COLOR if active else INACTIVE_COLOR)
	vbox.add_child(status_label)

	var bonus_label := Label.new()
	bonus_label.text = _bonus_summary(entry)
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus_label.add_theme_font_size_override("font_size", 9)
	bonus_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.7))
	vbox.add_child(bonus_label)

	var dismiss_button := Button.new()
	dismiss_button.text = "Dispensar"
	dismiss_button.add_theme_font_size_override("font_size", 10)
	dismiss_button.pressed.connect(func(): TavernHireSystem.dismiss(entry["id"]))
	vbox.add_child(dismiss_button)

	return card


## Dois motivos distintos pra não contribuir -- "Sem ração" (comida,
## `active`) e "Ferido"/"Doente" (`status`, Painel de Admin) são causas
## diferentes, mostrar o mesmo texto genérico pra ambas esconderia qual
## delas resolver.
func _status_text(entry: Dictionary, contributing: bool) -> String:
	if contributing:
		return "Em atividade"
	if not entry.get("active", true):
		return "Sem ração -- inativo"
	return "%s -- sem bônus" % TavernHireSystem.STATUS_NAMES.get(entry.get("status", ""), "Indisponível")


func _bonus_summary(entry: Dictionary) -> String:
	var bonus: Dictionary = TavernHireSystem.bonus_for(entry)
	var parts: PackedStringArray = []
	for key in bonus:
		var label: String = ItemTooltipZoom.STAT_LABELS.get(key, key)
		var value: float = bonus[key]
		if ItemTooltipZoom.PERCENT_STATS.has(key):
			parts.append("%s %s%.0f%%" % [label, "+" if value >= 0 else "", value * 100.0])
		else:
			parts.append("%s %s%.0f" % [label, "+" if value >= 0 else "", value])
	return ", ".join(parts)


func _next_glow_phase() -> float:
	_glow_phase_counter += 1
	return fmod(float(_glow_phase_counter) * 0.37, TAU)


func _pulse(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	var tw := create_tween()
	tw.tween_property(control, "scale", Vector2(1.12, 1.12), 0.1)
	tw.tween_property(control, "scale", Vector2.ONE, 0.18)
