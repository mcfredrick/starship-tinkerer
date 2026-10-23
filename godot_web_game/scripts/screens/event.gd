## A special event away from the hangar: a scene of its own, the cast's ships gathered, and a
## conversation. The Close Pass: the comet's nearest approach in fifty years, watched by the dock.
extends Screen

const TAIL := preload("res://shaders/comet_tail.gdshader")
## High over the gathered ships, so it reads above them and clear of the dialogue box.
const COMET := Vector3(-260, 400, -900)
const SHIP_HEIGHT := 5.0

var _id := ""
var _event: Dictionary
var _orbit := 0.0
var _ships: Array[Node3D] = []
var _cam: Camera3D


func setup(params: Dictionary) -> void:
	_id = params.get("id", "close_pass")


func _ready() -> void:
	super()
	_event = Content.world.events[_id]
	var world := Node3D.new()
	add_child(world)
	world.add_child(SpaceScenery.environment_for({"sky": ["3a6ea5", "c06fa8", "ffe0b8"], "fog_density": 0.0}))
	_comet(world)
	_gather(world)
	_cam = Camera3D.new()
	_cam.fov = 60
	_cam.far = 8000
	world.add_child(_cam)
	_play.call_deferred()


func _process(delta: float) -> void:
	_orbit += delta * 0.04
	# Drift slowly behind the ring of ships, looking past them toward the comet.
	_cam.position = Vector3(sin(_orbit) * 6.0, 3.0, 26.0 + cos(_orbit) * 3.0)
	_cam.look_at(Vector3(-40, 14, -200))
	for i in _ships.size():
		_ships[i].position.y = SHIP_HEIGHT + sin(Time.get_ticks_msec() / 900.0 + i) * 0.4


## A great comet: a glowing head, a broad tail of light, and a stream of sparkles behind it.
func _comet(world: Node3D) -> void:
	var at := COMET
	var head := Stage.mesh(_sphere(38.0), Stage.glow(Color("fff6e0")), at)
	world.add_child(head)
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo.albedo_color = Color(1.0, 0.75, 0.9, 0.25)
	halo.cull_mode = BaseMaterial3D.CULL_DISABLED
	world.add_child(Stage.mesh(_sphere(90.0), halo, at))
	# The tail points away from the sun, with its narrow end at the head.
	var away := Vector3(0.75, 0.3, -0.6).normalized()
	for layer in [[1700.0, 280.0, Color(0.6, 0.75, 1.0)], [1300.0, 150.0, Color(1.0, 0.7, 0.9)]]:
		var tail := CylinderMesh.new()
		tail.top_radius = 30.0
		tail.bottom_radius = layer[1]
		tail.height = layer[0]
		tail.radial_segments = 24
		tail.cap_top = false
		tail.cap_bottom = false
		var mat := ShaderMaterial.new()
		mat.shader = TAIL
		mat.set_shader_parameter("color", layer[2])
		var mi := Stage.mesh(tail, mat)
		var up := -away
		var side := up.cross(Vector3.FORWARD).normalized()
		mi.transform = Transform3D(Basis(side, up, side.cross(up)), at + away * layer[0] / 2.0)
		world.add_child(mi)
	var sparkles := CPUParticles3D.new()
	sparkles.amount = 400
	sparkles.lifetime = 6.0
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 60.0
	sparkles.direction = away
	sparkles.spread = 12.0
	sparkles.initial_velocity_min = 120.0
	sparkles.initial_velocity_max = 220.0
	sparkles.gravity = Vector3.ZERO
	sparkles.mesh = Fx.blob(3.0)
	sparkles.color_ramp = Fx.fade(Color(1.0, 0.85, 0.95, 0.9))
	sparkles.position = at
	world.add_child(sparkles)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe2c8")
	sun.rotation_degrees = Vector3(-35, -30, 0)
	world.add_child(sun)


## The guests' ships and yours, hanging in a loose circle facing the comet.
func _gather(world: Node3D) -> void:
	var ids: Array = _event.guests.map(func(p): return Content.world.pilots[p].ship)
	ids.append(GameState.race_ship)
	for i in ids.size():
		var a := -1.2 + 2.4 * i / maxf(ids.size() - 1, 1)
		var holder := Node3D.new()
		holder.position = Vector3(sin(a) * 14.0, SHIP_HEIGHT, cos(a) * 6.0)
		var model := ShipModel.new()
		holder.add_child(model)
		model.build(GameState.ships[ids[i]])
		model.look_at_from_position(Vector3.ZERO, COMET.normalized() * 10.0, Vector3.UP)
		world.add_child(holder)
		_ships.append(holder)


func _play() -> void:
	await get_tree().create_timer(1.5).timeout
	await Router.talk(_event.scene)
	GameState.flags["event_" + _id] = true
	if _event.has("unlock"):
		GameState.flags[_event.unlock] = true
		Router.toast("You can paint the Comet trail livery now.")
	GameState.phase = "evening"
	GameState.save()
	var home := UI.button("Fly home", func(): Router.go("shop"), 24)
	UI.place(home, Control.PRESET_CENTER_BOTTOM, Vector2(-120, -100), Vector2(240, 60))
	ui.add_child(home)


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	return s
