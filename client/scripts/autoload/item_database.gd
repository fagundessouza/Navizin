extends Node
## Autoload: catálogo de todo item fabricável do jogo -- peças do Galeão
## (Vela/Casco/Proa/Canhão em Tiers I-IV, Munições, Relíquias, Leme) e
## Equipamentos do Capitão (Brincos/Colares/Anéis/Cintos/Trajes em Tiers I-IV,
## Grimórios). Leme não tinha catálogo nem receita no pedido original (ver
## nota em `_HELM`); os 5 acessórios do Capitão também não existiam até esta
## rodada -- só tinham nomes cosméticos sem dado real em `STUB_INVENTORY`.
##
## Cada item: {id, name, category (= slot do Galeão/Capitão, ou "municao",
## que não tem slot em lugar nenhum ainda), tier (0 = sem tier), icon
## (Texture2D, carregado com `preload` -- os arquivos já existem no
## projeto), stats}.
##
## `stats` do Galeão (`hull_bonus`/`cargo_bonus`/`speed_bonus`/
## `damage_mult_bonus`) são somados por `ship_base.gd.recalc_equipment_bonuses()`.
## `stats` do Capitão (`leadership_bonus`/`boarding_crit_bonus`/
## `node_speed_bonus`/`armor_pen_bonus`) são somados por
## `PlayerInventory.get_captain_bonuses()` -- um sistema PARALELO, porque um
## brinco não deveria mexer no casco do navio. `elemental_damage_bonus`
## (Munição/Grimório) é só exibido por ora -- não existe ainda um sistema de
## combate ou de troca de munição pra consumir esse número, igual ao
## `cannon_damage_mult` do navio: o valor está certo, só não alimenta nada.
##
## `RECIPES`: id -> {output, station ("forja"/"estaleiro"/"boticario"/
## "feira"), materials}. Receitas em Tier são geradas em loop a partir de
## `_TIER_MATERIALS`, não escritas 4 vezes à mão.

var ITEMS: Dictionary = {}
var RECIPES: Dictionary = {}

const TIER_NAMES: Array[String] = ["I", "II", "III", "IV"]
const ICON_DIR: String = "res://assets/ui/icons/items/"

## Materiais por categoria/tier -- índice 0 = Tier I .. 3 = Tier IV.
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
	"brincos": [
		{"Prata": 2, "Pérola Negra": 1},
		{"Prata": 3, "Pérola Negra": 2},
		{"Ouro": 2, "Pérola Negra": 2},
		{"Ouro": 3, "Diamante Sombrio": 1},
	],
	"colar": [
		{"Prata": 2, "Osso de Leviatã": 1},
		{"Prata": 3, "Osso de Leviatã": 2},
		{"Ouro": 2, "Osso de Leviatã": 2},
		{"Ouro": 3, "Osso de Leviatã": 3},
	],
	"anel": [
		{"Prata": 2, "Bússola Fragmentada": 1},
		{"Prata": 3, "Bússola Fragmentada": 2},
		{"Ouro": 2, "Bússola Fragmentada": 2},
		{"Ouro": 3, "Bússola Fragmentada": 3},
	],
	"cinto": [
		{"Couro": 2, "Fivela de Bronze": 1},
		{"Couro": 3, "Fivela de Bronze": 2},
		{"Couro Reforçado": 2, "Fivela de Bronze": 3},
		{"Couro Reforçado": 3, "Fivela de Prata": 2},
	],
	"trajes": [
		{"Couro": 3, "Linho Encerado": 2},
		{"Couro Reforçado": 3, "Linho Encerado": 3},
		{"Couro Reforçado": 4, "Veludo Corsário": 2},
		{"Escamas de Kraken": 3, "Veludo Corsário": 4},
	],
}

## Bônus por tier (índice 0 = Tier I).
const _TIER_STATS: Dictionary = {
	"armamento": [{"damage_mult_bonus": 0.0}, {"damage_mult_bonus": 0.3, "armor_pen_bonus": 0.05}, {"damage_mult_bonus": 0.65, "armor_pen_bonus": 0.12}, {"damage_mult_bonus": 1.0, "armor_pen_bonus": 0.22}],
	"vela": [{"speed_bonus": 0.0}, {"speed_bonus": 15.0}, {"speed_bonus": 30.0}, {"speed_bonus": 50.0}],
	"casco": [{"hull_bonus": 0.0, "cargo_bonus": 0.0}, {"hull_bonus": 200.0, "cargo_bonus": 20.0}, {"hull_bonus": 450.0, "cargo_bonus": 40.0}, {"hull_bonus": 800.0, "cargo_bonus": 70.0}],
	"proa": [{"speed_bonus": 0.0}, {"speed_bonus": 5.0}, {"speed_bonus": 10.0}, {"speed_bonus": 18.0}],
	"brincos": [{"leadership_bonus": 0.0}, {"leadership_bonus": 5.0}, {"leadership_bonus": 12.0}, {"leadership_bonus": 22.0}],
	"colar": [{"boarding_crit_bonus": 0.0}, {"boarding_crit_bonus": 0.05}, {"boarding_crit_bonus": 0.12}, {"boarding_crit_bonus": 0.22}],
	"anel": [{"node_speed_bonus": 0.0}, {"node_speed_bonus": 8.0}, {"node_speed_bonus": 18.0}, {"node_speed_bonus": 32.0}],
	"cinto": [{"armor_pen_bonus": 0.0}, {"armor_pen_bonus": 0.08}, {"armor_pen_bonus": 0.18}, {"armor_pen_bonus": 0.32}],
	"trajes": [{"leadership_bonus": 0.0}, {"leadership_bonus": 4.0}, {"leadership_bonus": 10.0}, {"leadership_bonus": 18.0}],
}

