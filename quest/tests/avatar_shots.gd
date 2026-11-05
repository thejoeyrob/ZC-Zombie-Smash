extends SceneTree
## Draws every skin on a row, standing, waving, seated and from behind, and saves pictures. Run under xvfb with --rendering-driver opengl3.
func _initialize() -> void:
	var out := "/tmp/claude-0/avatars"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.06, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.75)
	e.ambient_light_energy = 0.8
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	root.add_child(sun)
	var key := OmniLight3D.new()
	key.position = Vector3(0, 2.5, 2.5)
	key.omni_range = 12.0
	key.light_energy = 1.5
	root.add_child(key)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 10)
	floor_m.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.2, 0.26)
	floor_m.material_override = fm
	root.add_child(floor_m)
	var avs: Array = []
	for i in range(VRAvatar.SKINS.size()):
		var av := VRAvatar.new()
		root.add_child(av)
		av.build(false)
		av.apply_skin(VRAvatar.SKINS[i].id)
		avs.append(av)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 40
	cam.current = true
	get_root().size = Vector2i(1920, 600)
	var step := 0.0
	for f in range(90):
		step += 1.0 / 30.0
		for i in range(avs.size()):
			avs[i].pose_idle(Vector3((i - (avs.size() - 1) / 2.0) * 0.9, 0, 0), PI, 1.0 / 30.0)
		await process_frame
	cam.look_at_from_position(Vector3(0, 1.0, -7.4), Vector3(0, 0.95, 0), Vector3.UP)
	for i in range(avs.size()):
		avs[i].pose_idle(Vector3((i - (avs.size() - 1) / 2.0) * 0.9, 0, 0), 0.0, 1.0 / 30.0)
	for f in range(4):
		await process_frame
	cam.look_at_from_position(Vector3(0, 1.0, 7.4), Vector3(0, 0.95, 0), Vector3.UP)
	for i in range(avs.size()):
		avs[i].pose_idle(Vector3((i - (avs.size() - 1) / 2.0) * 0.9, 0, 0), PI, 1.0 / 30.0)
	for f in range(4):
		await process_frame
	get_root().get_texture().get_image().save_png(out + "/front.png")
	cam.look_at_from_position(Vector3(0, 1.0, -7.4), Vector3(0, 0.95, 0), Vector3.UP)
	for i in range(avs.size()):
		avs[i].pose_idle(Vector3((i - (avs.size() - 1) / 2.0) * 0.9, 0, 0), 0.0, 1.0 / 30.0)
	for f in range(4):
		await process_frame
	get_root().get_texture().get_image().save_png(out + "/back.png")
	print("AVATAR SHOTS DONE")
	quit()
