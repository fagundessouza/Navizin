class_name Cannonball
extends Node2D
## Projétil temporário de canhão. Placeholder: um ponto que segue em linha reta
## e some ao fim do tempo de vida. Ainda sem colisão.

## Velocidade em pixels por segundo.
var velocity: Vector2 = Vector2.ZERO

## Tempo de vida em segundos.
var lifetime: float = 1.0

var _age: float = 0.0


func _process(delta: float) -> void:
	position += velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 2.0, Color(0.1, 0.08, 0.06))
