extends Node
## Autoload: Permuta/Comércio estilo Black Desert Online (pedido explícito --
## "montar um império de comércio e escambo melhorado do BDO"). Cadeia de
## troca em 5 níveis: matéria-prima -> bem processado -> Permuta Nv1 -> Nv2
## -> Nv3 -> Nv4 -> Nv5, cada degrau com proporção PRÓPRIA (pedido explícito
## -- "tem trocas que são de 1 pra 1, ou 1 pra 2, ou 1 pra 3"). Nível 5 não
## troca mais pra cima -- vende por Ouro via `NegotiationSession`
## (barganha com o comércio da cidade).
##
## ARQUITETURA PENSADA PRA ESCALAR (pedido explícito -- "tem que pensar
## nessa linha de arquitetura pra dar certo escalar isso pra frente"): toda
## matéria-prima/receita é DADO (`RAW_MATERIALS`/`PROCESSING_RECIPES`/
## `EXCHANGE_RECIPES`), nenhuma hardcoded em função -- adicionar um tipo
## novo de madeira/mineral/item de Permuta é uma linha nova aqui, sem tocar
## em `process()`/`exchange()`.
##
## MATÉRIAS-PRIMAS NOVAS, NÃO AS ANTIGAS (pedido explícito -- "cria os itens
## novos... não precisa usar os materiais atuais e nem criar os ofícios por
## hora, somente os materiais mesmo"): 3 tipos de madeira pra começar
## (Cedro/Bétula/Carvalho), cada uma processável em Tábuas ou Vigas. SEM
## estação de Coleta por trás ainda -- seedadas uma vez no início, mesmo
## padrão já usado pra `TavernHireSystem.FOOD_STARTER_QTY` (Ração de
## Bordo). Quando existir uma estação de Coleta de verdade, só troca a
## FONTE do material aqui (`force_add_raw()`/um craft real no lugar do
## seed), a cadeia inteira continua igual -- por isso os dados já são uma
## lista separada (`RAW_MATERIALS`) em vez de reaproveitar
## `ShipInventory.materials` como fonte de verdade, só como ARMAZÉM (ver
## nota em `_ready()`).
##
## FORA DE ESCOPO NESTA RODADA, documentado em vez de fingido (confirmado
## com o usuário -- "mesmo que não exista as ilhas no momento, deixa
## documentado pra quando formos mexer nessa questão"):
## - TABELA ALEATÓRIA POR ILHA: hoje só existe 1 porto jogável (Tortuga) --
##   sortear "o que está em falta nesta ilha" não tem sentido sem outra
##   ilha pra comparar. Ponto de extensão: `EXCHANGE_RECIPES` ganharia um
##   campo `island_id` opcional, e `available_recipes_for_island(island_id)`
##   filtraria por ele -- hoje `available_recipes()` devolve tudo, como se
##   só existisse uma ilha (porque só existe).
## - IMPÉRIO DE NODES (estilo BDO, conectar territórios/rotas de comércio):
##   pressupõe um mapa com mais de 1 território navegável conectável, que
##   não existe ainda. Nenhum dado foi inventado em cima disso.

signal changed

const RAW_MATERIALS: Dictionary = {
	"madeira_cedro": {"name": "Madeira de Cedro", "starter_qty": 12},
	"madeira_betula": {"name": "Madeira de Bétula", "starter_qty": 12},
	"madeira_carvalho": {"name": "Madeira de Carvalho", "starter_qty": 10},
}

## Cada entrada: matéria-prima -> bem processado, com a proporção de
## entrada (`ratio_in` unidades da matéria-prima rendem `qty_out` do bem).
const PROCESSING_RECIPES: Array[Dictionary] = [
	{"input": "madeira_cedro", "ratio_in": 2, "output": "Tábuas de Cedro", "qty_out": 1},
	{"input": "madeira_betula", "ratio_in": 2, "output": "Tábuas de Bétula", "qty_out": 1},
	{"input": "madeira_carvalho", "ratio_in": 3, "output": "Vigas de Carvalho", "qty_out": 1},
]

