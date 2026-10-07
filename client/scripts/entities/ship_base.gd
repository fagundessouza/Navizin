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

## Os 8 frames do navio, de `dir8/dir8_NN.png`. Frame 0 é Sul (frente), 1 Sudeste,
## 2 Leste, 3 Nordeste, 4 Norte (trás), 5 Noroeste, 6 Oeste, 7 Sudoeste.
const FRAME_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/ships/holandes_voador/dir8/dir8_00.png"),
	preload("res://assets/sprites/ships/holandes_voador/dir8/dir8_01.png"),
	preload("res://assets/sprites/ships/holandes_voador/dir8/dir8_02.png"),
	preload("res://assets/sprites/ships/holandes_voador/dir8/dir8_03.png"),
	preload("res://assets/sprites/ships/holandes_voador/dir8/dir8_04.png"),
	preload("res://assets/sprites/ships/holandes_voador/dir8/dir8_05.png"),
	preload("res://assets/sprites/ships/holandes_voador/dir8/dir8_06.png"),
	preload("res://assets/sprites/ships/holandes_voador/dir8/dir8_07.png"),
]

## Rumo em graus (convenção do jogo, y para baixo) de cada frame: Sul = 90, Leste = 0,
## Norte = -90, Oeste = 180.
const FRAME_HEADING_DEG: Array[float] = [90.0, 45.0, 0.0, -45.0, -90.0, -135.0, 180.0, 135.0]

## Escala do sprite e da sombra. Os frames novos são maiores que os antigos.
## Escala do sprite e da sombra: 15% acima da escala anterior (0.23 × 1.15).
const SPRITE_SCALE: float = 0.62

## Fator de tamanho do navio em relação à escala antiga: canhões, esteira, sombra e
## popa são escalados por ele para acompanhar o casco.
const SIZE_FACTOR: float = 2.34

## Histerese da troca de frame, em graus: só troca depois de passar da fronteira
## por este valor. Evita piscar quando o rumo fica parado perto dela.
const FRAME_HYSTERESIS_DEG: float = 10.0

## Zona morta do leme, em radianos (~1°): abaixo disso a proa para de girar.
const STEER_DEADBAND: float = 0.02


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

## Imperfeição do canhão: desvio angular e variação de velocidade por bala.
const CANNON_SCATTER: float = 0.05
const SHOT_SPEED_JITTER: float = 0.05

## Recuo visual do sprite ao disparar, em pixels.
const KICK_PX: float = 3.0
const KICK_RECOVERY: float = 18.0

## Vento: intensidade de referência, bônus a favor e penalidade contra.
const WIND_DRIFT_PX: float = 14.0
const WIND_BONUS: float = 0.35
const WIND_PENALTY: float = 0.50

## Distância lateral dos canhões ao centro do casco, em pixels.
const GUN_LATERAL: float = 23.0

## Convés na arte de vista lateral, em coordenadas de tela (não giram com o casco).
## O centro do sprite fica na altura das velas; os tiros saem daqui, e não do mastro.
const DECK_OFFSET: Vector2 = Vector2(0.0, 51.0)

## Linha d'água, em coordenadas de tela: a espuma sai daqui, sob o casco.
const WAKE_OFFSET: Vector2 = Vector2(0.0, 136.0)
## Distância da popa ao ponto de emissão, em pixels de tela.
const STERN_REACH: float = 94.0
## Ajuste vertical da popa por frame: frames com a proa para baixo descem o ponto
## de emissão até a borda inferior da popa; frames com a proa para cima sobem um pouco
## para colar na base traseira.
const STERN_DOWN_Y: float = -47.0
const STERN_UP_Y: float = 23.0

## Sombra: deslocamento no mundo e opacidade base.
const SHADOW_OFFSET: Vector2 = Vector2(14.0, 23.0)
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


