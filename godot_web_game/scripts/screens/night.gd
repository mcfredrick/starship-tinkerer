## Night: what the day added up to, skill by skill, then sleep.
extends Screen


func _ready() -> void:
	super()
	var bg := UI.full(ColorRect.new())
	bg.color = Color("1b1626")
	ui.add_child(bg)

	var rows := UI.vbox([], 8)
	for s in Skills.NAMES:
		var xp: int = GameState.skills[s]
		var gained: int = GameState.today.xp.get(s, 0)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = Skills.progress(xp)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(220, 16)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var name := UI.label("%s  ·  level %d" % [Skills.LABELS[s], Skills.level(xp)], 20)
		name.custom_minimum_size.x = 260
		var gain := UI.label("+%d today" % gained if gained else "", 18, UI.GOOD)
		rows.add_child(UI.hbox([name, bar, gain], 14))

	var notes := UI.vbox([], 4)
	for n in GameState.today.notes:
		notes.add_child(UI.label("·  " + n, 18, UI.MUTED))
	var earned: int = GameState.today.pebs
	var summary := UI.heading("%s %s today" % ["Earned" if earned >= 0 else "Spent", UI.pebs(absi(earned))], 24,
		UI.AMBER_DARK)
	var sleep := UI.button("Sleep", _sleep, 24)
	var box := UI.vbox([UI.heading("Day %d is done" % GameState.day, 34),
		UI.label("The hangar lights dim to amber. Somewhere a drum-garden mister sighs.", 19, UI.MUTED, true),
		rows, summary, notes, sleep], 14)
	var panel := UI.panel(box, UI.CREAM, 28)
	UI.place(panel, Control.PRESET_CENTER, Vector2(-330, -280), Vector2(660, 0))
	ui.add_child(panel)


func _sleep() -> void:
	GameState.flags.erase("raced_today")
	GameState.end_day()
	Router.go("shop")
