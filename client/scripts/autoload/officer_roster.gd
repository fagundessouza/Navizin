extends Node
## Autoload: os 8 Oficiais de Bordo (Timoneiro/Mestre Canhoneiro/
## Carpinteiro/Navegador/Cozinheiro/Médico/Imediato do Capitão/Músico) --
## slots FIXOS por cargo (não uma lista de N oficiais contratáveis), cada
## um concedendo um bônus direto quando contratado. Separado de
## `ShipInventory`/`CaptainInventory` porque um oficial não é um ITEM
## fabricado/equipado num slot de peça -- é uma vaga de tripulação
## preenchida ou não, com seu próprio custo de contratação.
##
## EXPANDIDO DE 5 PRA 8 CARGOS NESTA RODADA (pedido explícito, junto com os
## 32 retratos profissão x raça processados de
## `~/Downloads/Tortuga/Tripulação/`) -- os 3 cargos novos (Médico/Imediato/
## Musico) seguem o mesmo molde dos 5 originais: bônus real numa chave de
## stat já existente, mesmo caso "calculado, ainda sem física/combate pra
## ler" pra quem não tinha consumidor (ver `ROLE_BONUS`), EXCETO o Imediato,
## cujo `leadership_bonus` JÁ É consumido de verdade por
## `boarding_manager.gd` (soma junto com o de `CaptainInventory`).
##
## RETRATO POR RAÇA: cada cargo contratado sorteia uma das 4 raças da arte
## entregue (Humano/Goblin/Anão/Morto-Vivo) na hora da contratação --
## puramente visual, não afeta o bônus do cargo (o bônus é do CARGO, não da
## raça, pra não duplicar o sistema de raças que já existe em
## `TavernHireSystem` com um significado diferente). `hired_race` guarda
## qual raça saiu, pra o retrato não trocar sozinho toda vez que a UI
## reabre.
##
## SEM SISTEMA DE RECRUTAMENTO REAL AINDA (nenhum pedido descreveu um): pra
## não inventar uma economia de contratação do zero, "contratar" aqui só
## consome Ouro (material já existente, sem moeda nova) e liga o bônus na
## hora -- sem pool de candidatos, sem nome individual por oficial. Mesmo
## padrão "dado real, sistema ao redor ainda placeholder" já usado em
## `CaptainAttributes.available_points`.

signal changed

const ROLES: Array[String] = [
	"timoneiro", "canhoneiro", "carpinteiro", "navegador", "cozinheiro",
	"medico", "imediato", "musico",
]

const ROLE_NAMES: Dictionary = {
	"timoneiro": "Timoneiro", "canhoneiro": "Mestre Canhoneiro", "carpinteiro": "Carpinteiro",
	"navegador": "Navegador", "cozinheiro": "Cozinheiro", "medico": "Médico",
	"imediato": "Imediato do Capitão", "musico": "Músico",
}

const PORTRAIT_DIR: String = "res://assets/ui/crew/portraits/"
## As 4 Raças Oficiais do projeto (pedido explícito desta rodada -- Humano/
## Goblin/Anão/Morto-Vivo; "Goblin Puro" é um TÍTULO dentro de Goblin, não
## uma 5ª raça própria, por isso não entra nesta lista).
const PORTRAIT_RACES: Array[String] = ["human", "goblin", "dwarf", "undead"]
const RACE_LABELS: Dictionary = {
	"human": "Humano", "goblin": "Goblin", "dwarf": "Anão", "undead": "Morto-Vivo",
}

## Mapeamento EXPLÍCITO dos 32 retratos (pedido explícito -- "mapeie
## explicitamente... usando os 32 arquivos fatiados"), em vez de montar o
## caminho por concatenação de string (`"%s_%s.png" % [prefixo, raça]`): um
## nome de arquivo errado digitado aqui dá erro na hora de ler o dicionário,
## não um `load()` silenciosamente apontando pra um arquivo que não existe.
## Os 32 arquivos (4 lotes x 2 profissões x 4 raças, processados de
## `~/Downloads/Tortuga/Tripulação/`) foram conferidos um a um antes desta
## lista -- `ls res://assets/ui/crew/portraits/` bate exatamente com os 32
## caminhos abaixo.
const PORTRAITS: Dictionary = {
	"timoneiro": {
		"human": "helmsman_human.png", "goblin": "helmsman_goblin.png",
		"dwarf": "helmsman_dwarf.png", "undead": "helmsman_undead.png",
	},
	"navegador": {
		"human": "navigator_human.png", "goblin": "navigator_goblin.png",
		"dwarf": "navigator_dwarf.png", "undead": "navigator_undead.png",
	},
	"canhoneiro": {
		"human": "cannoneer_human.png", "goblin": "cannoneer_goblin.png",
		"dwarf": "cannoneer_dwarf.png", "undead": "cannoneer_undead.png",
	},
	"carpinteiro": {
		"human": "carpenter_human.png", "goblin": "carpenter_goblin.png",
		"dwarf": "carpenter_dwarf.png", "undead": "carpenter_undead.png",
	},
	"cozinheiro": {
		"human": "cook_human.png", "goblin": "cook_goblin.png",
		"dwarf": "cook_dwarf.png", "undead": "cook_undead.png",
	},
	"medico": {
		"human": "doctor_human.png", "goblin": "doctor_goblin.png",
		"dwarf": "doctor_dwarf.png", "undead": "doctor_undead.png",
	},
	"imediato": {
		"human": "first_mate_human.png", "goblin": "first_mate_goblin.png",
		"dwarf": "first_mate_dwarf.png", "undead": "first_mate_undead.png",
	},
	"musico": {
		"human": "musician_human.png", "goblin": "musician_goblin.png",
		"dwarf": "musician_dwarf.png", "undead": "musician_undead.png",
	},
}

