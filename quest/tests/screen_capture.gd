extends Node
## Renders the cabinet screen to PNG files for visual checks (needs a display, e.g. xvfb-run with the compatibility renderer).
## Usage: xvfb-run godot --path quest --rendering-driver opengl3 --rendering-method gl_compatibility tests/screen_capture.tscn

var vp: SubViewport
var screen: ZSScreen
var game: ZSEngine
var tick := 0
var shots_at := {}
var out_dir := "/tmp/claude-0/qshots"
var plan: Array = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	ZSEngine.setup()
	vp = SubViewport.new()
	vp.size = Vector2i(686, 824)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	screen = ZSScreen.new()
	screen.scale = Vector2(2, 2)
	vp.add_child(screen)
	await get_tree().process_frame
	screen.preload_all()
	screen.mode = "title"
	await shoot("title")
	var args := OS.get_cmdline_user_args()
	var scenario := args[0] if args.size() > 0 else "wave1"
	# scenarios: start a game, jump to a wave/boss and capture a few moments
	game = ZSEngine.new(11, Callable())
	game.invincible = true
	game.start()
	screen.g = game
	screen.mode = "play"
	var jump := 1
	var boss := ""
	if scenario.begins_with("wave"):
		jump = int(scenario.substr(4))
	if scenario.begins_with("boss-"):
		boss = scenario.substr(5)
	if jump > 1:
		game.wave = jump
		game.prepare_wave(jump)
	if boss != "":
		game.skip_boss(boss, 1)
	var caps: Array = [3.0, 9.0, 16.0, 24.0] if boss == "" else [1.0, 2.5, 5.0, 8.0, 14.0, 20.0]
	var t := 0.0
	var axes := [-1.0, 0.5, 1.0, -0.5, 0.0]
	var n := 0
	while caps.size() > 0:
		game.set_input(axes[(n / 80) % axes.size()], true)
		game.step(1.0 / 60.0)
		t += 1.0 / 60.0
		n += 1
		if n % 150 == 0 and game.player.grenades > 0:
			game.throw_grenade()
		if t >= caps[0]:
			caps.pop_front()
			screen.clock = t
			await shoot("%s_%02d" % [scenario, int(t)])
	get_tree().quit()

func shoot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := vp.get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)
