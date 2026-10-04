extends Node
## Singleton de estado global do jogo.
##
## Guarda o que é compartilhado entre cenas: sessão, configurações e
## o navio do jogador. Não contém lógica de rede (isso fica em NetworkClient).
##
## Acesso em qualquer script: `GameManager.<membro>`.

## Emitido quando o estado do jogador muda, para a UI reagir sem acoplamento.
signal player_state_changed(state: Dictionary)

## Identificador do jogador logado, vazio enquanto não há sessão.
var player_id: String = ""

func _ready() -> void:
	# Ponto de inicialização: carregar configurações locais, se houver.
	pass