@onready var _shadow: Sprite2D = $Shadow
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _wake: GPUParticles2D = $WaterTrailFX
@onready var _lantern: PointLight2D = $LanternGlow
@onready var _chimney: GPUParticles2D = $ChimneySmoke
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
var _kick: Vector2 = Vector2.ZERO
## Squash & stretch: -1 desacelerando forte, +1 acelerando forte. Suavizado.
var _squash: float = 0.0
## Vento global (autoload `WindManager`), obtido no _ready.
var _wind: Node = null
var _prev_speed: float = 0.0
## Offsets da popa por entrada de `DIR_ENTRIES`: base (tela) e vetor de ré.
var _stern_base: Array[Vector2] = []
var _stern_back: Array[Vector2] = []
var _shake: float = 0.0
var _camera: Camera2D = null
var _puff: GradientTexture2D

## Rumo mostrado na tela: segue o rumo real com atraso, então a virada parece pesada.
var _visual_heading: float = 0.0
## Índice em `DIR_ENTRIES` da direção mostrada.
var _shown_index: int = -1
var _time: float = 0.0


func _ready() -> void:
	_wind = get_node("/root/WindManager")
	if data == null:
		data = ShipData.new()
	for node in [_sprite, _shadow]:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# O sprite fica atrás do desenho do próprio navio (trilhos de mira).
	_sprite.show_behind_parent = true
	_camera = get_node_or_null("Camera2D") as Camera2D
	_build_stern_table()
	_visual_heading = rotation
	_puff = _make_puff_texture()
	_shadow.modulate = Color(0.0, 0.0, 0.0, SHADOW_ALPHA)
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	_shadow.scale = Vector2.ONE * SPRITE_SCALE
	_show_frame(_nearest_frame(rad_to_deg(rotation), -1))
	_setup_wake()
	_setup_lantern()
	_setup_chimney()


func _physics_process(delta: float) -> void:
	_update_steering(delta)
	fx_on_turn(angular_velocity / maxf(data.turn_speed, 0.001))
	_update_speed(delta)
	var accel: float = (speed - _prev_speed) / maxf(delta, 0.0001)
	_prev_speed = speed
	_squash = lerpf(_squash, clampf(accel / maxf(data.acceleration, 1.0), -1.0, 1.0), minf(1.0, 8.0 * delta))
	knockback = knockback.move_toward(Vector2.ZERO, data.recoil_damping * delta)
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	position += knockback * delta
	_apply_wind_drift(delta)
	_clamp_to_world()


func _process(delta: float) -> void:
	_update_visual(delta)
	_update_wake()
	_update_fx(delta)
	_update_charge(delta)
	_update_cooldown(delta)
	_update_shake(delta)
	_kick = _kick.move_toward(Vector2.ZERO, KICK_RECOVERY * delta)
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
		var scatter: float = randf_range(-CANNON_SCATTER, CANNON_SCATTER)
		var local_angle: float = clampf(aim + randf_range(-half_spread, half_spread) + scatter, limits.x, limits.y)
		var jitter: float = 1.0 + randf_range(-SHOT_SPEED_JITTER, SHOT_SPEED_JITTER)
		var velocity: Vector2 = Vector2.from_angle(rotation + local_angle) * shot_speed * jitter
		# Os canhões se revezam ao longo do casco.
		var gun_index: int = i % guns.size()
		get_tree().create_timer(i * data.volley_interval).timeout.connect(
			_spawn_cannonball.bind(side, gun_index, velocity)
		)

	# O recuo é perpendicular ao casco, no sentido oposto ao bordo que atirou.
	var barrel: Vector2 = Vector2(0.0, side).rotated(rotation)
	knockback += -barrel * data.recoil_strength * power
	_shake = maxf(_shake, power * data.shake_strength)
	_kick += -barrel * KICK_PX * power
	fx_on_fire(power)
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
	var shown: float = deg_to_rad(FRAME_HEADING_DEG[_shown_index])
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
	var wind: float = _wind_factor()
	var target: float = _target_speed() * wind
	if absf(target) > absf(speed):
		speed = move_toward(speed, target, data.acceleration * wind * delta)
	elif target == 0.0:
		# Sem comando: o atrito da água freia em proporção à velocidade, com inércia.
		var drag: float = data.deceleration * 0.4 + data.water_drag * absf(speed)
		speed = move_toward(speed, 0.0, drag * delta)
	else:
		speed = move_toward(speed, target, data.deceleration * delta)


