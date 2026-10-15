extends Node
## Autoload: Roleta de Marinheiros/Operários da Taverna, estilo BDO (Raça +
## Graduação sorteadas por peso, custando Energia + Ouro). Separado de
## `OfficerRoster` de propósito -- aquele é um painel de 5 CARGOS fixos
## (Timoneiro/Canhoneiro/...), sempre os mesmos; este é um POOL genérico de
## N tripulantes (até `ShipData.max_sailors`), cada rolagem pode repetir
## raça/graduação, cada um com nome/retrato/bônus próprio.
##
## ENERGIA: recurso novo, regenera sozinho com o tempo (1 a cada
## `ENERGY_REGEN_INTERVAL` segundos) até `MAX_ENERGY` -- não custa Ouro pra
## regenerar, só o tempo passando, igual ao Energy de BDO.
##
## "NODES" do pedido original: BDO usa isso pra workers produzirem recurso
## COLETANDO num mapa de nós ao longo do tempo. Não existe mapa de nós nem
## posição/recurso por nó definido em nenhum pedido até agora -- nada foi
## inventado em cima disso (sem mapa, sem produção passiva de item). O que
## ficou real e testável: Energia como recurso gastável na rolagem, e cada
## Marinheiro contratado concedendo um bônus passivo direto ao navio, pelas
## MESMAS chaves de stat que `OfficerRoster.ROLE_BONUS`/equipamento já usam
## (`turn_rate_bonus`/`hull_bonus`/... -- ver nota lá: algumas ainda são
## "calculadas, sem física pra consumir" e isso NÃO muda aqui, só mais uma
## fonte somando no mesmo total).
##
## COMIDA: `FOOD_MATERIAL` é um material novo (sem receita de craft, só
## existe pra isso), seedado aqui do mesmo jeito que `ShipInventory` seeda
## `Kit de Reparo`. Cada marinheiro tem um upkeep próprio por Raça (Goblin
## come mais, pedido explícito); sem ração suficiente pro ciclo inteiro, o
## EXCEDENTE fica inativo (bônus suspenso, `active=false`) em vez de ser
## dispensado -- perder uma rolagem de sorte rara só por atraso de
## abastecimento seria punitivo demais, mesmo padrão de nunca destruir de
## vez que o piso de Durabilidade Máxima já usa.

signal changed

enum Race { HUMAN, GOBLIN, GOBLIN_PURE, GIANT }

const RACE_NAMES: Dictionary = {
	Race.HUMAN: "Humano", Race.GOBLIN: "Goblin", Race.GOBLIN_PURE: "Goblin Puro", Race.GIANT: "Gigante",
}

const RACE_PORTRAITS: Dictionary = {
	Race.HUMAN: "res://assets/ui/crew/portrait_human.png",
	Race.GOBLIN: "res://assets/ui/crew/portrait_goblin.png",
	Race.GOBLIN_PURE: "res://assets/ui/crew/portrait_goblin_pure.png",
	Race.GIANT: "res://assets/ui/crew/portrait_giant.png",
}

## Bônus-BASE por raça (antes do multiplicador de Graduação) -- mesmas
## chaves de `OfficerRoster.ROLE_BONUS`, pra tudo somar no mesmo total
## (`get_total_bonuses()` abaixo, consumido por `ship_base.gd` igual a
## oficiais e equipamento).
const RACE_BASE_BONUS: Dictionary = {
	Race.HUMAN: {"wind_resistance_bonus": 0.04, "node_speed_bonus": 1.5},
	Race.GOBLIN: {"turn_rate_bonus": 0.09},
	Race.GOBLIN_PURE: {"turn_rate_bonus": 0.17, "reload_speed_bonus": 0.05, "wind_resistance_bonus": 0.05},
	Race.GIANT: {"hull_bonus": 15.0, "cargo_bonus": 6.0, "hull_repair_bonus": 0.03, "speed_bonus": -2.0},
}

