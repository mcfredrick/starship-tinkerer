## The hangar as a 3D backdrop: a deck with a turntable cradle, open to space and Bramble's bands,
## lit warm from inside and cool from outside. Screens put a ShipModel on `cradle`.
class_name Stage
extends Node3D

const STARS := preload("res://shaders/stars.gdshader")
const BRAMBLE := preload("res://shaders/bramble.gdshader")
const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const GLOW := preload("res://shaders/glow.gdshader")

var cradle: Node3D
var camera: OrbitCamera
var spin_speed := 0.12


func _ready() -> void:
	add_child(environment())
	add_child(bramble(Vector3(-70, 8, -150), 60.0))
	_lights()
	_deck()
	cradle = Node3D.new()
	cradle.position.y = 1.6
	add_child(cradle)
	camera = OrbitCamera.new()
	add_child(camera)


func _process(delta: float) -> void:
	cradle.rotation.y += spin_speed * delta


static func environment() -> WorldEnvironment:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = STARS
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a3550")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	return we


static func bramble(at: Vector3, radius: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 64
	mesh.rings = 32
	var mat := ShaderMaterial.new()
	mat.shader = BRAMBLE
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.rotation_degrees = Vector3(12, 0, -14)
	return mi


static func toon(color: Color, gloss := 0.0, line := 0.04) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("gloss", gloss)
	if line > 0:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("width", line)
		m.next_pass = o
	return m


static func glow(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLOW
	m.set_shader_parameter("color", color)
	return m


static func mesh(m: Mesh, mat: Material, at := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	return mi


func _lights() -> void:
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe2b8")
	key.light_energy = 1.25
	key.rotation_degrees = Vector3(-50, 35, 0)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("7fb6d8")
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-20, -150, 0)
	add_child(fill)


func _deck() -> void:
	var deck := CylinderMesh.new()
	deck.top_radius = 14.0
	deck.bottom_radius = 14.0
	deck.height = 0.6
	deck.radial_segments = 64
	add_child(mesh(deck, toon(Color("4e4552"), 0.0, 0.0), Vector3(0, -0.3, 0)))

	var table := CylinderMesh.new()
	table.top_radius = 3.4
	table.bottom_radius = 3.6
	table.height = 0.35
	table.radial_segments = 64
	add_child(mesh(table, toon(Color("c9a24b"), 0.4, 0.03), Vector3(0, 0.17, 0)))
	var ring := TorusMesh.new()
	ring.inner_radius = 3.45
	ring.outer_radius = 3.6
	ring.rings = 64
	add_child(mesh(ring, glow(Color("ffd27a")), Vector3(0, 0.36, 0)))
	var post := CylinderMesh.new()
	post.top_radius = 0.25
	post.bottom_radius = 0.45
	post.height = 1.2
	add_child(mesh(post, toon(Color("6c6470")), Vector3(0, 0.9, 0)))

	# The hangar mouth: an arch of beams framing Bramble behind the cradle.
	var beam_mat := toon(Color("5b5262"), 0.2, 0.05)
	for x in [-9.0, 9.0]:
		add_child(mesh(_box(Vector3(0.9, 11, 0.9)), beam_mat, Vector3(x, 5.5, -8)))
	add_child(mesh(_box(Vector3(19, 0.9, 0.9)), beam_mat, Vector3(0, 11, -8)))
	for i in 7:
		var lamp := SphereMesh.new()
		lamp.radius = 0.18
		lamp.height = 0.36
		add_child(mesh(lamp, glow(Color("ffd27a")), Vector3(-7.5 + i * 2.5, 10.4, -7.5)))

	var crate_mat := toon(Color("b86d48"), 0.0, 0.04)
	var crate_trim := toon(Color("e8a33d"), 0.0, 0.03)
	for c in [[Vector3(-7, 0.6, 2), 1.2], [Vector3(-6.2, 0.5, 3.6), 1.0], [Vector3(-7.2, 1.8, 2.3), 0.9],
			[Vector3(7.5, 0.7, -2), 1.4]]:
		var s: float = c[1]
		var crate := mesh(_box(Vector3.ONE * s), crate_mat, c[0])
		crate.rotation.y = c[0].x * 0.3
		crate.add_child(mesh(_box(Vector3(s * 1.04, s * 0.18, s * 1.04)), crate_trim))
		add_child(crate)


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
