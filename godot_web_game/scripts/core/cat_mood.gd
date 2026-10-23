## Sprocket the shop cat's mood each morning. Affection (from petting and shared treats) makes
## helpful days likelier and mischief rarer; plenty of days Sprocket just naps.
class_name CatMood
extends RefCounted


## {event, mood} for today: event is "" on a nap day; mood is "sweet", "grumpy" or "sleepy".
static func pick(rng: RandomNumberGenerator, affection: int, data: Dictionary) -> Dictionary:
	var helpful := minf(0.25 + affection * 0.04, 0.6)
	var mischief := maxf(0.3 - affection * 0.025, 0.08)
	var r := rng.randf()
	if r < helpful:
		return {"event": _pick(rng, data.events.helpful), "mood": "sweet"}
	if r < helpful + mischief:
		return {"event": _pick(rng, data.events.mischief), "mood": "grumpy"}
	return {"event": "", "mood": "sleepy"}


static func _pick(rng: RandomNumberGenerator, from: Array) -> String:
	return from[rng.randi_range(0, from.size() - 1)]
