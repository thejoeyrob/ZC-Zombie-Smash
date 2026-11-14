extends SceneTree
## Picks up a dart, an axe and a bowling ball the way a controller hand does (with the drawn hand tilted and rolled), swings and lets go,
## through the real hand loop, and checks the thing is carried sensibly and the throw lands.
## godot --headless --xr-mode off --fixed-fps 72 --path quest -s tests/hand_throw_sim.gd
var tg: ThrowGames
var fails := 0
var clock := 0.0
var cur := [{}, {}]
const TILT := -60.0


func _t(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _hand(pos: Vector3, aim: Vector3, grip: bool) -> Dictionary:
	var raw := Transform3D(Basis.looking_at(aim, Vector3.UP) * Basis.from_euler(Vector3(deg_to_rad(35.0), 0, 0)), pos)       # a controller is held with its own pitch
	var vis := raw
	vis.basis = raw.basis * Basis.from_euler(Vector3(deg_to_rad(TILT), 0, deg_to_rad(20.0)))
	return {"active": true, "bare": false, "xf": raw, "vis_xf": vis, "palm": pos, "tip": pos + aim * 0.15, "grip": pos, "aim_dir": aim.normalized(),
		"gripping": grip, "trigger": false, "grip_val": 1.0 if grip else 0.0, "trig_val": 0.0}


func _frame(h0: Dictionary, h1: Dictionary, at: Vector3, delta := 1.0 / 72.0) -> void:
	await process_frame
	clock += delta
	tg.update([h0, h1], delta, at, true)
	for g in tg.games:
		g.tick(delta)


func _idle() -> Dictionary:
	var h := _hand(Vector3(100, 100, 100), Vector3(0, 0, 1), false)
	h.active = false
	return h


func _carry(from: Vector3, to: Vector3, aim: Vector3, seconds: float, grip: bool, at: Vector3) -> void:
	var n := int(seconds * 72.0)
	for k in range(n):
		var u := float(k + 1) / float(n)
		await _frame(_hand(from.lerp(to, u), aim, grip), _idle(), at)


## A throw: accelerate from `start` along `dir` to `speed` over `swing` seconds, then let go while still moving.
func _swing(start: Vector3, dir: Vector3, speed: float, swing: float, aim: Vector3, at: Vector3) -> void:
	var n := int(swing * 72.0)
	var p := start
	for k in range(n):
		var u := float(k + 1) / float(n)
		p = start + dir * (speed * swing * 0.5 * u * u)
		await _frame(_hand(p, aim, true), _idle(), at)
	await _frame(_hand(p + dir * speed / 72.0, aim, false), _idle(), at)


func _wait(seconds: float, at: Vector3) -> void:
	for k in range(int(seconds * 72.0)):
		await _frame(_idle(), _idle(), at)


func _init() -> void:
	tg = ThrowGames.new()
	var world := Node3D.new()
	root.add_child(world)
	tg.build(world, null)
	var at := Vector3(0, 1.7, ShackAnnex.Z0 + 2.0)
	await _frame(_idle(), _idle(), at)
	_t(tg.active, "the hall is switched on when you stand in it")
	await _dart(at)
	await _axe(at)
	await _ball(at)
	print("HAND THROW SIM ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails > 0 else 0)


func _dart(at: Vector3) -> void:
	var d: DartsGame = tg.darts
	var t: Throwable = d.darts[0]
	var rack: Vector3 = t.node.global_position
	var aim := Vector3(-1, 0.04, 0).normalized()
	# walk the hand to the dart, close the fingers
	await _carry(rack + Vector3(0.4, 0.2, 0.2), rack, aim, 0.5, false, at)
	await _carry(rack, rack, aim, 0.3, true, at)
	_t(tg.held[0] == t and t.state == "held", "a dart is taken from its rack and a match starts there")
	# carried: the point faces where the hand points even though the drawn hand is tilted
	var nose: Vector3 = -t.node.global_transform.basis.z
	_t(nose.dot(aim) > 0.95, "the held dart points along the aim (%s)" % str(nose))
	var oche := Vector3(ShackAnnex.OCHE_X + 0.15, 1.55, float(ShackAnnex.DART_Z[0]))
	await _carry(rack, oche, aim, 1.0, true, at)
	await _swing(oche, Vector3(-1, 0.12, 0).normalized(), 4.5, 0.28, aim, at)
	await _wait(1.5, at)
	_t(t.state == "stuck", "a swing and let-go sticks the dart in the board (%s)" % t.state)
	_t(d.boards[0].last != "" and d.boards[0].last != "MISS", "and it scores (%s)" % d.boards[0].last)


func _axe(at: Vector3) -> void:
	var a: AxeGame = tg.axes
	var t: Throwable = a.axes[3]       # lane 1
	var rack: Vector3 = t.node.global_position
	var aim := Vector3(0, 0.1, 1).normalized()
	await _carry(rack + Vector3(0.2, 0.3, -0.5), rack, aim, 0.5, false, at)
	await _carry(rack, rack, aim, 0.3, true, at)
	_t(tg.held[0] == t and t.state == "held", "an axe is taken from its rack")
	var up: Vector3 = t.node.global_transform.basis.y
	_t(up.dot(Vector3.UP) > 0.9, "the held axe stands upright in the hand, head forward (%s)" % str(up))
	var line := Vector3(float(ShackAnnex.AXE_X[1]), 1.45, ShackAnnex.AXE_LINE_Z)
	await _carry(rack, line, aim, 1.0, true, at)
	await _swing(line, Vector3(0, 0.04, 1).normalized(), 5.0, 0.3, aim, at)
	for k in range(10):
		await _wait(0.25, at)
		if k % 4 == 3:
			print("  axe t=%.2f state=%s pos=%s vel=%s last=%s" % [0.25 * (k + 1), t.state, str(t.node.global_position), str(t.vel), str(a.lanes[1].last)])
	_t(t.state == "stuck", "a good overhand throw sticks the axe (%s)" % t.state)


func _ball(at: Vector3) -> void:
	var b: BowlingGame = tg.bowling
	var t: Throwable = b.balls[0]
	var rack: Vector3 = t.node.global_position
	var aim := Vector3(0, 0, 1)
	await _carry(rack + Vector3(-0.3, 0.2, -0.3), rack, aim, 0.5, false, at)
	await _carry(rack, rack, aim, 0.3, true, at)
	_t(tg.held[0] == t and t.state == "held", "a bowling ball is picked up from the return")
	var palm: Vector3 = tg.frames[0].origin
	var ball_at: Vector3 = t.node.global_position
	_t(ball_at.y > palm.y + 0.05 and ball_at.distance_to(palm) < 0.2, "the ball sits on top of the palm, not off to one side (%s)" % str(ball_at - palm))
	var start := Vector3(b.lane_x(0), 0.55, ShackAnnex.FOUL_Z - 1.3)
	await _carry(rack, start, aim, 0.8, true, at)
	await _swing(start, Vector3(0, 0.0, 1), 3.5, 0.45, aim, at)
	for k in range(22):
		await _wait(0.5, at)
		var bb := t.node as RigidBody3D
		if k % 4 == 3:
			print("  ball t=%.1f state=%s pos=%s vel=%s phase=%s" % [0.5 * (k + 1), t.state, str(bb.global_position), str(bb.linear_velocity), str(b.lanes[0].phase)])
	var s: Dictionary = b.lanes[0]
	_t(t.state != "held" and s.rolls[s.cur].size() + s.cur * 0 >= 0, "the ball leaves the hand")
	var knocked := 0
	for r in s.rolls:
		for x in r:
			knocked += int(x)
	_t(knocked > 0, "a roll down the middle knocks pins over (%d)" % knocked)