## Multiplica o consumo de `FOOD_MATERIAL` daquele marinheiro -- pedido
## explícito: "Goblin consome mais Alimentos/Comida de Bordo".
const RACE_FOOD_UPKEEP_MULT: Dictionary = {
	Race.HUMAN: 1.0, Race.GOBLIN: 1.6, Race.GOBLIN_PURE: 1.8, Race.GIANT: 1.3,
}

const RACE_DESCRIPTIONS: Dictionary = {
	Race.HUMAN: "Atributos equilibrados -- navegação e trânsito entre nós mais rápidos.",
	Race.GOBLIN: "Giro de leme altíssimo, mas consome mais ração.",
	Race.GOBLIN_PURE: "Variante rara do Goblin -- status no máximo.",
	Race.GIANT: "Casco, carga e reparo reforçados, mas mais devagar.",
}

## Peso de sorteio por raça -- Goblin Puro é a variante rara dentro do pool
## de Goblin (pedido explícito), por isso um peso bem menor que as outras 3.
const RACE_WEIGHTS: Dictionary = {
	Race.HUMAN: 45.0, Race.GOBLIN: 35.0, Race.GOBLIN_PURE: 4.0, Race.GIANT: 16.0,
}

## As 5 Graduações pedidas, nesta ordem exata. `mult` escala o bônus-base da
## raça; `aura` é o modo que `item_rarity_glow.gdshader` liga no card
## (0=só pulso, 1=elétrico, 2=fogo sombrio, 3=rúnico -- mesma escala que
## craft de equipamento já usa pra Excelente/Obra-Prima).
const QUALITIES: Array[Dictionary] = [
	{"id": "naive", "name": "Ingênuo", "color": Color(0.68, 0.68, 0.65, 1.0), "weight": 42.0, "mult": 0.6, "aura": 0},
	{"id": "skilled", "name": "Hábil", "color": Color(0.45, 0.85, 0.45, 1.0), "weight": 30.0, "mult": 0.85, "aura": 0},
	{"id": "artisan", "name": "Artesão", "color": Color(0.3, 0.55, 0.95, 1.0), "weight": 17.0, "mult": 1.1, "aura": 1},
	{"id": "master", "name": "Mestre", "color": Color(0.95, 0.6, 0.15, 1.0), "weight": 8.0, "mult": 1.4, "aura": 2},
	{"id": "guru", "name": "Guru", "color": Color(0.72, 0.4, 0.92, 1.0), "weight": 3.0, "mult": 1.8, "aura": 3},
]

## Pequenos pools de nome por raça, mesmo padrão combinatório que
## `CraftingManager` já usa pra nome de item (prefixo/sufixo) -- nomes
## gerados pra uma entidade de jogo NOVA (marinheiro), não uma contagem de
## asset de arte real sendo inventada por cima do que o usuário forneceu.
const FIRST_NAMES: Dictionary = {
	Race.HUMAN: ["Joaquim", "Bento", "Tomé", "Vicente", "Rosário", "Isadora", "Belmiro", "Catarina"],
	Race.GOBLIN: ["Grix", "Snagg", "Korr", "Mizzik", "Ruddle", "Ferrik", "Globb", "Yark"],
	Race.GOBLIN_PURE: ["Grix", "Snagg", "Korr", "Mizzik", "Ruddle", "Ferrik", "Globb", "Yark"],
	Race.GIANT: ["Thrak", "Gorn", "Borrim", "Haldor", "Ossian", "Kratz", "Dunmar", "Vrogar"],
}
const TITLES: Dictionary = {
	Race.HUMAN: ["das Marés", "do Cais", "Sortudo", "da Bússola"],
	Race.GOBLIN: ["Dentuço", "Rápido", "das Cordas", "Fuinha"],
	Race.GOBLIN_PURE: ["o Puro", "Áureo", "sem Mácula"],
	Race.GIANT: ["Punho de Ferro", "o Rochedo", "Costas-Largas"],
}

