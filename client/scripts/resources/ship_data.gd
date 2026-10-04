class_name ShipData
extends Resource
## Atributos de um tipo de navio. Fica em um `.tres` para ajustar no editor e
## para ser reaproveitado por jogador e NPCs.

@export var ship_name: String = "Navio"

@export_group("Velas")
## Velocidade com vela cheia, em pixels por segundo.
@export var max_speed: float = 120.0
## Velocidade com meia vela, em pixels por segundo.
@export var half_speed: float = 60.0
## Velocidade em ré, em pixels por segundo.
@export var reverse_speed: float = 40.0
## Aceleração enquanto a velocidade sobe em direção ao alvo, em px/s².
@export var acceleration: float = 40.0
## Desaceleração enquanto a velocidade cai (inércia), em px/s².
@export var deceleration: float = 30.0

@export_group("Leme")
## Velocidade angular máxima de giro, em radianos por segundo.
@export var turn_speed: float = 1.4
## Quão rápido a velocidade angular chega ao alvo (suavização do giro).
@export var turn_acceleration: float = 4.0
## Quanto a proa reage ao erro de mira. Valores maiores giram mais rápido.
@export var aim_responsiveness: float = 3.0
## Distância mínima do ponteiro para a proa mudar de direção, em pixels.
@export var aim_deadzone: float = 8.0

@export_group("Carga")
## Capacidade máxima de carga, em unidades de peso.
@export var max_cargo: float = 100.0
## Peso da carga atual. Carga pesada reduz a velocidade máxima.
@export var cargo_weight: float = 0.0
## Segundos segurando o botão para carregar o disparo por completo.
@export var charge_time: float = 1.5

@export_group("Canhões")
## Projéteis por bordada (um por canhão).
@export var cannon_count: int = 6
## Intervalo entre projéteis da mesma bordada, em segundos.
@export var volley_interval: float = 0.05
## Alcance mínimo e máximo, em pixels, conforme a força.
@export var range_min: float = 60.0
@export var range_max: float = 260.0
## Abertura mínima e máxima do cone de tiro, em radianos (metade do ângulo).
@export var spread_min: float = 0.05
@export var spread_max: float = 0.35
## Velocidade inicial do projétil conforme a força, em px/s.
@export var projectile_speed_min: float = 160.0
@export var projectile_speed_max: float = 420.0
## Tempo de vida do projétil, em segundos.
@export var projectile_lifetime: float = 1.2

@export_group("Física e efeitos")
## Impulso de recuo com força total, em px/s.
@export var recoil_strength: float = 90.0
## Quanto o recuo perde de força por segundo, em px/s².
@export var recoil_damping: float = 180.0
## Tremor da câmera com força total, em pixels.
@export var shake_strength: float = 12.0
## Quanto o tremor da câmera diminui por segundo, em pixels.
@export var shake_decay: float = 20.0
## Quanto do vento e da maré o navio sente (0 a 1).
@export var wind_influence: float = 0.15
## Metade do comprimento do casco, usada para posicionar a esteira na popa.
@export var hull_half_length: float = 80.0


## Fator de velocidade pela carga: de 1.0 (vazio) até 0.5 (carga cheia).
func effective_max_factor() -> float:
	if max_cargo <= 0.0:
		return 1.0
	return 1.0 - 0.5 * clampf(cargo_weight / max_cargo, 0.0, 1.0)
