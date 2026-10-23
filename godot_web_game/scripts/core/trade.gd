## The dock economy: prices that drift day to day, market events that push one kind of part up or
## down for a few days, worn parts, and what a whole ship is worth to a buyer. All seeded from the
## run, so a day's prices are the same however often you look.
class_name Trade
extends RefCounted


## Today's market event id, or "". Events last `event_days`, with a quiet spell between them.
static func event(run_seed: int, day: int, data: Dictionary) -> String:
	var span := int(data.event_days)
	var block := day / (span * 2)
	if day % (span * 2) >= span:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, block, "event"])
	var ids: Array = data.events.keys()
	return ids[rng.randi_range(0, ids.size() - 1)]


## How much today's price for `part_id` differs from list price: a small seeded drift, times the
## event's factor if one is on for this part's slot.
static func factor(run_seed: int, day: int, part_id: String, slot: String, data: Dictionary) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, day, part_id])
	var f := 1.0 + rng.randf_range(-1.0, 1.0) * float(data.drift)
	var ev := event(run_seed, day, data)
	if ev and data.events[ev].slot == slot:
		f *= float(data.events[ev].factor)
	return f


## What a buyer pays for a ship: its hull and fitted parts at resale, docked for every unfixed fault
## and for grime, with a bonus when its paint is to the buyer's taste.
static func ship_value(build: Dictionary, parts: Dictionary, taste: Array) -> int:
	var value := float(parts.hulls[build.hull].value)
	for slot in build.parts:
		value += parts.parts[build.parts[slot]].price * 0.6
	var broken: int = build.get("faults", []).filter(func(f): return not f.get("fixed", false)).size()
	value *= pow(0.7, broken)
	value *= 1.0 - 0.25 * float(build.get("grime", 0.0))
	if build.paint in taste:
		value *= 1.15
	return roundi(value / 5.0) * 5


## Which hawker parks outside today (one of `hawkers`, by id), or "".
static func hawker(run_seed: int, day: int, data: Dictionary, hawkers: Array) -> String:
	if day < int(data.hawker_from_day) or hawkers.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, day, "hawker"])
	return hawkers[rng.randi_range(0, hawkers.size() - 1)] if rng.randf() < float(data.hawker_chance) else ""


## A hawker's cart: four offers in their style ("worn", "mystery" or "fair"), and maybe a kind of
## part they're buying at a premium. Mystery crates decide their contents now, so a skilled ear can
## tell a good one from a dud before buying.
static func cart(run_seed: int, day: int, style: String, data: Dictionary, parts: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, day, "cart"])
	var kinds: Array = {"worn": ["worn", "worn", "part", "mystery"], "mystery": ["mystery", "mystery", "mystery", "trinket"],
		"fair": ["part", "part", "trinket", "worn"]}[style]
	var sellable: Array = parts.parts.keys().filter(func(id): return parts.parts[id].price > 0)
	var offers: Array = []
	for kind in kinds:
		var part: String = sellable[rng.randi_range(0, sellable.size() - 1)]
		var list: float = parts.parts[part].price
		match kind:
			"worn":
				offers.append({"kind": "worn", "part": part, "price": roundi(list * float(data.worn_value) * rng.randf_range(0.9, 1.3))})
			"part":
				offers.append({"kind": "part", "part": part, "price": roundi(list * rng.randf_range(0.7, 0.85))})
			"trinket":
				offers.append({"kind": "trinket", "trinket": _any(rng, data.trinkets.keys()), "price": rng.randi_range(25, 60)})
			"mystery":
				var roll := rng.randf()
				var tier := "trinket" if roll < 0.15 else ("good" if roll < 0.45 else "junk")
				var contents: String = _any(rng, data.trinkets.keys()) if tier == "trinket" else part
				offers.append({"kind": "mystery", "tier": tier, "contents": contents, "price": rng.randi_range(35, 75)})
	var wanted := ""
	if style == "fair" or rng.randf() < 0.5:
		wanted = _any(rng, ["engine", "fins", "cockpit", "lights"])
	return {"offers": offers, "wanted": wanted}


static func _any(rng: RandomNumberGenerator, from: Array) -> Variant:
	return from[rng.randi_range(0, from.size() - 1)]
