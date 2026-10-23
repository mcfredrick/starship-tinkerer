## Ready-made game states for screenshots and manual testing (`--fixture=name`).
class_name Fixtures
extends RefCounted


static func apply(name: String) -> void:
	GameState.new_game("Sam", "they")
	match name:
		"fresh":
			pass
		"job":
			GameState.flags.seen_intro = true
			GameState.flags.seen_odessa_arrives = true
			GameState.start_job("odessa_1")
		"scanned":
			GameState.flags.seen_intro = true
			GameState.flags.seen_odessa_arrives = true
			GameState.start_job("odessa_1")
			for f in _job_faults():
				f.found = true
		"finished":
			GameState.flags.seen_intro = true
			GameState.flags.seen_odessa_arrives = true
			GameState.start_job("odessa_1")
			for f in _job_faults():
				f.found = true
				f.fixed = true
				f.score = 0.85
			var moth: Dictionary = GameState.ships.pocket_moth
			GameState.take(GameState.parts, "engine_hush")
			GameState.give(GameState.parts, moth.parts.engine)
			moth.parts.engine = "engine_hush"
			moth.paint = "marigold"
		"brindle", "crake", "midway":
			for f in ["seen_intro", "seen_odessa_arrives", "odessa_1_done", "seen_racers_visit", "race_open",
					"seen_day2_morning", "knows_pearl"]:
				GameState.flags[f] = true
			var who := "crake" if name == "midway" else name
			GameState.day = 2 if who == "brindle" else 3
			GameState.flags["seen_%s_arrives" % who] = true
			GameState.start_job(who + "_1")
			for f in _job_faults():
				f.found = true
				# Midway: every fault has its first step done, for the in-between hull states.
				if name == "midway":
					f.step = 1
					f.scores = [0.8]
		"levelup":
			GameState.flags.seen_intro = true
			GameState.phase = "evening"
			GameState.skills.mechanics = 70
			GameState.skills.diagnostics = 65
			GameState.today.xp = {"mechanics": 70, "diagnostics": 65}
		"evening":
			GameState.flags.seen_intro = true
			GameState.flags.odessa_1_done = true
			GameState.flags.odessa_1_quiet = true
			GameState.flags.seen_odessa_arrives = true
			GameState.flags.seen_racers_visit = true
			GameState.flags.race_open = true
			GameState.phase = "evening"
			GameState.give(GameState.items, "cake_seed", 2)
		"day2":
			GameState.flags.seen_intro = true
			GameState.flags.odessa_1_done = true
			GameState.flags.odessa_1_quiet = true
			GameState.flags.seen_odessa_arrives = true
			GameState.flags.seen_racers_visit = true
			GameState.flags.race_open = true
			GameState.end_day()
		_:
			assert(false, "unknown fixture " + name)
	GameState.save()


static func _job_faults() -> Array:
	return GameState.ships[Content.world.jobs[GameState.job.id].ship].faults
