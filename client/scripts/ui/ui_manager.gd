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

## GAME JUICE (pedido explícito desta rodada): dois efeitos reutilizáveis
## chamados de QUALQUER modal/slot do jogo em vez de reescrever o mesmo
## tween em cada um dos ~10 arquivos de UI -- `animate_modal_open()` (uma
## linha a mais em cada `open()`) e `add_hover_pop()` (uma linha a mais ao
## construir cada slot/card). Isso NÃO vira uma classe-base de modal (o
## projeto evita generalizar cedo demais, ver `ship_inventory.gd`/
## `captain_inventory.gd` -- craft/durabilidade duplicados de propósito);
## aqui é só uma função utilitária pura, sem estado por modal, então
## compartilhar não cria o mesmo acoplamento.
const HOVER_POP_SCALE: Vector2 = Vector2(1.08, 1.08)
const MODAL_OPEN_FROM_SCALE: Vector2 = Vector2(0.9, 0.9)

var _current_modal: Control = null
var _hover_sfx: AudioStreamPlayer = null


func _ready() -> void:
	_hover_sfx = AudioStreamPlayer.new()
	_hover_sfx.stream = preload("res://assets/audio/sfx_hover.wav")
	_hover_sfx.volume_db = -8.0
	add_child(_hover_sfx)


## Abertura de modal "pop" (escala 0.9 -> 1.0 + transparência 0 -> 1,
## `EASE_OUT`) em vez de aparecer instantâneo -- chamado do `open()` de cada
## modal, DEPOIS de `visible = true`. Centraliza o pivô na própria janela
## pra escalar a partir do meio, não do canto.
func animate_modal_open(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = MODAL_OPEN_FROM_SCALE
	control.modulate.a = 0.0
	var tw := control.create_tween()
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(control, "scale", Vector2.ONE, 0.22)
	tw.tween_property(control, "modulate:a", 1.0, 0.16)


## Efeito hover orgânico pra slot de item/card de personagem: "pop" elástico
## leve (1.0 -> 1.08x) ao entrar o mouse, volta ao sair, com um tique de som
## tátil. Uma chamada só na criação do Control resolve os dois sinais.
func add_hover_pop(control: Control) -> void:
	control.mouse_entered.connect(_on_hover_enter.bind(control))
	control.mouse_exited.connect(_on_hover_exit.bind(control))


func _on_hover_enter(control: Control) -> void:
	if not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	var tw := control.create_tween()
	tw.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(control, "scale", HOVER_POP_SCALE, 0.35)
	_hover_sfx.play()


func _on_hover_exit(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var tw := control.create_tween()
	tw.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(control, "scale", Vector2.ONE, 0.3)


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
