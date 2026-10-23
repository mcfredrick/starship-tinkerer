## Base for repair minigames: a dimmed overlay with a card holding a title, instructions and a
## play area. Subclasses draw in `area` and call `finish(score)` with a score from 0 to 1.
class_name Minigame
extends Control

signal finished(score: float)

const CARD := Vector2(820, 560)

## How forgiving this attempt is (1.0 = level-one tinkerer, no tea). Set before adding.
var leniency := 1.0
var area: Control
var _status: Label
var _done := false


func _ready() -> void:
	UI.full(self)
	var shade := UI.full(ColorRect.new())
	shade.color = Color(0.06, 0.04, 0.1, 0.55)
	add_child(shade)
	area = Control.new()
	area.custom_minimum_size = Vector2(760, 330)
	area.draw.connect(_draw_area)
	area.gui_input.connect(_area_input)
	_status = UI.label("", 20, UI.MUTED)
	var card := UI.panel(UI.vbox([UI.heading(title(), 30), UI.label(instructions(), 19, UI.INK, true), area,
		_status], 10), UI.CREAM, 26)
	UI.place(card, Control.PRESET_CENTER, -CARD / 2, CARD)
	UI.fit(card)
	add_child(card)


func title() -> String:
	return ""


func instructions() -> String:
	return ""


func _draw_area() -> void:
	pass


func _area_input(_event: InputEvent) -> void:
	pass


func status(text: String) -> void:
	_status.text = text


func finish(score: float) -> void:
	if _done:
		return
	_done = true
	var words := "Lovely work!" if score >= 0.8 else ("That'll hold." if score >= 0.55 else "A bit rough, but fixed.")
	status("%s  Quality %d%%" % [words, roundi(score * 100)])
	await get_tree().create_timer(1.3).timeout
	finished.emit(score)
	queue_free()
