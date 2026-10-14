extends Node
## Autoload: refino de equipamento (+0 a +15), estilo Lineage 2/Ragnarok/
## Grand Chase. `PlayerInventory.refine_instance()` chama `refine_item()`
## aqui pra decidir o resultado -- quem cobra/consome Pedra de
## Refino/Pergaminho de Proteção é o `PlayerInventory`, este arquivo só
## sabe de chance e risco, não de inventário.

## +1 a +3: zona segura, nunca falha. +4 a +7: falha regride 1 nível, nunca
## destrói. +8 a +12: falha sem pergaminho tem 50% de ir pra +0 e 50% de
## destruir. +13 a +15: falha sem pergaminho destrói na hora.
const MAX_LEVEL: int = 15

## Índice 0 = chance de alcançar +1, índice 14 = chance de alcançar +15.
const SUCCESS_RATES: Array[float] = [
	100.0, 100.0, 100.0,
	80.0, 70.0, 60.0, 50.0,
	40.0, 35.0, 30.0, 25.0, 20.0,
	15.0, 10.0, 5.0,
]

## Bônus percentual DAQUELE nível específico -- `stat_multiplier_for()`
## multiplica (não soma) nível a nível, por isso "exponencial": +15 não é
## 15 vezes algum bônus fixo, é o produto composto de 7 passos de 8%, mais 5
## de 15%, mais 3 de 25%.
func _rate_for_level(level: int) -> float:
	if level <= 7:
		return 0.08
	elif level <= 12:
		return 0.15
	return 0.25


func success_rate_for(target_level: int) -> float:
	if target_level < 1 or target_level > MAX_LEVEL:
		return 0.0
	return SUCCESS_RATES[target_level - 1]


## Multiplicador total de atributo no nível pedido (1.0 = sem bônus, nível 0).
func stat_multiplier_for(level: int) -> float:
	var mult: float = 1.0
	for lvl in range(1, level + 1):
		mult *= 1.0 + _rate_for_level(lvl)
	return mult


## Tenta subir `item_data["refine_level"]` em 1 -- MUTA o dicionário recebido
## direto (Dictionary é referência em GDScript), então quem chama não
## precisa reatribuir o retorno pra aplicar o novo nível.
##
## Retorno: {"outcome", "new_level", "destroyed"}. `outcome` é um de:
## "max_level" (já no +15), "success", "fail_regress" (perdeu 1 nível),
## "fail_reset" (foi pra +0), "fail_destroyed" (sumiu) ou "fail_protected"
## (pergaminho segurou a queda, fica no nível atual).
func refine_item(item_data: Dictionary, protection_scroll_used: bool) -> Dictionary:
	var current_level: int = item_data.get("refine_level", 0)
	if current_level >= MAX_LEVEL:
		return {"outcome": "max_level", "new_level": current_level, "destroyed": false}

	var target_level: int = current_level + 1
	var rate: float = success_rate_for(target_level)
	var roll: float = randf() * 100.0

	if roll <= rate:
		item_data["refine_level"] = target_level
		return {"outcome": "success", "new_level": target_level, "destroyed": false}

	# Zona +4 a +7: regride 1 nível, nunca destrói -- pergaminho não muda nada
	# aqui, porque não existe risco de destruição pra proteger.
	if target_level <= 7:
		var new_level: int = maxi(0, current_level - 1)
		item_data["refine_level"] = new_level
		return {"outcome": "fail_regress", "new_level": new_level, "destroyed": false}

	if protection_scroll_used:
		return {"outcome": "fail_protected", "new_level": current_level, "destroyed": false}

	# Zona +8 a +12: metade das vezes só reseta, metade destrói.
	if target_level <= 12:
		if randf() < 0.5:
			item_data["refine_level"] = 0
			return {"outcome": "fail_reset", "new_level": 0, "destroyed": false}
		return {"outcome": "fail_destroyed", "new_level": current_level, "destroyed": true}

	# Zona +13 a +15: destruição instantânea sem pergaminho.
	return {"outcome": "fail_destroyed", "new_level": current_level, "destroyed": true}
