class_name InventoryPickerSubmodal
extends Control
## Submodal suspenso que abre do lado de um slot '+' (equipamento do capitão
## ou do navio) listando só os itens compatíveis daquela categoria. Sem
## inventário de verdade ainda -- `STUB_INVENTORY` é só pra demonstrar o
## filtro por categoria; trocar por dados reais depois é só mudar de onde
## `open_at()` lê a lista, sem mexer em quem chama isso.
##
## Um `Backdrop` cobrindo a tela inteira fecha o submodal ao clicar fora,
## atrás da caixa -- padrão comum de popup/context-menu.

signal item_selected(category: String, item_name: String)

const STUB_INVENTORY: Dictionary = {
	"brincos": ["Brincos de Pérola Negra", "Brincos de Caveira de Prata"],
	"colar": ["Colar do Kraken", "Amuleto de Osso"],
	"anel": ["Anel do Capitão Fantasma", "Anel de Sinete Dourado"],
	"cinto": ["Cinturão de Couro Reforçado", "Faixa Escarlate"],
	"trajes": ["Sobretudo do Corsário", "Casaca da Guarda Real"],
	"grimorio": ["Grimório das Marés Negras", "Compêndio do Kraken"],
	"velas": ["Velas Negras Reforçadas", "Velas de Seda Encantada"],
	"casco": ["Blindagem de Ferro Naval", "Placas de Bronze Antigo"],
	"mastro_proa": ["Mascarão de Dragão", "Mascarão de Sereia"],
	"armamento": ["Canhão Longo Naval", "Canhão Giratório", "Bombarda Pesada", "Culverina"],
}

@onready var _backdrop: Control = $Backdrop
@onready var _box: PanelContainer = $Box
@onready var _title: Label = $Box/Margin/VBox/Title
@onready var _list: VBoxContainer = $Box/Margin/VBox/List

var _category: String = ""


func _ready() -> void:
	visible = false
	_backdrop.gui_input.connect(_on_backdrop_input)


## `local_pos` já é no espaço do painel-pai (o slot resolve isso antes de
## chamar). A caixa nasce ali e cresce pra baixo/direita; quem usa isso em
## painéis estreitos pode querer checar se não estoura a borda -- não é um
## problema aqui porque todos os slots ficam numa faixa central confortável.
func open_at(local_pos: Vector2, category: String, label: String) -> void:
	_category = category
	_title.text = label
	for child in _list.get_children():
		child.queue_free()
	var items: Array = STUB_INVENTORY.get(category, [])
	for item_name in items:
		var row := Button.new()
		row.text = item_name
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(_on_item_pressed.bind(item_name))
		_list.add_child(row)
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Nada disponível no inventário."
		empty.add_theme_color_override("font_color", Color(0.65, 0.6, 0.55))
		empty.add_theme_font_size_override("font_size", 13)
		_list.add_child(empty)
	_box.position = local_pos
	visible = true


func close() -> void:
	visible = false


func _on_item_pressed(item_name: String) -> void:
	item_selected.emit(_category, item_name)
	close()


func _on_backdrop_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		close()
