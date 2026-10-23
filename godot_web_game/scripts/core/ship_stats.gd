## Ship numbers: stats from hull, parts, faults and tuning, and the performance rating races cap.
##
## A build is a Dictionary: {hull, parts: {slot: part_id}, paint, trim, faults: [{type, spot, fixed}],
## tuning: {gear: -1..1}}. `data` is parts.json.
class_name ShipStats
extends RefCounted

const STATS := ["thrust", "top_speed", "handling", "grip", "boost", "mass", "comfort", "noise"]
const SLOTS := ["engine", "fins", "cockpit", "lights", "top"]
## Gear ratio trades acceleration for top speed.
const GEAR_SWING := 10.0


static func compute(build: Dictionary, data: Dictionary) -> Dictionary:
	var stats := {}
	var base: Dictionary = data.hulls[build.hull].stats
	for s in STATS:
		stats[s] = float(base.get(s, 0))
	stats["view"] = 0.0
	for slot in build.parts:
		_add(stats, data.parts[build.parts[slot]].stats)
	for f in build.get("faults", []):
		if not f.get("fixed", false):
			_add(stats, data.faults[f.type].stats)
	var gear: float = build.get("tuning", {}).get("gear", 0.0)
	stats.thrust -= gear * GEAR_SWING
	stats.top_speed += gear * GEAR_SWING
	for s in STATS:
		stats[s] = maxf(stats[s], 0.0)
	return stats


static func _add(stats: Dictionary, delta: Dictionary) -> void:
	for s in delta:
		stats[s] = stats.get(s, 0.0) + delta[s]


## One number for how fast a ship is, used for race classes. Mass counts against everything.
static func rating(stats: Dictionary) -> int:
	return roundi(stats.thrust + stats.top_speed + stats.handling + stats.grip + stats.boost - stats.mass * 0.5)


## The race gadget fitted in the top socket, or "".
static func gadget(build: Dictionary, data: Dictionary) -> String:
	var part: String = build.parts.get("top", "")
	return data.parts[part].get("gadget", "") if part else ""


## Racing physics derived from stats, in world units (meters, seconds, radians).
static func handling_model(stats: Dictionary) -> Dictionary:
	var mass_factor := 60.0 / maxf(stats.mass, 30.0)
	return {
		"top_speed": 22.0 + stats.top_speed * 0.32,
		"accel": (6.0 + stats.thrust * 0.22) * mass_factor,
		"turn_rate": 1.1 + stats.handling * 0.022,
		"grip_speed": 18.0 + stats.grip * 0.42,
		"boost_capacity": 1.5 + stats.boost * 0.05,
		"boost_power": 1.35,
	}
