extends Node
## Autoload: inventário DESTRUÍVEL do Galeão -- Casco/Proa/Velas/Canhões/
## Munição/Arpão/Relíquia/Leme, mais os MATERIAIS BRUTOS (o porão de carga
## físico, de onde sai tanto o que o navio usa quanto o que o Capitão gasta
## pra fabricar o próprio equipamento -- ver `CaptainInventory.craft()`).
##
## SEPARAÇÃO EXPLÍCITA PEDIDA: isto aqui é tudo que SOME quando o navio
## afunda (sem sistema de afundamento de verdade ainda -- só a separação de
## dados, pronta pra quando existir). `CaptainInventory` é o espelho
## permanente (Capitão/joias/trajes), nunca tocado por esse processo.
##
## Antes desta rodada, isto e `CaptainInventory` eram um autoload só
## (`PlayerInventory`) com dois conjuntos de slot dentro -- 2 arquivos com
## `craft()`/refino/durabilidade praticamente duplicados é mais simples de
## acompanhar do que um `if captain_or_ship` espalhado por toda função,
## consistente com o resto do projeto (duplicar em vez de generalizar cedo
## demais).

signal changed

const STARTER_QTY: int = 15
const CANNON_SLOT_COUNT: int = 20

const REFINE_STONE: String = "Pedra de Refino"
const PROTECTION_SCROLL: String = "Pergaminho de Proteção"
const REFINE_STARTER_QTY: int = 30
const PROTECTION_STARTER_QTY: int = 5

const MAX_DURABILITY: float = 100.0
const DURABILITY_COST_SUCCESS: float = 3.0
const DURABILITY_COST_FAILURE: float = 10.0
const MAX_DURABILITY_LOSS_ON_FAIL: float = 5.0
const MAX_DURABILITY_FLOOR: float = 20.0
const REPAIR_KIT: String = "Kit de Reparo"
const REPAIR_KIT_STARTER_QTY: int = 5
const REPAIR_KIT_COST: int = 2

const SHIP_SLOTS: Array[String] = ["vela", "casco", "leme", "proa", "relíquia_ebenruth"]

## Materiais brutos -- compartilhados com `CaptainInventory.craft()` (o
## Capitão também gasta madeira/prata/etc daqui, só o RESULTADO fabricado é
## que vai pro inventário permanente dele).
var materials: Dictionary = {}
## instance_id ("s_%d") -> {item_id, instance_id, rarity_id, display_name,
## stats, durability, max_durability, float_value, refine_level}. Só itens
## de categoria do NAVIO (armamento/vela/casco/proa/relíquia_ebenruth/leme/
## municao/arpao) -- itens do Capitão vivem em `CaptainInventory.crafted_items`.
var crafted_items: Dictionary = {}
var equipped: Dictionary = {}
var equipped_cannons: Array[String] = []

var _next_instance_id: int = 1


func _ready() -> void:
	_seed_materials()
	for slot in SHIP_SLOTS:
		equipped[slot] = ""
	equipped_cannons.resize(CANNON_SLOT_COUNT)
	equipped_cannons.fill("")


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


## Só fabrica item de categoria do NAVIO -- `CraftingModal` já só mostra
## receitas da estação/categoria certa em cada aba, então isto nunca é
## chamado com um `item_id` do Capitão na prática, mas o `assert` deixa o
## erro óbvio se algum dia acontecer, em vez de criar um item fantasma.
func craft(item_id: String) -> String:
	var item: Dictionary = ItemDatabase.get_item(item_id)
	if item.is_empty() or ItemDatabase.is_captain_category(item.get("category", "")):
		return ""
	if not has_materials_for(item_id):
		return ""
	var recipe: Dictionary = ItemDatabase.get_recipe(item_id)
	for material_name in recipe["materials"]:
		materials[material_name] -= recipe["materials"][material_name]

	var rarity: Dictionary = CraftingManager.roll_rarity()
	var float_value: float = CraftingManager.roll_float_value()
	var display_name: String = CraftingManager.generate_name(item.get("name", item_id), rarity)
	var rarity_stats: Dictionary = CraftingManager.apply_rarity_stats(item.get("stats", {}), rarity)
	var float_mult: float = CraftingManager.float_stat_multiplier(float_value)
	var stats: Dictionary = {}
	for key in rarity_stats:
		stats[key] = rarity_stats[key] * float_mult

	var instance_id: String = "s_%d" % _next_instance_id
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


func get_unequipped_for_category(category: String) -> Array[Dictionary]:
	var equipped_ids: Dictionary = {}
	for slot in SHIP_SLOTS:
		if equipped[slot] != "":
			equipped_ids[equipped[slot]] = true
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


func equip_cannon(index: int, instance_id: String) -> void:
	if index < 0 or index >= CANNON_SLOT_COUNT:
		return
	equipped_cannons[index] = instance_id
	changed.emit()


func refine_stone_cost(target_level: int) -> int:
	if target_level <= 7:
		return 1
	elif target_level <= 12:
		return 2
	return 3


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
	for i in equipped_cannons.size():
		if equipped_cannons[i] == instance_id:
			equipped_cannons[i] = ""


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


func get_item_rarity(instance_id: String) -> Dictionary:
	if instance_id == "" or not crafted_items.has(instance_id):
		return CraftingManager.get_rarity("white")
	return CraftingManager.get_rarity(crafted_items[instance_id].get("rarity_id", "white"))


## Soma os bônus de tudo equipado no navio (peça única + canhões) --
## `ship_base.gd.recalc_equipment_bonuses()` chama isso direto. As 4 chaves
## de sempre (`hull_bonus`/`cargo_bonus`/`speed_bonus`/`damage_mult_bonus`)
## continuam fixas no total pra não quebrar quem já lê essas 4; as novas do
## dicionário de status avançado (`reload_speed_bonus`/`turn_rate_bonus`/
## `braking_bonus`/`wind_resistance_bonus`/`armor_pen_bonus`) entram
## dinamicamente, só aparecendo no total se algum item equipado tiver essa
## chave -- não precisam de uma entrada "0.0" fixa pra existir.
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
			totals[key] = totals.get(key, 0.0) + stats[key] * refine_mult
	return totals
