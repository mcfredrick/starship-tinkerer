## How the dock's characters (and pets) get on with each other. Each pair has a bond score; some
## mornings chance moves a few of them, leaning warmer when you're close to both people, and scenes
## move them with "! bond a b n". Strong bonds and frosty ones set flags scenes can check:
## bond_<a>_<b>_close and bond_<a>_<b>_cold. `data` is bonds.json.
class_name Bonds
extends RefCounted

const MIN := -3
const MAX := 5


static func value(bonds: Dictionary, pair: String, data: Dictionary) -> int:
	return int(bonds.get(pair, data.pairs[pair].start))


## The pair key for two names in either order, or "" if they aren't a pair.
static func pair(a: String, b: String, data: Dictionary) -> String:
	for key in ["%s|%s" % [a, b], "%s|%s" % [b, a]]:
		if data.pairs.has(key):
			return key
	return ""


static func shift(bonds: Dictionary, pair: String, delta: int, data: Dictionary) -> void:
	bonds[pair] = clampi(value(bonds, pair, data) + delta, MIN, MAX)


## This morning's moments: for each pair whose characters have met (their `after` flag is set),
## sometimes a nudge up or down with a line of gossip. Warmer odds when your rapport with both is
## high. Changes `bonds` and returns [{pair, delta, line}].
static func morning(rng: RandomNumberGenerator, bonds: Dictionary, rapport: Dictionary, flags: Dictionary,
		data: Dictionary) -> Array:
	var moments: Array = []
	for key in data.pairs:
		var spec: Dictionary = data.pairs[key]
		if not flags.has(spec.after) or rng.randf() >= float(data.chance):
			continue
		var names: PackedStringArray = key.split("|")
		var warmth := int(rapport.get(names[0], 0)) + int(rapport.get(names[1], 0))
		var up_odds := clampf(0.5 + 0.04 * warmth, 0.25, 0.85)
		var delta := 1 if rng.randf() < up_odds else -1
		shift(bonds, key, delta, data)
		var lines: Array = spec.up if delta > 0 else spec.down
		moments.append({"pair": key, "delta": delta, "line": lines[rng.randi_range(0, lines.size() - 1)]})
	return moments


## The close and cold flags every pair's current score implies.
static func flags_for(bonds: Dictionary, data: Dictionary) -> Dictionary:
	var out := {}
	for key in data.pairs:
		var name: String = "bond_" + key.replace("|", "_")
		var v := value(bonds, key, data)
		out[name + "_close"] = v >= int(data.close)
		out[name + "_cold"] = v <= int(data.cold)
	return out


## A phrase for how a pair gets on: "thick as thieves" down to "frosty".
static func describe(v: int, data: Dictionary) -> String:
	for level in data.levels:
		if v >= int(level[0]):
			return level[1]
	return data.levels[-1][1]
