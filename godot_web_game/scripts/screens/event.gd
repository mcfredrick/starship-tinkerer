## A special event away from the hangar: a place of its own, the guests' ships gathered, and a
## conversation, with an optional repair minigame and a gift. Places: "comet" (the Close Pass, the
## comet's nearest approach in fifty years) and "lighthouse" (the Lumen Reach light on its ice field).
extends Screen

const TAIL := preload("res://shaders/comet_tail.gdshader")
## High over the gathered ships, so it reads above them and clear of the dialogue box.
const COMET := Vector3(-260, 400, -900)
const SHIP_HEIGHT := 5.0
## The drum garden's size: the park wraps all the way round the inside of this cylinder.
const DRUM_RADIUS := 40.0
const DRUM_LENGTH := 160.0
## Where the lighthouse's whale settles once the beacon is lit: off to the side, behind the tower.
const WHALE_REST := Vector3(30, 24, 14)

var _id := ""
var _event: Dictionary
var _orbit := 0.0
var _ships: Array[Node3D] = []
var _cam: Camera3D
var _lit := false
var _beam: Node3D
var _lamp: ShaderMaterial
var _whale: Node3D


## Screen params: `id` (world.json events); `lit` (screenshots) shows the lighthouse already fixed.
func setup(params: Dictionary) -> void:
	_id = params.get("id", "close_pass")
	_lit = params.has("lit")


func _ready() -> void:
	super()
	_event = Content.world.events[_id]
	var world := Node3D.new()
	add_child(world)
	if _event.place == "gardens":
		world.add_child(SpaceScenery.environment_for({"sky": ["3a2f5a", "6b4a8a", "ffd27a"], "fog_density": 0.004,
			"fog": "6b5a8a", "ambient": "8a7a6a"}))
		_drum(world)
	elif _event.place == "lighthouse":
		world.add_child(SpaceScenery.environment_for({"sky": ["1d4a5a", "3a5f8a", "c9e8ff"], "deep": "02060c",
			"fog_density": 0.0, "ambient": "5a6f8a"}))
		_lighthouse(world)
	else:
		world.add_child(SpaceScenery.environment_for({"sky": ["3a6ea5", "c06fa8", "ffe0b8"], "fog_density": 0.0}))
		_comet(world)
	_gather(world)
	_cam = Camera3D.new()
	_cam.fov = 60
	_cam.far = 8000
	world.add_child(_cam)
	if _lit:
		_light_the_beacon()
		_whale.position = WHALE_REST
	else:
		_play.call_deferred()


func _process(delta: float) -> void:
	_orbit += delta * 0.04
	if _event.place == "gardens":
		# Stand on the orchard floor and look along the drum, so the far side curves up overhead.
		_cam.position = Vector3(-DRUM_LENGTH * 0.42, -DRUM_RADIUS + 3.0, sin(_orbit) * 4.0)
		_cam.look_at(Vector3(DRUM_LENGTH * 0.12, DRUM_RADIUS * 0.15, 6.0))
		return
	if _event.place == "lighthouse":
		_cam.position = Vector3(-34.0 + sin(_orbit) * 6.0, 12.0, 46.0 + cos(_orbit) * 4.0)
		_cam.look_at(Vector3(0, 16, 0))
		if _beam and _beam.visible:
			_beam.rotation.y += delta * 0.6
		if _whale and _whale.visible:
			_whale.position = _whale.position.lerp(WHALE_REST, delta * 0.25)
			_whale.get_node("tail").rotation.x = sin(_orbit * 30.0) * 0.3
		for i in _ships.size():
			_ships[i].position.y = 3.5 + sin(Time.get_ticks_msec() / 900.0 + i) * 0.2
		return
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