const FOOD_MATERIAL: String = "Ração de Bordo"
const FOOD_STARTER_QTY: int = 20
const ROLL_GOLD_MATERIAL: String = "Ouro"
const ROLL_GOLD_COST: int = 20
const ROLL_ENERGY_COST: int = 10
const MAX_ENERGY: int = 100
const ENERGY_REGEN_INTERVAL: float = 40.0
const FOOD_TICK_INTERVAL: float = 30.0
const FOOD_PER_SAILOR_PER_TICK: float = 1.0
const DEFAULT_MAX_SAILORS: int = 12

## Estado de saúde (pedido explícito do Painel de Admin -- "Crew Debug"):
## separado de `active` (que só reflete RAÇÃO em dia). Só "ready" concede
## bônus -- "wounded"/"sick" são ganchos reais prontos pra quando existir
## dano de tropa/doença de verdade (abordagem, por exemplo); por ora só o
## Painel de Admin escreve neles, pra testar o efeito sem esperar aquele
## sistema existir.
const STATUS_READY: String = "ready"
const STATUS_WOUNDED: String = "wounded"
const STATUS_SICK: String = "sick"
const STATUS_NAMES: Dictionary = {
	STATUS_READY: "Pronto", STATUS_WOUNDED: "Ferido", STATUS_SICK: "Doente",
}

var energy: int = MAX_ENERGY
## Cada entrada: {id, race, quality_index, name, active, status}.
var hired: Array[Dictionary] = []

var _next_id: int = 1
var _energy_accum: float = 0.0
var _food_accum: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if not ShipInventory.materials.has(FOOD_MATERIAL):
		ShipInventory.materials[FOOD_MATERIAL] = FOOD_STARTER_QTY


func _process(delta: float) -> void:
	_energy_accum += delta
	while _energy_accum >= ENERGY_REGEN_INTERVAL:
		_energy_accum -= ENERGY_REGEN_INTERVAL
		if energy < MAX_ENERGY:
			energy += 1
			changed.emit()
	_food_accum += delta
	while _food_accum >= FOOD_TICK_INTERVAL:
		_food_accum -= FOOD_TICK_INTERVAL
		_consume_food_tick()


func max_sailors() -> int:
	var ship: Node2D = get_tree().get_first_node_in_group("player_ship") as Node2D
	if ship != null and ship.data != null:
		return ship.data.max_sailors
	return DEFAULT_MAX_SAILORS


func can_roll() -> bool:
	if hired.size() >= max_sailors():
		return false
	if energy < ROLL_ENERGY_COST:
		return false
	return ShipInventory.materials.get(ROLL_GOLD_MATERIAL, 0) >= ROLL_GOLD_COST


## Sorteia Raça e Graduação por peso, gasta Energia+Ouro, adiciona ao pool e
## devolve a entrada criada (`{}` se não pôde rolar -- checar com
## `can_roll()` antes, igual ao padrão `OfficerRoster.can_hire()`).
func roll_sailor() -> Dictionary:
	if not can_roll():
		return {}
	energy -= ROLL_ENERGY_COST
	ShipInventory.materials[ROLL_GOLD_MATERIAL] -= ROLL_GOLD_COST

	var race: Race = _weighted_pick_race()
	var quality_index: int = _weighted_pick_quality()
	var entry: Dictionary = _make_entry(race, quality_index)
	hired.append(entry)
	changed.emit()
	return entry


func _make_entry(race: Race, quality_index: int) -> Dictionary:
	var entry: Dictionary = {
		"id": "sailor_%d" % _next_id,
		"race": race,
		"quality_index": quality_index,
		"name": _generate_name(race),
		"active": true,
		"status": STATUS_READY,
	}
	_next_id += 1
	return entry


## Adiciona um marinheiro direto, sem custo de Energia/Ouro e ignorando o
## teto de `max_sailors()` -- só pro Painel de Admin (aba Tripulação & Tropas,
## "adicionar Goblin Puro/Humano/Gigante"). `roll_sailor()` continua sendo o
## único caminho que o jogo de verdade usa.
func force_add(race: Race, quality_index: int) -> Dictionary:
	var entry: Dictionary = _make_entry(race, quality_index)
	hired.append(entry)
	changed.emit()
	return entry


