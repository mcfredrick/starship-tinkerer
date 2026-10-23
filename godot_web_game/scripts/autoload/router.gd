## Switches between screens with a fade and hosts the overlays every screen shares (dialogue, toasts).
##
## Screens are scripts under scripts/screens/ that build their own nodes. A screen may define
## `setup(params: Dictionary)`, called before it enters the tree.
extends Node

const FADE_TIME := 0.25

## Controls only inherit a theme from a parent Control or Window, and screens and overlays sit
## under plain Nodes and CanvasLayers, so each top-level control gets this one explicitly.
var theme: Theme
var screen: Node
var current := ""
var dialogue: DialogueBox
var _fade: ColorRect
var overlay: CanvasLayer
var _toasts: VBoxContainer


func _ready() -> void:
	UI.detect_device(get_window(), OS.get_cmdline_user_args())
	theme = UI.build_theme()
	overlay = CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	dialogue = DialogueBox.new()
	dialogue.theme = theme
	overlay.add_child(dialogue)
	_toasts = UI.vbox([], 8)
	_toasts.theme = theme
	UI.place(_toasts, Control.PRESET_CENTER_TOP, Vector2(-320, 86), Vector2(640, 0))
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_toasts)
	_fade = UI.full(ColorRect.new())
	_fade.color = Color("1b1626")
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_fade)
	if UI.compact:
		_add_rotate_prompt()


## The shop is laid out for a wide screen; a phone held upright gets a nudge to turn it.
func _add_rotate_prompt() -> void:
	var prompt := UI.full(ColorRect.new())
	prompt.color = Color("1b1626")
	var text := UI.heading("Turn your phone sideways\nto open the shop", 90, UI.CREAM)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_child(UI.full(text))
	overlay.add_child(prompt)
	var check := func():
		var view := get_viewport().get_visible_rect().size
		prompt.visible = view.y > view.x
	get_viewport().size_changed.connect(check)
	check.call()


func go(name: String, params := {}) -> void:
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, FADE_TIME if screen else 0.0)
	await t.finished
	if screen:
		screen.queue_free()
	screen = load("res://scripts/screens/%s.gd" % name).new()
	current = name
	if screen.has_method("setup"):
		screen.setup(params)
	get_tree().root.add_child.call_deferred(screen)
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)


## Plays a dialogue scene; resolves when it ends. `guest` is the generated customer the scene's
## "guest" speaker and {guest} tokens stand for.
func talk(scene_id: String, guest := "") -> void:
	await dialogue.play(scene_id, guest)


func toast(text: String, color := UI.TEAL) -> void:
	if color == UI.BAD:
		Sfx.play("bonk")
	var p := UI.panel(UI.label(text, 20, UI.CREAM), color, 10)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(p)
	var t := create_tween()
	t.tween_interval(2.4)
	t.tween_property(p, "modulate:a", 0.0, 0.5)
	t.tween_callback(p.queue_free)
