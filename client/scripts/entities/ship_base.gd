extends Node2D
## Base de todos os navios (jogador e NPCs).
##
## Concentra a física (velas com inércia, leme suave, recuo, vento e maré), a
## apresentação (vista contínua entre as 7 direções, balanço de flutuação,
## sombra, esteira e fumaça) e o disparo lateral com carga de força.
## Os atributos vêm do recurso `ShipData`.
##
## Controle do jogador:
## - A proa segue o ponteiro do mouse. O leme trava enquanto um tiro carrega.
## - W/S (ou setas) mudam o nível das velas.
## - Bombordo: tecla Q ou botão esquerdo. Estibordo: tecla E ou botão direito.
##   Cada bordo carrega sozinho, então Q e E juntos carregam os dois. Soltar
##   dispara aquele bordo. Um toque rápido já dispara uma bordada leve. A carga
##   cheia dispara sozinha.
## - A mira fica presa ao semiplano do bordo escolhido, entre a proa e a popa.
## - Teclas 1 a 4 emitem `skill_triggered`. Ainda sem efeito.
##
## NPCs deixam `player_controlled` falso e recebem comandos de IA no futuro.

## Nível das velas. O valor é o sentido e a força do impulso.
enum Sail { REVERSE = -1, STOPPED = 0, HALF = 1, FULL = 2 }

## Estado visual. Cada valor usa um sprite de `assets/sprites/ships/holandes_voador/dirs/`.
## TOP (vista de cima, proa para cima) não é escolhido pelo rumo: fica disponível
## para uso manual, como um modo de mapa.
enum Direction { FRONT, BACK, SIDE_LEFT, SIDE_RIGHT, TOP, TOP_LEFT, TOP_RIGHT }

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

const TEX_FRONT: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/front.png")
const TEX_BACK: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/back.png")
const TEX_SIDE_LEFT: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/left.png")
const TEX_SIDE_RIGHT: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/right.png")
const TEX_TOP: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/top.png")
const TEX_TOP_LEFT: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/top_left.png")
const TEX_TOP_RIGHT: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/top_right.png")

## Opacidade nas diagonais do topo, para o convés não ficar coberto pelas velas.
const DIAGONAL_OPACITY: float = 0.5

## Vista de cada múltiplo de 45°, a partir da direita, no sentido horário da tela.
## Cada item é [direção, espelhar]. Espelhar nos dois eixos é girar 180°,
## que reaproveita o sprite diagonal para as duas diagonais de cima.
const SECTORS: Array = [
	[Direction.SIDE_LEFT, false],
	[Direction.TOP_LEFT, false],
	[Direction.FRONT, false],
	[Direction.TOP_RIGHT, false],
	[Direction.SIDE_RIGHT, false],
	[Direction.TOP_LEFT, true],
	[Direction.BACK, false],
	[Direction.TOP_RIGHT, true],
]

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

## Margem junto da proa e da popa, em radianos (~8°). A mira nunca aponta direto
## para a frente ou para trás.
const SECTOR_MARGIN: float = 0.14

## Distância dos canhões ao centro do casco, em pixels.
const GUN_PORT_OFFSET: float = 20.0

## Sombra: deslocamento no mundo e opacidade base.
const SHADOW_OFFSET: Vector2 = Vector2(6.0, 10.0)
const SHADOW_ALPHA: float = 0.3

const ARC_COLOR: Color = Color(1.0, 0.95, 0.7, 1.0)
const ARC_FAINT_COLOR: Color = Color(1.0, 0.95, 0.7, 0.25)
const ARC_DOT_RADIUS: float = 2.2
const ARC_DOT_SPACING: float = 9.0

## Atributos do navio.
@export var data: ShipData

## Se verdadeiro, lê o mouse e o teclado. NPCs deixam falso.
@export var player_controlled: bool = false

## Vento e maré, em pixels por segundo. Definido pelo mapa.
@export var ambient_flow: Vector2 = Vector2.ZERO

@onready var _shadow: Sprite2D = $Shadow
@onready var _shadow_blend: Sprite2D = $ShadowBlend
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _blend: Sprite2D = $SpriteBlend
@onready var _wake: GPUParticles2D = $Wake
@onready var _smoke_port: GPUParticles2D = $SmokePort
@onready var _smoke_starboard: GPUParticles2D = $SmokeStarboard

