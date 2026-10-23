## Title: continue, or start fresh by choosing a name and pronouns.
extends Screen

const PRESETS := [["she/her", "she"], ["he/him", "he"], ["they/them", "they"], ["custom", "custom"]]

var _name: LineEdit
var _pronouns := "they"
var _custom: GridContainer
var _custom_fields := {}
var _plural: CheckBox
var _menu: VBoxContainer
var _setup: Control


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
	UI.place(_menu, Control.PRESET_BOTTOM_LEFT, Vector2(70, -220), Vector2(300, 0))
	ui.add_child(_menu)

	_build_setup()


func _continue() -> void:
	GameState.load_game()
	Router.go("shop")


func _show_setup() -> void:
	_menu.visible = false
	_setup.visible = true
	_name.grab_focus()


func _build_setup() -> void:
	_name = LineEdit.new()
	_name.placeholder_text = "Your name"
	_name.max_length = 18
	_name.custom_minimum_size.x = 380

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
		_custom_fields[f] = e
		_custom.add_child(e)
	_plural = CheckBox.new()
	_plural.text = "Uses plural verbs (\"they are\")"
	var custom_box := UI.vbox([UI.label("Fill in each form:", 18, UI.MUTED), _custom, _plural], 6)
	custom_box.visible = false
	_custom.set_meta("box", custom_box)

	var start := UI.button("Open the shop", _start, 24)
	var form := UI.vbox([UI.heading("Who's taking over the shop?", 30), _name,
		UI.label("Pronouns", 18, UI.MUTED), choices, custom_box, start], 12)
	_setup = UI.panel(form, UI.CREAM, 24)
	UI.place(_setup, Control.PRESET_BOTTOM_LEFT, Vector2(60, -420), Vector2(640, 0))
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
