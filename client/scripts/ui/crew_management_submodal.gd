class_name CrewManagementSubmodal
extends Control
## Overlay flutuante da Tripulação, aberto pelo 3º botão do rodapé da Ficha
## do Navio (`ship_status_modal.gd`). Duas seções:
## - OFICIAIS DE BORDO: 5 vagas FIXAS por cargo (Timoneiro/Mestre
##   Canhoneiro/Carpinteiro/Navegador/Cozinheiro, `OfficerRoster`), cada uma
##   contratável por Ouro, concedendo um bônus direto ao navio quando
##   preenchida.
## - MARINHEIROS/OPERÁRIOS (pedido explícito desta rodada, substitui a
##   antiga barra de texto seca "Tropas: 0/40"): `CrewCardModal` embutido
##   (`show_own_chrome = false`, sem moldura própria pra não aninhar com a
##   deste painel) -- grade de cards visuais dos marinheiros contratados na
##   Taverna (`TavernHireSystem`), com a mesma roleta de contratação
##   disponível ali dentro.
##
## ARTE PENDENTE: `Meshy_AI_CrewManagementSubmodal.png` (pedida junto com
## este painel, rodada antiga) ainda não chegou em `~/Downloads/Tortuga/`
## até a escrita deste script -- usando a mesma moldura gótica dos outros
## painéis (`modal_frame_iron.png` + `gothic_panel.gdshader`) como visual
## provisório. Trocar o `Frame`/fundo aqui assim que a arte certa aparecer,
## sem precisar mexer na lógica.

signal opened
signal closed

const NORMAL_FONT_COLOR: Color = Color(0.93, 0.9, 0.84, 1.0)
const OK_COLOR: Color = Color(0.6, 0.82, 0.5, 1.0)
const MISSING_COLOR: Color = Color(0.85, 0.4, 0.35, 1.0)
const HIRED_COLOR: Color = Color(0.82, 0.68, 0.32, 1.0)
const EMPTY_COLOR: Color = Color(0.35, 0.33, 0.3, 1.0)

@onready var _officers_list: VBoxContainer = $Margin/VBox/OfficersList


func _ready() -> void:
	visible = false
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	OfficerRoster.changed.connect(_on_officer_changed)


func open() -> void:
	_refresh()
	visible = true
	UIManager.animate_modal_open(self)
	opened.emit()


func close() -> void:
	visible = false
	closed.emit()


func _on_officer_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_refresh_officers()


## Uma linha por cargo: nome + cargo contratado/vago + botão
## contratar/dispensar. `OfficerRoster.ROLES` é a ordem fixa dos 5 cargos
## pedidos (Timoneiro/Canhoneiro/Carpinteiro/Navegador/Cozinheiro).
func _refresh_officers() -> void:
	for child in _officers_list.get_children():
		child.queue_free()
	for role in OfficerRoster.ROLES:
		_officers_list.add_child(_build_officer_row(role))


func _build_officer_row(role: String) -> Control:
	var hired: bool = OfficerRoster.is_hired(role)

	var row := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.07, 0.06, 0.55)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.corner_radius_bottom_right = 4
	row_style.content_margin_left = 8
	row_style.content_margin_right = 8
	row_style.content_margin_top = 4
	row_style.content_margin_bottom = 4
	if hired:
		row_style.border_width_left = 1
		row_style.border_color = HIRED_COLOR
	row.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var name_label := Label.new()
	name_label.text = OfficerRoster.ROLE_NAMES[role]
	name_label.custom_minimum_size = Vector2(130, 0)
	name_label.add_theme_color_override("font_color", HIRED_COLOR if hired else EMPTY_COLOR)
	hbox.add_child(name_label)

	var status_label := Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 11)
	if hired:
		status_label.text = _bonus_summary(role)
		status_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.7))
	else:
		status_label.text = OfficerRoster.ROLE_DESCRIPTIONS[role]
		status_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(status_label)

	var action_button := Button.new()
	if hired:
		action_button.text = "Dispensar"
		action_button.pressed.connect(func(): OfficerRoster.dismiss(role))
	else:
		action_button.text = "Contratar (%dx %s)" % [OfficerRoster.HIRE_COST_QTY, OfficerRoster.HIRE_COST_MATERIAL]
		action_button.disabled = not OfficerRoster.can_hire(role)
		action_button.pressed.connect(func(): OfficerRoster.hire(role))
	action_button.custom_minimum_size = Vector2(150, 0)
	_style_button(action_button)
	hbox.add_child(action_button)

	return row


func _bonus_summary(role: String) -> String:
	var parts: PackedStringArray = []
	for key in OfficerRoster.ROLE_BONUS[role]:
		var value: float = OfficerRoster.ROLE_BONUS[role][key]
		var label: String = ItemTooltipZoom.STAT_LABELS.get(key, key)
		if ItemTooltipZoom.PERCENT_STATS.has(key):
			parts.append("%s +%.0f%%" % [label, value * 100.0])
		else:
			parts.append("%s +%.0f" % [label, value])
	return ", ".join(parts)




func _style_button(button: Button) -> void:
	button.add_theme_color_override("font_color", NORMAL_FONT_COLOR)
	button.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 1.0))
	button.add_theme_constant_override("outline_size", 3)
