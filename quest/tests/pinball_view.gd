extends SceneTree
## Renders pictures of the pinball machine to /tmp (flat desktop renderer) so the table can be looked at without a headset.
## godot --path quest --rendering-driver opengl3 -s tests/pinball_view.gd -- out_prefix
var step := 0
var pin: Pinball
var cam: Camera3D
var prefix := "/tmp/claude-0/shots/pin"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		prefix = args[0]
	root.size = Vector2i(1100, 1100)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	root.add_child(sun)
	pin = Pinball.new()
	root.add_child(pin)
	pin.build(ThemeDB.fallback_font)
	pin.set_enabled(true)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	_view(0)

func _view(k: int) -> void:
	var pf := pin.pf.global_position
	if k == 0:       # straight down on the whole playfield
		cam.global_position = pf + Vector3(0, 1.35, 0.05)
		cam.look_at(pf, Vector3(0, 0, -1))
		cam.fov = 55
	elif k == 1:     # a player's view from the front rail
		cam.global_position = pin.to_global(Vector3(0, 1.45, 1.05))
		cam.look_at(pin.to_global(Vector3(0, 0.8, -0.1)), Vector3.UP)
		cam.fov = 65
	elif k == 2:     # close on the bumpers and the right ramp
		cam.global_position = pin.to_global(Vector3(0.1, 1.25, -0.1))
		cam.look_at(pin.to_global(Vector3(0.05, 0.8, -0.3)), Vector3.UP)
		cam.fov = 55
	elif k == 3:     # close on the flippers
		cam.global_position = pin.to_global(Vector3(0, 1.1, 0.75))
		cam.look_at(pin.to_global(Vector3(0, 0.8, 0.45)), Vector3.UP)
		cam.fov = 55
	elif k == 4:     # the stone door and the hole
		cam.global_position = pin.to_global(Vector3(0, 1.2, 0.2))
		cam.look_at(pin.to_global(Vector3(0, 0.8, 0.0)), Vector3.UP)
		cam.fov = 60

func _process(_d: float) -> bool:
	step += 1
	if step == 3:
		# launch a ball for the pictures: it sits in the lane
		pin.table.pull(1.0)
	if step > 8 and step % 4 == 0:
		var k := step / 4 - 3
		if k >= 1 and k <= 5:
			var img := root.get_texture().get_image()
			img.save_png("%s_%d.png" % [prefix, k - 1])
			if k < 5:
				_view(k)
		if k >= 6:
			quit()
	return false
