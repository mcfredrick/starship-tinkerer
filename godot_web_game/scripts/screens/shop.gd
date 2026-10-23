## The hangar hub: story beats play here, and every activity starts from here.
extends Screen

## Sprocket's spot on the deck, by the cradle.
const CAT_SPOT := Vector3(-3.9, 0.0, 3.6)

var _cat_override := ""
var _actions: VBoxContainer
var _cat: CatModel
var _hint: Label


func _ready() -> void:
	super()
	add_stage()
	stage.camera.yaw = 0.5
	stage.camera.target = Vector3(1.8, 2.2, 0)
	stage.camera.refresh()
	show_ship(_ship_on_cradle())
	_cat = CatModel.new()
	_cat.pose(_cat_mood() == "sleepy")
	_cat.position = CAT_SPOT
	_cat.rotation.y = -2.1
	_cat.scale = Vector3.ONE * 1.4
	stage.add_child(_cat)
	ui.add_child(Hud.new())

	_hint = UI.label("", 20, UI.INK, true)
	_actions = UI.vbox([], 10)
	var side := UI.panel(UI.vbox([UI.heading("What next?", 26), _hint, _actions], 12), UI.CREAM, 20)
	UI.place(side, Control.PRESET_CENTER_RIGHT, Vector2(-420, -230), Vector2(380, 0))
	UI.fit(side, 84)
	ui.add_child(side)
	_refresh()
	_play_beats.call_deferred()


## Screen params: `cat=<mood>` shows Sprocket in that mood (for screenshots).
func setup(params: Dictionary) -> void:
	_cat_override = params.get("cat", "")


func _cat_mood() -> String:
	return _cat_override if _cat_override else GameState.cat.get("mood", "sleepy")


func _ship_on_cradle() -> String:
	if not GameState.job.is_empty():
		return GameState.job_spec(GameState.job.id).ship
	return "kettle"


## Story beats come from world.json in order. Each plays once, when its conditions hold:
## day (exact), min_day, phase, idle (no job on the bench), requires and excludes (flags).
func _play_beats() -> void:
	for beat in Content.world.beats:
		var seen: String = "seen_" + beat.scene
		if not GameState.flags.has(seen) and _beat_ready(beat):
			await Router.talk(beat.scene)
			# Marked after the scene so closing the game mid-conversation replays it.
			GameState.flags[seen] = true
			GameState.save()
			if beat.has("event"):
				Router.go("event", {"id": beat.event})
				return
			_refresh()
	if GameState.phase == "morning":
		for id in GameState.stories.keys():
			await Router.story(id, "morning")
		if GameState.bond_morning() > 0:
			Router.toast("There's fresh dock gossip on your tablet.")
		var cat_scene := GameState.cat_morning()
		if cat_scene:
			await Router.talk(cat_scene)
		_refresh()


func _beat_ready(b: Dictionary) -> bool:
	var f := GameState.flags
	return (not b.has("day") or GameState.day == b.day) and GameState.day >= b.get("min_day", 0) \
		and (not b.has("phase") or GameState.phase == b.phase) \
		and (not b.get("idle", false) or GameState.job.is_empty()) \
		and (not b.has("requires") or f.has(b.requires)) and (not b.has("excludes") or not f.has(b.excludes))


func _refresh() -> void:
	for c in _actions.get_children():
		c.queue_free()
	var job_open := not GameState.job.is_empty()
	if job_open:
		var pilot: String = GameState.pilot(GameState.job_spec(GameState.job.id).pilot).short
		_hint.text = "%s's ship is on the cradle, waiting for you." % pilot
		_add("Workbench: %s" % pilot, func(): Router.go("workbench", {"ship": _ship_on_cradle()}))
	elif GameState.phase == "evening" and GameState.flags.has("race_open") and not GameState.flags.has("raced_today"):
		var cup := GameState.cup_today()
		_hint.text = ("Tonight's the %s! Or the club race, as ever." % Content.world.races[cup].name) if cup else \
			"The club race starts at last bell. Your ship's in the back bay."
	elif GameState.phase == "evening":
		_hint.text = "The dock lights are dimming. A good time for tea, or bed."
	elif GameState.phase == "morning":
		_hint.text = "Walk-ins have pinned requests to the job board."
	else:
		_hint.text = "A quiet spell. Tinker, trade, or put the kettle on."
	if GameState.phase == "morning" and not job_open:
		_add("Job board", func(): Router.go("board"))
	var visit := GameState.hawker_today()
	if visit and GameState.phase != "evening":
		_add("%s's cart" % GameState.pilot(visit.id).short, func(): Router.go("hawker"))
	_add("Tea nook", func(): Router.go("tea"))
	_add("Garage: the Kettle", func(): Router.go("workbench", {"ship": "kettle"}))
	for id in GameState.projects():
		_add("Garage: the %s" % GameState.ships[id].name, func(): Router.go("workbench", {"ship": id}))
	if GameState.day >= 2 and GameState.phase != "evening":
		_add("Salvage yard", func(): Router.go("yard"))
	_add("Parts market", func(): Router.go("market"))
	_add("Halloran's drawers", func(): Router.go("drawers"))
	if GameState.flags.has("race_open") and GameState.phase == "evening" and not job_open:
		for race_id in ["club", GameState.cup_today()]:
			if race_id == "":
				continue
			var spec: Dictionary = Content.world.races[race_id]
			var b := _add(spec.name, _enter.bind(race_id))
			b.disabled = GameState.flags.has("raced_today")
			b.tooltip_text = spec.about
	if GameState.phase == "evening" or GameState.day >= 2:
		_add("Sleep", func(): Router.go("night"))


func _enter(race_id: String) -> void:
	var block := GameState.race_block(race_id)
	if block:
		Router.toast(block, UI.BAD)
		return
	Router.go("race", {"race": race_id})


## Clicking Sprocket pets them, mood permitting.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var at := stage.camera.unproject_position(_cat.global_position + Vector3.UP * 0.7)
	if event.position.distance_to(at) > 70 * UI.reach():
		return
	match GameState.pet_cat():
		"purr":
			_cat.purr()
			Sfx.play("purr")
			Router.toast("Sprocket leans into your hand, purring.")
		"content":
			_cat.purr()
			Sfx.play("mrrp")
		"swat":
			_cat.swat()
			Sfx.play("mrrp", 0.7)
			Router.toast("Sprocket swats your hand away. Not today.", UI.BAD)
	get_viewport().set_input_as_handled()


func _add(text: String, action: Callable) -> Button:
	var b := UI.button(text, action, 22)
	_actions.add_child(b)
	return b
