class_name HudController
extends Control
## Controlador do HUD do capitão. Liga o navio do jogador à interface:
## - barras de casco e de suprimentos, lidas do navio a cada quadro;
## - bússola: a fita desliza pelo rumo do navio;
## - hotbar: ícones dos slots, recarga da bordada no slot 1, teclas 1 a 8;
## - barra de menus: 12 botões com atalho, som de clique e uma caixa de diálogo.

const SLOT_COUNT: int = 8
const FLASH_TIME: float = 0.25
const HOVER_SCALE: Vector2 = Vector2(1.05, 1.05)
const ICON_PATH: String = "res://assets/ui/icons/hot_%d.png"

## Ícones da hotbar por slot: 1 munição, 2 rum, 3 pistola, 4 espada.
const SLOT_ICON_COUNT: int = 4

## Menus: nome do botão, tecla de atalho, título e texto. Janelas ainda sem conteúdo
## mostram "em construção" para não parecer funcional.
const MENUS: Dictionary = {
	"MenuShip": {"key": KEY_L, "title": "Leme e Navio", "body": "Estatísticas do navio: casco, velocidade, carga e suprimentos. Em construção."},
	"MenuAnchor": {"key": KEY_N, "title": "Ancorar", "body": "Recolhe as velas e para o navio. Ativado pelo botão de âncora."},
	"MenuAmmo": {"key": KEY_B, "title": "Munição", "body": "Escolha entre balas normais, encadeadas e incendiárias. Em construção."},
	"MenuCrew": {"key": KEY_C, "title": "Tripulação", "body": "Marinheiros, moral e funções a bordo. Em construção."},
	"MenuGuild": {"key": KEY_F, "title": "Frota e Guilda", "body": "Sua frota, bandeira e guilda pirata. Em construção."},
	"MenuRum": {"key": KEY_R, "title": "Consumíveis", "body": "Poções, rum e rações para uso rápido. Em construção."},
	"MenuMap": {"key": KEY_M, "title": "Mapa do Mundo", "body": "Carta náutica com ilhas e rotas. Em construção."},
	"MenuRecon": {"key": KEY_T, "title": "Reconhecimento", "body": "Visão aumentada e bússola em tela cheia. Em construção."},
	"MenuInventory": {"key": KEY_I, "title": "Inventário", "body": "Inventário do capitão e porão do navio. Em construção."},
	"MenuProfile": {"key": KEY_P, "title": "Perfis e Títulos", "body": "Conquistas e reputação nos mares. Em construção."},
	"MenuCompass": {"key": KEY_V, "title": "Rosa dos Ventos", "body": ""},
	"MenuAlerts": {"key": KEY_K, "title": "Alertas", "body": "Avisos de perigo e de casco baixo. Em construção."},
}

var _ship: Node2D = null
var _hull_connected: bool = false
var _open_menu: String = ""
var _wind: Node = null

@onready var _compass: CompassTape = $CompassHUD
@onready var _hull_fill: TextureProgressBar = $CaptainStatus/HullFill
@onready var _hull_label: Label = $CaptainStatus/HullLabel
@onready var _supply_fill: TextureProgressBar = $CaptainStatus/SupplyFill
@onready var _supply_label: Label = $CaptainStatus/SupplyLabel
@onready var _wind_fill: TextureProgressBar = $CaptainStatus/WindFill
@onready var _wind_label: Label = $CaptainStatus/WindLabel
@onready var _cooldown_1: TextureProgressBar = $Hotbar/Slot1/Cooldown1
@onready var _dialog: NinePatchRect = $DialogPanel
@onready var _click: AudioStreamPlayer = $SystemMenuBar/ClickSound


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wind = get_node("/root/WindManager")
	for k in range(1, SLOT_COUNT + 1):
		var highlight: ColorRect = get_node("Hotbar/Slot%d/Highlight%d" % [k, k])
		highlight.visible = false
	for k in range(1, SLOT_ICON_COUNT + 1):
		var icon: TextureRect = get_node("Hotbar/Slot%d/Icon%d" % [k, k])
		icon.texture = load(ICON_PATH % k)
	for button in $SystemMenuBar/Grid.get_children():
		button.pressed.connect(_on_menu_pressed.bind(button.name))
		button.mouse_entered.connect(_hover.bind(button, true))
		button.mouse_exited.connect(_hover.bind(button, false))


