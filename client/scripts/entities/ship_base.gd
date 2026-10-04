extends Node2D
## Base de todos os navios (jogador e NPCs).
##
## Guarda a identidade do navio, a física de movimento e a animação. A
## animação dos frames fica no nó `Sprite2D` filho, configurado com `hframes`.
##
## O navio anda sempre para a frente da sua rotação. Aceleração, freio e
## atrito atuam sobre a velocidade escalar; a rotação suaviza a velocidade
## angular até o alvo do comando.

## Nome de exibição do navio.
@export var ship_name: String = "Navio"

## Quantidade de frames do spritesheet (ex.: 6 para o Holandês Voador).
@export var frame_count: int = 6

## Frames por segundo da animação das velas.
@export var animation_fps: float = 8.0

## Se verdadeiro, lê o teclado (setas). NPCs deixam falso e recebem comandos de IA.
@export var player_controlled: bool = false

## Velocidade máxima, em pixels por segundo.
@export var max_speed: float = 120.0

## Aceleração ao segurar para frente, em pixels por segundo ao quadrado.
@export var acceleration: float = 60.0

## Freio ao segurar para trás.
@export var brake_force: float = 140.0

## Atrito quando nenhum comando é dado: o navio perde velocidade devagar.
@export var drag: float = 25.0

## Velocidade angular máxima de giro, em radianos por segundo.
@export var turn_speed: float = 1.4

## Quão rápido a velocidade angular chega ao alvo (suavização do giro).
@export var turn_acceleration: float = 4.0

@onready var _sprite: Sprite2D = $Sprite2D

var _elapsed: float = 0.0

## Velocidade atual para frente, em pixels por segundo. Nunca fica negativa.
var speed: float = 0.0

## Velocidade de giro atual, em radianos por segundo.
var angular_velocity: float = 0.0


func _ready() -> void:
	_sprite.hframes = frame_count


func _process(delta: float) -> void:
	_elapsed += delta
	_sprite.frame = int(_elapsed * animation_fps) % frame_count


func _physics_process(delta: float) -> void:
	var command: Vector2 = _read_command()
	var throttle: float = command.y
	var steer: float = command.x

	if throttle > 0.0:
		speed = move_toward(speed, max_speed, acceleration * throttle * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, 0.0, brake_force * -throttle * delta)
	else:
		speed = move_toward(speed, 0.0, drag * delta)

	angular_velocity = move_toward(angular_velocity, steer * turn_speed, turn_acceleration * delta)
	rotation += angular_velocity * delta

	position += Vector2.RIGHT.rotated(rotation) * speed * delta


## Comando do piloto neste quadro: `x` é o giro (-1 esquerda, 1 direita) e
## `y` é o acelerador (1 frente, -1 freio). Sem jogador, o navio fica parado.
func _read_command() -> Vector2:
	if not player_controlled:
		return Vector2.ZERO
	return Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_down", "ui_up"),
	)
