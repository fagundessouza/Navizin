extends Node2D
## Cena principal: mapa do oceano.
##
## Contém o mar (ColorRect com shader procedural), o navio do jogador e a
## câmera presa a ele. Mar e câmera são definidos em `ocean_map.tscn`.

## Vento e maré do mapa. Todos os navios sentem o mesmo.
## O vento dá bônus ou penalidade de velocidade conforme a proa; a maré empurra o casco.
const WIND_DIRECTION: Vector2 = Vector2(1.0, 0.25)
const WIND_SPEED: float = 30.0
const CURRENT_FORCE: Vector2 = Vector2(4.0, 2.0)

func _ready() -> void:
	print("Navizin: mapa do oceano carregado.")
	$Ship.wind_direction = WIND_DIRECTION.normalized()
	$Ship.wind_speed = WIND_SPEED
	$Ship.current_force = CURRENT_FORCE
