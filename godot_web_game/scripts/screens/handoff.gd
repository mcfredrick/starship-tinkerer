## The pilot collects their ship: a report card, their reaction, then payment and barter.
extends Screen

var _job_id: String
var _job: Dictionary
var _pilot: Dictionary
var _grade: Dictionary
var _card: VBoxContainer
var _tricks: Array = []


func _ready() -> void:
	super()
	_job_id = GameState.job.id
	_job = GameState.job_terms()
	_pilot = GameState.pilot(_job.pilot)
	var build: Dictionary = GameState.ships[_job.ship]
	var repairs := {}
	for i in build.faults.size():
		if build.faults[i].fixed:
			repairs[i] = build.faults[i].score
	_grade = Grading.grade(_job, _pilot, GameState.job.before, build, repairs, Content.parts,
		Perks.effects(GameState.perks, Content.perks))
	_tricks = build.get("mischief", []).duplicate()

	add_stage()
	stage.spin_speed = 0.35
	stage.camera.target = Vector3(-2.4, 2.0, 0)
	stage.camera.distance = 11.0
	stage.camera.refresh()
	show_ship(_job.ship)
	ui.add_child(Hud.new())

	_card = UI.vbox([], 8)
	var panel := UI.panel(_card, Color(UI.CREAM, 0.97), 22)
	UI.place(panel, Control.PRESET_TOP_LEFT, Vector2(16, 84), Vector2(420, 0))
	ui.add_child(panel)
	_report()
	_play.call_deferred()


func _report() -> void:
	_card.add_child(UI.heading("%s's verdict" % _pilot.short, 28))
	for w in _grade.wants:
		_card.add_child(UI.label(("✓  " if w.met else "✗  ") + w.label, 20, UI.GOOD if w.met else UI.BAD))
	_card.add_child(UI.label("Repair quality  %d%%" % roundi(_grade.quality * 100), 20))
	var budget := "Parts used  %d of %d pebs" % [_grade.parts_cost, _job.budget]
	_card.add_child(UI.label(budget, 20))
	if _grade.gift > 0:
		_card.add_child(UI.label("You covered %d pebs yourself. %s noticed." % [_grade.gift, _pilot.short], 18,
			UI.TEAL, true))
	for id in _tricks:
		_card.add_child(UI.label("Mischief: " + Content.parts.mischief[id].name, 18, UI.ROSE))


func _play() -> void:
	await get_tree().create_timer(0.8).timeout
	var guest: String = _job.pilot if _pilot.get("generated", false) else ""
	await Router.talk(_scene(_grade.tier), guest)
	if _grade.mischief != "":
		await Router.talk(_scene(_grade.mischief, "mischief_" + _grade.mischief), guest)
	if guest:
		GameState.story_flag(guest, "tier_" + _grade.tier)
		await Router.story(guest, "handoff")
	_pay()


## The most specific reaction scene there is: one for this pilot's trait, then for the job, then
## `fallback`.
func _scene(outcome: String, fallback := "") -> String:
	for t in _pilot.get("traits", []):
		var scene := "%s_%s_%s" % [_job.dialogue, t, outcome]
		if Content.dialogue.has(scene):
			return scene
	var plain := "%s_%s" % [_job.dialogue, outcome]
	return plain if Content.dialogue.has(plain) or not fallback else fallback


func _pay() -> void:
	Sfx.play("coins")
	GameState.add_pebs(_grade.pay, "%s paid %s" % [_pilot.short, UI.pebs(_grade.pay)])
	var gifts: Array = []
	for item in _job.barter:
		GameState.give(GameState.items, item, _job.barter[item])
		gifts.append("%d × %s" % [_job.barter[item], Content.item(item).name])
	GameState.rapport[_job.pilot] = GameState.rapport.get(_job.pilot, 0) + _grade.rapport
	GameState.flags[_job_id + "_done"] = true
	if _grade.mischief != "":
		GameState.flags[_job_id + "_" + _grade.mischief] = true
		GameState.flags.any_mischief = true
		GameState.flags["any_mischief_" + _job.pilot] = true
		GameState.reputation += _grade.reputation
	for w in _job.wants:
		if w.has("flag") and _grade.wants[_job.wants.find(w)].met:
			GameState.flags[w.flag] = true
	if _grade.fit >= 0.66:
		GameState.add_xp("craft", 15)
	# Walk-ins who leave happy (and unsabotaged) become regulars and come back with new jobs.
	if _pilot.get("generated", false) and _grade.tier != "lukewarm" and _grade.mischief != "sabotage":
		GameState.cast[_job.pilot]["regular"] = true
	GameState.job = {}
	GameState.phase = "evening"
	GameState.save()

	_card.add_child(HSeparator.new())
	_card.add_child(UI.heading("Paid %s" % UI.pebs(_grade.pay), 26, UI.AMBER_DARK))
	if _grade.tip > 0:
		_card.add_child(UI.label("Including a tip, for work that delighted.", 17, UI.MUTED))
	if gifts:
		_card.add_child(UI.label("And: " + ", ".join(gifts), 19, UI.INK, true))
	_card.add_child(UI.label("%s rapport %+d" % [_pilot.short, _grade.rapport], 19, UI.TEAL if _grade.rapport >= 0 else UI.BAD))
	if _grade.reputation < 0:
		_card.add_child(UI.label("The dock will hear about this. Reputation %d" % _grade.reputation, 17, UI.BAD, true))
	_card.add_child(UI.button("Back to the shop", func(): Router.go("shop"), 22))
