extends Node
## Autoload: materiais do jogador, itens fabricados (Porão do Navio / Mochila
## do Capitão) e o que está equipado no Galeão. Sem Sea Hunt (coleta no mar)
## de verdade ainda -- `_seed_materials()` dá um estoque inicial generoso de
## cada material citado nas receitas de `item_database.gd`, só pra dar o que
## fabricar e testar o fluxo inteiro (igual ao padrão já usado em
## `CaptainAttributes.available_points`).

signal changed

const STARTER_QTY: int = 15
const CANNON_SLOT_COUNT: int = 20

## Materiais de refino -- não vêm de nenhuma receita de craft, então não
## entram no `_seed_materials()` genérico; seedados à parte, com um estoque
## menor que `STARTER_QTY` pra "pedra de refino acaba rápido" ser visível.
const REFINE_STONE: String = "Pedra de Refino"
const PROTECTION_SCROLL: String = "Pergaminho de Proteção"
const REFINE_STARTER_QTY: int = 30
const PROTECTION_STARTER_QTY: int = 5

## Durabilidade estilo BDO: todo item nasce no máximo, refinar gasta um
## pouco mesmo quando dá certo (o metal/tecido sofre no processo), e gasta
## MUITO mais numa falha (o jato de pólvora/martelada que não deu certo
## estressa o material). Isso aqui é a durabilidade ATUAL -- some igual a
## uma barra de vida comum.
const MAX_DURABILITY: float = 100.0
const DURABILITY_COST_SUCCESS: float = 3.0
const DURABILITY_COST_FAILURE: float = 10.0

## Durabilidade MÁXIMA estilo BDO: diferente da atual acima, essa é o TETO
## da barra, e só uma FALHA de refino reduz ela (sucesso não mexe aqui --
## só o "estresse" de uma tentativa que deu errado desgasta a estrutura do
## item de um jeito que nem recuperar a durabilidade atual conserta). Nasce
## em `MAX_DURABILITY` (100) igual à atual, cai `MAX_DURABILITY_LOSS_ON_FAIL`
## por falha, com piso em `MAX_DURABILITY_FLOOR` (nunca chega a 0 -- um item
## "capenga" ainda deve dar pra equipar, só com uma barra bem mais curta).
## A Oficina de Manutenção (`RefinementModal`, botão "Reparar") devolve ao
## teto cheio por um custo em material.
const MAX_DURABILITY_LOSS_ON_FAIL: float = 5.0
const MAX_DURABILITY_FLOOR: float = 20.0
const REPAIR_KIT: String = "Kit de Reparo"
const REPAIR_KIT_STARTER_QTY: int = 5
const REPAIR_KIT_COST: int = 2

## Slots de peça única do Galeão (fora a grade de canhão, que é `equipped_cannons`).
const SHIP_SLOTS: Array[String] = ["vela", "casco", "leme", "proa", "relíquia_ebenruth"]
## Slots de equipamento do Capitão -- ficha do capitão, não o navio. Separado
## de `SHIP_SLOTS` porque um brinco não deveria mexer no casco do navio
## (`get_captain_bonuses()` é um total à parte de `get_total_bonuses()`).
const CAPTAIN_SLOTS: Array[String] = ["brincos", "colar", "anel", "cinto", "trajes", "grimorio"]

var materials: Dictionary = {}
## instance_id (String) -> {item_id, instance_id, rarity_id, display_name,
## stats, refine_level, float_value}. `instance_id` existe porque dois
## Canhões Tier I fabricados separados são objetos diferentes -- com
## `CraftingManager`, também podem ter raridade, Float e nome diferentes, e
## com `EnchantmentManager`, refino diferente. `stats` aqui já tem a
## raridade E o Float multiplicados (os dois são fixados no craft, não mudam
## depois); o bônus de REFINO é aplicado por cima dinamicamente em
## `get_total_bonuses()`/`get_captain_bonuses()`, não gravado aqui, porque
## `refine_level` muda ao longo da vida do item.
var crafted_items: Dictionary = {}
## slot (de `SHIP_SLOTS`) -> instance_id equipado ali, ou "" se vazio.
var equipped: Dictionary = {}
## slot (de `CAPTAIN_SLOTS`) -> instance_id equipado ali, ou "" se vazio.
var equipped_captain: Dictionary = {}
## índice 0..19 -> instance_id equipado naquele canhão, ou "" se vazio.
var equipped_cannons: Array[String] = []

var _next_instance_id: int = 1


func _ready() -> void:
	_seed_materials()
	for slot in SHIP_SLOTS:
		equipped[slot] = ""
	for slot in CAPTAIN_SLOTS:
		equipped_captain[slot] = ""
	equipped_cannons.resize(CANNON_SLOT_COUNT)
	equipped_cannons.fill("")


