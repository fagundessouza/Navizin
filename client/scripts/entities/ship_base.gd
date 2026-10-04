extends Node2D
## Base de todos os navios (jogador e NPCs).
##
## Concentra a física (velas com inércia, leme suave, recuo, vento e maré), a
## apresentação (vista do navio entre as 7 direções, balanço de flutuação,
## sombra, esteira e fumaça) e o disparo lateral com carga de força.
## Os atributos vêm do recurso `ShipData`.
##
## Controle do jogador:
## - A proa segue o ponteiro do mouse. O leme trava enquanto um tiro carrega.
## - W/S (ou setas) mudam o nível das velas.
## - Bombordo: tecla Q ou botão esquerdo. Estibordo: tecla E ou botão direito.
##   Segurar entra em modo de mira e carrega a força. Soltar dispara aquele bordo.
##   Q e E juntos mantêm os dois em mira. A carga cheia dispara sozinha.
##   Cada bateria tem cooldown próprio.
## - A mira fica presa ao semiplano do bordo escolhido, entre a proa e a popa.
## - Teclas 1 a 4 emitem `skill_triggered`. Ainda sem efeito.
##
## NPCs deixam `player_controlled` falso e recebem comandos de IA no futuro.

## Nível das velas. O valor é o sentido e a força do impulso.
enum Sail { REVERSE = -1, STOPPED = 0, HALF = 1, FULL = 2 }


## Emitido ao pressionar uma tecla de habilidade. `skill_index` vai de 1 a 4.
signal skill_triggered(skill_index: int)

## Emitido a cada bordada disparada. `target` é a posição do ponteiro no mundo.
signal primary_action_triggered(target: Vector2)

## Emitido com o bordo (-1 bombordo, 1 estibordo) e a força (0 a 1).
signal broadside_fired(side: int, power: float)

const SIDE_PORT: int = -1
const SIDE_STARBOARD: int = 1

## Força mínima de qualquer bordada. Um toque rápido ainda sai como tiro visível.
const TAP_MIN_POWER: float = 0.3

## Os 16 frames de direção, arquivo `dir16_NN.png`, 00 a 15 da ficha.
const DIR16_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_00.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_01.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_02.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_03.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_04.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_05.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_06.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_07.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_08.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_09.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_10.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_11.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_12.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_13.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_14.png"),
	preload("res://assets/sprites/ships/holandes_voador/dirs16/dir16_15.png"),
]

## Direções mostradas: [ângulo em graus, frame, espelha na horizontal, espelha na
## vertical]. Ordenadas pelo ângulo. Os 16 passos de 22.5° mais os intermediários
## de 33.75°, 191.25° e 348.75°, que são os espelhos do primeiro frame lateral
## depois de 6 e de 4.
const DIR_ENTRIES: Array = [
	[0, 4, false, false],  # 0°
	[22.5, 4, false, false],  # 22.5°
	[45, 10, false, false],  # 45°
	[67.5, 13, true, false],  # 67.5°
	[90, 0, false, false],  # 90°
	[112.5, 13, false, false],  # 112.5°
	[135, 10, true, false],  # 135°
	[157.5, 4, true, false],  # 157.5°
	[180, 4, true, false],  # 180°
	[202.5, 4, true, false],  # 202.5°
	[225, 5, false, true],  # 225°
	[247.5, 13, false, true],  # 247.5°
	[270, 8, false, false],  # 270°
	[292.5, 13, true, true],  # 292.5°
	[315, 5, true, true],  # 315°
	[337.5, 4, false, false],  # 337.5°
	[348.75, 4, false, false],  # 348.75°
]

## Escala do sprite e da sombra: o navio fica 8% maior.
const SPRITE_SCALE: float = 1.08

## Histerese da troca de frame, em graus: só troca depois de passar da fronteira
## por este valor. Evita piscar quando o rumo fica parado perto dela.
const FRAME_HYSTERESIS_DEG: float = 3.0

## Zona morta do leme, em radianos (~1°): abaixo disso a proa para de girar.
const STEER_DEADBAND: float = 0.02

## Passo angular de cada direção, em graus.
const DIR_STEP_DEG: float = 22.5

## Número de direções discretas do navio.
const DIRECTIONS: int = 16


## Quão rápido a vista acompanha o rumo real, em 1/s. Um valor menor deixa a
## virada mais lenta e pesada.
const VISUAL_TURN_RATE: float = 5.0

