extends Node
## Autoload: raridade de crafting, estilo Albion/Taskbar Hero (sorteio por
## peso) com nomes dinâmicos estilo MU Online/Diablo IV (prefixo + base +
## sufixo). `PlayerInventory.craft()` chama `roll_rarity()` e
## `generate_name()` ao fabricar -- a raridade é sorteada NA HORA do craft,
## não é um atributo fixo do item-base em `ItemDatabase`, então dois Canhões
## Tier I fabricados separados podem sair com raridades diferentes.

## Ordem importa pro sorteio por peso (cumulativo), mas também é a ordem de
## "poder": White é a mais fraca, Red a mais forte.
##
## Cores em hex exato pedido (White/Blue/Yellow/Purple/Red) -- as 2 faixas
## intermediárias que o pedido não listou (Bom/Místico) tiveram sua cor
## trocada também, pra "remover a fonte em verde genérico": Bom usava um
## verde puro antes, virou um creme pálido (nem branco puro de Normal, nem
## nenhuma cor nova inventada sem pedido).
##
## `default_aura`: a aura que a raridade liga por padrão mesmo sem Float/
## Refino alto (`_aura_mode_for()` em `ship_status_modal.gd`/
## `captain_profile_modal.gd` só cai nisso depois de checar Relíquia/
## Grimório e Float≥0.95) -- Lendário "com brilho" = elétrico (1), Divino
## "com chama" = fogo sombrio (2), o resto fica 0 (só pulso) por padrão.
const RARITIES: Array[Dictionary] = [
	{"id": "white", "name": "Normal", "color": Color("#FFFFFF"), "weight": 50.0, "mult": 1.0, "default_aura": 0},
	{"id": "green", "name": "Bom", "color": Color(0.88, 0.85, 0.72, 1.0), "weight": 25.0, "mult": 1.15, "default_aura": 0},
	{"id": "blue", "name": "Raro", "color": Color("#0088FF"), "weight": 13.0, "mult": 1.35, "default_aura": 0},
	{"id": "yellow", "name": "Épico", "color": Color("#FFD700"), "weight": 7.0, "mult": 1.6, "default_aura": 0},
	{"id": "orange", "name": "Místico", "color": Color(0.96, 0.55, 0.15, 1.0), "weight": 3.0, "mult": 2.0, "default_aura": 0},
	{"id": "purple", "name": "Lendário", "color": Color("#A020F0"), "weight": 1.5, "mult": 2.5, "default_aura": 1},
	{"id": "red", "name": "Divino", "color": Color("#FF2222"), "weight": 0.5, "mult": 3.5, "default_aura": 2},
]

## Sem prefixo/sufixo pro White -- ele fica só com o nome-base do item
## mesmo, pra "esse item não rolou nada especial" ficar óbvio à primeira
## vista (cor cinza + nome simples), sem precisar ler o tooltip.
const PREFIXES: Dictionary = {
	"green": ["Resistente", "Afiado", "Sólido", "Preciso"],
	"blue": ["Veloz", "Temperado", "Reforçado", "Certeiro"],
	"yellow": ["Flamejante", "Gélido", "Fulminante", "Sombrio"],
	"orange": ["Abissal", "Profano", "Celestial", "Vulcânico"],
	"purple": ["Lendário", "Ancestral", "Amaldiçoado", "Imortal"],
	"red": ["Divino", "Apocalíptico", "Primordial", "Eterno"],
}

const SUFFIXES: Dictionary = {
	"green": ["da Precisão", "da Resistência"],
	"blue": ["da Fúria", "da Tempestade"],
	"yellow": ["da Destruição", "do Trovão"],
	"orange": ["da Devastação", "do Caos"],
	"purple": ["dos Mares Eternos", "do Juízo Final"],
	"red": ["da Criação", "do Apocalipse"],
}


func get_rarity(rarity_id: String) -> Dictionary:
	for r in RARITIES:
		if r["id"] == rarity_id:
			return r
	return RARITIES[0]


## Sorteio por peso cumulativo (50/25/13/7/3/1.5/0.5, soma 100) -- um
## `randf() * 100.0` e percorre a lista até o acumulado passar do sorteado.
func roll_rarity() -> Dictionary:
	var roll: float = randf() * 100.0
	var cumulative: float = 0.0
	for r in RARITIES:
		cumulative += r["weight"]
		if roll <= cumulative:
			return r
	return RARITIES[0]


## "Canhão Tier I" + raridade Orange -> "Canhão Abissal Tier I da
## Devastação" -- insere o prefixo logo depois da primeira palavra (o
## substantivo do item) e o sufixo no fim, pra soar como adjetivo mesmo com
## nomes-base de formatos diferentes ("Canhão Tier I", "Munição de Fogo",
## "Luz Divina de Ebenruth").
func generate_name(base_name: String, rarity: Dictionary) -> String:
	if rarity["id"] == "white":
		return base_name
	var prefix: String = PREFIXES[rarity["id"]].pick_random()
	var suffix: String = SUFFIXES[rarity["id"]].pick_random()
	var parts: PackedStringArray = base_name.split(" ", true, 1)
	if parts.size() < 2:
		return "%s %s %s" % [base_name, prefix, suffix]
	return "%s %s %s %s" % [parts[0], prefix, parts[1], suffix]


## Multiplica todo bônus do item-base pelo `mult` da raridade -- o resultado
## vira o `stats` DA INSTÂNCIA fabricada (`PlayerInventory.crafted_items`),
## não o `stats` genérico de `ItemDatabase`, porque dois itens do mesmo tipo
## podem ter rolado raridades diferentes.
func apply_rarity_stats(base_stats: Dictionary, rarity: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var mult: float = rarity["mult"]
	for key in base_stats:
		result[key] = base_stats[key] * mult
	return result


## Float Value (CS/Albion): 0.000 (Gasto) a 1.000 (Perfeito), independente
## da raridade -- um Canhão White pode rolar Float 0.99 (sortudo na têmpera,
## mas sem qualidade "de fábrica" especial) e um Red pode rolar Float 0.05
## (raro, mas malfeito). Escala LINEAR, não por faixa: Float 1.000 concede
## `FLOAT_MAX_BONUS` (20%) de atributo extra, Float 0.990 concede ~19.8%
## (bate com o exemplo do pedido, "+20% sobre o tier base").
const FLOAT_MAX_BONUS: float = 0.20

## Faixas só pra CLASSIFICAÇÃO exibida (tooltip) -- o multiplicador em si é
## contínuo, essas faixas não mudam o número, só rotulam ele.
const FLOAT_LABELS: Array[Dictionary] = [
	{"min": 0.95, "name": "Perfeito"},
	{"min": 0.80, "name": "Excelente"},
	{"min": 0.50, "name": "Bom"},
	{"min": 0.20, "name": "Regular"},
	{"min": 0.0, "name": "Gasto"},
]


func roll_float_value() -> float:
	return randf()


func float_stat_multiplier(float_value: float) -> float:
	return 1.0 + float_value * FLOAT_MAX_BONUS


func float_label(float_value: float) -> String:
	for tier in FLOAT_LABELS:
		if float_value >= tier["min"]:
			return tier["name"]
	return "Gasto"
