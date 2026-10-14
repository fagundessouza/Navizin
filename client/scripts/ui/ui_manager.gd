extends Node
## Autoload: garante um único modal urbano aberto por vez. Antes, cada botão
## de um distrito (Loja/Fabricar/Refinar) chamava `modal.open()` direto --
## nada impedia abrir Refino por cima de Fabricar por cima da Loja,
## empilhando texto/janela sem fim. Agora todo "abrir modal" passa por
## `open_modal()`, que fecha o que estava aberto antes primeiro.
##
## Também resolve profundidade: `move_to_front()` garante que o modal recém
## aberto desenha por cima de qualquer coisa que tenha ficado na frente dele
## por ordem de nó na cena, sem precisar de um `CanvasLayer` dedicado por
## modal (todos os modais de um distrito já são filhos diretos da mesma cena,
## um `CanvasLayer` a mais só pra isso seria complexidade sem ganho aqui).
##
## Cada modal continua dono do próprio botão de fechar (`CloseButton`) e do
## próprio `close()` -- este arquivo só decide QUANDO fechar o anterior, não
## como.

var _current_modal: Control = null


## Fecha o modal atual (se houver um diferente do pedido) e abre o novo,
## trazendo-o pra frente. Chamado tanto por clique de botão quanto pelo
## auto-abrir de entrada no distrito (`city_district_base.gd`).
func open_modal(modal: Control) -> void:
	if _current_modal != null and _current_modal != modal and is_instance_valid(_current_modal):
		_current_modal.close()
	_current_modal = modal
	modal.move_to_front()
	modal.open()


## Pra quando algo precisa fechar explicitamente em vez de abrir outro --
## fecha e esquece, pra não achar que ele ainda é "o modal atual" depois.
func close_modal(modal: Control) -> void:
	modal.close()
	if _current_modal == modal:
		_current_modal = null
