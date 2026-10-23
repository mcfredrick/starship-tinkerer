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
			GameState.flags.seen_grommet_intro = true
			GameState.flags.seen_odessa_arrives = true
			GameState.start_job("odessa_1")
		"scanned":
			GameState.flags.seen_intro = true
			GameState.flags.seen_grommet_intro = true
			GameState.flags.seen_odessa_arrives = true
			GameState.start_job("odessa_1")
			for f in _job_faults():
				f.found = true
		"finished":
			GameState.flags.seen_intro = true
			GameState.flags.seen_grommet_intro = true
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
			for f in ["seen_intro", "seen_grommet_intro", "seen_odessa_arrives", "odessa_1_done", "seen_racers_visit", "race_open",
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
		"board", "walkin":
			# Day four: the cast's first jobs are done and walk-ins have started.
			for f in ["seen_intro", "seen_grommet_intro", "seen_odessa_arrives", "odessa_1_done", "seen_racers_visit", "race_open",
					"seen_day2_morning", "seen_brindle_arrives", "brindle_1_done", "seen_day3_morning",
					"seen_crake_arrives", "crake_1_done", "seen_day4_morning", "knows_pearl"]:
				GameState.flags[f] = true
			GameState.day = 4
			GameState.run_seed = 1234
			if name == "walkin":
				GameState.job_board()
				GameState.accept_offer(0)
				for f in _job_faults():
					f.found = true
		"hawker":
			# Day five, Fennimore's cart outside, and a good enough ear to judge the crates.
			for f in ["seen_intro", "seen_grommet_intro", "seen_day4_morning"]:
				GameState.flags[f] = true
			GameState.day = 5
			GameState.pebs = 400
			GameState.skills.diagnostics = 70
			GameState.worn = {"fin_swept": 1}
			GameState.hawker = {"day": 5, "id": "fennimore", "bought": [],
				"cart": Trade.cart(GameState.run_seed, 5, "mystery", Content.trade, Content.parts)}
		"yard":
			# Day five with money to spend and one junker already bought.
			for f in ["seen_intro", "seen_grommet_intro", "seen_day4_morning"]:
				GameState.flags[f] = true
			GameState.day = 5
			GameState.pebs = 900
			GameState.run_seed = 77
			GameState.buy_junker(GameState.yard()[0])
		"drawers":
			# A seasoned tinkerer: most drawers will open.
			for f in ["seen_intro", "seen_grommet_intro", "seen_day4_morning"]:
				GameState.flags[f] = true
			GameState.day = 8
			for s in Skills.NAMES:
				GameState.skills[s] = 130
			GameState.finds = {"brass_compass": true, "snow_globe": true}
			GameState.flags.drawer_bolts = true
		"close_pass":
			# Day eleven, every arc job done well, the dock ready to fly out.
			for f in ["seen_intro", "seen_grommet_intro", "seen_day4_morning", "seen_ilse_arrives", "ilse_1_done",
					"ilse_1_delighted", "seen_odessa_returns", "odessa_2_done", "odessa_roots", "seen_brindle_returns",
					"brindle_2_done", "seen_crake_returns", "crake_2_done", "crake_2_delighted", "seen_close_pass_eve",
					"race_open", "odessa_1_done", "brindle_1_done", "crake_1_done"]:
				GameState.flags[f] = true
			GameState.day = 11
		"levelup":
			GameState.flags.seen_intro = true
			GameState.flags.seen_grommet_intro = true
			GameState.phase = "evening"
			GameState.skills.mechanics = 70
			GameState.skills.diagnostics = 65
			GameState.today.xp = {"mechanics": 70, "diagnostics": 65}
		"evening":
			GameState.flags.seen_intro = true
			GameState.flags.seen_grommet_intro = true
			GameState.flags.odessa_1_done = true
			GameState.flags.odessa_1_quiet = true
			GameState.flags.seen_odessa_arrives = true
			GameState.flags.seen_racers_visit = true
			GameState.flags.race_open = true
			GameState.phase = "evening"
			GameState.give(GameState.items, "cake_seed", 2)
		"day2":
			GameState.flags.seen_intro = true
			GameState.flags.seen_grommet_intro = true
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
	return GameState.ships[GameState.job_spec(GameState.job.id).ship].faults
