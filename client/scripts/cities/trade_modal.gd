class_name TradeModal
extends PanelContainer
## Modal de comércio reutilizável: duas abas configuráveis por distrito (ex.
## no Ferreiro, "Canhões" / "Blindagem do Casco"; no Boticário, "Poções de
## Cura" / "Elixires Raros"), cada uma com um espaço de itens (vazio por ora,
## "Em breve") e botões Comprar/Vender já estilizados.
##
## Só a estrutura -- sem inventário, preço ou lógica de troca ainda. Pronta
## pra receber isso depois sem precisar redesenhar a tela.

@export var tab_1_name: String = "Categoria 1"
@export var tab_2_name: String = "Categoria 2"
@export var shop_title: String = "Loja"

@onready var _title: Label = $Margin/VBox/Header/Title
@onready var _tab_1_button: Button = $Margin/VBox/Tabs/Tab1
@onready var _tab_2_button: Button = $Margin/VBox/Tabs/Tab2
@onready var _page_1: Control = $Margin/VBox/Pages/Page1
@onready var _page_2: Control = $Margin/VBox/Pages/Page2


func _ready() -> void:
	visible = false
	_title.text = shop_title
	_tab_1_button.text = tab_1_name
	_tab_2_button.text = tab_2_name
	_tab_1_button.pressed.connect(_select_tab.bind(0))
	_tab_2_button.pressed.connect(_select_tab.bind(1))
	$Margin/VBox/Header/CloseButton.pressed.connect(close)
	_select_tab(0)


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func _select_tab(index: int) -> void:
	_page_1.visible = index == 0
	_page_2.visible = index == 1
	_tab_1_button.disabled = index == 0
	_tab_2_button.disabled = index == 1
