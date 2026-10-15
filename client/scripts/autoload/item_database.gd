extends Node
## Autoload: catálogo de todo item fabricável do jogo.
##
## MODELO BASE vs QUALIDADE DE CRAFT (pedido explícito, estilo Albion): o que
## está aqui é só o MODELO -- a arte/estatística-base de cada peça (ex:
## "Canhão de Ferro"). A QUALIDADE (Normal/Bom/Excelente/Obra-Prima, o
## multiplicador e a borda) é sorteada em `CraftingManager.roll_rarity()` no
## momento de fabricar, em cima do modelo escolhido aqui -- são dois eixos
## independentes, não dois nomes pro mesmo número.
##
## CONTAGEM EXATA DE ASSETS (pedido explícito -- não inventar além do que
## existe fisicamente): cada categoria usa a quantidade REAL de arquivos que
## o usuário cortou em `~/Downloads/Tortuga/Items - <Categoria>/`, verificada
## pasta por pasta antes de escrever qualquer entrada aqui:
##   Canhões=4, Velas=4, Proa=4, Casco=4, Relíquias=4 (AJUSTADO NESTA RODADA:
##   uma rodada anterior tinha inventado 50 relíquias por combinação de nome
##   -- não existiam 50 arquivos, só 4. Corrigido pra usar só os 4 reais.)
##   Brincos=10, Colares=10, Anéis=10, Cintos=10, Trajes=10, Secundária=10.
## "Secundária" é uma categoria NOVA desta rodada que substitui o antigo
## slot "grimorio" (que só tinha 3 itens inventados sem pasta própria) --
## o usuário cortou 10 peças reais (grimórios, pistola, facão, mapa,
## bússola, poção, ídolo, totem) nessa pasta.
##
## Cada item: {id, name, category (= slot do Galeão/Capitão, ou "municao"/
## "arpao", que não têm slot ainda), tier (0 = sem modelo numerado), icon
## (Texture2D), stats}.

var ITEMS: Dictionary = {}
var RECIPES: Dictionary = {}

const ICON_DIR: String = "res://assets/ui/icons/items/"

## Quantos MODELOS reais cada categoria tem -- lido direto da contagem de
## arquivos em `~/Downloads/Tortuga/Items - <Categoria>/`, não um número
## escolhido à mão.
const _MODEL_COUNT: Dictionary = {
	"armamento": 4, "vela": 4, "casco": 4, "proa": 4,
	"brincos": 10, "colar": 10, "anel": 10, "cinto": 10, "trajes": 10, "secundaria": 10,
}

## Nome de cada modelo, na ordem exata do arquivo numerado (1..N) daquela
## pasta -- pra Canhão/Vela/Proa os nomes vieram literais do pedido do
## usuário; Casco não teve nomes dados, nomeado pela progressão visual
## (madeira simples -> reforçado -> escamado -> blindado com espinhos).
## Capitão: nomeado pelo que CADA ícone mostra de verdade (visto um por um),
## não "Modelo 1..10" genérico.
const _MODEL_NAMES: Dictionary = {
	"armamento": ["Normal", "Ferro", "Ouro", "Supremo"],
	"vela": ["Normal", "Aprimorada", "Real", "Suprema"],
	"proa": ["Madeira", "Aprimorada", "Ferro", "Real"],
	"casco": ["Madeira", "Reforçado", "Escamado", "Blindado"],
	"brincos": [
		"Argola de Presa", "Argola Rúnica", "Brinco de Caveira", "Pingente de Caveira",
		"Pérola Negra Pendente", "Âncora Pendente", "Presa Amuletada", "Âncora Gravada",
		"Gema Sombria", "Caveira Acorrentada",
	],
	"anel": [
		"Anel da Bússola", "Anel da Caveira", "Anel da Pérola Negra", "Anel do Selo Âncora",
		"Anel de Osso", "Anel da Gema Azul", "Anel do Ancoradouro", "Anel da Serpente",
		"Anel Rachado", "Anel da Garra Rubra",
	],
	"colar": [
		"Colar de Presa", "Colar da Caveira", "Colar da Âncora", "Colar da Gema Negra",
		"Colar da Bússola", "Colar do Corvo", "Colar das Presas Triplas", "Colar da Bússola Dourada",
		"Colar do Diamante Sombrio", "Colar da Presa do Dragão",
	],
	"cinto": [
		"Cinto de Couro Simples", "Cinto Reforçado", "Cinto da Caveira", "Cinto Amarrado",
		"Cinto Selado", "Cinto de Fivela Dupla", "Cinto com Bolsas", "Cinto de Correntes",
		"Cinto da Bússola Dourada", "Cinto do Kraken",
	],
	"trajes": [
		"Colete de Couro", "Casaco do Corsário", "Casaco de Oficial", "Colete Escamado",
		"Túnica de Combate", "Manto Encapuzado", "Sobretudo Dourado", "Armadura de Placas",
		"Casaco de Pele", "Cota de Malha",
	],
	"secundaria": [
		"Grimório da Caveira", "Navio Engarrafado", "Diário do Ancoradouro", "Mapa do Tesouro",
		"Bússola de Latão", "Pistola de Pederneira", "Facão Corsário", "Totem Amaldiçoado",
		"Poção Mística", "Ídolo Ancestral",
	],
}

const _TIER_DISPLAY_NAMES: Dictionary = {
	"armamento": "Canhão", "vela": "Vela", "casco": "Casco", "proa": "Proa",
}

## Materiais por categoria/modelo -- índice 0 = 1º modelo .. N-1 = último.
## Canhão/Vela/Casco/Proa mantêm a progressão de 4 passos já testada;
## Capitão (10 passos) interpola a mesma progressão de material em 10
## degraus mais graduais, reusando o MESMO POOL de materiais de sempre (não
## inventa material novo só pra preencher os 6 passos a mais).
const _MODEL_MATERIALS: Dictionary = {
	"armamento": [
		{"Liga de Ferro": 3, "Pólvora": 2, "Essência de Monstro Marinho": 1},
		{"Liga de Cobre": 3, "Pólvora": 3, "Essência de Monstro Marinho": 2},
		{"Liga de Ouro": 3, "Pólvora": 4, "Essência de Monstro Marinho": 3},
		{"Liga de Ouro": 5, "Pólvora": 6, "Essência de Monstro Marinho": 5},
	],
	"vela": [
		{"Lona": 3, "Cordame": 2, "Vento Rúnico": 1},
		{"Lona Reforçada": 3, "Cordame": 3, "Vento Rúnico": 2},
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
		{"Prata": 1, "Pérola Negra": 1}, {"Prata": 2, "Pérola Negra": 1}, {"Prata": 2, "Pérola Negra": 2}, {"Prata": 3, "Pérola Negra": 2},
		{"Ouro": 1, "Pérola Negra": 2}, {"Ouro": 2, "Pérola Negra": 2}, {"Ouro": 2, "Pérola Negra": 3}, {"Ouro": 3, "Pérola Negra": 3},
		{"Ouro": 3, "Diamante Sombrio": 1}, {"Ouro": 4, "Diamante Sombrio": 1},
	],
	"colar": [
		{"Prata": 1, "Osso de Leviatã": 1}, {"Prata": 2, "Osso de Leviatã": 1}, {"Prata": 2, "Osso de Leviatã": 2}, {"Prata": 3, "Osso de Leviatã": 2},
		{"Ouro": 1, "Osso de Leviatã": 2}, {"Ouro": 2, "Osso de Leviatã": 2}, {"Ouro": 2, "Osso de Leviatã": 3}, {"Ouro": 3, "Osso de Leviatã": 3},
		{"Ouro": 3, "Pérola Abissal": 1}, {"Ouro": 4, "Pérola Abissal": 1},
	],
	"anel": [
		{"Prata": 1, "Bússola Fragmentada": 1}, {"Prata": 2, "Bússola Fragmentada": 1}, {"Prata": 2, "Bússola Fragmentada": 2}, {"Prata": 3, "Bússola Fragmentada": 2},
		{"Ouro": 1, "Bússola Fragmentada": 2}, {"Ouro": 2, "Bússola Fragmentada": 2}, {"Ouro": 2, "Bússola Fragmentada": 3}, {"Ouro": 3, "Bússola Fragmentada": 3},
		{"Ouro": 3, "Diamante Sombrio": 1}, {"Ouro": 4, "Diamante Sombrio": 1},
	],
	"cinto": [
		{"Couro": 2, "Fivela de Bronze": 1}, {"Couro": 2, "Fivela de Bronze": 2}, {"Couro": 3, "Fivela de Bronze": 2}, {"Couro Reforçado": 2, "Fivela de Bronze": 2},
		{"Couro Reforçado": 2, "Fivela de Bronze": 3}, {"Couro Reforçado": 3, "Fivela de Prata": 1}, {"Couro Reforçado": 3, "Fivela de Prata": 2}, {"Couro Reforçado": 4, "Fivela de Prata": 2},
		{"Escamas de Kraken": 2, "Fivela de Prata": 2}, {"Escamas de Kraken": 3, "Fivela de Prata": 3},
	],
	"trajes": [
		{"Couro": 3, "Linho Encerado": 2}, {"Couro": 4, "Linho Encerado": 2}, {"Couro Reforçado": 3, "Linho Encerado": 2}, {"Couro Reforçado": 3, "Linho Encerado": 3},
		{"Couro Reforçado": 4, "Veludo Corsário": 1}, {"Couro Reforçado": 4, "Veludo Corsário": 2}, {"Couro Reforçado": 5, "Veludo Corsário": 2}, {"Escamas de Kraken": 2, "Veludo Corsário": 3},
		{"Escamas de Kraken": 3, "Veludo Corsário": 3}, {"Escamas de Kraken": 4, "Veludo Corsário": 4},
	],
	"secundaria": [
		{"Couro": 2, "Tinta Rúnica": 1}, {"Couro": 2, "Tinta Rúnica": 2}, {"Couro Reforçado": 2, "Tinta Rúnica": 2}, {"Couro Reforçado": 3, "Tinta Rúnica": 2},
		{"Liga de Ferro": 2, "Pólvora": 2}, {"Liga de Cobre": 2, "Pólvora": 2}, {"Couro Reforçado": 3, "Tinta Rúnica": 3}, {"Osso de Titã": 2, "Coral Amaldiçoado": 1},
		{"Fragmentos Místicos": 2, "Essência de Ebenruth": 1}, {"Fragmentos Místicos": 3, "Essência de Ebenruth": 2},
	],
}

