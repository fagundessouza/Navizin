extends Node
## Singleton de comunicação com o servidor FastAPI.
##
## Responsável por enviar intenções (ex.: mover o navio) e receber estados.
## Nesta fase é um esqueleto: as chamadas reais entram quando a API tiver rotas.

## Emitido quando uma resposta do servidor chega com sucesso.
signal request_succeeded(endpoint: String, payload: Dictionary)

## Emitido quando uma chamada falha (rede, HTTP ou JSON inválido).
signal request_failed(endpoint: String, reason: String)

## Endereço base da API em desenvolvimento.
const API_BASE_URL: String = "http://localhost:8000"

func _ready() -> void:
	# Ainda sem conexão: o servidor não expõe rotas de jogo nesta fase.
	pass
