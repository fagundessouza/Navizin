class_name HudController
extends Control
## Controlador do HUD do capitão. Liga o navio do jogador à interface:
## - painel compacto (`CaptainStatus`): Casco e Suprimentos, lidos do navio a
##   cada quadro, mais "Disparo Preparado" (mesmo dado do cooldown da
##   bordada, só invertido) e uma fileira reservada pra ícones de Buffs/
##   Debuffs (vazia por ora, sem sistema de status ainda). Vento SAIU desta
##   lista principal nesta rodada (pedido explícito) -- a mecânica de vento
##   em si continua rodando normal em `WindManager`, só não tem mais barra
##   própria aqui.
## - bússola: a fita desliza pelo rumo do navio;
## - hotbar: 8 slots vazios por padrão (sem item/equip de verdade ainda),
##   recarga da bordada no slot 1, teclas 1 a 8;
## - barra de menus: 6 botões com destino próprio (painel com abas, painel de
##   proficiências ou a caixa de diálogo simples), atalho de teclado e som de clique.
##
## Reduzida de 13 pra 6 ícones: tirado leme isolado, âncora avulsa, munição,
## tripulação solta, rum, mapa, reconhecimento e alertas soltos como botões
## próprios -- cada um ou virou aba dentro de um painel maior (Tripulação ->
## aba do Navio; Alertas -> aba do Diário de Bordo) ou não tinha função clara
## o bastante pra justificar um ícone fixo. "Ancorar" continua funcionando
## pela tecla N, só não tem mais botão (não fazia sentido num grid que agora
## é só de JANELAS, não de ações rápidas).

const SLOT_COUNT: int = 8
const FLASH_TIME: float = 0.25
const HOVER_SCALE: Vector2 = Vector2(1.05, 1.05)

## Botões sem painel dedicado ainda: usam a caixa de diálogo genérica (só
## título + corpo), igual ao sistema antigo.
const SIMPLE_MENUS: Dictionary = {
	"MenuGuild": {"key": KEY_G, "title": "Salão das Frotas", "body": "Sua frota, bandeira e guilda pirata. Veja o salão completo na Guilda de Tortuga. Em construção."},
	"MenuSettings": {"key": KEY_O, "title": "Configurações", "body": "Resolução, áudio e escala de UI. Em construção."},
}

## Botões com painel próprio (`CaptainPanel`/`LifeSkillsPanel` na cena) -- só
## a tecla de atalho fica aqui, o nó em si é resolvido em `_ready()`.
const DEDICATED_KEYS: Dictionary = {
	"MenuShip": KEY_L,
	"MenuMissions": KEY_J,
	"MenuAccessories": KEY_C,
	"MenuLifeSkills": KEY_V,
}

var _ship: Node2D = null
var _hull_connected: bool = false
var _open_menu: String = ""
var _dedicated_panels: Dictionary = {}

@onready var _compass: CompassTape = $CompassHUD
@onready var _hull_fill: TextureProgressBar = $CaptainStatus/HullFill
@onready var _hull_label: Label = $CaptainStatus/HullLabel
@onready var _supply_fill: TextureProgressBar = $CaptainStatus/SupplyFill
@onready var _supply_label: Label = $CaptainStatus/SupplyLabel
@onready var _shot_fill: ProgressBar = $CaptainStatus/ShotFill
@onready var _cooldown_1: TextureProgressBar = $Hotbar/Slot1/Cooldown1
@onready var _dialog: NinePatchRect = $DialogPanel
@onready var _click: AudioStreamPlayer = $SystemMenuBar/ClickSound


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dedicated_panels = {
		"MenuShip": $ShipPanel,
		"MenuMissions": $MissionsPanel,
		"MenuAccessories": $AccessoriesPanel,
		"MenuLifeSkills": $LifeSkillsPanel,
	}
	for k in range(1, SLOT_COUNT + 1):
		var highlight: ColorRect = get_node("Hotbar/Slot%d/Highlight%d" % [k, k])
		highlight.visible = false
	for button in $SystemMenuBar/Grid.get_children():
		button.pressed.connect(_on_menu_pressed.bind(button.name))
		button.mouse_entered.connect(_hover.bind(button, true))
		button.mouse_exited.connect(_hover.bind(button, false))


func _process(_delta: float) -> void:
	if not _hull_connected:
		_connect_ship()
	_update_compass()
	_update_status()
	_update_cooldown()
	_update_shot_fill()


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


## "Disparo Preparado" do painel compacto: mesmo dado de `_update_cooldown()`
## (`broadside_ratio()`, 0 = pronto, 1 = recém disparado), só que invertido
## pra a barra ENCHER conforme fica pronta, em vez de esvaziar -- é mais
## legível como "carga pronta" assim do que como "tempo de recarga restante".
## Não é um número novo inventado só pra essa barra, é o mesmo cooldown que
## já media o slot 1 da hotbar.
func _update_shot_fill() -> void:
	if _ship == null:
		return
	_shot_fill.value = 1.0 - float(_ship.call("broadside_ratio"))


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE and _open_menu != "":
		_close_panel()
		return
	if key.keycode == KEY_N:
		if _ship != null:
			_ship.set("sail", 0)
		return
	var index: int = key.keycode - KEY_1
	if index >= 0 and index < SLOT_COUNT:
		_flash_slot(index + 1)
		return
	for menu_name in SIMPLE_MENUS:
		if SIMPLE_MENUS[menu_name]["key"] == key.keycode:
			_on_menu_pressed(menu_name)
			return
	for menu_name in DEDICATED_KEYS:
		if DEDICATED_KEYS[menu_name] == key.keycode:
			_on_menu_pressed(menu_name)
			return


## Clique numa janela: abre, troca ou fecha. Mostra o som de clique. Os 4
## botões com painel próprio (`_dedicated_panels`) abrem/fecham o painel deles;
## os outros 2 continuam na caixa de diálogo genérica de título + corpo.
func _on_menu_pressed(menu_name: String) -> void:
	_click.play()
	if _open_menu == menu_name:
		_close_panel()
		return
	if _open_menu != "":
		_close_panel()
	_open_menu = menu_name
	if _dedicated_panels.has(menu_name):
		_dedicated_panels[menu_name].open()
		return
	var info: Dictionary = SIMPLE_MENUS[menu_name]
	_dialog.get_node("Title").text = info["title"]
	_dialog.get_node("Body").text = info["body"]
	_dialog.visible = true


func _close_panel() -> void:
	if _dedicated_panels.has(_open_menu):
		_dedicated_panels[_open_menu].close()
	else:
		_dialog.visible = false
	_open_menu = ""


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
