## Renders every hull in the kit with a sample loadout and livery into one contact sheet.
## Run: godot --path . --resolution 640x400 res://tools/hull_gallery.tscn -- --out=<path.png> [--hull=<id>]
## [--yaw=<radians>]
extends Node

const LOADOUTS := [
	{"engine": "engine_ring", "fins": "fin_feather", "cockpit": "cockpit_eye", "lights": "lights_stalks", "top": "gadget_magnet"},
	{"engine": "engine_sprint", "fins": "fin_swept", "cockpit": "cockpit_visor", "lights": "lights_bar", "top": "gadget_horn"},
	{"engine": "engine_hush", "fins": "fin_wing", "cockpit": "cockpit_bay", "lights": "lights_round"},
]
const PAINTS := [["teal", "marigold", "stripe"], ["rose", "cream", "dots"], ["dusk", "mint", "two_tone"],
	["scarlet", "slate", "zigzag"], ["sage", "brass", "bands"], ["plum", "cream", "checker"]]


func _ready() -> void:
	var out := "gallery.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	# The router's fade starts opaque and only clears when a screen opens.
	Router.overlay.visible = false
	var stage := Stage.new()
	add_child(stage)
	stage.spin_speed = 0.0
	stage.camera.distance = 9.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--yaw="):
			stage.camera.yaw = float(a.trim_prefix("--yaw="))
	stage.camera.refresh()
	var shots: Array[Image] = []
	var i := 0
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hull="):
			only = a.trim_prefix("--hull=")
	for hull in Content.parts.hulls:
		if only and hull != only:
			continue
		var paint: Array = PAINTS[i % PAINTS.size()]
		var model := ShipModel.new()
		stage.cradle.add_child(model)
		model.build({"hull": hull, "parts": LOADOUTS[i % LOADOUTS.size()], "paint": paint[0], "trim": paint[1],
			"livery": paint[2]})
		for f in 3:
			await get_tree().process_frame
		shots.append(get_viewport().get_texture().get_image())
		model.free()
		i += 1
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var sheet := Image.create(w * 3, h * ceili(shots.size() / 3.0), false, shots[0].get_format())
	for k in shots.size():
		sheet.blit_rect(shots[k], Rect2i(0, 0, w, h), Vector2i((k % 3) * w, (k / 3) * h))
	sheet.save_png(out)
	get_tree().quit()
