extends Node
## Autoload: Painel de Admin/Debug global, estilo "Admin Menu" do FiveM --
## `is_admin_mode = true` fixo (ambiente de desenvolvimento local, sem
## servidor/autenticação de verdade pra checar quem é admin ainda -- mesmo
## padrão "flag real, sistema de permissão ao redor ainda placeholder" já
## usado em `CaptainAttributes.available_points`). F3 alterna a janela em
## QUALQUER cena (mar, cidade, batalha de abordagem) -- o painel e o overlay
## de IDs vivem direto sob `get_tree().root`, não dentro da cena atual, pra
## sobreviver a troca de cena sem precisar reabrir.
##
## OVERLAY DE IDS: quando `show_debug_ids` está ligado, qualquer Control
## marcado com `UIManager.add_hover_pop(control, debug_id)` (o MESMO
## call-site que já liga o "pop" de hover em todo slot/card do jogo, so
## passando um id a mais) ganha uma etiqueta flutuante com esse id. Pra NÓS
## do mundo (navio do jogador, marcadores de abordagem), este arquivo varre
## os grupos relevantes direto.

signal changed

const PANEL_SCENE: PackedScene = preload("res://scenes/ui/admin_panel.tscn")
const DEBUG_ID_META: String = "admin_debug_id"
const WORLD_LABEL_COLOR: Color = Color(0.4, 0.95, 0.5, 1.0)
const UI_LABEL_COLOR: Color = Color(1.0, 0.85, 0.3, 1.0)

var is_admin_mode: bool = true
var show_debug_ids: bool = false

var _panel: Control = null
var _overlay_layer: CanvasLayer = null
var _world_label_pool: Array[Label] = []
var _ui_label_pool: Array[Label] = []


func _ready() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 90
	get_tree().root.add_child.call_deferred(_overlay_layer)


func _unhandled_input(event: InputEvent) -> void:
	if not is_admin_mode:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F3:
		toggle_panel()
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func toggle_panel() -> void:
	if _panel == null:
		_panel = PANEL_SCENE.instantiate()
		get_tree().root.add_child(_panel)
		_panel.visible = false
	_panel.visible = not _panel.visible
	if _panel.visible and _panel.has_method("open"):
		_panel.open()


func _process(_delta: float) -> void:
	if show_debug_ids:
		_update_debug_overlay()
	elif not _world_label_pool.is_empty() or not _ui_label_pool.is_empty():
		_clear_overlay()


func _clear_overlay() -> void:
	for label in _world_label_pool:
		label.visible = false
	for label in _ui_label_pool:
		label.visible = false


## Nós do MUNDO (não-UI): navio do jogador + marcadores de abordagem ativos
## -- posição convertida de espaço de mundo pra espaço de tela pela câmera
## atual, então a etiqueta acompanha o nó mesmo com a câmera se movendo.
func _update_debug_overlay() -> void:
	var world_nodes: Array = []
	for group in ["player_ship", "boarding_marker"]:
		world_nodes.append_array(get_tree().get_nodes_in_group(group))

	var viewport: Viewport = get_viewport()
	var camera: Camera2D = viewport.get_camera_2d() if viewport != null else null
	for i in world_nodes.size():
		var node: Node2D = world_nodes[i] as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var label: Label = _pooled_label(_world_label_pool, WORLD_LABEL_COLOR)
		var screen_pos: Vector2 = node.global_position
		if camera != null:
			screen_pos = (node.global_position - camera.global_position) * camera.zoom + viewport.get_visible_rect().size * 0.5
		label.text = "%s (id %d)" % [node.name, node.get_instance_id()]
		label.position = screen_pos + Vector2(-label.size.x * 0.5, -70.0)
		label.visible = true

	# Esconde o resto do pool de nós de mundo que sobrou de um frame anterior
	# com mais nós visíveis que agora.
	for i in range(world_nodes.size(), _world_label_pool.size()):
		_world_label_pool[i].visible = false

	_update_ui_debug_labels()


## Controls de UI marcados com `UIManager.add_hover_pop(control, debug_id)`
## -- varre a árvore atual (cada chamada é barata, só roda enquanto o
## overlay está ligado, uma ferramenta de debug não precisa ser O(1)).
func _update_ui_debug_labels() -> void:
	var tagged: Array[Control] = []
	_collect_tagged(get_tree().root, tagged)
	for i in tagged.size():
		var control: Control = tagged[i]
		var label: Label = _pooled_label(_ui_label_pool, UI_LABEL_COLOR)
		label.text = str(control.get_meta(DEBUG_ID_META))
		label.global_position = control.global_position + Vector2(2, -14)
		label.visible = control.is_visible_in_tree()
	for i in range(tagged.size(), _ui_label_pool.size()):
		_ui_label_pool[i].visible = false


func _collect_tagged(node: Node, result: Array[Control]) -> void:
	var control := node as Control
	if control != null and control.has_meta(DEBUG_ID_META):
		result.append(control)
	for child in node.get_children():
		_collect_tagged(child, result)


func _pooled_label(pool: Array[Label], color: Color) -> Label:
	for label in pool:
		if not label.visible:
			return label
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", 11)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(label)
	pool.append(label)
	return label
