## Read-only game content loaded from data/: parts, world, comforts, reading and dialogue.
extends Node

var parts: Dictionary
var world: Dictionary
var comforts: Dictionary
var reading: Dictionary
var dialogue := {}


func _ready() -> void:
	parts = _json("res://data/parts.json")
	world = _json("res://data/world.json")
	comforts = _json("res://data/comforts.json")
	reading = _json("res://data/reading.json")
	# JSON and .txt aren't Godot resources; export_presets.cfg includes data/ by filter.
	for file in DirAccess.get_files_at("res://data/dialogue"):
		if file.ends_with(".txt"):
			dialogue.merge(Dialogue.parse(FileAccess.get_file_as_string("res://data/dialogue/" + file)))


func _json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "missing content file " + path)
	return JSON.parse_string(text)


func color(name: String) -> Color:
	return Color(parts.palette[name])


func part(id: String) -> Dictionary:
	return parts.parts[id]


func item(id: String) -> Dictionary:
	if comforts.teas.has(id):
		return comforts.teas[id]
	return comforts.cakes[id]


func portrait(pilot: String, expr: String) -> Texture2D:
	var path := "res://assets/portraits/%s_%s.png" % [pilot, expr if expr else "neutral"]
	return load(path)


func prop(id: String) -> Texture2D:
	return load("res://assets/props/%s.png" % id)
