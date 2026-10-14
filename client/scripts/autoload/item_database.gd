extends Node
## Autoload: catálogo de todo item naval fabricável -- 3 famílias pedidas:
## Catálogo Gótico de Armas Navais (Vela/Casco/Proa/Canhão, Tiers I-IV),
## Catálogo de Munições Fantásticas (9 tipos, sem tier) e Relíquias
## Místicas em Grade Gótica (4 relíquias distintas, sem tier). Leme também
## virou equipável aqui (`SHIP_SLOTS` em `player_inventory.gd` pede os 5
## slots do Galeão, mas as seções 1/2 do pedido não descrevem catálogo nem
## receita pra Leme) -- 2 itens simples inferidos pra fechar o conjunto,
## sinalizados abaixo.
##
## Cada item: {id, name, category (= slot do Galeão ou "municao", que não
## tem slot no navio), tier (0 = sem tier), stats}. `stats` são bônus
## somados em cima da base do navio por `ship_base.gd.recalc_equipment_bonuses()`:
## `hull_bonus`, `cargo_bonus`, `speed_bonus`, `damage_mult_bonus`.
##
## `RECIPES`: id -> {output, station ("forja"/"estaleiro"), materials}.
## Receitas em Tier são geradas em loop a partir de `_TIER_MATERIALS`, não
## escritas 4 vezes à mão.

var ITEMS: Dictionary = {}
var RECIPES: Dictionary = {}

## Nome de exibição de cada tier.
const TIER_NAMES: Array[String] = ["I", "II", "III", "IV"]

## Materiais do "Catálogo Gótico de Armas Navais" por categoria/tier -- índice
## 0 = Tier I .. 3 = Tier IV. Cada entrada já é o dicionário de materiais
## daquele craft.
const _TIER_MATERIALS: Dictionary = {
	"armamento": [
		{"Liga de Ferro": 3, "Pólvora": 2, "Essência de Monstro Marinho": 1},
		{"Liga de Cobre": 3, "Pólvora": 3, "Essência de Monstro Marinho": 2},
		{"Liga de Ouro": 3, "Pólvora": 4, "Essência de Monstro Marinho": 3},
		{"Liga de Ouro": 5, "Pólvora": 6, "Essência de Monstro Marinho": 5},
	],
	"vela": [
		{"Lona": 3, "Cordame": 2, "Vento Rúnico": 1},
		{"Couro": 3, "Cordame": 3, "Vento Rúnico": 2},
		{"Seda": 3, "Cordame": 4, "Vento Rúnico": 3},
		{"Seda": 5, "Cordame": 6, "Vento Rúnico": 5},
	],
	"casco": [
		{"Madeira de Carvalho": 4, "Placas de Ferro": 2},
		{"Madeira de Carvalho": 6, "Placas de Ferro": 4},
		{"Escamas de Kraken": 4, "Placas de Ferro": 6},
		{"Escamas de Kraken": 7, "Placas de Ferro": 9},
	],
	"proa": [
		{"Madeira Nobre": 3, "Relíquia de Osso": 1},
		{"Madeira Nobre": 5, "Relíquia de Osso": 2},
		{"Madeira Nobre": 5, "Relíquia de Ouro": 2},
		{"Madeira Nobre": 8, "Relíquia de Ouro": 3},
	],
}

## Bônus por tier (índice 0 = Tier I), somados em `ship_base.gd`.
const _TIER_STATS: Dictionary = {
	"armamento": [{"damage_mult_bonus": 0.0}, {"damage_mult_bonus": 0.3}, {"damage_mult_bonus": 0.65}, {"damage_mult_bonus": 1.0}],
	"vela": [{"speed_bonus": 0.0}, {"speed_bonus": 15.0}, {"speed_bonus": 30.0}, {"speed_bonus": 50.0}],
	"casco": [{"hull_bonus": 0.0, "cargo_bonus": 0.0}, {"hull_bonus": 200.0, "cargo_bonus": 20.0}, {"hull_bonus": 450.0, "cargo_bonus": 40.0}, {"hull_bonus": 800.0, "cargo_bonus": 70.0}],
	"proa": [{"speed_bonus": 0.0}, {"speed_bonus": 5.0}, {"speed_bonus": 10.0}, {"speed_bonus": 18.0}],
}

const _TIER_DISPLAY_NAMES: Dictionary = {
	"armamento": "Canhão",
	"vela": "Vela",
	"casco": "Casco",
	"proa": "Proa",
}

