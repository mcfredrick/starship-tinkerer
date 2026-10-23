## The translucent tablet: letters, stories, the bulletin and manuals, on frosted glass.
## Reading a manual for the first time teaches something (its `unlock` flag) and some XP.
class_name Tablet
extends Control

const FROST := preload("res://shaders/frost.gdshader")
const KINDS := {"letter": "Letter", "story": "Story", "bulletin": "Bulletin", "manual": "Manual", "guide": "Field guide"}
## Illustrations (assets/illustrations, rendered by blender/illustrations.py) fill the reading column.
const IMAGE_WIDTH := 600
const SIZE := Vector2(1040, 600)

var _list: VBoxContainer
var _body: RichTextLabel
var _title: Label
var _first := ""


## Opens the tablet, at entry `first` if given (screenshots use this).
static func open(first := "") -> void:
	var t := Tablet.new()
	t._first = first
	t.theme = Router.theme
	Router.overlay.add_child(t)


static func available() -> Array:
	var out: Array = []
	for id in Content.reading.entries:
		var e: Dictionary = Content.reading.entries[id]
		if e.day > GameState.day:
			continue
		if e.has("requires") and not GameState.flags.has(e.requires):
			continue
		if e.has("excludes") and GameState.flags.has(e.excludes):
			continue
		out.append(id)
	# Generated pages: today's gossip (its own id each day, so it reads as new) and who's who.
	if GameState.gossip.get("lines", []):
		out.append(_gossip_id())
	if _known_pairs():
		out.append("whos_who")
	return out


static func _gossip_id() -> String:
	return "gossip_%d" % int(GameState.gossip.day)


static func _known_pairs() -> Array:
	return Content.bonds.pairs.keys().filter(func(k): return GameState.flags.has(Content.bonds.pairs[k].after))


## A reading entry by id: from data/reading.json, or one of the generated pages.
static func entry(id: String) -> Dictionary:
	if Content.reading.entries.has(id):
		return Content.reading.entries[id]
	if id.begins_with("gossip_"):
		return {"kind": "bulletin", "title": "Dock gossip", "from": "Overheard on the spine", "day": GameState.day,
			"body": "\n\n".join(GameState.gossip.lines)}
	var lines: Array = []
	for key in _known_pairs():
		var names: Array = Array(key.split("|")).map(func(n): return _display(n))
		var v := Bonds.value(GameState.bonds, key, Content.bonds)
		lines.append("[b]%s and %s[/b]: %s" % [names[0], names[1], Bonds.describe(v, Content.bonds)])
	var pets: Array = []
	for id2 in Content.bonds.pets:
		var pet: Dictionary = Content.bonds.pets[id2]
		if GameState.flags.has("met_pet_" + id2):
			pets.append("[b]%s[/b], %s\n%s" % [pet.name, pet.kind, pet.about])
	var body := "How everyone's getting on, as far as the dock can tell.\n\n" + "\n".join(lines)
	if pets:
		body += "\n\n[b]Pets of the dock[/b]\n\n" + "\n\n".join(pets)
	return {"kind": "guide", "title": "Who's who", "from": "Dock gossip, compiled", "day": GameState.day, "body": body}


static func _display(id: String) -> String:
	if Content.bonds.pets.has(id):
		return Content.bonds.pets[id].name
	return GameState.pilot(id).short


static func unread() -> int:
	return available().filter(func(id): return not GameState.flags.has("read_" + id)).size()


func _ready() -> void:
	UI.full(self)
	var shade := UI.full(ColorRect.new())
	shade.color = Color(0.05, 0.03, 0.1, 0.3)
	add_child(shade)

	var glass := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = FROST
	mat.set_shader_parameter("rect_size", SIZE)
	glass.material = mat
	UI.place(glass, Control.PRESET_CENTER, -SIZE / 2, SIZE)
	UI.fit(glass)
	add_child(glass)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	UI.place(margin, Control.PRESET_CENTER, -SIZE / 2, SIZE)
	UI.fit(margin)
	add_child(margin)

	_list = UI.vbox([], 6)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(300, 0)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.add_child(_list)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_title = UI.heading("", 28, Color("1d3a40"))
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.add_theme_font_size_override("normal_font_size", 21)
	_body.add_theme_color_override("default_color", Color("1d2a30"))
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reader := UI.vbox([_title, _body], 12)
	reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var close := UI.button("Put it down", queue_free, 18)
	var header := UI.hbox([UI.heading("Tablet", 26, Color("1d3a40")), UI.spacer(), close])
	var columns := UI.hbox([list_scroll, _vline(), reader], 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(UI.vbox([header, columns], 14))
	_fill_list()
	if _first:
		_open(_first)


func _vline() -> Control:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.5)
	r.custom_minimum_size = Vector2(2, 0)
	return r


func _fill_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var ids := available()
	ids.reverse()
	if not GameState.finds.is_empty():
		var finds := UI.button("Your finds  (%d of %d)" % [GameState.finds.size(), Content.trade.trinkets.size()],
			_open_finds, 17)
		_list.add_child(finds)
	for id in ids:
		var e: Dictionary = entry(id)
		var unread_mark := "" if GameState.flags.has("read_" + id) else "● "
		var b := Button.new()
		b.text = "%s%s\n%s · %s" % [unread_mark, e.title, KINDS[e.kind], e.from]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_override("font", UI.body_font)
		b.add_theme_font_size_override("font_size", 17)
		var normal := UI.box(Color(1, 1, 1, 0.35), 12, 8)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.6), 12, 8))
		b.add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.75), 12, 8))
		b.add_theme_stylebox_override("focus", UI.box(Color(0, 0, 0, 0), 12, 8))
		b.pressed.connect(_open.bind(id))
		_list.add_child(b)
	if ids.size() > 0 and _title.text == "":
		_open(ids[0])


## The trinkets you've found, with the rest left as question marks to hunt for.
func _open_finds() -> void:
	_title.text = "Your finds"
	var lines: Array = []
	for id in Content.trade.trinkets:
		var t: Dictionary = Content.trade.trinkets[id]
		if GameState.finds.has(id):
			lines.append("[b]%s[/b]\n%s" % [t.name, t.desc])
		else:
			lines.append("[b]???[/b]\nStill out there somewhere. Hawkers, junkers and old drawers turn things up.")
	_body.text = "\n\n".join(lines)
	_body.scroll_to_line(0)


func _open(id: String) -> void:
	var e: Dictionary = entry(id)
	_title.text = e.title
	var picture := ""
	if e.has("image"):
		picture = "[center][img width=%d]res://assets/illustrations/%s.png[/img][/center]\n\n" % [IMAGE_WIDTH, e.image]
	_body.text = picture + GameState.fill(e.body)
	_body.scroll_to_line(0)
	if not GameState.flags.has("read_" + id):
		GameState.flags["read_" + id] = true
		if e.has("unlock"):
			GameState.flags[e.unlock] = true
			GameState.add_xp("diagnostics", 15)
			Router.toast("You learned something from the %s. Diagnostics +15" % KINDS[e.kind].to_lower())
		GameState.save()
		_fill_list.call_deferred()
