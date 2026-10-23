## A ship assembled at runtime from the Blender kit: a hull with parts snapped onto its sockets,
## dressed by material role (the suffix after the last "_" in each mesh name).
class_name ShipModel
extends Node3D

const KIT_SCENE := preload("res://assets/ships/kit.glb")
const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const GLOW := preload("res://shaders/glow.gdshader")
const FIXED := {
	"glass": Color("bfe6ec"), "metal": Color("a7a9b3"), "dark": Color("39343f"), "glow": Color("ffe08a"),
}
const GLOSS := {"glass": 1.0, "metal": 0.6, "paint": 0.25, "trim": 0.4}
const LINE := 0.035

static var _kit: Node

var hull: Node3D
var _materials := {}
var _highlight := 0.0


func build(b: Dictionary) -> void:
	if hull:
		hull.free()
	_materials.clear()
	if _kit == null:
		_kit = KIT_SCENE.instantiate()
	hull = _kit.get_node("hull_" + b.hull).duplicate()
	hull.transform = Transform3D.IDENTITY
	add_child(hull)
	for slot in b.parts:
		var part_id: String = b.parts[slot]
		var model: String = Content.part(part_id).model
		if slot == "fins":
			_attach(model, "fin_l", false)
			_attach(model, "fin_r", true)
		else:
			_attach(model, slot, false)
	for mi in hull.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _material(_role(mi.name), b)


func _attach(model: String, socket: String, mirror: bool) -> void:
	var sock: Node3D = hull.get_node("%s__socket_%s" % [hull.name, socket])
	var part: Node3D = _kit.get_node(model).duplicate()
	var t := sock.transform
	if mirror:
		t.basis = t.basis * Basis.from_scale(Vector3(-1, 1, 1))
	part.transform = t
	hull.add_child(part)


static func _role(mesh_name: String) -> String:
	return mesh_name.rsplit("_", true, 1)[-1]


func _material(role: String, b: Dictionary) -> Material:
	if role in _materials:
		return _materials[role]
	var m := ShaderMaterial.new()
	if role == "glow":
		m.shader = GLOW
		m.set_shader_parameter("color", FIXED.glow)
	else:
		m.shader = TOON
		var c: Color = FIXED.get(role, Color.WHITE)
		if role == "paint":
			c = Content.color(b.paint)
		elif role == "trim":
			c = Content.color(b.trim)
		m.set_shader_parameter("color", c)
		m.set_shader_parameter("gloss", GLOSS.get(role, 0.0))
		m.set_shader_parameter("highlight", _highlight)
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE
		outline.set_shader_parameter("width", LINE)
		m.next_pass = outline
	_materials[role] = m
	return m


## Brightens the whole ship, for a gentle pulse when something about it changes.
func set_highlight(amount: float) -> void:
	_highlight = amount
	for m in _materials.values():
		if m.shader == TOON:
			m.set_shader_parameter("highlight", amount)


func flash() -> void:
	var t := create_tween()
	t.tween_method(set_highlight, 1.0, 0.0, 0.5)


## A repair spot's position in this node's space.
func spot_position(index: int) -> Vector3:
	var spot: Node3D = hull.get_node("%s__spot_%d" % [hull.name, index])
	return hull.transform * spot.position


## Rough outward direction at a spot, for deciding whether it faces the camera.
func spot_normal(index: int) -> Vector3:
	var p := spot_position(index)
	return Vector3(p.x, p.y, p.z * 0.3).normalized()
