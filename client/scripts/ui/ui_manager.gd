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

## Pilha de verdade (não um único "modal atual"), em ordem de abertura --
## achado rodando de verdade via MCP, não suposto lendo o código: um único
## `_current_modal` global não representa aninhamento. Abrir Munição
## (dentro da Ficha do Navio) fechava a PRÓPRIA Ficha do Navio, e abrir
## Refino (dentro de Fabricação) fechava a PRÓPRIA Fabricação -- os dois
## ficavam marcados como "o modal atual", concorrendo entre si, mesmo sendo
## pai e filho, não irmãos. `open_modal()` agora só fecha IRMÃOS de verdade
## (mesmo `get_parent()`, ou seja, mesmo `ModalOverlay`) em vez de fechar
## QUALQUER coisa que estivesse marcada como "atual" em qualquer nível.
var _modal_stack: Array[Control] = []
var _hover_sfx: AudioStreamPlayer = null

## REGISTRO/PILHA DE MODAIS EM RUNTIME (pedido explícito -- migração completa
## do projeto pra instanciação dinâmica, revertendo a decisão anterior de
## manter tudo instanciado no editor -- ver `.clauderules` e o checkpoint
## desta rodada no STATE.md). Cada modal continua dono do próprio
## `open()`/`close()` (regra do `.clauderules` nunca mudou) -- isto só decide
## QUANDO instanciar e ONDE guardar a instância, reaproveitando a mesma
## lógica de exclusão mútua de `open_modal()`/`close_modal()` acima em vez de
## duplicá-la.
##
## Instância por (overlay, modal_id), não só por modal_id: o mesmo modal
## (ex. `crew_management_submodal`) é aberto por MAIS de um host com
## configuração diferente (`read_only`, `show_sailors_section`) -- Ficha do
## Navio é só consulta, Taverna contrata de verdade. Cada overlay guarda sua
## própria instância configurada, sem reaproveitar a de outro host por
## engano.
var _modal_scenes: Dictionary = {}
## "<overlay_instance_id>::<modal_id>" -> Control já instanciado (reaproveitado
## entre aberturas, só show/hide -- igual era quando ficavam no .tscn, não
## recria o nó toda vez que abre).
var _modal_instances: Dictionary = {}


func _ready() -> void:
	_hover_sfx = AudioStreamPlayer.new()
	_hover_sfx.stream = preload("res://assets/audio/sfx_hover.wav")
	_hover_sfx.volume_db = -8.0
	add_child(_hover_sfx)
	var base_font: FontFile = load(READABLE_FONT_PATH)
	_readable_font = FontVariation.new()
	_readable_font.base_font = base_font
	_readable_font.variation_opentype = {2003265652: 700}  # 'wght' = 700 (negrito)
	_register_modal_scenes()


## Único lugar com a lista modal_id -> cena -- adicionar um modal novo ao
## sistema é uma linha aqui, não uma instância nova espalhada em algum
## `.tscn`.
func _register_modal_scenes() -> void:
	_modal_scenes["cargo"] = preload("res://scenes/ui/modals/ship_info_modal.tscn")
	_modal_scenes["ammo"] = preload("res://scenes/ui/modals/ship_info_modal.tscn")
	_modal_scenes["supplies"] = preload("res://scenes/ui/modals/ship_info_modal.tscn")
	_modal_scenes["crew_management"] = preload("res://scenes/ui/modals/crew_management_submodal.tscn")
	_modal_scenes["crew_card"] = preload("res://scenes/ui/modals/crew_card_modal.tscn")
	_modal_scenes["vault"] = preload("res://scenes/ui/modals/vault_modal.tscn")
	_modal_scenes["crafting"] = preload("res://scenes/ui/modals/crafting_modal.tscn")
	_modal_scenes["refinement"] = preload("res://scenes/ui/modals/refinement_modal.tscn")
	_modal_scenes["trade"] = preload("res://scenes/ui/modals/trade_modal.tscn")
	_modal_scenes["captain_profile"] = preload("res://scenes/ui/modals/captain_profile_modal.tscn")
	_modal_scenes["life_skills"] = preload("res://scenes/ui/modals/life_skills_panel.tscn")
	_modal_scenes["captain_panel"] = preload("res://scenes/ui/modals/captain_panel.tscn")
	_modal_scenes["ship_status"] = preload("res://scenes/ui/ship_status_modal.tscn")


