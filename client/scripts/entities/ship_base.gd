extends Node2D
## Base de todos os navios (jogador e NPCs).
##
## Concentra a física (velas com inércia, leme suave, recuo, vento e maré), a
## apresentação (vista do navio entre as 7 direções, balanço de flutuação,
## sombra, esteira e fumaça) e o disparo lateral com carga de força.
## Os atributos vêm do recurso `ShipData`.
##
## Controle do jogador:
## - W/S (ou setas) mudam o nível das velas.
## - Q liga e desliga a mira de bombordo; E, a de estibordo. Mostrar a mira
##   nunca dispara. Com a mira ligada, a proa fica travada e o mouse só ajusta
##   o ângulo, em um arco de ±20° em torno da lateral.
## - Botão esquerdo do mouse: segura para carregar a bateria ativa. A mira começa
##   curta, perto do casco, e estende até o alcance máximo. Ao soltar, dispara.
##   Não há disparo automático.
## - As baterias de bombordo e estibordo têm cooldown independente.
## - Sem mira ativa, a proa segue o ponteiro do mouse.
## - Teclas 1 a 4 emitem `skill_triggered`. Ainda sem efeito.
##
## NPCs deixam `player_controlled` falso e recebem comandos de IA no futuro.

## Nível das velas. O valor é o sentido e a força do impulso.
enum Sail { REVERSE = -1, STOPPED = 0, HALF = 1, FULL = 2 }

## Vista do navio. Cada valor usa um sprite de `assets/sprites/ships/holandes_voador/dirs/`.
## TOP (vista de cima, proa para cima) não é escolhido pelo rumo: fica disponível
## para uso manual, como um modo de mapa.
enum Direction { FRONT, BACK, SIDE_LEFT, SIDE_RIGHT, TOP, TOP_LEFT, TOP_RIGHT }

## Emitido ao pressionar uma tecla de habilidade. `skill_index` vai de 1 a 4.
signal skill_triggered(skill_index: int)

## Emitido a cada bordada disparada. `target` é a posição do ponteiro no mundo.
signal primary_action_triggered(target: Vector2)

## Emitido com o bordo (-1 bombordo, 1 estibordo) e a força (0 a 1).
signal broadside_fired(side: int, power: float)

const SIDE_NONE: int = 0
const SIDE_PORT: int = -1
const SIDE_STARBOARD: int = 1

## Força mínima de um disparo. Um toque rápido ainda sai como tiro visível.
const TAP_MIN_POWER: float = 0.3

## Arco de ajuste da mira, em torno da lateral: ±20°, sem apontar para proa ou popa.
const AIM_ARC: float = 0.35

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

## Velocidade da troca de vista: escurece e clareia em cerca de 0.1 s cada.
const DIP_SPEED: float = 9.0

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

## Distância lateral dos canhões ao centro do casco, em pixels.
const GUN_LATERAL: float = 10.0

## Convés na arte de vista lateral, em coordenadas de tela (não giram com o casco).
## O centro do sprite fica na altura das velas; os tiros saem daqui, e não do mastro.
const DECK_OFFSET: Vector2 = Vector2(0.0, 22.0)

## Sombra: deslocamento no mundo e opacidade base.
const SHADOW_OFFSET: Vector2 = Vector2(6.0, 10.0)
const SHADOW_ALPHA: float = 0.3

## Trilhos de mira em laranja-avermelhado: faixas paralelas translúcidas que
## seguem a direção de tiro. Contrastam com o azul escuro do mar.
const RAIL_COLOR: Color = Color(1.0, 0.45, 0.15, 0.35)
const RAIL_FAINT_COLOR: Color = Color(1.0, 0.45, 0.15, 0.12)
const RAIL_HALF_WIDTH: float = 3.0

## Atributos do navio.
@export var data: ShipData

## Se verdadeiro, lê o mouse e o teclado. NPCs deixam falso.
@export var player_controlled: bool = false

## Vento e maré, em pixels por segundo. Definido pelo mapa.
@export var ambient_flow: Vector2 = Vector2.ZERO

## Área útil do mar. O navio não sai dela.
@export var world_bounds: Rect2 = Rect2(-4000.0, -4000.0, 8000.0, 8000.0)

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

## Vista mostrada agora.
var direction: Direction = Direction.SIDE_LEFT

## Bateria com mira ligada: SIDE_PORT, SIDE_STARBOARD, ou SIDE_NONE.
var _active_side: int = SIDE_NONE
## Carga em andamento: se o botão está segurado, de que bordo, e a força atual.
var _holding: bool = false
var _charge_side: int = SIDE_NONE
var _power: float = 0.0
## Tempo restante de cooldown de cada bateria, indexado por SIDE_PORT e SIDE_STARBOARD.
var _cooldown: Dictionary = {SIDE_PORT: 0.0, SIDE_STARBOARD: 0.0}

