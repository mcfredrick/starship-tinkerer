## A fault drawn on the hull at its repair spot. Local +Z points out of the skin.
##
## Unfound faults only give themselves away with the odd wisp of smoke. Found ones show plainly
## (a glowing crack, spilled wires, a stuttering light, a crumple), and fixed ones leave a mark of
## the work: a weld bead, a new hatch plate, a steady lamp.
class_name FaultFx
extends Node3D

const HOT := Color("ff8a3d")
const METAL := Color("c9ccd4")
const DARK := Color("2a2430")
const WIRE_COLORS := [Color("e8a33d"), Color("3f8f8f"), Color("e48aa0")]

var look: String
var state := ""
var _seed := 0
var _parts: Node3D
var _lamp: ShaderMaterial
var _wisp_in := 0.0
var _spark_in := 0.0


func setup(fault_look: String, spot: int) -> void:
	look = fault_look
	_seed = spot


func show_state(new_state: String) -> void:
	if new_state == state:
		return
	state = new_state
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts)
	_lamp = null
	_wisp_in = randf_range(1.0, 4.0)
	if state == "hidden":
		return
	match look:
		"crack":
			_crack(state == "fixed")
		"flicker":
			_flicker(state == "fixed")
		"wires":
			_wires(state == "fixed")
		"dent":
			if state == "found":
				_dent()


