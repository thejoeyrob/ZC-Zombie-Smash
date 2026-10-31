extends SceneTree
## Plays the pinball table headless: launches a ball and flips for a while, printing where the ball goes.

func _init() -> void:
	var t := PinTable.new()
	root.add_child(t)
	t.enabled = true
	t._build_segments()
	t.reset_game()
	t.launch()
	var steps := 0
	var log_t := 0.0
	var flipped := 0
	for i in range(60 * 40):
		var pulse := int(float(i) / 7.0) % 2 == 0
		var l := t.in_play and t.ball.y > 690.0 and t.ball.x < 205.0 and pulse
		var r := t.in_play and t.ball.y > 690.0 and t.ball.x >= 195.0 and pulse
		t.flippers(l, r)
		t._process(1.0 / 60.0)
		log_t += 1.0 / 60.0
		if log_t >= 2.0:
			log_t = 0.0
			print("t=%d ball=(%.0f,%.0f) vel=(%.0f,%.0f) in_play=%s score=%d left=%d" % [i / 60, t.ball.x, t.ball.y, t.vel.x, t.vel.y, str(t.in_play), t.score, t.balls_left])
		if t.game_over:
			t.launch()
	print("DONE score ", t.score, " best ", t.best)
	quit()
