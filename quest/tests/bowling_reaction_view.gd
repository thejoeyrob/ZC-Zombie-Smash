extends SceneTree
## Renders each comic reaction of the bowling screen to PNG files (needs a display: xvfb-run ... --rendering-driver opengl3 -s tests/bowling_reaction_view.gd -- OUTDIR)

func _init() -> void:
	var out := "/tmp"
	for a in OS.get_cmdline_user_args():
		out = a
	var root3d := Node3D.new()
	root.add_child(root3d)
	var r := BowlingReaction.new()
	r.build(root3d, Vector3.ZERO, null, 0)
	await process_frame
	await process_frame
	r.viewport.get_texture().get_image().save_png(out + "/rx_idle.png")
	for case in [["STRIKE!", 10], ["SPARE!", 3], ["7 PINS", 7], ["GUTTER BALL", 0]]:
		r.react(case[0], case[1], 0)
		for k in range(40):
			await process_frame
		await create_timer(0.2).timeout
		r._animate(BowlingReaction.RUN)
		await process_frame
		await process_frame
		r.viewport.get_texture().get_image().save_png(out + "/rx_" + str(case[0]).replace(" ", "_").replace("!", "") + ".png")
		# a frame mid-animation too
		r.react(case[0], case[1], 0)
		r._animate(0.18)
		await process_frame
		await process_frame
		r.viewport.get_texture().get_image().save_png(out + "/rx_" + str(case[0]).replace(" ", "_").replace("!", "") + "_early.png")
	quit()
