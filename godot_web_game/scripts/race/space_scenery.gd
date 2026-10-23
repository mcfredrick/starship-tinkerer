## Everything around a race track that isn't the track: Bramble and its rings under the course,
## tumbling asteroids with glowing crystals, lantern buoys along the edges, hoops to fly through,
## glass terrarium bubbles, drifting moon-jellies, a pod of star whales and the odd comet.
## Placement is seeded, so a track always looks the same. A track's `theme` (data/tracks.json)
## recolors the sky, fog and lanterns, moves the planet and sets how much of each thing there is.
class_name SpaceScenery
extends Node3D

const ROCK_SHADER := preload("res://shaders/asteroid.gdshader")
const RING_SHADER := preload("res://shaders/rings.gdshader")
const GLASS_SHADER := preload("res://shaders/glass.gdshader")
const SKY_SHADER := preload("res://shaders/nebula_sky.gdshader")
const JELLY_COLORS := [Color("ff8ad8"), Color("7ff0ff"), Color("c39bff"), Color("ffd27a")]

var track: Track
var _theme := {}
var _rng := RandomNumberGenerator.new()
var _jellies: Array = []
var _whales: Array = []
var _comet_in := 3.0


func build(t: Track, theme := {}) -> void:
	track = t
	_theme = theme
	_rng.seed = 2024
	add_child(_environment())
	_bramble()
	_asteroids()
	_buoys()
	_terrariums()
	_jelly_school()
	_whale_pod()


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for j in _jellies:
		var node: Node3D = j.node
		var beat := sin(now * j.speed + j.phase)
		node.position = j.home + Vector3(sin(now * 0.2 + j.phase) * 6.0, beat * 1.5, cos(now * 0.15 + j.phase) * 6.0)
		node.scale = Vector3(1.0 + beat * 0.08, 1.0 - beat * 0.1, 1.0 + beat * 0.08) * j.size
		for k in j.tentacles.size():
			j.tentacles[k].rotation.x = sin(now * j.speed + j.phase + k) * 0.35
	for w in _whales:
		var a: float = w.angle + now * w.speed
		var node: Node3D = w.node
		var at: Vector3 = w.center + Vector3(cos(a) * w.radius, sin(a * 2.0) * 8.0, sin(a) * w.radius)
		var ahead: Vector3 = w.center + Vector3(cos(a + 0.01) * w.radius, sin((a + 0.01) * 2.0) * 8.0,
			sin(a + 0.01) * w.radius)
		node.look_at_from_position(at, ahead, Vector3.UP)
		w.tail.rotation.x = sin(now * 1.2 + w.angle) * 0.35
	_comet_in -= delta
	if _comet_in <= 0:
		_comet_in = _rng.randf_range(5.0, 11.0)
		_comet()


## A theme value, or `fallback` when the track doesn't set it.
func _t(key: String, fallback: Variant) -> Variant:
	return _theme.get(key, fallback)


## Just the nebula sky, light and fog for `theme`, for scenes that aren't race tracks.
static func environment_for(theme: Dictionary) -> WorldEnvironment:
	var s := SpaceScenery.new()
	s._theme = theme
	var env := s._environment()
	s.free()
	return env


func _environment() -> WorldEnvironment:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	if _theme.has("sky"):
		for i in 3:
			sky_mat.set_shader_parameter(["cloud_a", "cloud_b", "cloud_c"][i], Color(_theme.sky[i]))
	if _theme.has("deep"):
		sky_mat.set_shader_parameter("deep", Color(_theme.deep))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(_t("ambient", "4a3d6a"))
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(_t("fog", "3a2a5a"))
	env.fog_density = float(_t("fog_density", 0.0012))
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	return we


## Bramble hangs off to one side and below, with its rings sweeping under the whole course.
func _bramble() -> void:
	var p: Array = _t("planet", [1100, -420, 250, 520])
	var planet := Stage.bramble(Vector3(p[0], p[1], p[2]), float(p[3]))
	add_child(planet)
	var plane := PlaneMesh.new()
	plane.size = Vector2(3200, 3200)
	var mat := ShaderMaterial.new()
	mat.shader = RING_SHADER
	var r: Array = _t("rings_at", [1100, -120, 250])
	var rings := Stage.mesh(plane, mat, Vector3(r[0], r[1], r[2]))
	rings.rotation_degrees = Vector3(4, 0, -6)
	add_child(rings)


func _rock_mesh(radius: float) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	sphere.radial_segments = 10
	sphere.rings = 6
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 1.6 / radius
	for i in verts.size():
		var v := verts[i]
		verts[i] = v * (0.75 + 0.45 * (noise.get_noise_3dv(v) + 0.5))
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_normals()
	return st.commit()


## A spot beside the track, `near`..`far` meters off either edge, lifted `rise` meters.
func _beside(near: float, far: float, rise: Vector2) -> Vector3:
	var s := _rng.randf() * track.length
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var d := side * (track.half_width + _rng.randf_range(near, far))
	return track.position(s, d) + Vector3.UP * _rng.randf_range(rise.x, rise.y)


