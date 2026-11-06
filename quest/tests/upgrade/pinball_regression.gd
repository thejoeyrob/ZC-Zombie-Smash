extends SceneTree
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failed += 1
func _initialize() -> void:
	var t := PinTable.new()
	root.add_child(t)
	t.set_process(false)
	t.enabled = true
	t.reset_game()
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
		table.reset_game()
		table.pull(0.7)
		table.launch()
	for i in range(72):
		a._process(1.0 / 72.0)
	for i in range(120):
		b._process(1.0 / 120.0)
	check(a.ball.distance_to(b.ball) < 0.1, "Physics changes with headset refresh rate")
	print("PINBALL REGRESSION PASS" if failed == 0 else "PINBALL REGRESSION FAILED")
	quit(failed)
