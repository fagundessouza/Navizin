class_name WaterSplashFX
extends Node2D
## Respingo de água no impacto de um projétil. Gotas finas sobem em arco e caem,
## e uma névoa rala se dissipa. Se remove sozinho ao fim (~1 s).
##
## Materiais e textura são compartilhados por todas as instâncias, para que vários
## disparos simultâneos não criem recursos novos a cada tiro.

const DURATION: float = 1.0

static var _drop_material: ParticleProcessMaterial
static var _mist_material: ParticleProcessMaterial
static var _drop_texture: Texture2D
static var _mist_texture: Texture2D


func _ready() -> void:
	_ensure_shared()

	var drops := GPUParticles2D.new()
	drops.process_material = _drop_material
	drops.texture = _drop_texture
	drops.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	drops.one_shot = true
	drops.explosiveness = 1.0
	drops.amount = 14
	drops.lifetime = 0.7
	drops.local_coords = false
	add_child(drops)

	var mist := GPUParticles2D.new()
	mist.process_material = _mist_material
	mist.texture = _mist_texture
	mist.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mist.one_shot = true
	mist.explosiveness = 0.8
	mist.amount = 6
	mist.lifetime = 0.9
	mist.local_coords = false
	add_child(mist)

	drops.emitting = true
	mist.emitting = true
	get_tree().create_timer(DURATION).timeout.connect(queue_free)


static func _ensure_shared() -> void:
	if _drop_material != null:
		return

	_drop_texture = _make_radial(4)
	_mist_texture = _make_radial(32)

	# Gotas: sobem em arco (gravidade), de branco para turquesa, e somem.
	var drop_colors := Gradient.new()
	drop_colors.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	drop_colors.set_color(1, Color(0.4, 0.9, 0.9, 0.0))
	var drop_ramp := GradientTexture1D.new()
	drop_ramp.gradient = drop_colors
	_drop_material = ParticleProcessMaterial.new()
	_drop_material.direction = Vector3(0.0, -1.0, 0.0)
	_drop_material.spread = 30.0
	_drop_material.gravity = Vector3(0.0, 300.0, 0.0)
	_drop_material.initial_velocity_min = 80.0
	_drop_material.initial_velocity_max = 140.0
	_drop_material.scale_min = 1.0
	_drop_material.scale_max = 2.5
	_drop_material.color_ramp = drop_ramp

	# Névoa: rala, cinza-esbranquiçada, cresce levemente e some.
	var mist_fade := Gradient.new()
	mist_fade.set_color(0, Color(0.9, 0.95, 1.0, 0.4))
	mist_fade.set_color(1, Color(0.9, 0.95, 1.0, 0.0))
	var mist_ramp := GradientTexture1D.new()
	mist_ramp.gradient = mist_fade
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.6))
	grow.add_point(Vector2(1.0, 1.4))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	_mist_material = ParticleProcessMaterial.new()
	_mist_material.direction = Vector3(0.0, -1.0, 0.0)
	_mist_material.spread = 45.0
	_mist_material.gravity = Vector3.ZERO
	_mist_material.initial_velocity_min = 6.0
	_mist_material.initial_velocity_max = 18.0
	_mist_material.damping_min = 10.0
	_mist_material.damping_max = 14.0
	_mist_material.scale_min = 1.0
	_mist_material.scale_max = 2.0
	_mist_material.scale_curve = grow_tex
	_mist_material.color_ramp = mist_ramp


## Círculo suave de `size` pixels, para as partículas.
static func _make_radial(size: int) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = size
	texture.height = size
	return texture
