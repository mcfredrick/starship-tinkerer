## Everything about one playthrough, saved to user://save.json (IndexedDB on web).
extends Node

signal changed

## Screenshot runs point this elsewhere so they never touch a real save.
var save_path := "user://save.json"
const MAX_SPARK := 4
const BOARD_SIZE := 3
const RETURN_CHANCE := 0.5

var player := {"name": "Tinkerer", "pronouns": "they"}
var day := 1
## "morning" until the day's commission is taken, "day" while working, "evening" after the handoff.
var phase := "morning"
var spark := MAX_SPARK
var pebs := 0
var parts := {}
## Worn parts on the shelves, restorable at the market: {part id: count}.
var worn := {}
var items := {}
var ships := {}
var skills := {}
var rapport := {}
var flags := {}
var buff := ""
var perks: Array = []
## Goes down with sabotage; the dock gossips.
var reputation := 0
## The commission on the bench: {id, before: build, budget}. Its faults live on the ship's build.
var job := {}
## What happened today, for the night summary: {xp: {skill: n}, pebs: n, notes: [...]}.
var today := {}
## The run's seed: it decides who walks in and what they fly, so each playthrough differs.
var run_seed := 0
## Generated customers by id, and the jobs made for them (authored ones live in Content).
var cast := {}
var jobs := {}
## Today's job board: offers of {pilot, job, ship}, and the day they were drawn up for.
var board: Array = []
var board_day := 0
var next_id := 1
## Storylets running with generated customers, by pilot id (see Storylets).
var stories := {}
## Grommet the shop cat: affection, today's mood and event, and a part they've hidden away.
var cat := {}


func new_game(name: String, pronouns: Variant) -> void:
	var start: Dictionary = Content.world.start
	player = {"name": name, "pronouns": pronouns}
	day = 1
	phase = "morning"
	spark = MAX_SPARK
	pebs = start.pebs
	parts = start.parts.duplicate()
	worn = {}
	items = start.items.duplicate()
	ships = Content.world.ships.duplicate(true)
	skills = {}
	for s in Skills.NAMES:
		skills[s] = 0
	rapport = {}
	flags = {}
	buff = ""
	perks = []
	reputation = 0
	job = {}
	run_seed = randi()
	cast = {}
	jobs = {}
	board = []
	board_day = 0
	next_id = 1
	stories = {}
	cat = _new_cat()
	_reset_today()
	save()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(to_dict()))
	changed.emit()


func load_game() -> void:
	from_dict(JSON.parse_string(FileAccess.get_file_as_string(save_path)))


func to_dict() -> Dictionary:
	return {
		"player": player, "day": day, "phase": phase, "spark": spark, "pebs": pebs, "parts": parts,
		"items": items, "ships": ships, "skills": skills, "rapport": rapport, "flags": flags, "buff": buff,
		"job": job, "today": today, "perks": perks, "reputation": reputation, "seed": run_seed, "cast": cast,
		"jobs": jobs, "board": board, "board_day": board_day, "next_id": next_id,
		"stories": stories, "cat": cat, "worn": worn,
	}


func from_dict(d: Dictionary) -> void:
	player = d.player
	day = int(d.day)
	phase = d.phase
	spark = int(d.spark)
	pebs = int(d.pebs)
	parts = _ints(d.parts)
	items = _ints(d.items)
	ships = d.ships
	skills = _ints(d.skills)
	rapport = _ints(d.rapport)
	flags = d.flags
	buff = d.buff
	job = d.job
	today = d.today
	# Saves from before perks and reputation existed load with neither.
	perks = d.get("perks", [])
	reputation = int(d.get("reputation", 0))
	# Saves from before walk-ins pick a seed now and start with an empty cast.
	run_seed = int(d.get("seed", randi()))
	cast = d.get("cast", {})
	jobs = d.get("jobs", {})
	board = d.get("board", [])
	board_day = int(d.get("board_day", 0))
	next_id = int(d.get("next_id", 1))
	stories = d.get("stories", {})
	cat = d.get("cat", _new_cat())
	worn = _ints(d.get("worn", {}))


