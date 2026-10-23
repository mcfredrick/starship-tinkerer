## The club race: your Kettle against the dock's racers on the Quietwater ring.
## Physics live in RaceSim; this screen draws the track and ships and reads input.
extends Screen

const TRACK_SHADER := preload("res://shaders/track.gdshader")
const HOVER := 1.3
const PLACES := ["1st", "2nd", "3rd", "4th"]

var sim: RaceSim
var race: Dictionary
var player: Dictionary
var _ships := {}
var _flames := {}
var _shields := {}
var _camera: Camera3D
var _ribbons: MeshInstance3D
var _lap: Label
var _place: Label
var _speed: Label
var _boost: ProgressBar
var _drift: ProgressBar
var _gadget: Label
var _big: Label
var _results: PanelContainer
var _touch := {}
var _done := false
var _engine: AudioStreamPlayer
var _count := 4


func _ready() -> void:
	super()
	race = Content.world.race.club
	sim = RaceSim.new(Track.quietwater(), race.laps)
	for pilot in race.rivals:
		var ship: Dictionary = GameState.ships[Content.world.pilots[pilot].ship]
		sim.add_racer(pilot, ShipStats.compute(ship, Content.parts), ShipStats.gadget(ship, Content.parts), true,
			race.rivals[pilot])
	var kettle: Dictionary = GameState.ships.kettle
	player = sim.add_racer("player", ShipStats.compute(kettle, Content.parts), ShipStats.gadget(kettle, Content.parts),
		false, 1.0, Perks.effects(GameState.perks, Content.perks))
	_build_world()
	_build_hud()
	if DisplayServer.is_touchscreen_available():
		_build_touch()
	_engine = Sfx.loop("engine", self, -10.0)
	_engine.play()


# ---------------------------------------------------------------- world

func _build_world() -> void:
	var world := Node3D.new()
	add_child(world)
	move_child(world, 0)
	world.add_child(Stage.environment())
	world.add_child(Stage.bramble(Vector3(150, -60, 900), 420.0))
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe2b8")
	sun.rotation_degrees = Vector3(-55, 30, 0)
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("7fb6d8")
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-20, -150, 0)
	world.add_child(fill)

	world.add_child(_track_mesh())
	world.add_child(_gate(0.0, true))
	for s in range(300, int(sim.track.length) - 100, 300):
		world.add_child(_gate(float(s), false))
	_drum_gardens(world)

	for r in sim.racers:
		var ship_id: String = "kettle" if r.id == "player" else Content.world.pilots[r.id].ship
		var model := ShipModel.new()
		world.add_child(model)
		model.build(GameState.ships[ship_id])
		model.scale = Vector3.ONE * 0.9
		_ships[r.id] = model
		_flames[r.id] = _flame(model)
		var bubble := Stage.mesh(_sphere(3.2), _bubble_material())
		bubble.visible = false
		model.add_child(bubble)
		_shields[r.id] = bubble

	_ribbons = MeshInstance3D.new()
	_ribbons.material_override = _ribbon_material()
	world.add_child(_ribbons)
	_camera = Camera3D.new()
	_camera.fov = 70
	_camera.far = 4000
	world.add_child(_camera)
	_update_visuals(1.0)


func _track_mesh() -> MeshInstance3D:
	var t := sim.track
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := t.points.size()
	for i in n + 1:
		var k := i % n
		var p := t.points[k]
		var l := t.lefts[k] * t.half_width
		var v := i * Track.STEP / 10.0
		st.set_uv(Vector2(0, v))
		st.add_vertex(p + l)
		st.set_uv(Vector2(1, v))
		st.add_vertex(p - l)
	for i in n:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 3)
		st.add_index(a + 2)
	var mat := ShaderMaterial.new()
	mat.shader = TRACK_SHADER
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