## Fator de vento sobre a velocidade, pelo produto escalar entre a proa e o vento
## global. A favor: até +40%. Contra: até -50%, com a força do vento.
func _wind_factor() -> float:
	var along: float = _wind_along()
	var strength: float = _wind.wind_strength
	if along >= 0.0:
		return 1.0 + WIND_BONUS * along * strength
	return maxf(0.5, 1.0 + WIND_PENALTY * along * strength)


## Produto escalar entre a proa e a direção do vento: +1 a favor, -1 contra.
func _wind_along() -> float:
	return Vector2.RIGHT.rotated(rotation).dot(_wind.wind_direction)


## Vento contra: a componente lateral empurra o casco para o lado, obrigando a
## navegar em zig-zag. Quanto mais forte o vento de frente, maior a deriva.
func _apply_wind_drift(delta: float) -> void:
	var forward: Vector2 = Vector2.RIGHT.rotated(rotation)
	var along: float = _wind_along()
	if along < 0.0:
		var lateral: Vector2 = _wind.wind_direction - forward * along
		position += lateral * WIND_DRIFT_PX * _wind.wind_strength * (-along) * delta


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
	_show_frame(_nearest_frame(deg, _shown_index))
	_apply_float()


## Frame mais próximo do rumo, em graus. Se `current` está dentro da histerese,
## mantém o atual.
func _nearest_frame(deg: float, current: int) -> int:
	var best: int = 0
	var best_dist: float = INF
	for k in range(FRAME_HEADING_DEG.size()):
		var d: float = _circ_dist(deg, FRAME_HEADING_DEG[k])
		if d < best_dist:
			best_dist = d
			best = k
	if current >= 0 and current != best:
		var cur_dist: float = _circ_dist(deg, FRAME_HEADING_DEG[current])
		if cur_dist <= best_dist + FRAME_HYSTERESIS_DEG:
			return current
	return best


func _circ_dist(a: float, b: float) -> float:
	return absf(wrapf(a - b, -180.0, 180.0))


## Mostra o frame: um único sprite, opaco, sem espelhamento. A sombra segue o mesmo frame.
func _show_frame(index: int) -> void:
	_shown_index = index
	var tex: Texture2D = FRAME_TEXTURES[index]
	_sprite.texture = tex
	_sprite.modulate.a = 1.0
	_shadow.texture = tex


## Balanço de flutuação: o navio sobe e desce, deriva de lado e balança. Mais
## velocidade, mais balanço. A sombra fica no mesmo lugar e se afasta quando o
## navio sobe.
func _apply_float() -> void:
	var fraction: float = clampf(absf(speed) / maxf(data.max_speed, 1.0), 0.0, 1.0)
	var amp: float = 1.0 + 0.5 * fraction
	# Flutuação sobre as ondas: relógio do sistema, como pedido.
	var tick: float = sin(Time.get_ticks_msec() * 0.002)
	var bob: float = tick * BOB_AMPLITUDE * amp
	var drift: float = sin(_time * TAU / DRIFT_PERIOD) * DRIFT_AMPLITUDE * amp
	var sway: float = tick * SWAY_ANGLE * amp

	# O sprite é filho do nó, que gira com o rumo. Ele é contra-rotacionado para
	# mostrar o frame da direção como está; a orientação já está no frame.
	# Squash & stretch: comprime no impulso e estica quando ganha velocidade de cruzeiro.
	var squash: Vector2 = Vector2(1.0 - 0.03 * _squash, 1.0 + 0.03 * _squash)
	_sprite.scale = Vector2.ONE * SPRITE_SCALE * squash
	_sprite.position = (Vector2(drift, bob) + _kick).rotated(-rotation)
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
	# Espuma orgânica: partículas circulares, com giro aleatório, que crescem um
	# pouco e somem suavemente. Vida varia de 0.6 a 1.6 s.
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.15))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	var active_mat := ParticleProcessMaterial.new()
	active_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	active_mat.emission_box_extents = Vector3(data.hull_half_length * 0.35, 6.0, 0.0)
	active_mat.spread = 60.0
	active_mat.gravity = Vector3.ZERO
	active_mat.initial_velocity_min = 0.5
	active_mat.initial_velocity_max = 3.0
	active_mat.damping_min = 16.0
	active_mat.damping_max = 24.0
	active_mat.angle_min = 0.0
	active_mat.angle_max = 360.0
	active_mat.angular_velocity_min = -90.0
	active_mat.angular_velocity_max = 90.0
	active_mat.scale_min = 0.5
	active_mat.scale_max = 1.2
	active_mat.scale_curve = scale_tex
	active_mat.color = Color(0.9, 0.98, 1.0, 0.5)
	active_mat.color_ramp = fade_tex
	active_mat.lifetime_randomness = 0.45
	_wake.process_material = active_mat
	_wake.texture = _puff
	# Névoa suave: filtro linear, senão o Nearest do projeto a quebra em blocos.
	_wake.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# No referencial do casco: a popa e a deriva seguem a proa, em qualquer rumo.
	# No mundo: a espuma fica onde foi solta e se dissolve aos poucos.
	_wake.local_coords = false
	# Atrás do casco: a espuma fica abaixo do sprite do navio.
	_wake.show_behind_parent = true
	_wake.amount = 40
	_wake.lifetime = 1.1
	_wake.emitting = false