func _process(_delta: float) -> void:
	if not _hull_connected:
		_connect_ship()
	_update_compass()
	_update_status()
	_update_wind()
	_update_cooldown()
	if _open_menu == "MenuCompass":
		_update_compass_body()


## Procura o navio do jogador e liga o sinal de casco uma única vez.
func _connect_ship() -> void:
	_ship = get_tree().get_first_node_in_group("player_ship") as Node2D
	if _ship == null:
		return
	_ship.hull_changed.connect(_on_hull_changed)
	_hull_connected = true


func _on_hull_changed(value: float, max_value: float) -> void:
	_hull_fill.max_value = max_value
	_hull_fill.value = value
	_hull_label.text = "CASCO %d / %d" % [int(value), int(max_value)]


## Barra de suprimentos: lida do navio a cada quadro.
func _update_status() -> void:
	if _ship == null:
		return
	var supply: float = _ship.get("supply")
	var max_supply: float = _ship.get("max_supply")
	_supply_fill.max_value = max_supply
	_supply_fill.value = supply
	_supply_label.text = "SUPRIM. %d/%d" % [int(supply), int(max_supply)]


## Recarga da bordada no slot 1: a área cinza some conforme a arma fica pronta.
func _update_cooldown() -> void:
	if _ship == null:
		return
	_cooldown_1.value = _ship.call("broadside_ratio")


## Rumo do navio: 0 = Norte, cresce no sentido horário, como na bússola.
func _update_compass() -> void:
	if _ship == null:
		return
	_compass.heading = fmod(rad_to_deg(_ship.rotation) + 90.0 + 360.0, 360.0)


## Barra de vento: força atual do WindManager (0.3 a 1.5), com a direção em graus.
func _update_wind() -> void:
	var strength: float = _wind.wind_strength
	_wind_fill.value = clampf(strength / 1.5, 0.0, 1.0)
	var wdir: Vector2 = _wind.wind_direction
	var degrees: int = int(fmod(rad_to_deg(wdir.angle()) + 90.0 + 360.0, 360.0))
	_wind_label.text = "VENTO %d°  %.1f" % [degrees, strength]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE and _open_menu != "":
		_close_panel()
		return
	var index: int = key.keycode - KEY_1
	if index >= 0 and index < SLOT_COUNT:
		_flash_slot(index + 1)
		return
	for menu_name in MENUS:
		if MENUS[menu_name]["key"] == key.keycode:
			_on_menu_pressed(menu_name)
			return


## Clique numa janela: abre, troca ou fecha. Mostra o som de clique.
func _on_menu_pressed(menu_name: String) -> void:
	_click.play()
	if menu_name == "MenuAnchor":
		if _ship != null:
			_ship.set("sail", 0)
		return
	if _open_menu == menu_name:
		_close_panel()
		return
	_open_menu = menu_name
	_dialog.get_node("Title").text = MENUS[menu_name]["title"]
	_dialog.get_node("Body").text = MENUS[menu_name]["body"]
	_dialog.visible = true
	if menu_name == "MenuCompass":
		_update_compass_body()


func _close_panel() -> void:
	_open_menu = ""
	_dialog.visible = false


## Texto da rosa dos ventos: direção e força do vento atual.
func _update_compass_body() -> void:
	var wdir: Vector2 = _wind.wind_direction
	var degrees: int = int(fmod(rad_to_deg(wdir.angle()) + 90.0 + 360.0, 360.0))
	_dialog.get_node("Body").text = "Vento de %d° (rumo do vento).\nForça: %.1f de 1.5." % [degrees, _wind.wind_strength]


## Botão em hover cresce um pouco; sai ao tirar o mouse.
func _hover(button: TextureButton, entered: bool) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.tween_property(button, "scale", HOVER_SCALE if entered else Vector2.ONE, 0.08)


## Acende o slot por um instante, mostrando a tecla que foi usada.
func _flash_slot(slot: int) -> void:
	var highlight: ColorRect = get_node("Hotbar/Slot%d/Highlight%d" % [slot, slot])
	highlight.visible = true
	await get_tree().create_timer(FLASH_TIME).timeout
	highlight.visible = false
