## Generated walk-in customers and their jobs, from a seeded RNG so a run's seed always produces
## the same dock. Every line of prose comes from hand-written pieces in walkins.json; generation
## only picks and combines them.
##
## Jobs are solvable by construction. The generator imagines a "dream build" (market parts and
## tuning) and sets each wanted stat a little short of what that build reaches, choosing only
## stats the dream actually improves over the repaired stock ship.
class_name Walkins
extends RefCounted

const SLOTS := ["engine", "fins", "cockpit", "lights"]
## Wants sit this far between the repaired ship and the dream build, so there's slack.
const REACH := 0.75
## A stat only becomes a want if the dream build moves it at least this much.
const MIN_GAIN := 6.0


static func customer(rng: RandomNumberGenerator, id: String, w: Dictionary, palette: Array) -> Dictionary:
	var species_id: String = _pick(rng, w.species.keys())
	var sp: Dictionary = w.species[species_id]
	var given: String = _pick(rng, sp.given)
	var name := given if rng.randf() < 0.4 else "%s %s" % [given, _pick(rng, sp.family)]
	var traits: Array = _sample(rng, w.traits.keys(), 2)
	var colors: Array = _pick(rng, sp.palettes)
	var extras: Array = _sample(rng, sp.look.extras, rng.randi_range(1, sp.look.extras.size()))
	var taste: Array = _sample(rng, palette, 3)
	return {
		"id": id, "name": name, "short": given, "species": species_id, "pronouns": _pick(rng, w.pronouns),
		"traits": traits, "taste": taste, "generated": true,
		"taste_hint": "%s keeps mentioning %s and %s." % [given, taste[0], taste[1]],
		"blurb": "%s, %s and %s." % [sp.name, w.traits[traits[0]].label.to_lower(), w.traits[traits[1]].label.to_lower()],
		"look": {"head": _pick(rng, sp.look.head), "eyes": int(_pick(rng, sp.look.eyes)), "extras": extras,
			"outfit": _pick(rng, w.outfits), "skin": colors[0], "outfit_color": colors[1], "accent": colors[2]},
	}


## A job for `pilot` on ship `ship_id`: a new ship, or `existing` (a regular's) with fresh trouble.
## `level` (0 and up) makes faults more numerous and more serious as the shop grows.
## Returns {job, ship, dream}.
static func job(rng: RandomNumberGenerator, pilot: Dictionary, ship_id: String, level: int, w: Dictionary,
		data: Dictionary, market: Array, existing := {}) -> Dictionary:
	var ship := _ship(rng, w, data)
	if existing:
		ship = existing.duplicate(true)
		for key in ["faults", "grime", "clean", "mischief"]:
			ship.erase(key)
	var faults := _faults(rng, w, level)
	var stock := ship.duplicate(true)
	var stock_stats := ShipStats.compute(stock, data)

	var dream := {}
	var dream_stats := {}
	var gains := {}
	for attempt in 12:
		dream = _dream(rng, stock, data, market)
		dream_stats = ShipStats.compute(dream, data)
		gains = {}
		for want_id in w.wants:
			var spec: Dictionary = w.wants[want_id]
			var gain: float = dream_stats[spec.stat] - stock_stats[spec.stat]
			if spec.dir == "max":
				gain = -gain
			if gain >= MIN_GAIN:
				gains[want_id] = gain
		if gains.size() >= 2:
			break

	var trait_ids: Array = pilot.traits
	var count := 2 if "fussy" in trait_ids else 1
	count = mini(count + int(rng.randf() < 0.4), gains.size())
	var wants: Array = []
	var asks: Array = []
	for want_id in _sample(rng, gains.keys(), count):
		var spec: Dictionary = w.wants[want_id]
		var base: float = stock_stats[spec.stat]
		var step: float = gains[want_id] * REACH
		var want := {"stat": spec.stat, "label": _pick(rng, spec.labels), "weight": 1}
		if spec.dir == "max":
			want["max"] = ceili(base - step)
		else:
			want["min"] = floori(base + step)
		wants.append(want)
		asks.append(_pick(rng, spec.ask))
	wants.append({"taste": true, "label": "In %s's colors" % pilot.short, "weight": 1})
	if rng.randf() < 0.3:
		wants.append({"clean": true, "label": "Spotless", "weight": 1})

	var steps := 0
	for f in faults:
		steps += data.faults[f.type].steps.size()
	var mult := 1.0
	for t in trait_ids:
		mult *= w.traits[t].budget
	var cost := Grading.parts_cost(stock, dream, data)
	var budget := maxi(roundi((cost + 25 * steps + 15 * wants.size()) * mult / 10.0) * 10, 60)

	ship["faults"] = faults
	ship["grime"] = snappedf(rng.randf_range(0.2, 0.85), 0.05)
	var opener: String = _pick(rng, w.openers[trait_ids[0]])
	var spec := {
		"pilot": pilot.id, "ship": ship_id, "budget": budget, "faults": faults, "wants": wants,
		"request": " ".join([opener] + asks), "barter": {}, "dialogue": "walkin",
	}
	if rng.randf() < 0.35:
		spec.barter[_pick(rng, w.barter)] = 1
	return {"job": spec, "ship": ship, "dream": dream}


