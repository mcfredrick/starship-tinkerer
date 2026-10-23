## Visual-novel style conversation overlay: a portrait, a name plate, typed-out text and choices.
class_name DialogueBox
extends Control

signal finished

const CHARS_PER_SEC := 55.0

var _runner: Dialogue.Runner
var _portrait: Portrait
## The generated customer this conversation is with: the "guest" speaker and {guest} tokens.
var _guest := ""
var _name_plate: PanelContainer
var _name: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _hint: Label
var _typing := false
var _type_tween: Tween
var _waiting_choice := false


func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var shade := UI.full(ColorRect.new())
	shade.color = Color(0.08, 0.05, 0.12, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_portrait = Portrait.new()
	UI.place(_portrait, Control.PRESET_BOTTOM_LEFT, Vector2(20, -540), Vector2(432, 540))
	add_child(_portrait)

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.box(UI.CREAM, 22, 22, true, UI.PAPER.darkened(0.2)))
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 380
	box.offset_right = -40
	box.offset_top = -230
	box.offset_bottom = -30
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.add_theme_font_size_override("normal_font_size", 24)
	_text.add_theme_font_size_override("italics_font_size", 23)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_text)

	_name = UI.heading("", 24, UI.CREAM)
	_name_plate = UI.panel(_name, UI.TEAL, 6)
	UI.place(_name_plate, Control.PRESET_BOTTOM_LEFT, Vector2(410, -270), Vector2.ZERO)
	_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_plate)

	_hint = UI.label("click to continue", 16, UI.MUTED)
	UI.place(_hint, Control.PRESET_BOTTOM_RIGHT, Vector2(-240, -66), Vector2(180, 24))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_hint)

	_choices = UI.vbox([], 10)
	UI.place(_choices, Control.PRESET_CENTER_RIGHT, Vector2(-580, -220), Vector2(520, 0))
	add_child(_choices)


func play(scene_id: String, guest := "") -> void:
	assert(Content.dialogue.has(scene_id), "no dialogue scene " + scene_id)
	_guest = guest
	_runner = Dialogue.Runner.new(Content.dialogue[scene_id], _command, _has_flag)
	visible = true
	_advance()
	await finished


func _gui_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if click:
		_next()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_next()
		get_viewport().set_input_as_handled()


func _next() -> void:
	if _waiting_choice:
		return
	if _typing:
		_type_tween.kill()
		_text.visible_ratio = 1.0
		_typing = false
		return
	_advance()


func _advance() -> void:
	var s := _runner.step()
	match s.t:
		"end":
			visible = false
			finished.emit()
		"say":
			_show_line(s)
		"choice":
			_show_choice(s)


func _show_line(s: Dictionary) -> void:
	for c in _choices.get_children():
		c.queue_free()
	_waiting_choice = false
	var text := _fill(s.text)
	_portrait.visible = s.who not in ["", "you"]
	if s.who == "":
		_name_plate.visible = false
		_text.text = "[i]%s[/i]" % text
	else:
		_name_plate.visible = true
		if s.who == "you":
			_name.text = GameState.player.name
		else:
			var pilot := GameState.pilot(_guest if s.who == "guest" else s.who)
			_name.text = pilot.short
			_portrait.show_pilot(pilot, s.expr)
		_text.text = text
	_hint.visible = true
	_type_out()


## "! story <flag>" marks the guest's storylet; everything else is the game's.
func _command(cmd: String, args: Array) -> void:
	if cmd == "story":
		GameState.story_flag(_guest, args[0])
		GameState.save()
	else:
		GameState.run_command(cmd, args)


## A "?" check reads the guest's storylet flags as well as the game's.
func _has_flag(flag: String) -> bool:
	return GameState.flags.has(flag) or (GameState.stories.has(_guest) and GameState.stories[_guest].flags.has(flag))


## Fills the player's name and pronouns, and for a guest their name, ship and request.
func _fill(text: String) -> String:
	if _guest:
		var pilot := GameState.pilot(_guest)
		text = text.replace("{guest}", pilot.short).replace("{guest_ship}", GameState.ships[pilot.ship].name)
		if not GameState.job.is_empty():
			text = text.replace("{request}", GameState.job_spec(GameState.job.id).request)
	return GameState.fill(text)


func _type_out() -> void:
	_typing = true
	_text.visible_ratio = 0.0
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_ratio", 1.0, _text.get_parsed_text().length() / CHARS_PER_SEC)
	_type_tween.finished.connect(func(): _typing = false)


func _show_choice(s: Dictionary) -> void:
	_waiting_choice = true
	_hint.visible = false
	for i in s.options.size():
		var b := UI.button(_fill(s.options[i].text), _on_choice.bind(i), 22)
		b.custom_minimum_size.x = 500
		_choices.add_child(b)


func _on_choice(i: int) -> void:
	_waiting_choice = false
	for c in _choices.get_children():
		c.queue_free()
	_runner.choose(i)
	_advance()
