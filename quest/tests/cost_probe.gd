extends SceneTree
## Counts what the headset would have to draw from several spots: draw calls and triangles per frame, with the hall switched on or off.
## godot --path quest --rendering-driver opengl3 -s tests/cost_probe.gd
var step := 0
var cam: Camera3D
var room := ArcadeRoom.new()
var spots := [
	["arcade, looking at the door wall", Vector3(0, 1.7, 3.5), Vector3(0, 1.5, -0.5), false],
	["arcade, looking at the back wall", Vector3(0, 1.7, 3.5), Vector3(0, 1.5, 7.3), false],
	["arcade, looking at the machines", Vector3(0.3, 1.7, 2.6), Vector3(-3.0, 1.3, 2.0), false],
	["hall, looking down the lanes (hall on)", Vector3(2.1, 1.6, 8.4), Vector3(2.1, 0.5, 20.0), true],
	["hall, looking at darts and axes (hall on)", Vector3(-1.5, 1.6, 12.5), Vector3(-2.2, 1.4, 19.0), true],
	["hall, looking back at the arcade (hall on)", Vector3(-3.2, 1.6, 9.0), Vector3(-3.2, 1.4, 5.0), true],
	["arcade with the hall also switched on", Vector3(0, 1.7, 3.5), Vector3(0, 1.5, 7.3), true],
]

func _initialize() -> void:
	ZSEngine.setup()
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	room.build(world, ImageTexture.create_from_image(img), ImageTexture.create_from_image(img), load("res://assets/fonts/font-barlow-condensed-900.woff2"), VRProgress.new())
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true

func _process(_d: float) -> bool:
	step += 1
	var k := (step - 1) / 8
	if k < spots.size() and step % 8 == 1:
		var s: Array = spots[k]
		room.sports.set_active(bool(s[3]))
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
	if k < spots.size() and step % 8 == 6:
		var rid := root.get_viewport_rid()
		var dc := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var pr := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		print("%-48s draw calls %5d   triangles %8d" % [spots[k][0], dc, pr])
	if k >= spots.size():
		quit()
	return false