## Soma todo material citado em qualquer receita e dá `STARTER_QTY` de cada
## -- lê de `ItemDatabase.RECIPES` em vez de listar os ~26 materiais aqui de
## novo, pra nunca ficar fora de sincronia com as receitas de verdade.
func _seed_materials() -> void:
	for item_id in ItemDatabase.RECIPES:
		var recipe: Dictionary = ItemDatabase.RECIPES[item_id]
		for material_name in recipe["materials"]:
			if not materials.has(material_name):
				materials[material_name] = STARTER_QTY
	materials[REFINE_STONE] = REFINE_STARTER_QTY
	materials[PROTECTION_SCROLL] = PROTECTION_STARTER_QTY
	materials[REPAIR_KIT] = REPAIR_KIT_STARTER_QTY


func has_materials_for(item_id: String) -> bool:
	var recipe: Dictionary = ItemDatabase.get_recipe(item_id)
	if recipe.is_empty():
		return false
	for material_name in recipe["materials"]:
		var needed: int = recipe["materials"][material_name]
		if materials.get(material_name, 0) < needed:
			return false
	return true


## Consome os materiais, sorteia raridade E Float Value
## (`CraftingManager.roll_rarity()`/`roll_float_value()`) e acrescenta uma
## instância nova do item fabricado no Porão do Navio / Mochila do Capitão --
## nome e stats já vêm com os dois bônus aplicados (multiplicam em cadeia,
## raridade primeiro, Float depois). Retorna "" se faltou material.
func craft(item_id: String) -> String:
	if not has_materials_for(item_id):
		return ""
	var recipe: Dictionary = ItemDatabase.get_recipe(item_id)
	for material_name in recipe["materials"]:
		materials[material_name] -= recipe["materials"][material_name]

	var item: Dictionary = ItemDatabase.get_item(item_id)
	var rarity: Dictionary = CraftingManager.roll_rarity()
	var float_value: float = CraftingManager.roll_float_value()
	var display_name: String = CraftingManager.generate_name(item.get("name", item_id), rarity)
	var rarity_stats: Dictionary = CraftingManager.apply_rarity_stats(item.get("stats", {}), rarity)
	var float_mult: float = CraftingManager.float_stat_multiplier(float_value)
	var stats: Dictionary = {}
	for key in rarity_stats:
		stats[key] = rarity_stats[key] * float_mult

	var instance_id: String = "item_%d" % _next_instance_id
	_next_instance_id += 1
	crafted_items[instance_id] = {
		"item_id": item_id,
		"instance_id": instance_id,
		"rarity_id": rarity["id"],
		"display_name": display_name,
		"stats": stats,
		"durability": MAX_DURABILITY,
		"max_durability": MAX_DURABILITY,
		"float_value": float_value,
	}
	changed.emit()
	return instance_id


## Itens fabricados e NÃO equipados em lugar nenhum, da categoria pedida --
## é o que o `InventoryPickerSubmodal` lista pra um slot do Galeão/Capitão.
func get_unequipped_for_category(category: String) -> Array[Dictionary]:
	var equipped_ids: Dictionary = {}
	for slot in SHIP_SLOTS:
		if equipped[slot] != "":
			equipped_ids[equipped[slot]] = true
	for slot in CAPTAIN_SLOTS:
		if equipped_captain[slot] != "":
			equipped_ids[equipped_captain[slot]] = true
	for cannon_id in equipped_cannons:
		if cannon_id != "":
			equipped_ids[cannon_id] = true

	var result: Array[Dictionary] = []
	for instance_id in crafted_items:
		if equipped_ids.has(instance_id):
			continue
		var entry: Dictionary = crafted_items[instance_id]
		var item: Dictionary = ItemDatabase.get_item(entry["item_id"])
		if item.get("category", "") == category:
			result.append(entry)
	return result


func equip_slot(slot: String, instance_id: String) -> void:
	if not SHIP_SLOTS.has(slot):
		return
	equipped[slot] = instance_id
	changed.emit()


func equip_captain_slot(slot: String, instance_id: String) -> void:
	if not CAPTAIN_SLOTS.has(slot):
		return
	equipped_captain[slot] = instance_id
	changed.emit()


func equip_cannon(index: int, instance_id: String) -> void:
	if index < 0 or index >= CANNON_SLOT_COUNT:
		return
	equipped_cannons[index] = instance_id
	changed.emit()


## Custo em Pedra de Refino por tentativa -- cresce com a zona de risco do
## nível-alvo, não é um número fixo (refinar além de +12 custa mais que
## refinar de +1 a +3). Público porque `RefinementModal` mostra esse custo
## antes de tentar, não só no momento de gastar.
func refine_stone_cost(target_level: int) -> int:
	if target_level <= 7:
		return 1
	elif target_level <= 12:
		return 2
	return 3


