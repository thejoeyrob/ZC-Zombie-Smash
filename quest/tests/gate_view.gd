extends SceneTree
## Renders the gate between the arcade and the sports hall from both sides, to /tmp. godot --path quest --rendering-driver opengl3 -s tests/gate_view.gd -- out_prefix
var step := 0
var cam: Camera3D
var room := ArcadeRoom.new()
var prefix := "/tmp/claude-0/shots/gate"
var views := [
	[Vector3(-2.0, 1.6, 3.6), Vector3(-3.2, 1.3, 7.3), 75.0],      # in the arcade, looking at the gate
	[Vector3(-3.2, 1.6, 8.9), Vector3(-3.2, 1.5, 7.3), 75.0],      # in the hall, looking back at the gate
	[Vector3(-3.2, 1.6, 8.3), Vector3(-0.5, 1.5, 13.0), 75.0],     # in the hall just inside, looking along it
]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		prefix = args[0]
	root.size = Vector2i(1280, 720)
	ZSEngine.setup()
	var world := Node3D.new()
	root.add_child(world)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.2))
	room.build(world, ImageTexture.create_from_image(img), ImageTexture.create_from_image(img), load("res://assets/fonts/font-barlow-condensed-900.woff2"), VRProgress.new())
	room.sports.set_active(true)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true

func _view(k: int) -> void:
	var v: Array = views[k]
	cam.global_position = v[0]
	cam.look_at(v[1], Vector3.UP)
	cam.fov = v[2]

func _process(_d: float) -> bool:
	step += 1
	var k := (step - 1) / 10
	if k < views.size() and step % 10 == 1:
		_view(k)
	if k < views.size() and step % 10 == 8:
		root.get_texture().get_image().save_png("%s_%d.png" % [prefix, k])
	if k >= views.size():
		quit()
	return false
