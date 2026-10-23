## The hangar hub: story beats play here, and every activity starts from here.
extends Screen

var _actions: VBoxContainer
var _hint: Label


func _ready() -> void:
	super()
	add_stage()
	stage.camera.yaw = 0.5
	stage.camera.target = Vector3(1.8, 2.2, 0)
	stage.camera.refresh()
	show_ship(_ship_on_cradle())
	ui.add_child(Hud.new())

	_hint = UI.label("", 20, UI.INK, true)
	_actions = UI.vbox([], 10)
	var side := UI.panel(UI.vbox([UI.heading("What next?", 26), _hint, _actions], 12), UI.CREAM, 20)
	UI.place(side, Control.PRESET_CENTER_RIGHT, Vector2(-420, -230), Vector2(380, 0))
	UI.fit(side, 84)
	ui.add_child(side)
	_refresh()
	_play_beats.call_deferred()


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
			_refresh()
	if GameState.phase == "morning":
		for id in GameState.stories.keys():
			await Router.story(id, "morning")


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
		_hint.text = "The club race starts at last bell. The Kettle's in the back bay."
	elif GameState.phase == "evening":
		_hint.text = "The dock lights are dimming. A good time for tea, or bed."
	elif GameState.phase == "morning":
		_hint.text = "Walk-ins have pinned requests to the job board."
	else:
		_hint.text = "A quiet spell. Tinker, trade, or put the kettle on."
	if GameState.phase == "morning" and not job_open:
		_add("Job board", func(): Router.go("board"))
	_add("Tea nook", func(): Router.go("tea"))
	_add("Garage: the Kettle", func(): Router.go("workbench", {"ship": "kettle"}))
	_add("Parts market", func(): Router.go("market"))
	if GameState.flags.has("race_open") and GameState.phase == "evening" and not job_open:
		var b := _add("Club race", func(): Router.go("race"))
		b.disabled = GameState.flags.has("raced_today")
	if GameState.phase == "evening" or GameState.day >= 2:
		_add("Sleep", func(): Router.go("night"))


func _add(text: String, action: Callable) -> Button:
	var b := UI.button(text, action, 22)
	_actions.add_child(b)
	return b
