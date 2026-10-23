## Night: what the day added up to, skill by skill, any new perks to choose, then sleep.
extends Screen

var _panel: PanelContainer


func _ready() -> void:
	super()
	var bg := UI.full(ColorRect.new())
	bg.color = Color("1b1626")
	ui.add_child(bg)
	_build()


func _build() -> void:
	if _panel:
		_panel.queue_free()
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

	var box := UI.vbox([UI.heading("Day %d is done" % GameState.day, 34),
		UI.label("The hangar lights dim to amber. Somewhere a drum-garden mister sighs.", 19, UI.MUTED, true),
		rows], 14)

	var pending := Perks.pending(GameState.skills, GameState.perks, Content.perks)
	if pending.is_empty():
		var notes := UI.vbox([], 4)
		for n in GameState.today.notes:
			notes.add_child(UI.label("·  " + n, 18, UI.MUTED))
		var earned: int = GameState.today.pebs
		box.add_child(UI.heading("%s %s today" % ["Earned" if earned >= 0 else "Spent", UI.pebs(absi(earned))], 24,
			UI.AMBER_DARK))
		box.add_child(notes)
		box.add_child(UI.button("Sleep", _sleep, 24))
	else:
		var next: Dictionary = pending[0]
		box.add_child(UI.heading("%s reached level %d. Pick a perk:" % [Skills.LABELS[next.skill], next.level], 22,
			UI.TEAL, true))
		var choices := UI.hbox([], 12)
		for perk in Perks.options(next.skill, next.level, Content.perks):
			var card := UI.vbox([UI.heading(perk.name, 21), UI.label(perk.desc, 17, UI.INK, true),
				UI.button("Choose", _choose.bind(perk.id), 18)], 8)
			card.custom_minimum_size = Vector2(280, 0)
			choices.add_child(UI.panel(card, Color.WHITE, 14))
		box.add_child(choices)
	_panel = UI.panel(box, UI.CREAM, 28)
	UI.place(_panel, Control.PRESET_CENTER, Vector2(-340, -300), Vector2(680, 0))
	ui.add_child(_panel)


func _choose(id: String) -> void:
	GameState.perks.append(id)
	GameState.save()
	Sfx.play("success")
	Router.toast("New perk: " + Perks.find(id, Content.perks).name)
	_build()


func _sleep() -> void:
	GameState.end_day()
	Router.go("shop")
