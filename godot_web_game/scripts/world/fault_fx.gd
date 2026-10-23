## A fault drawn on the hull at its repair spot. Local +Z points out of the skin.
##
## Unfound faults only give themselves away with the odd wisp of smoke. Found ones show plainly
## (a glowing crack, wires behind a hatch, a stuttering light, a crumple, a smoking coupling, a
## torn breach) and change as multi-step repairs progress. Fixed ones leave a mark of the work: a
## weld bead, a new hatch plate, a steady lamp, a patch.
class_name FaultFx
extends Node3D

const HOT := Color("ff8a3d")
const METAL := Color("c9ccd4")
const DARK := Color("2a2430")
const WIRE_COLORS := [Color("e8a33d"), Color("3f8f8f"), Color("e48aa0")]

var look: String
var state := ""
## Repair steps finished so far.
var step := 0
## Whether the first step opens a bolted hatch, so it stays shut until then.
var bolted := false
var _seed := 0
var _parts: Node3D
var _lamp: ShaderMaterial
var _smoke: CPUParticles3D
var _wisp_in := 0.0
var _spark_in := 0.0


func setup(fault_look: String, spot: int, opens_with_bolts: bool) -> void:
	look = fault_look
	_seed = spot
	bolted = opens_with_bolts


func show_state(new_state: String, new_step := 0) -> void:
	if new_state == state and new_step == step:
		return
	state = new_state
	step = new_step
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts)
	_lamp = null
	_smoke = null
	_wisp_in = randf_range(1.0, 4.0)
	if state == "hidden":
		return
	var fixed := state == "fixed"
	match look:
		"crack":
			_crack(fixed)
		"flicker":
			_flicker(fixed)
		"wires":
			_hatch_fault(fixed, _wires)
		"smoke":
			_hatch_fault(fixed, _coupling)
		"breach":
			_breach(fixed)
		"dent":
			if not fixed:
				_dent()


func _opened() -> bool:
	return not bolted or step >= 1


## Shows the result of finishing a step partway through a repair.
func play_step(done: int) -> void:
	var was_closed := not _opened()
	show_state(state, done)
	Fx.puff(self, global_position, global_basis.z)
	if was_closed and _opened() and _parts.has_node("hatch"):
		var hatch: Node3D = _parts.get_node("hatch")
		var open := hatch.rotation.x
		hatch.rotation.x = 0.0
		var t := create_tween()
		t.tween_property(hatch, "rotation:x", open, 0.4).set_trans(Tween.TRANS_BACK)
		Sfx.play("tick", 0.5)
		await t.finished
	await get_tree().create_timer(0.35).timeout