## Monta os offsets da popa para cada entrada de `DIR_ENTRIES`. A ré é o sentido
## oposto à proa, na tela. Nas vistas laterais (proa para a direita ou esquerda) o
## resultado é o mesmo offset de antes.
func _build_stern_table() -> void:
	_stern_base.clear()
	_stern_back.clear()
	for heading in FRAME_HEADING_DEG:
		var angle: float = deg_to_rad(heading)
		var bow_down: float = sin(angle)
		var base: Vector2 = WAKE_OFFSET
		if bow_down > 0.5:
			base.y += STERN_DOWN_Y
		elif bow_down < -0.5:
			base.y += STERN_UP_Y
		_stern_base.append(base)
		_stern_back.append(Vector2.from_angle(angle + PI) * STERN_REACH)


## A espuma sai da popa, na linha d'água. Usa o offset da direção mostrada, e a
## deriva segue a ré do frame. A quantidade acompanha a velocidade: parado, não emite.
func _update_wake() -> void:
	var reversing: bool = speed < 0.0
	var fraction: float = clampf(absf(speed) / maxf(data.max_speed, 1.0), 0.0, 1.0)
	var back: Vector2 = _stern_back[_shown_index]
	var base: Vector2 = _stern_base[_shown_index]
	if reversing:
		back = -back
	# Frames são desenhados na tela, então a ré e a emissão são em coordenadas do mundo.
	var active_mat := _wake.process_material as ParticleProcessMaterial
	active_mat.direction = Vector3(back.normalized().x, back.normalized().y, 0.0)
	active_mat.initial_velocity_min = lerpf(0.5, 4.0, fraction)
	active_mat.initial_velocity_max = lerpf(3.0, 9.0, fraction)
	_wake.global_position = global_position + base + back
	_wake.amount_ratio = fraction
	_wake.emitting = fraction > 0.02


## Luz quente das lanternas: energia oscila de forma orgânica, sem repetição exata.
func _setup_lantern() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_lantern.texture = tex
	_lantern.texture_scale = 1.4
	_lantern.blend_mode = Light2D.BLEND_MODE_ADD


