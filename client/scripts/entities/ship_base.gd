extends Node2D
## Base de todos os navios (jogador e NPCs).
##
## Concentra a física (velas com inércia, leme suave, recuo, vento e maré), o
## estado visual (7 direções, sombra, esteira e fumaça), e o disparo lateral com
## carga de força. Os atributos vêm do recurso `ShipData`.
##
## Controle do jogador:
## - A proa segue o ponteiro do mouse. O leme trava durante a carga do tiro.
## - W/S (ou setas) mudam o nível das velas.
## - Bombordo: tecla Q ou segurar o botão esquerdo. Estibordo: tecla E ou o botão
##   direito. Soltar dispara. A carga cheia dispara sozinha.
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

const TEX_FRONT: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/front.png")
const TEX_BACK: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/back.png")
const TEX_SIDE_LEFT: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/left.png")
const TEX_SIDE_RIGHT: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/right.png")
const TEX_TOP: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/top.png")
const TEX_TOP_LEFT: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/top_left.png")
const TEX_TOP_RIGHT: Texture2D = preload("res://assets/sprites/ships/holandes_voador/dirs/top_right.png")

## Opacidade nas diagonais do topo, para o convés não ficar coberto pelas velas.
const DIAGONAL_OPACITY: float = 0.5

## Ordem dos 8 setores de 45° a partir da direita, no sentido horário da tela.
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

## Margem junto da proa e da popa, em radianos (~8°). A mira nunca aponta direto
## para a frente ou para trás.
const SECTOR_MARGIN: float = 0.14

## Distância dos canhões ao centro do casco, em pixels.
const GUN_PORT_OFFSET: float = 20.0

## Deslocamento da sombra em relação ao casco, no mundo (não gira com o navio).
const SHADOW_OFFSET: Vector2 = Vector2(6.0, 10.0)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.3)

const ARC_COLOR: Color = Color(1.0, 0.95, 0.7, 1.0)
const ARC_FAINT_COLOR: Color = Color(1.0, 0.9, 0.5, 0.25)
const ARC_DOT_RADIUS: float = 2.2
const ARC_DOT_SPACING: float = 9.0

## Atributos do navio.
@export var data: ShipData

## Se verdadeiro, lê o mouse e o teclado. NPCs deixam falso.
@export var player_controlled: bool = false

## Vento e maré, em pixels por segundo. Definido pelo mapa.
@export var ambient_flow: Vector2 = Vector2.ZERO

@onready var _shadow: Sprite2D = $Shadow
@onready var _sprite: Sprite2D = $Sprite2D
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

## Força da bordada em carga, de 0.0 a 1.0.
var shot_power: float = 0.0

## Estado visual atual.
var direction: Direction = Direction.SIDE_LEFT

var _charging: bool = false
var _charge_side: int = SIDE_PORT
var _awaiting_release: bool = false
var _sector: int = -1
var _shake: float = 0.0
var _camera: Camera2D = null
var _puff: GradientTexture2D


func _ready() -> void:
	if data == null:
		data = ShipData.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.modulate = SHADOW_COLOR
	# O sprite fica atrás do desenho do próprio navio (arco de mira).
	_sprite.show_behind_parent = true
	_camera = get_node_or_null("Camera2D") as Camera2D
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
	_update_visual()
	_update_wake()
	_update_charge(delta)
	_update_shake(delta)
	if _charging:
		queue_redraw()


func _draw() -> void:
	if not _charging:
		return
	var limits: Vector2 = _sector_limits(_charge_side)
	var aim: float = _broadside_angle(_charge_side)
	var half: float = lerpf(data.spread_min, data.spread_max, shot_power)
	var from: float = clampf(aim - half, limits.x, limits.y)
	var to: float = clampf(aim + half, limits.x, limits.y)
	# Alcance atual da carga, e o alcance máximo com a mesma abertura, mais discreto.
	_draw_dotted_arc(from, to, data.range_max, ARC_FAINT_COLOR)
	_draw_dotted_arc(from, to, lerpf(data.range_min, data.range_max, shot_power), ARC_COLOR)


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
	if _charging or _awaiting_release:
		return
	_charging = true
	_charge_side = side
	shot_power = 0.0


func _release_charge(side: int) -> void:
	if _charging and side == _charge_side:
		fire_broadside(shot_power, side)
		_stop_charging()
	if _awaiting_release and side == _charge_side:
		_awaiting_release = false


func _mouse_charge(pressed: bool, side: int) -> void:
	if pressed:
		_press_charge(side)
	else:
		_release_charge(side)


func _stop_charging() -> void:
	_charging = false
	shot_power = 0.0


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
	# Com o tiro carregado, o leme trava: a proa não pode mudar o semiplano do bordo.
	var aim: Vector2 = Vector2.ZERO if (_charging or _awaiting_release) else get_aim_vector()
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


## Escolhe o sprite pelo rumo do navio. O sprite não gira com o casco: o rumo
## aparece pela troca de vista. A sombra acompanha, com deslocamento fixo no mundo.
func _update_visual() -> void:
	var sector: int = posmod(floori((wrapf(rotation, -PI, PI) + PI / 8.0) / (PI / 4.0)), 8)
	if sector != _sector:
		_sector = sector
		var entry: Array = SECTORS[sector]
		_apply_direction(entry[0], entry[1])
	_sprite.rotation = -rotation
	_shadow.rotation = -rotation
	_shadow.position = SHADOW_OFFSET.rotated(-rotation)


func _apply_direction(dir: Direction, mirrored: bool) -> void:
	direction = dir
	var texture: Texture2D = _texture_for(dir)
	_sprite.texture = texture
	_shadow.texture = texture
	_sprite.flip_h = mirrored
	_sprite.flip_v = mirrored
	_shadow.flip_h = mirrored
	_shadow.flip_v = mirrored
	var diagonal: bool = dir == Direction.TOP_LEFT or dir == Direction.TOP_RIGHT
	_sprite.modulate.a = DIAGONAL_OPACITY if diagonal else 1.0


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
	if not _charging:
		return
	shot_power = minf(1.0, shot_power + delta / data.charge_time)
	if shot_power >= 1.0:
		# Carga cheia: dispara sozinho e espera o botão ser solto para armar de novo.
		fire_broadside(1.0, _charge_side)
		_stop_charging()
		_awaiting_release = true


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
