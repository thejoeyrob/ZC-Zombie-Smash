extends SceneTree
## One avatar from four sides (and standing, seated, crouched, leaning) so the body shape and joints can be checked. Args: --skin=id --out=dir
func _initialize() -> void:
	var out := "/tmp/claude-0/avatars"
	var skin := "survivor"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		if a.begins_with("--skin="): skin = a.substr(7)
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
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_m.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.25, 0.25, 0.3)
	floor_m.material_override = fm
	root.add_child(floor_m)
	var av := VRAvatar.new()
	root.add_child(av)
	av.build(false)
	av.apply_skin(skin)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 35
	cam.current = true
	get_root().size = Vector2i(640, 960)
	var views := {"front": Vector3(0, 1.0, 4.2), "side": Vector3(4.2, 1.0, 0), "back": Vector3(0, 1.0, -4.2), "tq": Vector3(3.0, 1.2, 3.0)}
	for f in range(60):
		av.pose_idle(Vector3.ZERO, PI, 1.0 / 30.0)
		await process_frame
	for v in views:
		cam.look_at_from_position(views[v], Vector3(0, 0.9, 0), Vector3.UP)
		for f in range(3):
			av.pose_idle(Vector3.ZERO, PI, 1.0 / 30.0)
			await process_frame
		get_root().get_texture().get_image().save_png("%s/solo_%s.png" % [out, v])
	# crouching, looking down with hands forward
	var b := Basis(Vector3.UP, PI)
	for f in range(40):
		var head := Transform3D(b * Basis(Vector3.RIGHT, -0.5), Vector3(0, 1.0, 0.1))
		av.update(head, [Vector3(-0.2, 0.7, -0.1) * Vector3(1, 1, -1), Vector3(0.2, 0.7, -0.1) * Vector3(1, 1, -1)], [true, true], 1.0 / 30.0, false)
		await process_frame
	cam.look_at_from_position(views["side"], Vector3(0, 0.7, 0), Vector3.UP)
	await process_frame
	get_root().get_texture().get_image().save_png(out + "/solo_crouch.png")
	for f in range(40):
		var head := Transform3D(b, Vector3(0, 1.2, 0.2))
		av.update(head, [Vector3(-0.15, 0.95, 0.5), Vector3(0.15, 0.95, 0.5)], [true, true], 1.0 / 30.0, true)
		await process_frame
	await process_frame
	get_root().get_texture().get_image().save_png(out + "/solo_seat.png")
	print("SOLO DONE")
	quit()
