## Skill perks: each new skill level offers a choice of two, and chosen perks add up into effect
## values the rest of the game reads (`value(chosen, "weld_leniency")`). `data` is perks.json.
class_name Perks
extends RefCounted


## Perk choices the player has earned but not made yet, oldest first: [{skill, level}].
static func pending(skill_xp: Dictionary, chosen: Array, data: Dictionary) -> Array:
	var out: Array = []
	for skill in Skills.NAMES:
		var tiers: Dictionary = data.perks.get(skill, {})
		for lvl in range(2, Skills.level(skill_xp.get(skill, 0)) + 1):
			var options: Array = tiers.get(str(lvl), [])
			if options.is_empty():
				continue
			if not options.any(func(o): return o.id in chosen):
				out.append({"skill": skill, "level": lvl})
	return out


static func options(skill: String, level: int, data: Dictionary) -> Array:
	return data.perks[skill][str(level)]


static func find(id: String, data: Dictionary) -> Dictionary:
	for skill in data.perks:
		for lvl in data.perks[skill]:
			for p in data.perks[skill][lvl]:
				if p.id == id:
					return p
	assert(false, "unknown perk " + id)
	return {}


static func value(chosen: Array, key: String, data: Dictionary) -> float:
	var total := 0.0
	for id in chosen:
		total += find(id, data).effects.get(key, 0.0)
	return total


## Every effect key summed, for code that takes a whole bundle (grading, races).
static func effects(chosen: Array, data: Dictionary) -> Dictionary:
	var out := {}
	for id in chosen:
		var fx: Dictionary = find(id, data).effects
		for k in fx:
			out[k] = out.get(k, 0.0) + fx[k]
	return out
