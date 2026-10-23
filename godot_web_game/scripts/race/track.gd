## A closed race track: a smooth centerline sampled by distance, with tangents, left normals and
## curvature, so racers can live in track space (distance along it, offset across it).
class_name Track
extends RefCounted

const STEP := 2.0

var length := 0.0
var half_width := 11.0
var points := PackedVector3Array()
var tangents := PackedVector3Array()
var lefts := PackedVector3Array()
var curvature := PackedFloat32Array()


## `control` is a closed loop of (x, height, z) points, smoothed with Catmull-Rom.
static func from_points(control: Array, width: float) -> Track:
	var t := Track.new()
	t.half_width = width
	var dense: Array[Vector3] = []
	var n := control.size()
	for i in n:
		var p0: Vector3 = control[(i - 1 + n) % n]
		var p1: Vector3 = control[i]
		var p2: Vector3 = control[(i + 1) % n]
		var p3: Vector3 = control[(i + 2) % n]
		for k in 40:
			var u := k / 40.0
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u))
	# Resample at even spacing so lookups by distance are a simple index.
	var total := 0.0
	var acc := [0.0]
	for i in range(1, dense.size() + 1):
		total += dense[i % dense.size()].distance_to(dense[i - 1])
		acc.append(total)
	t.length = total
	var j := 0
	var s := 0.0
	while s < total:
		while acc[j + 1] < s:
			j += 1
		var f: float = (s - acc[j]) / maxf(acc[j + 1] - acc[j], 0.0001)
		t.points.append(dense[j].lerp(dense[(j + 1) % dense.size()], f))
		s += STEP
	var m := t.points.size()
	for i in m:
		var fwd := (t.points[(i + 1) % m] - t.points[(i - 1 + m) % m])
		fwd.y = 0
		fwd = fwd.normalized()
		t.tangents.append(fwd)
		t.lefts.append(Vector3(fwd.z, 0, -fwd.x))
	for i in m:
		var a := t.tangents[(i - 2 + m) % m]
		var b := t.tangents[(i + 2) % m]
		# Signed: positive when the track bends left.
		var turn := atan2(a.x * b.z - a.z * b.x, a.dot(b))
		t.curvature.append(-turn / (4 * STEP))
	return t


func index(s: float) -> int:
	return int(fposmod(s, length) / STEP) % points.size()


func position(s: float, d: float) -> Vector3:
	var i := index(s)
	var f := fposmod(fposmod(s, length), STEP) / STEP
	var j := (i + 1) % points.size()
	var center := points[i].lerp(points[j], f)
	return center + lefts[i].lerp(lefts[j], f).normalized() * d


func heading(s: float) -> Vector3:
	return tangents[index(s)]


func kappa(s: float) -> float:
	return curvature[index(s)]


## The direction of travel including slope, for pitching ships and gates over the hills. The
## simulation itself stays flat in track space.
func forward(s: float) -> Vector3:
	return (position(s + STEP, 0) - position(s - STEP, 0)).normalized()


## A track from its data/tracks.json entry: control points [[x, height, z], ...] and a width.
static func from_spec(spec: Dictionary) -> Track:
	var pts: Array = spec.points.map(func(p): return Vector3(p[0], p[1], p[2]))
	return from_points(pts, float(spec.width))
