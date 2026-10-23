## Storylets: short hand-written arcs that attach to a generated customer and unfold over their
## visit. Each beat waits for a hook ("arrive", "handoff", "morning") and plays one dialogue scene.
## A story's state is {id, beat, flags, day}; its scenes set flags with "! story <flag>" and test
## them with "? <flag> => label", and the handoff records the grade as a "tier_<tier>" flag.
class_name Storylets
extends RefCounted

## How often a new walk-in arrives with a story attached.
const CHANCE := 0.6


## A storylet for `pilot`, or "" if they don't get one. Prefers stories written for one of their
## traits, and skips ones already running with someone else.
static func pick(rng: RandomNumberGenerator, pilot: Dictionary, data: Dictionary, running: Array) -> String:
	if rng.randf() >= CHANCE:
		return ""
	var fits: Array = []
	var any: Array = []
	for id in data:
		if id in running:
			continue
		var wanted: Array = data[id].traits
		if wanted.is_empty():
			any.append(id)
		elif pilot.traits.any(func(t): return t in wanted):
			fits.append(id)
	var pool := fits if fits else any
	return pool[rng.randi_range(0, pool.size() - 1)] if pool else ""


static func start(id: String, day: int) -> Dictionary:
	return {"id": id, "beat": 0, "flags": {}, "day": day}


## The scene a story plays at `hook` today, or "". Morning beats wait for a new day after the
## story last moved, so a customer drops by the day after the handoff, not the same evening.
static func scene_at(story: Dictionary, hook: String, day: int, data: Dictionary) -> String:
	var beats: Array = data[story.id].beats
	if story.beat >= beats.size():
		return ""
	var beat: Dictionary = beats[story.beat]
	if beat.hook != hook or (hook == "morning" and day <= story.day):
		return ""
	return beat.scene


static func advance(story: Dictionary, day: int) -> void:
	story.beat += 1
	story.day = day


static func finished(story: Dictionary, data: Dictionary) -> bool:
	return story.beat >= data[story.id].beats.size()
