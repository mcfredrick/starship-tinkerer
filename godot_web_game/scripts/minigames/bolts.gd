## Unbolting an access panel: circle each bolt counterclockwise until it backs out. Cranking too fast
## makes the wrench slip, which costs a little progress and some quality; skill eases the limit.
extends Minigame

const TURNS := 2.0
const SLIP_SPEED := 9.0
const GRAB := 70.0

var _bolts: Array = []
var _active := -1
var _last_angle := 0.0
var _last_time := 0.0
var _slips := 0
var _wrong_way := 0.0
var _seed := 0


func setup(spot: int) -> void:
	_seed = spot


func title() -> String:
	return "Open the access panel"


func instructions() -> String:
	return "Press on a bolt and circle it counterclockwise to back it out. Steady turns; crank too fast and the wrench slips."


func _ready() -> void:
	super()
	var count := 4 if leniency < 1.3 else 3
	var corners := [Vector2(170, 75), Vector2(590, 75), Vector2(590, 255), Vector2(170, 255)]
	for i in count:
		_bolts.append({"pos": corners[i], "turned": 0.0, "out": false})
	status("Pick a bolt.")


func _process(_delta: float) -> void:
	area.queue_redraw()


func _area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_active = -1
		if event.pressed:
			for i in _bolts.size():
				var b: Dictionary = _bolts[i]
				if not b.out and event.position.distance_to(b.pos) < GRAB * UI.reach():
					_active = i
					_last_angle = (event.position - b.pos).angle()
					_last_time = Time.get_ticks_msec() / 1000.0
	elif event is InputEventMouseMotion and _active >= 0:
		_turn(event.position)


func _turn(at: Vector2) -> void:
	var b: Dictionary = _bolts[_active]
	if at.distance_to(b.pos) < 8:
		return
	var angle: float = (at - b.pos).angle()
	# Screen y points down, so a counterclockwise turn on screen lowers the angle.
	var step := -wrapf(angle - _last_angle, -PI, PI)
	var now := Time.get_ticks_msec() / 1000.0
	var speed := absf(step) / maxf(now - _last_time, 0.001)
	_last_angle = angle
	_last_time = now
	if step < 0:
		_wrong_way += -step
		if _wrong_way > PI:
			_wrong_way = 0.0
			status("Righty tighty! The other way.")
		return
	if speed > SLIP_SPEED * leniency:
		_slips += 1
		b.turned = maxf(b.turned - 0.3, 0.0)
		_active = -1
		Sfx.play("bonk", 1.3)
		status("The wrench slipped. Easy does it.")
		return
	b.turned += step / TAU
	if fmod(b.turned, 0.25) < fmod(b.turned - step / TAU, 0.25):
		Sfx.play("tick", 0.8 + b.turned * 0.2)
	status("Turning...")
	if b.turned >= TURNS:
		b.out = true
		_active = -1
		Sfx.play("ping", 1.2)
		status("One out.")
		if _bolts.all(func(x): return x.out):
			finish(clampf(1.0 - _slips * 0.08 + (leniency - 1.0) * 0.2, 0.35, 1.0))


func _draw_area() -> void:
	area.draw_style_box(UI.box(Color("8e9298"), 14, 0), Rect2(Vector2.ZERO, area.size))
	area.draw_style_box(UI.box(Color("a7abb2"), 10, 0, false, Color("6e7177")), Rect2(Vector2(120, 30), Vector2(520, 270)))
	area.draw_string(UI.body_font, Vector2(330, 172), "ACCESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, 0.25))
	for i in _bolts.size():
		var b: Dictionary = _bolts[i]
		if b.out:
			area.draw_circle(b.pos, 12, Color("3b3d42"))
			continue
		var lift: float = b.turned / TURNS
		var r := 22.0 + lift * 6.0
		area.draw_circle(b.pos + Vector2(3, 4), r, Color(0, 0, 0, 0.25 * (1.0 + lift)))
		area.draw_circle(b.pos, r, Color("c9ccd4").lerp(Color("e8e9ee"), lift))
		var spin: float = b.turned * -TAU
		var hex := PackedVector2Array()
		for k in 7:
			hex.append(b.pos + Vector2.from_angle(spin + TAU * k / 6) * r * 0.62)
		area.draw_polyline(hex, Color("6e7177"), 3.0, true)
		if i == _active:
			area.draw_arc(b.pos, r + 14, 0, TAU, 32, Color(1.0, 0.85, 0.4, 0.8), 3.0)
			area.draw_arc(b.pos, r + 14, -PI / 2, -PI / 2 - TAU * fmod(b.turned, 1.0), 32, Color("ffd27a"), 6.0)
