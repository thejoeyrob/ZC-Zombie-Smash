extends SceneTree
## Renders pictures of the Frustration / Trouble board to /tmp so it can be looked at without a headset.
## godot --path quest --rendering-driver opengl3 -s tests/board_view.gd -- out_prefix
var step := 0
var bg: BoardGame
var cam: Camera3D
var prefix := "/tmp/claude-0/shots/board"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		prefix = args[0]
	root.size = Vector2i(1000, 1000)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	root.add_child(sun)
	var tex = load("res://assets/art/boardgame-trouble.jpg")
	if tex == null:
		tex = ImageTexture.create_from_image(Image.load_from_file("res://vr-art/boardgame-trouble.jpg"))
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.76, 0.76)
	q.mesh = qm
	q.material_override = m
	q.rotation = Vector3(-PI / 2, PI, 0)
	q.position = Vector3(0, -0.002, 0)
	root.add_child(q)
	bg = BoardGame.new()
	bg.rotation.y = PI
	root.add_child(bg)
	bg.build(ThemeDB.fallback_font)
	bg.take_seat(0, "local")
	bg.authority = false
	# a mid-game position: pegs out on the loop, one in a lane, a die showing 5 and a choice to make
	bg.players[0].pegs = [0, 6, 29, -1]
	bg.players[1].pegs = [2, 10, -1, -1]
	bg.players[2].pegs = [4, -1, -1, -1]
	bg.players[3].pegs = [1, 15, 28, -1]
	bg.current = 0
	bg.phase = "move"
	bg.die_value = 5
	bg.legal = [0, 1]
	bg._place_all(true)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 50
	cam.global_position = Vector3(0, 1.0, 0.02)
	cam.look_at(Vector3.ZERO, Vector3(0, 0, -1))

func _process(_d: float) -> bool:
	step += 1
	if step == 12:
		root.get_texture().get_image().save_png(prefix + "_top.png")
		cam.global_position = Vector3(0.2, 0.45, 0.65)
		cam.look_at(Vector3(0, 0.0, 0.0), Vector3.UP)
	if step == 20:
		root.get_texture().get_image().save_png(prefix + "_angle.png")
		quit()
	return false