## Nível atual das velas.
var sail: Sail = Sail.STOPPED

## Velocidade escalar para frente, em pixels por segundo. Negativa em ré.
var speed: float = 0.0

## Velocidade de giro atual, em radianos por segundo.
var angular_velocity: float = 0.0

## Impulso de recuo atual, em pixels por segundo.
var knockback: Vector2 = Vector2.ZERO

## Estado visual atual: a vista dominante no momento.
var direction: Direction = Direction.SIDE_LEFT

## Carga de cada bordo, indexada por SIDE_PORT e SIDE_STARBOARD.
var _charging: Dictionary = {SIDE_PORT: false, SIDE_STARBOARD: false}
var _power: Dictionary = {SIDE_PORT: 0.0, SIDE_STARBOARD: 0.0}
var _awaiting_release: Dictionary = {SIDE_PORT: false, SIDE_STARBOARD: false}

var _shake: float = 0.0
var _camera: Camera2D = null
var _puff: GradientTexture2D

## Rumo mostrado na tela: segue o rumo real com atraso, então a virada parece pesada.
var _visual_heading: float = 0.0
var _sector: int = -1
var _entry_a: Array = []
var _entry_b: Array = []
var _time: float = 0.0


func _ready() -> void:
	if data == null:
		data = ShipData.new()
	for node in [_sprite, _blend, _shadow, _shadow_blend]:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow_blend.modulate = Color(0.0, 0.0, 0.0, 0.0)
	# Os sprites ficam atrás do desenho do próprio navio (arco de mira).
	_sprite.show_behind_parent = true
	_blend.show_behind_parent = true
	_camera = get_node_or_null("Camera2D") as Camera2D
	_visual_heading = rotation
	_puff = _make_puff_texture()
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


func _process(delta: float) -> void:
	_update_visual(delta)
	_update_wake()
	_update_charge(delta)
	_update_shake(delta)
	if _any_charging():
		queue_redraw()


func _draw() -> void:
	for side in [SIDE_PORT, SIDE_STARBOARD]:
		if _charging[side]:
			_draw_broadside_arc(side, _power[side])


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


## Se o bordo está carregando um tiro neste momento.
func is_charging(side: int) -> bool:
	return _charging[side]


## Força atual da carga do bordo, de 0.0 a 1.0.
func charge_power(side: int) -> float:
	return _power[side]


## Dispara uma bordada pelo bordo escolhido, com força de 0.0 a 1.0.
## Cria `cannon_count` projéteis em sequência, aplica recuo e tremor.
func fire_broadside(power: float, side: int) -> void:
	power = clampf(power, 0.0, 1.0)
	var limits: Vector2 = _sector_limits(side)
	var aim: float = _broadside_angle(side)
	var half_spread: float = lerpf(data.spread_min, data.spread_max, power)
	var shot_speed: float = lerpf(data.projectile_speed_min, data.projectile_speed_max, power)

	for i in range(data.cannon_count):
		var local_angle: float = clampf(aim + randf_range(-half_spread, half_spread), limits.x, limits.y)
		var velocity: Vector2 = Vector2.from_angle(rotation + local_angle) * shot_speed
		get_tree().create_timer(i * data.volley_interval).timeout.connect(
			_spawn_cannonball.bind(side, velocity)
		)

	# O recuo é perpendicular ao casco, no sentido oposto ao bordo que atirou.
	var barrel: Vector2 = Vector2(0.0, side).rotated(rotation)
	knockback += -barrel * data.recoil_strength * power
	_shake = maxf(_shake, power * data.shake_strength)
	_puff_smoke(side)

	primary_action_triggered.emit(get_global_mouse_position())
	broadside_fired.emit(side, power)


func _press_charge(side: int) -> void:
	if _charging[side] or _awaiting_release[side]:
		return
	_charging[side] = true
	_power[side] = 0.0


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


## Limites do ângulo de tiro (em relação à proa) para o bordo: só o semiplano dele.
func _sector_limits(side: int) -> Vector2:
	if side == SIDE_PORT:
		return Vector2(-PI + SECTOR_MARGIN, -SECTOR_MARGIN)
	return Vector2(SECTOR_MARGIN, PI - SECTOR_MARGIN)


