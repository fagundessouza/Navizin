extends Node
## Autoload: inventário PERMANENTE do Capitão -- Brincos/Colares/Anéis/
## Cintos/Trajes/Equipamento Secundário. Não some quando o navio afunda
## (sem sistema de afundamento de verdade ainda -- só a separação de dados,
## pronta pra quando existir): "um anel no dedo do Capitão não vai pro
## fundo do mar junto com o casco."
##
## Fabricar aqui ainda GASTA material do porão físico do navio
## (`ShipInventory.materials` -- compartilhado, não duplicado: não faz
## sentido o Capitão ter um estoque de prata separado do navio que ele está
## navegando) -- só o RESULTADO fabricado (o anel pronto) é que entra no
## inventário permanente, não o material bruto usado pra fazê-lo.

signal changed

const REFINE_STONE: String = "Pedra de Refino"
const PROTECTION_SCROLL: String = "Pergaminho de Proteção"
const MAX_DURABILITY: float = 100.0
const DURABILITY_COST_SUCCESS: float = 3.0
const DURABILITY_COST_FAILURE: float = 10.0
const MAX_DURABILITY_LOSS_ON_FAIL: float = 5.0
const MAX_DURABILITY_FLOOR: float = 20.0
const REPAIR_KIT: String = "Kit de Reparo"
const REPAIR_KIT_COST: int = 2

const CAPTAIN_SLOTS: Array[String] = ["brincos", "colar", "anel", "cinto", "trajes", "secundaria"]

## instance_id ("c_%d") -> mesmo formato de `ShipInventory.crafted_items`.
## Prefixo diferente (`c_` vs `s_`) garante que os dois contadores de
## instância nunca colidem, já que agora são dois `_next_instance_id`
## independentes em vez de um só.
var crafted_items: Dictionary = {}
var equipped_captain: Dictionary = {}

var _next_instance_id: int = 1


func _ready() -> void:
	for slot in CAPTAIN_SLOTS:
		equipped_captain[slot] = ""


func has_materials_for(item_id: String) -> bool:
	return ShipInventory.has_materials_for(item_id)


## Só fabrica item de categoria do CAPITÃO -- gasta de
## `ShipInventory.materials` (porão físico do navio), guarda o resultado
## aqui (inventário permanente).
func craft(item_id: String) -> String:
	var item: Dictionary = ItemDatabase.get_item(item_id)
	if item.is_empty() or not ItemDatabase.is_captain_category(item.get("category", "")):
		return ""
	if not ShipInventory.has_materials_for(item_id):
		return ""
	var recipe: Dictionary = ItemDatabase.get_recipe(item_id)
	for material_name in recipe["materials"]:
		ShipInventory.materials[material_name] -= recipe["materials"][material_name]

	var rarity: Dictionary = CraftingManager.roll_rarity()
	var float_value: float = CraftingManager.roll_float_value()
	var display_name: String = CraftingManager.generate_name(item.get("name", item_id), rarity)
	var rarity_stats: Dictionary = CraftingManager.apply_rarity_stats(item.get("stats", {}), rarity)
	var float_mult: float = CraftingManager.float_stat_multiplier(float_value)
	var stats: Dictionary = {}
	for key in rarity_stats:
		stats[key] = rarity_stats[key] * float_mult

	var instance_id: String = "c_%d" % _next_instance_id
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
	for slot in CAPTAIN_SLOTS:
		if equipped_captain[slot] != "":
			equipped_ids[equipped_captain[slot]] = true

	var result: Array[Dictionary] = []
	for instance_id in crafted_items:
		if equipped_ids.has(instance_id):
			continue
		var entry: Dictionary = crafted_items[instance_id]
		var item: Dictionary = ItemDatabase.get_item(entry["item_id"])
		if item.get("category", "") == category:
			result.append(entry)
	return result


func equip_captain_slot(slot: String, instance_id: String) -> void:
	if not CAPTAIN_SLOTS.has(slot):
		return
	equipped_captain[slot] = instance_id
	changed.emit()


func refine_stone_cost(target_level: int) -> int:
	return ShipInventory.refine_stone_cost(target_level)


func can_refine(instance_id: String, use_protection: bool) -> bool:
	if not crafted_items.has(instance_id):
		return false
	var level: int = crafted_items[instance_id].get("refine_level", 0)
	if level >= EnchantmentManager.MAX_LEVEL:
		return false
	if ShipInventory.materials.get(REFINE_STONE, 0) < refine_stone_cost(level + 1):
		return false
	if use_protection and ShipInventory.materials.get(PROTECTION_SCROLL, 0) < 1:
		return false
	return true


func refine_instance(instance_id: String, use_protection: bool) -> Dictionary:
	if not can_refine(instance_id, use_protection):
		return {"outcome": "cannot", "new_level": 0, "destroyed": false}

	var entry: Dictionary = crafted_items[instance_id]
	var target_level: int = entry.get("refine_level", 0) + 1
	ShipInventory.materials[REFINE_STONE] -= refine_stone_cost(target_level)
	if use_protection:
		ShipInventory.materials[PROTECTION_SCROLL] -= 1

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
	return ShipInventory.materials.get(REPAIR_KIT, 0) >= REPAIR_KIT_COST


func repair_max_durability(instance_id: String) -> bool:
	if not can_repair(instance_id):
		return false
	ShipInventory.materials[REPAIR_KIT] -= REPAIR_KIT_COST
	var entry: Dictionary = crafted_items[instance_id]
	entry["max_durability"] = MAX_DURABILITY
	entry["durability"] = MAX_DURABILITY
	changed.emit()
	return true


func _unequip_everywhere(instance_id: String) -> void:
	for slot in CAPTAIN_SLOTS:
		if equipped_captain[slot] == instance_id:
			equipped_captain[slot] = ""


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


## Mesma lógica de `ShipInventory.get_total_bonuses()`, pros 6 slots do
## CAPITÃO -- um brinco ou colar nunca deveria entrar no total do navio,
## por isso é um total à parte (ver nota histórica no antigo
## `PlayerInventory.get_captain_bonuses()`, dividido nesta rodada).
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
			totals[key] = totals.get(key, 0.0) + stats[key] * refine_mult
	return totals
