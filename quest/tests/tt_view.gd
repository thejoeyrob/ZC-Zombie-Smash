extends SceneTree
## Draws TRUCKIN' & DRIVIN' to pictures: title, driving by day (a job under way), a sheep, night, game over. godot --path quest --rendering-driver opengl3 -s tests/tt_view.gd -- /tmp/prefix
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "/tmp/claude-0/shots/tt"
	root.size = Vector2i(420, 640)
	var v := TTView.new()
	root.add_child(v)
	v.setup(load("res://assets/fonts/DejaVuSansMono-Bold.ttf"))
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(prefix + "_title.png")
	v.start_game()
	var g: TTGame = v.game
	g.next_sheep = 900.0
	g.next_night = 2600.0
	g.next_job = 99999.0
	var shots := {}
	for f in range(60 * 120):
		# the same simple bot as the unit test
		var want := g.lane
		for e in g.items:
			if bool(e.done) or TTGame.PICKUPS.has(str(e.type)):
				continue
			var d: float = float(e.z) - g.distance
			if d > -40.0 and d < 380.0 and absf(float(e.lane) - g.x) < 0.8:
				for cand in [g.lane - 1, g.lane + 1]:
					if cand >= 0 and cand <= 4:
						want = cand
						break
		if want == g.lane:
			for e in g.items:
				if (e.type == "crumb" or e.type == "coin") and not bool(e.done) and float(e.z) - g.distance > 0.0 and float(e.z) - g.distance < 400.0:
					want = int(e.lane)
					break
		g.set_lane(want)
		if not g.sheep.is_empty() and bool(g.sheep.baa) and not bool(g.sheep.cleared) and g.time - float(g.sheep.baa_at) > 0.2:
			g.horn()
		v.tick(1.0 / 60.0)
		if v.state == "over":
			break
		var tag := ""
		if not g.job.is_empty() and int(g.job.count) >= 4 and not shots.has("job"):
			tag = "job"
		elif not g.sheep.is_empty() and not shots.has("sheep") and float(g.sheep.z) - g.distance < 330.0:
			tag = "sheep"
		elif not g.night.is_empty() and not shots.has("night") and g.distance > float(g.night.start) + 300.0:
			tag = "night"
		elif g.stage == 2 and not shots.has("sub") and f > 600:
			tag = "sub"
		if tag != "":
			shots[tag] = true
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png("%s_%s.png" % [prefix, tag])
	print("shots: ", shots.keys(), " distance ", int(g.distance))
	quit()
