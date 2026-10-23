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


func _ready() -> void:
	fov = 45.0
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_dragging = event.pressed
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


func refresh() -> void:
	var offset := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * distance
	position = target + offset
	look_at(target)