func _asteroids() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _rock_mesh(1.0)
	mm.instance_count = int(_t("asteroids", 140))
	for i in mm.instance_count:
		var at := _beside(25, 320, Vector2(-60, 90))
		var size := _rng.randf_range(1.5, 9.0) if i % 9 else _rng.randf_range(14.0, 26.0)
		var crystal := 1.0 if i % 7 == 0 and size < 5.0 else 0.0
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1.0, _rng.randf_range(0.6, 1.0),
			_rng.randf_range(0.7, 1.3)) * size), at))
		mm.set_instance_custom_data(i, Color(_rng.randf(), _rng.randf(), _rng.randf(), crystal))
	var mat := ShaderMaterial.new()
	mat.shader = ROCK_SHADER
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)


## Lanterns bobbing along both edges, amber on the left and teal on the right.
func _buoys() -> void:
	var lamp := SphereMesh.new()
	lamp.radius = 0.55
	lamp.height = 1.1
	lamp.radial_segments = 8
	lamp.rings = 4
	for side in [1.0, -1.0]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = lamp
		var count := int(track.length / 24.0)
		mm.instance_count = count
		for i in count:
			var s := i * 24.0
			mm.set_instance_transform(i, Transform3D(Basis(), track.position(s, side * (track.half_width + 3.0))
				+ Vector3.UP * (2.2 + sin(s * 0.3) * 0.6)))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var lanterns: Array = _t("lanterns", ["ffc46b", "7ff0e0"])
		mi.material_override = Stage.glow(Color(lanterns[0] if side > 0 else lanterns[1]))
		add_child(mi)


## Hoops to fly through, glowing and slowly cycling color.
func hoop(s: float) -> Node3D:
	var ring := TorusMesh.new()
	ring.inner_radius = track.half_width + 3.0
	ring.outer_radius = track.half_width + 4.2
	ring.rings = 48
	ring.ring_segments = 8
	var mat := Stage.glow(Color.from_hsv(fmod(s / 900.0, 1.0), 0.55, 1.0))
	mat.set_shader_parameter("pulse", 0.25)
	var mi := Stage.mesh(ring, mat)
	mi.transform = Transform3D(Basis.looking_at(track.forward(s)) * Basis(Vector3.RIGHT, PI / 2),
		track.position(s, 0) + Vector3.UP * 3.0)
	add_child(mi)
	return mi


## Glass bubbles with a little green island, a tree and a cottage inside: the drum gardens,
## floating free.
func _terrariums() -> void:
	for i in int(_t("terrariums", 11)):
		var r := _rng.randf_range(9.0, 18.0)
		var at := _beside(r + 15.0, 160.0, Vector2(-20, 45))
		var bubble := Node3D.new()
		bubble.position = at
		add_child(bubble)
		var island := SphereMesh.new()
		island.radius = r * 0.62
		island.height = r * 0.5
		bubble.add_child(Stage.mesh(island, Stage.toon(Color("8fae7e"), 0.0, 0.0), Vector3(0, -r * 0.35, 0)))
		var soil := SphereMesh.new()
		soil.radius = r * 0.6
		soil.height = r * 0.7
		bubble.add_child(Stage.mesh(soil, Stage.toon(Color("6c4f45"), 0.0, 0.0), Vector3(0, -r * 0.48, 0)))
		var trunk := CylinderMesh.new()
		trunk.top_radius = r * 0.04
		trunk.bottom_radius = r * 0.06
		trunk.height = r * 0.45
		bubble.add_child(Stage.mesh(trunk, Stage.toon(Color("7a5040"), 0.0, 0.04), Vector3(r * 0.15, -r * 0.05, 0)))
		var canopy := SphereMesh.new()
		canopy.radius = r * 0.2
		canopy.height = r * 0.36
		bubble.add_child(Stage.mesh(canopy, Stage.toon([Color("e48aa0"), Color("6f9e6e"), Color("e8a33d")][i % 3], 0.0, 0.05),
			Vector3(r * 0.15, r * 0.2, 0)))
		var hut := Stage.mesh(Stage._box(Vector3(r * 0.18, r * 0.14, r * 0.16)), Stage.toon(UI.CREAM, 0.0, 0.04),
			Vector3(-r * 0.2, -r * 0.15, r * 0.1))
		bubble.add_child(hut)
		var shell := SphereMesh.new()
		shell.radius = r
		shell.height = r * 2
		var glass := ShaderMaterial.new()
		glass.shader = GLASS_SHADER
		glass.set_shader_parameter("tint", Color("bfe6ec"))
		glass.set_shader_parameter("body", 0.06)
		bubble.add_child(Stage.mesh(shell, glass))