## Bônus por modelo (índice 0 = 1º modelo). Ship (armamento/vela/casco/proa):
## mantém as chaves já consumidas por `ship_base.gd` (hull_bonus/
## cargo_bonus/speed_bonus/damage_mult_bonus/armor_pen_bonus) E acrescenta as
## novas do "Dicionário de Status Avançados" pedido nesta rodada
## (reload_speed_bonus/turn_rate_bonus/braking_bonus/wind_resistance_bonus)
## -- essas 4 ainda não têm nenhum sistema de combate/física pra consumir
## (mesmo caso já documentado de `cannon_damage_mult`: o número existe e
## aparece no tooltip, só não alimenta nada ainda).
##
## Capitão (brincos/colar/anel/cinto/trajes/secundaria): mantém
## leadership_bonus/boarding_crit_bonus/node_speed_bonus/armor_pen_bonus/
## elemental_damage_bonus já consumidos por `get_captain_bonuses()`, e
## acrescenta boarding_damage_bonus/effect_resistance_bonus (novos, mesma
## situação "calculado, não consumido ainda").
## `var`, não `const`, porque os 6 passos de Capitão são preenchidos por
## `_step10()` (interpolação) em `_ready()` -- GDScript não permite chamar
## função dentro de inicializador de `const`.
var _MODEL_STATS: Dictionary = {
	"armamento": [
		{"damage_mult_bonus": 0.0, "reload_speed_bonus": 0.0},
		{"damage_mult_bonus": 0.3, "armor_pen_bonus": 0.05, "reload_speed_bonus": 0.05},
		{"damage_mult_bonus": 0.65, "armor_pen_bonus": 0.12, "reload_speed_bonus": 0.12},
		{"damage_mult_bonus": 1.0, "armor_pen_bonus": 0.22, "reload_speed_bonus": 0.22},
	],
	"vela": [
		{"speed_bonus": 0.0, "wind_resistance_bonus": 0.0},
		{"speed_bonus": 15.0, "wind_resistance_bonus": 0.08},
		{"speed_bonus": 30.0, "wind_resistance_bonus": 0.16},
		{"speed_bonus": 50.0, "wind_resistance_bonus": 0.28},
	],
	"casco": [
		{"hull_bonus": 0.0, "cargo_bonus": 0.0, "braking_bonus": 0.0},
		{"hull_bonus": 200.0, "cargo_bonus": 20.0, "braking_bonus": 0.06},
		{"hull_bonus": 450.0, "cargo_bonus": 40.0, "braking_bonus": 0.14},
		{"hull_bonus": 800.0, "cargo_bonus": 70.0, "braking_bonus": 0.25},
	],
	"proa": [
		{"speed_bonus": 0.0, "turn_rate_bonus": 0.0},
		{"speed_bonus": 5.0, "turn_rate_bonus": 0.05},
		{"speed_bonus": 10.0, "turn_rate_bonus": 0.12},
		{"speed_bonus": 18.0, "turn_rate_bonus": 0.2},
	],
}


