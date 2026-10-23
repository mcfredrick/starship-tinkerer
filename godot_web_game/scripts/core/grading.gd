## Scores a finished commission on fit, quality and value, and works out the pilot's reaction.
class_name Grading
extends RefCounted

const TIERS := [
	{"min": 0.8, "tier": "delighted", "rapport": 3, "tip": 0.25},
	{"min": 0.55, "tier": "pleased", "rapport": 2, "tip": 0.0},
	{"min": 0.0, "tier": "lukewarm", "rapport": 1, "tip": 0.0},
]


## `before` and `after` are builds; `repairs` maps fault index to a minigame score 0..1.
static func grade(job: Dictionary, pilot: Dictionary, before: Dictionary, after: Dictionary, repairs: Dictionary,
		data: Dictionary) -> Dictionary:
	var stats := ShipStats.compute(after, data)
	var wants: Array = []
	var fit_total := 0.0
	var fit_weight := 0.0
	for w in job.wants:
		var met := _met(w, stats, after, pilot)
		wants.append({"label": w.label, "met": met})
		fit_weight += w.weight
		fit_total += w.weight if met else 0.0

	var quality := 0.0
	for i in job.faults.size():
		quality += repairs.get(i, 0.0)
	quality /= maxf(job.faults.size(), 1)

	var cost := parts_cost(before, after, data)
	var fit := fit_total / fit_weight
	var overall := fit * 0.6 + quality * 0.4
	var result: Dictionary = TIERS.filter(func(t): return overall >= t.min)[0].duplicate()
	result.merge({
		"fit": fit, "quality": quality, "overall": overall, "wants": wants, "parts_cost": cost,
		"gift": maxi(cost - job.budget, 0), "pay": job.budget + roundi(job.budget * result.tip),
	})
	# Going over budget is a gift the pilot notices.
	if result.gift > 0:
		result.rapport += 1
	return result


static func _met(want: Dictionary, stats: Dictionary, build: Dictionary, pilot: Dictionary) -> bool:
	if want.get("taste", false):
		return build.paint in pilot.taste
	var v: float = stats[want.stat]
	return (not want.has("max") or v <= want.max) and (not want.has("min") or v >= want.min)


## Market price of every part fitted after the job that wasn't there before.
static func parts_cost(before: Dictionary, after: Dictionary, data: Dictionary) -> int:
	var cost := 0
	for slot in after.parts:
		if before.parts.get(slot, "") != after.parts[slot]:
			cost += data.parts[after.parts[slot]].price
	return cost
