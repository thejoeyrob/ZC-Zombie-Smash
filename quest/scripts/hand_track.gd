class_name HandTrack
extends RefCounted
## Follows one hand so a throw can be read when the fingers let go: how fast the hand was moving and how fast it was turning over the last
## tenth of a second. Positions are world positions; the turn is the world-space angular velocity (radians a second).

const WINDOW := 0.12
var _t: Array = []
var _p: Array = []
var _b: Array = []


func push(t: float, pos: Vector3, basis: Basis) -> void:
	_t.append(t)
	_p.append(pos)
	_b.append(basis.orthonormalized())
	while _t.size() > 2 and t - float(_t[0]) > WINDOW * 1.5:
		_t.pop_front()
		_p.pop_front()
		_b.pop_front()


func clear() -> void:
	_t.clear()
	_p.clear()
	_b.clear()


func _oldest_index() -> int:
	var last := _t.size() - 1
	var i := last
	while i > 0 and float(_t[last]) - float(_t[i - 1]) <= WINDOW:
		i -= 1
	return i


func velocity() -> Vector3:
	if _t.size() < 2:
		return Vector3.ZERO
	var i := _oldest_index()
	var last := _t.size() - 1
	var dt := float(_t[last]) - float(_t[i])
	if i == last or dt < 0.016:
		return Vector3.ZERO
	return ((_p[last] as Vector3) - (_p[i] as Vector3)) / dt


## The speed the hand had at its fastest in the window (a throw is let go a moment after the hand has slowed down a little).
func peak_velocity() -> Vector3:
	var best := velocity()
	for j in range(1, _t.size()):
		var dt := float(_t[j]) - float(_t[j - 1])
		if dt > 0.004:
			var v := ((_p[j] as Vector3) - (_p[j - 1] as Vector3)) / dt
			if v.length() > best.length() * 1.35:
				best = v
	return best.lerp(velocity(), 0.35) if best.length() > velocity().length() else best


func angular_velocity() -> Vector3:
	if _t.size() < 2:
		return Vector3.ZERO
	var i := _oldest_index()
	var last := _t.size() - 1
	var dt := float(_t[last]) - float(_t[i])
	if i == last or dt < 0.016:
		return Vector3.ZERO
	var q: Basis = (_b[last] as Basis) * (_b[i] as Basis).inverse()
	var quat := q.get_rotation_quaternion()
	var angle := quat.get_angle()
	if angle > PI:
		angle -= TAU
	var axis := quat.get_axis()
	if not axis.is_finite() or axis.length() < 0.001:
		return Vector3.ZERO
	return axis.normalized() * angle / dt
