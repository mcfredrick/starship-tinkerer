## Compiles every script so parse errors show up without visiting each screen.
## Run as a scene so autoloads exist: godot --headless --path godot_web_game res://tools/check_scripts.tscn
extends Node


func _ready() -> void:
	var bad := 0
	for path in _scripts("res://scripts") + _scripts("res://scenes"):
		var s: GDScript = load(path)
		if s == null or not s.can_instantiate():
			bad += 1
			push_error("does not compile: " + path)
	print("%d scripts failed" % bad if bad else "all scripts compile")
	get_tree().quit(1 if bad else 0)


func _scripts(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out += _scripts(dir + "/" + d)
	return out
