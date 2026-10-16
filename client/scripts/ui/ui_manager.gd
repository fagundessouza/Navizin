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

## LEGIBILIDADE (pedido explícito -- "fonte atual embaçada/pixelada"): o tema
## padrão do projeto (`theme_navizin.tres`) usa `PirataOne-Regular.ttf` pra
## TUDO, inclusive rótulo pequeno -- é uma fonte decorativa/blackletter,
## ótima pra título grande, ilegível em 10-13px (letras grudam, contorno
## sem definição). `Cinzel-Variable.ttf` já era usado pra título em
## `captain_status.tscn`; isto generaliza o mesmo tratamento (peso 700 +
## contorno escuro) pra texto pequeno de corpo em qualquer Label/Button
## construído por código, sem precisar duplicar o `FontVariation` em cada
## cena.
const READABLE_FONT_PATH: String = "res://assets/fonts/Cinzel-Variable.ttf"
var _readable_font: FontVariation = null

var _current_modal: Control = null
var _hover_sfx: AudioStreamPlayer = null


func _ready() -> void:
	_hover_sfx = AudioStreamPlayer.new()
	_hover_sfx.stream = preload("res://assets/audio/sfx_hover.wav")
	_hover_sfx.volume_db = -8.0
	add_child(_hover_sfx)
	var base_font: FontFile = load(READABLE_FONT_PATH)
	_readable_font = FontVariation.new()
	_readable_font.base_font = base_font
	_readable_font.variation_opentype = {2003265652: 700}  # 'wght' = 700 (negrito)


## Aplica a fonte gótica legível + contorno escuro num Label/Button
## construído por código (o tema padrão já cobre o resto da UI). `size`
## opcional só quando o padrão do tema (15px) não serve.
func apply_readable_font(control: Control, size: int = 0) -> void:
	control.add_theme_font_override("font", _readable_font)
	if size > 0:
		control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 1.0))
	control.add_theme_constant_override("outline_size", 3)


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
## `debug_id` opcional: grava num meta próprio (`AdminManager.DEBUG_ID_META`)
## que o overlay de IDs do Painel de Admin (F3) lê pra desenhar a etiqueta
## flutuante -- mesma chamada que já liga o hover em todo slot/card do jogo,
## só com um id a mais, em vez de marcar os Controls em dois lugares.
func add_hover_pop(control: Control, debug_id: String = "") -> void:
	# Guardado contra chamada repetida no MESMO Control (slots reconstruídos
	# a cada refresh, como a grade de Inventário do Navio, podiam chamar
	# isto de novo em cima de um Control já conectado -- Godot lança erro ao
	# conectar o mesmo par sinal+callable duas vezes).
	if not control.mouse_entered.is_connected(_on_hover_enter):
		control.mouse_entered.connect(_on_hover_enter.bind(control))
		control.mouse_exited.connect(_on_hover_exit.bind(control))
	if debug_id != "":
		control.set_meta(AdminManager.DEBUG_ID_META, debug_id)


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
