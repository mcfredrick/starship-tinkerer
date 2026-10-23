## Run: godot --headless --path godot_web_game --script res://tests/run_tests.gd
extends SceneTree

var _failures := 0
var parts_data: Dictionary
var world: Dictionary


func _init() -> void:
	parts_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/parts.json"))
	world = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	test_pronoun_tokens()
	test_dialogue_runner_follows_choices_flags_and_commands()
	test_shipped_dialogue_parses()
	test_faults_and_gear_change_stats()
	test_odessa_job_grades()
	test_skill_levels()
	test_content_matches_kit()
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