## Inside a drum garden: lawns and orchards on every side of a slowly turning cylinder, an amber
## sun-line down the middle, misters, and paper lanterns drifting up toward it.
func _drum(world: Node3D) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffd9a0")
	lamp.light_energy = 2.0
	lamp.omni_range = DRUM_LENGTH
	world.add_child(lamp)
	var shell := CylinderMesh.new()
	shell.top_radius = DRUM_RADIUS
	shell.bottom_radius = DRUM_RADIUS
	shell.height = DRUM_LENGTH
	shell.radial_segments = 64
	shell.flip_faces = true
	shell.cap_top = false
	shell.cap_bottom = false
	var floor := Stage.mesh(shell, Stage.toon(Color("6fae5c"), 0.0, 0.0))
	floor.rotation.z = PI / 2
	world.add_child(floor)
	var axis := Basis(Vector3(0, 0, 1), PI / 2)
	# End walls: plated discs with a big round window onto space and a brass rim.
	for end in [-1, 1]:
		var wall := CylinderMesh.new()
		wall.top_radius = DRUM_RADIUS
		wall.bottom_radius = DRUM_RADIUS
		wall.height = 1.0
		var w := Stage.mesh(wall, Stage.toon(Color("8e9298"), 0.2, 0.0), Vector3(end * DRUM_LENGTH / 2, 0, 0))
		w.basis = axis
		world.add_child(w)
		var pane := CylinderMesh.new()
		pane.top_radius = DRUM_RADIUS * 0.45
		pane.bottom_radius = DRUM_RADIUS * 0.45
		pane.height = 1.2
		var p := Stage.mesh(pane, Stage.glow(Color("1d1838")), Vector3(end * (DRUM_LENGTH / 2 - 0.2), 0, 0))
		p.basis = axis
		world.add_child(p)
		var rim := TorusMesh.new()
		rim.inner_radius = DRUM_RADIUS * 0.45
		rim.outer_radius = DRUM_RADIUS * 0.5
		var r := Stage.mesh(rim, Stage.toon(Color("e8a33d"), 0.5, 0.0), Vector3(end * (DRUM_LENGTH / 2 - 0.6), 0, 0))
		r.basis = axis
		world.add_child(r)
	var sun := CylinderMesh.new()
	sun.top_radius = 0.8
	sun.bottom_radius = 0.8
	sun.height = DRUM_LENGTH
	var s := Stage.mesh(sun, Stage.glow(Color("ffd27a")))
	s.basis = axis
	world.add_child(s)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var leaves := [Color("8fae7e"), Color("6f9e6e"), Color("a8c686")]
	var plum := Stage.toon(Color("7d3f6e"), 0.4, 0.02)
	for i in 160:
		var a := rng.randf() * TAU
		var x := rng.randf_range(-DRUM_LENGTH * 0.48, DRUM_LENGTH * 0.48)
		var inward := Vector3(0, -cos(a), -sin(a))
		var base := -inward * DRUM_RADIUS + Vector3(x, 0, 0)
		var tree := Node3D.new()
		tree.transform = Transform3D(Basis(inward.cross(Vector3.RIGHT).normalized(), inward, Vector3.RIGHT), base)
		var h := rng.randf_range(4.0, 7.0)
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.25
		trunk.bottom_radius = 0.4
		trunk.height = h * 0.6
		tree.add_child(Stage.mesh(trunk, Stage.toon(Color("7a5040"), 0.0, 0.03), Vector3(0, h * 0.3, 0)))
		var crown := SphereMesh.new()
		crown.radius = h * 0.35
		crown.height = h * 0.6
		tree.add_child(Stage.mesh(crown, Stage.toon(leaves[i % 3], 0.0, 0.03), Vector3(0, h * 0.75, 0)))
		for k in 3:
			var fruit := SphereMesh.new()
			fruit.radius = 0.3
			fruit.height = 0.6
			var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.2), rng.randf_range(-1, 1)).normalized() * h * 0.33
			tree.add_child(Stage.mesh(fruit, plum, Vector3(0, h * 0.75, 0) + off))
		world.add_child(tree)
	var lanterns := CPUParticles3D.new()
	lanterns.amount = 160
	lanterns.lifetime = 14.0
	lanterns.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	lanterns.emission_box_extents = Vector3(DRUM_LENGTH * 0.45, 1, 6)
	lanterns.position = Vector3(0, -DRUM_RADIUS + 3, 0)
	lanterns.direction = Vector3.UP
	lanterns.spread = 10.0
	lanterns.gravity = Vector3.ZERO
	lanterns.initial_velocity_min = 1.5
	lanterns.initial_velocity_max = 2.5
	lanterns.mesh = Fx.blob(0.45)
	lanterns.color_ramp = Fx.fade(Color(1.0, 0.75, 0.4, 1.0))
	lanterns.preprocess = 10.0
	world.add_child(lanterns)
	var mist := CPUParticles3D.new()
	mist.amount = 80
	mist.lifetime = 3.0
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(DRUM_LENGTH * 0.45, 0.5, 2)
	mist.position = Vector3(0, -DRUM_RADIUS + 1.5, 9)
	mist.direction = Vector3.UP
	mist.gravity = Vector3(0, -1, 0)
	mist.initial_velocity_min = 2.0
	mist.initial_velocity_max = 4.0
	mist.mesh = Fx.blob(0.3)
	mist.color_ramp = Fx.fade(Color(0.9, 0.97, 1.0, 0.5))
	mist.preprocess = 3.0
	world.add_child(mist)


