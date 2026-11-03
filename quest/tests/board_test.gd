extends SceneTree
## Plays the lounge board game by itself (the human seat is rolled by the test) and checks that a game always finishes.
func _initialize() -> void:
	Engine.time_scale = 30.0
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var g := BoardGame.new()
	root.add_child(g)
	g.build(ThemeDB.fallback_font)
	var wins := 0
	var seen := {}
	g.event.connect(func(n): seen[n] = int(seen.get(n, 0)) + 1)
	var t := 0.0
	var last_winner := -1
	while wins < 3 and t < 4000.0:
		await process_frame
		t += 1.0 / 60.0 * 1.0
		if g.waiting_for_roll:
			g.roll_human()
		if g.winner >= 0 and g.winner != last_winner + 100:
			if last_winner != g.winner or true:
				wins += 1
				print("game ", wins, " won by ", g.players[g.winner].name, " after ", snappedf(t, 0.1), "s  ", g.message)
			# wait for the reset
			while g.winner >= 0:
				await process_frame
				if g.waiting_for_roll:
					g.roll_human()
	print("events: ", seen)
	print("BOARD TEST OK" if wins >= 3 else "BOARD TEST FAILED")
	quit()
