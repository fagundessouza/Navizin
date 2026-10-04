extends Node2D
## Cena principal: mapa do oceano.
##
## Contém o mar (ColorRect com shader procedural), o navio do jogador e a
## câmera presa a ele. Mar e câmera são definidos em `ocean_map.tscn`.

## Vento e maré do mapa, em pixels por segundo. Todos os navios sentem o mesmo.
const AMBIENT_FLOW: Vector2 = Vector2(14.0, 5.0)

func _ready() -> void:
	print("Navizin: mapa do oceano carregado.")
	$Ship.ambient_flow = AMBIENT_FLOW
