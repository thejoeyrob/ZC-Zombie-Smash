extends SceneTree
## Actual engine render capture. Run with a GPU/display, not --headless.
var subjects: Array = []
var camera: Camera3D
var stage: Node3D
var close_hands := false
var curls := 0.12
var output := "user://avatar-review"
func _initialize() -> void:
	_run.call_deferred()
func _process(delta: float) -> bool:
	for i in range(subjects.size()):
		var avatar: VRAvatar = subjects[i]
		var x := -0.55 if i == 0 else 0.55
		var head := Transform3D(Basis.IDENTITY, Vector3(x, 1.62, 0))
		var left := Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(x - 0.23, 1.1, -0.32))
		var right := Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(x + 0.23, 1.1, -0.32))
		avatar.hand_poses = [left, right]
		avatar.finger_curls.fill(curls)
		avatar.update(head, [left.origin, right.origin], [true, true], delta)
	return false
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1400, 1000)
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1c2430")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c5d4e9")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -28, 0)
	light.light_color = Color("fff3e7")
	light.light_energy = 1.5
	light.shadow_enabled = true
	stage.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(2, 2.5, -2)
	fill.omni_range = 8
	fill.light_energy = 1.0
	fill.light_color = Color("abc9f7")
	stage.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("343c48")
	mat.roughness = 0.78
	floor_mesh.material_override = mat
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 34
	for id in ["human_joeyrob", "human_fatamy"]:
		var avatar := VRAvatar.new()
		stage.add_child(avatar)
		avatar.build(false)
		avatar.apply_skin(id)
		subjects.append(avatar)
	var label := Label.new()
	label.position = Vector2(32, 25)
	label.add_theme_font_size_override("font_size", 24)
	label.text = "FATTY'S GAME SHACK  /  ACTUAL GODOT RENDER  /  TWO GAME CHARACTERS"
	root.add_child(label)
	camera.look_at_from_position(Vector3(0, 1.35, -4.7), Vector3(0, 0.95, 0))
	await capture("01-full-body.png")
	camera.look_at_from_position(Vector3(0, 1.65, -2.45), Vector3(0, 1.4, 0))
	await capture("02-face-and-shoulders.png")
	label.text = "ACTUAL SKINNED HANDS  /  OPEN POSE"
	camera.fov = 25
	camera.look_at_from_position(Vector3(-0.55, 1.35, -1.6), Vector3(-0.55, 1.1, -0.34))
	curls = 0.0
	await capture("03-open-hands.png")
	label.text = "ACTUAL SKINNED HANDS  /  GRIP POSE"
	curls = 0.9
	await capture("04-grip-hands.png")
	print("RENDER REVIEW SAVED: " + output)
	quit()
func capture(filename: String) -> void:
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	assert(img != null and not img.is_empty())
	assert(img.save_png(output.path_join(filename)) == OK)