## A striped lighthouse on a floe in a drifting ice field, its lamp dark until the beacon's fixed,
## and a star whale waiting below the ice.
func _lighthouse(world: Node3D) -> void:
	var star := DirectionalLight3D.new()
	star.light_color = Color("cfe4ff")
	star.light_energy = 0.9
	star.rotation_degrees = Vector3(-40, 50, 0)
	world.add_child(star)
	var ice := Stage.toon(Color("dcefff"), 0.4, 0.03)
	var floe := CylinderMesh.new()
	floe.top_radius = 16.0
	floe.bottom_radius = 13.0
	floe.height = 4.0
	world.add_child(Stage.mesh(floe, ice, Vector3(0, -2, 0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 60:
		var chunk := BoxMesh.new()
		chunk.size = Vector3(rng.randf_range(4, 14), rng.randf_range(1, 3), rng.randf_range(4, 14))
		var a := rng.randf() * TAU
		var r := rng.randf_range(26, 220)
		var mi := Stage.mesh(chunk, ice, Vector3(cos(a) * r, rng.randf_range(-14, 2), sin(a) * r))
		mi.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
		world.add_child(mi)
	var stripes := [Color("c8433f"), Color("f4ecdc")]
	for k in 6:
		var band := CylinderMesh.new()
		band.top_radius = 3.4 - (k + 1) * 0.25
		band.bottom_radius = 3.4 - k * 0.25
		band.height = 4.0
		world.add_child(Stage.mesh(band, Stage.toon(stripes[k % 2], 0.1, 0.04), Vector3(0, 2 + k * 4.0, 0)))
	var gallery := TorusMesh.new()
	gallery.inner_radius = 2.0
	gallery.outer_radius = 2.6
	world.add_child(Stage.mesh(gallery, Stage.toon(Color("39343f")), Vector3(0, 24.2, 0)))
	var lamp_room := CylinderMesh.new()
	lamp_room.top_radius = 1.5
	lamp_room.bottom_radius = 1.6
	lamp_room.height = 3.0
	_lamp = Stage.glow(Color("4a4a3a"))
	world.add_child(Stage.mesh(lamp_room, _lamp, Vector3(0, 25.8, 0)))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.2
	cap.bottom_radius = 1.9
	cap.height = 1.6
	world.add_child(Stage.mesh(cap, Stage.toon(Color("c8433f"), 0.1, 0.04), Vector3(0, 28.1, 0)))
	_beam = Node3D.new()
	_beam.position = Vector3(0, 25.8, 0)
	_beam.visible = false
	# The comet tail's shader fades each arm out from the lamp.
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = TAIL
	beam_mat.set_shader_parameter("color", Color(1.0, 0.75, 0.35))
	beam_mat.set_shader_parameter("core", Color(1.0, 0.95, 0.7))
	for side in [-1, 1]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.8
		cone.bottom_radius = 14.0
		cone.height = 180.0
		cone.cap_top = false
		cone.cap_bottom = false
		var arm := Stage.mesh(cone, beam_mat, Vector3(side * 90.0, 0, 0))
		arm.rotation.z = side * PI / 2
		_beam.add_child(arm)
	world.add_child(_beam)
	_whale = SpaceScenery.whale(9.0, Color("7f9fd6"))
	_whale.position = Vector3(60, -60, -30)
	_whale.rotation.y = -PI / 2
	_whale.visible = false
	world.add_child(_whale)


## The beacon catches: the lamp lights, the beam sweeps, and the whale rises.
func _light_the_beacon() -> void:
	_lamp.set_shader_parameter("color", Color("ffe08a"))
	_beam.visible = true
	_whale.visible = true
	Sfx.play("success")


## The guests' ships and yours, gathered to watch: in a loose circle facing the comet, or parked
## at the foot of the lighthouse.
func _gather(world: Node3D) -> void:
	var ids: Array = _event.guests.map(func(p): return Content.world.pilots[p].ship)
	ids.append(GameState.race_ship)
	if _event.place == "gardens":
		return
	if _event.place == "lighthouse":
		var holder := Node3D.new()
		holder.position = Vector3(-9, 3.5, 7)
		var model := ShipModel.new()
		holder.add_child(model)
		model.build(GameState.ships[GameState.race_ship])
		model.rotation.y = 0.8
		world.add_child(holder)
		_ships.append(holder)
		return
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
	if _event.has("minigame"):
		var game: Minigame = load("res://scripts/minigames/%s.gd" % _event.minigame).new()
		game.setup(7)
		game.leniency = GameState.leniency("electronics", _event.minigame) + 0.3
		game.theme = Router.theme
		ui.add_child(game)
		await game.finished
	if _event.place == "lighthouse":
		_light_the_beacon()
		await get_tree().create_timer(2.5).timeout
	if _event.has("after"):
		await Router.talk(_event.after)
	if _event.has("gift"):
		GameState.finds[_event.gift] = true
		Router.toast("For your collection: %s." % Content.trade.trinkets[_event.gift].name)
	GameState.flags["event_" + _id] = true
	if _event.has("unlock"):
		GameState.flags[_event.unlock] = true
		Router.toast(_event.unlock_note)
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