## Back-to-front [layer name, tint] pairs for a generated look's portrait (see blender/dolls.py).
static func doll_layers(look: Dictionary, expr: String) -> Array:
	var accent := Color(look.accent)
	var out: Array = [["body_" + look.outfit, Color(look.outfit_color)], ["trim_" + look.outfit, accent]]
	for x in look.extras:
		if x != "stache":
			out.append(["extra_%s_%s" % [x, look.head], accent])
	out.append(["head_" + look.head, Color(look.skin)])
	if "stache" in look.extras:
		out.append(["stache", accent])
	out.append(["eyes_%d_%s" % [look.eyes, expr], Color.WHITE])
	out.append(["mouth_" + expr, Color.WHITE])
	return out


static func _ship(rng: RandomNumberGenerator, w: Dictionary, data: Dictionary) -> Dictionary:
	var parts := {}
	for slot in SLOTS:
		var options: Array = data.parts.keys().filter(func(id): return data.parts[id].slot == slot)
		parts[slot] = _pick(rng, options)
	var palette: Array = data.palette.keys()
	var paint: String = _pick(rng, palette)
	var trim: String = _pick(rng, palette.filter(func(c): return c != paint))
	return {
		"name": "%s %s" % [_pick(rng, w.ship_names.first), _pick(rng, w.ship_names.second)], "hull": _pick(rng, w.hulls), "parts": parts, "paint": paint, "trim": trim,
		"livery": _pick(rng, w.liveries), "finish": _pick(rng, w.finishes),
	}


static func _faults(rng: RandomNumberGenerator, w: Dictionary, level: int) -> Array:
	var count := clampi(1 + level / 3 + int(rng.randf() < 0.5), 1, 3)
	var spots: Array = _sample(rng, [1, 2, 3, 4, 5, 6], count)
	var faults: Array = []
	for spot in spots:
		var major := rng.randf() < 0.15 + level * 0.08
		faults.append({"type": _pick(rng, w.faults.major if major else w.faults.minor), "spot": spot})
	return faults


static func _dream(rng: RandomNumberGenerator, stock: Dictionary, data: Dictionary, market: Array) -> Dictionary:
	var dream := stock.duplicate(true)
	for slot in SLOTS:
		var options: Array = market.filter(func(id): return data.parts[id].slot == slot)
		if options and rng.randf() < 0.7:
			dream.parts[slot] = _pick(rng, options)
	dream["tuning"] = {}
	for knob in data.tuning:
		dream.tuning[knob] = snappedf(rng.randf_range(-1.0, 1.0), 0.25)
	return dream


static func _pick(rng: RandomNumberGenerator, from: Array) -> Variant:
	return from[rng.randi_range(0, from.size() - 1)]


static func _sample(rng: RandomNumberGenerator, from: Array, count: int) -> Array:
	var pool := from.duplicate()
	var out: Array = []
	for i in mini(count, pool.size()):
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out