## Ângulo de tiro local do bordo: o cursor, preso ao semiplano desse lado.
func _broadside_angle(side: int) -> float:
	var to_pointer: Vector2 = get_global_mouse_position() - global_position
	var local_angle: float = wrapf(to_pointer.angle() - rotation, -PI, PI)
	var limits: Vector2 = _sector_limits(side)
	return clampf(local_angle, limits.x, limits.y)


func _draw_broadside_arc(side: int, power: float) -> void:
	var limits: Vector2 = _sector_limits(side)
	var aim: float = _broadside_angle(side)
	var half: float = lerpf(data.spread_min, data.spread_max, power)
	var from: float = clampf(aim - half, limits.x, limits.y)
	var to: float = clampf(aim + half, limits.x, limits.y)
	# Alcance atual da carga, e o alcance máximo com a mesma abertura, mais discreto.
	_draw_dotted_arc(from, to, data.range_max, ARC_FAINT_COLOR)
	_draw_dotted_arc(from, to, lerpf(data.range_min, data.range_max, power), ARC_COLOR)


func _draw_dotted_arc(from: float, to: float, radius: float, color: Color) -> void:
	var length: float = absf(to - from) * radius
	var count: int = maxi(2, floori(length / ARC_DOT_SPACING))
	for i in range(count + 1):
		var angle: float = lerpf(from, to, float(i) / count)
		draw_circle(Vector2.from_angle(angle) * radius, ARC_DOT_RADIUS, color)


func _spawn_cannonball(side: int, velocity: Vector2) -> void:
	var ball := Cannonball.new()
	ball.velocity = velocity
	ball.lifetime = data.projectile_lifetime
	get_parent().add_child(ball)
	ball.global_position = global_position + Vector2(0.0, side * GUN_PORT_OFFSET).rotated(rotation)


func _update_steering(delta: float) -> void:
	var steer: float = 0.0
	# Com um tiro carregado, o leme trava: a proa não pode mudar o semiplano do bordo.
	var aim: Vector2 = Vector2.ZERO if _any_holding() else get_aim_vector()
	if aim != Vector2.ZERO:
		var error: float = angle_difference(rotation, aim.angle())
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


## Vista contínua: o rumo mostrado segue o real com atraso, e a vista é uma
## mistura entre os dois setores vizinhos. Assim a virada não tem corte seco.
func _update_visual(delta: float) -> void:
	_time += delta
	_visual_heading = lerp_angle(_visual_heading, rotation, 1.0 - exp(-VISUAL_TURN_RATE * delta))

	# Posição no ciclo de 8 setores: cada vista fica exatamente no seu ângulo
	# (múltiplo de 45°). A parte inteira é o setor, a fração é a mistura com o vizinho.
	var f: float = wrapf(_visual_heading, -PI, PI) / (PI / 4.0)
	var base: int = posmod(floori(f), 8)
	var t: float = f - floorf(f)

	if base != _sector:
		_sector = base
		_entry_a = SECTORS[base]
		_entry_b = SECTORS[(base + 1) % 8]
		_set_textures()

	_blend.modulate.a = t * _opacity_for(_entry_b[0])
	_sprite.modulate.a = _under_alpha((1.0 - t) * _opacity_for(_entry_a[0]), _blend.modulate.a)
	_shadow_blend.modulate.a = t * SHADOW_ALPHA
	_shadow.modulate.a = _under_alpha((1.0 - t) * SHADOW_ALPHA, _shadow_blend.modulate.a)
	direction = _entry_a[0] if t < 0.5 else _entry_b[0]

	_apply_float()