## "Catálogo de Munições Fantásticas": sem slot no navio (nenhum dos 5 slots
## do Galeão é de munição), fica guardada no inventário pra quando existir
## um sistema de bordada por tipo de bala.
const _AMMO: Array[Dictionary] = [
	{"id": "municao_polvora", "name": "Munição de Pólvora", "materials": {"Esfera de Ferro": 2, "Pólvora": 1}},
	{"id": "municao_fogo", "name": "Munição de Fogo", "materials": {"Esfera de Ferro": 2, "Minério de Fogo": 1}},
	{"id": "municao_gelo", "name": "Munição de Gelo", "materials": {"Esfera de Ferro": 2, "Minério de Gelo": 1}},
	{"id": "municao_veneno", "name": "Munição de Veneno", "materials": {"Esfera de Ferro": 2, "Minério de Veneno": 1}},
	{"id": "municao_prata", "name": "Munição de Prata", "materials": {"Esfera de Ferro": 2, "Minério de Prata": 1}},
	{"id": "municao_ouro", "name": "Munição de Ouro", "materials": {"Esfera de Ferro": 2, "Minério de Ouro": 1}},
	{"id": "municao_diamante", "name": "Munição de Diamante", "materials": {"Esfera de Ferro": 2, "Minério de Diamante": 1}},
	{"id": "municao_alma", "name": "Munição de Alma", "materials": {"Esfera de Ferro": 2, "Minério de Alma": 1}},
	{"id": "municao_cursada", "name": "Munição Cursada", "materials": {"Esfera de Ferro": 2, "Minério Amaldiçoado": 1}},
]

## "Relíquias Místicas em Grade Gótica": 4 relíquias distintas (o pedido diz
## "etc.", ficou em 4 pra cobrir os dois materiais-chave citados -- Essência
## de Ebenruth e Dente de Leviatã -- sem inflar o catálogo sem necessidade).
const _RELICS: Array[Dictionary] = [
	{"id": "relíquia_luz_ebenruth", "name": "Luz Divina de Ebenruth", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"hull_bonus": 150.0}},
	{"id": "relíquia_totem_tempestade", "name": "Totem de Tempestade", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"speed_bonus": 20.0}},
	{"id": "relíquia_dente_kraken", "name": "Dente de Kraken", "materials": {"Fragmentos Místicos": 3, "Dente de Leviatã": 2}, "stats": {"damage_mult_bonus": 0.15}},
	{"id": "relíquia_ancora_espectral", "name": "Âncora Espectral", "materials": {"Fragmentos Místicos": 5, "Dente de Leviatã": 3}, "stats": {"cargo_bonus": 30.0}},
]

## Leme: nem a seção 1 (catálogo) nem a seção 2 (receitas) do pedido
## descrevem esse slot, embora a seção 3 peça pra equipá-lo -- inferido pra
## fechar os 5 slots do Galeão, com o mesmo tema de madeira nobre + latão
## usado pra Proa.
const _HELM: Array[Dictionary] = [
	{"id": "leme_carvalho", "name": "Leme de Carvalho Reforçado", "materials": {"Madeira Nobre": 3, "Peças de Latão": 2}, "stats": {}},
	{"id": "leme_latao", "name": "Leme Ornamentado de Latão", "materials": {"Madeira Nobre": 5, "Peças de Latão": 4, "Vento Rúnico": 1}, "stats": {"speed_bonus": 5.0}},
]


func _ready() -> void:
	_register_tiered_catalog()
	_register_flat_catalog(_AMMO, "municao", "forja")
	_register_flat_catalog(_RELICS, "relíquia_ebenruth", "estaleiro")
	_register_flat_catalog(_HELM, "leme", "estaleiro")


func _register_tiered_catalog() -> void:
	for category in _TIER_MATERIALS:
		var station: String = "forja" if category == "armamento" else "estaleiro"
		var display: String = _TIER_DISPLAY_NAMES[category]
		for tier_index in 4:
			var tier_num: int = tier_index + 1
			var item_id: String = "%s_t%d" % [category, tier_num]
			var item_name: String = "%s Tier %s" % [display, TIER_NAMES[tier_index]]
			ITEMS[item_id] = {
				"id": item_id,
				"name": item_name,
				"category": category,
				"tier": tier_num,
				"stats": _TIER_STATS[category][tier_index],
			}
			RECIPES[item_id] = {
				"output": item_id,
				"station": station,
				"materials": _TIER_MATERIALS[category][tier_index],
			}


func _register_flat_catalog(entries: Array[Dictionary], category: String, station: String) -> void:
	for entry in entries:
		ITEMS[entry["id"]] = {
			"id": entry["id"],
			"name": entry["name"],
			"category": category,
			"tier": 0,
			"stats": entry.get("stats", {}),
		}
		RECIPES[entry["id"]] = {
			"output": entry["id"],
			"station": station,
			"materials": entry["materials"],
		}


func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


func get_recipe(item_id: String) -> Dictionary:
	return RECIPES.get(item_id, {})


## Receitas de uma categoria numa estação -- as abas do `CraftingModal` usam
## isso direto, uma chamada por aba.
func get_recipes_for(station: String, category: String) -> Array[String]:
	var result: Array[String] = []
	for item_id in RECIPES:
		var recipe: Dictionary = RECIPES[item_id]
		if recipe["station"] != station:
			continue
		if ITEMS[item_id]["category"] != category:
			continue
		result.append(item_id)
	result.sort()
	return result
