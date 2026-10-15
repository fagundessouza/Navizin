extends Node
## Autoload: os 5 Oficiais de Bordo (Timoneiro/Mestre Canhoneiro/Carpinteiro/
## Navegador/Cozinheiro) -- slots FIXOS por cargo (não uma lista de N
## oficiais contratáveis), cada um concedendo um bônus direto quando
## contratado. Separado de `ShipInventory`/`CaptainInventory` porque um
## oficial não é um ITEM fabricado/equipado num slot de peça -- é uma vaga
## de tripulação preenchida ou não, com seu próprio custo de contratação.
##
## SEM SISTEMA DE RECRUTAMENTO REAL AINDA (nenhum pedido descreveu um): pra
## não inventar uma economia de contratação do zero, "contratar" aqui só
## consome Ouro (material já existente, sem moeda nova) e liga o bônus na
## hora -- sem pool de candidatos, sem nome/retrato individual por oficial.
## Mesmo padrão "dado real, sistema ao redor ainda placeholder" já usado em
## `CaptainAttributes.available_points`.

signal changed

const ROLES: Array[String] = ["timoneiro", "canhoneiro", "carpinteiro", "navegador", "cozinheiro"]

const ROLE_NAMES: Dictionary = {
	"timoneiro": "Timoneiro", "canhoneiro": "Mestre Canhoneiro", "carpinteiro": "Carpinteiro",
	"navegador": "Navegador", "cozinheiro": "Cozinheiro",
}

## O que cada cargo concede ao navio/tropa quando contratado -- usa as
## mesmas chaves de stat já definidas em `item_database.gd`
## (`turn_rate_bonus`/`reload_speed_bonus`/`braking_bonus`/
## `wind_resistance_bonus`/`effect_resistance_bonus`), consumidas do mesmo
## jeito "calculado, ainda sem física/combate pra ler" que todo o resto do
## jogo já segue. Carpinteiro e Cozinheiro somam no total do NAVIO
## (`hull_bonus`/`cargo_bonus`, cuidado de casco e porão); os outros 3 nos
## stats específicos do papel.
const ROLE_BONUS: Dictionary = {
	"timoneiro": {"turn_rate_bonus": 0.15},
	"canhoneiro": {"reload_speed_bonus": 0.18},
	"carpinteiro": {"braking_bonus": 0.1, "hull_bonus": 80.0},
	"navegador": {"wind_resistance_bonus": 0.15, "node_speed_bonus": 6.0},
	"cozinheiro": {"effect_resistance_bonus": 0.12, "cargo_bonus": 10.0},
}

const ROLE_DESCRIPTIONS: Dictionary = {
	"timoneiro": "Melhora o giro do navio no leme.",
	"canhoneiro": "Acelera a recarga das baterias.",
	"carpinteiro": "Reforça o casco e a frenagem.",
	"navegador": "Resiste melhor ao vento e acelera a navegação entre nós.",
	"cozinheiro": "Melhora a resistência a efeitos da tropa e libera mais porão.",
}

const HIRE_COST_MATERIAL: String = "Ouro"
const HIRE_COST_QTY: int = 10

## cargo -> true/false (contratado ou não).
var hired: Dictionary = {}


func _ready() -> void:
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
	changed.emit()
	return true


func dismiss(role: String) -> void:
	if not is_hired(role):
		return
	hired[role] = false
	changed.emit()


## Soma os bônus de todo cargo contratado -- `ship_base.gd` pode somar isso
## em cima de `ShipInventory.get_total_bonuses()` do mesmo jeito que já soma
## equipamento, quando/se um sistema de giro/recarga/frenagem passar a
## existir de verdade.
func get_officer_bonuses() -> Dictionary:
	var totals: Dictionary = {}
	for role in ROLES:
		if not is_hired(role):
			continue
		for key in ROLE_BONUS[role]:
			totals[key] = totals.get(key, 0.0) + ROLE_BONUS[role][key]
	return totals
