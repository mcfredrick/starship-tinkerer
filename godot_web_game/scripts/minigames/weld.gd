## Seam welding: hold and trace a bead along a wavy seam. Staying on the line and keeping an even
## pace both count; skill and Steady Leaf tea widen the line and the comfortable pace.
extends Minigame

const STEPS := 140
const TOLERANCE := 16.0
const PACE := Vector2(110, 260)

var _path := PackedVector2Array()
var _lengths := PackedFloat32Array()
var _progress := 0.0
var _samples: Array[float] = []
var _bead: Array = []
var _holding := false
var _torch := Vector2.ZERO
var _last_time := 0.0
var _seed := 0
var _sizzle: AudioStreamPlayer


func setup(spot: int) -> void:
	_seed = spot


func title() -> String:
	return "Weld the cracked seam"


func instructions() -> String:
	return "Press on the glowing start and trace the seam to the end. Stay on the line at an even pace."


func _ready() -> void:
	super()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 7919 + 13
	var a := rng.randf_range(0.8, 1.6)
	var b := rng.randf_range(2.0, 3.4)
	var total := 0.0
	for i in STEPS + 1:
		var u := float(i) / STEPS
		var p := Vector2(50 + u * 660, 165 + sin(u * TAU * a) * 70 + sin(u * TAU * b + 1.0) * 28)
		if i > 0:
			total += p.distance_to(_path[i - 1])
		_path.append(p)
		_lengths.append(total)
	status("Ready when you are.")
	_sizzle = Sfx.loop("weld", self, -6.0)


func _tolerance() -> float:
	return TOLERANCE * leniency


func _process(_delta: float) -> void:
	area.queue_redraw()
	if _holding and not _sizzle.playing:
		_sizzle.play()
	elif not _holding and _sizzle.playing:
		_sizzle.stop()


func _area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_holding = event.pressed and event.position.distance_to(_point_at(_progress)) < _tolerance() * 2.5
		_torch = event.position
		_last_time = Time.get_ticks_msec() / 1000.0
		if event.pressed and not _holding:
			status("Start from the end of your bead, where the line glows.")
	elif event is InputEventMouseMotion and _holding:
		_torch = event.position
		_advance()


func _advance() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var dt := maxf(now - _last_time, 0.001)
	_last_time = now
	var best := -1
	var best_dist := INF
	for i in _path.size():
		if _lengths[i] < _progress - 10 or _lengths[i] > _progress + 70:
			continue
		var d := _torch.distance_to(_path[i])
		if d < best_dist:
			best_dist = d
			best = i
	if best < 0 or best_dist > _tolerance():
		status("Off the seam! Ease back onto the line.")
		return
	var gained := _lengths[best] - _progress
	if gained <= 0:
		return
	var speed := gained / dt
	var slack := (leniency - 1.0) * 80.0
	var steady := 1.0
	if speed < PACE.x - slack:
		steady = clampf(speed / (PACE.x - slack), 0.4, 1.0)
	elif speed > PACE.y + slack:
		steady = clampf((PACE.y + slack) / speed, 0.3, 1.0)
	var accurate := 1.0 - clampf(best_dist / _tolerance(), 0.0, 1.0) * 0.6
	var q := accurate * 0.6 + steady * 0.4
	_samples.append(q)
	_bead.append([_path[best], q])
	_progress = _lengths[best]
	status("Too slow, the metal's pooling." if steady < 0.8 and speed < PACE.x else
		("Too fast, the bead's thin." if steady < 0.8 else "Nice and even."))
	if _progress >= _lengths[-1] - 3:
		_holding = false
		var total := 0.0
		for s in _samples:
			total += s
		finish(clampf(total / _samples.size() * (1.0 + (leniency - 1.0) * 0.3), 0.0, 1.0))


func _point_at(length: float) -> Vector2:
	for i in _path.size():
		if _lengths[i] >= length:
			return _path[i]
	return _path[-1]


func _draw_area() -> void:
	area.draw_style_box(UI.box(Color("8e9298"), 14, 0), Rect2(Vector2.ZERO, area.size))
	area.draw_style_box(UI.box(Color("a3a7ad"), 12, 0), Rect2(Vector2(6, 6), area.size - Vector2(12, 18)))
	for x in [22, area.size.x - 22]:
		for y in [22, area.size.y - 26]:
			area.draw_circle(Vector2(x, y), 6, Color("6e7177"))
	area.draw_polyline(_path, Color("3b3d42"), 5.0, true)
	area.draw_polyline(_path, Color(1, 0.75, 0.4, 0.18), _tolerance() * 2, true)
	for b in _bead:
		var c: Color = Color("ffcf6b").lerp(Color("d0603a"), clampf(1.0 - b[1], 0, 1) * 1.6)
		area.draw_circle(b[0], 7, c.darkened(0.3))
		area.draw_circle(b[0], 5, c)
	var tip := _point_at(_progress)
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
	area.draw_circle(tip, 11 + pulse * 3, Color(1, 0.85, 0.4, 0.5))
	area.draw_circle(_path[-1], 8, Color("5f9e6e"))
	if _holding:
		area.draw_circle(_torch, 14, Color(0.6, 0.9, 1.0, 0.35))
		area.draw_circle(_torch, 6, Color(1, 1, 1, 0.9))