## O que cada cargo concede ao navio/tropa quando contratado -- usa as
## mesmas chaves de stat já definidas em `item_database.gd`
## (`turn_rate_bonus`/`reload_speed_bonus`/`braking_bonus`/
## `wind_resistance_bonus`/`effect_resistance_bonus`/`leadership_bonus`/
## `node_speed_bonus`), consumidas do mesmo jeito "calculado, ainda sem
## física/combate pra ler" que todo o resto do jogo segue -- EXCETO
## `leadership_bonus` (Imediato), que `boarding_manager.gd` já soma de
## verdade na potência de abordagem. Carpinteiro e Cozinheiro somam no total
## do NAVIO (`hull_bonus`/`cargo_bonus`, cuidado de casco e porão); os
## outros nos stats específicos do papel.
const ROLE_BONUS: Dictionary = {
	"timoneiro": {"turn_rate_bonus": 0.15},
	"canhoneiro": {"reload_speed_bonus": 0.18},
	"carpinteiro": {"braking_bonus": 0.1, "hull_bonus": 80.0},
	"navegador": {"wind_resistance_bonus": 0.15, "node_speed_bonus": 6.0},
	"cozinheiro": {"effect_resistance_bonus": 0.12, "cargo_bonus": 10.0},
	"medico": {"effect_resistance_bonus": 0.1},
	"imediato": {"leadership_bonus": 10.0},
	"musico": {"node_speed_bonus": 4.0},
}

const ROLE_DESCRIPTIONS: Dictionary = {
	"timoneiro": "Melhora o giro do navio no leme.",
	"canhoneiro": "Acelera a recarga das baterias.",
	"carpinteiro": "Reforça o casco e a frenagem.",
	"navegador": "Resiste melhor ao vento e acelera a navegação entre nós.",
	"cozinheiro": "Melhora a resistência a efeitos da tropa e libera mais porão.",
	"medico": "Melhora a resistência a efeitos da tripulação.",
	"imediato": "Soma Liderança direto na potência de abordagem, igual joia/traje do Capitão.",
	"musico": "Anima a tripulação -- acelera o trajeto entre nós.",
}

const HIRE_COST_MATERIAL: String = "Ouro"
const HIRE_COST_QTY: int = 10

## cargo -> true/false (contratado ou não).
var hired: Dictionary = {}
## cargo -> "human"/"goblin"/"dwarf"/"undead", só preenchido pra cargo
## contratado. Sorteado em `hire()`, fica fixo até `dismiss()`.
var hired_race: Dictionary = {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for role in ROLES:
		hired[role] = false


func is_hired(role: String) -> bool:
	return hired.get(role, false)


func can_hire(role: String) -> bool:
	if not ROLES.has(role) or is_hired(role):
		return false
	return ShipInventory.materials.get(HIRE_COST_MATERIAL, 0) >= HIRE_COST_QTY


func hire(role: String) -> bool:
	if not can_hire(role):
		return false
	ShipInventory.materials[HIRE_COST_MATERIAL] -= HIRE_COST_QTY
	hired[role] = true
	hired_race[role] = PORTRAIT_RACES[_rng.randi() % PORTRAIT_RACES.size()]
	changed.emit()
	return true


func dismiss(role: String) -> void:
	if not is_hired(role):
		return
	hired[role] = false
	hired_race.erase(role)
	changed.emit()


## Caminho do retrato pro cargo (contratado ou não -- sem contratar ainda,
## devolve a variante "human" só pra ter algo pra mostrar numa prévia/vaga
## vazia; `ShipStatusModal`/`CrewCardModal` decidem se mostram isso ou um
## ícone de vaga vazia).
func portrait_path(role: String) -> String:
	return portrait_path_for(role, hired_race.get(role, "human"))


## Versão explícita (cargo + raça), sem depender do que está contratado --
## `TavernHireSystem` chama isto direto pra montar o retrato de um
## Marinheiro/Operário (que não é um CARGO de `OfficerRoster`, mas usa a
## MESMA prancha de 32 retratos, sorteando a profissão só pra variar o
## visual).
func portrait_path_for(role: String, race: String) -> String:
	var filename: String = PORTRAITS.get(role, {}).get(race, "")
	if filename == "":
		return ""
	return PORTRAIT_DIR + filename


func race_label(role: String) -> String:
	return RACE_LABELS.get(hired_race.get(role, ""), "")


## Soma os bônus de todo cargo contratado -- `ship_base.gd` soma isso em
## cima de `ShipInventory.get_total_bonuses()`/`TavernHireSystem.get_total_bonuses()`
## do mesmo jeito que já soma equipamento e marinheiros.
func get_officer_bonuses() -> Dictionary:
	var totals: Dictionary = {}
	for role in ROLES:
		if not is_hired(role):
			continue
		for key in ROLE_BONUS[role]:
			totals[key] = totals.get(key, 0.0) + ROLE_BONUS[role][key]
	return totals
