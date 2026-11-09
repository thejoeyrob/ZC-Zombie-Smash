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
	print("PINBALL REGRESSION PASS" if failed == 0 else "PINBALL REGRESSION FAILED")
	quit(failed)
