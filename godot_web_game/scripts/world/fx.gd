## Small one-shot particle effects (sparks, puffs, mist) that clean themselves up.
class_name Fx
extends RefCounted


## A burst of `count` blobs from `at` (global), thrown along `direction` and fading out.
static func burst(parent: Node, at: Vector3, direction: Vector3, color: Color, count := 24, speed := 3.0,
		size := 0.05, gravity := -6.0, lifetime := 0.8) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = count
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector3.FORWARD
	p.spread = 40.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.mesh = blob(size)
	p.color_ramp = fade(color)
	parent.add_child(p)
	p.global_position = at
	if direction.length() > 0.01:
		p.look_at(at + direction, Vector3.UP if absf(direction.normalized().y) < 0.95 else Vector3.RIGHT)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## A soft puff of dust or steam that drifts up.
static func puff(parent: Node, at: Vector3, direction: Vector3, color := Color(0.85, 0.82, 0.78)) -> void:
	burst(parent, at, direction, color, 14, 0.9, 0.12, 0.6, 1.1)


static func blob(size: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	return m


static func fade(color: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color, 0.0))
	return g
