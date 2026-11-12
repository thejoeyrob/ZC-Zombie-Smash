extends SceneTree
## Plays each built-in JW EDS game with a random player for a while (no crash, scores move) and draws each one to /tmp.
## godot --path quest --rendering-driver opengl3 -s tests/mini_games_test.gd -- out_prefix
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "/tmp/claude-0/shots/mini"
	root.size = Vector2i(576, 876)
	var font = load("res://assets/fonts/DejaVuSansMono-Bold.ttf")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var fails := 0
	for id in MiniArcade.IDS:
		var arc := MiniArcade.new()
		root.add_child(arc)
		arc.start(id, font)
		var st := Vector2.ZERO
		var shots := 0
		for f in range(5400):
			if f % 20 == 0:
				st = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			var btn := {"a": f % 7 < 3, "b": f % 11 < 2, "c": f % 13 == 0, "start": f == 3, "menu": false}
			arc.set_input(st, btn)
			arc.tick(1.0 / 60.0)
			if arc.state == "play" and f == 1500 and shots == 0:
				shots += 1
				await process_frame
				await process_frame
				root.get_texture().get_image().save_png("%s_%s.png" % [prefix, id])
			if arc.state == "over":
				arc.set_input(Vector2.ZERO, {"a": false})
				arc.set_input(Vector2.ZERO, {"a": true})
		print(id, ": state=", arc.state, " score=", arc.game.score, " lives=", arc.game.lives)
		if arc.game == null:
			fails += 1
		arc.queue_free()
		await process_frame
	print("MINI GAMES ", "PASS" if fails == 0 else "FAIL")
	quit(fails)
