extends Node
## Autoload stub: reputação do jogador e a saudação dos NPCs nos distritos.
##
## Sem sistema de progressão de verdade ainda -- `player_level`/`player_title`
## são valores fixos pra popular a faixa de saudação (`TradeModal`) enquanto
## não existe XP/reputação real. `get_greeting()` é o único ponto de entrada
## que o resto do jogo deveria chamar; trocar os valores fixos por uma conta
## de verdade depois não deve exigir mudar quem chama isso.

## Títulos por faixa de reputação, do mais baixo ao mais alto -- "Flagelo"
## (dos Sete Mares) é a cobiçada última palavra, que todo pirata quer ouvir
## um NPC dizer pra ele.
const TITLES_BY_TIER: Array[String] = ["Grumete", "Corsário", "Capitão", "Flagelo dos Sete Mares"]

var player_level: int = 1
var player_title: String = "Capitão"
var reputation_tier: int = 2  # indice em TITLES_BY_TIER; 2 = "Capitão"

const GREETINGS: Array[String] = [
	"Bem-vindo(a), %s. O que traz por aqui?",
	"%s... não esperava ver você de novo tão cedo.",
	"Ah, %s! Sempre um prazer fazer negócio.",
	"%s! Sua fama chegou antes de você.",
]


## Frase de saudação pro NPC do balcão/estação, considerando o título atual
## do jogador. `npc_name` é decorativo por ora (não muda a frase).
func get_greeting(npc_name: String = "") -> String:
	var template: String = GREETINGS[reputation_tier % GREETINGS.size()]
	return template % player_title


func get_title() -> String:
	return player_title