## Interpola 10 passos lineares entre `from`/`to` (mesmas chaves nos dois) --
## em vez de escrever 10 dicionários à mão por categoria de Capitão, já que
## a progressão é só "cresce mais ou menos de forma linear", igual já era
## pros 4 modelos de Vela/Proa/Casco antes desta rodada.
func _step10(from: Dictionary, to: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for step in 10:
		var t: float = float(step) / 9.0
		var entry: Dictionary = {}
		for key in from:
			entry[key] = lerpf(from[key], to.get(key, from[key]), t)
		result.append(entry)
	return result


func _build_captain_model_stats() -> void:
	_MODEL_STATS["brincos"] = _step10({"leadership_bonus": 0.0}, {"leadership_bonus": 24.0})
	_MODEL_STATS["colar"] = _step10({"boarding_crit_bonus": 0.0}, {"boarding_crit_bonus": 0.24})
	_MODEL_STATS["anel"] = _step10({"node_speed_bonus": 0.0}, {"node_speed_bonus": 34.0})
	_MODEL_STATS["cinto"] = _step10({"armor_pen_bonus": 0.0}, {"armor_pen_bonus": 0.34})
	_MODEL_STATS["trajes"] = _step10({"leadership_bonus": 0.0, "boarding_damage_bonus": 0.0}, {"leadership_bonus": 10.0, "boarding_damage_bonus": 0.3})
	_MODEL_STATS["secundaria"] = _step10({"elemental_damage_bonus": 0.0, "effect_resistance_bonus": 0.0}, {"elemental_damage_bonus": 0.2, "effect_resistance_bonus": 0.25})


## Ícone de cada modelo -- Canhão/Vela/Casco/Proa/Relíquia vêm de
## `Items - <Categoria>/N.png` (recorte limpo do próprio usuário, fundo
## branco já tratado); Capitão vem de `Items - <Categoria>/Design Sem Nome -
## N.png`, mesma fonte. Nomes de arquivo final: `<categoria>_t<N>.png` pros
## 4 primeiros, `<categoria>_m<N>.png` (modelo) pros de 10.
func _icon_file_for(category: String, model_index: int) -> String:
	var n: int = model_index + 1
	if _MODEL_COUNT.get(category, 4) == 4:
		return "%s_t%d.png" % [category, n]
	return "%s_m%d.png" % [category, n]


## "Catálogo de Munições Fantásticas": sem slot em lugar nenhum ainda (nem
## do navio, nem do capitão) -- fica guardada no inventário pra quando
## existir bordada por tipo de bala. `elemental_damage_bonus` é só pra
## tooltip mostrar o dano elemental da munição, sem sistema de troca de
## bala pra consumir isso ainda. Ícones/pacotes desta seção não vieram das
## pastas varridas nesta rodada -- mantidos como estavam.
const _AMMO_TYPES: Dictionary = {
	"polvora": {"name": "Pólvora", "ore": "Pólvora", "stats": {}, "icon": "municao_polvora.png", "element": "none"},
	"fogo": {"name": "Fogo", "ore": "Minério de Fogo", "stats": {"elemental_damage_bonus": 0.12}, "icon": "municao_fogo.png", "element": "fogo"},
	"gelo": {"name": "Gelo", "ore": "Minério de Gelo", "stats": {"elemental_damage_bonus": 0.12}, "icon": "municao_gelo.png", "element": "gelo"},
	"veneno": {"name": "Veneno", "ore": "Minério de Veneno", "stats": {"elemental_damage_bonus": 0.1}, "icon": "municao_veneno.png", "element": "terra"},
	"prata": {"name": "Prata", "ore": "Minério de Prata", "stats": {"elemental_damage_bonus": 0.15}, "icon": "municao_prata.png", "element": "none"},
	"ouro": {"name": "Ouro", "ore": "Minério de Ouro", "stats": {"elemental_damage_bonus": 0.15}, "icon": "municao_ouro.png", "element": "none"},
	"diamante": {"name": "Diamante", "ore": "Minério de Diamante", "stats": {"elemental_damage_bonus": 0.2}, "icon": "municao_diamante.png", "element": "vento"},
	"alma": {"name": "Alma", "ore": "Minério de Alma", "stats": {"elemental_damage_bonus": 0.22}, "icon": "municao_alma.png", "element": "raio"},
	"cursada": {"name": "Cursada", "ore": "Minério Amaldiçoado", "stats": {"elemental_damage_bonus": 0.25}, "icon": "municao_cursada.png", "element": "raio"},
}

const _PACKAGE_SIZES: Array[Dictionary] = [
	{"id": "p", "label": "Pacote P", "mult": 1},
	{"id": "m", "label": "Pacote M", "mult": 3},
	{"id": "g", "label": "Pacote G", "mult": 8},
	{"id": "gg", "label": "Pacote Extra G", "mult": 20},
]


func _build_ammo_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for type_id in _AMMO_TYPES:
		var data: Dictionary = _AMMO_TYPES[type_id]
		for pkg in _PACKAGE_SIZES:
			var mult: int = pkg["mult"]
			result.append({
				"id": "municao_%s_%s" % [type_id, pkg["id"]],
				"name": "Munição de %s -- %s" % [data["name"], pkg["label"]],
				"materials": {"Esfera de Ferro": 2 * mult, data["ore"]: 1 * mult},
				"stats": data["stats"],
				"icon": data["icon"],
				"element": data["element"],
			})
	return result

## "Arpões de Caça Marítima": mantido como estava (ícone desenhado à mão na
## rodada anterior -- não existe pasta de arpão entre as varridas agora).
const _HARPOONS: Array[Dictionary] = [
	{"id": "arpao_t1", "name": "Arpão de Caça Tier I", "materials": {"Madeira Nobre": 2, "Esfera de Ferro": 2}, "stats": {}, "icon": "arpao.png", "element": "none"},
	{"id": "arpao_t2", "name": "Arpão Farpado Tier II", "materials": {"Madeira Nobre": 3, "Liga de Ferro": 2}, "stats": {"armor_pen_bonus": 0.08}, "icon": "arpao.png", "element": "none"},
	{"id": "arpao_t3", "name": "Arpão de Aço Tier III", "materials": {"Liga de Cobre": 3, "Dente de Leviatã": 1}, "stats": {"armor_pen_bonus": 0.16, "elemental_damage_bonus": 0.1}, "icon": "arpao.png", "element": "gelo"},
	{"id": "arpao_t4", "name": "Arpão Rúnico Tier IV", "materials": {"Liga de Ouro": 3, "Dente de Leviatã": 2, "Vento Rúnico": 1}, "stats": {"armor_pen_bonus": 0.25, "elemental_damage_bonus": 0.2}, "icon": "arpao.png", "element": "vento"},
]

## Relíquias: SÓ 4 -- `~/Downloads/Tortuga/Items - Relíquias/` tem
## literalmente 4 arquivos (1.png..4.png), nunca teve 50. Uma rodada
## anterior criou 50 entradas por combinação de nome sem conferir a pasta
## de verdade -- corrigido aqui, descrito no cada ícone visto (máscara
## demoníaca chifruda, estátua angelical, fragmento vermelho, âmbar verde).
const _RELICS: Array[Dictionary] = [
	{"id": "relic_mascara_demoniaca", "name": "Máscara do Demônio Chifrudo", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"hull_bonus": 150.0, "elemental_damage_bonus": 0.15}, "icon": "relic_00.png", "element": "raio"},
	{"id": "relic_estatua_anjo", "name": "Estátua do Anjo Guardião", "materials": {"Fragmentos Místicos": 3, "Osso de Titã": 2}, "stats": {"leadership_bonus": 18.0, "effect_resistance_bonus": 0.15}, "icon": "relic_01.png", "element": "none"},
	{"id": "relic_fragmento_escarlate", "name": "Fragmento Escarlate do Kraken", "materials": {"Fragmentos Místicos": 5, "Coral Amaldiçoado": 3}, "stats": {"damage_mult_bonus": 0.25, "elemental_damage_bonus": 0.2}, "icon": "relic_02.png", "element": "fogo"},
	{"id": "relic_coracao_esmeralda", "name": "Coração Esmeralda de Ebenruth", "materials": {"Fragmentos Místicos": 4, "Pérola Abissal": 2}, "stats": {"cargo_bonus": 30.0, "wind_resistance_bonus": 0.2}, "icon": "relic_03.png", "element": "vento"},
]