## Balanço de flutuação: sobe e desce, deriva de lado e balança levemente.
const BOB_AMPLITUDE: float = 1.2
const BOB_PERIOD: float = 2.6
const DRIFT_AMPLITUDE: float = 1.0
const DRIFT_PERIOD: float = 4.1
const SWAY_ANGLE: float = 0.012
const SWAY_PERIOD: float = 3.7

## Abertura da mira em torno da lateral, em radianos (±20°). Fora desse arco, o
## tiro iria para a proa ou a popa, o que é proibido.
const AIM_ARC: float = 0.35

## Distância lateral dos canhões ao centro do casco, em pixels.
const GUN_LATERAL: float = 10.0

## Convés na arte de vista lateral, em coordenadas de tela (não giram com o casco).
## O centro do sprite fica na altura das velas; os tiros saem daqui, e não do mastro.
const DECK_OFFSET: Vector2 = Vector2(0.0, 22.0)

## Linha d'água, em coordenadas de tela: a espuma sai daqui, sob o casco.
const WAKE_OFFSET: Vector2 = Vector2(0.0, 58.0)

## Sombra: deslocamento no mundo e opacidade base.
const SHADOW_OFFSET: Vector2 = Vector2(6.0, 10.0)
const SHADOW_ALPHA: float = 0.3

## Trilhos de mira, no estilo de combate naval: faixas paralelas translúcidas
## saindo perpendiculares à lateral ativa.
const RAIL_COLOR: Color = Color(1.0, 0.45, 0.15, 0.35)
const RAIL_FAINT_COLOR: Color = Color(1.0, 0.45, 0.15, 0.12)
const RAIL_HALF_WIDTH: float = 3.0

## Atributos do navio.
@export var data: ShipData

## Área útil do mar. O navio não sai dela.
@export var world_bounds: Rect2 = Rect2(-4000.0, -4000.0, 8000.0, 8000.0)

## Se verdadeiro, lê o mouse e o teclado. NPCs deixam falso.
@export var player_controlled: bool = false

## Vento e maré, em pixels por segundo. Definido pelo mapa.
@export var ambient_flow: Vector2 = Vector2.ZERO

@onready var _shadow: Sprite2D = $Shadow
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _wake: GPUParticles2D = $Wake
@onready var _smoke_port: GPUParticles2D = $SmokePort
@onready var _smoke_starboard: GPUParticles2D = $SmokeStarboard
@onready var _port_cannons: Node2D = $PortCannons
@onready var _starboard_cannons: Node2D = $StarboardCannons

## Nível atual das velas.
var sail: Sail = Sail.STOPPED

## Velocidade escalar para frente, em pixels por segundo. Negativa em ré.
var speed: float = 0.0

## Velocidade de giro atual, em radianos por segundo.
var angular_velocity: float = 0.0

## Impulso de recuo atual, em pixels por segundo.
var knockback: Vector2 = Vector2.ZERO

## Índice da direção mostrada agora, de 0 a 15.
var direction: int = 0

## Estado de cada bateria, indexado por SIDE_PORT e SIDE_STARBOARD.
var _charging: Dictionary = {SIDE_PORT: false, SIDE_STARBOARD: false}
var _power: Dictionary = {SIDE_PORT: 0.0, SIDE_STARBOARD: 0.0}
var _awaiting_release: Dictionary = {SIDE_PORT: false, SIDE_STARBOARD: false}
var _cooldown: Dictionary = {SIDE_PORT: 0.0, SIDE_STARBOARD: 0.0}

var _was_charging: bool = false
var _shake: float = 0.0
var _camera: Camera2D = null
var _puff: GradientTexture2D

## Rumo mostrado na tela: segue o rumo real com atraso, então a virada parece pesada.
var _visual_heading: float = 0.0
## Índice em `DIR_ENTRIES` da direção mostrada.
var _shown_index: int = -1
var _time: float = 0.0


