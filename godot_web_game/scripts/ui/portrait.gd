## A character portrait: the authored cast's rendered sheet, or a generated customer assembled
## from paper-doll layers (see blender/dolls.py), each tinted by multiplying in one of their colors.
class_name Portrait
extends Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_pilot(pilot: Dictionary, expression: String) -> void:
	for c in get_children():
		c.queue_free()
	var expr := expression if expression else "neutral"
	if not pilot.get("generated", false):
		_layer(Content.portrait(pilot.id, expr), Color.WHITE)
		return
	for l in Walkins.doll_layers(pilot.look, expr):
		_layer(load("res://assets/dolls/%s.png" % l[0]), l[1])


func _layer(tex: Texture2D, tint: Color) -> void:
	var t := TextureRect.new()
	t.texture = tex
	t.modulate = tint
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UI.full(t))
