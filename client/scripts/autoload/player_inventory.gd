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

## Slots de peça única do Galeão (fora a grade de canhão, que é `equipped_cannons`).
const SHIP_SLOTS: Array[String] = ["vela", "casco", "leme", "proa", "relíquia_ebenruth"]

var materials: Dictionary = {}
## instance_id (String) -> {item_id, instance_id, rarity_id, display_name,
## stats}. `instance_id` existe porque dois Canhões Tier I fabricados
## separados são objetos diferentes -- com `CraftingManager`, também podem
## ter raridade e nome diferentes. `stats` aqui já é o bônus-base
## multiplicado pela raridade ROLADA NESSA INSTÂNCIA, não o `stats` genérico
## de `ItemDatabase` (que é só o bônus de referência do item branco).
var crafted_items: Dictionary = {}
## slot (de `SHIP_SLOTS`) -> instance_id equipado ali, ou "" se vazio.
var equipped: Dictionary = {}
## índice 0..19 -> instance_id equipado naquele canhão, ou "" se vazio.
var equipped_cannons: Array[String] = []

var _next_instance_id: int = 1


func _ready() -> void:
	_seed_materials()
	for slot in SHIP_SLOTS:
		equipped[slot] = ""
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


func has_materials_for(item_id: String) -> bool:
	var recipe: Dictionary = ItemDatabase.get_recipe(item_id)
	if recipe.is_empty():
		return false
	for material_name in recipe["materials"]:
		var needed: int = recipe["materials"][material_name]
		if materials.get(material_name, 0) < needed:
			return false
	return true


## Consome os materiais, sorteia a raridade (`CraftingManager.roll_rarity()`)
## e acrescenta uma instância nova do item fabricado no Porão do Navio /
## Mochila do Capitão -- nome e stats já vêm com o bônus de raridade
## aplicado. Retorna "" se faltou material.
func craft(item_id: String) -> String:
	if not has_materials_for(item_id):
		return ""
	var recipe: Dictionary = ItemDatabase.get_recipe(item_id)
	for material_name in recipe["materials"]:
		materials[material_name] -= recipe["materials"][material_name]

	var item: Dictionary = ItemDatabase.get_item(item_id)
	var rarity: Dictionary = CraftingManager.roll_rarity()
	var display_name: String = CraftingManager.generate_name(item.get("name", item_id), rarity)
	var stats: Dictionary = CraftingManager.apply_rarity_stats(item.get("stats", {}), rarity)

	var instance_id: String = "item_%d" % _next_instance_id
	_next_instance_id += 1
	crafted_items[instance_id] = {
		"item_id": item_id,
		"instance_id": instance_id,
		"rarity_id": rarity["id"],
		"display_name": display_name,
		"stats": stats,
	}
	changed.emit()
	return instance_id


## Itens fabricados e NÃO equipados em lugar nenhum, da categoria pedida --
## é o que o `InventoryPickerSubmodal` lista pra um slot do Galeão.
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


## Nome já com prefixo/sufixo de raridade (ex: "Canhão Abissal Tier I da
## Devastação") -- o que a UI deveria mostrar em vez do `item_id`/nome-base.
func get_item_name(instance_id: String) -> String:
	if instance_id == "" or not crafted_items.has(instance_id):
		return ""
	return crafted_items[instance_id].get("display_name", "")


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
## `entry["stats"]` (já multiplicado pela raridade daquela instância), não
## `ItemDatabase`, que só tem o bônus-base de referência.
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
		for key in stats:
			if totals.has(key):
				totals[key] += stats[key]
	return totals