func _ready() -> void:
	if data == null:
		data = ShipData.new()
	for node in [_sprite, _shadow]:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# O sprite fica atrás do desenho do próprio navio (trilhos de mira).
	_sprite.show_behind_parent = true
	_camera = get_node_or_null("Camera2D") as Camera2D
	_visual_heading = rotation
	_puff = _make_puff_texture()
	_shadow.modulate = Color(0.0, 0.0, 0.0, SHADOW_ALPHA)
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	_shadow.scale = Vector2.ONE * SPRITE_SCALE
	_show_direction(_nearest_entry(rad_to_deg(rotation), -1))
	_setup_wake()
	_setup_smoke(_smoke_port, SIDE_PORT)
	_setup_smoke(_smoke_starboard, SIDE_STARBOARD)


func _physics_process(delta: float) -> void:
	_update_steering(delta)
	_update_speed(delta)
	knockback = knockback.move_toward(Vector2.ZERO, data.recoil_damping * delta)
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	position += knockback * delta
	position += ambient_flow * data.wind_influence * delta
	_clamp_to_world()


func _process(delta: float) -> void:
	_update_visual(delta)
	_update_wake()
	_update_charge(delta)
	_update_cooldown(delta)
	_update_shake(delta)
	# Redesenha durante a carga e também no quadro em que ela termina, para apagar os trilhos.
	var charging: bool = _any_charging()
	if charging or _was_charging:
		queue_redraw()
	_was_charging = charging


func _draw() -> void:
	for side in [SIDE_PORT, SIDE_STARBOARD]:
		if _charging[side]:
			_draw_rails(side, _power[side])


func _unhandled_input(event: InputEvent) -> void:
	if not player_controlled:
		return

	if event.is_action_pressed("sail_up"):
		sail = clampi(sail + 1, Sail.REVERSE, Sail.FULL) as Sail
	elif event.is_action_pressed("sail_down"):
		sail = clampi(sail - 1, Sail.REVERSE, Sail.FULL) as Sail

	for skill_index in range(1, 5):
		if event.is_action_pressed("skill_%d" % skill_index):
			skill_triggered.emit(skill_index)

	if event.is_action_pressed("broadside_port"):
		_press_charge(SIDE_PORT)
	elif event.is_action_released("broadside_port"):
		_release_charge(SIDE_PORT)
	elif event.is_action_pressed("broadside_starboard"):
		_press_charge(SIDE_STARBOARD)
	elif event.is_action_released("broadside_starboard"):
		_release_charge(SIDE_STARBOARD)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_charge(event.pressed, SIDE_PORT)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_charge(event.pressed, SIDE_STARBOARD)


## Direção da mira: do navio até o ponteiro, normalizada.
## Retorna vetor zero sem jogador ou quando o ponteiro está dentro da zona morta.
func get_aim_vector() -> Vector2:
	if not player_controlled:
		return Vector2.ZERO
	var to_pointer: Vector2 = get_global_mouse_position() - global_position
	if to_pointer.length() < data.aim_deadzone:
		return Vector2.ZERO
	return to_pointer.normalized()


## Se o bordo está em mira, carregando a força.
func is_charging(side: int) -> bool:
	return _charging[side]


## Força atual da carga do bordo, de 0.0 a 1.0.
func charge_power(side: int) -> float:
	return _power[side]


## Segundos restantes até a bateria do bordo poder disparar de novo.
func cooldown_left(side: int) -> float:
	return _cooldown[side]


## Dispara uma bordada pelo bordo escolhido, com força de 0.0 a 1.0.
## Cria `cannon_count` projéteis em sequência, saindo dos canhões do bordo.
## Não dispara se a bateria ainda está em cooldown.
func fire_broadside(power: float, side: int) -> void:
	if _cooldown[side] > 0.0:
		return
	power = clampf(power, 0.0, 1.0)
	var limits: Vector2 = _sector_limits(side)
	var aim: float = _aim_local(side)
	var half_spread: float = lerpf(data.spread_min, data.spread_max, power)
	var shot_speed: float = lerpf(data.projectile_speed_min, data.projectile_speed_max, power)
	var guns: Array = _guns(side)

	for i in range(data.cannon_count):
		var local_angle: float = clampf(aim + randf_range(-half_spread, half_spread), limits.x, limits.y)
		var velocity: Vector2 = Vector2.from_angle(rotation + local_angle) * shot_speed
		# Os canhões se revezam ao longo do casco.
		var gun_index: int = i % guns.size()
		get_tree().create_timer(i * data.volley_interval).timeout.connect(
			_spawn_cannonball.bind(side, gun_index, velocity)
		)

	# O recuo é perpendicular ao casco, no sentido oposto ao bordo que atirou.
	var barrel: Vector2 = Vector2(0.0, side).rotated(rotation)
	knockback += -barrel * data.recoil_strength * power
	_shake = maxf(_shake, power * data.shake_strength)
	_cooldown[side] = data.broadside_cooldown
	_puff_smoke(side)

	primary_action_triggered.emit(get_global_mouse_position())
	broadside_fired.emit(side, power)


