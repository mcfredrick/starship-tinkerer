## Top bar: day and time of day, pebs, spark, the active tea, and the tablet.
class_name Hud
extends PanelContainer

const PHASES := {"morning": "Morning", "day": "Afternoon", "evening": "Evening"}

var _day: Label
var _pebs: Label
var _spark: Label
var _tea: Label
var _tablet: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.box(Color(UI.CREAM, 0.94), 16, 8, true))
	# Inset so the web shell's share and music buttons in the top corners stay clear.
	UI.place(self, Control.PRESET_TOP_WIDE, Vector2(84, 12), Vector2(-168, 0))
	_day = UI.heading("", 22)
	_pebs = UI.heading("", 22, UI.AMBER_DARK)
	_spark = UI.label("", 20, UI.TEAL)
	_tea = UI.label("", 18, UI.MUTED)
	_tablet = UI.button("Tablet", Tablet.open, 18)
	add_child(UI.hbox([_day, UI.spacer(), _tea, _spark, _pebs, _tablet], 22))
	GameState.changed.connect(refresh)
	refresh()


func refresh() -> void:
	_day.text = "Day %d · %s" % [GameState.day, PHASES[GameState.phase]]
	_pebs.text = UI.pebs(GameState.pebs)
	_spark.text = "Spark " + "●".repeat(GameState.spark) + "○".repeat(GameState.MAX_SPARK - GameState.spark)
	_tea.text = Content.comforts.teas[GameState.buff].name if GameState.buff else ""
	var unread := Tablet.unread()
	_tablet.text = "Tablet  ● %d" % unread if unread else "Tablet"
