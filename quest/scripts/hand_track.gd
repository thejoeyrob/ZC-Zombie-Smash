class_name HandTrack
extends RefCounted
## Follows one hand so a throw can be read when the fingers let go: how fast the hand was moving and how fast it was turning over the last
## tenth of a second. Positions are world positions; the turn is the world-space angular velocity (radians a second).

const WINDOW := 0.12
var _t: Array = []
var _p: Array = []
var _b: Array = []


func push(t: float, pos: Vector3, basis: Basis) -> void:
	if not pos.is_finite() or not basis.is_finite():
		clear()
		return
	if not _t.is_empty():
		var dt: float = t - float(_t.back())
		if dt <= 0.0:
			return
		# Do not turn a tracking recovery or player teleport into a fast throw.
		if dt > 0.25 or pos.distance_to(_p.back()) / dt > 30.0:
			clear()
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
	var average := velocity()
	var best := average
	if _t.size() < 2:
		return best
	var last: float = _t.back()
	# Measure across several samples, not a single noisy tracking frame.
	# Only recent intervals count; old backswing peaks must not reverse release.
	for j in range(_t.size() - 1, 0, -1):
		if last - float(_t[j]) > 0.055:
			break
		for i in range(j - 1, -1, -1):
			var dt := float(_t[j]) - float(_t[i])
			if dt > 0.065:
				break
			if dt < 0.028:
				continue
			var candidate: Vector3 = (_p[j] - _p[i]) / dt
			if candidate.dot(average) >= 0.0 and candidate.length() > best.length():
				best = candidate
	return best.lerp(average, 0.35).limit_length(18.0)


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