func _gate(s: float, start: bool) -> Node3D:
	var t := sim.track
	var g := Node3D.new()
	var p := t.position(s, 0)
	var fwd := t.heading(s)
	g.transform = Transform3D(Basis.looking_at(fwd), p)
	var post_mat := Stage.toon(Color("5b5262"), 0.2, 0.05)
	for side in [-1, 1]:
		g.add_child(Stage.mesh(Stage._box(Vector3(0.8, 9, 0.8)), post_mat, Vector3(side * (t.half_width + 0.6), 4.5, 0)))
	var beam := Stage.mesh(Stage._box(Vector3(t.half_width * 2 + 2, 1.2, 0.8)), post_mat, Vector3(0, 9, 0))
	g.add_child(beam)
	var strip := Stage.mesh(Stage._box(Vector3(t.half_width * 2, 0.4, 0.9)),
		Stage.glow(Color("ffd27a") if not start else Color("9fffd0")), Vector3(0, 8.4, 0))
	g.add_child(strip)
	if start:
		var banner := Stage.mesh(Stage._box(Vector3(t.half_width * 2 - 2, 1.4, 0.3)), Stage.toon(UI.CREAM, 0, 0.03),
			Vector3(0, 10.6, 0))
		g.add_child(banner)
	return g


func _drum_gardens(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var greens := [Color("8fae7e"), Color("6f9e6e"), Color("a8c686")]
	for i in 26:
		var s := rng.randf() * sim.track.length
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var p := sim.track.position(s, side * rng.randf_range(40, 140))
		var drum := CylinderMesh.new()
		var r := rng.randf_range(8, 20)
		drum.top_radius = r
		drum.bottom_radius = r
		drum.height = rng.randf_range(12, 40)
		var mi := Stage.mesh(drum, Stage.toon(Color("6c6470"), 0.1, 0.0), p + Vector3(0, -drum.height * 0.5 - rng.randf_range(4, 30), 0))
		var top := CylinderMesh.new()
		top.top_radius = r * 0.92
		top.bottom_radius = r * 0.92
		top.height = 0.6
		mi.add_child(Stage.mesh(top, Stage.toon(greens[i % 3], 0, 0), Vector3(0, drum.height * 0.5 + 0.2, 0)))
		world.add_child(mi)


func _flame(model: Node3D) -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.45
	cone.height = 1.0
	var mi := Stage.mesh(cone, Stage.glow(Color("ffb35a")))
	mi.rotation_degrees.x = 90
	model.add_child(mi)
	return mi


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	return s


func _bubble_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.6, 0.95, 1.0, 0.25)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _ribbon_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# ---------------------------------------------------------------- hud

func _build_hud() -> void:
	_lap = UI.heading("", 30, UI.CREAM)
	_place = UI.heading("", 44, Color("ffd27a"))
	var top := UI.vbox([_place, _lap], 0)
	UI.place(top, Control.PRESET_TOP_LEFT, Vector2(90, 20), Vector2(300, 0))
	ui.add_child(top)

	_speed = UI.heading("", 30, UI.CREAM)
	_boost = _bar(Color("ffb35a"))
	_drift = _bar(Color("9fffd0"))
	_gadget = UI.label("", 18, UI.CREAM)
	var dash := UI.vbox([_speed, UI.hbox([UI.label("Boost", 16, UI.CREAM), _boost]),
		UI.hbox([UI.label("Drift", 16, UI.CREAM), _drift]), _gadget], 4)
	var dash_panel := UI.panel(dash, Color(0.1, 0.07, 0.16, 0.6), 12)
	UI.place(dash_panel, Control.PRESET_BOTTOM_LEFT, Vector2(24, -190), Vector2(300, 0))
	ui.add_child(dash_panel)

	var keys := "A/D or arrows steer   ·   S brake   ·   hold Space while turning to drift, release for a burst"
	keys += "   ·   Shift boost   ·   E gadget"
	var hint := UI.label(keys, 16, Color(UI.CREAM, 0.8))
	UI.place(hint, Control.PRESET_BOTTOM_WIDE, Vector2(340, -40), Vector2(-360, 30))
	ui.add_child(hint)

	_big = UI.heading("", 96, Color("ffd27a"))
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.place(_big, Control.PRESET_CENTER, Vector2(-300, -160), Vector2(600, 120))
	ui.add_child(_big)