## Se dá pra tentar refinar: tem o item, não está no +15, e tem material
## suficiente pro custo (e pro pergaminho, se for usar um). A UI de refino
## chama isso pra desabilitar o botão "Tentar Refino" antes mesmo de tentar.
func can_refine(instance_id: String, use_protection: bool) -> bool:
	if not crafted_items.has(instance_id):
		return false
	var level: int = crafted_items[instance_id].get("refine_level", 0)
	if level >= EnchantmentManager.MAX_LEVEL:
		return false
	if materials.get(REFINE_STONE, 0) < refine_stone_cost(level + 1):
		return false
	if use_protection and materials.get(PROTECTION_SCROLL, 0) < 1:
		return false
	return true


## Consome Pedra de Refino (e Pergaminho de Proteção, se pedido) e chama
## `EnchantmentManager.refine_item()` -- se o resultado destrói o item,
## também desequipa (de onde quer que estivesse) e apaga de `crafted_items`.
## Retorna o mesmo dicionário de `refine_item()`, ou `{"outcome": "cannot"}`
## se `can_refine()` já tivesse recusado.
func refine_instance(instance_id: String, use_protection: bool) -> Dictionary:
	if not can_refine(instance_id, use_protection):
		return {"outcome": "cannot", "new_level": 0, "destroyed": false}

	var entry: Dictionary = crafted_items[instance_id]
	var target_level: int = entry.get("refine_level", 0) + 1
	materials[REFINE_STONE] -= refine_stone_cost(target_level)
	if use_protection:
		materials[PROTECTION_SCROLL] -= 1

	var result: Dictionary = EnchantmentManager.refine_item(entry, use_protection)
	if result["destroyed"]:
		_unequip_everywhere(instance_id)
		crafted_items.erase(instance_id)
	else:
		var is_success: bool = result["outcome"] == "success"
		var cost: float = DURABILITY_COST_SUCCESS if is_success else DURABILITY_COST_FAILURE
		var max_dur: float = entry.get("max_durability", MAX_DURABILITY)
		if not is_success:
			# BDO style: só FALHA desgasta o TETO -- sucesso só gasta da barra
			# atual (já tratado acima, igual sempre foi). Nunca passa do piso
			# (`MAX_DURABILITY_FLOOR`), pra um item muito refinado não virar
			# inutilizável de vez só de apanhar tentando subir de novo.
			max_dur = maxf(MAX_DURABILITY_FLOOR, max_dur - MAX_DURABILITY_LOSS_ON_FAIL)
			entry["max_durability"] = max_dur
		entry["durability"] = clampf(entry.get("durability", MAX_DURABILITY) - cost, 0.0, max_dur)
	changed.emit()
	return result


func get_durability(instance_id: String) -> float:
	if instance_id == "" or not crafted_items.has(instance_id):
		return 0.0
	return crafted_items[instance_id].get("durability", MAX_DURABILITY)


func get_max_durability(instance_id: String) -> float:
	if instance_id == "" or not crafted_items.has(instance_id):
		return MAX_DURABILITY
	return crafted_items[instance_id].get("max_durability", MAX_DURABILITY)


## Oficina de Manutenção (`RefinementModal`): repõe o TETO de volta a
## `MAX_DURABILITY` (não só a barra atual -- `repair_instance` já faria isso
## de um jeito mais barato se fosse só a atual; aqui é especificamente o
## reparo estrutural pedido, "recuperar a durabilidade máxima").
func can_repair(instance_id: String) -> bool:
	if not crafted_items.has(instance_id):
		return false
	if get_max_durability(instance_id) >= MAX_DURABILITY:
		return false
	return materials.get(REPAIR_KIT, 0) >= REPAIR_KIT_COST


func repair_max_durability(instance_id: String) -> bool:
	if not can_repair(instance_id):
		return false
	materials[REPAIR_KIT] -= REPAIR_KIT_COST
	var entry: Dictionary = crafted_items[instance_id]
	entry["max_durability"] = MAX_DURABILITY
	entry["durability"] = MAX_DURABILITY
	changed.emit()
	return true


func _unequip_everywhere(instance_id: String) -> void:
	for slot in SHIP_SLOTS:
		if equipped[slot] == instance_id:
			equipped[slot] = ""
	for slot in CAPTAIN_SLOTS:
		if equipped_captain[slot] == instance_id:
			equipped_captain[slot] = ""
	for i in equipped_cannons.size():
		if equipped_cannons[i] == instance_id:
			equipped_cannons[i] = ""


