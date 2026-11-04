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
	# seats: take one, swap, leave, come back
	assert(g.take_seat(1, "local"))
	assert(g.players[1].human and g.seat_of("local") == 1)
	assert(not g.take_seat(1, "guest"))                       # taken
	assert(g.take_seat(2, "guest", "GUEST"))
	g.leave_seat("local")
	assert(not g.players[1].human and g.players[1].name == "DR MANTIS")
	assert(g.seat_for("local", 2) == 1)                       # their old seat is free, the stool they chose is not
	assert(g.seat_for("local", 3) == 3)
	g.leave_seat("guest")
	assert(g.take_seat(0, "local"))
	var swapped := 0
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
		if int(t * 60.0) % 900 == 0:                               # stand up and sit down again mid-game now and then
			swapped += 1
			if swapped % 2 == 1:
				g.leave_seat("local")
			else:
				g.take_seat(g.seat_for("local", 0), "local")
		if g.winner >= 0 and g.winner != last_winner + 100:
			if last_winner != g.winner or true:
				wins += 1
				print("game ", wins, " won by ", g.players[g.winner].name, " after ", snappedf(t, 0.1), "s  ", g.message)
			# wait for the reset
			while g.winner >= 0:
				await process_frame
				if g.waiting_for_roll:
					g.roll_human()
	print("events: ", seen, "  seat swaps: ", swapped)
	print("BOARD TEST OK" if wins >= 3 else "BOARD TEST FAILED")
	quit()
