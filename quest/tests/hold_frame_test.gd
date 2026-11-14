extends SceneTree
## What a hand holds follows where it points, not the tilt the visible hand is drawn with.
## godot --headless --path quest -s tests/hold_frame_test.gd
var fails := 0

func _t(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL: ", what)
		fails += 1

func _init() -> void:
	# a controller hand: the drawn hand is tilted -60 degrees and rolled, the aim ray points level along -z
	var raw := Transform3D(Basis.from_euler(Vector3(0.3, 0.2, 0.0)), Vector3(0, 1.4, 5))
	var tilted := raw
	tilted.basis = raw.basis * Basis.from_euler(Vector3(deg_to_rad(-60.0), 0, deg_to_rad(25.0)))
	var h := {"xf": raw, "vis_xf": tilted, "aim_dir": Vector3(0.2, 0.05, -1).normalized(), "bare": false}
	var b := ThrowGames.hold_frame(h)
	_t((-b.z).dot(h.aim_dir) > 0.999, "forward is the aim, however the hand is drawn")
	_t(b.y.dot(Vector3.UP) > 0.99, "a dart or axe is held upright, not rolled with the hand")
	h.vis_xf = Transform3D(raw.basis * Basis.from_euler(Vector3(deg_to_rad(-60.0), 0, 0)), raw.origin)
	_t(ThrowGames.hold_frame(h).is_equal_approx(b), "changing the drawn tilt changes nothing")
	# a bare hand: wrist to knuckles
	var bare := {"xf": Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), Vector3.ZERO), "vis_xf": Transform3D.IDENTITY, "aim_dir": Vector3.UP, "bare": true}
	_t((-ThrowGames.hold_frame(bare).z).dot(Vector3(0, 0, -1)) > 0.999, "a bare hand uses the line of the hand, not the pointing finger")
	# pointing straight up must still give a usable frame
	var up := {"xf": raw, "vis_xf": raw, "aim_dir": Vector3.UP, "bare": false}
	var ub := ThrowGames.hold_frame(up)
	_t(ub.is_finite() and absf(ub.determinant() - 1.0) < 0.001, "straight up gives a valid frame")
	# a dart is carried nose forward, a ball above the palm
	var palm := Vector3(0, 1.3, 5)
	var f := Transform3D(b, palm)
	var dart_at: Vector3 = (f * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.012, -0.05))).origin
	_t(((dart_at - palm).normalized()).dot(h.aim_dir) > 0.9, "the dart sits ahead of the hand along the aim")
	var ball_at: Vector3 = (f * Transform3D(Basis.IDENTITY, Vector3(0, 0.095, -0.04))).origin
	_t(ball_at.y > palm.y + 0.08, "the ball rests above the palm")
	print("HOLD FRAME TESTS ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails > 0 else 0)
