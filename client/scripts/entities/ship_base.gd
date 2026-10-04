extends Node2D
## Base de todos os navios (jogador e NPCs).
##
## Guarda a identidade do navio e a direção atual. A animação dos frames
## fica no nó `Sprite2D` filho, configurado com `hframes`.

## Nome de exibição do navio.
@export var ship_name: String = "Navio"

## Quantidade de frames do spritesheet (ex.: 6 para o Holandês Voador).
@export var frame_count: int = 6

## Frames por segundo da animação das velas.
@export var animation_fps: float = 8.0

@onready var _sprite: Sprite2D = $Sprite2D

var _elapsed: float = 0.0


func _ready() -> void:
	_sprite.hframes = frame_count


func _process(delta: float) -> void:
	_elapsed += delta
	_sprite.frame = int(_elapsed * animation_fps) % frame_count