## Muda o estado de saúde de UM marinheiro, ou de TODOS se `id` for "" --
## o Painel de Admin usa a versão "todos" (botão só, sem precisar listar
## marinheiro por marinheiro pra testar o efeito rápido).
func set_status(id: String, status: String) -> void:
	var touched: bool = false
	for entry in hired:
		if id == "" or entry["id"] == id:
			entry["status"] = status
			touched = true
	if touched:
		changed.emit()


func dismiss(id: String) -> void:
	for i in hired.size():
		if hired[i]["id"] == id:
			hired.remove_at(i)
			changed.emit()
			return


func bonus_for(entry: Dictionary) -> Dictionary:
	var race: Race = entry["race"]
	var mult: float = QUALITIES[entry["quality_index"]]["mult"]
	var result: Dictionary = {}
	for key in RACE_BASE_BONUS.get(race, {}):
		result[key] = RACE_BASE_BONUS[race][key] * mult
	return result


func is_contributing(entry: Dictionary) -> bool:
	return entry.get("active", true) and entry.get("status", STATUS_READY) == STATUS_READY


## Soma os bônus de todo marinheiro ATIVO (com ração em dia) E "Pronto" (sem
## ferimento/doença) -- mesmo formato de `OfficerRoster.get_officer_bonuses()`,
## pra `ship_base.gd` somar os dois junto com `ShipInventory.get_total_bonuses()`.
func get_total_bonuses() -> Dictionary:
	var totals: Dictionary = {}
	for entry in hired:
		if not is_contributing(entry):
			continue
		var bonus: Dictionary = bonus_for(entry)
		for key in bonus:
			totals[key] = totals.get(key, 0.0) + bonus[key]
	return totals


func food_upkeep_for(entry: Dictionary) -> float:
	var race: Race = entry["race"]
	return FOOD_PER_SAILOR_PER_TICK * RACE_FOOD_UPKEEP_MULT.get(race, 1.0)


func _consume_food_tick() -> void:
	if hired.is_empty():
		return
	var available: float = ShipInventory.materials.get(FOOD_MATERIAL, 0)
	var changed_any: bool = false
	# Ordem de prioridade: quem já está ativo come primeiro (mantém o bônus
	# de quem já estava funcionando), sobra reativa quem estava inativo --
	# evita ligar/desligar um marinheiro já ativo por causa de outro novo
	# que acabou de entrar no pool.
	hired.sort_custom(func(a, b): return a.get("active", true) and not b.get("active", true))
	for entry in hired:
		var cost: float = food_upkeep_for(entry)
		var should_be_active: bool = available >= cost
		if should_be_active:
			available -= cost
		if entry.get("active", true) != should_be_active:
			entry["active"] = should_be_active
			changed_any = true
	ShipInventory.materials[FOOD_MATERIAL] = maxf(0.0, available)
	if changed_any:
		changed.emit()


func _weighted_pick_race() -> Race:
	var total: float = 0.0
	for race in RACE_WEIGHTS:
		total += RACE_WEIGHTS[race]
	var roll: float = _rng.randf() * total
	var acc: float = 0.0
	for race in RACE_WEIGHTS:
		acc += RACE_WEIGHTS[race]
		if roll <= acc:
			return race
	return Race.HUMAN


func _weighted_pick_quality() -> int:
	var total: float = 0.0
	for q in QUALITIES:
		total += q["weight"]
	var roll: float = _rng.randf() * total
	var acc: float = 0.0
	for i in QUALITIES.size():
		acc += QUALITIES[i]["weight"]
		if roll <= acc:
			return i
	return 0


func _generate_name(race: Race) -> String:
	var first: String = FIRST_NAMES[race][_rng.randi() % FIRST_NAMES[race].size()]
	var title: String = TITLES[race][_rng.randi() % TITLES[race].size()]
	return "%s %s" % [first, title]
