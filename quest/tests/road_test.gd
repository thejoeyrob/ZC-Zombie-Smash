extends SceneTree
## Drives ROAD RUSH and BIG RIG with a simple autopilot and draws them to /tmp. Checks the games run: speed builds, time runs, a game can be lost and restarted.
## godot --path quest --rendering-driver opengl3 -s tests/road_test.gd -- out_prefix
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "/tmp/claude-0/shots/road"
	root.size = Vector2i(540, 822)
	var font = load("res://assets/fonts/DejaVuSansMono-Bold.ttf")
	var fails := 0
	for mode in ["racer", "trucker"]:
		var v := RoadView.new()
		root.add_child(v)
		v.setup(mode, font)
		for i in range(30):
			v.tick(1.0 / 60.0)
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("%s_%s_title.png" % [prefix, mode])
		v.set_input(0.0, true, false, true)             # start
		if v.state != "play":
			print("FAIL: ", mode, " did not start")
			fails += 1
		var shot := false
		for f in range(60 * 70):
			var seg_curve: float = v.seg_curve[v._seg_index(v.pos_z + RoadView.PLAYER_Z)]
			var axis := clampf(-v.player_x * 1.5 + seg_curve * 0.1, -1.0, 1.0)
			v.set_input(axis, true, v.speed > v.max_speed * 0.9 and absf(seg_curve) > 3.0, false)
			v.tick(1.0 / 60.0)
			if f == 60 * 12 and not shot:
				shot = true
				await process_frame
				await process_frame
				root.get_texture().get_image().save_png("%s_%s_play.png" % [prefix, mode])
			if v.state == "over":
				break
		print(mode, ": state=", v.state, " speed=", int(v.speed), " score=", v.score, " distance=", int(v.distance), " overtakes=", v.overtakes, " time_left=", int(v.time_left), " reason=", v.over_reason)
		if v.distance < 20000.0:
			print("FAIL: ", mode, " barely moved")
			fails += 1
		# let it run out of time with no gas, then restart
		for f in range(60 * 200):
			v.set_input(0.0, false, true, false)
			v.tick(1.0 / 60.0)
			if v.state == "over":
				break
		if v.state != "over":
			print("FAIL: ", mode, " never ended")
			fails += 1
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("%s_%s_over.png" % [prefix, mode])
		v.t = 2.0
		v.set_input(0.0, true, false, true)
		if v.state != "play" or v.score != 0:
			print("FAIL: ", mode, " did not restart")
			fails += 1
		v.queue_free()
		await process_frame
	print("ROAD TEST ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(fails)