## Leme: sem pasta própria varrida nesta rodada -- mantido como estava.
const _HELM: Array[Dictionary] = [
	{"id": "leme_carvalho", "name": "Leme de Carvalho Reforçado", "materials": {"Madeira Nobre": 3, "Peças de Latão": 2}, "stats": {}},
	{"id": "leme_latao", "name": "Leme Ornamentado de Latão", "materials": {"Madeira Nobre": 5, "Peças de Latão": 4, "Vento Rúnico": 1}, "stats": {"speed_bonus": 5.0, "turn_rate_bonus": 0.08}},
]
const _HELM_ICON: String = "leme.png"


## DICIONÁRIO DE ELEMENTOS (pedido explícito seção 4): só a estrutura de
## dados -- quem é forte contra quem -- sem sistema de combate pra resolver
## isso ainda (mesmo caso de todo stat "calculado, não consumido" acima).
## Baseado nos 2 exemplos dados ("Fogo racha Gelo/Vento", "Terra absorve
## Raio") fechados num ciclo de 5 coerente: Fogo > Gelo/Vento > Raio > Fogo,
## com Terra sendo defensivo puro (absorve Raio, não ataca).
enum Element { NONE, FOGO, GELO, VENTO, TERRA, RAIO }

const ELEMENT_NAMES: Dictionary = {
	Element.NONE: "Nenhum", Element.FOGO: "Fogo", Element.GELO: "Gelo",
	Element.VENTO: "Vento", Element.TERRA: "Terra", Element.RAIO: "Raio",
}