const _TIER_DISPLAY_NAMES: Dictionary = {
	"armamento": "Canhão", "vela": "Vela", "casco": "Casco", "proa": "Proa",
	"brincos": "Brincos", "colar": "Colar", "anel": "Anel", "cinto": "Cinto", "trajes": "Trajes",
}

## Ícone por categoria: um só por tier pros 4 itens de peça do Galeão (não há
## arte dedicada por tier ainda), 4 distintos (um por tier, ordem de
## "fantasia" crescente) pros acessórios do Capitão -- extraídos da prancha
## `Gemini_Generated_Image...zb2.jpeg` que o pedido referenciou por nome de
## arquivo genérico.
const _CATEGORY_ICON: Dictionary = {
	"armamento": "armamento.png", "vela": "vela.png", "casco": "casco.png", "proa": "proa_figurehead.png",
}
const _TIER_ICONS: Dictionary = {
	"brincos": ["brincos_t1.png", "brincos_t2.png", "brincos_t3.png", "brincos_t4.png"],
	"colar": ["colar_t1.png", "colar_t2.png", "colar_t3.png", "colar_t4.png"],
	"anel": ["anel_t1.png", "anel_t2.png", "anel_t3.png", "anel_t4.png"],
	"cinto": ["cinto_t1.png", "cinto_t2.png", "cinto_t3.png", "cinto_t4.png"],
	"trajes": ["trajes_t1.png", "trajes_t2.png", "trajes_t3.png", "trajes_t4.png"],
}

## "Catálogo de Munições Fantásticas": sem slot em lugar nenhum ainda (nem
## do navio, nem do capitão) -- fica guardada no inventário pra quando
## existir bordada por tipo de bala. `elemental_damage_bonus` é só pra
## tooltip mostrar o dano elemental da munição, sem sistema de troca de
## bala pra consumir isso ainda.
const _AMMO: Array[Dictionary] = [
	{"id": "municao_polvora", "name": "Munição de Pólvora", "materials": {"Esfera de Ferro": 2, "Pólvora": 1}, "stats": {}},
	{"id": "municao_fogo", "name": "Munição de Fogo", "materials": {"Esfera de Ferro": 2, "Minério de Fogo": 1}, "stats": {"elemental_damage_bonus": 0.12}},
	{"id": "municao_gelo", "name": "Munição de Gelo", "materials": {"Esfera de Ferro": 2, "Minério de Gelo": 1}, "stats": {"elemental_damage_bonus": 0.12}},
	{"id": "municao_veneno", "name": "Munição de Veneno", "materials": {"Esfera de Ferro": 2, "Minério de Veneno": 1}, "stats": {"elemental_damage_bonus": 0.1}},
	{"id": "municao_prata", "name": "Munição de Prata", "materials": {"Esfera de Ferro": 2, "Minério de Prata": 1}, "stats": {"elemental_damage_bonus": 0.15}},
	{"id": "municao_ouro", "name": "Munição de Ouro", "materials": {"Esfera de Ferro": 2, "Minério de Ouro": 1}, "stats": {"elemental_damage_bonus": 0.15}},
	{"id": "municao_diamante", "name": "Munição de Diamante", "materials": {"Esfera de Ferro": 2, "Minério de Diamante": 1}, "stats": {"elemental_damage_bonus": 0.2}},
	{"id": "municao_alma", "name": "Munição de Alma", "materials": {"Esfera de Ferro": 2, "Minério de Alma": 1}, "stats": {"elemental_damage_bonus": 0.22}},
	{"id": "municao_cursada", "name": "Munição Cursada", "materials": {"Esfera de Ferro": 2, "Minério Amaldiçoado": 1}, "stats": {"elemental_damage_bonus": 0.25}},
]
const _AMMO_ICON: String = "municao.png"

