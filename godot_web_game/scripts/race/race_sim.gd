## Arcade race physics in track space, separate from rendering so it can run headless in tests.
##
## Each racer has distance `s` along the track (counting up across laps), lateral offset `d`
## (positive is left), speed `v` and heading `psi` relative to the track. The track bending under
## a racer turns `psi` away, so holding a line through a corner takes steering, and how hard a
## ship can turn at speed comes from its handling and grip.
class_name RaceSim
extends RefCounted

const COUNTDOWN := 3.0
const DRAG := 3.0
const BRAKE := 26.0
const WALL_SLOW := 0.72
const DRIFT_TURN := 1.55
const DRIFT_CHARGE := 0.9
const MINI_BOOST := 0.9
const ASSIST := 0.9
const RIBBON_LENGTH := 70.0
const RIBBON_TIME := 7.0
const SHIELD_TIME := 5.0
const GADGET_COOLDOWN := 12.0

var track: Track
var laps: int
var racers: Array[Dictionary] = []
var ribbons: Array[Dictionary] = []
var time := -COUNTDOWN
var events: Array[Dictionary] = []


func _init(t: Track, lap_count: int) -> void:
	track = t
	laps = lap_count


## `skill` 0..1 scales how close an AI drives to its ship's limit; the player has no skill value.
## `perks` are summed perk effects (boost_capacity, boost_power, drift_charge, wall_grace,
## gadget_cooldown), used for the player's ship.
func add_racer(id: String, stats: Dictionary, gadget: String, ai: bool, skill := 1.0, perks := {}) -> Dictionary:
	var grid := racers.size()
	var r := {
		"id": id, "ai": ai, "skill": skill, "m": ShipStats.handling_model(stats),
		"s": -6.0 - grid * 9.0, "d": [3.0, -3.0, 0.0, 6.0][grid % 4], "v": 0.0, "psi": 0.0,
		"steer": 0.0, "boost": 0.0, "boosting": false, "drift": false, "charge": 0.0, "mini": 0.0,
		"gadget": gadget, "cooldown": 3.0, "shield": 0.0, "finish": -1.0, "bump": 0.0,
		"drift_need": DRIFT_CHARGE * (1.0 - perks.get("drift_charge", 0.0)),
		"wall_slow": 0.93 if perks.get("wall_grace", 0.0) > 0 else WALL_SLOW,
		"gadget_time": GADGET_COOLDOWN * (1.0 - perks.get("gadget_cooldown", 0.0)),
	}
	r.m.boost_capacity += perks.get("boost_capacity", 0.0)
	r.m.boost_power += perks.get("boost_power", 0.0)
	r.boost = r.m.boost_capacity
	racers.append(r)
	return r


func finished() -> bool:
	return racers.all(func(r): return r.finish >= 0)


func lap_of(r: Dictionary) -> int:
	return clampi(int(floor(r.s / track.length)) + 1, 1, laps)


## Racers ordered by progress; finished racers by finish time.
func standings() -> Array:
	var order := racers.duplicate()
	order.sort_custom(func(a, b):
		if a.finish >= 0 and b.finish >= 0:
			return a.finish < b.finish
		if a.finish >= 0 or b.finish >= 0:
			return a.finish >= 0
		return a.s > b.s)
	return order


func place_of(r: Dictionary) -> int:
	return standings().find(r) + 1


## Input keys: steer (-1 right .. 1 left), throttle, brake, drift, boost, gadget (bools).
func step(dt: float, player_input: Dictionary) -> void:
	events.clear()
	time += dt
	if time < 0:
		return
	for r in racers:
		if r.finish >= 0:
			_coast(r, dt)
			continue
		var input := _ai_input(r) if r.ai else player_input
		_drive(r, input, dt)
		if r.s >= track.length * laps:
			r.finish = time
			events.append({"type": "finish", "id": r.id})
	_collide()
	for rb in ribbons:
		rb.life -= dt
	ribbons = ribbons.filter(func(rb): return rb.life > 0)


