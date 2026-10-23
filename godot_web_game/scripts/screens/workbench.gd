## The workbench: scan for faults, repair them, swap parts, paint, tune, and (if you must) make mischief.
## Works on the commission ship (with the pilot's wants) or on your own Kettle.
extends Screen

const SCAN_RADIUS := 90.0
const WARM_RADIUS := 220.0
const SCAN_TIME := 1.4
const MARKER_LIFT := 56.0
## Scrubbing counts as done at this share of the hull, since some skin hides behind parts.
const WASH_DONE := 0.7

var ship_id: String
var commission := false
var build: Dictionary
var model: ShipModel
var stats_panel: StatsPanel
var _tab := ""
var _tabs: HFlowContainer
var _content: VBoxContainer
var _overlay: Control
var _markers := {}
var _scan := {}
var _painted := false
var _confirm_finish := false
var _open_repair := -1
var _open_tab := ""
var _focus := -1
var _fix_demo := -1
var _demo := ""
var _view: Array = []
var _scrubbing := false
var _repairing := false
var _wash_bar: ProgressBar
var _drone: WasherDrone
var _splash_in := 0.0


func setup(params: Dictionary) -> void:
	var job_ship: String = GameState.job_spec(GameState.job.id).ship if not GameState.job.is_empty() else "kettle"
	ship_id = params.get("ship", job_ship)
	_open_repair = int(params.get("repair", "-1"))
	_open_tab = params.get("tab", "")
	_focus = int(params.get("focus", "-1"))
	_fix_demo = int(params.get("fixfx", "-1"))
	_demo = params.get("demo", "")


func _ready() -> void:
	super()
	add_stage()
	stage.spin_speed = 0.0
	stage.camera.interactive = true
	stage.camera.distance = 10.5
	stage.camera.target = Vector3(-1.6, 1.9, 0)
	stage.camera.yaw = 0.9
	stage.camera.refresh()
	build = GameState.ships[ship_id]
	commission = not GameState.job.is_empty() and GameState.job_spec(GameState.job.id).ship == ship_id
	model = show_ship(ship_id)

	_overlay = UI.full(Control.new())
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	ui.add_child(_overlay)
	ui.add_child(Hud.new())

	_tabs = HFlowContainer.new()
	_tabs.add_theme_constant_override("h_separation", 6)
	_tabs.add_theme_constant_override("v_separation", 6)
	_content = UI.vbox([], 10)
	var title := UI.heading(build.name, 28)
	# Tab content scrolls inside a panel that stops above the bottom buttons, so expanding part
	# lists can't run off screen.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	var left := UI.panel(UI.vbox([title, _tabs, scroll], 12), Color(UI.CREAM, 0.96), 18)
	UI.place(left, Control.PRESET_LEFT_WIDE, Vector2(16, 84), Vector2(400, -170))
	ui.add_child(left)

	stats_panel = StatsPanel.new()
	stats_panel.baseline = ShipStats.compute(GameState.job.before if commission else build, Content.parts)
	if commission:
		var job: Dictionary = GameState.job_spec(GameState.job.id)
		stats_panel.wants = job.wants
		stats_panel.pilot = GameState.pilot(job.pilot)
	UI.place(stats_panel, Control.PRESET_TOP_RIGHT, Vector2(-346, 84), Vector2(330, 0))
	UI.fit(stats_panel, 84, 86)
	ui.add_child(stats_panel)

	var finish := UI.button("Hand over to %s" % stats_panel.pilot.short if commission else "Back to the shop",
		_finish, 22)
	finish.name = "Finish"
	UI.place(finish, Control.PRESET_BOTTOM_RIGHT, Vector2(-346, -76), Vector2(330, 56))
	ui.add_child(finish)
	if commission:
		var back := UI.button("Step away", func(): Router.go("shop"), 18)
		UI.place(back, Control.PRESET_BOTTOM_LEFT, Vector2(16, -66), Vector2(160, 48))
		ui.add_child(back)

	var names := ["Scan", "Repair", "Wash", "Parts", "Paint", "Tune", "Mischief"] if commission else [
		"Wash", "Parts", "Paint", "Tune"]
	# Your own fixer-uppers have faults to find too.
	if not commission and _faults().any(func(f): return not f.fixed):
		names = ["Scan", "Repair"] + names
	for n in names:
		var b := UI.button(n, _select.bind(n), 17)
		b.toggle_mode = true
		b.name = n
		_tabs.add_child(b)
	stats_panel.show_build.call_deferred(build)
	_select(_open_tab if _open_tab in names else names[0])
	if _open_repair >= 0:
		_repair.call_deferred(_open_repair)
	if _focus >= 0:
		_lean_in.call_deferred(_focus)
	if _fix_demo >= 0:
		_demo_fix.call_deferred(_fix_demo)
	# Screenshot aids for the animated actions: `paint` repaints, `part` swaps the engine, `scrub`
	# strokes the brush across the middle of the screen, and a livery id puts that livery on.
	match _demo:
		"scrub":
			_demo_scrub.call_deferred()
		"paint":
			_paint.call_deferred("paint", "plum" if build.paint != "plum" else "teal")
		"part":
			_install.call_deferred("engine", _candidates("engine", build.parts.engine)[0])
	if _demo in Content.parts.liveries:
		_livery.call_deferred(_demo)


func _faults() -> Array:
	return build.get("faults", [])


func _select(tab: String) -> void:
	_tab = tab
	stage.camera.drag_filter = _on_hull if tab == "Wash" else Callable()
	for b in _tabs.get_children():
		b.button_pressed = b.name == tab
	for c in _content.get_children():
		c.queue_free()
	match tab:
		"Scan":
			_scan_tab()
		"Repair":
			_repair_tab()
		"Parts":
			_parts_tab()
		"Paint":
			_paint_tab()
		"Wash":
			_wash_tab()
		"Tune":
			_tune_tab()
		"Mischief":
			_mischief_tab()


func _say(text: String, size := 19, color := UI.INK) -> Label:
	var l := UI.label(text, size, color, true)
	l.custom_minimum_size.x = 360
	_content.add_child(l)
	return l


# ---------------------------------------------------------------- scan

func _scan_tab() -> void:
	if commission:
		_say("\"%s\"" % GameState.job_spec(GameState.job.id).request, 17, UI.MUTED)
	_say("Sweep the scanner slowly over the hull. Faults glow warm as you get close. Drag empty space to turn the view.")
	var found := _faults().filter(func(f): return f.found).size()
	_say("Faults found: %d" % found, 22, UI.TEAL)


func _process(delta: float) -> void:
	_position_markers()
	if _tab == "Scan":
		_update_scan(delta)
	if _drone:
		if _tab == "Wash" and build.get("grime", 0.0) > 0:
			if _demo != "scrub":
				_wash_at(ui.get_local_mouse_position(), delta)
		else:
			_drone.queue_free()
			_drone = null
	_overlay.queue_redraw()


func _screen_spot(f: Dictionary) -> Array:
	var cam := stage.camera
	var world := model.global_transform * model.spot_position(f.spot)
	var normal := model.global_basis * model.spot_normal(f.spot)
	var facing := normal.dot((cam.global_position - world).normalized()) > 0.05
	return [cam.unproject_position(world), facing]


func _update_scan(delta: float) -> void:
	var mouse := ui.get_local_mouse_position()
	var leniency := GameState.leniency("diagnostics", "scan")
	for i in _faults().size():
		var f: Dictionary = _faults()[i]
		if f.found:
			continue
		var s := _screen_spot(f)
		if s[1] and mouse.distance_to(s[0]) < SCAN_RADIUS:
			var before: float = _scan.get(i, 0.0)
			_scan[i] = before + delta * leniency
			if fmod(_scan[i], 0.35) < fmod(before, 0.35):
				Sfx.play("ping", 0.8 + _scan[i] / SCAN_TIME * 0.6)
			if _scan[i] >= SCAN_TIME:
				f.found = true
				Sfx.play("found")
				var xp := 12 + int(GameState.perk("scan_xp"))
				GameState.add_xp("diagnostics", xp)
				GameState.save()
				Router.toast("Found it: %s.  Diagnostics +%d" % [Content.parts.faults[f.type].name, xp])
				if _faults().all(func(x): return x.found):
					var find := GameState.roll_find(ship_id)
					if find:
						Sfx.play("found", 1.3)
						Router.toast("Tucked behind a panel: %s! It's yours now." % Content.trade.trinkets[find].name)
				_select(_tab)


func _draw_overlay() -> void:
	for i in _markers:
		var m: Button = _markers[i]
		if m.visible:
			var spot := m.position + Vector2(20, 20 + MARKER_LIFT)
			_overlay.draw_line(spot, m.position + Vector2(20, 40), Color(UI.CREAM, 0.8), 2.0, true)
			_overlay.draw_circle(spot, 3.5, Color(UI.CREAM, 0.9))
	if _tab == "Wash" and build.get("grime", 0.0) > 0:
		var at := ui.get_local_mouse_position()
		var ring := Color(0.8, 0.95, 1.0, 0.9 if _scrubbing else 0.5)
		_overlay.draw_arc(at, 16, 0, TAU, 24, ring, 2.0)
		for k in 4:
			var d := Vector2.from_angle(TAU * k / 4)
			_overlay.draw_line(at + d * 10, at + d * 22, ring, 2.0)
	if _tab != "Scan":
		return
	var mouse := ui.get_local_mouse_position()
	for i in _faults().size():
		var f: Dictionary = _faults()[i]
		if f.found:
			continue
		var s := _screen_spot(f)
		var d: float = mouse.distance_to(s[0])
		if s[1] and GameState.perk("deep_scan") > 0:
			_overlay.draw_circle(s[0], 9, Color(1.0, 0.8, 0.4, 0.25 + 0.1 * sin(Time.get_ticks_msec() / 300.0)))
		if s[1] and d < WARM_RADIUS:
			var warmth := 1.0 - d / WARM_RADIUS
			var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 120.0)
			_overlay.draw_circle(s[0], 26 * pulse, Color(1.0, 0.55, 0.25, warmth * 0.45))
			_overlay.draw_circle(s[0], 12 * pulse, Color(1.0, 0.8, 0.4, warmth * 0.7))
			if _scan.has(i):
				var t: float = _scan[i] / SCAN_TIME
				_overlay.draw_arc(mouse, 40, -PI / 2, -PI / 2 + TAU * t, 32, Color("ffd27a"), 5.0)
	_overlay.draw_arc(mouse, SCAN_RADIUS * 0.45, 0, TAU, 48, Color(0.6, 1.0, 0.9, 0.7), 2.0)
	_overlay.draw_line(mouse + Vector2(-12, 0), mouse + Vector2(12, 0), Color(0.6, 1.0, 0.9, 0.8), 2.0)
	_overlay.draw_line(mouse + Vector2(0, -12), mouse + Vector2(0, 12), Color(0.6, 1.0, 0.9, 0.8), 2.0)


func _position_markers() -> void:
	for i in _faults().size():
		var f: Dictionary = _faults()[i]
		if not f.found:
			continue
		if not _markers.has(i):
			var b := UI.button("!", _repair.bind(i), 20)
			b.custom_minimum_size = Vector2(40, 40)
			b.tooltip_text = Content.parts.faults[f.type].name
			ui.add_child(b)
			ui.move_child(b, 1)
			_markers[i] = b
		var m: Button = _markers[i]
		var s := _screen_spot(f)
		m.visible = s[1]
		# Markers float above their fault so the damage itself stays in view.
		m.position = s[0] - Vector2(20, 20 + MARKER_LIFT)
		m.text = "✓" if f.fixed else "!"
		m.disabled = f.fixed


# ---------------------------------------------------------------- repair

func _repair_tab() -> void:
	var found := 0
	for i in _faults().size():
		var f: Dictionary = _faults()[i]
		if not f.found:
			continue
		found += 1
		var spec: Dictionary = Content.parts.faults[f.type]
		if f.fixed:
			_say("✓  %s  (quality %d%%)" % [spec.name, roundi(f.score * 100)], 19, UI.GOOD)
			continue
		var steps: int = spec.steps.size()
		var done: int = f.get("step", 0)
		var text: String = "Repair: " + spec.name
		if done > 0:
			text = "Carry on: %s  (step %d of %d)" % [spec.name, done + 1, steps]
		elif steps > 1:
			text += "  (%d steps)" % steps
		_content.add_child(UI.button(text, _repair.bind(i), 19))
	if found < _faults().size():
		_say("The scan isn't finished. Something else may be off.", 18, UI.MUTED)
	_say("Starting a repair takes a little spark. Big faults take several steps.", 16, UI.MUTED)


## Works through a fault's remaining steps, one minigame each, showing progress on the hull
## between them. Spark is spent once, when the repair starts.
func _repair(i: int) -> void:
	var f: Dictionary = _faults()[i]
	if f.fixed or _repairing:
		return
	var spec: Dictionary = Content.parts.faults[f.type]
	var steps: Array = spec.steps
	if f.get("step", 0) == 0:
		if GameState.spark <= 0:
			Router.toast("You're out of spark. Time for tea and cake.", UI.BAD)
			return
		GameState.spark -= 1
		GameState.save()
	_repairing = true
	await _lean_in(i)
	while f.get("step", 0) < steps.size():
		var at: int = f.get("step", 0)
		var task: Dictionary = steps[at]
		var game: Minigame = load("res://scripts/minigames/%s.gd" % task.game).new()
		game.setup(f.spot)
		game.leniency = GameState.leniency(task.skill, task.game)
		game.step_note = "Step %d of %d" % [at + 1, steps.size()] if steps.size() > 1 else ""
		game.theme = Router.theme
		ui.add_child(game)
		var score: float = await game.finished
		f["scores"] = f.get("scores", []) + [score]
		f["step"] = at + 1
		var xp := 6 + roundi(14 * score)
		GameState.add_xp(task.skill, xp)
		GameState.save()
		if f.step < steps.size():
			Router.toast("Step done.  %s +%d" % [Skills.LABELS[task.skill], xp])
			await model.fault_fx(i).play_step(f.step)
	var total := 0.0
	for sc in f.scores:
		total += sc
	f.fixed = true
	f.score = total / f.scores.size()
	await model.fault_fx(i).play_fix()
	Sfx.play("success")
	GameState.save()
	Router.toast("%s fixed.  Quality %d%%" % [spec.name, roundi(f.score * 100)])
	await _lean_out()
	_repairing = false
	_rebuild()


## Swings the camera in to face a repair spot, remembering where it was.
func _lean_in(i: int) -> void:
	var cam := stage.camera
	_view = [cam.target, cam.yaw, cam.pitch, cam.distance]
	cam.interactive = false
	var spot: int = _faults()[i].spot
	var at := model.global_transform * model.spot_position(spot)
	await cam.fly_to(at, model.global_basis * model.spot_normal(spot), 4.2)


## Screenshot aid: leans in and plays a fault's fix effect without the minigame.
func _demo_fix(i: int) -> void:
	await _lean_in(i)
	model.fault_fx(i).play_fix()


func _lean_out() -> void:
	await stage.camera.glide(_view[0], _view[1], _view[2], _view[3], 0.7)
	stage.camera.interactive = true


# ---------------------------------------------------------------- parts

func _parts_tab() -> void:
	_say("Swap parts from your shelves, or buy from the market. Parts you take off go on your shelves.", 17,
		UI.MUTED)
	for slot in ShipStats.SLOTS:
		var current: String = build.parts.get(slot, "")
		var label := "%s:  %s" % [slot.capitalize(), Content.part(current).name if current else "(empty)"]
		var row := UI.vbox([UI.heading(label, 19)], 4)
		var options := UI.vbox([], 4)
		for id in _candidates(slot, current):
			var owned: int = GameState.parts.get(id, 0)
			var text := "%s  ·  %s" % [Content.part(id).name, "on your shelf" if owned > 0 else UI.pebs(Market.price(id))]
			var b := UI.button(text, _install.bind(slot, id), 16)
			b.tooltip_text = Content.part(id).desc
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			options.add_child(b)
			var delta := _delta_text(slot, id)
			if delta:
				var line := UI.label(delta, 14, UI.MUTED, true)
				line.custom_minimum_size.x = 300
				options.add_child(line)
		if slot == "top" and current:
			options.add_child(UI.button("Take it off", _remove.bind(slot), 16))
		options.visible = false
		var toggle := UI.button("Change", func(): options.visible = not options.visible, 16)
		row.add_child(UI.hbox([UI.label(Content.part(current).desc if current else "", 15, UI.MUTED, true), toggle]))
		row.get_child(1).get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(options)
		_content.add_child(row)


func _candidates(slot: String, current: String) -> Array:
	var ids: Array = []
	for id in Content.world.market + GameState.parts.keys():
		if id != current and Content.part(id).slot == slot and id not in ids:
			ids.append(id)
	return ids


func _delta_text(slot: String, id: String) -> String:
	var before := ShipStats.compute(build, Content.parts)
	var trial := build.duplicate(true)
	trial.parts[slot] = id
	var after := ShipStats.compute(trial, Content.parts)
	var parts: Array = []
	for s in StatsPanel.LABELS:
		var d: float = after[s] - before[s]
		if absf(d) >= 1:
			parts.append("%s %+d" % [StatsPanel.LABELS[s], d])
	return "  ".join(parts)


func _install(slot: String, id: String) -> void:
	if GameState.parts.get(id, 0) > 0:
		GameState.take(GameState.parts, id)
	else:
		var price := Market.price(id)
		if GameState.pebs < price:
			Router.toast("Not enough pebs for the %s." % Content.part(id).name, UI.BAD)
			return
		GameState.add_pebs(-price, "")
	var old: String = build.parts.get(slot, "")
	if old:
		GameState.give(GameState.parts, old)
	build.parts[slot] = id
	GameState.add_xp("mechanics", 3)
	GameState.save()
	model.lift_off(slot)
	_rebuild()
	model.drop_in(slot)
	Sfx.play("tick", 0.5)


func _remove(slot: String) -> void:
	GameState.give(GameState.parts, build.parts[slot])
	build.parts.erase(slot)
	GameState.save()
	model.lift_off(slot)
	_rebuild()


# ---------------------------------------------------------------- paint

func _paint_tab() -> void:
	var hearts := commission and GameState.perk("taste_hearts") > 0
	if commission:
		_say(stats_panel.pilot.taste_hint, 17, UI.MUTED)
	for zone in ["paint", "trim"]:
		_content.add_child(UI.heading("Main color" if zone == "paint" else "Trim", 19))
		var grid := GridContainer.new()
		grid.columns = 6
		for name in Content.parts.palette:
			var b := Button.new()
			b.custom_minimum_size = Vector2(52, 40)
			b.tooltip_text = name.capitalize()
			if hearts and name in stats_panel.pilot.taste:
				b.text = "♥"
				b.add_theme_color_override("font_color", Color.WHITE)
			var c := Content.color(name)
			var chosen: bool = build[zone] == name
			for state in ["normal", "hover", "pressed", "focus"]:
				var box := UI.box(c.lightened(0.15) if state == "hover" else c, 10, 0, false,
					UI.INK if chosen else c.darkened(0.25))
				b.add_theme_stylebox_override(state, box)
			b.pressed.connect(_paint.bind(zone, name))
			grid.add_child(b)
		_content.add_child(grid)
	_choice_row("Finish", Content.parts.finishes, build.get("finish", "gloss"), _finish_paint)
	_choice_row("Livery (in the trim color)", Content.parts.liveries, build.get("livery", "solid"), _livery)


## A row of toggle buttons for paint options, locked by Craft level or knowledge where they say so.
func _choice_row(title: String, options: Dictionary, current: String, action: Callable) -> void:
	_content.add_child(UI.heading(title, 19))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	for id in options:
		var o: Dictionary = options[id]
		var b := UI.button(o.name, action.bind(id), 16)
		b.toggle_mode = true
		b.button_pressed = id == current
		if o.has("craft") and Skills.level(GameState.skills.craft) < o.craft:
			b.disabled = true
			b.tooltip_text = "Needs Craft level %d" % o.craft
		elif o.has("knowledge") and not GameState.flags.has(o.knowledge):
			b.disabled = true
			b.tooltip_text = "You don't know how to lay this one down yet."
		row.add_child(b)
	_content.add_child(row)


func _livery(id: String) -> void:
	build["livery"] = id
	GameState.add_xp("craft", 2)
	GameState.save()
	_rebuild()
	Fx.puff(model, model.global_position + Vector3.UP, Vector3.UP, Content.color(build.trim))


func _finish_paint(id: String) -> void:
	build["finish"] = id
	GameState.add_xp("craft", 2)
	GameState.save()
	_rebuild()


func _paint(zone: String, color: String) -> void:
	var old := Content.color(build[zone])
	build[zone] = color
	if not _painted:
		_painted = true
		GameState.add_xp("craft", 6)
	GameState.save()
	_rebuild()
	model.sweep_paint(zone, old)
	Sfx.play("weld", 1.6)


# ---------------------------------------------------------------- wash

func _wash_tab() -> void:
	if build.get("grime", 0.0) <= 0:
		_say("Spotless. You can see your face in it.", 19, UI.GOOD)
		return
	model.make_scrubbable()
	if not _drone:
		_drone = WasherDrone.new()
		stage.add_child(_drone)
		_drone.global_position = stage.camera.global_position.lerp(model.global_position, 0.6)
	_say("Hold on the hull to blast the grime off with the washer drone. Drag empty space to turn the view. "
		+ "Washing costs no spark.")
	_wash_bar = ProgressBar.new()
	_wash_bar.max_value = 1.0
	_wash_bar.show_percentage = false
	_wash_bar.custom_minimum_size = Vector2(300, 18)
	_wash_bar.value = model.scrub_coverage() / WASH_DONE
	_content.add_child(_wash_bar)
	_say("A grimy ship rides rougher and handles heavier.", 16, UI.MUTED)


func _hull_hit(screen: Vector2) -> Dictionary:
	var cam := stage.camera
	var query := PhysicsRayQueryParameters3D.create(cam.project_ray_origin(screen),
		cam.project_ray_origin(screen) + cam.project_ray_normal(screen) * 50.0)
	return stage.get_world_3d().direct_space_state.intersect_ray(query)


func _on_hull(screen: Vector2) -> bool:
	return not _hull_hit(screen).is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if _tab != "Wash" or build.get("grime", 0.0) <= 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_scrubbing = event.pressed and _on_hull(event.position)
		if not event.pressed:
			GameState.save()


## Points the drone at the hull under `screen` and, while spraying, blasts that patch clean.
func _wash_at(screen: Vector2, delta: float) -> void:
	var hit := _hull_hit(screen)
	if hit.is_empty():
		_drone.idle()
		return
	_drone.aim(hit.position, hit.normal, _scrubbing)
	if not _scrubbing:
		return
	_splash_in -= delta
	if _splash_in <= 0:
		_splash_in = 0.06
		Fx.burst(model, hit.position, hit.normal, Color(0.85, 0.95, 1.0, 0.9), 8, 2.0, 0.06, -5.0, 0.5)
	if model.scrub(model.to_local(hit.position)):
		Fx.burst(model, hit.position, hit.normal, Color(0.45, 0.37, 0.28, 0.9), 10, 2.5, 0.06, -6.0, 0.7)
		var coverage := model.scrub_coverage()
		_wash_bar.value = coverage / WASH_DONE
		if coverage >= WASH_DONE or model.scrub_full():
			_finish_wash()


func _demo_scrub() -> void:
	await get_tree().create_timer(0.3).timeout
	_scrubbing = true
	for y in [330.0, 380.0, 430.0]:
		for x in range(480, 900, 12):
			_wash_at(Vector2(x, y), 0.1)
	_wash_at(Vector2(640, 380), 0.1)
	print("coverage ", model.scrub_coverage())


func _finish_wash() -> void:
	_scrubbing = false
	_drone.idle()
	build.grime = 0.0
	build.erase("clean")
	GameState.add_xp("craft", 8)
	GameState.save()
	Sfx.play("success")
	Router.toast("Squeaky clean.  Craft +8")
	_rebuild()


# ---------------------------------------------------------------- tune

func _tune_tab() -> void:
	if not build.has("tuning"):
		build["tuning"] = {}
	for knob in Content.parts.tuning:
		var spec: Dictionary = Content.parts.tuning[knob]
		_content.add_child(UI.heading(spec.label, 19))
		var slider := HSlider.new()
		slider.min_value = -1
		slider.max_value = 1
		slider.step = 0.05
		slider.value = build.tuning.get(knob, 0.0)
		slider.custom_minimum_size.x = 340
		slider.value_changed.connect(func(v):
			build.tuning[knob] = v
			stats_panel.show_build(build))
		slider.drag_ended.connect(func(_c):
			model.flash()
			GameState.save())
		_content.add_child(slider)
		_content.add_child(UI.hbox([UI.label(spec.low, 15, UI.MUTED), UI.spacer(), UI.label(spec.high, 15, UI.MUTED)]))
	_say("Grander cups will cap race rating. The club race doesn't.", 15, UI.MUTED)


# ---------------------------------------------------------------- mischief

func _mischief_tab() -> void:
	var pilot: Dictionary = stats_panel.pilot
	_say("Nobody gets hurt and everything can be fixed later. But %s will notice, and the dock will talk." % pilot.short,
		16, UI.MUTED)
	if not build.has("mischief"):
		build["mischief"] = []
	for kind in ["prank", "sabotage"]:
		_content.add_child(UI.heading("Pranks" if kind == "prank" else "Sabotage", 19))
		for id in Content.parts.mischief:
			var m: Dictionary = Content.parts.mischief[id]
			if m.kind != kind:
				continue
			var on: bool = id in build.mischief
			var b := UI.button(("✓ " if on else "") + m.name, _toggle_mischief.bind(id), 16)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_content.add_child(b)
			var line := UI.label(m.desc, 14, UI.MUTED, true)
			line.custom_minimum_size.x = 300
			_content.add_child(line)


func _toggle_mischief(id: String) -> void:
	if id in build.mischief:
		build.mischief.erase(id)
	else:
		build.mischief.append(id)
		Sfx.play("tick", 0.6)
	GameState.save()
	_rebuild()


func _rebuild() -> void:
	model.build(build)
	model.flash()
	stats_panel.show_build(build)
	_select(_tab)


func _finish() -> void:
	if not commission:
		Router.go("shop")
		return
	var unfinished := _faults().filter(func(f): return not f.fixed).size()
	if unfinished > 0 and not _confirm_finish:
		_confirm_finish = true
		Router.toast("Something's still not fixed. Press again to hand over anyway.", UI.BAD)
		return
	Router.go("handoff")
