## Dent pulling: tap the dent's rings from the outside in. Tapping an inner ring before the outer
## ones are out stretches the metal and costs quality; skill and perks need fewer taps per ring.
extends Minigame

const RINGS := 4
const RING_STEP := 34.0
const TAPS := 3

var _center := Vector2(380, 165)
var _depth: Array[float] = []
var _mistakes := 0
var _ripples: Array = []
var _seed := 0


func setup(spot: int) -> void:
	_seed = spot


func title() -> String:
	return "Pull the dent"


func instructions() -> String:
	return "Tap around the dent, working from the outermost ring inward. Tapping the middle too early stretches the metal."


func _ready() -> void:
	super()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 7727 + 3
	_center = Vector2(rng.randf_range(300, 460), rng.randf_range(140, 190))
	for i in RINGS:
		_depth.append(1.0)
	status("Start at the outside edge.")


func _taps_per_ring() -> int:
	return maxi(TAPS - int((leniency - 1.0) / 0.25), 1)


func _process(delta: float) -> void:
	for r in _ripples:
		r.t += delta
	_ripples = _ripples.filter(func(r): return r.t < 0.5)
	area.queue_redraw()


func _area_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var dist: float = event.position.distance_to(_center)
	var ring := RINGS - 1 - int(dist / RING_STEP)
	if ring < 0 or ring >= RINGS:
		return
	_ripples.append({"at": event.position, "t": 0.0})
	var outer := _outermost()
	# A fingertip landing just inside the ring being worked meant that ring.
	if UI.touch and ring == outer + 1 and (RINGS - 1 - outer) * RING_STEP - dist < RING_STEP * 0.4:
		ring = outer
	if ring == outer:
		_depth[ring] = maxf(_depth[ring] - 1.0 / _taps_per_ring(), 0.0)
		Sfx.play("tick", 0.7 + ring * 0.15)
		status("Good. The metal's easing out." if _depth[ring] > 0 else "That ring's smooth.")
		if _outermost() < 0:
			finish(clampf(1.0 - _mistakes * 0.12 + (leniency - 1.0) * 0.2, 0.35, 1.0))
	elif ring > outer:
		_mistakes += 1
		Sfx.play("bonk")
		status("Too far in! Work the outside first.")
	else:
		status("That part's already smooth.")


## Index of the outermost ring still dented (ring 0 is outermost), or -1 when done.
func _outermost() -> int:
	for i in RINGS:
		if _depth[i] > 0:
			return i
	return -1


func _draw_area() -> void:
	area.draw_style_box(UI.box(Color("c8643f"), 14, 0), Rect2(Vector2.ZERO, area.size))
	area.draw_style_box(UI.box(Color("d9805a"), 12, 0), Rect2(Vector2(6, 6), area.size - Vector2(12, 18)))
	for i in RINGS:
		var radius := (RINGS - i) * RING_STEP
		var shade := Color("d9805a").darkened(0.12 + 0.1 * i * _depth[i]) if _depth[i] > 0 else Color("d9805a")
		area.draw_circle(_center, radius, shade)
		area.draw_arc(_center, radius, 0, TAU, 48, Color(0, 0, 0, 0.12 * _depth[i]), 2.0)
	var outer := _outermost()
	if outer >= 0:
		area.draw_arc(_center, (RINGS - outer) * RING_STEP - RING_STEP * 0.5, 0, TAU, 48,
			Color(1, 0.9, 0.6, 0.35 + 0.15 * sin(Time.get_ticks_msec() / 200.0)), RING_STEP * 0.8)
	for r in _ripples:
		area.draw_arc(r.at, 8 + r.t * 50, 0, TAU, 24, Color(1, 1, 1, 0.6 * (1 - r.t / 0.5)), 3.0)
