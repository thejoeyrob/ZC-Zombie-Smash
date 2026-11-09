extends SceneTree
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failed += 1
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var t := PinTable.new()
	root.add_child(t)
	t.set_process(false)
	t.enabled = true
	t.game_over = true
	t.pull(0.8)
	t.launch()
	check(t.in_play, "Launch did not start play")
	t._drain()
	check(t.balls_left == 3 and t.in_play and t.save_used, "Early drain must save one ball")
	t._drain()
	check(t.balls_left == 2, "Save must be single use")
	t.target_lit.fill(true)
	t.multiplier = 4
	t.reset_game()
	check(t.multiplier == 1 and not true in t.target_lit, "Restart leaves stale targets/multiplier")
	t.pull(0.8)
	t.launch()
	for i in range(3):
		t.nudge_cool = 0
		t.nudge()
	check(t.tilted, "Three rapid nudges should tilt")
	var old_score := t.score
	t._score(100, "bump")
	check(t.score == old_score, "Tilt must suppress scoring")
	var a := PinTable.new()
	var b := PinTable.new()
	root.add_child(a)
	root.add_child(b)
	for table in [a, b]:
		table.set_process(false)
		table.enabled = true
		table.pull(0.7)
		table.launch()
	for i in range(72):
		a._process(1.0 / 72.0)
	for i in range(120):
		b._process(1.0 / 120.0)
	check(a.ball.distance_to(b.ball) < 0.1, "Physics changes with headset refresh rate")
	# the stone door swallows the ball and the hole gives it back on the other side of the table
	var d := PinTable.new()
	root.add_child(d)
	d.set_process(false)
	d.enabled = true
	d.game_over = true
	d.pull(1.0)
	d.launch()
	d.ball = PinTable.DOOR_POS + Vector2(8, 0)
	d.vel = Vector2(-40, 20)
	d._step(1.0 / 120.0)
	check(d.in_portal, "Ball at the door should be taken in")
	var waited := 0
	while d.in_portal and waited < 400:
		d._step(1.0 / 120.0)
		waited += 1
	check(not d.in_portal and d.ball.distance_to(PinTable.EXIT_POS) < 1.0, "Ball should come out of the hole")
	check(waited > int(PinTable.PORTAL_TIME * 120.0) - 3, "Ball should stay inside the door for a moment")
	check(d.ball.x > 200.0, "The hole is on the far side of the table from the door")
	# the lane's flap: a ball coming down the lane from above is turned back, never returned to the plunger
	var g := PinTable.new()
	root.add_child(g)
	g.set_process(false)
	g.enabled = true
	g.game_over = true
	g.pull(0.1)
	g.launch()
	g.ball = Vector2(366, PinTable.GATE_Y - 20.0)
	g.vel = Vector2(0, 260)
	for i in range(240):
		g._step(1.0 / 120.0)
		check(not (g.ball.x > 352.0 and g.ball.y > PinTable.GATE_Y + 12.0 and g.ball.y < 700.0), "A ball fell back down the plunger lane")
		if g.ball.y > PinTable.GATE_Y + 12.0 and g.ball.x > 352.0:
			break
	# the weakest possible plunger shot still clears the flap
	var w := PinTable.new()
	root.add_child(w)
	w.set_process(false)
	w.enabled = true
	w.game_over = true
	w.pull(0.0)
	w.launch()
	var top := 9999.0
	for i in range(480):
		w._step(1.0 / 120.0)
		top = minf(top, w.ball.y)
	check(top < PinTable.GATE_Y - 40.0, "The weakest plunger shot must reach past the lane's flap (reached y=%d)" % int(top))
	# multiball: two balls locked behind the door, the next trip through the door releases three balls on the table
	var m := PinTable.new()
	root.add_child(m)
	m.set_process(false)
	m.enabled = true
	m.game_over = true
	m.pull(1.0)
	m.launch()
	for round in range(3):
		m.ball = PinTable.DOOR_POS + Vector2(8, 0)
		m.vel = Vector2(-40, 20)
		m.portal_cool = 0.0
		m.on_ramp = -1
		for i in range(400):
			m._step(1.0 / 120.0)
			if round < 2 and not m.in_portal and i > 20:
				break
			if m.multiball:
				break
	check(m.multiball and m.extra.size() == 2, "Third trip through the door should start multiball (balls: %d)" % m.extra.size())
	var before := m.balls_left
	# lose the main ball while others are alive: no life is lost
	m.ball_save = 0.0
	m.ball = Vector2(200, 900)
	m._step(1.0 / 120.0)
	check(m.balls_left == before and m.extra.size() == 1 and m.in_play, "Losing one ball of several must not cost a life (left %d/%d extra %d play %s ball %s portal %s ramp %d)" % [m.balls_left, before, m.extra.size(), m.in_play, m.ball, m.in_portal, m.on_ramp])
	m.ball = Vector2(200, 900)
	m._step(1.0 / 120.0)
	check(m.balls_left == before and not m.multiball and m.in_play, "Down to the last ball the game goes on as normal")
	for i in range(1200):
		m._step(1.0 / 120.0)
		check(is_finite(m.ball.x) and is_finite(m.ball.y), "Ball position went bad")
	# a hard shot cannot tunnel through a wall
	var f := PinTable.new()
	root.add_child(f)
	f.set_process(false)
	f.enabled = true
	f.game_over = true
	f.pull(1.0)
	f.launch()
	f.ball = Vector2(200, 400)
	f.vel = Vector2(2400, 0)
	for i in range(30):
		f._step(1.0 / 120.0)
		check(f.ball.x < 392.0 and f.ball.x > 4.0, "A fast ball went through a wall (x=%d)" % int(f.ball.x))
	print("PINBALL REGRESSION PASS" if failed == 0 else "PINBALL REGRESSION FAILED")
	quit(failed)
