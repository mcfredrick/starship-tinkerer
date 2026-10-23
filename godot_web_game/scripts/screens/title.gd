## Title: continue, or start fresh by choosing a name and pronouns.
extends Screen

const PRESETS := [["she/her", "she"], ["he/him", "he"], ["they/them", "they"], ["custom", "custom"]]

var _open_credits := false
var _name: LineEdit
var _pronouns := "they"
var _custom: GridContainer
var _custom_fields := {}
var _plural: CheckBox
var _menu: VBoxContainer
var _setup: Control
var _open_form := ""


## `--form=` (any value) opens the new-game form straight away; `--form=custom` also picks custom
## pronouns. Used for screenshot checks.
func setup(params: Dictionary) -> void:
	_open_form = params.get("form", "")
	_open_credits = params.has("credits")


func _ready() -> void:
	super()
	add_stage()
	stage.camera.yaw = 0.9
	stage.camera.pitch = -0.18
	stage.camera.distance = 12.5
	stage.camera.target = Vector3(-2.5, 2.4, 0)
	stage.camera.refresh()
	var kettle := ShipModel.new()
	stage.cradle.add_child(kettle)
	kettle.build(Content.world.ships.kettle)

	var title := UI.vbox([UI.heading("Starship Tinkerer", 72, UI.CREAM),
		UI.label("A cozy repair shop at the edge of the rings", 24, UI.CREAM.darkened(0.1))], 0)
	UI.place(title, Control.PRESET_TOP_LEFT, Vector2(70, 70), Vector2(800, 0))
	ui.add_child(title)

	_menu = UI.vbox([], 14)
	if GameState.has_save():
		_menu.add_child(UI.button("Continue", _continue, 26))
	_menu.add_child(UI.button("New game", _show_setup, 26))
	_menu.add_child(UI.button("Credits", _show_credits, 20))
	UI.place(_menu, Control.PRESET_BOTTOM_LEFT, Vector2(70, -220), Vector2(300, 0))
	ui.add_child(_menu)

	_build_setup()
	if _open_credits:
		_show_credits()
	if _open_form != "":
		_show_setup()
		if _open_form == "custom":
			_pick("custom")


func _show_credits() -> void:
	var box := UI.vbox([], 8)
	for line in Content.credits.lines:
		if line.has("heading"):
			box.add_child(UI.heading(line.heading, 22, UI.TEAL))
		else:
			var l := UI.label(line.text, 18, UI.INK, true)
			l.custom_minimum_size.x = 560
			box.add_child(l)
	var back := UI.button("Back", func(): pass, 20)
	var panel := UI.panel(UI.vbox([box, back], 14), UI.CREAM, 26)
	back.pressed.connect(panel.queue_free)
	UI.place(panel, Control.PRESET_CENTER, Vector2(-320, -260), Vector2(640, 0))
	UI.fit(panel)
	ui.add_child(panel)


func _continue() -> void:
	GameState.load_game()
	Router.go("shop")


func _show_setup() -> void:
	_menu.visible = false
	_setup.visible = true
	# On phones focus would do nothing useful; the field is tapped to open the prompt.
	if not UI.touch:
		_name.grab_focus()


func _build_setup() -> void:
	_name = LineEdit.new()
	_name.placeholder_text = "Tap to enter your name" if UI.touch else "Your name"
	_name.max_length = 18
	_name.custom_minimum_size.x = 380
	UI.touch_text(_name, "Your name (what the dock will call you)")

	var choices := UI.hbox([], 8)
	var group := ButtonGroup.new()
	for p in PRESETS:
		var b := UI.button(p[0], _pick.bind(p[1]), 18)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = p[1] == _pronouns
		choices.add_child(b)

	_custom = GridContainer.new()
	_custom.columns = 5
	for f in Pronouns.FORMS:
		var e := LineEdit.new()
		e.placeholder_text = f
		e.custom_minimum_size.x = 110
		e.add_theme_font_size_override("font_size", 18)
		UI.touch_text(e, "Pronoun: %s" % f)
		_custom_fields[f] = e
		_custom.add_child(e)
	_plural = CheckBox.new()
	_plural.text = "Uses plural verbs (\"they are\")"
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		_plural.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var custom_box := UI.vbox([UI.label("Fill in each form:", 18, UI.MUTED), _custom, _plural], 6)
	custom_box.visible = false
	_custom.set_meta("box", custom_box)

	var start := UI.button("Open the shop", _start, 24)
	var form := UI.vbox([UI.heading("Who's taking over the shop?", 30), _name,
		UI.label("Pronouns", 18, UI.MUTED), choices, custom_box, start], 12)
	_setup = UI.panel(form, UI.CREAM, 24)
	# Bottom-anchored and growing upward, so the custom pronoun fields never push it off screen.
	UI.place(_setup, Control.PRESET_BOTTOM_LEFT, Vector2(60, -40), Vector2(640, 0))
	_setup.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_setup.visible = false
	ui.add_child(_setup)


func _pick(key: String) -> void:
	_pronouns = key
	_custom.get_meta("box").visible = key == "custom"


func _start() -> void:
	var name := _name.text.strip_edges()
	if name == "":
		Router.toast("What should folks call you?", UI.BAD)
		return
	var pronouns: Variant = _pronouns
	if _pronouns == "custom":
		var set := {"plural": _plural.button_pressed}
		for f in Pronouns.FORMS:
			var v: String = _custom_fields[f].text.strip_edges().to_lower()
			if v == "":
				Router.toast("Fill in every pronoun form.", UI.BAD)
				return
			set[f] = v
		pronouns = set
	GameState.new_game(name, pronouns)
	Router.go("shop")
