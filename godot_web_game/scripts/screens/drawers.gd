## Halloran's chest of drawers: each one labelled, some stuck until you've grown in the right way,
## each hiding something.
extends Screen

const WOOD := Color("8a5a3c")

var _grid: GridContainer
var _note: Label


func _ready() -> void:
	super()
	var bg := UI.full(ColorRect.new())
	bg.color = Color("2a2238")
	ui.add_child(bg)
	ui.add_child(Hud.new())
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_note = UI.label("Halloran's chest of drawers. Some are stuck. Some are probably stuck on purpose.", 18,
		UI.MUTED, true)
	_note.custom_minimum_size.x = 720
	var chest := UI.panel(_grid, WOOD, 18)
	var box := UI.vbox([UI.heading("Halloran's drawers", 30), chest, _note,
		UI.button("Back to the shop", func(): Router.go("shop"), 20)], 12)
	var panel := UI.panel(box, Color(UI.CREAM, 0.97), 22)
	UI.place(panel, Control.PRESET_CENTER, Vector2(-400, -280), Vector2(800, 0))
	UI.fit(panel, 84)
	ui.add_child(panel)
	_fill()


func _fill() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for id in Content.drawers:
		var spec: Dictionary = Content.drawers[id]
		var opened := GameState.flags.has("drawer_" + id)
		var b := UI.button(spec.label, _pull.bind(id), 16)
		b.custom_minimum_size = Vector2(170, 76)
		b.add_theme_stylebox_override("normal", UI.box(WOOD.lightened(0.2 if not opened else 0.0), 8, 6, false,
			WOOD.darkened(0.4)))
		b.add_theme_stylebox_override("hover", UI.box(WOOD.lightened(0.32), 8, 6, false, WOOD.darkened(0.4)))
		b.add_theme_color_override("font_color", UI.CREAM if not opened else Color(UI.CREAM, 0.45))
		b.add_theme_color_override("font_hover_color", UI.CREAM)
		_grid.add_child(b)


func _pull(id: String) -> void:
	if GameState.flags.has("drawer_" + id):
		_note.text = "Empty now, apart from fluff."
		return
	if not GameState.drawer_ready(id):
		Sfx.play("bonk", 0.8)
		_note.text = Content.drawers[id].hint
		return
	Sfx.play("found")
	_note.text = GameState.open_drawer(id)
	_fill()