## Segurar entra em mira e começa a carregar. Não dispara.
func _press_charge(side: int) -> void:
	if _charging[side] or _awaiting_release[side] or _cooldown[side] > 0.0:
		return
	_charging[side] = true
	_power[side] = 0.0


## Soltar dispara o bordo com a força acumulada, e só ele.
func _release_charge(side: int) -> void:
	if _charging[side]:
		fire_broadside(maxf(_power[side], TAP_MIN_POWER), side)
		_charging[side] = false
		_power[side] = 0.0
	_awaiting_release[side] = false


func _mouse_charge(pressed: bool, side: int) -> void:
	if pressed:
		_press_charge(side)
	else:
		_release_charge(side)


func _any_charging() -> bool:
	return _charging[SIDE_PORT] or _charging[SIDE_STARBOARD]


## Verdadeiro enquanto há carga ou um disparo automático aguardando soltar.
func _any_holding() -> bool:
	return _any_charging() or _awaiting_release[SIDE_PORT] or _awaiting_release[SIDE_STARBOARD]


## Lateral da direção mostrada, no referencial do casco. A mira usa o ângulo da
## vista (índice × 22.5°), para ficar alinhada ao desenho e não ao rumo contínuo.
func _aim_local(side: int) -> float:
	var shown: float = deg_to_rad(float(DIR_ENTRIES[_shown_index][0]))
	return shown + _normal_local(side) - rotation


## Lateral da direção mostrada, no referencial do casco.: bombordo aponta para -Y, estibordo para +Y.
func _normal_local(side: int) -> float:
	return -PI / 2.0 if side == SIDE_PORT else PI / 2.0


## Limites do ângulo de tiro (em relação à proa): só ±20° em torno da lateral do bordo.
func _sector_limits(side: int) -> Vector2:
	var normal: float = -PI / 2.0 if side == SIDE_PORT else PI / 2.0
	return Vector2(normal - AIM_ARC, normal + AIM_ARC)


func _guns(side: int) -> Array:
	return _port_cannons.get_children() if side == SIDE_PORT else _starboard_cannons.get_children()


## Trilhos paralelos perpendiculares ao bordo, um por canhão. Crescem com a carga.
## O trilho de alcance máximo fica como referência discreta.
func _draw_rails(side: int, power: float) -> void:
	var dir: Vector2 = Vector2.from_angle(_aim_local(side))
	var length: float = lerpf(data.range_min, data.range_max, power)
	var deck: Vector2 = DECK_OFFSET.rotated(-rotation)
	for gun in _guns(side):
		var start: Vector2 = (gun as Node2D).position + deck
		_draw_rail(start, start + dir * data.range_max, RAIL_FAINT_COLOR, dir)
		_draw_rail(start, start + dir * length, RAIL_COLOR, dir)


func _draw_rail(from: Vector2, to: Vector2, color: Color, dir: Vector2) -> void:
	var w: Vector2 = dir.orthogonal().normalized() * RAIL_HALF_WIDTH
	var points: PackedVector2Array = PackedVector2Array([from - w, from + w, to + w, to - w])
	draw_colored_polygon(points, color)


func _spawn_cannonball(side: int, gun_index: int, velocity: Vector2) -> void:
	var gun: Node2D = _guns(side)[gun_index] as Node2D
	var ball := Cannonball.new()
	ball.velocity = velocity
	ball.lifetime = data.projectile_lifetime
	get_parent().add_child(ball)
	# Atrás do navio: na arte de lado, um tiro para bombordo sobe pelas velas e
	# deve passar por trás delas, não por cima.
	get_parent().move_child(ball, get_index())
	ball.global_position = global_position + DECK_OFFSET + gun.position.rotated(rotation)


