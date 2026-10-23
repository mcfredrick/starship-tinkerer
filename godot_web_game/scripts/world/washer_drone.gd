## A little pressure-washer drone that hovers off the hull and blasts a jet at where you point.
class_name WasherDrone
extends Node3D

const STANDOFF := 1.4
const JET_SPEED := 14.0

var _rotors: Array[Node3D] = []
var _jet: CPUParticles3D
var _hiss: AudioStreamPlayer
var _goal := Vector3.ZERO
var _aim := Vector3.ZERO
var _bob := 0.0


func _ready() -> void:
	var body := SphereMesh.new()
	body.radius = 0.22
	body.height = 0.32
	add_child(Stage.mesh(body, Stage.toon(Color("9fd8c0"), 0.4, 0.02)))
	var eye := SphereMesh.new()
	eye.radius = 0.07
	eye.height = 0.1
	add_child(Stage.mesh(eye, Stage.glow(Color("fff2b0")), Vector3(0, 0.06, -0.18)))
	var nozzle := CylinderMesh.new()
	nozzle.top_radius = 0.035
	nozzle.bottom_radius = 0.06
	nozzle.height = 0.3
	var barrel := Stage.mesh(nozzle, Stage.toon(Color("e8a33d"), 0.5, 0.02), Vector3(0, -0.1, -0.25))
	barrel.rotation.x = -PI / 2
	add_child(barrel)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.7, 0.03, 0.05)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.16
	disc.bottom_radius = 0.16
	disc.height = 0.015
	var blade := Stage.toon(Color(1, 1, 1), 0.0, 0.0)
	for angle in [PI / 4, -PI / 4]:
		var a := Stage.mesh(arm, Stage.toon(Color("5d6b78")), Vector3(0, 0.08, 0))
		a.rotation.y = angle
		add_child(a)
	for corner in [Vector3(0.25, 0.1, 0.25), Vector3(-0.25, 0.1, 0.25), Vector3(0.25, 0.1, -0.25), Vector3(-0.25, 0.1, -0.25)]:
		var rotor := Node3D.new()
		rotor.position = corner
		var spin := Stage.mesh(disc, blade)
		spin.transparency = 0.55
		rotor.add_child(spin)
		var tip := BoxMesh.new()
		tip.size = Vector3(0.3, 0.012, 0.04)
		rotor.add_child(Stage.mesh(tip, Stage.toon(Color("39343f"), 0.0, 0.0), Vector3(0, 0.01, 0)))
		add_child(rotor)
		_rotors.append(rotor)

	_jet = CPUParticles3D.new()
	_jet.amount = 60
	_jet.lifetime = 0.12
	_jet.local_coords = false
	_jet.direction = Vector3.FORWARD
	_jet.spread = 3.0
	_jet.initial_velocity_min = JET_SPEED
	_jet.initial_velocity_max = JET_SPEED
	_jet.gravity = Vector3.ZERO
	_jet.mesh = Fx.blob(0.04)
	_jet.color_ramp = Fx.fade(Color(0.8, 0.95, 1.0, 0.9))
	_jet.position = Vector3(0, -0.1, -0.42)
	_jet.emitting = false
	add_child(_jet)
	_hiss = Sfx.loop("spray", self, -8.0)


## Hovers off `point` along `normal`, facing it, and sprays when `spraying`.
func aim(point: Vector3, normal: Vector3, spraying: bool) -> void:
	var camera_side := (get_viewport().get_camera_3d().global_position - point).normalized()
	_goal = point + (normal + camera_side).normalized() * STANDOFF + Vector3.UP * 0.25
	_aim = point
	_jet.emitting = spraying
	_jet.lifetime = clampf(_goal.distance_to(point) / JET_SPEED, 0.05, 0.3)
	if spraying and not _hiss.playing:
		_hiss.play()
	elif not spraying and _hiss.playing:
		_hiss.stop()


func idle() -> void:
	_jet.emitting = false
	if _hiss.playing:
		_hiss.stop()


func _process(delta: float) -> void:
	_bob += delta
	if _goal != Vector3.ZERO:
		global_position = global_position.lerp(_goal + Vector3.UP * sin(_bob * 3.0) * 0.05, minf(delta * 8.0, 1.0))
		if global_position.distance_to(_aim) > 0.1:
			look_at(_aim, Vector3.UP)
	for r in _rotors:
		r.rotation.y += delta * 40.0
