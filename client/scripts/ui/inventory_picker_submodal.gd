class_name InventoryPickerSubmodal
extends Control
## Submodal suspenso que abre do lado de um slot '+' (equipamento do capitão
## ou do navio) listando só os itens compatíveis daquela categoria.
##
## Dois modos, decididos pela própria categoria:
## - Slots do Galeão (`PlayerInventory.SHIP_SLOTS` + "armamento"): lista
##   itens de VERDADE, fabricados e ainda não equipados em lugar nenhum
##   (`PlayerInventory.get_unequipped_for_category()`). Selecionar emite
##   `instance_selected` e EQUIPA de fato.
## - Acessórios do capitão (brincos/colar/anel/cinto/trajes/grimorio): não
##   têm sistema de fabricação ainda, continuam no `STUB_INVENTORY` cosmético
##   de antes -- selecionar só emite `item_selected` com o nome, sem estado
##   real por trás.
##
## Um `Backdrop` cobrindo a tela inteira fecha o submodal ao clicar fora,
## atrás da caixa -- padrão comum de popup/context-menu.

signal item_selected(category: String, item_name: String)
signal instance_selected(category: String, instance_id: String)

const STUB_INVENTORY: Dictionary = {
	"brincos": ["Brincos de Pérola Negra", "Brincos de Caveira de Prata"],
	"colar": ["Colar do Kraken", "Amuleto de Osso"],
	"anel": ["Anel do Capitão Fantasma", "Anel de Sinete Dourado"],
	"cinto": ["Cinturão de Couro Reforçado", "Faixa Escarlate"],
	"trajes": ["Sobretudo do Corsário", "Casaca da Guarda Real"],
	"grimorio": ["Grimório das Marés Negras", "Compêndio do Kraken"],
}

## Categorias que são slots de equipamento de verdade do Galeão -- tudo que
## não está aqui cai no `STUB_INVENTORY` cosmético.
const EQUIPMENT_CATEGORIES: Array[String] = ["vela", "casco", "leme", "proa", "relíquia_ebenruth", "armamento"]

@onready var _backdrop: Control = $Backdrop
@onready var _box: PanelContainer = $Box
@onready var _title: Label = $Box/Margin/VBox/Title
@onready var _list: VBoxContainer = $Box/Margin/VBox/List

var _category: String = ""
var _is_equipment: bool = false


## `local_pos` já é no espaço do painel-pai (o slot resolve isso antes de
## chamar). A caixa nasce ali e cresce pra baixo/direita; quem usa isso em
## painéis estreitos pode querer checar se não estoura a borda -- não é um
## problema aqui porque todos os slots ficam numa faixa central confortável.
func _ready() -> void:
	visible = false
	_backdrop.gui_input.connect(_on_backdrop_input)


func open_at(local_pos: Vector2, category: String, label: String) -> void:
	_category = category
	_is_equipment = EQUIPMENT_CATEGORIES.has(category)
	_title.text = label
	for child in _list.get_children():
		child.queue_free()

	var has_any: bool = false
	if _is_equipment:
		var entries: Array[Dictionary] = PlayerInventory.get_unequipped_for_category(category)
		for entry in entries:
			has_any = true
			var item: Dictionary = ItemDatabase.get_item(entry["item_id"])
			var row := Button.new()
			row.text = item.get("name", entry["item_id"])
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.pressed.connect(_on_instance_pressed.bind(entry["instance_id"]))
			_list.add_child(row)
	else:
		var items: Array = STUB_INVENTORY.get(category, [])
		for item_name in items:
			has_any = true
			var row := Button.new()
			row.text = item_name
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.pressed.connect(_on_item_pressed.bind(item_name))
			_list.add_child(row)

	if not has_any:
		var empty := Label.new()
		empty.text = "Nada fabricado ainda." if _is_equipment else "Nada disponível no inventário."
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


func _on_instance_pressed(instance_id: String) -> void:
	instance_selected.emit(_category, instance_id)
	close()


func _on_backdrop_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		close()
