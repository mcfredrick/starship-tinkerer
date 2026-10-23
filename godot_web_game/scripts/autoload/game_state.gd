## Everything about one playthrough, saved to user://save.json (IndexedDB on web).
extends Node

signal changed

const SAVE_PATH := "user://save.json"
const MAX_SPARK := 4

var player := {"name": "Tinkerer", "pronouns": "they"}
var day := 1
## "morning" until the day's commission is taken, "day" while working, "evening" after the handoff.
var phase := "morning"
var spark := MAX_SPARK
var pebs := 0
var parts := {}
var items := {}
var ships := {}
var skills := {}
var rapport := {}
var flags := {}
var buff := ""
## The commission on the bench: {id, faults: [{type, spot, found, fixed, score}], before: build}.
var job := {}
## What happened today, for the night summary: {xp: {skill: n}, pebs: n, notes: [...]}.
var today := {}


func new_game(name: String, pronouns: Variant) -> void:
	var start: Dictionary = Content.world.start
	player = {"name": name, "pronouns": pronouns}
	day = 1
	phase = "morning"
	spark = MAX_SPARK
	pebs = start.pebs
	parts = start.parts.duplicate()
	items = start.items.duplicate()
	ships = Content.world.ships.duplicate(true)
	skills = {}
	for s in Skills.NAMES:
		skills[s] = 0
	rapport = {}
	flags = {}
	buff = ""
	job = {}
	_reset_today()
	save()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(to_dict()))
	changed.emit()


func load_game() -> void:
	from_dict(JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)))


func to_dict() -> Dictionary:
	return {
		"player": player, "day": day, "phase": phase, "spark": spark, "pebs": pebs, "parts": parts,
		"items": items, "ships": ships, "skills": skills, "rapport": rapport, "flags": flags, "buff": buff,
		"job": job, "today": today,
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


func ease(skill: String, task: String) -> float:
	return Skills.ease(skills[skill], buff_bonus(task))


func start_job(id: String) -> void:
	var spec: Dictionary = Content.world.jobs[id]
	var faults: Array = []
	for f in spec.faults:
		faults.append({"type": f.type, "spot": f.spot, "found": false, "fixed": false, "score": 0.0})
	var ship: Dictionary = ships[spec.ship]
	ship["faults"] = faults
	job = {"id": id, "before": ship.duplicate(true)}
	phase = "day"
	save()


func end_day() -> void:
	day += 1
	phase = "morning"
	spark = MAX_SPARK
	buff = ""
	_reset_today()
	save()


func _reset_today() -> void:
	today = {"xp": {}, "pebs": 0, "notes": []}