## Plays the fix out on the hull, then settles into the fixed look. Resolves when it's done.
func play_fix() -> void:
	var out := global_basis.z
	match look:
		"crack":
			for i in 3:
				Fx.burst(self, global_position + global_basis.x * (i - 1) * 0.25, out, Color("ffd27a"), 30, 3.5)
				await get_tree().create_timer(0.18).timeout
			show_state("fixed")
			var glow := Stage.glow(HOT)
			for mi in _parts.get_children():
				mi.material_override = glow
			var t := create_tween()
			t.tween_interval(0.5)
			t.tween_callback(func():
				for mi in _parts.get_children():
					mi.material_override = Stage.toon(METAL, 0.6, 0.0))
			await t.finished
		"wires":
			var t := create_tween().set_parallel()
			for c in _parts.get_children():
				if c.has_meta("wire"):
					t.tween_property(c, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
			var hatch: Node3D = _parts.get_node("hatch")
			t.tween_property(hatch, "rotation:x", 0.0, 0.35).set_delay(0.3).set_trans(Tween.TRANS_BACK)
			await t.finished
			Fx.puff(self, global_position, out)
			Sfx.play("tick", 0.6)
			show_state("fixed")
		"dent":
			var t := create_tween()
			t.tween_property(_parts, "scale", Vector3(1.3, 1.3, 1.3), 0.12)
			t.tween_property(_parts, "scale", Vector3(0.01, 0.01, 0.01), 0.18)
			await t.finished
			Sfx.play("bonk", 1.4)
			Fx.puff(self, global_position, out)
			show_state("fixed")
		"flicker":
			show_state("fixed")
			var t := create_tween()
			t.tween_property(_parts, "scale", Vector3(1.6, 1.6, 1.6), 0.15)
			t.tween_property(_parts, "scale", Vector3.ONE, 0.25)
			await t.finished
	await get_tree().create_timer(0.35).timeout


func _process(delta: float) -> void:
	if state == "hidden":
		_wisp_in -= delta
		if _wisp_in <= 0:
			_wisp_in = randf_range(4.0, 8.0)
			Fx.burst(self, global_position, global_basis.z + Vector3.UP, Color(0.75, 0.72, 0.7, 0.7), 6, 0.5, 0.08,
				0.8, 1.4)
	elif state == "found":
		if _lamp:
			_lamp.set_shader_parameter("color", Color("ffe08a") if randf() > 0.25 else Color("4a3b2a"))
		_spark_in -= delta
		if _spark_in <= 0 and look in ["crack", "wires"]:
			_spark_in = randf_range(1.0, 2.5)
			var at := global_position
			if look == "wires":
				at = _parts.get_child(randi_range(1, WIRE_COLORS.size())).get_child(-1).global_position
			Fx.burst(self, at, global_basis.z, Color("ffe7a0"), 8, 2.0, 0.03, -6.0, 0.5)


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 977 + hash(look)
	return rng


func _segment(a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 6
	mesh.rings = 1
	var mi := Stage.mesh(mesh, mat, (a + b) / 2)
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.FORWARD if absf(dir.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(side, dir, side.cross(dir))
	_parts.add_child(mi)
	return mi


func _crack(fixed: bool) -> void:
	var rng := _rng()
	var pts: Array[Vector3] = []
	for i in 8:
		pts.append(Vector3(-0.38 + i * 0.11, rng.randf_range(-0.07, 0.07), 0.01))
	if fixed:
		var bead := Stage.toon(METAL, 0.6, 0.0)
		var ball := SphereMesh.new()
		ball.radius = 0.028
		ball.height = 0.04
		for i in pts.size() - 1:
			for k in 2:
				_parts.add_child(Stage.mesh(ball, bead, pts[i].lerp(pts[i + 1], k / 2.0)))
	else:
		var hot := Stage.glow(HOT)
		for i in pts.size() - 1:
			_segment(pts[i], pts[i + 1], 0.025, hot)


func _flicker(fixed: bool) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.09
	ring.outer_radius = 0.14
	var housing := Stage.mesh(ring, Stage.toon(DARK, 0.3, 0.0))
	housing.rotation.x = PI / 2
	_parts.add_child(housing)
	var bulb := SphereMesh.new()
	bulb.radius = 0.09
	bulb.height = 0.12
	if fixed:
		_parts.add_child(Stage.mesh(bulb, Stage.glow(Color("b8ffe0")), Vector3(0, 0, 0.02)))
	else:
		_lamp = Stage.glow(Color("ffe08a"))
		_parts.add_child(Stage.mesh(bulb, _lamp, Vector3(0, 0, 0.02)))


func _wires(fixed: bool) -> void:
	var plate := BoxMesh.new()
	plate.size = Vector3(0.42, 0.32, 0.03)
	if fixed:
		_parts.add_child(Stage.mesh(plate, Stage.toon(METAL, 0.5, 0.02), Vector3(0, 0, 0.02)))
		var rivet := SphereMesh.new()
		rivet.radius = 0.02
		rivet.height = 0.03
		for x in [-0.17, 0.17]:
			for y in [-0.12, 0.12]:
				_parts.add_child(Stage.mesh(rivet, Stage.toon(DARK), Vector3(x, y, 0.04)))
		return
	var hatch := Node3D.new()
	hatch.name = "hatch"
	hatch.position = Vector3(0, 0.16, 0.02)
	hatch.rotation.x = -1.9
	hatch.add_child(Stage.mesh(plate, Stage.toon(METAL, 0.5, 0.02), Vector3(0, -0.16, 0)))
	_parts.add_child(hatch)
	var hole := BoxMesh.new()
	hole.size = Vector3(0.38, 0.28, 0.02)
	_parts.add_child(Stage.mesh(hole, Stage.toon(DARK), Vector3(0, 0, 0.005)))
	var rng := _rng()
	for i in WIRE_COLORS.size():
		var wire := Node3D.new()
		wire.set_meta("wire", true)
		wire.position = Vector3(-0.1 + i * 0.1, 0.05, 0.02)
		_parts.add_child(wire)
		_parts.move_child(wire, 1 + i)
		var mat := Stage.toon(WIRE_COLORS[i], 0.2, 0.0)
		var last := Vector3.ZERO
		var droop := rng.randf_range(0.25, 0.4)
		for k in range(1, 6):
			var u := k / 5.0
			var p := Vector3(rng.randf_range(-0.03, 0.03) * k, -droop * u * u, 0.12 * u)
			var seg := _segment(last, p, 0.018, mat)
			seg.reparent(wire, false)
			last = p


func _dent() -> void:
	var dish := SphereMesh.new()
	dish.radius = 0.24
	dish.height = 0.06
	_parts.add_child(Stage.mesh(dish, Stage.toon(DARK.lightened(0.15), 0.0, 0.0), Vector3(0, 0, 0.01)))
	var crease := Stage.toon(DARK, 0.0, 0.0)
	var rng := _rng()
	for i in 5:
		var a := TAU * i / 5 + rng.randf_range(-0.3, 0.3)
		var inner := Vector3(cos(a), sin(a), 0) * 0.05 + Vector3(0, 0, 0.03)
		var outer := Vector3(cos(a), sin(a), 0) * rng.randf_range(0.2, 0.3) + Vector3(0, 0, 0.02)
		_segment(inner, outer, 0.012, crease)