## ataque -> array de elementos contra os quais causa dano extra.
const ELEMENT_ADVANTAGE: Dictionary = {
	"fogo": ["gelo", "vento"],
	"vento": ["raio"],
	"raio": ["fogo"],
	"gelo": [],
	"terra": [],
}

## defensor -> array de elementos que ele absorve (resiste, não causa dano
## extra de volta) -- "Terra absorve Raio" é defensivo, diferente de
## "Fogo racha Gelo" que é ofensivo.
const ELEMENT_ABSORPTION: Dictionary = {
	"terra": ["raio"],
}


func element_advantage_multiplier(attack_element: String, defender_element: String) -> float:
	if ELEMENT_ABSORPTION.get(defender_element, []).has(attack_element):
		return 0.5
	if ELEMENT_ADVANTAGE.get(attack_element, []).has(defender_element):
		return 1.5
	return 1.0


## Ícone genérico por MATERIAL BRUTO (não item fabricado). Materiais não
## têm arte dedicada em nenhuma prancha recebida; desenhados do zero (PIL,
## formas geométricas simples), cada arquétipo tingido na cor do próprio
## material.
const MATERIAL_ICON_DIR: String = "res://assets/ui/icons/materials/"
const _MATERIAL_ICON_FILES: Dictionary = {
	"Liga de Ferro": "material_liga_de_ferro.png", "Liga de Cobre": "material_liga_de_cobre.png",
	"Liga de Ouro": "material_liga_de_ouro.png", "Prata": "material_prata.png", "Ouro": "material_ouro.png",
	"Placas de Ferro": "material_placas_de_ferro.png", "Esfera de Ferro": "material_esfera_de_ferro.png",
	"Peças de Latão": "material_pecas_de_latao.png", "Madeira de Carvalho": "material_madeira_de_carvalho.png",
	"Madeira Nobre": "material_madeira_nobre.png", "Lona": "material_lona.png",
	"Lona Reforçada": "material_lona_reforcada.png", "Seda": "material_seda.png",
	"Linho Encerado": "material_linho_encerado.png", "Veludo Corsário": "material_veludo_corsario.png",
	"Couro": "material_couro.png", "Couro Reforçado": "material_couro_reforcado.png",
	"Cordame": "material_cordame.png", "Pérola Negra": "material_perola_negra.png",
	"Pérola Abissal": "material_perola_abissal.png", "Diamante Sombrio": "material_diamante_sombrio.png",
	"Osso de Leviatã": "material_osso_de_leviata.png", "Osso de Titã": "material_osso_de_tita.png",
	"Dente de Leviatã": "material_dente_de_leviata.png", "Relíquia de Osso": "material_reliquia_de_osso.png",
	"Escamas de Kraken": "material_escamas_de_kraken.png", "Coral Amaldiçoado": "material_coral_amaldicoado.png",
	"Essência de Monstro Marinho": "material_essencia_de_monstro_marinho.png",
	"Essência de Ebenruth": "material_essencia_de_ebenruth.png", "Fragmentos Místicos": "material_fragmentos_misticos.png",
	"Vento Rúnico": "material_vento_runico.png", "Tinta Rúnica": "material_tinta_runica.png",
	"Fivela de Bronze": "material_fivela_de_bronze.png", "Fivela de Prata": "material_fivela_de_prata.png",
	"Bússola Fragmentada": "material_bussola_fragmentada.png", "Pólvora": "material_polvora.png",
	"Relíquia de Ouro": "material_reliquia_de_ouro.png",
}
var _material_icon_cache: Dictionary = {}