var _was_showing_aim: bool = false
var _shake: float = 0.0
var _camera: Camera2D = null
var _puff: GradientTexture2D

## Rumo mostrado na tela: segue o rumo real com atraso, então a virada parece pesada.
var _visual_heading: float = 0.0
## Vista exibida e a vista para a qual a troca está indo (-1 sem troca).
var _shown_sector: int = -1
var _swap_to: int = -1
var _fade: float = 1.0
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
	_show_sector(_sector_for(rotation))
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
	# Redesenha enquanto a mira está ligada, e no quadro em que ela desliga, para apagar os trilhos.
	var showing: bool = _active_side != SIDE_NONE
	if showing or _was_showing_aim:
		queue_redraw()
	_was_showing_aim = showing


func _draw() -> void:
	if _active_side != SIDE_NONE:
		_draw_rails(_active_side)


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

	# Q e E só ligam ou desligam a mira. Nunca disparam.
	if event.is_action_pressed("broadside_port"):
		_toggle_aim(SIDE_PORT)
	elif event.is_action_pressed("broadside_starboard"):
		_toggle_aim(SIDE_STARBOARD)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_hold()
		else:
			_end_hold()


## Direção da mira: do navio até o ponteiro, normalizada.
## Retorna vetor zero sem jogador ou quando o ponteiro está dentro da zona morta.
func get_aim_vector() -> Vector2:
	if not player_controlled:
		return Vector2.ZERO
	var to_pointer: Vector2 = get_global_mouse_position() - global_position
	if to_pointer.length() < data.aim_deadzone:
		return Vector2.ZERO
	return to_pointer.normalized()


## Bateria com a mira ligada, ou SIDE_NONE.
func active_side() -> int:
	return _active_side


## Se a bateria está com o botão segurado, carregando.
func is_charging(side: int) -> bool:
	return _holding and _charge_side == side


## Força atual da carga, de 0.0 a 1.0.
func charge_power() -> float:
	return _power


## Segundos restantes até a bateria do bordo poder disparar de novo.
func cooldown_left(side: int) -> float:
	return _cooldown[side]


## Dispara uma bordada pelo bordo escolhido, com força de 0.0 a 1.0.
## Cria `cannon_count` projéteis em sequência, saindo dos canhões do bordo.
## Não dispara se a bateria ainda está em cooldown.
func fire_broadside(power: float, side: int) -> void:
	if side == SIDE_NONE or _cooldown[side] > 0.0:
		return
	power = clampf(power, 0.0, 1.0)
	var aim: float = _aim_local(side)
	var half_spread: float = lerpf(data.spread_min, data.spread_max, power)
	var shot_speed: float = lerpf(data.projectile_speed_min, data.projectile_speed_max, power)
	var normal: float = _normal_local(side)
	var guns: Array = _guns(side)

	for i in range(data.cannon_count):
		# A dispersão fica dentro do arco de ±20°: nunca aponta para a proa ou a popa.
		var local_angle: float = clampf(aim + randf_range(-half_spread, half_spread),
			normal - AIM_ARC, normal + AIM_ARC)
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


## Liga ou desliga a mira de uma bateria. Trocar de bordo muda a mira ativa.
func _toggle_aim(side: int) -> void:
	_active_side = SIDE_NONE if _active_side == side else side


## Botão esquerdo pressionado: começa a carregar a bateria ativa, se pronta.
func _begin_hold() -> void:
	if _holding or _active_side == SIDE_NONE or _cooldown[_active_side] > 0.0:
		return
	_holding = true
	_charge_side = _active_side
	_power = 0.0


## Botão esquerdo solto: dispara a bateria que carregou, com a força acumulada.
func _end_hold() -> void:
	if not _holding:
		return
	fire_broadside(maxf(_power, TAP_MIN_POWER), _charge_side)
	_holding = false
	_charge_side = SIDE_NONE
	_power = 0.0


## Normal do bordo no referencial do casco: bombordo aponta para -Y, estibordo para +Y.
func _normal_local(side: int) -> float:
	return -PI / 2.0 if side == SIDE_PORT else PI / 2.0


## Ângulo de tiro local do bordo: a lateral, desviada pelo cursor dentro de ±AIM_ARC.
func _aim_local(side: int) -> float:
	var normal: float = _normal_local(side)
	var to_pointer: Vector2 = get_global_mouse_position() - global_position
	var pointer_local: float = wrapf(to_pointer.angle() - rotation, -PI, PI)
	var offset: float = clampf(angle_difference(normal, pointer_local), -AIM_ARC, AIM_ARC)
	return normal + offset