func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = 1.0
	b.show_percentage = false
	b.custom_minimum_size = Vector2(200, 14)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("fill", UI.box(color, 6, 0))
	b.add_theme_stylebox_override("background", UI.box(Color(1, 1, 1, 0.15), 6, 0))
	return b


func _build_touch() -> void:
	var left := UI.hbox([_touch_button("◀", "left"), _touch_button("▶", "right")], 16)
	UI.place(left, Control.PRESET_BOTTOM_LEFT, Vector2(30, -330), Vector2(260, 110))
	ui.add_child(left)
	var right := UI.hbox([_touch_button("Drift", "drift"), _touch_button("Boost", "boost"),
		_touch_button("Gadget", "gadget")], 12)
	UI.place(right, Control.PRESET_BOTTOM_RIGHT, Vector2(-420, -150), Vector2(400, 110))
	ui.add_child(right)


func _touch_button(text: String, key: String) -> Button:
	var b := UI.button(text, func(): pass, 26)
	b.custom_minimum_size = Vector2(120, 100)
	b.button_down.connect(func(): _touch[key] = true)
	b.button_up.connect(func(): _touch[key] = false)
	return b


# ---------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
	sim.step(delta, _input_state())
	for e in sim.events:
		if e.id != "player":
			continue
		match e.type:
			"wall":
				Sfx.play("bump", randf_range(0.9, 1.1))
			"miniboost":
				Sfx.play("whoosh")
				_flash_text("Whoosh!")
			"gadget":
				_flash_text("Ribbon out!" if e.gadget == "ribbon" else "Pop!")
			"finish":
				_on_finish()


func _input_state() -> Dictionary:
	var steer := Input.get_axis("steer_right", "steer_left")
	if _touch.get("left", false):
		steer += 1.0
	if _touch.get("right", false):
		steer -= 1.0
	return {
		"steer": steer,
		"throttle": not Input.is_action_pressed("brake"),
		"brake": Input.is_action_pressed("brake"),
		"drift": Input.is_action_pressed("drift") or _touch.get("drift", false),
		"boost": Input.is_action_pressed("boost") or _touch.get("boost", false),
		"gadget": Input.is_action_just_pressed("gadget") or _touch.get("gadget", false),
	}


func _process(delta: float) -> void:
	_update_visuals(minf(delta * 5.0, 1.0))
	_update_hud()
	_engine.pitch_scale = 0.6 + player.v / 40.0 + (0.25 if player.boosting or player.mini > 0 else 0.0)
	var count := ceili(-sim.time)
	if count != _count and count >= 0:
		_count = count
		Sfx.play("go" if count == 0 else "beep")


func _update_visuals(follow: float) -> void:
	var t := sim.track
	for r in sim.racers:
		var model: Node3D = _ships[r.id]
		var dir := t.heading(r.s).rotated(Vector3.UP, r.psi)
		var bob := sin(sim.time * 3.0 + r.s * 0.05) * 0.12
		var roll := Basis(Vector3.FORWARD, -r.steer * 0.35 * clampf(r.v / 30.0, 0, 1))
		model.transform = Transform3D(Basis.looking_at(dir) * roll * Basis.from_scale(Vector3.ONE * 0.9),
			t.position(r.s, r.d) + Vector3.UP * (HOVER + bob))
		var flame: MeshInstance3D = _flames[r.id]
		var heat: float = 0.4 + r.v / 30.0 + (1.2 if r.boosting or r.mini > 0 else 0.0)
		flame.scale = Vector3(1, heat, 1)
		flame.position = Vector3(0, 0, 2.0 + heat * 0.5)
		_shields[r.id].visible = r.shield > 0
	var p: Node3D = _ships["player"]
	var back := -p.global_basis.z
	var want := p.global_position - back * 10.0 + Vector3.UP * 4.0
	_camera.global_position = _camera.global_position.lerp(want, follow)
	_camera.look_at(p.global_position + back * 6.0 + Vector3.UP * 1.0)
	_camera.fov = lerpf(_camera.fov, 68.0 + player.v * 0.25, follow * 0.5)
	_draw_ribbons()


