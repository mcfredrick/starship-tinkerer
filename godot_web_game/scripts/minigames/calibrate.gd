## Drive timing calibration: turn the frequency and phase dials until your waveform sits on the
## target and hold it there until it locks. Skill and Drift Bloom tea widen the lock window.
extends Minigame

const SCOPE := Rect2(20, 10, 470, 300)
const DIALS := [Vector2(590, 110), Vector2(590, 250)]
const DIAL_R := 48.0
const FREQ_RANGE := Vector2(1.0, 5.0)
const TOLERANCE := 0.1
const LOCK_TIME := 1.2

var _target := Vector2.ZERO
var _value := Vector2.ZERO
var _lock := 0.0
var _elapsed := 0.0
var _dragging := -1
var _best_error := INF
var _seed := 0


func setup(spot: int) -> void:
	_seed = spot


func title() -> String:
	return "Calibrate the drive timing"


func instructions() -> String:
	return "Drag the dials up and down (or scroll over them) until the green wave sits on the gold one, then hold steady."


func _ready() -> void:
	super()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 104729 + 7
	_target = Vector2(rng.randf_range(2.2, 4.2), rng.randf_range(0.5, TAU - 0.5))
	_value = Vector2(rng.randf_range(1.2, 1.8), _target.y + PI)
	status("The drive's out of step. Bring it back in.")


func _error() -> float:
	var df := absf(_value.x - _target.x) / (FREQ_RANGE.y - FREQ_RANGE.x)
	var dp := absf(angle_difference(_value.y, _target.y)) / PI
	return df * 2.0 + dp


func _process(delta: float) -> void:
	_elapsed += delta
	var err := _error()
	_best_error = minf(_best_error, err)
	if err < TOLERANCE * leniency:
		_lock += delta / LOCK_TIME
		status("Holding... %d%%" % roundi(_lock * 100))
		if _lock >= 1.0:
			var precision := 1.0 - clampf(err / (TOLERANCE * leniency), 0, 1) * 0.35
			var pace := clampf(1.15 - _elapsed / 70.0, 0.7, 1.0)
			set_process(false)
			finish(clampf(precision * pace * (1.0 + (leniency - 1.0) * 0.3), 0, 1))
	else:
		_lock = maxf(_lock - delta, 0)
		status("Close!" if err < TOLERANCE * leniency * 2.5 else "Out of step.")
	area.queue_redraw()


func _area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var dial := _dial_at(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = dial if event.pressed else -1
		elif event.pressed and dial >= 0 and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_turn(dial, 6.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -6.0)
	elif event is InputEventMouseMotion and _dragging >= 0:
		_turn(_dragging, -event.relative.y)


func _dial_at(p: Vector2) -> int:
	for i in DIALS.size():
		if p.distance_to(DIALS[i]) < DIAL_R * 1.4:
			return i
	return -1


func _turn(dial: int, amount: float) -> void:
	if randf() < absf(amount) * 0.08:
		Sfx.play("tick", randf_range(0.9, 1.2))
	if dial == 0:
		_value.x = clampf(_value.x + amount * 0.012, FREQ_RANGE.x, FREQ_RANGE.y)
	else:
		_value.y = wrapf(_value.y + amount * 0.025, 0, TAU)


func _wave(freq: float, phase: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 121:
		var u := float(i) / 120
		pts.append(SCOPE.position + Vector2(u * SCOPE.size.x,
			SCOPE.size.y * 0.5 - sin(u * TAU * freq + phase) * SCOPE.size.y * 0.36))
	return pts


func _draw_area() -> void:
	area.draw_style_box(UI.box(Color("16343a"), 16, 0), SCOPE.grow(6))
	for i in range(1, 8):
		var x := SCOPE.position.x + SCOPE.size.x * i / 8.0
		area.draw_line(Vector2(x, SCOPE.position.y), Vector2(x, SCOPE.end.y), Color(0.4, 0.8, 0.8, 0.12))
	for i in range(1, 4):
		var y := SCOPE.position.y + SCOPE.size.y * i / 4.0
		area.draw_line(Vector2(SCOPE.position.x, y), Vector2(SCOPE.end.x, y), Color(0.4, 0.8, 0.8, 0.12))
	area.draw_polyline(_wave(_target.x, _target.y), Color(1.0, 0.8, 0.35, 0.8), 4.0, true)
	var locked := _lock > 0
	area.draw_polyline(_wave(_value.x, _value.y), Color("9fffd0") if locked else Color("6fdcae"),
		5.0 if locked else 3.0, true)
	area.draw_rect(Rect2(SCOPE.position.x, SCOPE.end.y - 8, SCOPE.size.x * _lock, 6), Color("ffd27a"))

	var names := ["FREQ", "PHASE"]
	var angles := [remap(_value.x, FREQ_RANGE.x, FREQ_RANGE.y, -2.4, 2.4), _value.y]
	for i in DIALS.size():
		var c: Vector2 = DIALS[i]
		area.draw_circle(c + Vector2(0, 4), DIAL_R, Color(0, 0, 0, 0.2))
		area.draw_circle(c, DIAL_R, Color("c9a24b"))
		area.draw_circle(c, DIAL_R - 8, Color("e6c573"))
		var tip: Vector2 = c + Vector2(sin(angles[i]), -cos(angles[i])) * (DIAL_R - 14)
		area.draw_line(c, tip, Color("4a3428"), 6.0)
		area.draw_circle(tip, 5, Color("4a3428"))
		area.draw_string(UI.heading_font, c + Vector2(-34, DIAL_R + 26), names[i], HORIZONTAL_ALIGNMENT_CENTER, 68, 18,
			UI.INK)
