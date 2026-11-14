extends SceneTree
## Renders the options board with the pointing beam to a PNG, to check the beam and dot show on top of the board.
## xvfb-run godot --rendering-driver opengl3 --xr-mode off --path quest --resolution 1280x720 -s tests/menu_pointer_view.gd -- OUT.png
func _init() -> void:
	var out := "/tmp/menu_pointer.png"
	for a in OS.get_cmdline_user_args():
		out = a
	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	cam.fov = 70
	var menu := VRMenu.new()
	menu.build(world, null, {"music": 0.5, "effects": 0.8, "turn": "smooth", "snap": 45, "turnspeed": 90, "walk": 1.5, "haptics": 1.0, "pointer": "right", "assist": "off", "handroll": 0, "handtilt": -60, "sports_feel": "social", "hud": "on", "resolution": "game", "sharp": 1.2, "refresh": "72", "smooth": "off", "fps": "off", "foveation": "external", "glow": "on", "screenlight": 0.85, "handmode": "auto", "scares": "on", "body": "full", "skin": "human_joeyrob", "topper": "yellow", "battle": "JORDAN", "reach": 0.0, "lift": 0.0})
	menu.set_open(true)
	menu.global_position = Vector3(0, 0, -1.2)
	await process_frame
	await process_frame
	menu.point(Vector3(0.45, -0.35, 0.1), (Vector3(0.1, 0.05, -1.2) - Vector3(0.45, -0.35, 0.1)).normalized(), false)
	for i in range(6):
		await process_frame
	await create_timer(0.3).timeout
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
