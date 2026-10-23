## Sprocket in 3D: sitting (tail swishing, head turning) or curled up asleep, colored by the role
## suffix on each mesh name (see blender/cat.py).
class_name CatModel
extends Node3D

const SCENE := preload("res://assets/props/cat.glb")
const COLORS := {
	"fur": Color("3b3742"), "cream": Color("f4f1ea"), "pink": Color("f4a6b8"), "ink": Color("1a0f24"),
	"collar": Color("2f9e5b"), "tag": Color("e8b931"), "eye": Color("b7e24a"),
}

var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _asleep := false
var _t := 0.0


func pose(asleep: bool) -> void:
	_asleep = asleep
	var source := SCENE.instantiate()
	var name := "cat_sleep" if asleep else "cat_sit"
	_body = source.get_node(name).duplicate()
	source.free()
	_body.transform = Transform3D.IDENTITY
	add_child(_body)
	_head = _body.get_node_or_null(name + "__head")
	_tail = _body.get_node_or_null(name + "__tail")
	for mi: MeshInstance3D in _body.find_children("*", "MeshInstance3D", true, false):
		var role: String = mi.name.rsplit("_", true, 1)[-1]
		mi.material_override = Stage.glow(COLORS.eye) if role == "eye" else Stage.toon(COLORS[role],
			0.8 if role == "tag" else 0.0, 0.0 if role in ["ink", "pink"] else 0.02)


func _process(delta: float) -> void:
	_t += delta
	if _asleep:
		_body.scale = Vector3(1.0, 1.0 + sin(_t * 1.6) * 0.03, 1.0)
		return
	if _tail:
		_tail.rotation.y = sin(_t * 1.3) * 0.35
	if _head:
		_head.rotation.y = sin(_t * 0.35) * 0.45


## A happy hop and a little cloud of hearts.
func purr() -> void:
	var t := create_tween()
	t.tween_property(_body, "position:y", 0.25, 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(_body, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Fx.burst(self, global_position + Vector3.UP * 1.4, Vector3.UP, Color("ff8fb1"), 10, 1.6, 0.09, 1.0, 1.2)


## Ears back, a quick swipe.
func swat() -> void:
	var t := create_tween()
	t.tween_property(_body, "rotation:z", 0.3, 0.06)
	t.tween_property(_body, "rotation:z", -0.15, 0.08)
	t.tween_property(_body, "rotation:z", 0.0, 0.15)
