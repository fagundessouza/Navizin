class_name HudController
extends Control
## Controlador do HUD do capitão. Liga o navio do jogador à interface:
## - barra de casco (sinal `hull_changed` do navio);
## - bússola: a fita desliza pelo rumo do navio em tempo real;
## - teclas 1 a 8 acendem o slot correspondente na barra de ação.

const SLOT_COUNT: int = 8
## Pixels de fita por grau. A fita tem 634 px e cobre a volta inteira.
const TAPE_PX_PER_DEG: float = 634.0 / 360.0
const TAPE_WIDTH: float = 634.0
const FLASH_TIME: float = 0.25

var _ship: Node2D = null
var _hull_connected: bool = false

@onready var _hull_bar: TextureProgressBar = $PlayerPortrait/HullBar
@onready var _tape_a: TextureRect = $CompassHUD/TapeA
@onready var _tape_b: TextureRect = $CompassHUD/TapeB


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in range(1, SLOT_COUNT + 1):
		var highlight: ColorRect = get_node("HotbarHUD/Slots/Slot%d/Highlight%d" % [k, k])
		highlight.visible = false


func _process(_delta: float) -> void:
	if not _hull_connected:
		_connect_ship()
	_update_compass()


## Procura o navio do jogador e liga o sinal de casco uma única vez.
func _connect_ship() -> void:
	_ship = get_tree().get_first_node_in_group("player_ship") as Node2D
	if _ship == null:
		return
	_ship.hull_changed.connect(_on_hull_changed)
	_on_hull_changed(_ship.get("hull"), _ship.get("max_hull"))
	_hull_connected = true


func _on_hull_changed(value: float, max_value: float) -> void:
	_hull_bar.max_value = max_value
	_hull_bar.value = value


## Rumo do navio: 0 = Norte, cresce no sentido horário, como na bússola.
func _update_compass() -> void:
	var heading: float = 0.0
	if _ship != null:
		heading = fmod(rad_to_deg(_ship.rotation) + 90.0 + 360.0, 360.0)
	var offset: float = fmod(heading * TAPE_PX_PER_DEG, TAPE_WIDTH)
	# A fita anda para a esquerda quando o rumo cresce; a segunda cópia fecha a volta.
	_tape_a.position.x = 180.0 - offset - TAPE_WIDTH * 0.5
	_tape_b.position.x = _tape_a.position.x + TAPE_WIDTH


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index: int = key.keycode - KEY_1
	if index < 0 or index >= SLOT_COUNT:
		return
	_flash_slot(index + 1)


## Acende o slot por um instante, mostrando a tecla que foi usada.
func _flash_slot(slot: int) -> void:
	var highlight: ColorRect = get_node("HotbarHUD/Slots/Slot%d/Highlight%d" % [slot, slot])
	highlight.visible = true
	await get_tree().create_timer(FLASH_TIME).timeout
	highlight.visible = false
