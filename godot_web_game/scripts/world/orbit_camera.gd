## Camera that circles a target. Dragging rotates it and the wheel zooms when `interactive` is on.
class_name OrbitCamera
extends Camera3D

var target := Vector3(0, 1.6, 0)
var yaw := 0.6
var pitch := -0.32
var distance := 11.0
var interactive := false
var min_distance := 5.0
var max_distance := 16.0
var _dragging := false
## When set, a press it returns true for belongs to someone else (the scrub brush) and won't orbit.
var drag_filter: Callable


func _ready() -> void:
	fov = 45.0
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_dragging = event.pressed and not (event.button_index == MOUSE_BUTTON_LEFT and drag_filter.is_valid()
				and drag_filter.call(event.position))
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = maxf(distance * 0.92, min_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = minf(distance * 1.08, max_distance)
		refresh()
	elif event is InputEventMouseMotion and _dragging:
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch - event.relative.y * 0.006, -1.2, 0.35)
		refresh()
	elif event is InputEventMagnifyGesture:
		distance = clampf(distance / event.factor, min_distance, max_distance)
		refresh()


## Glides to look at `point` from along `out`, `reach` away. Resolves when it arrives.
func fly_to(point: Vector3, out: Vector3, reach: float, time := 0.6) -> void:
	var to_yaw := atan2(out.x, out.z)
	to_yaw = yaw + wrapf(to_yaw - yaw, -PI, PI)
	var to_pitch := clampf(-asin(clampf(out.y, -1.0, 1.0)), -1.2, 0.35)
	await glide(point, to_yaw, to_pitch, reach, time)


func glide(to_target: Vector3, to_yaw: float, to_pitch: float, to_distance: float, time := 0.6) -> void:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "target", to_target, time)
	t.tween_property(self, "yaw", to_yaw, time)
	t.tween_property(self, "pitch", to_pitch, time)
	t.tween_property(self, "distance", to_distance, time)
	t.tween_method(func(_v): refresh(), 0.0, 1.0, time)
	await t.finished


func refresh() -> void:
	var offset := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * distance
	position = target + offset
	look_at(target)
