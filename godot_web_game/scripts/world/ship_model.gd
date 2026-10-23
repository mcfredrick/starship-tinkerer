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
## Fault visuals are modeled at a handy size and scaled up to read from the workbench's distance.
const FAULT_SCALE := 1.9
## Paint sweeps cover this span along the ship, comfortably more than the longest hull.
const SWEEP_LENGTH := 9.0

static var _kit: Node

var hull: Node3D
var _materials := {}
var _faults: Array[FaultFx] = []
## Part nodes on the hull by slot, so a swap can animate just that part.
var _slots := {}
var _highlight := 0.0
var _build: Dictionary


func build(b: Dictionary) -> void:
	if hull:
		hull.free()
	_materials.clear()
	_slots.clear()
	_build = b
	if _kit == null:
		_kit = KIT_SCENE.instantiate()
	hull = _kit.get_node("hull_" + b.hull).duplicate()
	hull.transform = Transform3D.IDENTITY
	add_child(hull)
	for slot in b.parts:
		var part_id: String = b.parts[slot]
		var model: String = Content.part(part_id).model
		if slot == "fins":
			_slots[slot] = [_attach(model, "fin_l", false), _attach(model, "fin_r", true)]
		else:
			_slots[slot] = [_attach(model, slot, false)]
	for mi in hull.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _material(_role(mi.name), b)
	_show_faults(b.get("faults", []))


func _show_faults(faults: Array) -> void:
	while _faults.size() > faults.size():
		_faults.pop_back().queue_free()
	for i in faults.size():
		var f: Dictionary = faults[i]
		if i == _faults.size():
			var fx := FaultFx.new()
			fx.setup(Content.parts.faults[f.type].look, f.spot)
			fx.transform = _spot_frame(f.spot).scaled_local(Vector3.ONE * FAULT_SCALE)
			add_child(fx)
			_faults.append(fx)
		_faults[i].show_state("fixed" if f.get("fixed", false) else ("found" if f.get("found", false) else "hidden"))


func fault_fx(index: int) -> FaultFx:
	return _faults[index]


## A frame at a repair spot with +Z pointing out of the skin.
func _spot_frame(index: int) -> Transform3D:
	var out := spot_normal(index)
	var side := Vector3.UP.cross(out)
	side = side.normalized() if side.length() > 0.1 else Vector3.RIGHT
	return Transform3D(Basis(side, out.cross(side), out), spot_position(index) + out * 0.08)


func _attach(model: String, socket: String, mirror: bool) -> Node3D:
	var sock: Node3D = hull.get_node("%s__socket_%s" % [hull.name, socket])
	var part: Node3D = _kit.get_node(model).duplicate()
	var t := sock.transform
	if mirror:
		t.basis = t.basis * Basis.from_scale(Vector3(-1, 1, 1))
	part.transform = t
	hull.add_child(part)
	return part


## Lifts the part in `slot` away and fades it out. Call before rebuilding with the new part.
func lift_off(slot: String) -> void:
	for part: Node3D in _slots.get(slot, []):
		part.reparent(self)
		var t := create_tween().set_parallel()
		t.tween_property(part, "position:y", part.position.y + 1.6, 0.45).set_ease(Tween.EASE_IN)
		t.tween_property(part, "scale", Vector3.ONE * 0.01, 0.45).set_ease(Tween.EASE_IN)
		t.chain().tween_callback(part.queue_free)
	_slots.erase(slot)


## Drops the part in `slot` onto its socket from above with a bounce and a puff.
func drop_in(slot: String) -> void:
	for part: Node3D in _slots.get(slot, []):
		var rest := part.position
		part.position.y += 2.0
		var t := create_tween()
		t.tween_property(part, "position", rest, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		t.tween_callback(func(): Fx.puff(self, part.global_position, Vector3.UP))


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
		if role == "paint":
			var finish: Dictionary = Content.parts.finishes[b.get("finish", "gloss")]
			m.set_shader_parameter("gloss", finish.gloss)
			m.set_shader_parameter("shadow", finish.shadow)
			m.set_shader_parameter("pearl", finish.get("pearl", 0.0))
		m.set_shader_parameter("highlight", _highlight)
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE
		outline.set_shader_parameter("width", LINE)
		m.next_pass = outline
	_materials[role] = m
	return m


## Sweeps a new paint color over `role` from nose to tail, with mist riding the front.
func sweep_paint(role: String, old_color: Color) -> void:
	var m: ShaderMaterial = _materials.get(role)
	if m == null:
		return
	var axis := global_basis.z.normalized()
	var origin := global_position - axis * SWEEP_LENGTH / 2
	m.set_shader_parameter("old_color", old_color)
	m.set_shader_parameter("sweep_origin", origin)
	m.set_shader_parameter("sweep_axis", axis)
	var t := create_tween()
	t.tween_method(func(v: float): m.set_shader_parameter("sweep", v), 0.0, SWEEP_LENGTH, 0.9)
	for i in 4:
		var at := origin + axis * SWEEP_LENGTH * (i + 0.5) / 4 + Vector3.UP * 0.6
		get_tree().create_timer(0.9 * i / 4).timeout.connect(
			func(): Fx.burst(self, at, Vector3.DOWN, Color(Content.color(_paint_name(role)), 0.6), 16, 1.2, 0.1, -1.0, 0.7))
	t.tween_callback(func(): m.set_shader_parameter("sweep", 1000.0))


## Brightens the whole ship, for a gentle pulse when something about it changes.
func set_highlight(amount: float) -> void:
	_highlight = amount
	for m in _materials.values():
		if m.shader == TOON:
			m.set_shader_parameter("highlight", amount)


func flash() -> void:
	var t := create_tween()
	t.tween_method(set_highlight, 1.0, 0.0, 0.5)


func _paint_name(role: String) -> String:
	return _build[role]


## A repair spot's position in this node's space.
func spot_position(index: int) -> Vector3:
	var spot: Node3D = hull.get_node("%s__spot_%d" % [hull.name, index])
	return hull.transform * spot.position


## Rough outward direction at a spot, for deciding whether it faces the camera.
func spot_normal(index: int) -> Vector3:
	var p := spot_position(index)
	return Vector3(p.x, p.y, p.z * 0.3).normalized()
