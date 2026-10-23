## The tea nook: pick a tea for a gentle buff, eat a cake for spark, and read on the tablet.
extends Screen

const NOOK := preload("res://shaders/nook.gdshader")

var _teas: HBoxContainer
var _cakes: HBoxContainer
var _note: Label


func _ready() -> void:
	super()
	var bg := UI.full(ColorRect.new())
	var mat := ShaderMaterial.new()
	mat.shader = NOOK
	bg.material = mat
	ui.add_child(bg)
	ui.add_child(Hud.new())

	_teas = UI.hbox([], 14)
	_cakes = UI.hbox([], 14)
	_note = UI.label("", 19, UI.MUTED, true)
	_note.custom_minimum_size.x = 640
	var buttons := UI.hbox([UI.button("Read on the tablet", Tablet.open, 20), UI.spacer(),
		UI.button("Back to work", func(): Router.go("shop"), 20)])
	var box := UI.vbox([UI.heading("The tea nook", 32), UI.label("Pick a tea", 19, UI.MUTED), _teas,
		UI.label("Have a cake", 19, UI.MUTED), _cakes, _note, buttons], 10)
	var panel := UI.panel(box, Color(UI.CREAM, 0.95), 24)
	UI.place(panel, Control.PRESET_CENTER_LEFT, Vector2(60, -282), Vector2(700, 0))
	ui.add_child(panel)
	_fill()


func _fill() -> void:
	for c in _teas.get_children() + _cakes.get_children():
		c.queue_free()
	for id in Content.comforts.teas:
		_teas.add_child(_card(id, GameState.items.get(id, 0), _brew))
	var any_cake := false
	for id in Content.comforts.cakes:
		if GameState.items.get(id, 0) > 0:
			any_cake = true
			_cakes.add_child(_card(id, GameState.items[id], _eat))
	if not any_cake:
		_cakes.add_child(UI.label("The cake tin is empty. The market sells a few.", 18, UI.MUTED))
	if _note.text == "":
		_note.text = "Spark %d of %d. A tea lasts until you sleep." % [GameState.spark, GameState.MAX_SPARK]


func _card(id: String, count: int, action: Callable) -> Control:
	var info: Dictionary = Content.item(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 168)
	b.disabled = count <= 0
	b.tooltip_text = info.desc
	b.pressed.connect(action.bind(id))
	var art := UI.icon(Content.prop(info.icon), 104)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := UI.label("%s\n× %d" % [info.name, count], 15, UI.INK, true)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.custom_minimum_size.x = 136
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := UI.vbox([art, name], 2)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(inner, Control.PRESET_TOP_LEFT, Vector2(7, 4), Vector2(136, 160))
	b.add_child(inner)
	var plain := UI.box(Color(1, 1, 1, 0.5), 16, 0, false, UI.PAPER.darkened(0.15))
	b.add_theme_stylebox_override("normal", plain)
	b.add_theme_stylebox_override("hover", UI.box(Color(1, 0.97, 0.88), 16, 0, false, UI.AMBER))
	b.add_theme_stylebox_override("pressed", UI.box(UI.PAPER, 16, 0, false, UI.AMBER_DARK))
	b.add_theme_stylebox_override("disabled", UI.box(Color(1, 1, 1, 0.2), 16, 0, false, UI.PAPER))
	return b


func _brew(id: String) -> void:
	GameState.take(GameState.items, id)
	GameState.buff = id
	Sfx.play("pour")
	GameState.save()
	var tea: Dictionary = Content.comforts.teas[id]
	_note.text = "You brew a pot of %s. %s" % [tea.name, tea.desc]
	_fill()


func _eat(id: String) -> void:
	GameState.take(GameState.items, id)
	var cake: Dictionary = Content.comforts.cakes[id]
	GameState.spark = mini(GameState.spark + int(cake.spark), GameState.MAX_SPARK)
	GameState.save()
	_note.text = "%s. %s Spark %d of %d." % [cake.name, cake.desc, GameState.spark, GameState.MAX_SPARK]
	_fill()
