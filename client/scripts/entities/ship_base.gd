extends Node2D
## Base de todos os navios (jogador e NPCs).
##
## Guarda a identidade do navio, a física de movimento e a animação. A
## animação dos frames fica no nó `Sprite2D` filho, configurado com `hframes`.
##
## Controle do jogador (estilo MOBA / ARPG):
## - A proa segue o ponteiro do mouse, girando com `turn_speed`.
## - W/S (ou setas) mudam o nível das velas, com inércia: a velocidade chega
##   ao alvo aos poucos, sem trocar de velocidade de uma vez.
## - Teclas 1 a 4 emitem `skill_triggered`, e o clique esquerdo emite
##   `primary_action_triggered`. Os sinais são só a ponte; quem decide o efeito
##   é o sistema de habilidades, que ainda não existe.
##
## NPCs deixam `player_controlled` falso e recebem comandos de IA no futuro.

## Nível das velas. O valor é o sentido e a força do impulso.
enum Sail { REVERSE = -1, STOPPED = 0, HALF = 1, FULL = 2 }

## Emitido ao pressionar uma tecla de habilidade. `skill_index` vai de 1 a 4.
signal skill_triggered(skill_index: int)

## Emitido ao clicar com o botão esquerdo. `target` é a posição global do ponteiro.
signal primary_action_triggered(target: Vector2)

## Nome de exibição do navio.
@export var ship_name: String = "Navio"

## Quantidade de frames do spritesheet (ex.: 6 para o Holandês Voador).
@export var frame_count: int = 6

## Frames por segundo da animação das velas.
@export var animation_fps: float = 8.0

## Se verdadeiro, lê o mouse e o teclado. NPCs deixam falso.
@export var player_controlled: bool = false

## Velocidade com vela cheia, em pixels por segundo.
@export var max_speed: float = 120.0

## Velocidade com meia vela, em pixels por segundo.
@export var half_speed: float = 60.0

## Velocidade em ré, em pixels por segundo.
@export var reverse_speed: float = 40.0

## Aceleração enquanto a velocidade sobe em direção ao alvo, em px/s².
@export var acceleration: float = 40.0

## Desaceleração enquanto a velocidade cai (inércia), em px/s².
@export var deceleration: float = 30.0

## Velocidade angular máxima de giro, em radianos por segundo.
@export var turn_speed: float = 1.4

## Quão rápido a velocidade angular chega ao alvo (suavização do giro).
@export var turn_acceleration: float = 4.0

## Quanto a proa reage ao erro de mira. Valores maiores giram mais rápido.
@export var aim_responsiveness: float = 3.0

## Distância mínima do ponteiro para a proa mudar de direção, em pixels.
@export var aim_deadzone: float = 8.0

@onready var _sprite: Sprite2D = $Sprite2D

var _elapsed: float = 0.0

## Nível atual das velas.
var sail: Sail = Sail.STOPPED

## Velocidade escalar atual, em pixels por segundo. Negativa em ré.
var speed: float = 0.0

## Velocidade de giro atual, em radianos por segundo.
var angular_velocity: float = 0.0


func _ready() -> void:
	_sprite.hframes = frame_count


func _process(delta: float) -> void:
	_elapsed += delta
	_sprite.frame = int(_elapsed * animation_fps) % frame_count


func _physics_process(delta: float) -> void:
	_update_steering(delta)
	_update_speed(delta)
	position += Vector2.RIGHT.rotated(rotation) * speed * delta


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

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		primary_action_triggered.emit(get_global_mouse_position())


## Direção da mira: do navio até o ponteiro, normalizada.
## Retorna vetor zero sem jogador ou quando o ponteiro está dentro da zona morta.
func get_aim_vector() -> Vector2:
	if not player_controlled:
		return Vector2.ZERO
	var to_pointer: Vector2 = get_global_mouse_position() - global_position
	if to_pointer.length() < aim_deadzone:
		return Vector2.ZERO
	return to_pointer.normalized()


func _update_steering(delta: float) -> void:
	var steer: float = 0.0
	var aim: Vector2 = get_aim_vector()
	if aim != Vector2.ZERO:
		var error: float = angle_difference(rotation, aim.angle())
		steer = clampf(error * aim_responsiveness, -1.0, 1.0)

	angular_velocity = move_toward(angular_velocity, steer * turn_speed, turn_acceleration * delta)
	rotation += angular_velocity * delta


func _update_speed(delta: float) -> void:
	var target: float = _target_speed()
	# Acelera quando o alvo está mais longe de zero que a velocidade atual;
	# caso contrário, solta devagar (inércia).
	var rate: float = acceleration if absf(target) > absf(speed) else deceleration
	speed = move_toward(speed, target, rate * delta)


func _target_speed() -> float:
	match sail:
		Sail.REVERSE:
			return -reverse_speed
		Sail.HALF:
			return half_speed
		Sail.FULL:
			return max_speed
		_:
			return 0.0
