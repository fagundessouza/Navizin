class_name BoardingMarker
extends Node2D
## Nó indicador "Espadas Cruzadas em Chamas", instanciado por
## `ship_base.gd._update_vulnerability()` acima de qualquer navio (jogador
## ou NPC) que cruze o limiar de vulnerabilidade (`BoardingManager`). Sinaliza
## o combate de abordagem a quem passar perto, igual a um marcador de ponto
## de interesse -- pulsa suavemente (`Sprite2D` + seno no `_process`, mesma
## técnica usada em outros brilhos do projeto) pra chamar atenção sem ser
## uma luz/partícula cara.
##
## Mesmo padrão de `tortuga_dock.gd` (`Area2D` detecta o navio do JOGADOR no
## alcance, tecla "interact" confirma) -- reaproveitado aqui porque é
## exatamente o mesmo problema (gatilho de proximidade + confirmação por
## tecla), só que o alvo da interação é "abordar este navio" em vez de
## "entrar no porto".

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _area: Area2D = $Area2D

var _target_ship: Node2D = null
var _player_in_range: Node2D = null
var _time: float = 0.0


func set_target_ship(ship: Node2D) -> void:
	_target_ship = ship


func _ready() -> void:
	_area.area_entered.connect(_on_area_entered)
	_area.area_exited.connect(_on_area_exited)


func _process(delta: float) -> void:
	_time += delta
	var pulse: float = 0.85 + 0.15 * sin(_time * 2.2)
	_sprite.scale = Vector2.ONE * pulse
	_sprite.modulate.a = 0.75 + 0.25 * sin(_time * 2.2)


func _on_area_entered(area: Area2D) -> void:
	var ship: Node2D = area.get_parent() as Node2D
	if ship != null and ship.is_in_group("player_ship") and ship != _target_ship:
		_player_in_range = ship


func _on_area_exited(area: Area2D) -> void:
	if area.get_parent() == _player_in_range:
		_player_in_range = null


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range == null or _target_ship == null or not event.is_action_pressed("interact"):
		return
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	var attacker: Node2D = _player_in_range
	BoardingManager.start_boarding(attacker, _target_ship)
