## Ready-made game states for screenshots and manual testing (`--fixture=name`).
class_name Fixtures
extends RefCounted


static func apply(name: String) -> void:
	GameState.new_game("Sam", "they")
	match name:
		"fresh":
			pass
		"job":
			GameState.flags.intro_seen = true
			GameState.start_job("odessa_1")
		"scanned":
			GameState.flags.intro_seen = true
			GameState.start_job("odessa_1")
			for f in _job_faults():
				f.found = true
		"evening":
			GameState.flags.intro_seen = true
			GameState.flags.odessa_1_done = true
			GameState.flags.odessa_1_quiet = true
			GameState.flags.racers_visited = true
			GameState.flags.race_open = true
			GameState.phase = "evening"
			GameState.give(GameState.items, "cake_seed", 2)
		"day2":
			GameState.flags.intro_seen = true
			GameState.flags.odessa_1_done = true
			GameState.flags.odessa_1_quiet = true
			GameState.flags.racers_visited = true
			GameState.flags.race_open = true
			GameState.end_day()
		_:
			assert(false, "unknown fixture " + name)
	GameState.save()


static func _job_faults() -> Array:
	return GameState.ships[Content.world.jobs[GameState.job.id].ship].faults
