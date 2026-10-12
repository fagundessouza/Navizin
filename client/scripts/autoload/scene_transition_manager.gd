extends CanvasLayer
## Autoload. Troca de cena com um fade de "nevoeiro da morte": a tela se cobre
## de bruma escura antes da troca, e desfaz depois -- esconde o corte seco do
## `change_scene_to_file` puro. Fica sempre por cima (layer alto) e sobrevive
## à troca de cena por ser autoload, então a camada de nevoeiro em si nunca
## descarrega.
##
## Uso: `SceneTransitionManager.change_scene("res://scenes/.../x.tscn")` no
## lugar de chamar `get_tree().change_scene_to_file()` direto.
##
## Deliberadamente SEM Tween/await encadeado por cima da troca de cena: um
## `Tween` criado antes do `change_scene_to_file` nunca termina depois dele
## (a troca de cena mexe no processamento da árvore de um jeito que trava o
## `await tween.finished` pendente, visto na prática rodando o jogo de
## verdade). Máquina de estados simples em `_process()`, movida a `delta`
## real, não tem esse problema.

const FADE_TIME: float = 0.42
const SWAP_WAIT_FRAMES: int = 2

enum State { IDLE, FADE_OUT, SWAPPING, FADE_IN }

var _rect: ColorRect
var _state: State = State.IDLE
var _t: float = 0.0
var _swap_frames_left: int = 0
var _pending_path: String = ""
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/fog_transition.gdshader")
	mat.set_shader_parameter("noise_tex", load("res://assets/sprites/vfx/noise/water_noise_real.png"))
	mat.set_shader_parameter("progress", 0.0)
	_rect.material = mat
	add_child(_rect)


## Troca para `path` com o fade de nevoeiro. Chamadas enquanto já há uma troca
## em curso são ignoradas (evita duas trocas de cena disputando a mesma vez).
func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_pending_path = path
	_state = State.FADE_OUT
	_t = 0.0


func _process(delta: float) -> void:
	match _state:
		State.FADE_OUT:
			_t += delta
			var p: float = clampf(_t / FADE_TIME, 0.0, 1.0)
			_set_progress(p)
			if p >= 1.0:
				var err := get_tree().change_scene_to_file(_pending_path)
				if err != OK:
					push_error("SceneTransitionManager: falha ao trocar para %s (código %d)" % [_pending_path, err])
					_set_progress(0.0)
					_state = State.IDLE
					_busy = false
					return
				_swap_frames_left = SWAP_WAIT_FRAMES
				_state = State.SWAPPING
		State.SWAPPING:
			# A troca de cena some com o `current_scene` por um ou dois quadros;
			# espera a nova cena existir antes de desfazer o nevoeiro, senão
			# clareia sobre nada.
			_swap_frames_left -= 1
			if _swap_frames_left <= 0:
				_t = 0.0
				_state = State.FADE_IN
		State.FADE_IN:
			_t += delta
			var p: float = 1.0 - clampf(_t / FADE_TIME, 0.0, 1.0)
			_set_progress(p)
			if _t >= FADE_TIME:
				_set_progress(0.0)
				_state = State.IDLE
				_busy = false


func _set_progress(v: float) -> void:
	_rect.material.set_shader_parameter("progress", v)
