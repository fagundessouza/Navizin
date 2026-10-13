extends Node
## Autoload: pontos de atributo social do capitão (Liderança, Carisma,
## Persuasão), atribuídos pelos 3 brasões na Ficha do Capitão. Sem XP/nível
## de verdade ainda -- `available_points` começa com um valor fixo só pra dar
## o que gastar e testar o fluxo; trocar por progressão real depois é só
## mudar quem alimenta esse número, sem mexer em quem gasta.

signal changed

var leadership: int = 0
var charisma: int = 0
var persuasion: int = 0
var available_points: int = 5

const ATTR_KEYS: Array[String] = ["leadership", "charisma", "persuasion"]


func get_value(attr: String) -> int:
	match attr:
		"leadership":
			return leadership
		"charisma":
			return charisma
		"persuasion":
			return persuasion
		_:
			return 0


## Gasta 1 ponto disponível no atributo pedido. Retorna false sem gastar nada
## se não tiver ponto sobrando ou se `attr` não for um dos 3 conhecidos.
func spend(attr: String) -> bool:
	if available_points <= 0 or not ATTR_KEYS.has(attr):
		return false
	match attr:
		"leadership":
			leadership += 1
		"charisma":
			charisma += 1
		"persuasion":
			persuasion += 1
	available_points -= 1
	changed.emit()
	return true
