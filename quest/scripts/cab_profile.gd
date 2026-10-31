class_name CabProfile
extends RefCounted
## The outlines traced from the cabinet side-art pictures (see tools/make_cabinet_art.py). The 3D cabinet body is cut to the same shape,
## so the art covers the whole side of the machine.

const W_M := 1.1          # side-to-side... front-to-back length of a cabinet in metres
const H_M := 1.96         # height of a cabinet in metres
const Z_BACK := -0.80     # where the back of the picture lands in the cabinet's own space

static var _all := {}


static func get_profile(name: String) -> Dictionary:
	if _all.is_empty():
		var f := FileAccess.open("res://data/cab_profiles.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_all = d
	return _all.get(name, {})


## (left, right) edge of the outline at picture height v (0 top .. 1 bottom), as fractions of the picture width.
static func edges_at(poly: Array, v: float) -> Vector2:
	var lo := 1.0e9
	var hi := -1.0e9
	for i in range(poly.size()):
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % poly.size()]
		var v0: float = a[1]
		var v1: float = b[1]
		if (v0 <= v and v1 >= v) or (v1 <= v and v0 >= v):
			var t := 0.5 if absf(v1 - v0) < 0.00001 else (v - v0) / (v1 - v0)
			var x: float = lerpf(float(a[0]), float(b[0]), t)
			lo = minf(lo, x)
			hi = maxf(hi, x)
	return Vector2(lo, hi)


static func z_of(u: float) -> float:
	return Z_BACK + u * W_M


static func y_of(v: float) -> float:
	return (1.0 - v) * H_M
