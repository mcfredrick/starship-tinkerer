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