func get_material_icon(material_name: String) -> Texture2D:
	if _material_icon_cache.has(material_name):
		return _material_icon_cache[material_name]
	var file: String = _MATERIAL_ICON_FILES.get(material_name, "")
	var icon: Texture2D = load(MATERIAL_ICON_DIR + file) if file != "" else null
	_material_icon_cache[material_name] = icon
	return icon


func _ready() -> void:
	_build_captain_model_stats()
	_register_model_catalog()
	_register_flat_catalog(_build_ammo_catalog(), "municao", "forja", "")
	_register_flat_catalog(_HARPOONS, "arpao", "forja", "")
	_register_flat_catalog(_RELICS, "relíquia_ebenruth", "boticario", "")
	_register_flat_catalog(_HELM, "leme", "estaleiro", _HELM_ICON)


## Categorias do Capitão -- "roteamento" entre `ShipInventory`/
## `CaptainInventory` (separação explícita pedida: equipamento do capitão é
## PERMANENTE/não perde ao afundar, equipamento do navio é DESTRUÍVEL). Toda
## categoria que não está aqui é do navio.
const CAPTAIN_CATEGORIES: Array[String] = ["brincos", "colar", "anel", "cinto", "trajes", "secundaria"]


func is_captain_category(category: String) -> bool:
	return CAPTAIN_CATEGORIES.has(category)


func _station_for(category: String) -> String:
	if category == "armamento":
		return "forja"
	if CAPTAIN_CATEGORIES.has(category):
		return "feira"
	return "estaleiro"


func _register_model_catalog() -> void:
	for category in _MODEL_COUNT:
		var station: String = _station_for(category)
		var display: String = _TIER_DISPLAY_NAMES.get(category, "")
		var model_count: int = _MODEL_COUNT[category]
		for model_index in model_count:
			var model_num: int = model_index + 1
			var item_id: String = "%s_t%d" % [category, model_num]
			var model_name: String = _MODEL_NAMES[category][model_index]
			var item_name: String = "%s %s" % [display, model_name] if display != "" else model_name
			var icon_file: String = _icon_file_for(category, model_index)
			ITEMS[item_id] = {
				"id": item_id,
				"name": item_name,
				"category": category,
				"tier": model_num,
				"icon": load(ICON_DIR + icon_file) if icon_file != "" else null,
				"stats": _MODEL_STATS[category][model_index],
				"element": "none",
			}
			RECIPES[item_id] = {
				"output": item_id,
				"station": station,
				"materials": _MODEL_MATERIALS[category][model_index],
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
			"element": entry.get("element", "none"),
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