## Canhões de um bordo, na ordem em que são usados na bordada.
func _guns(side: int) -> Array:
	return _port_cannons.get_children() if side == SIDE_PORT else _starboard_cannons.get_children()


## Trilhos paralelos que seguem a direção de tiro, um por canhão.
## Começam curtos perto do casco e se estendem com a carga. O alcance máximo
## fica como referência discreta.
func _draw_rails(side: int) -> void:
	var dir: Vector2 = Vector2.from_angle(_aim_local(side))
	var length: float = lerpf(data.range_min, data.range_max, _power) if is_charging(side) else data.range_min
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
	# Atrás do navio: na arte de lado, um tiro para bombordo sobe pelas velas
	# e deve passar por trás delas, não por cima.
	get_parent().move_child(ball, get_index())
	ball.global_position = global_position + DECK_OFFSET + gun.position.rotated(rotation)


func _update_steering(delta: float) -> void:
	var steer: float = 0.0
	# Com a mira ligada, a proa trava: o mouse só ajusta o ângulo de tiro.
	var aim: Vector2 = Vector2.ZERO if _active_side != SIDE_NONE else get_aim_vector()
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


## Uma vista por vez. O rumo mostrado segue o real com atraso. Quando ele passa
## para outra vista, a atual escurece, a nova aparece e a vista clareia de novo.
## Assim não há duas direções visíveis ao mesmo tempo.
func _update_visual(delta: float) -> void:
	_time += delta
	_visual_heading = lerp_angle(_visual_heading, rotation, 1.0 - exp(-VISUAL_TURN_RATE * delta))

	var wanted: int = _sector_for(_visual_heading)
	if wanted != _shown_sector:
		_swap_to = wanted
	else:
		_swap_to = -1

	if _swap_to != -1:
		_fade = move_toward(_fade, 0.0, DIP_SPEED * delta)
		if _fade <= 0.0:
			_show_sector(_swap_to)
			_swap_to = -1
	else:
		_fade = move_toward(_fade, 1.0, DIP_SPEED * delta)

	var entry: Array = SECTORS[_shown_sector]
	_sprite.modulate.a = _fade * _opacity_for(entry[0])
	_shadow.modulate.a = SHADOW_ALPHA * _fade
	direction = entry[0]

	_apply_float()


## Vista mais próxima do rumo, como índice em `SECTORS`.
func _sector_for(angle: float) -> int:
	return posmod(roundi(wrapf(angle, -PI, PI) / (PI / 4.0)), 8)


## Mostra a vista do setor: textura, espelhamento e sombra.
func _show_sector(sector: int) -> void:
	_shown_sector = sector
	var entry: Array = SECTORS[sector]
	var tex: Texture2D = _texture_for(entry[0])
	_sprite.texture = tex
	_shadow.texture = tex
	_sprite.flip_h = entry[1]
	_sprite.flip_v = entry[1]
	_shadow.flip_h = entry[1]
	_shadow.flip_v = entry[1]


## Balanço de flutuação: o navio sobe e desce, deriva de lado e balança. Mais
## velocidade, mais balanço. A sombra fica no mesmo lugar e se afasta quando o
## navio sobe.
func _apply_float() -> void:
	var fraction: float = clampf(absf(speed) / maxf(data.max_speed, 1.0), 0.0, 1.0)
	var amp: float = 1.0 + 0.5 * fraction
	var bob: float = sin(_time * TAU / BOB_PERIOD) * BOB_AMPLITUDE * amp
	var drift: float = sin(_time * TAU / DRIFT_PERIOD) * DRIFT_AMPLITUDE * amp
	var sway: float = sin(_time * TAU / SWAY_PERIOD) * SWAY_ANGLE * amp

	_sprite.position = Vector2(drift, bob).rotated(-rotation)
	_sprite.rotation = -rotation + sway

	var shadow_offset: Vector2 = (SHADOW_OFFSET + Vector2(0.0, -bob * 0.8)).rotated(-rotation)
	_shadow.position = shadow_offset
	_shadow.rotation = -rotation

	# Fumaça de cada bordo sai do convés, na altura do canhão.
	_smoke_port.position = (DECK_OFFSET + Vector2(0.0, -GUN_LATERAL)).rotated(-rotation)
	_smoke_starboard.position = (DECK_OFFSET + Vector2(0.0, GUN_LATERAL)).rotated(-rotation)


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


## Enquanto o botão está segurado, a força cresce até 1.0. Não dispara sozinha.
func _update_charge(delta: float) -> void:
	if _holding:
		_power = minf(1.0, _power + delta / data.charge_time)


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
