extends SceneTree
## Renders the two driving machines to /tmp. godot --path quest --rendering-driver opengl3 -s tests/driving_view.gd -- out_prefix
var step := 0
var cam: Camera3D
var room := ArcadeRoom.new()
var prefix := "/tmp/claude-0/shots/driving"
var views := []
var carts: Array = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		prefix = args[0]
	root.size = Vector2i(1280, 720)
	ZSEngine.setup()
	var world := Node3D.new()
	root.add_child(world)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	room.build(world, ImageTexture.create_from_image(img), ImageTexture.create_from_image(img), load("res://assets/fonts/font-barlow-condensed-900.woff2"), VRProgress.new())
	for m in room.machines:
		if m.cart_mode != "":
			var rc := RoadCartridge.new(m.cart_mode)
			rc.build(world)
			m.cart = rc
			m.attract_tex = rc.screen_texture()
			m.set_live(null)
			carts.append(rc)
			views.append([m.transform * Vector3(0, 1.5, 1.7), m.position + Vector3(0, 1.15, 0), 60.0])
			views.append([m.transform * Vector3(0.8, 1.55, 1.0), m.position + Vector3(0, 0.9, 0), 60.0])
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	_view(0)

func _view(k: int) -> void:
	var v: Array = views[k]
	cam.global_position = v[0]
	cam.look_at(v[1], Vector3.UP)
	cam.fov = v[2]

func _process(d: float) -> bool:
	step += 1
	for c in carts:
		c.tick(d)
	var k := (step - 1) / 12
	if k < views.size() and step % 12 == 1:
		_view(k)
	if k < views.size() and step % 12 == 10:
		root.get_texture().get_image().save_png("%s_%d.png" % [prefix, k])
	if k >= views.size():
		quit()
	return false
