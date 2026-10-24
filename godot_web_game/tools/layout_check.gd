## Layout check: opens every screen state the sweep covers, then shows every dialogue line, every
## choice and every tablet page, and fails if any visible control reaches past the edge of the screen.
## Controls grow to fit their text, so off-screen is how a cut-off button or line shows up.
## Run at both shapes (test.sh does):
##   godot --headless res://tools/layout_check.tscn
##   godot --headless res://tools/layout_check.tscn -- --phone
extends Node

## Same states as tools/sweep.sh, minus the shot-only arguments.
const CASES := [
	"--screen=title", "--screen=title --form=custom", "--screen=title --credits",
	"--fixture=job --screen=shop", "--fixture=job --screen=workbench --tab=Scan",
	"--fixture=crake --screen=workbench --tab=Repair", "--fixture=scanned --screen=workbench --repair=0",
	"--fixture=brindle --screen=workbench --repair=0", "--fixture=scanned --screen=workbench --tab=Wash",
	"--fixture=scanned --screen=workbench --tab=Parts", "--fixture=scanned --screen=workbench --tab=Paint",
	"--fixture=scanned --screen=workbench --tab=Tune", "--fixture=scanned --screen=workbench --tab=Mischief",
	"--fixture=finished --screen=handoff", "--fixture=evening --screen=tea", "--fixture=hawker --screen=market",
	"--fixture=evening --screen=night", "--fixture=levelup --screen=night", "--fixture=board --screen=board",
	"--fixture=walkin --screen=workbench --tab=Repair", "--fixture=hawker --screen=hawker",
	"--fixture=yard --screen=yard", "--fixture=drawers --screen=drawers", "--fixture=close_pass --screen=event",
	"--fixture=harvest --screen=event --id=harvest", "--fixture=lumen --screen=event --id=lumen_reach --lit",
	"--fixture=evening --screen=race", "--fixture=evening --screen=race --race=shadow_run --at=600",
	"--fixture=evening --screen=race --race=garden_dash --at=600", "--fixture=evening --screen=race --paused",
]
## Slack for anti-aliased borders and shadows.
const TOLERANCE := 2.0

var _failures: Array = []


func _ready() -> void:
	GameState.save_path = "user://layout_save.json"
	# Headless ignores --resolution. A 16:9 phone is the tightest shape the canvas meets: wider phones
	# only add room at the sides.
	get_window().size = Vector2i(960, 540) if UI.compact else Vector2i(1280, 720)
	var shape := "phone" if UI.compact else "desktop"
	for c in CASES:
		await _check_case(c)
	await _check_dialogue()
	await _check_tablet()
	for f in _failures:
		push_error("[%s] %s" % [shape, f])
	print("LAYOUT FAILED: %d (%s)" % [_failures.size(), shape] if _failures else "layout passed (%s)" % shape)
	get_tree().quit(1 if _failures else 0)


func _check_case(case: String) -> void:
	var args := {}
	for a in case.split(" ", false):
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if "fixture" in args:
		Fixtures.apply(args.fixture)
	await Router.go(args.screen, args)
	await _settle()
	_check(get_tree().root, case)


## Every say and choice in every scene, shown in the real dialogue box over the shop. A walk-in is on
## the bench so guest lines have someone to be.
func _check_dialogue() -> void:
	Fixtures.apply("walkin")
	await Router.go("shop")
	var box := Router.dialogue
	box._guest = GameState.job_spec(GameState.job.id).pilot
	box.visible = true
	for scene_id in Content.dialogue:
		for s in Content.dialogue[scene_id]:
			if s.t == "say":
				box._show_line(s)
			elif s.t == "choice":
				box._show_choice(s)
			else:
				continue
			await _settle(0.0)
			_check(box, "dialogue %s: %s" % [scene_id, s.get("text", s.get("options", [{}])[0].get("text", ""))])
	box.visible = false


func _check_tablet() -> void:
	for id in Content.reading.entries:
		Tablet.open(id)
		await _settle(0.0)
		_check(Router.overlay, "tablet " + id)
		for c in Router.overlay.get_children():
			if c is Tablet:
				c.free()


## Lets layout, deferred refits and entry tweens finish.
func _settle(seconds := 0.6) -> void:
	for i in 3:
		await get_tree().process_frame
	if seconds > 0:
		await get_tree().create_timer(seconds).timeout


func _check(root: Node, where: String) -> void:
	var view := get_viewport().get_visible_rect().grow(TOLERANCE)
	for c: Control in root.find_children("*", "Control", true, false):
		if not c.is_visible_in_tree() or c.size == Vector2.ZERO or _clipped(c):
			continue
		var r: Rect2 = c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)
		if not view.encloses(r):
			var text: String = c.text if "text" in c and c.text is String else ""
			_failures.append("%s: %s %s \"%s\" at %s" % [where, c.get_class(), c.name, text.left(50), r])


## Children of a scroll area or other clipping parent may extend past it on purpose; only the clipper
## itself has to be on screen.
func _clipped(c: Control) -> bool:
	var p := c.get_parent()
	while p:
		if p is Control and p.clip_contents:
			return true
		p = p.get_parent()
	return false