## Fumaça da chaminé: sobe devagar, abre e some, levada pelo vento do mapa.
func _setup_chimney() -> void:
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.85, 0.85, 0.35))
	fade.set_color(1, Color(0.85, 0.85, 0.85, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	var active_mat := ParticleProcessMaterial.new()
	active_mat.direction = Vector3(0.0, -1.0, 0.0)
	active_mat.spread = 12.0
	active_mat.gravity = Vector3(0.0, -10.0, 0.0)
	active_mat.initial_velocity_min = 6.0
	active_mat.initial_velocity_max = 12.0
	active_mat.damping_min = 4.0
	active_mat.damping_max = 8.0
	active_mat.scale_min = 0.8
	active_mat.scale_max = 1.2
	active_mat.scale_curve = grow_tex
	active_mat.color_ramp = fade_tex
	active_mat.lifetime_randomness = 0.3
	_chimney.process_material = active_mat
	_chimney.texture = _puff
	_chimney.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_chimney.local_coords = false
	_chimney.amount = 12
	_chimney.lifetime = 2.2
	_chimney.emitting = true


## Módulo de efeitos: o navio informa as ações (acelerar, virar, atirar) e cada efeito
## reage com os parâmetros de `FX_TUNING`. Sem ação, cada efeito volta ao repouso.
const FX_TUNING: Dictionary = {
	"lantern_base_energy": 0.8,
	"lantern_wave": 0.12,
	"wake_turn_boost": 0.5,
	"smoke_wind": 6.0,
	"fire_kick_glow": 0.6,
}
var _fx_turn: float = 0.0
var _fx_fire: float = 0.0


## Ações do jogador que alimentam os efeitos. Chamadas pelo próprio navio.
func fx_on_turn(amount: float) -> void:
	_fx_turn = clampf(absf(amount), 0.0, 1.0)


func fx_on_fire(power: float) -> void:
	_fx_fire = maxf(_fx_fire, power)


## Atualiza os efeitos a cada quadro, a partir do estado atual do navio.
func _update_fx(delta: float) -> void:
	var fraction: float = clampf(absf(speed) / maxf(data.max_speed, 1.0), 0.0, 1.0)
	var wave: float = sin(_time * 3.1) * 0.6 + sin(_time * 7.3) * 0.4
	_lantern.energy = FX_TUNING["lantern_base_energy"] + FX_TUNING["lantern_wave"] * wave + FX_TUNING["fire_kick_glow"] * _fx_fire
	var smoke_mat := _chimney.process_material as ParticleProcessMaterial
	var wind_vec: Vector2 = _wind.wind_direction * _wind.wind_strength
	smoke_mat.gravity = Vector3(wind_vec.x * FX_TUNING["smoke_wind"] * 0.1, -10.0, 0.0)
	_chimney.amount_ratio = 0.3 + 0.7 * fraction
	_fx_turn = move_toward(_fx_turn, 0.0, delta * 2.0)
	_fx_fire = move_toward(_fx_fire, 0.0, delta * 3.0)
	var wake_mat := _wake.process_material as ParticleProcessMaterial
	wake_mat.initial_velocity_max = lerpf(3.0, 9.0, fraction) * (1.0 + FX_TUNING["wake_turn_boost"] * _fx_turn)


## Clarão e fumaça na saída de cada canhão do bordo que atirou.
func _puff_smoke(side: int) -> void:
	for gun in _guns(side):
		# Na linha do casco, distribuído ao longo do navio, e não na altura das velas.
		_spawn_muzzle(global_position + WAKE_OFFSET + (gun as Node2D).position.x * Vector2.RIGHT.rotated(rotation))


## Baforada rápida de fumaça cinza, que se dissipa e some sozinha.
func _spawn_muzzle(at: Vector2) -> void:
	var burst := GPUParticles2D.new()
	var active_mat := ParticleProcessMaterial.new()
	active_mat.spread = 180.0
	active_mat.gravity = Vector3.ZERO
	active_mat.initial_velocity_min = 8.0
	active_mat.initial_velocity_max = 22.0
	active_mat.damping_min = 40.0
	active_mat.damping_max = 60.0
	active_mat.scale_min = 0.6
	active_mat.scale_max = 1.2
	active_mat.color = Color(0.7, 0.7, 0.72, 0.55)
	burst.process_material = active_mat
	burst.texture = _puff
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 8
	burst.lifetime = 0.6
	burst.local_coords = false
	get_parent().add_child(burst)
	burst.global_position = at
	burst.emitting = true
	get_tree().create_timer(1.2).timeout.connect(burst.queue_free)


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