## JSON numbers load as floats; counts should stay ints.
static func _ints(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(d[k])
	return out


func pronoun_set() -> Dictionary:
	return Pronouns.resolve(player.pronouns)


func fill(text: String) -> String:
	return Pronouns.fill(text, player.name, pronoun_set())


func add_xp(skill: String, amount: int) -> void:
	skills[skill] += amount
	today.xp[skill] = today.xp.get(skill, 0) + amount


func add_pebs(amount: int, note: String) -> void:
	pebs += amount
	today.pebs += amount
	if note:
		today.notes.append(note)


func give(bag: Dictionary, id: String, count := 1) -> void:
	bag[id] = bag.get(id, 0) + count
	if bag[id] <= 0:
		bag.erase(id)


func take(bag: Dictionary, id: String) -> void:
	assert(bag.get(id, 0) > 0, "nothing to take: " + id)
	give(bag, id, -1)


## Bonus from the active tea for one kind of task ("weld", "scan", "calibrate").
func buff_bonus(task: String) -> float:
	if buff == "":
		return 0.0
	return Content.comforts.buffs[Content.comforts.teas[buff].buff].get(task, 0.0)


func leniency(skill: String, task: String) -> float:
	# Grommet sitting on the bench makes the day's repairs a little fiddlier.
	var cat_in_the_way := -0.15 if int(cat.get("bench", 0)) == day else 0.0
	return Skills.leniency(skills[skill], buff_bonus(task) + perk(task + "_leniency") + cat_in_the_way)


func perk(key: String) -> float:
	return Perks.value(perks, key, Content.perks)


func max_spark() -> int:
	return MAX_SPARK + int(perk("spark_max"))


## A pilot by id: the authored cast first, then the generated one.
func pilot(id: String) -> Dictionary:
	return Content.world.pilots[id] if Content.world.pilots.has(id) else cast[id]


func job_spec(id: String) -> Dictionary:
	return Content.world.jobs[id] if Content.world.jobs.has(id) else jobs[id]


## Today's walk-ins, drawn up once per day from the run seed so reloading doesn't reshuffle them.
func job_board() -> Array:
	if board_day != day:
		board = []
		board_day = day
		var w: Dictionary = Content.walkins
		var regulars: Array = cast.keys().filter(func(id): return cast[id].get("regular", false))
		for k in BOARD_SIZE:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([run_seed, day, k])
			# Some mornings, the first card is a regular coming back with the same ship.
			if k == 0 and regulars and rng.randf() < RETURN_CHANCE:
				var who: Dictionary = cast[regulars[rng.randi_range(0, regulars.size() - 1)]]
				var made := Walkins.job(rng, who, who.ship, shop_level(), w, Content.parts, Content.world.market,
					ships[who.ship])
				board.append({"pilot": who.duplicate(true), "job": made.job, "ship": made.ship})
				continue
			var id := "g%d" % (next_id + k)
			var who := Walkins.customer(rng, id, w, Content.parts.palette.keys())
			var made := Walkins.job(rng, who, id + "_ship", shop_level(), w, Content.parts, Content.world.market)
			board.append({"pilot": who, "job": made.job, "ship": made.ship})
		next_id += BOARD_SIZE
		save()
	return board


## How far along the shop is, for how tough walk-in jobs get.
func shop_level() -> int:
	return maxi(day - 3, 0) / 2 + maxi(reputation, 0)


## Takes board offer `index`: the customer joins the cast (or comes back, if a regular), their
## ship comes into the bay, and a new customer may arrive with a storylet.
func accept_offer(index: int) -> String:
	var offer: Dictionary = board.pop_at(index)
	var id: String = offer.pilot.id
	var visits: int = cast.get(id, {}).get("visits", 0) + 1
	cast[id] = offer.pilot
	cast[id]["ship"] = offer.job.ship
	cast[id]["visits"] = visits
	ships[offer.job.ship] = offer.ship.duplicate(true)
	var job_id := "%s_job%d" % [id, visits]
	jobs[job_id] = offer.job
	if visits == 1:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([run_seed, id, "story"])
		var running: Array = stories.values().filter(func(s): return not Storylets.finished(s, Content.storylets)).map(
			func(s): return s.id)
		var story := Storylets.pick(rng, cast[id], Content.storylets, running)
		if story:
			stories[id] = Storylets.start(story, day)
	start_job(job_id)
	return id


static func _new_cat() -> Dictionary:
	return {"affection": 2, "day": 0, "event": "", "mood": "sleepy", "stash": "", "petted": false, "bench": 0,
		"cuddle": 0}


## Grommet's scene for this morning, once per day ("" on a nap day). A hidden part always comes
## back the next morning.
func cat_morning() -> String:
	if int(cat.day) == day:
		return ""
	cat.day = day
	cat.petted = false
	if cat.stash:
		cat.event = "return_part"
		cat.mood = "sweet"
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([run_seed, day, "cat"])
		var today := CatMood.pick(rng, int(cat.affection), Content.cat)
		cat.event = today.event
		cat.mood = today.mood
	save()
	return "cat_" + cat.event if cat.event else ""


## Petting Grommet: "purr" (and a little affection, once a day), "content" if already petted
## today, or "swat" on a grumpy day.
func pet_cat() -> String:
	if cat.mood == "grumpy":
		return "swat"
	if cat.petted:
		return "content"
	cat.petted = true
	cat.affection = mini(int(cat.affection) + 1, int(Content.cat.max_affection))
	save()
	return "purr"


func treat_cat(cake: String) -> void:
	take(items, cake)
	cat.affection = mini(int(cat.affection) + 2, int(Content.cat.max_affection))
	if cat.mood == "grumpy":
		cat.mood = "sweet"
	save()


func _cat_effect(effect: String) -> void:
	match effect:
		"sniff":
			# Finds a fault on the job on the bench, or on the next one to arrive.
			if not job.is_empty() and _first_hidden_fault():
				_first_hidden_fault().found = true
			else:
				flags.cat_sniff = true
		"gift":
			var gift: String = Content.cat.gifts[randi() % Content.cat.gifts.size()]
			give(parts, gift)
			Router.toast("Grommet's gift: %s, on your shelf." % Content.part(gift).name)
		"cuddle":
			cat.cuddle = day
		"hide_part":
			if parts.is_empty():
				return
			var id: String = parts.keys()[randi() % parts.size()]
			take(parts, id)
			cat.stash = id
			Router.toast("Missing from your shelves: %s." % Content.part(id).name, UI.BAD)
		"return_part":
			give(parts, cat.stash)
			Router.toast("Back on your shelf: %s." % Content.part(cat.stash).name)
			cat.stash = ""
		"bench":
			cat.bench = day
		"spill":
			var teas: Array = items.keys().filter(func(i): return Content.comforts.teas.has(i))
			if teas:
				var spilt: String = teas[randi() % teas.size()]
				take(items, spilt)
				Router.toast("Spilt: one %s." % Content.comforts.teas[spilt].name, UI.BAD)


func _first_hidden_fault() -> Dictionary:
	for f in ships[job_spec(job.id).ship].faults:
		if not f.found:
			return f
	return {}


## The storylet scene `pilot_id` plays at `hook` now, or "".
func story_scene(pilot_id: String, hook: String) -> String:
	return Storylets.scene_at(stories[pilot_id], hook, day, Content.storylets) if stories.has(pilot_id) else ""


func advance_story(pilot_id: String) -> void:
	Storylets.advance(stories[pilot_id], day)
	save()


func story_flag(pilot_id: String, flag: String) -> void:
	if stories.has(pilot_id):
		stories[pilot_id].flags[flag] = true


## The job spec with the agreed budget, which haggling in dialogue may have changed.
func job_terms() -> Dictionary:
	var spec: Dictionary = job_spec(job.id).duplicate()
	spec.budget = job.get("budget", spec.budget)
	return spec


## Commands from dialogue scripts ("! set flag", "! job id", "! give item n", "! pebs n",
## "! budget n" to change the agreed budget of the job on the bench).
func run_command(cmd: String, args: Array) -> void:
	match cmd:
		"set":
			flags[args[0]] = true
		"job":
			start_job(args[0])
		"give":
			give(items, args[0], int(args[1]) if args.size() > 1 else 1)
		"pebs":
			add_pebs(int(args[0]), "")
		"budget":
			job.budget = int(args[0])
		"cat":
			_cat_effect(args[0])
		_:
			assert(false, "unknown dialogue command: " + cmd)
	save()


func start_job(id: String) -> void:
	var spec: Dictionary = job_spec(id)
	var faults: Array = []
	for f in spec.faults:
		faults.append({"type": f.type, "spot": f.spot, "found": false, "fixed": false, "score": 0.0})
	var ship: Dictionary = ships[spec.ship]
	ship["faults"] = faults
	if flags.has("cat_sniff") and faults:
		faults[0].found = true
		flags.erase("cat_sniff")
	job = {"id": id, "before": ship.duplicate(true)}
	phase = "day"
	save()


func end_day() -> void:
	day += 1
	phase = "morning"
	spark = max_spark()
	buff = ""
	flags.erase("raced_today")
	_reset_today()
	save()


func _reset_today() -> void:
	today = {"xp": {}, "pebs": 0, "notes": []}