func _draw_ribbons() -> void:
	var t := sim.track
	var im := ImmediateMesh.new()
	for rb in sim.ribbons:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var alpha := clampf(rb.life, 0.0, 1.0) * 0.7
		var s: float = rb.from
		while s <= rb.to:
			var wave := sin(s * 0.3 + sim.time * 6.0) * 0.4
			var c := Color(1.0, 0.6 + 0.3 * sin(s * 0.2), 0.8, alpha)
			im.surface_set_color(c)
			im.surface_add_vertex(t.position(s, rb.d + 1.6) + Vector3.UP * (0.6 + wave))
			im.surface_set_color(c)
			im.surface_add_vertex(t.position(s, rb.d - 1.6) + Vector3.UP * (0.6 + wave))
			s += 2.0
		im.surface_end()
	_ribbons.mesh = im


func _update_hud() -> void:
	if sim.time < 0:
		_big.text = str(ceili(-sim.time))
	elif sim.time < 1.0:
		_big.text = "Go!"
	elif _big.text in ["Go!", "1", "2", "3"]:
		_big.text = ""
	_lap.text = "Lap %d / %d" % [sim.lap_of(player), sim.laps]
	_place.text = PLACES[sim.place_of(player) - 1]
	_speed.text = "%d km/h" % roundi(player.v * 3.6)
	_boost.value = player.boost / player.m.boost_capacity
	_drift.value = clampf(player.charge / player.drift_need, 0, 1)
	if player.gadget == "":
		_gadget.text = "No gadget fitted"
	elif player.cooldown > 0:
		_gadget.text = "%s recharging" % player.gadget.capitalize()
	else:
		_gadget.text = "%s ready (E)" % player.gadget.capitalize()


func _flash_text(text: String) -> void:
	_big.text = text
	var t := create_tween()
	t.tween_interval(0.8)
	t.tween_callback(func(): if _big.text == text: _big.text = "")


func _on_finish() -> void:
	if _done:
		return
	_done = true
	var place := sim.place_of(player)
	_big.text = PLACES[place - 1] + "!"
	await get_tree().create_timer(2.0).timeout
	var prize: int = race.prizes[place - 1] if place <= race.prizes.size() else 0
	var xp := 20 + (3 - place) * 10
	GameState.add_xp("piloting", xp)
	if prize > 0:
		GameState.add_pebs(prize, "Club race, %s place: %s" % [PLACES[place - 1], UI.pebs(prize)])
	GameState.flags.raced_today = true
	GameState.spark = maxi(GameState.spark - 1, 0)
	GameState.save()

	var rows := UI.vbox([UI.heading("Quietwater Club Race", 28)], 6)
	for i in sim.standings().size():
		var r: Dictionary = sim.standings()[i]
		var name: String = GameState.player.name if r.id == "player" else Content.world.pilots[r.id].short
		var time := "%.1fs" % r.finish if r.finish >= 0 else "still flying"
		rows.add_child(UI.label("%s   %s   %s" % [PLACES[i], name, time], 22, UI.TEAL if r.id == "player" else UI.INK))
	rows.add_child(UI.label("Prize %s   ·   Piloting +%d" % [UI.pebs(prize), xp], 20, UI.AMBER_DARK))
	_results = UI.panel(rows, UI.CREAM, 24)
	UI.place(_results, Control.PRESET_CENTER, Vector2(-260, -160), Vector2(520, 0))
	ui.add_child(_results)
	var scene := "race_won" if place == 1 else ("race_podium" if place <= 3 and place < sim.racers.size() else "race_back")
	await Router.talk(scene)
	rows.add_child(UI.button("Back to the shop", func(): Router.go("shop"), 22))
