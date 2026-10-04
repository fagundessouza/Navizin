extends Node2D
## Base de todos os navios (jogador e NPCs).
##
## Concentra a física (velas com inércia, leme suave, recuo, vento e maré), o
## estado visual (7 direções), o disparo lateral com carga de força e a esteira.
## Os atributos vêm do recurso `ShipData`.
##
## Controle do jogador:
## - A proa segue o ponteiro do mouse, girando com `turn_speed`.
## - W/S (ou setas) mudam o nível das velas.
## - Segurar o botão esquerdo carrega o tiro. Pelo lado do cursor em relação ao
##   casco, mira a bateria de bombordo (esquerda) ou estibordo (direita). Soltar
##   dispara, e a carga cheia dispara sozinha.
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

## Emitido com o lado da bordada (-1 bombordo, 1 estibordo) e a força (0 a 1).
signal broadside_fired(side: int, power: float)

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

## Atributos do navio.
@export var data: ShipData

## Se verdadeiro, lê o mouse e o teclado. NPCs deixam falso.
@export var player_controlled: bool = false

## Vento e maré, em pixels por segundo. Definido pelo mapa.
@export var ambient_flow: Vector2 = Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _wake: GPUParticles2D = $Wake

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
var _awaiting_release: bool = false
var _shake: float = 0.0
var _camera: Camera2D = null


func _ready() -> void:
	if data == null:
		data = ShipData.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# O sprite fica atrás do desenho do próprio navio (arco de mira).
	_sprite.show_behind_parent = true
	_camera = get_node_or_null("Camera2D") as Camera2D
	_setup_wake()
	_apply_direction(Direction.SIDE_LEFT, false)


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
	if not _charging or not player_controlled:
		return
	var side: int = aim_side()
	if side == 0:
		return
	var normal: Vector2 = Vector2(0.0, side)
	var length: float = lerpf(data.range_min, data.range_max, shot_power)
	var half: float = lerpf(data.spread_min, data.spread_max, shot_power)
	var steps: int = 16
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for i in range(steps + 1):
		var angle: float = lerpf(normal.angle() - half, normal.angle() + half, float(i) / steps)
		points.append(Vector2.from_angle(angle) * length)
	draw_colored_polygon(points, Color(1.0, 0.85, 0.3, 0.25))
	draw_polyline(points.slice(1), Color(1.0, 0.85, 0.3, 0.8), 1.0)


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

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _awaiting_release:
				_charging = true
				shot_power = 0.0
		elif _charging:
			fire_broadside(shot_power)
			_charging = false
			shot_power = 0.0
		else:
			_awaiting_release = false


## Direção da mira: do navio até o ponteiro, normalizada.
## Retorna vetor zero sem jogador ou quando o ponteiro está dentro da zona morta.
func get_aim_vector() -> Vector2:
	if not player_controlled:
		return Vector2.ZERO
	var to_pointer: Vector2 = get_global_mouse_position() - global_position
	if to_pointer.length() < data.aim_deadzone:
		return Vector2.ZERO
	return to_pointer.normalized()


## Lado da bateria que a mira seleciona: -1 bombordo (esquerda do casco),
## 1 estibordo (direita) e 0 sem mira.
func aim_side() -> int:
	var aim_local: Vector2 = get_aim_vector().rotated(-rotation)
	if aim_local == Vector2.ZERO:
		return 0
	return -1 if aim_local.y < 0.0 else 1


## Dispara uma bordada do lado da mira, com força de 0.0 a 1.0.
## Cria `cannon_count` projéteis em sequência, aplica recuo e tremor.
func fire_broadside(power: float) -> void:
	var side: int = aim_side()
	if side == 0:
		return
	power = clampf(power, 0.0, 1.0)

	var normal: Vector2 = Vector2(0.0, side).rotated(rotation)
	var half_spread: float = lerpf(data.spread_min, data.spread_max, power)
	var shot_speed: float = lerpf(data.projectile_speed_min, data.projectile_speed_max, power)
	var origin: Vector2 = global_position

	for i in range(data.cannon_count):
		var angle: float = normal.angle() + randf_range(-half_spread, half_spread)
		var velocity: Vector2 = Vector2.from_angle(angle) * shot_speed
		get_tree().create_timer(i * data.volley_interval).timeout.connect(
			_spawn_cannonball.bind(origin, velocity)
		)

	knockback += -normal * data.recoil_strength * power
	_shake = maxf(_shake, power * data.shake_strength)

	primary_action_triggered.emit(get_global_mouse_position())
	broadside_fired.emit(side, power)


func _spawn_cannonball(origin: Vector2, velocity: Vector2) -> void:
	var ball := Cannonball.new()
	ball.velocity = velocity
	ball.lifetime = data.projectile_lifetime
	get_parent().add_child(ball)
	ball.global_position = origin


func _update_steering(delta: float) -> void:
	var steer: float = 0.0
	# Com o tiro carregado, o leme trava: o cursor precisa poder ir para um dos
	# lados do casco para escolher a bateria, e a proa não pode acompanhá-lo.
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
## aparece pela troca de direção.
func _update_visual() -> void:
	var sector: int = posmod(floori((wrapf(rotation, -PI, PI) + PI / 8.0) / (PI / 4.0)), 8)
	var entry: Array = SECTORS[sector]
	_apply_direction(entry[0], entry[1])
	_sprite.rotation = -rotation


func _apply_direction(dir: Direction, mirrored: bool) -> void:
	direction = dir
	_sprite.texture = _texture_for(dir)
	_sprite.flip_h = mirrored
	_sprite.flip_v = mirrored
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
		fire_broadside(1.0)
		_charging = false
		shot_power = 0.0
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
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 22.0
	material.gravity = Vector3.ZERO
	material.scale_min = 1.5
	material.scale_max = 3.0
	material.color = Color(0.85, 0.97, 1.0, 0.7)
	_wake.process_material = material
	_wake.local_coords = false
	_wake.emitting = false


## A esteira sai da popa: a popa é o lado oposto ao sentido do movimento.
func _update_wake() -> void:
	var stern_sign: float = -1.0 if speed >= 0.0 else 1.0
	_wake.position = Vector2(stern_sign * data.hull_half_length, 0.0)
	var material := _wake.process_material as ParticleProcessMaterial
	material.direction = Vector3(stern_sign, 0.0, 0.0)
	_wake.emitting = absf(speed) > 5.0
