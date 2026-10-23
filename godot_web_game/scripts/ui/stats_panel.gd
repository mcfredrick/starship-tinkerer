## Live ship numbers: a bar per stat with the change from a baseline, the race rating, and
## (for commissions) the pilot's wants as a checklist.
class_name StatsPanel
extends PanelContainer

const LABELS := {
	"thrust": "Thrust", "top_speed": "Top speed", "handling": "Handling", "grip": "Grip", "boost": "Boost",
	"mass": "Mass", "comfort": "Comfort", "noise": "Noise",
}
## Stats where lower is better, so a drop shows green.
const LOWER_IS_BETTER := ["mass", "noise"]

var baseline: Dictionary
var wants: Array = []
var pilot: Dictionary
var _rows := {}
var _rating: Label
var _wants_box: VBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.box(Color(UI.CREAM, 0.95), 18, 14, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	for s in LABELS:
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(110, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var value := UI.label("", 17, UI.INK)
		value.custom_minimum_size.x = 70
		grid.add_child(UI.label(LABELS[s], 17, UI.MUTED))
		grid.add_child(bar)
		grid.add_child(value)
		_rows[s] = [bar, value]
	_rating = UI.heading("", 20, UI.TEAL)
	_wants_box = UI.vbox([], 4)
	add_child(UI.vbox([UI.heading("Ship readout", 22), grid, _rating, _wants_box], 8))


func show_build(build: Dictionary) -> void:
	var stats := ShipStats.compute(build, Content.parts)
	for s in LABELS:
		var bar: ProgressBar = _rows[s][0]
		var value: Label = _rows[s][1]
		bar.value = stats[s]
		var delta: float = stats[s] - baseline.get(s, stats[s])
		var good := delta < 0 if s in LOWER_IS_BETTER else delta > 0
		value.text = "%d" % stats[s]
		if absf(delta) >= 0.5:
			value.text += "  %+d" % delta
			value.add_theme_color_override("font_color", UI.GOOD if good else UI.BAD)
		else:
			value.add_theme_color_override("font_color", UI.INK)
		var fill := UI.box(UI.TEAL if s not in LOWER_IS_BETTER else UI.ROSE, 6, 0)
		bar.add_theme_stylebox_override("fill", fill)
	_rating.text = "Race rating %d" % ShipStats.rating(stats)

	for c in _wants_box.get_children():
		c.queue_free()
	if wants.is_empty():
		return
	_wants_box.add_child(UI.heading("%s wants" % pilot.short, 20))
	for w in wants:
		var met := Grading.want_met(w, stats, build, pilot)
		var line := UI.label(("✓  " if met else "○  ") + w.label, 18, UI.GOOD if met else UI.INK)
		_wants_box.add_child(line)