func _update_steering(delta: float) -> void:
	var steer: float = 0.0
	# Com um tiro carregado, o leme trava: a proa não pode mudar o semiplano do bordo.
	var aim: Vector2 = Vector2.ZERO if _any_holding() else get_aim_vector()
	if aim != Vector2.ZERO:
		var error: float = angle_difference(rotation, aim.angle())
		if absf(error) > STEER_DEADBAND:
			steer = clampf(error * data.aim_responsiveness, -1.0, 1.0)

	angular_velocity = move_toward(angular_velocity, steer * data.turn_speed, data.turn_acceleration * delta)
	rotation += angular_velocity * delta


func _update_speed(delta: float) -> void:
	var target: float = _target_speed()
	# Acelera quando o alvo está mais longe de zero que a velocidade atual;
	# caso contrário, solta devagar (inércia).
	var rate: float = data.acceleration if absf(target) > absf(speed) else data.deceleration
	speed = move_toward(speed, target, rate * delta)


func _target_speed() -> float:
	var factor: float = data.effective_max_factor()
	match sail:
		Sail.REVERSE:
			return -data.reverse_speed * factor
		Sail.HALF:
			return data.half_speed * factor
		Sail.FULL:
			return data.max_speed * factor
		_:
			return 0.0


## Uma direção por vez, de 16, sem mudança de opacidade. A direção só troca
## quando o rumo passa da fronteira com folga (histerese), para não piscar.
func _update_visual(delta: float) -> void:
	_time += delta
	var deg: float = rad_to_deg(global_rotation)
	_show_direction(_nearest_entry(deg, _shown_index))
	_apply_float()


## Entrada de `DIR_ENTRIES` mais próxima do rumo, em graus. Se `current` já é uma
## entrada vizinha dentro da histerese, mantém a atual.
func _nearest_entry(deg: float, current: int) -> int:
	var best: int = 0
	var best_dist: float = INF
	for k in range(DIR_ENTRIES.size()):
		var d: float = _circ_dist(deg, DIR_ENTRIES[k][0])
		if d < best_dist:
			best_dist = d
			best = k
	if current >= 0 and current != best:
		var cur_dist: float = _circ_dist(deg, DIR_ENTRIES[current][0])
		if cur_dist <= best_dist + FRAME_HYSTERESIS_DEG:
			return current
	return best


func _circ_dist(a: float, b: float) -> float:
	return absf(wrapf(a - b, -180.0, 180.0))


## Mostra a direção: um único sprite, opaco. Nas vistas de cima
## a sombra some, porque o casco já cobre a água.
func _show_direction(index: int) -> void:
	_shown_index = index
	var entry: Array = DIR_ENTRIES[index]
	var frame: int = entry[1]
	var tex: Texture2D = DIR16_TEXTURES[frame]
	_sprite.texture = tex
	_sprite.flip_h = entry[2]
	_sprite.flip_v = entry[3]
	_sprite.modulate.a = 1.0
	# Vistas de cima (frames ímpares) não levam sombra deslocada.
	var top_view: bool = frame % 2 == 1
	_shadow.texture = null if top_view else tex
	_shadow.flip_h = entry[2]
	_shadow.flip_v = entry[3]


## Balanço de flutuação: o navio sobe e desce, deriva de lado e balança. Mais
## velocidade, mais balanço. A sombra fica no mesmo lugar e se afasta quando o
## navio sobe.
func _apply_float() -> void:
	var fraction: float = clampf(absf(speed) / maxf(data.max_speed, 1.0), 0.0, 1.0)
	var amp: float = 1.0 + 0.5 * fraction
	var bob: float = sin(_time * TAU / BOB_PERIOD) * BOB_AMPLITUDE * amp
	var drift: float = sin(_time * TAU / DRIFT_PERIOD) * DRIFT_AMPLITUDE * amp
	var sway: float = sin(_time * TAU / SWAY_PERIOD) * SWAY_ANGLE * amp

	# O sprite é filho do nó, que gira com o rumo. Ele é contra-rotacionado para
	# mostrar o frame da direção como está; a orientação já está no frame.
	_sprite.position = Vector2(drift, bob).rotated(-rotation)
	_sprite.rotation = -rotation + sway

	_shadow.position = (SHADOW_OFFSET + Vector2(0.0, -bob * 0.8)).rotated(-rotation)
	_shadow.rotation = -rotation


## Mantém o navio dentro da área útil do mar. Ao bater na borda, para.
func _clamp_to_world() -> void:
	if world_bounds.has_point(position):
		return
	position = Vector2(
		clampf(position.x, world_bounds.position.x, world_bounds.end.x),
		clampf(position.y, world_bounds.position.y, world_bounds.end.y)
	)
	speed = 0.0
	knockback = Vector2.ZERO