func _jelly_school() -> void:
	for i in int(_t("jellies", 16)):
		var color: Color = JELLY_COLORS[i % JELLY_COLORS.size()]
		var node := Node3D.new()
		var home := _beside(8, 90, Vector2(6, 40))
		node.position = home
		add_child(node)
		var dome := SphereMesh.new()
		dome.radius = 2.0
		dome.height = 2.0
		dome.is_hemisphere = true
		var glass := ShaderMaterial.new()
		glass.shader = GLASS_SHADER
		glass.set_shader_parameter("tint", color)
		glass.set_shader_parameter("body", 0.25)
		glass.set_shader_parameter("pulse", 0.3)
		node.add_child(Stage.mesh(dome, glass))
		var core := SphereMesh.new()
		core.radius = 0.6
		core.height = 1.0
		node.add_child(Stage.mesh(core, Stage.glow(color.lightened(0.3)), Vector3(0, 0.4, 0)))
		var tentacles: Array = []
		var strand := CylinderMesh.new()
		strand.top_radius = 0.08
		strand.bottom_radius = 0.02
		strand.height = 4.5
		strand.radial_segments = 4
		strand.rings = 1
		for k in 5:
			var a := TAU * k / 5
			var pivot := Node3D.new()
			pivot.position = Vector3(cos(a), 0, sin(a)) * 1.3
			pivot.add_child(Stage.mesh(strand, Stage.glow(color), Vector3(0, -2.25, 0)))
			node.add_child(pivot)
			tentacles.append(pivot)
		_jellies.append({"node": node, "home": home, "tentacles": tentacles, "phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(1.2, 2.2), "size": _rng.randf_range(0.8, 1.8)})


## Star whales: great blue swimmers with glowing spots, circling far out from the course.
func _whale_pod() -> void:
	var center := Vector3(120, 0, 230)
	for i in int(_t("whales", 3)):
		var whale := whale(_rng.randf_range(7.0, 11.0), Color("4f6fb5").lerp(Color("6b5a9e"), i * 0.4))
		add_child(whale)
		_whales.append({"node": whale, "tail": whale.get_node("tail"), "center": center + Vector3(0, _rng.randf_range(60, 140), 0),
			"radius": _rng.randf_range(520, 760), "angle": TAU * i / 3, "speed": _rng.randf_range(0.012, 0.02)})


## A star whale `size` meters around, nose toward -Z, with a "tail" child to swish.
static func whale(size: float, color: Color) -> Node3D:
	var whale := Node3D.new()
	var skin := Stage.toon(color, 0.3, 0.0)
	var belly := Stage.toon(Color("d8e4f0"), 0.2, 0.0)
	var body := SphereMesh.new()
	body.radius = size
	body.height = size * 1.5
	var b := Stage.mesh(body, skin)
	b.scale = Vector3(1.0, 1.0, 2.6)
	whale.add_child(b)
	var under := Stage.mesh(body, belly, Vector3(0, -size * 0.25, -size * 0.3))
	under.scale = Vector3(0.8, 0.55, 2.1)
	whale.add_child(under)
	var tail := Node3D.new()
	tail.name = "tail"
	tail.position = Vector3(0, 0, size * 2.4)
	whale.add_child(tail)
	var fluke := SphereMesh.new()
	fluke.radius = size * 0.6
	fluke.height = size * 0.25
	for side in [-1, 1]:
		var f := Stage.mesh(fluke, skin, Vector3(side * size * 0.55, 0, size * 0.5))
		f.rotation.y = side * 0.5
		f.scale = Vector3(1.4, 1.0, 0.7)
		tail.add_child(f)
	for side in [-1, 1]:
		var fin := Stage.mesh(fluke, skin, Vector3(side * size * 1.0, -size * 0.35, -size * 0.6))
		fin.rotation.z = side * 0.5
		whale.add_child(fin)
	var spot := SphereMesh.new()
	spot.radius = size * 0.09
	spot.height = size * 0.18
	for k in 7:
		for side in [-1, 1]:
			whale.add_child(Stage.mesh(spot, Stage.glow(Color("9fffe0")),
				Vector3(side * size * 0.82, size * 0.25, -size * 1.6 + k * size * 0.5)))
	return whale


func _comet() -> void:
	var start := Vector3(_rng.randf_range(-1500, 1500), _rng.randf_range(250, 650), _rng.randf_range(-1500, 1500))
	var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, -0.1), _rng.randf_range(-1, 1)).normalized()
	var head := Stage.mesh(_sphere(4.0), Stage.glow(Color("fff2d0")), start)
	add_child(head)
	var trail := CPUParticles3D.new()
	trail.amount = 60
	trail.lifetime = 1.6
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 2.0
	trail.scale_amount_min = 1.0
	trail.scale_amount_max = 3.0
	trail.mesh = Fx.blob(2.5)
	trail.color_ramp = Fx.fade(Color(0.75, 0.9, 1.0, 0.8))
	head.add_child(trail)
	var t := create_tween()
	t.tween_property(head, "position", start + dir * 2400.0, 6.0)
	t.tween_callback(head.queue_free)


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	return s
