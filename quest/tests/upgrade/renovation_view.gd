extends SceneTree
## Renders pictures of the sports hall to /tmp so it can be looked at without a headset.
## godot --path quest --rendering-driver opengl3 -s tests/annex_view.gd -- out_prefix
var step := 0
var sports: ThrowGames
var cam: Camera3D
var prefix := "/tmp/claude-0/shots/annex"
var views := [
	[Vector3(0,1.8,0.3), Vector3(0,1.6,5.0), 70.0],       # in through the gate
	[Vector3(-1.2, 1.7, 10.6), Vector3(-3.9, 1.7, 10.6), 60.0],      # at the oche, looking at the dartboards
	[Vector3(-1.75, 1.6, 15.8), Vector3(-1.75, 1.5, 21.0), 62.0],    # at the axe lanes
	[Vector3(2.1, 1.6, 8.4), Vector3(2.1, 0.5, 20.0), 65.0],         # on the approach, looking down the lanes
	[Vector3(2.1, 1.2, 17.0), Vector3(2.1, 0.3, 20.4), 60.0],        # close on the pins
]

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		prefix = args[0]
	root.size = Vector2i(1280, 720)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.01, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.61, 0.68)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var font = load("res://assets/fonts/font-barlow-condensed-900.woff2")
	var world := Node3D.new()
	root.add_child(world)
	ZSEngine.setup()
	var room:=ArcadeRoom.new()
	room.build(world,null,null,font,VRProgress.new())
	sports=room.sports
	sports.set_active(true)
	sports.bowling.lanes[0].reaction.react("STRIKE!",10,0)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	_view(0)

func _view(k: int) -> void:
	var v: Array = views[k]
	cam.global_position = v[0]
	cam.look_at(v[1], Vector3.UP)
	cam.fov = v[2]

func _process(_d: float) -> bool:
	step += 1
	if step >= 12 and step % 8 == 4:
		var k := step / 8 - 1
		if k >= 0 and k < views.size():
			root.get_texture().get_image().save_png("%s_%d.png" % [prefix, k])
			if k + 1 < views.size():
				_view(k + 1)
		if k >= views.size():
			quit()
	return false
