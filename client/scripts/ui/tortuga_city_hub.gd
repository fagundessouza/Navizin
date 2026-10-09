class_name TortugaCityHub
extends Control
## Tela da cidade de Tortuga: a ilustração inteira como fundo, com 8 pontos de
## interação invisíveis (realçados só no hover) sobre os prédios certos.

signal close_requested

const DESCRIPTIONS: Dictionary = {
	"Shipyard": "O esqueleto de um navio em construção. Compra e reparo de embarcações. Em construção.",
	"Forge": "O calor da forja nunca esfria. Armas e peças de canhão. Em construção.",
	"Tavern": "Rum, rumores e tripulação para contratar sob a caveira pintada na parede. Em construção.",
	"Apothecary": "Um brilho verde-pântano escapa pelas janelas. Poções e curas. Em construção.",
	"BountyBoard": "O obelisco da praça central, coberto de cartazes. Contratos e recompensas. Em construção.",
	"BlackMarket": "Tendas que não fazem perguntas. Comércio de itens raros. Em construção.",
	"GuildHall": "Bandeiras azuis tremulam sobre a mansão gótica. Sua guilda e sua frota. Em construção.",
	"Academy": "O farol no topo do penhasco guia os que estudam o mar. Em construção.",
}

const TITLES: Dictionary = {
	"Shipyard": "Estaleiro", "Forge": "Forja", "Tavern": "Taverna",
	"Apothecary": "Boticário", "BountyBoard": "Quadro de Recompensas",
	"BlackMarket": "Mercado Negro", "GuildHall": "Salão da Guilda", "Academy": "Academia",
}

@onready var _info: NinePatchRect = $InfoPanel


func _ready() -> void:
	for button in $Hotspots.get_children():
		button.pressed.connect(_on_hotspot_pressed.bind(button.name))


func _on_hotspot_pressed(location: String) -> void:
	_info.get_node("Title").text = TITLES.get(location, location)
	_info.get_node("Body").text = DESCRIPTIONS.get(location, "Em construção.")
	_info.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE and _info.visible:
		_info.visible = false
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_E and not _info.visible:
		close_requested.emit()
		get_viewport().set_input_as_handled()
