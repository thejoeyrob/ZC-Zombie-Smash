extends SceneTree
## Pictures of an arcade machine with a live game on its screen, from where the player stands and from above the deck (flat renderer, for checks).
## godot --path quest --rendering-driver opengl3 --rendering-method gl_compatibility -s tests/machine_view.gd -- out_prefix [machine_index] [boss]
var vp: SubViewport
var screen: ZSScreen
var game: ZSEngine
var room: ArcadeRoom
var cam: Camera3D
var step := 0
var prefix := "/tmp/claude-0/shots/machine"
var idx := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		prefix = args[0]
	if args.size() > 1:
		idx = int(args[1])
	root.size = Vector2i(1200, 900)
	ZSEngine.setup()
	vp = SubViewport.new()
	vp.size = Vector2i(686, int(ZSScreen.FULL_H * 2.0))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	screen = ZSScreen.new()
	screen.scale = Vector2(2, 2)
	vp.add_child(screen)
	screen.preload_all()
	game = ZSEngine.new(11, Callable())
	game.invincible = true
	game.start()
	game.player.inventory.smg = 38.0
	game.player.inventory.dmr = 12.0
	game.player.lives = 3
	game.breaches = 2
	if args.size() > 2 and args[2] != "":
		game.skip_boss(args[2], 1)
	screen.best = 61500
	screen.g = game
	screen.mode = "play"
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.1, 0.1))
	var holder := Node3D.new()
	root.add_child(holder)
	room = ArcadeRoom.new()
	room.build(holder, vp.get_texture(), ImageTexture.create_from_image(img), ThemeDB.fallback_font, VRProgress.new())
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var cab: Cabinet = room.machines[idx]
	cab.set_live(vp.get_texture())
	cab.screen_mat.albedo_color = Color(Cabinet.SCREEN_LEVEL, Cabinet.SCREEN_LEVEL, Cabinet.SCREEN_LEVEL)

func _view(k: int) -> void:
	var cab: Cabinet = room.machines[idx]
	if k == 0:
		cam.global_position = cab.stand_world() + Vector3(0, 1.62, 0)
		cam.look_at(cab.look_world() - Vector3(0, 0.12, 0), Vector3.UP)
		cam.fov = 62
	elif k == 1:
		cam.global_position = cab.stand_world() + Vector3(0, 1.35, 0.1)
		cam.look_at(cab.look_world() - Vector3(0, 0.45, 0), Vector3.UP)
		cam.fov = 70
	else:
		cam.global_position = cab.stand_world() + Vector3(0, 1.1, 0.25)
		cam.look_at(cab.to_global(Vector3(0.0, 0.85, 0.05)), Vector3.UP)
		cam.fov = 60

func _process(_d: float) -> bool:
	step += 1
	game.set_input(sin(step * 0.03), true)
	game.step(1.0 / 60.0)
	game.step(1.0 / 60.0)
	if step == 2:
		_view(0)
	if step == 140:
		root.get_texture().get_image().save_png("%s_%d_a.png" % [prefix, idx])
		_view(1)
	if step == 145:
		root.get_texture().get_image().save_png("%s_%d_b.png" % [prefix, idx])
		_view(2)
	if step == 150:
		root.get_texture().get_image().save_png("%s_%d_c.png" % [prefix, idx])
		quit()
	return false
