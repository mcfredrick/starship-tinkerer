## Rewiring: drag each frayed lead to the terminal of the same color before the capacitor drains.
## Running dry pauses things while it gently recharges, which costs a little quality; skill and
## perks slow the drain.
extends Minigame

const COLORS := [Color("e8a33d"), Color("3f8f8f"), Color("e48aa0"), Color("8fae7e"), Color("6b5a9e")]
const LEAD_X := 90.0
const TERM_X := 640.0
const DRAIN := 16.0
const RECHARGE := 2.5

var _leads: Array = []
var _terms: Array = []
var _done_leads := {}
var _dragging := -1
var _cursor := Vector2.ZERO
var _charge := 1.0
var _recharging := 0.0
var _mistakes := 0
var _dry := 0
var _seed := 0
var _flash := {}


func setup(spot: int) -> void:
	_seed = spot


func title() -> String:
	return "Rewire the frayed harness"


func instructions() -> String:
	return "Drag each lead on the left to the terminal of the same color. Finish before the capacitor drains."


func _ready() -> void:
	super()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 31337 + 5
	var count := 4 if leniency < 1.3 else 3
	var order := range(count)
	var targets := range(count)
	_shuffle(order, rng)
	_shuffle(targets, rng)
	for i in count:
		_leads.append({"color": order[i], "pos": Vector2(LEAD_X, 40 + i * 200.0 / maxf(count - 1, 1))})
		_terms.append({"color": targets[i], "pos": Vector2(TERM_X, 40 + i * 200.0 / maxf(count - 1, 1))})
	status("Capacitor holding.")


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _process(delta: float) -> void:
	if _recharging > 0:
		_recharging -= delta
		_charge = minf(_charge + delta / RECHARGE, 1.0)
		if _recharging <= 0:
			status("Charged again. Carry on.")
	else:
		_charge -= delta / (DRAIN * leniency)
		if _charge <= 0:
			_charge = 0
			_dry += 1
			_recharging = RECHARGE
			_dragging = -1
			status("The capacitor ran dry. Let it recharge a moment.")
	for k in _flash.keys():
		_flash[k] -= delta
		if _flash[k] <= 0:
			_flash.erase(k)
	area.queue_redraw()


func _area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _recharging <= 0:
			for i in _leads.size():
				if i not in _done_leads and event.position.distance_to(_leads[i].pos) < 30 * UI.reach():
					_dragging = i
		elif not event.pressed and _dragging >= 0:
			_drop(event.position)
			_dragging = -1
		_cursor = event.position
	elif event is InputEventMouseMotion:
		_cursor = event.position


func _drop(at: Vector2) -> void:
	for t in _terms:
		if at.distance_to(t.pos) < 34 * UI.reach():
			if t.color == _leads[_dragging].color:
				_done_leads[_dragging] = true
				Sfx.play("tick", 1.4)
				status("Connected.")
				if _done_leads.size() == _leads.size():
					var score := 1.0 - _mistakes * 0.1 - _dry * 0.15 + (leniency - 1.0) * 0.2
					finish(clampf(score, 0.35, 1.0))
			else:
				_mistakes += 1
				_flash[t.pos] = 0.4
				Sfx.play("bonk")
				status("Zap! Wrong terminal.")
			return


func _draw_area() -> void:
	area.draw_style_box(UI.box(Color("3b3542"), 16, 0), Rect2(Vector2.ZERO, area.size))
	for i in _terms.size():
		var t: Dictionary = _terms[i]
		var c: Color = COLORS[t.color]
		var flash: bool = _flash.has(t.pos)
		area.draw_circle(t.pos, 24, Color("c9a24b") if not flash else Color("ffffff"))
		area.draw_circle(t.pos, 16, c)
	for i in _leads.size():
		var l: Dictionary = _leads[i]
		var c: Color = COLORS[l.color]
		var end: Vector2 = _cursor if i == _dragging else l.pos + Vector2(40, 0)
		if i in _done_leads:
			end = _terms.filter(func(t): return t.color == l.color)[0].pos
		var mid: Vector2 = (l.pos + end) / 2 + Vector2(0, 40)
		var pts := PackedVector2Array()
		for k in 17:
			var u := k / 16.0
			pts.append(l.pos.lerp(mid, u).lerp(mid.lerp(end, u), u))
		area.draw_polyline(pts, c.darkened(0.3), 9.0, true)
		area.draw_polyline(pts, c, 6.0, true)
		if i not in _done_leads and i != _dragging:
			for f in 3:
				area.draw_line(end, end + Vector2(8, -6 + f * 6), c.lightened(0.3), 2.0)
		area.draw_circle(l.pos, 14, Color("5b5262"))
	var bar := Rect2(170, area.size.y - 30, 420, 16)
	area.draw_style_box(UI.box(Color(1, 1, 1, 0.15), 8, 0), bar)
	var fill := bar
	fill.size.x *= _charge
	area.draw_style_box(UI.box(Color("9fffd0") if _recharging <= 0 else Color("e8a33d"), 8, 0), fill)
	area.draw_string(UI.body_font, Vector2(170, area.size.y - 38), "CAPACITOR", HORIZONTAL_ALIGNMENT_LEFT, -1,
		14, Color(1, 1, 1, 0.6))
