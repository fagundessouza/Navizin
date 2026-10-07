extends Node
## Vento global do mar: direção e força que mudam devagar, de forma procedural.
##
## A direção gira com `lerp_angle` em direção a um alvo que um ruído suave escolhe;
## a força segue outro ruído, entre 0.3 e 1.5. Todos os navios e a HUD leem daqui.

## Emitido quando a direção ou a força mudam o suficiente para importar.
signal wind_changed(direction: Vector2, strength: float)

## Força mínima e máxima do vento.
const STRENGTH_MIN: float = 0.3
const STRENGTH_MAX: float = 1.5

## Quanto a direção e a força se aproximam do alvo por segundo.
const TURN_RATE: float = 0.15
const STRENGTH_RATE: float = 0.2

## Velocidade com que o ruído escolhe novos alvos.
const NOISE_SPEED: float = 0.02

var wind_direction: Vector2 = Vector2.RIGHT
var wind_strength: float = 1.0

var _noise: FastNoiseLite = FastNoiseLite.new()
var _target_angle: float = 0.0
var _target_strength: float = 1.0
var _time: float = 0.0
var _last_direction: Vector2 = Vector2.RIGHT
var _last_strength: float = 1.0


func _ready() -> void:
	_noise.seed = 1337
	_noise.frequency = 0.05
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wind_direction = Vector2.from_angle(_angle_from_noise(0.0))
	_target_angle = wind_direction.angle()


func _process(delta: float) -> void:
	_time += delta
	_target_angle = _angle_from_noise(_time * NOISE_SPEED)
	_target_strength = lerpf(STRENGTH_MIN, STRENGTH_MAX, 0.5 + 0.5 * _noise.get_noise_1d(_time * NOISE_SPEED + 100.0))

	var current_angle: float = lerp_angle(wind_direction.angle(), _target_angle, 1.0 - exp(-TURN_RATE * delta))
	wind_direction = Vector2.from_angle(current_angle)
	wind_strength = lerpf(wind_strength, _target_strength, 1.0 - exp(-STRENGTH_RATE * delta))

	if wind_direction.distance_to(_last_direction) > 0.005 or absf(wind_strength - _last_strength) > 0.005:
		_last_direction = wind_direction
		_last_strength = wind_strength
		wind_changed.emit(wind_direction, wind_strength)


## Ângulo do vento a partir do ruído: uma volta completa em alguns minutos.
func _angle_from_noise(t: float) -> float:
	return _noise.get_noise_1d(t) * PI