## Nome com prefixo de raridade embutido (ex: "Canhão Abissal Tier I da
## Devastação") e, se refinado, o prefixo de nível na frente (ex: "[+12]
## Canhão de Ouro") -- o que a UI deveria mostrar em vez do `item_id`/nome-base.
func get_item_name(instance_id: String) -> String:
	if instance_id == "" or not crafted_items.has(instance_id):
		return ""
	var entry: Dictionary = crafted_items[instance_id]
	var name: String = entry.get("display_name", "")
	var level: int = entry.get("refine_level", 0)
	if level > 0:
		return "[+%d] %s" % [level, name]
	return name


func get_refine_level(instance_id: String) -> int:
	if instance_id == "" or not crafted_items.has(instance_id):
		return 0
	return crafted_items[instance_id].get("refine_level", 0)


func get_float_value(instance_id: String) -> float:
	if instance_id == "" or not crafted_items.has(instance_id):
		return 0.0
	return crafted_items[instance_id].get("float_value", 0.0)


## "Float: 0.990 (Perfeito)" -- linha pronta pra colar num tooltip, pedida
## explicitamente ("exiba o valor do Float e a classificação... no
## Tooltip").
func get_float_tooltip_line(instance_id: String) -> String:
	if instance_id == "" or not crafted_items.has(instance_id):
		return ""
	var value: float = get_float_value(instance_id)
	return "Float: %.3f (%s)" % [value, CraftingManager.float_label(value)]


func get_item_icon(instance_id: String) -> Texture2D:
	if instance_id == "" or not crafted_items.has(instance_id):
		return null
	var item: Dictionary = ItemDatabase.get_item(crafted_items[instance_id]["item_id"])
	return item.get("icon", null)


## Dicionário de `CraftingManager.RARITIES` (tem `id`/`name`/`color`/
## `lightning`) -- "" devolve White, pra quem for colorir um slot vazio não
## precisar checar nulo.
func get_item_rarity(instance_id: String) -> Dictionary:
	if instance_id == "" or not crafted_items.has(instance_id):
		return CraftingManager.get_rarity("white")
	return CraftingManager.get_rarity(crafted_items[instance_id].get("rarity_id", "white"))


## Soma os bônus (`hull_bonus`/`cargo_bonus`/`speed_bonus`/`damage_mult_bonus`)
## de tudo que está equipado -- `ship_base.gd.recalc_equipment_bonuses()`
## chama isso direto, sem duplicar a lógica de percorrer slots lá. Lê
## `entry["stats"]` (já multiplicado pela raridade daquela instância) e
## multiplica de novo pelo bônus de REFINO atual daquela instância --
## `ItemDatabase` só tem o bônus-base de referência, sem raridade nem refino.
func get_total_bonuses() -> Dictionary:
	var totals: Dictionary = {"hull_bonus": 0.0, "cargo_bonus": 0.0, "speed_bonus": 0.0, "damage_mult_bonus": 0.0}
	var instance_ids: Array = []
	for slot in SHIP_SLOTS:
		if equipped[slot] != "":
			instance_ids.append(equipped[slot])
	for cannon_id in equipped_cannons:
		if cannon_id != "":
			instance_ids.append(cannon_id)

	for instance_id in instance_ids:
		var entry: Dictionary = crafted_items.get(instance_id, {})
		if entry.is_empty():
			continue
		var stats: Dictionary = entry.get("stats", {})
		var refine_mult: float = EnchantmentManager.stat_multiplier_for(entry.get("refine_level", 0))
		for key in stats:
			if totals.has(key):
				totals[key] += stats[key] * refine_mult
	return totals


## Mesma lógica de `get_total_bonuses()`, mas pros 6 slots do CAPITÃO
## (`CAPTAIN_SLOTS`), somando `leadership_bonus`/`boarding_crit_bonus`/
## `node_speed_bonus`/`armor_pen_bonus`/`elemental_damage_bonus` -- um brinco
## ou colar nunca deveria entrar no total do navio, por isso é uma função
## (e um total) à parte, não um `if` a mais dentro de `get_total_bonuses()`.
func get_captain_bonuses() -> Dictionary:
	var totals: Dictionary = {
		"leadership_bonus": 0.0, "boarding_crit_bonus": 0.0, "node_speed_bonus": 0.0,
		"armor_pen_bonus": 0.0, "elemental_damage_bonus": 0.0,
	}
	for slot in CAPTAIN_SLOTS:
		var instance_id: String = equipped_captain[slot]
		if instance_id == "":
			continue
		var entry: Dictionary = crafted_items.get(instance_id, {})
		if entry.is_empty():
			continue
		var stats: Dictionary = entry.get("stats", {})
		var refine_mult: float = EnchantmentManager.stat_multiplier_for(entry.get("refine_level", 0))
		for key in stats:
			if totals.has(key):
				totals[key] += stats[key] * refine_mult
	return totals
