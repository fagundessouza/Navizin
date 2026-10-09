class_name Cannonball
extends Node2D
## Projétil de canhão: esfera grande de ferro, com borda incandescente e um rastro
## de fumaça escura e densa que se apaga atrás dela. Segue em linha reta e some
## ao fim do tempo de vida. Ainda sem colisão.

## Velocidade em pixels por segundo.
var velocity: Vector2 = Vector2.ZERO

## Tempo de vida em segundos.
var lifetime: float = 1.0

## Raio da esfera de ferro, em pixels.
const RADIUS: float = 5.0

const SPLASH_SCENE: PackedScene = preload("res://scenes/fx/WaterSplashFX.tscn")

const IRON_COLOR: Color = Color(0.09, 0.09, 0.11)
const OUTLINE_COLOR: Color = Color(0.05, 0.05, 0.07)
const GLINT_COLOR: Color = Color(0.6, 0.66, 0.7, 0.8)
const EMBER_COLOR: Color = Color(1.0, 0.55, 0.15, 0.85)
const SMOKE_COLOR: Color = Color(0.55, 0.55, 0.56)

## Quantos pontos de rastro guardar, e o intervalo entre eles, em segundos.
const TRAIL_LENGTH: int = 8
const TRAIL_STEP: float = 0.03

var _age: float = 0.0
var _trail_clock: float = 0.0
## Posições globais recentes, da mais antiga à mais nova.
var _trail: Array[Vector2] = []


func _process(delta: float) -> void:
	position += velocity * delta
	_age += delta
	_trail_clock += delta
	if _trail_clock >= TRAIL_STEP:
		_trail_clock = 0.0
		_trail.append(global_position)
		if _trail.size() > TRAIL_LENGTH:
			_trail.pop_front()
	queue_redraw()
	if _age >= lifetime:
		_impact()


## Fim do alcance: a bala cai na água. Some e deixa o respingo no lugar.
func _impact() -> void:
	visible = false
	var fx := SPLASH_SCENE.instantiate() as Node2D
	# Cena principal; se não houver, a raiz da árvore.
	var host: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	host.add_child(fx)
	fx.global_position = global_position
	queue_free()


func _draw() -> void:
	# Rastro: fumaça cinza curta, mais densa perto da bola, e apagando para trás.
	var count: int = _trail.size()
	for i in range(count):
		var t: float = float(i + 1) / float(count + 1)
		var local: Vector2 = _trail[i] - global_position
		draw_circle(local, lerpf(1.5, 3.5, t), Color(SMOKE_COLOR.r, SMOKE_COLOR.g, SMOKE_COLOR.b, 0.45 * t))

	# Esfera de ferro, com contorno escuro, borda em brasa e um brilho.
	draw_circle(Vector2.ZERO, RADIUS + 1.0, OUTLINE_COLOR)
	draw_circle(Vector2.ZERO, RADIUS, IRON_COLOR)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, EMBER_COLOR, 1.0)
	draw_circle(Vector2(-1.8, -1.8), 1.4, GLINT_COLOR)
