extends Node2D
## Cena principal: mapa do oceano.
##
## Contém o mar (ColorRect com shader procedural), o navio do jogador e a
## câmera presa a ele. Mar e câmera são definidos em `ocean_map.tscn`.

func _ready() -> void:
	print("Navizin: mapa do oceano carregado.")