## Os 5 níveis da cadeia de Permuta -- cada entrada troca `ratio_in`
## unidades do item de entrada (bem processado, pro Nível 1; item do nível
## anterior, do Nível 2 em diante) por `qty_out` do item de saída. Mais de
## uma receita por nível (pedido implícito -- "trocas aleatórias", aqui
## como "mais de um caminho possível por nível" já que sorteio por ilha
## ainda não se aplica, ver nota de classe).
const EXCHANGE_RECIPES: Array[Dictionary] = [
	{"tier": 1, "input": "Tábuas de Cedro", "ratio_in": 1, "output": "Permuta Nv1: Prancha Reforçada", "qty_out": 1},
	{"tier": 1, "input": "Tábuas de Bétula", "ratio_in": 2, "output": "Permuta Nv1: Remo Trabalhado", "qty_out": 1},
	{"tier": 1, "input": "Vigas de Carvalho", "ratio_in": 1, "output": "Permuta Nv1: Mastro Improvisado", "qty_out": 1},

	{"tier": 2, "input": "Permuta Nv1: Prancha Reforçada", "ratio_in": 2, "output": "Permuta Nv2: Casco Selado", "qty_out": 1},
	{"tier": 2, "input": "Permuta Nv1: Remo Trabalhado", "ratio_in": 3, "output": "Permuta Nv2: Bote Salva-Vidas", "qty_out": 1},
	{"tier": 2, "input": "Permuta Nv1: Mastro Improvisado", "ratio_in": 2, "output": "Permuta Nv2: Verga Trabalhada", "qty_out": 1},

	{"tier": 3, "input": "Permuta Nv2: Casco Selado", "ratio_in": 2, "output": "Permuta Nv3: Galeão em Miniatura", "qty_out": 1},
	{"tier": 3, "input": "Permuta Nv2: Bote Salva-Vidas", "ratio_in": 2, "output": "Permuta Nv3: Instrumentos de Navegação", "qty_out": 1},
	{"tier": 3, "input": "Permuta Nv2: Verga Trabalhada", "ratio_in": 3, "output": "Permuta Nv3: Bandeira Corsária", "qty_out": 1},

	{"tier": 4, "input": "Permuta Nv3: Galeão em Miniatura", "ratio_in": 2, "output": "Permuta Nv4: Baú de Capitão", "qty_out": 1},
	{"tier": 4, "input": "Permuta Nv3: Instrumentos de Navegação", "ratio_in": 2, "output": "Permuta Nv4: Carta Náutica Rara", "qty_out": 1},
	{"tier": 4, "input": "Permuta Nv3: Bandeira Corsária", "ratio_in": 3, "output": "Permuta Nv4: Relato de Corsário Lendário", "qty_out": 1},

	{"tier": 5, "input": "Permuta Nv4: Baú de Capitão", "ratio_in": 2, "output": "Permuta Nv5: Relicário Perdido", "qty_out": 1},
	{"tier": 5, "input": "Permuta Nv4: Carta Náutica Rara", "ratio_in": 2, "output": "Permuta Nv5: Mapa do Tesouro Lendário", "qty_out": 1},
	{"tier": 5, "input": "Permuta Nv4: Relato de Corsário Lendário", "ratio_in": 3, "output": "Permuta Nv5: Coroa Afundada", "qty_out": 1},
]

const MAX_TIER: int = 5

## NEGOCIAÇÃO (puzzle Nível 5, pedido explícito -- "Paciência" + preço-alvo
## escondido + tentativas limitadas, confirmado com o usuário). Um item
## Nv5 só vira Ouro passando por uma `NegotiationSession` -- não tem troca
## direta/preço fixo pra eles.
const NEGOTIATION_PRICE_RANGE: Vector2i = Vector2i(80, 160)
const NEGOTIATION_MAX_PATIENCE: int = 4
const NEGOTIATION_MAX_ATTEMPTS: int = 5
## Oferta a até isto de distância do alvo fecha negócio na hora.
const NEGOTIATION_TOLERANCE: int = 12
## Oferta a até isto (mas fora da tolerância) só dá a dica "perto" em vez
## de "longe" -- ajuda o jogador a convergir sem revelar o número exato.
const NEGOTIATION_CLOSE_HINT: int = 35