## Plays the fix out on the hull, then settles into the fixed look. Resolves when it's done.
func play_fix() -> void:
	var out := global_basis.z
	match look:
		"crack", "breach":
			for i in 3:
				Fx.burst(self, global_position + global_basis.x * (i - 1) * 0.25, out, Color("ffd27a"), 30, 3.5)
				await get_tree().create_timer(0.18).timeout
			show_state("fixed", step)
			var glow := Stage.glow(HOT)
			var beads := _parts.find_children("bead*", "", false, false)
			for mi in beads:
				mi.material_override = glow
			var t := create_tween()
			t.tween_interval(0.5)
			t.tween_callback(func():
				for mi in beads:
					mi.material_override = Stage.toon(METAL, 0.6, 0.0))
			await t.finished
		"wires", "smoke":
			var t := create_tween().set_parallel()
			for c in _parts.get_children():
				if c.has_meta("inner"):
					t.tween_property(c, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
			var hatch: Node3D = _parts.get_node("hatch")
			t.tween_property(hatch, "rotation:x", 0.0, 0.35).set_delay(0.3).set_trans(Tween.TRANS_BACK)
			await t.finished
			Fx.puff(self, global_position, out)
			Sfx.play("tick", 0.6)
			show_state("fixed", step)
		"dent":
			var t := create_tween()
			t.tween_property(_parts, "scale", Vector3(1.3, 1.3, 1.3), 0.12)
			t.tween_property(_parts, "scale", Vector3(0.01, 0.01, 0.01), 0.18)
			await t.finished
			Sfx.play("bonk", 1.4)
			Fx.puff(self, global_position, out)
			show_state("fixed", step)
		"flicker":
			show_state("fixed", step)
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
		if _spark_in <= 0 and look in ["crack", "wires", "smoke", "breach"]:
			_spark_in = randf_range(1.0, 2.5)
			var tips := _parts.find_children("tip*", "", true, false)
			var at: Vector3 = tips.pick_random().global_position if tips else global_position
			if look == "breach" and step == 0:
				Fx.burst(self, global_position, global_basis.z, Color(0.9, 0.95, 1.0, 0.7), 12, 2.5, 0.07, 0.0, 0.6)
			else:
				Fx.burst(self, at, global_basis.z, Color("ffe7a0"), 8, 2.0, 0.03, -6.0, 0.5)


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 977 + hash(look)
	return rng


func _segment(a: Vector3, b: Vector3, radius: float, mat: Material, parent: Node3D = null) -> MeshInstance3D:
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
	(parent if parent else _parts).add_child(mi)
	return mi


func _beads(pts: Array[Vector3]) -> void:
	var bead := Stage.toon(METAL, 0.6, 0.0)
	var ball := SphereMesh.new()
	ball.radius = 0.028
	ball.height = 0.04
	for i in pts.size() - 1:
		for k in 2:
			var mi := Stage.mesh(ball, bead, pts[i].lerp(pts[i + 1], k / 2.0))
			mi.name = "bead%d_%d" % [i, k]
			_parts.add_child(mi)


func _crack(fixed: bool) -> void:
	var rng := _rng()
	var pts: Array[Vector3] = []
	for i in 8:
		pts.append(Vector3(-0.38 + i * 0.11, rng.randf_range(-0.07, 0.07), 0.01))
	if fixed:
		_beads(pts)
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


## An access hatch over `inside`: bolted shut until opened, swung up while open, and replaced with
## a fresh riveted plate once fixed.
func _hatch_fault(fixed: bool, inside: Callable) -> void:
	var plate := BoxMesh.new()
	plate.size = Vector3(0.42, 0.32, 0.03)
	var rivet := SphereMesh.new()
	rivet.radius = 0.02
	rivet.height = 0.03
	if fixed or not _opened():
		_parts.add_child(Stage.mesh(plate, Stage.toon(METAL if fixed else METAL.darkened(0.25), 0.5, 0.02),
			Vector3(0, 0, 0.02)))
		for x in [-0.17, 0.17]:
			for y in [-0.12, 0.12]:
				var r := Stage.mesh(rivet, Stage.toon(DARK), Vector3(x, y, 0.04))
				r.name = "tip_%d_%d" % [x * 100, y * 100]
				_parts.add_child(r)
		if not fixed and look == "smoke":
			_add_smoke(1.0)
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
	inside.call()


func _wires() -> void:
	var rng := _rng()
	for i in WIRE_COLORS.size():
		var wire := Node3D.new()
		wire.set_meta("inner", true)
		wire.position = Vector3(-0.1 + i * 0.1, 0.05, 0.02)
		_parts.add_child(wire)
		var mat := Stage.toon(WIRE_COLORS[i], 0.2, 0.0)
		var last := Vector3.ZERO
		var droop := rng.randf_range(0.25, 0.4)
		for k in range(1, 6):
			var u := k / 5.0
			var p := Vector3(rng.randf_range(-0.03, 0.03) * k, -droop * u * u, 0.12 * u)
			var seg := _segment(last, p, 0.018, mat, wire)
			if k == 5:
				seg.name = "tip"
			last = p


## A drive coupling inside the hatch: a scorched drum with a hot seam, smoking less once rewired.
func _coupling() -> void:
	var core := Node3D.new()
	core.set_meta("inner", true)
	_parts.add_child(core)
	var drum := CylinderMesh.new()
	drum.top_radius = 0.1
	drum.bottom_radius = 0.1
	drum.height = 0.3
	var d := Stage.mesh(drum, Stage.toon(Color("4a4250"), 0.3, 0.02), Vector3(0, 0, 0.06))
	d.rotation.z = PI / 2
	core.add_child(d)
	var seam := TorusMesh.new()
	seam.inner_radius = 0.1
	seam.outer_radius = 0.125
	var s := Stage.mesh(seam, Stage.glow(HOT if step < 2 else Color("ffd27a")), Vector3(0, 0, 0.06))
	s.rotation.z = PI / 2
	s.name = "tip"
	core.add_child(s)
	_add_smoke(1.0 if step < 2 else 0.35)


func _add_smoke(amount: float) -> void:
	_smoke = CPUParticles3D.new()
	_smoke.amount = int(18 * amount) + 2
	_smoke.lifetime = 1.6
	_smoke.local_coords = false
	_smoke.direction = Vector3.BACK
	_smoke.spread = 20.0
	_smoke.initial_velocity_min = 0.4
	_smoke.initial_velocity_max = 0.8
	_smoke.gravity = Vector3(0, 0.9, 0)
	_smoke.scale_amount_min = 0.8
	_smoke.scale_amount_max = 2.0
	_smoke.mesh = Fx.blob(0.08)
	_smoke.color_ramp = Fx.fade(Color(0.35, 0.32, 0.36, 0.75))
	_smoke.position = Vector3(0, 0, 0.08)
	_parts.add_child(_smoke)


## A hull breach: a hole with torn petals bent outward. Pulling the dent flattens them; the weld
## then leaves a patch ringed with a bead.
func _breach(fixed: bool) -> void:
	var ring: Array[Vector3] = []
	for i in 13:
		var a := TAU * i / 12
		ring.append(Vector3(cos(a), sin(a), 0) * 0.24 + Vector3(0, 0, 0.02))
	if fixed:
		var patch := CylinderMesh.new()
		patch.top_radius = 0.25
		patch.bottom_radius = 0.25
		patch.height = 0.02
		var p := Stage.mesh(patch, Stage.toon(METAL, 0.5, 0.02), Vector3(0, 0, 0.01))
		p.rotation.x = PI / 2
		_parts.add_child(p)
		_beads(ring)
		return
	var hole := CylinderMesh.new()
	hole.top_radius = 0.17 if step == 0 else 0.1
	hole.bottom_radius = hole.top_radius
	hole.height = 0.01
	var h := Stage.mesh(hole, Stage.glow(Color("0d0a12")), Vector3(0, 0, 0.012))
	h.rotation.x = PI / 2
	_parts.add_child(h)
	var petal := BoxMesh.new()
	petal.size = Vector3(0.1, 0.14, 0.015)
	var mat := Stage.toon(METAL.darkened(0.3), 0.3, 0.02)
	var rng := _rng()
	for i in 7:
		var a := TAU * i / 7 + rng.randf_range(-0.2, 0.2)
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(a), sin(a), 0) * 0.17 + Vector3(0, 0, 0.02)
		pivot.rotation.z = a - PI / 2
		pivot.rotation.x = (rng.randf_range(0.6, 1.1) if step == 0 else 0.05)
		pivot.add_child(Stage.mesh(petal, mat, Vector3(0, 0.07, 0)))
		_parts.add_child(pivot)
	if step >= 1:
		var hot := Stage.glow(HOT)
		for i in 12:
			_segment(ring[i] * 0.8, ring[i + 1] * 0.8, 0.02, hot)


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