## "Relíquias Místicas em Grade Gótica": 4 relíquias distintas (o pedido diz
## "etc.", ficou em 4 pra cobrir os dois materiais-chave citados -- Essência
## de Ebenruth e Dente de Leviatã). Movida pro Boticário na reestruturação
## urbana (seção 3) -- antes era fabricada no Estaleiro.
const _RELICS: Array[Dictionary] = [
	{"id": "relíquia_luz_ebenruth", "name": "Luz Divina de Ebenruth", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"hull_bonus": 150.0}, "icon": "relíquia_luz.png"},
	{"id": "relíquia_totem_tempestade", "name": "Totem de Tempestade", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"speed_bonus": 20.0}, "icon": "relíquia_totem.png"},
	{"id": "relíquia_dente_kraken", "name": "Dente de Kraken", "materials": {"Fragmentos Místicos": 3, "Dente de Leviatã": 2}, "stats": {"damage_mult_bonus": 0.15}, "icon": "relíquia_dente.png"},
	{"id": "relíquia_ancora_espectral", "name": "Âncora Espectral", "materials": {"Fragmentos Místicos": 5, "Dente de Leviatã": 3}, "stats": {"cargo_bonus": 30.0}, "icon": "relíquia_ancora.png"},
]

## Leme: nem a seção 1 (catálogo) nem a seção 2 (receitas) do pedido
## original de crafting descrevem esse slot, embora o pedido daquela rodada
## pedisse pra equipá-lo -- inferido pra fechar os 5 slots do Galeão, tema
## de madeira nobre + latão (mesmo de Proa).
const _HELM: Array[Dictionary] = [
	{"id": "leme_carvalho", "name": "Leme de Carvalho Reforçado", "materials": {"Madeira Nobre": 3, "Peças de Latão": 2}, "stats": {}},
	{"id": "leme_latao", "name": "Leme Ornamentado de Latão", "materials": {"Madeira Nobre": 5, "Peças de Latão": 4, "Vento Rúnico": 1}, "stats": {"speed_bonus": 5.0}},
]
const _HELM_ICON: String = "leme.png"

## Grimórios/Tomes: 3 especiais não-tiered (igual às Relíquias) -- extraídos
## da mesma prancha dos acessórios do Capitão.
const _GRIMOIRES: Array[Dictionary] = [
	{"id": "grimorio_caveira", "name": "Grimório da Caveira Dourada", "materials": {"Couro": 2, "Tinta Rúnica": 2}, "stats": {"elemental_damage_bonus": 0.1}, "icon": "grimorio_caveira.png"},
	{"id": "grimorio_acorrentado", "name": "Tomo Acorrentado das Marés", "materials": {"Couro Reforçado": 2, "Tinta Rúnica": 3}, "stats": {"elemental_damage_bonus": 0.16}, "icon": "grimorio_acorrentado.png"},
	{"id": "grimorio_atlas", "name": "Atlas Perdido do Corsário", "materials": {"Couro Reforçado": 3, "Tinta Rúnica": 4}, "stats": {"node_speed_bonus": 10.0}, "icon": "grimorio_atlas.png"},
]


func _ready() -> void:
	_register_tiered_catalog()
	_register_flat_catalog(_AMMO, "municao", "forja", _AMMO_ICON)
	_register_flat_catalog(_RELICS, "relíquia_ebenruth", "boticario", "")
	_register_flat_catalog(_HELM, "leme", "estaleiro", _HELM_ICON)
	_register_flat_catalog(_GRIMOIRES, "grimorio", "feira", "")


func _station_for(category: String) -> String:
	if category == "armamento":
		return "forja"
	if ["brincos", "colar", "anel", "cinto", "trajes"].has(category):
		return "feira"
	return "estaleiro"


func _register_tiered_catalog() -> void:
	for category in _TIER_MATERIALS:
		var station: String = _station_for(category)
		var display: String = _TIER_DISPLAY_NAMES[category]
		for tier_index in 4:
			var tier_num: int = tier_index + 1
			var item_id: String = "%s_t%d" % [category, tier_num]
			var item_name: String = "%s Tier %s" % [display, TIER_NAMES[tier_index]]
			var icon_file: String = _TIER_ICONS[category][tier_index] if _TIER_ICONS.has(category) else _CATEGORY_ICON.get(category, "")
			ITEMS[item_id] = {
				"id": item_id,
				"name": item_name,
				"category": category,
				"tier": tier_num,
				"icon": load(ICON_DIR + icon_file) if icon_file != "" else null,
				"stats": _TIER_STATS[category][tier_index],
			}
			RECIPES[item_id] = {
				"output": item_id,
				"station": station,
				"materials": _TIER_MATERIALS[category][tier_index],
			}


func _register_flat_catalog(entries: Array[Dictionary], category: String, station: String, default_icon_file: String) -> void:
	for entry in entries:
		var icon_file: String = entry.get("icon", default_icon_file)
		ITEMS[entry["id"]] = {
			"id": entry["id"],
			"name": entry["name"],
			"category": category,
			"tier": 0,
			"icon": load(ICON_DIR + icon_file) if icon_file != "" else null,
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
