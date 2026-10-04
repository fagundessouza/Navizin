class_name Cannonball
extends Node2D
## Projétil de canhão: esfera escura de ferro com brilho e um halo fantasma.
## Segue em linha reta e some ao fim do tempo de vida. Ainda sem colisão.

## Velocidade em pixels por segundo.
var velocity: Vector2 = Vector2.ZERO

## Tempo de vida em segundos.
var lifetime: float = 1.0

const HALO_COLOR: Color = Color(0.4, 1.0, 0.9, 0.2)
const IRON_COLOR: Color = Color(0.1, 0.1, 0.12)
const GLINT_COLOR: Color = Color(0.55, 0.62, 0.66, 0.75)

var _age: float = 0.0


func _process(delta: float) -> void:
	position += velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.6, HALO_COLOR)
	draw_circle(Vector2.ZERO, 2.6, IRON_COLOR)
	draw_circle(Vector2(-0.9, -0.9), 0.8, GLINT_COLOR)
