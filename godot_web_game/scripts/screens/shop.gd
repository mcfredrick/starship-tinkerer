## The hangar hub: story beats play here, and every activity starts from here.
extends Screen

## Story beats in order: [scene, condition]. The first unseen beat whose condition holds plays.
var beats := [
	["intro", func(): return true],
	["odessa_arrives", func(): return GameState.day == 1 and GameState.phase == "morning" and GameState.job.is_empty()],
	["racers_visit", func(): return GameState.phase == "evening"],
	["day2_morning", func(): return GameState.day >= 2],
]

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
	ui.add_child(side)
	_refresh()
	_play_beats.call_deferred()


func _ship_on_cradle() -> String:
	if not GameState.job.is_empty():
		return Content.world.jobs[GameState.job.id].ship
	return "kettle"


func _play_beats() -> void:
	for beat in beats:
		var seen: String = "seen_" + beat[0]
		if not GameState.flags.has(seen) and beat[1].call():
			GameState.flags[seen] = true
			GameState.save()
			await Router.talk(beat[0])
			_refresh()


func _refresh() -> void:
	for c in _actions.get_children():
		c.queue_free()
	var job_open := not GameState.job.is_empty()
	if job_open:
		var pilot: String = Content.world.pilots[Content.world.jobs[GameState.job.id].pilot].short
		_hint.text = "%s's ship is on the cradle, waiting for you." % pilot
		_add("Workbench: %s" % pilot, func(): Router.go("workbench", {"ship": _ship_on_cradle()}))
	elif GameState.phase == "evening" and GameState.flags.has("race_open") and not GameState.flags.has("raced_today"):
		_hint.text = "The club race starts at last bell. The Kettle's in the back bay."
	elif GameState.phase == "evening":
		_hint.text = "The dock lights are dimming. A good time for tea, or bed."
	else:
		_hint.text = "A quiet spell. Tinker, trade, or put the kettle on."
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
