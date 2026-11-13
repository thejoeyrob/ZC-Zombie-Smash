class_name SportAssist
extends RefCounted
## Social mode boosts effort, not score. Lateral aiming remains the player's.
static func launch(v: Vector3, forward: Vector3, distance: float, minimum: float, maximum: float) -> Vector3:
	if not v.is_finite() or v.length() < 0.8 or v.dot(forward) < 0.6:
		return v if v.is_finite() else Vector3.ZERO
	var result := v.normalized() * clampf(v.length() * 2.15, minimum, maximum)
	var travel := clampf(distance / maxf(result.dot(forward), 1.0), 0.0, 0.8)
	# Compensate most of gravity drop without pulling horizontal aim to a target.
	result.y += 0.5 * 9.8 * travel * 0.8
	return result.limit_length(maximum)

static func bowling(v: Vector3, at: Vector3, lane_x: float, head_z: float) -> Vector3:
	if v.z < 0.8:
		return v
	var out := v * 1.35
	out.z = clampf(out.z, 4.5, 10.5)
	out.y = clampf(out.y, -2.0, 1.4)
	var distance := maxf(head_z - at.z, 0.1)
	var projected := at.x + out.x / out.z * distance
	if absf(projected - lane_x) < 0.18:
		var pocket := lane_x + (-0.075 if projected < lane_x else 0.075)
		var desired := (pocket - at.x) / distance * out.z
		out.x = lerpf(out.x, desired, 0.85)
	return out.limit_length(12.0)
