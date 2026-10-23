## Run: godot --headless --path godot_web_game --script res://tests/run_tests.gd
extends SceneTree

var _failures := 0
var parts_data: Dictionary
var world: Dictionary
var perks_data: Dictionary


func _init() -> void:
	parts_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/parts.json"))
	world = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	perks_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/perks.json"))
	test_pronoun_tokens()
	test_dialogue_runner_follows_choices_flags_and_commands()
	test_shipped_dialogue_parses()
	test_faults_and_gear_change_stats()
	test_odessa_job_grades()
	test_skill_levels()
	test_content_matches_kit()
	test_club_race_finishes_cleanly_and_upgrades_pay_off()
	test_new_jobs_reward_tuning_and_finishes()
	test_mischief_costs_rapport_and_sabotage_costs_the_tip()
	test_perks_become_pending_and_add_up()
	test_beats_and_jobs_point_at_real_dialogue()
	print("FAILED: %d" % _failures if _failures else "all tests passed")
	quit(1 if _failures else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		push_error(msg)


func test_pronoun_tokens() -> void:
	var line := "{They} said {they} {was|were} {their} own boss, {name}."
	var cases := [
		["she", "She said she was her own boss, Sam."],
		["they", "They said they were their own boss, Sam."],
		[{"they": "xe", "them": "xem", "their": "xyr", "theirs": "xyrs", "themself": "xemself", "plural": false},
			"Xe said xe was xyr own boss, Sam."],
	]
	for c in cases:
		var got := Pronouns.fill(line, "Sam", Pronouns.resolve(c[0]))
		check(got == c[1], "pronouns %s: %s" % [c[0], got])


func test_dialogue_runner_follows_choices_flags_and_commands() -> void:
	var scenes := Dialogue.parse("""
== s
odessa happy: Hi {name}.
> A => a
> B => b
-- a
? met => skip
* not met
-- skip
! give cake 2
end
-- b
you: B line
""")
	var commands := []
	var flags := {"met": true}
	var r := Dialogue.Runner.new(scenes.s, func(c, a): commands.append([c, a]), func(f): return flags.has(f))
	var first := r.step()
	check(first.who == "odessa" and first.expr == "happy", "speaker and expression: %s" % first)
	var choice := r.step()
	check(choice.t == "choice" and choice.options.size() == 2, "consecutive options merge: %s" % choice)
	r.choose(0)
	check(r.step().t == "end", "flag jump skips narration")
	check(commands == [["give", ["cake", "2"]]], "commands reach the handler: %s" % [commands])

	var r2 := Dialogue.Runner.new(scenes.s, func(_c, _a): pass, func(_f): return false)
	r2.step()
	r2.step()
	r2.choose(1)
	check(r2.step().text == "B line", "second option jumps to its label")


func test_shipped_dialogue_parses() -> void:
	for file in DirAccess.get_files_at("res://data/dialogue"):
		var scenes := Dialogue.parse(FileAccess.get_file_as_string("res://data/dialogue/" + file))
		check(scenes.size() > 0, "%s has scenes" % file)
	var scenes := Dialogue.parse(FileAccess.get_file_as_string("res://data/dialogue/day1.txt"))
	for tier in ["delighted", "pleased", "lukewarm"]:
		check(scenes.has("odessa_1_" + tier), "handoff scene for " + tier)


func test_faults_and_gear_change_stats() -> void:
	var moth: Dictionary = world.ships.pocket_moth.duplicate(true)
	var stock := ShipStats.compute(moth, parts_data)
	moth.faults = [{"type": "weld", "fixed": false}, {"type": "calibrate", "fixed": false}]
	var broken := ShipStats.compute(moth, parts_data)
	check(broken.noise == stock.noise + 22, "faults add noise: %s vs %s" % [broken.noise, stock.noise])
	moth.tuning = {"gear": 1.0}
	var geared := ShipStats.compute(moth, parts_data)
	check(geared.top_speed > broken.top_speed and geared.thrust < broken.thrust, "gear trades thrust for speed")


func test_odessa_job_grades() -> void:
	var job: Dictionary = world.jobs.odessa_1
	var pilot: Dictionary = world.pilots.odessa
	var before: Dictionary = world.ships.pocket_moth.duplicate(true)
	before.faults = [{"type": "weld", "fixed": false}, {"type": "calibrate", "fixed": false}]

	var untouched := Grading.grade(job, pilot, before, before, {}, parts_data)
	check(untouched.tier == "lukewarm", "doing nothing is lukewarm: %s" % untouched.tier)

	var fixed := before.duplicate(true)
	for f in fixed.faults:
		f.fixed = true
	fixed.parts.engine = "engine_hush"
	fixed.paint = "marigold"
	var best := Grading.grade(job, pilot, before, fixed, {0: 0.9, 1: 0.9}, parts_data)
	check(best.tier == "delighted", "repairs plus Hushdrive plus her colors delight: %s" % best)
	check(best.wants.all(func(w): return w.met), "every want met")
	check(best.parts_cost == 140 and best.gift == 0, "Hushdrive fits the budget: %s" % best.parts_cost)
	check(best.pay == 220 + 55, "delighted pilots tip a quarter: %s" % best.pay)

	fixed.parts.cockpit = "cockpit_bay"
	var generous := Grading.grade(job, pilot, before, fixed, {0: 0.9, 1: 0.9}, parts_data)
	check(generous.gift == 30 and generous.rapport == best.rapport + 1, "over budget is a noticed gift")


func test_skill_levels() -> void:
	check(Skills.level(0) == 1 and Skills.level(59) == 1 and Skills.level(60) == 2, "level thresholds")
	check(is_equal_approx(Skills.progress(105), 0.5), "progress within a level: %s" % Skills.progress(105))
	check(Skills.leniency(60, 0.35) > Skills.leniency(0, 0.0), "skill and tea both ease minigames")


func test_content_matches_kit() -> void:
	var kit: Node = load("res://assets/ships/kit.glb").instantiate()
	for id in parts_data.hulls:
		var hull: Node = kit.get_node_or_null("hull_" + id)
		check(hull != null, "hull %s is in the kit" % id)
		for socket in ["engine", "fin_l", "fin_r", "cockpit", "lights", "top"]:
			check(hull.has_node("hull_%s__socket_%s" % [id, socket]), "hull %s has a %s socket" % [id, socket])
		for spot in range(1, 7):
			check(hull.has_node("hull_%s__spot_%d" % [id, spot]), "hull %s has spot %d" % [id, spot])
	for id in parts_data.parts:
		var model: String = parts_data.parts[id].model
		check(kit.has_node(model), "part %s has kit model %s" % [id, model])
	for id in world.ships:
		var ship: Dictionary = world.ships[id]
		var hull: Node = kit.get_node_or_null("hull_" + ship.hull)
		check(hull != null, "ship %s hull %s in kit" % [id, ship.hull])
		for slot in ship.parts:
			check(parts_data.parts[ship.parts[slot]].slot == slot, "%s fits %s in the right slot" % [id, slot])
	for id in world.jobs:
		var job: Dictionary = world.jobs[id]
		var hull: Node = kit.get_node("hull_" + world.ships[job.ship].hull)
		for f in job.faults:
			check(hull.has_node("%s__spot_%d" % [hull.name, f.spot]), "job %s spot %d exists" % [id, f.spot])
	kit.free()


func _club_race(kettle: Dictionary) -> Dictionary:
	var race: Dictionary = world.race.club
	var sim := RaceSim.new(Track.quietwater(), race.laps)
	var entries := [["kettle", kettle, 0.92]]
	for pilot in race.rivals:
		entries.append([pilot, world.ships[world.pilots[pilot].ship], race.rivals[pilot]])
	for e in entries:
		sim.add_racer(e[0], ShipStats.compute(e[1], parts_data), ShipStats.gadget(e[1], parts_data), true, e[2])
	var walls := 0
	while not sim.finished() and sim.time < 400:
		sim.step(1.0 / 60.0, {})
		walls += sim.events.filter(func(ev): return ev.type == "wall").size()
	var times := {}
	for r in sim.racers:
		times[r.id] = r.finish
	return {"times": times, "walls": walls, "finished": sim.finished()}


func test_club_race_finishes_cleanly_and_upgrades_pay_off() -> void:
	var stock: Dictionary = world.ships.kettle
	var tuned := stock.duplicate(true)
	tuned.parts.merge({"engine": "engine_sprint", "fins": "fin_wing", "cockpit": "cockpit_visor"}, true)
	var a := _club_race(stock)
	var b := _club_race(tuned)
	check(a.finished and b.finished, "every racer finishes the club race")
	check(a.walls == 0 and b.walls == 0, "AI drivers stay off the walls: %d, %d" % [a.walls, b.walls])
	check(b.times.kettle < a.times.kettle - 5.0, "upgrades make the Kettle faster: %.1f vs %.1f" % [b.times.kettle,
		a.times.kettle])
	check(b.times.kettle < b.times.brindle, "a racing build beats Brindle's tug")


func _fixed(ship_id: String, job: Dictionary) -> Array:
	var before: Dictionary = world.ships[ship_id].duplicate(true)
	before.faults = job.faults.map(func(f): return {"type": f.type, "spot": f.spot, "fixed": false})
	var after := before.duplicate(true)
	for f in after.faults:
		f.fixed = true
	return [before, after]


func test_empty_boost_stays_off_until_it_refills() -> void:
	var sim := RaceSim.new(Track.quietwater(), 2)
	var r := sim.add_racer("p", ShipStats.compute(world.ships.kettle, parts_data), "", false)
	var held := {"throttle": true, "boost": true, "steer": 0.0}
	while sim.time < 0:
		sim.step(1.0 / 60.0, {})
	while r.boost > 0:
		sim.step(1.0 / 60.0, held)
	var relit := 0
	for i in 60:
		sim.step(1.0 / 60.0, held)
		relit += int(r.boosting)
	check(relit == 0, "holding boost on an empty tank doesn't boost: %d frames" % relit)


func test_new_jobs_reward_tuning_and_finishes() -> void:
	var repairs := {0: 0.85, 1: 0.85}
	var bj: Dictionary = world.jobs.brindle_1
	var b := _fixed("bucket", bj)
	var plain := Grading.grade(bj, world.pilots.brindle, b[0], b[1], repairs, parts_data)
	check(plain.tier != "delighted", "Brindle's tug needs more than repairs: %s" % plain.tier)
	b[1].tuning = {"damping": -1.0, "fins": 0.3}
	var grimy := Grading.grade(bj, world.pilots.brindle, b[0], b[1], repairs, parts_data)
	check(grimy.tier != "delighted", "grime still drags on the tuned tug's handling")
	b[1].grime = 0.0
	var tuned := Grading.grade(bj, world.pilots.brindle, b[0], b[1], repairs, parts_data)
	check(tuned.tier == "delighted", "tuned and washed, the tug delights Brindle: %s" % [tuned.wants])

	var cj: Dictionary = world.jobs.crake_1
	var c := _fixed("magnificence", cj)
	c[1].tuning = {"gear": 0.6}
	var no_pearl := Grading.grade(cj, world.pilots.crake, c[0], c[1], repairs, parts_data)
	check(not no_pearl.wants[1].met, "gloss isn't pearl")
	c[1].finish = "pearl"
	var best := Grading.grade(cj, world.pilots.crake, c[0], c[1], repairs, parts_data)
	check(best.tier == "delighted", "fast and pearl delights Crake: %s" % [best.wants])
	var haggled := cj.duplicate()
	haggled.budget = 160
	check(Grading.grade(haggled, world.pilots.crake, c[0], c[1], repairs, parts_data).pay == 200,
		"a haggled budget pays less, tip included")


func test_mischief_costs_rapport_and_sabotage_costs_the_tip() -> void:
	var job: Dictionary = world.jobs.crake_1
	var c := _fixed("magnificence", job)
	c[1].tuning = {"gear": 0.6}
	c[1].finish = "pearl"
	var repairs := {0: 0.9, 1: 0.9}
	var clean := Grading.grade(job, world.pilots.crake, c[0], c[1], repairs, parts_data)
	c[1].mischief = ["goose_horn"]
	var prank := Grading.grade(job, world.pilots.crake, c[0], c[1], repairs, parts_data)
	check(prank.mischief == "prank" and prank.rapport == clean.rapport - 1, "a prank costs a little rapport")
	check(prank.pay == clean.pay and prank.reputation == 0, "pranks keep the tip and the reputation")
	c[1].mischief = ["goose_horn", "foam"]
	var sab := Grading.grade(job, world.pilots.crake, c[0], c[1], repairs, parts_data)
	check(sab.mischief == "sabotage" and sab.pay == job.budget and sab.reputation == -1,
		"sabotage loses the tip and some reputation: %s" % sab)
	var forgiven := Grading.grade(job, world.pilots.crake, c[0], c[1], repairs, parts_data,
		{"mischief_forgiven": 1})
	check(forgiven.reputation == 0, "Word of mouth softens the gossip")


func test_perks_become_pending_and_add_up() -> void:
	var xp := {"mechanics": 160, "electronics": 0, "diagnostics": 70, "craft": 0, "piloting": 0}
	var pending := Perks.pending(xp, [], perks_data)
	check(pending.size() == 3, "mechanics 2 and 3 plus diagnostics 2 are pending: %s" % [pending])
	check(Perks.pending(xp, ["steady_torch", "salvager", "warm_hands"], perks_data).is_empty(), "choosing clears them")
	check(is_equal_approx(Perks.value(["trickle_charge", "second_wind"], "spark_max", perks_data), 2.0),
		"effects from different skills add up")
	for skill in perks_data.perks:
		for lvl in perks_data.perks[skill]:
			check(perks_data.perks[skill][lvl].size() == 2, "%s level %s offers two perks" % [skill, lvl])


func test_beats_and_jobs_point_at_real_dialogue() -> void:
	var scenes := {}
	for file in DirAccess.get_files_at("res://data/dialogue"):
		scenes.merge(Dialogue.parse(FileAccess.get_file_as_string("res://data/dialogue/" + file)))
	for beat in world.beats:
		check(scenes.has(beat.scene), "beat scene %s exists" % beat.scene)
	for id in world.jobs:
		for tier in ["delighted", "pleased", "lukewarm"]:
			check(scenes.has("%s_%s" % [world.jobs[id].dialogue, tier]), "%s has a %s scene" % [id, tier])
	for kind in ["prank", "sabotage"]:
		check(scenes.has("mischief_" + kind), "generic %s reaction exists" % kind)
