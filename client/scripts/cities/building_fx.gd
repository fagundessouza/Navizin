class_name BuildingFX
extends Area2D
## Efeitos reutilizáveis de um prédio de distrito: luz piscando (tocha,
## lanterna, forja, poção), partículas temáticas (fumaça, fagulhas, névoa
## mágica) e reação da escala ao passar o mouse. Um `BuildingFX` por prédio,
## filho do mesmo nó que tem o Sprite2D do prédio -- aponta pra ele via
## `sprite_path`. Precisa de um `CollisionPolygon2D`/`CollisionShape2D` filho
## pra detectar o hover (não criado em código: a silhueta muda por prédio).

enum ParticleKind { NONE, SMOKE, SPARKS, MIST }

@export var sprite_path: NodePath
@export var light_offset: Vector2 = Vector2.ZERO
@export var light_color: Color = Color(1.0, 0.7, 0.35, 1.0)
@export var light_energy: float = 1.0
@export var light_texture_scale: float = 3.0
@export var particle_kind: ParticleKind = ParticleKind.NONE
@export var particle_offset: Vector2 = Vector2.ZERO
@export var hover_scale: float = 1.02

const FLICKER_PERIOD: float = 0.35
const FLICKER_FLOOR: float = 0.72

var _sprite: Node2D
var _base_scale: Vector2
var _light: PointLight2D
var _hover_tween: Tween


func _ready() -> void:
	_sprite = get_node(sprite_path)
	_base_scale = _sprite.scale
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_setup_light()
	_setup_particles()


## Textura radial branca->transparente, a mesma receita usada na luz do
## capitão em `ocean_map.gd`.
func _radial_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _setup_light() -> void:
	_light = PointLight2D.new()
	_light.texture = _radial_texture()
	_light.texture_scale = light_texture_scale
	_light.color = light_color
	_light.energy = light_energy
	_light.position = light_offset
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(_light)
	var tw := create_tween().set_loops()
	tw.tween_property(_light, "energy", light_energy, FLICKER_PERIOD).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_light, "energy", light_energy * FLICKER_FLOOR, FLICKER_PERIOD).set_trans(Tween.TRANS_SINE)


func _setup_particles() -> void:
	if particle_kind == ParticleKind.NONE:
		return
	var p := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.gravity = Vector3.ZERO
	match particle_kind:
		ParticleKind.SMOKE:
			mat.spread = 12.0
			mat.gravity = Vector3(0.0, -18.0, 0.0)
			mat.initial_velocity_min = 8.0
			mat.initial_velocity_max = 16.0
			mat.scale_min = 0.5
			mat.scale_max = 0.9
			mat.color = Color(0.6, 0.6, 0.62, 0.35)
			p.amount = 10
			p.lifetime = 3.0
			p.texture = load("res://assets/sprites/vfx/battle/smoke_puff_soft.png")
		ParticleKind.SPARKS:
			mat.spread = 45.0
			mat.gravity = Vector3(0.0, 70.0, 0.0)
			mat.initial_velocity_min = 20.0
			mat.initial_velocity_max = 50.0
			mat.scale_min = 0.08
			mat.scale_max = 0.18
			mat.color = Color(1.0, 0.6, 0.2, 0.9)
			p.amount = 14
			p.lifetime = 0.7
			p.texture = load("res://assets/sprites/vfx/foam_dot.png")
		ParticleKind.MIST:
			mat.spread = 30.0
			mat.initial_velocity_min = 3.0
			mat.initial_velocity_max = 8.0
			mat.scale_min = 0.9
			mat.scale_max = 1.6
			mat.color = Color(0.55, 0.35, 0.85, 0.28)
			p.amount = 8
			p.lifetime = 2.5
			p.texture = load("res://assets/sprites/vfx/foam_dot.png")
	p.process_material = mat
	p.position = particle_offset
	p.local_coords = false
	p.emitting = true
	add_child(p)


func _on_mouse_entered() -> void:
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(_sprite, "scale", _base_scale * hover_scale, 0.12)


func _on_mouse_exited() -> void:
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(_sprite, "scale", _base_scale, 0.12)
