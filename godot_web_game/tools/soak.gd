## Autoplay soak test: a bot plays several seeded runs of many days through the real game logic
## (GameState, the generators, grading and payout) and checks invariants every day. Runs as a scene
## because it needs the autoloads. Prints "SOAK FAILED" on any broken invariant, and a summary of
## each run's economy for balancing.
## Run: godot --headless res://tools/soak.tscn
extends Node

const SEEDS := [11, 22, 33]
const DAYS := 40

var _failures := 0


func _ready() -> void:
	GameState.save_path = "user://soak_save.json"
	for run_seed in SEEDS:
		_run(run_seed)
	print("SOAK FAILED: %d" % _failures if _failures else "soak passed")
	get_tree().quit(1 if _failures else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		push_error(msg)


func _run(run_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	seed(run_seed)
	GameState.new_game("Bot", "they")
	GameState.run_seed = run_seed
	var tally := {"jobs": 0, "delighted": 0, "pleased": 0, "lukewarm": 0, "earned": 0, "flips": 0, "flip_profit": 0}
	for day in DAYS:
		_morning(rng)
		_trade(rng, tally)
		_work(rng, tally)
		_night()
		_invariants()
	var regulars := GameState.cast.values().filter(func(c): return c.get("regular", false)).size()
	var done_stories := GameState.stories.values().filter(func(s): return Storylets.finished(s, Content.storylets)).size()
	print("seed %d: day %d, %d pebs, %d jobs (%d delighted, %d pleased, %d lukewarm), avg pay %d, %d regulars, %d/%d storylets done, %d finds, %d flips (+%d), skills %s" % [
		run_seed, GameState.day, GameState.pebs, tally.jobs, tally.delighted, tally.pleased, tally.lukewarm,
		tally.earned / maxi(tally.jobs, 1), regulars, done_stories, GameState.stories.size(), GameState.finds.size(),
		tally.flips, tally.flip_profit, GameState.skills])
	check(GameState.pebs > 500, "seed %d: a working shop builds savings over %d days (%d)" % [run_seed, DAYS, GameState.pebs])
	check(tally.jobs >= DAYS - 3, "seed %d: there's work every day (%d jobs)" % [run_seed, tally.jobs])


func _morning(rng: RandomNumberGenerator) -> void:
	for id in GameState.stories.keys():
		_story(id, "morning")
	if GameState.cat_morning() and GameState.cat.event:
		GameState.run_command("cat", [GameState.cat.event])
	if rng.randf() < 0.5:
		GameState.pet_cat()


func _trade(rng: RandomNumberGenerator, tally: Dictionary) -> void:
	var visit := GameState.hawker_today()
	if visit and GameState.pebs > 300:
		var offers: Array = visit.cart.offers
		var i := rng.randi_range(0, offers.size() - 1)
		if i not in visit.bought and GameState.pebs >= int(offers[i].price):
			var before := GameState.pebs
			GameState.buy_from_cart(i)
			check(GameState.pebs == before - int(offers[i].price), "buying from a cart costs its price")
			GameState.save()
			GameState.load_game()
			check(i in GameState.hawker.bought, "a bought cart offer stays sold after reloading")
	# Flip a junker: buy, fix and clean it the next day, sell to the better buyer.
	for id in GameState.projects():
		var ship: Dictionary = GameState.ships[id]
		for f in ship.faults:
			f.found = true
			f.fixed = true
		ship.grime = 0.0
		var best: Dictionary = GameState.buyers(id).reduce(func(a, b): return a if a.price >= b.price else b)
		tally.flip_profit += int(best.price) - int(ship.get("paid", 0))
		tally.flips += 1
		GameState.sell_ship(id, best.price, best.pilot.short)
		check(not GameState.ships.has(id), "a sold ship leaves the garage")
	if GameState.day >= 2 and GameState.pebs > 600 and rng.randf() < 0.3:
		var stock := GameState.yard()
		if stock:
			var id := GameState.buy_junker(stock[0])
			GameState.ships[id]["paid"] = stock[0].price


func _work(rng: RandomNumberGenerator, tally: Dictionary) -> void:
	var board := GameState.job_board()
	if board.is_empty():
		return
	var guest := GameState.accept_offer(0)
	_story(guest, "arrive")
	var spec := GameState.job_terms()
	var ship: Dictionary = GameState.ships[spec.ship]
	check(not ship.faults.is_empty(), "a walk-in's ship has something wrong with it")
	var repairs := {}
	for i in ship.faults.size():
		ship.faults[i].found = true
		ship.faults[i].fixed = true
		ship.faults[i].score = rng.randf_range(0.5, 1.0)
		repairs[i] = ship.faults[i].score
	if rng.randf() < 0.7:
		ship.grime = 0.0
	if rng.randf() < 0.6:
		ship.paint = GameState.pilot(spec.pilot).taste[0]
	var grade := Grading.grade(spec, GameState.pilot(spec.pilot), GameState.job.before, ship, repairs, Content.parts,
		Perks.effects(GameState.perks, Content.perks))
	GameState.story_flag(guest, "tier_" + grade.tier)
	_story(guest, "handoff")
	var before := GameState.pebs
	GameState.settle_job(GameState.job.id, grade)
	check(GameState.pebs == before + int(grade.pay), "payout adds the grade's pay")
	check(GameState.job.is_empty() and GameState.phase == "evening", "settling clears the bench")
	tally.jobs += 1
	tally[grade.tier] += 1
	tally.earned += int(grade.pay)


func _story(guest: String, hook: String) -> void:
	var scene := GameState.story_scene(guest, hook)
	if scene:
		check(Content.dialogue.has(scene), "storylet scene %s exists" % scene)
		GameState.advance_story(guest)


func _night() -> void:
	var pending := Perks.pending(GameState.skills, GameState.perks, Content.perks)
	while not pending.is_empty():
		var options := Perks.options(pending[0].skill, pending[0].level, Content.perks)
		GameState.perks.append(options[0].id)
		pending = Perks.pending(GameState.skills, GameState.perks, Content.perks)
	GameState.end_day()


func _invariants() -> void:
	check(GameState.pebs >= 0, "pebs never go negative (%d)" % GameState.pebs)
	for bag in [GameState.parts, GameState.items, GameState.worn]:
		for id in bag:
			check(int(bag[id]) > 0, "no empty or negative stacks (%s)" % id)
	check(int(GameState.cat.affection) >= 0 and int(GameState.cat.affection) <= int(Content.cat.max_affection),
		"Sprocket's affection stays in range")
	check(GameState.spark >= 0 and GameState.spark <= GameState.max_spark(), "spark stays in range")
	# Saving and loading gives back the same game (compared as JSON values: numbers come back as
	# floats, which is fine wherever the game doesn't test membership with `in`).
	var snapshot := JSON.stringify(JSON.parse_string(JSON.stringify(GameState.to_dict())))
	GameState.save()
	GameState.load_game()
	check(JSON.stringify(JSON.parse_string(JSON.stringify(GameState.to_dict()))) == snapshot,
		"a save loads back unchanged on day %d" % GameState.day)
