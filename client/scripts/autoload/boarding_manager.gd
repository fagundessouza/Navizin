extends Node
## Autoload: ponte entre o mapa do mar e `boarding_battle_scene.tscn` --
## salva um retrato do confronto (atacante/alvo) antes de trocar de cena,
## igual ao padrão já usado por `GameManager` (`saved_hull`/
## `saved_ship_position`/etc, escritos por `ocean_map.gd._enter_tortuga()`
## antes de ir pra cidade). A posição/casco/suprimento do PRÓPRIO navio do
## jogador continuam usando os campos de sempre do `GameManager` -- não
## precisa duplicar isso aqui, `ocean_map.gd._restore_ship_state()` já
## recoloca o navio sozinho quando a cena de abordagem volta pro mar.
##
## SEM NAVIO INIMIGO DE VERDADE AINDA (nenhum NPC com IA existe no mapa --
## `ship_base.gd` já suporta `player_controlled = false`, mas "recebe
## comandos de IA no futuro" ainda não chegou): esta é a infraestrutura
## completa e testável (vulnerabilidade, marcador, troca de cena, resolução
## de Reversal), pronta pra ligar no primeiro navio inimigo que existir.
## Testado nesta rodada instanciando um `ship_base.tscn` de teste como alvo.

signal boarding_started

const VULNERABLE_THRESHOLD: float = 0.25

## Retrato do confronto, montado em `start_boarding()` e lido por
## `boarding_battle_scene.gd` -- nomes/potências já calculadas, a cena de
## batalha só exibe e resolve, não recalcula nada de novo.
var pending: Dictionary = {}


func is_vulnerable(ship: Node2D) -> bool:
	if ship == null or not ("hull" in ship) or not ("max_hull" in ship):
		return false
	if ship.max_hull <= 0.0:
		return false
	return ship.hull <= ship.max_hull * VULNERABLE_THRESHOLD


## Potência do atacante: base 1.0 + Liderança (atributo, `CaptainAttributes`)
## + bônus de Liderança de equipamento (brincos/trajes, `CaptainInventory`)
## + o multiplicador de dano dos canhões equipados -- Liderança e Trajes
## concedem o "Reversal" pedido explicitamente contra navio mais forte (ver
## `_roll_outcome()`), o resto da fórmula já eram números reais existentes
## no jogo (só nunca combinados num confronto até agora).
func _attacker_power(ship: Node2D) -> float:
	var leadership_attr: int = CaptainAttributes.leadership
	var captain_bonuses: Dictionary = CaptainInventory.get_captain_bonuses()
	var cannon_mult: float = ship.cannon_damage_mult if ("cannon_damage_mult" in ship) else 1.0
	return 1.0 + leadership_attr * 0.04 + captain_bonuses.get("leadership_bonus", 0.0) * 0.015 + (cannon_mult - 1.0) * 0.5


## Potência do alvo: só o que o `ship_base.gd` dele já expõe -- sem
## equipamento de capitão (NPC não tem ficha de capitão ainda), só o
## multiplicador de canhão que ele estiver carregando.
func _defender_power(ship: Node2D) -> float:
	var cannon_mult: float = ship.cannon_damage_mult if ("cannon_damage_mult" in ship) else 1.0
	return 1.0 + (cannon_mult - 1.0) * 0.5


func start_boarding(attacker_ship: Node2D, target_ship: Node2D) -> void:
	# O navio do jogador não sobrevive à troca de cena (igual a entrar na
	# cidade) -- salva posição/casco/suprimento em `GameManager` do mesmo
	# jeito que `ocean_map.gd._enter_tortuga()` já faz, pra
	# `_restore_ship_state()` recolocar tudo sozinho quando a cena de
	# abordagem voltar pro mar.
	GameManager.saved_ship_position = attacker_ship.global_position
	GameManager.saved_hull = attacker_ship.hull
	GameManager.saved_supply = attacker_ship.supply

	var attacker_power: float = _attacker_power(attacker_ship)
	var defender_power: float = _defender_power(target_ship)
	# Chance de Reversal: só existe quando o alvo é mais forte (senão não é
	# "virar o jogo contra um navio mais forte", é só ganhar normal) --
	# escala com Liderança (atributo + equipamento), tetada em 35% pra nunca
	# virar garantido.
	var leadership_attr: int = CaptainAttributes.leadership
	var leadership_gear: float = CaptainInventory.get_captain_bonuses().get("leadership_bonus", 0.0)
	var reversal_chance: float = clampf(leadership_attr * 0.03 + leadership_gear * 0.01, 0.0, 0.35)

	pending = {
		"attacker_power": attacker_power,
		"defender_power": defender_power,
		"reversal_chance": reversal_chance if defender_power > attacker_power else 0.0,
		"target_name": target_ship.name,
	}
	boarding_started.emit()
	SceneTransitionManager.change_scene("res://scenes/combat/boarding_battle_scene.tscn")


## Resolve o confronto -- chamado pela cena de batalha quando o jogador
## confirma o ataque. Retorna {"outcome": "vitoria"/"derrota"/"reversal",
## "roll": float} pra tela mostrar o resultado.
func resolve() -> Dictionary:
	var attacker: float = pending.get("attacker_power", 1.0)
	var defender: float = pending.get("defender_power", 1.0)
	var ratio: float = attacker / maxf(defender, 0.01)
	var win_chance: float = clampf(0.5 + (ratio - 1.0) * 0.3, 0.1, 0.9)

	var roll: float = randf()
	if roll <= win_chance:
		return {"outcome": "vitoria", "roll": roll}

	var reversal_chance: float = pending.get("reversal_chance", 0.0)
	if reversal_chance > 0.0 and randf() <= reversal_chance:
		return {"outcome": "reversal", "roll": roll}

	return {"outcome": "derrota", "roll": roll}