func _drive(r: Dictionary, input: Dictionary, dt: float) -> void:
	var m: Dictionary = r.m
	var top: float = m.top_speed
	var accel: float = m.accel
	r.mini = maxf(r.mini - dt, 0.0)
	r.shield = maxf(r.shield - dt, 0.0)
	r.cooldown = maxf(r.cooldown - dt, 0.0)
	r.bump = maxf(r.bump - dt, 0.0)

	r.boosting = input.get("boost", false) and r.boost > 0.0
	if r.boosting:
		r.boost = maxf(r.boost - dt, 0.0)
		top *= m.boost_power
		accel *= 1.8
	else:
		r.boost = minf(r.boost + dt * 0.18, m.boost_capacity)
	if r.mini > 0:
		top *= 1.22
		accel *= 1.6
	if _on_ribbon(r):
		top *= 1.3
		accel *= 1.5

	if input.get("throttle", false) or r.boosting:
		r.v += accel * maxf(1.0 - r.v / top, -0.6) * dt
	else:
		r.v = maxf(r.v - DRAG * dt, 0.0)
	if input.get("brake", false):
		r.v = maxf(r.v - BRAKE * dt, 0.0)

	var steer: float = clampf(input.get("steer", 0.0), -1.0, 1.0)
	r.steer = lerpf(r.steer, steer, minf(dt * 10.0, 1.0))
	var was_drifting: bool = r.drift
	r.drift = input.get("drift", false) and absf(steer) > 0.3 and r.v > 12.0
	var authority := clampf(m.grip_speed / maxf(r.v, 1.0), 0.4, 1.0)
	var turn: float = r.steer * m.turn_rate * authority
	if r.drift:
		turn *= DRIFT_TURN
		r.v *= 1.0 - 0.12 * dt
		r.charge += dt * absf(steer)
	elif was_drifting:
		if r.charge >= r.drift_need:
			r.mini = MINI_BOOST
			events.append({"type": "miniboost", "id": r.id})
		r.charge = 0.0
	if absf(steer) < 0.05:
		r.psi -= r.psi * ASSIST * dt

	var ds: float = r.v * cos(r.psi) * dt
	r.psi += turn * dt - track.kappa(r.s) * ds
	r.psi = clampf(r.psi, -1.1, 1.1)
	r.s += ds
	r.d += r.v * sin(r.psi) * dt

	var limit := track.half_width - 1.2
	if absf(r.d) > limit:
		r.d = signf(r.d) * limit
		r.psi *= -0.3
		if r.shield <= 0 and r.bump <= 0:
			r.v *= r.wall_slow
			r.bump = 0.4
			events.append({"type": "wall", "id": r.id})

	if input.get("gadget", false) and r.gadget != "" and r.cooldown <= 0:
		_use_gadget(r)


func _coast(r: Dictionary, dt: float) -> void:
	r.v = maxf(r.v - DRAG * 2 * dt, 8.0)
	r.s += r.v * dt
	r.psi = lerpf(r.psi, 0.0, dt * 2)


func _use_gadget(r: Dictionary) -> void:
	r.cooldown = r.gadget_time
	match r.gadget:
		"ribbon":
			ribbons.append({"from": r.s + 4.0, "to": r.s + 4.0 + RIBBON_LENGTH, "d": r.d, "life": RIBBON_TIME})
		"bubble":
			r.shield = SHIELD_TIME
	events.append({"type": "gadget", "id": r.id, "gadget": r.gadget})


func _on_ribbon(r: Dictionary) -> bool:
	for rb in ribbons:
		if r.s >= rb.from and r.s <= rb.to and absf(r.d - rb.d) < 2.5:
			return true
	return false


func _collide() -> void:
	for i in racers.size():
		for j in range(i + 1, racers.size()):
			var a: Dictionary = racers[i]
			var b: Dictionary = racers[j]
			if absf(a.s - b.s) > 4.0 or absf(a.d - b.d) > 2.4:
				continue
			var push := (2.4 - absf(a.d - b.d)) * 0.5
			var dir := signf(a.d - b.d) if a.d != b.d else 1.0
			a.d += dir * push * (0.2 if a.shield > 0 else 1.0)
			b.d -= dir * push * (0.2 if b.shield > 0 else 1.0)
			var behind: Dictionary = a if a.s < b.s else b
			if behind.shield <= 0:
				behind.v *= 0.97


## A simple driver: aim for the inside of the coming bend, brake for what the ship can hold,
## boost on straights and use the gadget when it's ready.
func _ai_input(r: Dictionary) -> Dictionary:
	var look: float = 14.0 + r.v * 0.9
	var k_far := track.kappa(r.s + look)
	var k_mid := track.kappa(r.s + look * 0.5)
	var k := k_far if absf(k_far) > absf(k_mid) else k_mid
	var target_d := clampf(k * 700.0, -6.5, 6.5) + sin(r.s * 0.01 + r.skill * 9.0) * 1.5
	var want_psi := atan2(target_d - r.d, 16.0 + r.v * 0.5)
	var steer := clampf((want_psi - r.psi) * 3.0 + track.kappa(r.s) * r.v * 0.6, -1.0, 1.0)
	var hold: float = r.m.turn_rate * r.m.grip_speed
	var corner := sqrt(hold / maxf(absf(k), 0.0004)) * lerpf(0.72, 0.97, r.skill)
	var cap: float = r.m.top_speed * lerpf(0.7, 1.0, r.skill)
	var target_v := minf(corner, cap)
	var straight := absf(k) < 0.004 and absf(track.kappa(r.s + look * 2)) < 0.004
	return {
		"steer": steer, "throttle": r.v < target_v, "brake": r.v > target_v * 1.12,
		"boost": straight and r.boost > r.m.boost_capacity * 0.5 and r.skill > 0.5,
		"drift": false, "gadget": r.cooldown <= 0 and straight,
	}
