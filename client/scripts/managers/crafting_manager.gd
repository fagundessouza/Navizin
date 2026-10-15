extends Node
## Autoload: QUALIDADE DE CRAFT, estilo Albion (sorteio por peso, 4 faixas)
## com nomes dinâmicos estilo MU Online/Diablo IV (prefixo + base + sufixo).
## `PlayerInventory.craft()` chama `roll_rarity()` e `generate_name()` ao
## fabricar -- a qualidade é sorteada NA HORA do craft, não é um atributo
## fixo do item-base em `ItemDatabase` (que guarda só o MODELO, ver nota no
## topo daquele arquivo). Dois Canhões de Ferro fabricados separados podem
## sair com qualidades diferentes.
##
## SUBSTITUÍDO NESTA RODADA: a escada anterior tinha 7 degraus (Normal/Bom/
## Raro/Épico/Místico/Lendário/Divino). O pedido explícito desta rodada
## especifica 4 (Normal/Bom/Excelente/Obra-Prima, cores Cinza-Branco/
## Verde-Suave/Azul-Arcano/Dourado-Laranja) -- MODELO BASE (Canhão de Ferro,
## Ouro, Supremo...) já cobre a progressão de poder que antes vinha de
## misturar raridade+tier; a qualidade agora é só o multiplicador "quão bem
## saiu esta fabricação específica", não mais uma segunda escada de poder
## inteira por cima. IDs mantidos (`white`/`green`/`blue`/`gold`) onde pareciam
## os nomes mais diretos pras 4 cores, pra não quebrar o que já lia
## `rarity_id` salvo (`PlayerInventory.get_item_rarity()` cai em "white" por
## padrão se o id não bater com nada).

## Ordem importa pro sorteio por peso (cumulativo) e é a ordem de "poder":
## Normal é a mais fraca, Obra-Prima a mais forte.
##
## `default_aura`: a aura que a qualidade liga por padrão mesmo sem Float/
## Refino alto (`_aura_mode_for()` em `ship_status_modal.gd`/
## `captain_profile_modal.gd`) -- Excelente "arcano" = elétrico (1), Obra-
## Prima "brilhante" = rúnico (3, o mais rico dos três modos), o resto fica
## 0 (só pulso) por padrão.
const RARITIES: Array[Dictionary] = [
	{"id": "white", "name": "Normal", "color": Color(0.82, 0.82, 0.8, 1.0), "weight": 45.0, "mult": 1.0, "default_aura": 0},
	{"id": "green", "name": "Bom", "color": Color(0.45, 0.85, 0.45, 1.0), "weight": 35.0, "mult": 1.2, "default_aura": 0},
	{"id": "blue", "name": "Excelente", "color": Color(0.3, 0.55, 0.95, 1.0), "weight": 15.0, "mult": 1.45, "default_aura": 1},
	{"id": "gold", "name": "Obra-Prima", "color": Color(1.0, 0.72, 0.15, 1.0), "weight": 5.0, "mult": 1.8, "default_aura": 3},
]

## Sem prefixo/sufixo pro Normal -- ele fica só com o nome-base do item
## mesmo, pra "essa fabricação não saiu especial" ficar óbvio à primeira
## vista (cor cinza + nome simples), sem precisar ler o tooltip.
const PREFIXES: Dictionary = {
	"green": ["Resistente", "Afiado", "Sólido", "Preciso"],
	"blue": ["Arcano", "Veloz", "Reforçado", "Certeiro"],
	"gold": ["Primoroso", "Magistral", "Impecável", "Supremo"],
}

const SUFFIXES: Dictionary = {
	"green": ["da Precisão", "da Resistência"],
	"blue": ["da Fúria Arcana", "da Tempestade"],
	"gold": ["da Obra-Prima", "do Mestre Artesão"],
}


## ESTILO DE TEXTO RICO (pedido explícito -- "eliminar cores sólidas e
## chapadas como o verde Tibia"): todo Label de nome de item em qualquer
## modal passa por aqui em vez de só `add_theme_color_override("font_color",
## ...)` sozinho. Sombra projetada + contorno escuro dão peso/profundidade
## que uma cor lisa não tem -- é a mesma técnica que Diablo/MU usam pros
## nomes de item (não é literalmente um gradiente -- `Label` não suporta
## gradiente de texto nativo sem um shader por cima; sombra+contorno+cor
## viva já tira o visual "chapado" sem precisar de um shader de texto só
## pra isso).
const LABEL_SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.85)
const LABEL_SHADOW_OFFSET: Vector2 = Vector2(2.0, 2.0)
const LABEL_OUTLINE_COLOR: Color = Color(0.05, 0.03, 0.02, 0.9)
const LABEL_OUTLINE_SIZE: int = 2


## `Control`, não `Label` -- usado tanto em `Label` quanto em `Button` (os
## overrides de tema de sombra/contorno de fonte existem nos dois, Control
## é a base comum).
func style_item_label(label: Control, rarity: Dictionary) -> void:
	label.add_theme_color_override("font_color", rarity["color"])
	label.add_theme_color_override("font_shadow_color", LABEL_SHADOW_COLOR)
	label.add_theme_constant_override("shadow_offset_x", int(LABEL_SHADOW_OFFSET.x))
	label.add_theme_constant_override("shadow_offset_y", int(LABEL_SHADOW_OFFSET.y))
	label.add_theme_color_override("font_outline_color", LABEL_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", LABEL_OUTLINE_SIZE)


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