func _update_charge(delta: float) -> void:
	for side in [SIDE_PORT, SIDE_STARBOARD]:
		if not _charging[side]:
			continue
		_power[side] = minf(1.0, _power[side] + delta / data.charge_time)
		if _power[side] >= 1.0:
			# Carga cheia: dispara sozinho e espera o botão ser solto para armar de novo.
			fire_broadside(1.0, side)
			_charging[side] = false
			_power[side] = 0.0
			_awaiting_release[side] = true


func _update_cooldown(delta: float) -> void:
	for side in [SIDE_PORT, SIDE_STARBOARD]:
		_cooldown[side] = maxf(0.0, _cooldown[side] - delta)


func _update_shake(delta: float) -> void:
	if _camera == null:
		return
	if _shake <= 0.0:
		_camera.offset = Vector2.ZERO
		return
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	_shake = move_toward(_shake, 0.0, data.shake_decay * delta)


func _setup_wake() -> void:
	# Espuma sob a área do casco, na linha d'água: partículas macias, espalhadas
	# pela largura e pelo comprimento do casco, que se dissipam sem formar fio.
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Metade de popa do casco: a espuma nasce atrás e é levada para trás.
	material.emission_box_extents = Vector3(data.hull_half_length * 0.5, 9.0, 0.0)
	material.spread = 60.0
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 3.0
	material.damping_min = 16.0
	material.damping_max = 24.0
	material.scale_min = 0.25
	material.scale_max = 0.5
	material.color = Color(0.9, 0.98, 1.0, 0.4)
	_wake.process_material = material
	_wake.texture = _puff
	# No referencial do casco: a popa e a deriva seguem a proa, em qualquer rumo.
	_wake.local_coords = true
	_wake.amount = 40
	_wake.lifetime = 1.2
	_wake.emitting = false


## A espuma acompanha a área do casco. Com mais velocidade, ela fica mais forte
## e se espalha mais para trás, do lado oposto ao movimento.
func _update_wake() -> void:
	var stern_sign: float = -1.0 if speed >= 0.0 else 1.0
	var fraction: float = clampf(absf(speed) / maxf(data.max_speed, 1.0), 0.0, 1.0)
	var material := _wake.process_material as ParticleProcessMaterial
	material.direction = Vector3(stern_sign, 0.0, 0.0)
	_wake.position = WAKE_OFFSET.rotated(-rotation) + Vector2(stern_sign * data.hull_half_length * 0.8, 0.0)
	# A fumaça sai das portinholas, na linha do casco, e não do centro do sprite.
	_smoke_port.position = (WAKE_OFFSET + Vector2(0.0, -4.0)).rotated(-rotation)
	_smoke_starboard.position = (WAKE_OFFSET + Vector2(0.0, 4.0)).rotated(-rotation)
	material.initial_velocity_min = lerpf(0.5, 4.0, fraction)
	material.initial_velocity_max = lerpf(3.0, 9.0, fraction)
	_wake.modulate.a = fraction * 0.9
	_wake.emitting = fraction > 0.05


func _setup_smoke(node: GPUParticles2D, side: int) -> void:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(data.hull_half_length * 0.6, 3.0, 0.0)
	material.direction = Vector3(0.0, side, 0.0)
	material.spread = 22.0
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = 14.0
	material.initial_velocity_max = 30.0
	material.damping_min = 18.0
	material.damping_max = 30.0
	material.scale_min = 0.6
	material.scale_max = 1.3
	material.color = Color(0.62, 0.63, 0.66, 0.45)
	node.process_material = material
	node.texture = _puff
	node.position = Vector2(0.0, side * GUN_LATERAL)
	node.local_coords = false
	node.one_shot = true
	node.explosiveness = 0.9
	node.amount = 10
	node.lifetime = 1.6
	node.emitting = false


## Fumaça de pólvora: uma baforada no bordo que atirou.
func _puff_smoke(side: int) -> void:
	var node: GPUParticles2D = _smoke_port if side == SIDE_PORT else _smoke_starboard
	node.restart()
	node.emitting = true


## Mancha redonda e macia usada como partícula de fumaça.
func _make_puff_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture
