## The workbench: scan for faults, repair them, swap parts, paint and tune.
## Works on the commission ship (with the pilot's wants) or on your own Kettle (with tuning).
extends Screen

const SCAN_RADIUS := 90.0
const WARM_RADIUS := 220.0
const SCAN_TIME := 1.4
const TASKS := {"weld": "weld", "calibrate": "calibrate"}

var ship_id: String
var commission := false
var build: Dictionary
var model: ShipModel
var stats_panel: StatsPanel
var _tab := ""
var _tabs: HBoxContainer
var _content: VBoxContainer
var _overlay: Control
var _markers := {}
var _scan := {}
var _painted := false
var _confirm_finish := false
var _open_repair := -1


func setup(params: Dictionary) -> void:
	var job_ship: String = Content.world.jobs[GameState.job.id].ship if not GameState.job.is_empty() else "kettle"
	ship_id = params.get("ship", job_ship)
	_open_repair = int(params.get("repair", "-1"))


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
	commission = not GameState.job.is_empty() and Content.world.jobs[GameState.job.id].ship == ship_id
	model = show_ship(ship_id)

	_overlay = UI.full(Control.new())
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	ui.add_child(_overlay)
	ui.add_child(Hud.new())

	_tabs = UI.hbox([], 6)
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
		var job: Dictionary = Content.world.jobs[GameState.job.id]
		stats_panel.wants = job.wants
		stats_panel.pilot = Content.world.pilots[job.pilot]
	UI.place(stats_panel, Control.PRESET_TOP_RIGHT, Vector2(-346, 84), Vector2(330, 0))
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

	var names := ["Scan", "Repair", "Parts", "Paint"] if commission else ["Parts", "Paint", "Tune"]
	for n in names:
		var b := UI.button(n, _select.bind(n), 18)
		b.toggle_mode = true
		b.name = n
		_tabs.add_child(b)
	stats_panel.show_build.call_deferred(build)
	_select(names[0])
	if _open_repair >= 0:
		_repair.call_deferred(_open_repair)


func _faults() -> Array:
	return build.get("faults", [])


func _select(tab: String) -> void:
	_tab = tab
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
		"Tune":
			_tune_tab()


func _say(text: String, size := 19, color := UI.INK) -> Label:
	var l := UI.label(text, size, color, true)
	l.custom_minimum_size.x = 360
	_content.add_child(l)
	return l


# ---------------------------------------------------------------- scan

func _scan_tab() -> void:
	var job: Dictionary = Content.world.jobs[GameState.job.id]
	_say("\"%s\"" % job.request, 17, UI.MUTED)
	_say("Sweep the scanner slowly over the hull. Faults glow warm as you get close. Drag empty space to turn the view.")
	var found := _faults().filter(func(f): return f.found).size()
	_say("Faults found: %d" % found, 22, UI.TEAL)


func _process(delta: float) -> void:
	_position_markers()
	if _tab == "Scan":
		_update_scan(delta)
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
				GameState.add_xp("diagnostics", 12)
				GameState.save()
				Router.toast("Found it: %s.  Diagnostics +12" % Content.parts.faults[f.type].name)
				_select(_tab)


func _draw_overlay() -> void:
	if _tab != "Scan":
		return
	var mouse := ui.get_local_mouse_position()
	for i in _faults().size():
		var f: Dictionary = _faults()[i]
		if f.found:
			continue
		var s := _screen_spot(f)
		var d: float = mouse.distance_to(s[0])
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
		m.position = s[0] - Vector2(20, 20)
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
		var name: String = Content.parts.faults[f.type].name
		if f.fixed:
			_say("✓  %s  (quality %d%%)" % [name, roundi(f.score * 100)], 19, UI.GOOD)
		else:
			_content.add_child(UI.button("Repair: " + name, _repair.bind(i), 19))
	if found < _faults().size():
		_say("The scan isn't finished. Something else may be off.", 18, UI.MUTED)
	_say("Each repair takes a little spark.", 16, UI.MUTED)


func _repair(i: int) -> void:
	var f: Dictionary = _faults()[i]
	if f.fixed:
		return
	if GameState.spark <= 0:
		Router.toast("You're out of spark. Time for tea and cake.", UI.BAD)
		return
	var spec: Dictionary = Content.parts.faults[f.type]
	var game: Minigame = load("res://scripts/minigames/%s.gd" % spec.minigame).new()
	game.setup(f.spot)
	game.leniency = GameState.leniency(spec.skill, TASKS[spec.minigame])
	game.theme = Router.theme
	game.finished.connect(_on_repaired.bind(i))
	ui.add_child(game)
	GameState.spark -= 1
	GameState.save()


func _on_repaired(score: float, i: int) -> void:
	var f: Dictionary = _faults()[i]
	var spec: Dictionary = Content.parts.faults[f.type]
	f.fixed = true
	f.score = score
	Sfx.play("success")
	var xp := 10 + roundi(20 * score)
	GameState.add_xp(spec.skill, xp)
	GameState.save()
	Router.toast("%s fixed.  %s +%d" % [spec.name, Skills.LABELS[spec.skill], xp])
	_rebuild()


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
			var text := "%s  ·  %s" % [Content.part(id).name, "on your shelf" if owned > 0 else UI.pebs(Content.part(id).price)]
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
		var price: int = Content.part(id).price
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
	_rebuild()


func _remove(slot: String) -> void:
	GameState.give(GameState.parts, build.parts[slot])
	build.parts.erase(slot)
	GameState.save()
	_rebuild()


# ---------------------------------------------------------------- paint

func _paint_tab() -> void:
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
			var c := Content.color(name)
			var chosen: bool = build[zone] == name
			for state in ["normal", "hover", "pressed", "focus"]:
				var box := UI.box(c.lightened(0.15) if state == "hover" else c, 10, 0, false,
					UI.INK if chosen else c.darkened(0.25))
				b.add_theme_stylebox_override(state, box)
			b.pressed.connect(_paint.bind(zone, name))
			grid.add_child(b)
		_content.add_child(grid)


func _paint(zone: String, color: String) -> void:
	build[zone] = color
	if not _painted:
		_painted = true
		GameState.add_xp("craft", 6)
	GameState.save()
	_rebuild()


# ---------------------------------------------------------------- tune

func _tune_tab() -> void:
	_say("Gear ratio trades punch off the line for top speed.")
	var slider := HSlider.new()
	slider.min_value = -1
	slider.max_value = 1
	slider.step = 0.1
	slider.value = build.get("tuning", {}).get("gear", 0.0)
	slider.custom_minimum_size.x = 340
	slider.value_changed.connect(func(v):
		build["tuning"] = {"gear": v}
		model.flash()
		stats_panel.show_build(build))
	slider.drag_ended.connect(func(_c): GameState.save())
	_content.add_child(slider)
	_content.add_child(UI.hbox([UI.label("Punchy", 16, UI.MUTED), UI.spacer(), UI.label("Fast", 16, UI.MUTED)]))
	_say("The club race has no rating cap, but grander cups will.", 16, UI.MUTED)


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
