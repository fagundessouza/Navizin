extends Control
## Cena dedicada de abordagem (`res://scenes/combat/boarding_battle_scene.tscn`),
## carregada por `BoardingManager.start_boarding()` -- substitui a antiga
## modal de abordagem por uma troca de cena de verdade, igual ao pedido
## explícito ("Carregue a cena dedicada"). Só mostra/resolve o que
## `BoardingManager.pending` já calculou; toda a matemática de potência/
## Reversal mora lá, não aqui.
##
## "Simule o confronto do convés": não existe minigame tático de verdade
## (nenhum pedido descreveu um) -- um roll ponderado pela potência das duas
## partes, com a chance de Reversal da Liderança/Trajes do Capitão
## entrando quando o alvo é mais forte, é a simulação.

const OK_COLOR: Color = Color(0.6, 0.82, 0.5, 1.0)
const MISSING_COLOR: Color = Color(0.85, 0.4, 0.35, 1.0)
const REVERSAL_COLOR: Color = Color(0.85, 0.75, 0.25, 1.0)

## Recompensa/penalidade modestas -- sem sistema de loot de abordagem
## descrito em nenhum pedido, então o confronto ainda precisa ter
## consequência real (não só um texto), fica nisso: material salvado na
## vitória, um tranco no casco na derrota, usando os números que já
## existem (`ShipInventory.materials`/`GameManager.saved_hull`).
const VICTORY_LOOT: Dictionary = {"Ouro": 15, "Pólvora": 10}
const DEFEAT_HULL_LOSS: float = 150.0

@onready var _attacker_bar: ProgressBar = $Panel/Margin/VBox/Stats/AttackerBar
@onready var _defender_bar: ProgressBar = $Panel/Margin/VBox/Stats/DefenderBar
@onready var _reversal_label: Label = $Panel/Margin/VBox/ReversalLabel
@onready var _result_label: Label = $Panel/Margin/VBox/ResultLabel
@onready var _attack_button: Button = $Panel/Margin/VBox/Buttons/AttackButton
@onready var _return_button: Button = $Panel/Margin/VBox/Buttons/ReturnButton

var _resolved: bool = false


func _ready() -> void:
	var attacker: float = BoardingManager.pending.get("attacker_power", 1.0)
	var defender: float = BoardingManager.pending.get("defender_power", 1.0)
	var reversal: float = BoardingManager.pending.get("reversal_chance", 0.0)

	_attacker_bar.max_value = maxf(attacker, defender) * 1.2
	_attacker_bar.value = attacker
	_defender_bar.max_value = _attacker_bar.max_value
	_defender_bar.value = defender

	if reversal > 0.0:
		_reversal_label.text = "O navio alvo é mais forte -- Liderança e Trajes do Capitão dão %.0f%% de chance de Reversal mesmo numa falha." % (reversal * 100.0)
		_reversal_label.visible = true
	else:
		_reversal_label.visible = false

	_result_label.text = ""
	_return_button.disabled = true
	_attack_button.pressed.connect(_on_attack_pressed)
	_return_button.pressed.connect(_on_return_pressed)


func _on_attack_pressed() -> void:
	if _resolved:
		return
	_resolved = true
	_attack_button.disabled = true
	var result: Dictionary = BoardingManager.resolve()
	_show_result(result)
	_return_button.disabled = false


func _show_result(result: Dictionary) -> void:
	match result["outcome"]:
		"vitoria":
			_result_label.text = "Vitória! A tripulação toma o navio alvo e recolhe o que sobrou do porão."
			_result_label.add_theme_color_override("font_color", OK_COLOR)
			for material_name in VICTORY_LOOT:
				ShipInventory.materials[material_name] = ShipInventory.materials.get(material_name, 0) + VICTORY_LOOT[material_name]
		"reversal":
			_result_label.text = "Reversal! O navio alvo era mais forte, mas a Liderança do Capitão virou o abordo a seu favor."
			_result_label.add_theme_color_override("font_color", REVERSAL_COLOR)
			for material_name in VICTORY_LOOT:
				ShipInventory.materials[material_name] = ShipInventory.materials.get(material_name, 0) + VICTORY_LOOT[material_name]
		_:
			_result_label.text = "Derrota -- a tripulação recua com o casco avariado pelo contra-ataque."
			_result_label.add_theme_color_override("font_color", MISSING_COLOR)
			GameManager.saved_hull = maxf(0.0, GameManager.saved_hull - DEFEAT_HULL_LOSS)


func _on_return_pressed() -> void:
	SceneTransitionManager.change_scene("res://scenes/world/ocean_map.tscn")