## Sessão ativa (uma de cada vez) -- {item, target_price, patience, attempts}.
## `{}` quando nenhuma negociação está rolando.
var _negotiation: Dictionary = {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for key in RAW_MATERIALS:
		var mat: Dictionary = RAW_MATERIALS[key]
		if not ShipInventory.materials.has(mat["name"]):
			ShipInventory.materials[mat["name"]] = mat["starter_qty"]


## Quantas unidades de `item_name` o jogador tem -- mesmo armazém de
## `ShipInventory.materials` que Ração/Ouro/Pólvora já usam (pedido de não
## criar um 2º sistema de inventário só pra Permuta).
func quantity_of(item_name: String) -> int:
	return int(ShipInventory.materials.get(item_name, 0))


func can_process_recipe(recipe: Dictionary) -> bool:
	var input_name: String = RAW_MATERIALS[recipe["input"]]["name"]
	return quantity_of(input_name) >= recipe["ratio_in"]


func process(recipe: Dictionary) -> bool:
	if not can_process_recipe(recipe):
		return false
	var input_name: String = RAW_MATERIALS[recipe["input"]]["name"]
	ShipInventory.materials[input_name] = quantity_of(input_name) - recipe["ratio_in"]
	ShipInventory.materials[recipe["output"]] = quantity_of(recipe["output"]) + recipe["qty_out"]
	changed.emit()
	return true


func can_exchange(recipe: Dictionary) -> bool:
	return quantity_of(recipe["input"]) >= recipe["ratio_in"]


func exchange(recipe: Dictionary) -> bool:
	if not can_exchange(recipe):
		return false
	ShipInventory.materials[recipe["input"]] = quantity_of(recipe["input"]) - recipe["ratio_in"]
	ShipInventory.materials[recipe["output"]] = quantity_of(recipe["output"]) + recipe["qty_out"]
	changed.emit()
	return true


func exchange_recipes_for_tier(tier: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for recipe in EXCHANGE_RECIPES:
		if recipe["tier"] == tier:
			out.append(recipe)
	return out


## Todo item Nível 5 existente, usado pela UI pra listar o que dá pra levar
## pra negociação -- não inclui proporção (item Nv5 só negocia, não troca
## mais pra cima, ver nota de classe).
func tier5_items() -> Array[String]:
	var out: Array[String] = []
	for recipe in EXCHANGE_RECIPES:
		if recipe["tier"] == MAX_TIER and not out.has(recipe["output"]):
			out.append(recipe["output"])
	return out


func negotiation_active() -> bool:
	return not _negotiation.is_empty()


## Começa a negociar UM item Nv5 (consumido só se a negociação terminar em
## sucesso, ver `propose_price()`). Preço-alvo sorteado agora e nunca
## exposto à UI -- só as dicas de `propose_price()` revelam direção.
func start_negotiation(item_name: String) -> Dictionary:
	if negotiation_active() or quantity_of(item_name) < 1:
		return {}
	_negotiation = {
		"item": item_name,
		"target_price": _rng.randi_range(NEGOTIATION_PRICE_RANGE.x, NEGOTIATION_PRICE_RANGE.y),
		"patience": NEGOTIATION_MAX_PATIENCE,
		"attempts": NEGOTIATION_MAX_ATTEMPTS,
	}
	changed.emit()
	return _negotiation.duplicate()


## Uma rodada de barganha. Resultado: {outcome: "deal"|"hint"|"walked_away",
## hint: "longe_abaixo"|"longe_acima"|"perto_abaixo"|"perto_acima" (só
## quando outcome=="hint"), patience, attempts, gold_gained (só "deal")}.
func propose_price(price: int) -> Dictionary:
	if not negotiation_active():
		return {}
	var target: int = _negotiation["target_price"]
	var diff: int = price - target
	var abs_diff: int = absi(diff)
	_negotiation["attempts"] -= 1

	if abs_diff <= NEGOTIATION_TOLERANCE:
		var item: String = _negotiation["item"]
		ShipInventory.materials[item] = quantity_of(item) - 1
		ShipInventory.materials["Ouro"] = quantity_of("Ouro") + price
		var result: Dictionary = {"outcome": "deal", "gold_gained": price, "patience": _negotiation["patience"], "attempts": _negotiation["attempts"]}
		_negotiation = {}
		changed.emit()
		return result

	_negotiation["patience"] -= 1
	if _negotiation["patience"] <= 0 or _negotiation["attempts"] <= 0:
		var fail_result: Dictionary = {"outcome": "walked_away", "patience": 0, "attempts": _negotiation["attempts"]}
		_negotiation = {}
		changed.emit()
		return fail_result

	var closeness: String = "perto" if abs_diff <= NEGOTIATION_CLOSE_HINT else "longe"
	var direction: String = "acima" if diff < 0 else "abaixo"
	changed.emit()
	return {
		"outcome": "hint",
		"hint": "%s_%s" % [closeness, direction],
		"patience": _negotiation["patience"],
		"attempts": _negotiation["attempts"],
	}


## Desiste da negociação atual sem gastar o item (pedido implícito --
## jogador pode recuar sem perder o Nv5 que estava tentando vender).
func cancel_negotiation() -> void:
	if negotiation_active():
		_negotiation = {}
		changed.emit()
