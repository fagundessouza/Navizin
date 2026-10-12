class_name LifeSkillsPanel
extends PanelContainer
## Painel de Life Skills / Proficiências do capitão, no estilo BDO/Albion:
## uma barra de progresso por ofício. Sem XP de verdade rastreado ainda --
## `SKILLS` só preenche a interface com valores de demonstração; quando
## existir progresso real, troca-se a fonte dos valores aqui dentro, sem
## mexer em quem abre o painel.

signal opened
signal closed

const SKILLS: Array[Dictionary] = [
	{"name": "Pesca", "value": 0.65, "level": "Aprendiz 3"},
	{"name": "Coleta", "value": 0.40, "level": "Aprendiz 1"},
	{"name": "Comércio", "value": 0.80, "level": "Mestre 1"},
	{"name": "Navegação", "value": 0.55, "level": "Aprendiz 2"},
	{"name": "Culinária", "value": 0.20, "level": "Novato 2"},
	{"name": "Alquimia", "value": 0.10, "level": "Novato 1"},
]

@onready var _list: VBoxContainer = $Margin/VBox/SkillList


func _ready() -> void:
	visible = false
	_style_close($Margin/VBox/Header/CloseButton)
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	_build_skills()


func open() -> void:
	visible = true
	opened.emit()


func close() -> void:
	visible = false
	closed.emit()


func _build_skills() -> void:
	for skill in SKILLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var name_label := Label.new()
		name_label.text = skill["name"]
		name_label.custom_minimum_size = Vector2(110, 0)
		name_label.add_theme_color_override("font_color", Color(0.93, 0.9, 0.84))
		row.add_child(name_label)

		var bar := ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.max_value = 1.0
		bar.value = skill["value"]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 18)
		bar.add_theme_stylebox_override("fill", _bar_style(Color(0.82, 0.68, 0.32, 1.0)))
		bar.add_theme_stylebox_override("background", _bar_style(Color(0.12, 0.1, 0.08, 0.9)))
		row.add_child(bar)

		var level_label := Label.new()
		level_label.text = skill["level"]
		level_label.custom_minimum_size = Vector2(90, 0)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		level_label.add_theme_color_override("font_color", Color(0.78, 0.7, 0.5))
		level_label.add_theme_font_size_override("font_size", 13)
		row.add_child(level_label)

		_list.add_child(row)


func _bar_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


func _style_close(button: Button) -> void:
	button.add_theme_color_override("font_color", Color(0.93, 0.9, 0.84, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.65, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 1.0))
	button.add_theme_constant_override("outline_size", 3)