## Retorna a instância do modal `modal_id` dentro de `overlay`, criando na
## primeira chamada (e só então). Chamadas seguintes devolvem a mesma
## instância já configurada. `configure` (opcional) roda ANTES de
## `overlay.add_child()` -- IMPORTANTE rodar antes, não depois: `_ready()`
## do modal dispara na hora que entra na árvore, e lê `@export var` como
## `info_mode`/`read_only` pra decidir título/seções visíveis logo ali;
## configurar DEPOIS de `add_child()` deixaria `_ready()` ler o valor padrão
## errado (achado rodando a migração de verdade -- `AmmoModal` nascia com
## título "Porão de Carga" até essa ordem ser corrigida):
##   UIManager.get_modal("ammo", overlay, func(m): m.info_mode = "ammo")
func get_modal(modal_id: String, overlay: Node, configure: Callable = Callable()) -> Control:
	var key: String = "%d::%s" % [overlay.get_instance_id(), modal_id]
	if _modal_instances.has(key) and is_instance_valid(_modal_instances[key]):
		return _modal_instances[key]
	var scene: PackedScene = _modal_scenes.get(modal_id)
	if scene == null:
		push_error("UIManager.get_modal: modal_id desconhecido: %s" % modal_id)
		return null
	var instance: Control = scene.instantiate()
	if configure.is_valid():
		configure.call(instance)
	overlay.add_child(instance)
	_modal_instances[key] = instance
	return instance


## Atalho pro par comum "pega (cria se precisar) + abre", já passando pela
## exclusão mútua de `open_modal()`.
func open_modal_id(modal_id: String, overlay: Node, configure: Callable = Callable()) -> Control:
	var instance: Control = get_modal(modal_id, overlay, configure)
	if instance != null:
		open_modal(instance)
	return instance


## ESC fecha o modal no TOPO da pilha (pedido explícito -- "fechamento via
## tecla ESC") -- o último aberto, que é o mais aninhado/mais por cima
## visualmente, não necessariamente o último item do array se algum tiver
## sido invalidado sem passar por `close_modal()` (daí o loop de trás pra
## frente descartando instâncias mortas).
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	while not _modal_stack.is_empty():
		var top: Control = _modal_stack[-1]
		if not is_instance_valid(top):
			_modal_stack.pop_back()
			continue
		close_modal(top)
		get_viewport().set_input_as_handled()
		return


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


## Fecha qualquer IRMÃO do modal pedido (mesmo `get_parent()` -- ou seja,
## mesmo `ModalOverlay`/mesmo nível de aninhamento) e abre o novo, trazendo-o
## pra frente. Chamado tanto por clique de botão quanto pelo auto-abrir de
## entrada no distrito (`city_district_base.gd`).
##
## Só fecha IRMÃOS, não qualquer coisa aberta em QUALQUER lugar -- achado
## rodando de verdade via MCP: a versão antiga rastreava um `_current_modal`
## único pro jogo inteiro, então abrir um sub-modal (Munição dentro da Ficha
## do Navio, Refino dentro de Fabricação) fechava o PRÓPRIO modal pai, já
## que os dois disputavam o mesmo "atual" apesar de serem pai e filho, não
## concorrentes de verdade. Dois modais só competem entre si quando
## morariam no MESMO overlay (duas abas de distrito, os 4 painéis do HUD,
## os 3 sub-modais da Ficha do Navio entre si) -- nunca entre um modal e o
## que o abriga.
func open_modal(modal: Control) -> void:
	var parent: Node = modal.get_parent()
	for existing in _modal_stack.duplicate():
		if existing != modal and is_instance_valid(existing) and existing.get_parent() == parent:
			close_modal(existing)
	_modal_stack.erase(modal)
	_modal_stack.append(modal)
	modal.move_to_front()
	modal.open()


## Pra quando algo precisa fechar explicitamente em vez de abrir outro --
## fecha e tira da pilha.
func close_modal(modal: Control) -> void:
	modal.close()
	_modal_stack.erase(modal)