## Balanço de flutuação: o navio sobe e desce, deriva de lado e balança. Mais
## velocidade, mais balanço. A sombra fica no mesmo lugar e se afasta quando o
## navio sobe.
func _apply_float() -> void:
	var fraction: float = clampf(absf(speed) / maxf(data.max_speed, 1.0), 0.0, 1.0)
	var amp: float = 1.0 + 0.5 * fraction
	var bob: float = sin(_time * TAU / BOB_PERIOD) * BOB_AMPLITUDE * amp
	var drift: float = sin(_time * TAU / DRIFT_PERIOD) * DRIFT_AMPLITUDE * amp
	var sway: float = sin(_time * TAU / SWAY_PERIOD) * SWAY_ANGLE * amp

	var local_offset: Vector2 = Vector2(drift, bob).rotated(-rotation)
	_sprite.position = local_offset
	_blend.position = local_offset
	_sprite.rotation = -rotation + sway
	_blend.rotation = -rotation + sway

	var shadow_offset: Vector2 = (SHADOW_OFFSET + Vector2(0.0, -bob * 0.8)).rotated(-rotation)
	_shadow.position = shadow_offset
	_shadow_blend.position = shadow_offset
	_shadow.rotation = -rotation
	_shadow_blend.rotation = -rotation


## Aplica os dois sprites da mistura: a vista atual e a próxima, com espelhamento.
func _set_textures() -> void:
	var tex_a: Texture2D = _texture_for(_entry_a[0])
	_sprite.texture = tex_a
	_shadow.texture = tex_a
	_sprite.flip_h = _entry_a[1]
	_sprite.flip_v = _entry_a[1]
	_shadow.flip_h = _entry_a[1]
	_shadow.flip_v = _entry_a[1]

	var tex_b: Texture2D = _texture_for(_entry_b[0])
	_blend.texture = tex_b
	_shadow_blend.texture = tex_b
	_blend.flip_h = _entry_b[1]
	_blend.flip_v = _entry_b[1]
	_shadow_blend.flip_h = _entry_b[1]
	_shadow_blend.flip_v = _entry_b[1]


## Opacidade da camada de baixo para que, sob a camada de cima, o peso visível
## seja `weight`. Sem isso, as duas vistas translúcidas deixam o fundo aparecer
## e a virada parece um fantasma.
func _under_alpha(weight: float, over_alpha: float) -> float:
	return clampf(weight / maxf(1.0 - over_alpha, 0.0001), 0.0, 1.0)


func _opacity_for(dir: Direction) -> float:
	var diagonal: bool = dir == Direction.TOP_LEFT or dir == Direction.TOP_RIGHT
	return DIAGONAL_OPACITY if diagonal else 1.0


func _texture_for(dir: Direction) -> Texture2D:
	match dir:
		Direction.FRONT:
			return TEX_FRONT
		Direction.BACK:
			return TEX_BACK
		Direction.SIDE_LEFT:
			return TEX_SIDE_LEFT
		Direction.SIDE_RIGHT:
			return TEX_SIDE_RIGHT
		Direction.TOP:
			return TEX_TOP
		Direction.TOP_LEFT:
			return TEX_TOP_LEFT
		_:
			return TEX_TOP_RIGHT


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


func _update_shake(delta: float) -> void:
	if _camera == null:
		return
	if _shake <= 0.0:
		_camera.offset = Vector2.ZERO
		return
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	_shake = move_toward(_shake, 0.0, data.shake_decay * delta)


func _setup_wake() -> void:
	var material := ParticleProcessMaterial.new()
	material.spread = 12.0
	material.gravity = Vector3.ZERO
	material.scale_min = 1.5
	material.scale_max = 3.0
	material.color = Color(0.85, 0.97, 1.0, 0.7)
	_wake.process_material = material
	_wake.local_coords = false
	_wake.emitting = false


## A esteira sai da popa, do lado oposto ao movimento. Com mais velocidade, a
## espuma fica mais forte: mais impulso e mais opacidade.
func _update_wake() -> void:
	var stern_sign: float = -1.0 if speed >= 0.0 else 1.0
	_wake.position = Vector2(stern_sign * data.hull_half_length, 0.0)
	var fraction: float = clampf(absf(speed) / maxf(data.max_speed, 1.0), 0.0, 1.0)
	var material := _wake.process_material as ParticleProcessMaterial
	material.direction = Vector3(stern_sign, 0.0, 0.0)
	material.initial_velocity_min = lerpf(2.0, 10.0, fraction)
	material.initial_velocity_max = lerpf(6.0, 22.0, fraction)
	_wake.modulate.a = fraction * 0.8
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
	node.position = Vector2(0.0, side * GUN_PORT_OFFSET)
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
