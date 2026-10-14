class_name CrewManagementSubmodal
extends Control
## Overlay flutuante da Tripulação, aberto pelo 3º botão do rodapé da Ficha
## do Navio (`ship_status_modal.gd`). Mostra a capacidade máxima do Galeão
## atual -- Oficiais e Tropas -- lida de `ship.data` (`ShipData.max_officers`/
## `max_troops`), não um número fixo escrito aqui.
##
## Sem sistema de contratação ainda, então a parte "atual" de cada barra
## fica em 0 -- é só o teto que já é real.
##
## ARTE PENDENTE: `Meshy_AI_CrewManagementSubmodal.png` (pedida junto com
## este painel) ainda não chegou em `~/Downloads/Tortuga/` até a escrita
## deste script -- usando a mesma moldura gótica dos outros painéis
## (`modal_frame_iron.png` + `gothic_panel.gdshader`) como visual provisório.
## Trocar o `Frame`/fundo aqui assim que a arte certa aparecer, sem precisar
## mexer na lógica de leitura de capacidade.

signal opened
signal closed

@onready var _list: VBoxContainer = $Margin/VBox/List


func _ready() -> void:
	visible = false
	$Margin/VBox/Header/CloseButton.pressed.connect(close)


func open() -> void:
	_refresh()
	visible = true
	opened.emit()


func close() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var ship: Node2D = get_tree().get_first_node_in_group("player_ship") as Node2D
	var max_officers: int = 4
	var max_troops: int = 40
	if ship != null and ship.data != null:
		max_officers = ship.data.max_officers
		max_troops = ship.data.max_troops
	_add_row("Oficiais", 0, max_officers, Color(0.82, 0.68, 0.32, 1.0))
	_add_row("Tropas", 0, max_troops, Color(0.56, 0.64, 0.74, 1.0))


func _add_row(label: String, current: int, max_value: int, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(80, 0)
	name_label.add_theme_color_override("font_color", Color(0.93, 0.9, 0.84))
	row.add_child(name_label)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = max_value if max_value > 0 else 1
	bar.value = current
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.add_theme_stylebox_override("fill", _bar_style(color))
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.12, 0.1, 0.08, 0.9)))
	row.add_child(bar)

	var value_label := Label.new()
	value_label.text = "%d / %d" % [current, max_value]
	value_label.custom_minimum_size = Vector2(70, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", Color(0.78, 0.7, 0.5))
	value_label.add_theme_font_size_override("font_size", 13)
	row.add_child(value_label)

	_list.add_child(row)


func _bar_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb
