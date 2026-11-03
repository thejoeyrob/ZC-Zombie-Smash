extends Node3D
## Zombie Smash VR: one standing player, one arcade machine. Runs on a Quest (OpenXR) and, for development and
## screenshots, on a desktop with a flat camera and simulated hands.

const TICK := 1.0 / 60.0
const GRAB_RADIUS := 0.09
const DEADZONE := 0.10
const BEST_PATH := "user://best.json"

var xr_on := false
var origin: XROrigin3D
var cam: Camera3D
var hands: Array = []          # [{ctrl, aim, mesh, side}]
var room: ArcadeRoom
var cab: Cabinet
var machines: Array = []
var viewport: SubViewport
var screen: ZSScreen
var cartridge: Cartridge       # the game every machine runs (Zombie Smash is the first cartridge)
var audio: ZSAudio
var game: ZSEngine
var font: Font

var state := "title"           # title | play | paused | over
var acc := 0.0
var clock := 0.0
var over_at := 0.0
var best := 0
var calibrated := false
var calibrate_timer := 0.0

var grab_hand := -1
var roll := 0.0
var pitch := 0.0
var axis := 0.0
var fire_now := false
var grenade_prev := false
var menu_prev := false
var click_side := 0
var axis_seen := 0.0
var locked := true             # red light: held at the machine; green: free to move about the room
var selector: Selector
var leave_t := 0.0
var leave_prompt: Node3D
var leave_fill: MeshInstance3D
var leave_label: Label3D
var fade_quad: MeshInstance3D
var lock_prev := false
var pause_prev := false
var turn_ready := true
var trig_prev := [false, false]
var tele_busy := false
const SETTINGS_PATH := "user://settings.json"
var settings := {"music": 0.55, "effects": 0.8, "lift": 0.0, "reach": 0.0, "turn": "smooth", "turnspeed": 90, "snap": 45, "walk": 1.5, "haptics": 1.0, "topper": "yellow", "pointer": "right", "assist": "off", "handroll": 0, "handtilt": 0, "hud": "on", "battle": "JORDAN"}
var progress := VRProgress.new()
var run_bosses := 0
var run_grenades := 0
var run_hurt_wave := false
var run_assisted := false
var run_clean_wave := false
var run_start := 0.0
var menu: VRMenu
var menu_prev_btn := false
var menu_resume_state := ""
var base_scale := 1.0
const HAND_ANCHOR := 0.032     # the stick ball sits this far into the palm

# development / screenshot helpers (desktop only)
var args := {}
var demo := false
var demo_t := 0.0
var shot_plan: Array = []
var shot_dir := "/tmp/claude-0/qvr"
var sim_hands: Array = [_blank_hand(), _blank_hand()]


func _ready() -> void:
	ZSEngine.setup()
	for a in OS.get_cmdline_user_args():
		var kv := a.lstrip("-").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_load_best()
	progress.load_all()
	font = load("res://assets/fonts/font-barlow-condensed-900.woff2")
	_setup_xr()
	_build_screen()
	cartridge = Cartridges.create(Cartridges.default_id(), self)
	room = ArcadeRoom.new()
	var banner: Texture2D = load("res://assets/art/game-banner.webp")
	room.build(self, cartridge.screen_texture(), banner, font, progress)
	machines = room.machines
	cab = machines[room.player_index]
	cab.set_live(cartridge.screen_texture())
	room.set_active(room.player_index)
	room.prize_wall.set_unlocked(progress.unlocked(), true)
	room.pinball.set_enabled(true)      # the pinball machine is always playable
	room.pinball.table.best = progress.pinball_best
	room.pinball.table.bonus_balls = progress.codes.has("pinball")
	room.vending.code_entered.connect(_on_code)
	room.vending.key_pressed.connect(func(k, ok): audio.sfx("key" if ok else "error", 0.7, 0.0, room.vending.global_position + Vector3(0, 1.3, 0.5)); _haptic(-1, 0.2, 0.03))
	room.pinball.sound.connect(_on_pinball_sound)
	room.door.scare.connect(func(kind): audio.sfx("doom" if kind != "stare" else "warn", 0.45, 0.0, Vector3(0, 1.4, -0.6)))
	room.prize_wall.grabbed.connect(func(_i, open): audio.sfx("pickup" if open else "switch", 0.7); _haptic(1, 0.35, 0.05))
	room.prize_wall.dropped.connect(func(_i): audio.sfx("toggle", 0.6))
	_build_hands()
	selector = Selector.new()
	selector.accessible = Callable(self, "_floor_ok")
	selector.build(self, _selector_targets(), font)
	_build_leave_prompt()
	if args.has("hover"):
		for i in range(selector.targets.size()):
			if selector.targets[i].id == str(args.hover):
				selector.forced = i
				selector.set_shown(true)
				selector.aim(Vector3.ZERO, Vector3.FORWARD)
	_build_fade()
	_load_settings()
	menu = VRMenu.new()
	menu.build(self, font, settings, build_number())
	# a small build number on the machine's panel and on the floor sign, so a new install is easy to recognise
	for m in machines:
		VRBuild.label(m.panel, "BUILD %d" % build_number(), 0.03, Vector3(0.0, 0.003, 0.163), Color(1, 1, 1, 0.4), Vector3(-PI / 2, 0, 0), 3)
	menu.changed.connect(_on_setting)
	menu.action.connect(_on_menu_action)
	_capture_attract()
	if args.has("approach"):
		room.door.force_approach = true
		room.door._timer = 0.2
	if args.has("scare"):
		room.door.debug_show(str(args.scare) if str(args.scare).ends_with(".webp") else "zombie-brute.webp", 0.3)
	if args.has("pinplay"):
		room.pinball.set_enabled(true)
		_pinplay()
	if args.has("die"):
		get_tree().create_timer(7.0).timeout.connect(func():
			game.end("test")
			await get_tree().create_timer(5.0).timeout
			print("DIE TEST: state ", state, " runs ", progress.runs, " best ", progress.best, " unlocked ", progress.unlocked()))
	if args.has("prizes"):
		room.prize_wall.set_unlocked(int(args.prizes), true)
	if args.has("fakehall"):    # development only: sample rows so the board layout can be checked offline
		progress.last = {"score": 48210, "wave": 7, "kills": 212, "bosses": 3, "seconds": 400}
		progress.best = 61500
		progress.badges = ["first_boss", "score_10k", "wave_10"]
		room.hall.rows = [{"username": "SAMPLE ONE", "score": 912340}, {"username": "SAMPLE TWO", "score": 640200}, {"username": "SAMPLE THREE", "score": 233100}, {"username": "SAMPLE FOUR", "score": 98700}]
		room.hall.refresh()
	if args.has("menu"):
		get_tree().create_timer(2.0).timeout.connect(_open_menu)
	if args.has("unlocked"):
		_set_locked(false)
	audio = ZSAudio.new()
	add_child(audio)
	audio.setup(cab)
	audio.set_volumes(float(settings.music), float(settings.effects))
	cab.set_topper_color(VRMenu.TOPPERS[settings.topper])
	audio.play_music("ambient", 0.01)
	room.jukebox.command.connect(_on_jukebox)
	screen.best = best
	if not xr_on:
		_setup_desktop_camera()
	demo = args.has("demo")
	if args.has("autoplay"):
		demo = true
		start_game()
		get_tree().create_timer(float(args.get("quit_after", "20"))).timeout.connect(func():
			print("AUTOPLAY RESULT: score ", game.score, " wave ", game.wave, " kills ", game.kills, " lives ", game.player.lives, " axis-seen ", axis_seen)
			get_tree().quit())
	if args.has("shots"):
		shot_dir = args.shots
		_run_shots()
	if args.has("tour"):
		_run_tour()


# ---- set-up -------------------------------------------------------------------------------------
func _setup_xr() -> void:
	origin = XROrigin3D.new()
	add_child(origin)
	var iface := XRServer.find_interface("OpenXR")
	if iface != null and iface.is_initialized():
		xr_on = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		get_viewport().msaa_3d = Viewport.MSAA_4X
		get_viewport().anisotropic_filtering_level = Viewport.ANISOTROPY_16X if get_viewport().has_method("set_anisotropic_filtering_level") else Viewport.ANISOTROPY_8X
		iface.render_target_size_multiplier = 1.3          # draw each eye 30% sharper than the headset's default, so far-away detail stays clean
		Engine.max_fps = 0
		cam = XRCamera3D.new()
		origin.add_child(cam)
		print("OpenXR is running")
	else:
		cam = Camera3D.new()
		origin.add_child(cam)
		print("OpenXR not available: flat desktop mode")


func _setup_desktop_camera() -> void:
	cam.fov = 70.0
	cam.look_at_from_position(cab.stand_world() + Vector3(0, 1.68, 0), cab.look_world() - Vector3(0, 0.1, 0), Vector3.UP)


func _build_screen() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1029, 1236)         # the 343 x 412 game, drawn three times sharper than on the phone
	viewport.msaa_2d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)
	screen = ZSScreen.new()
	screen.ss = 3.0
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	viewport.add_child(screen)
	screen.preload_all()
	screen.tex("intro-jw.png")
	screen.intro_done.connect(_on_intro_done)


static func _blank_hand() -> Dictionary:
	return {"xf": Transform3D.IDENTITY, "grip": Vector3.ZERO, "gripping": false, "trigger": false, "grip_val": 0.0, "trig_val": 0.0,
		"stick": Vector2.ZERO, "a": false, "b": false, "menu": false, "aim_origin": Vector3.ZERO, "aim_dir": Vector3.FORWARD, "active": true, "bare": false, "thumb": -1.0, "angles": {}}


func _build_hands() -> void:
	for side in range(2):
		var name := "left_hand" if side == 0 else "right_hand"
		var grip := XRController3D.new()
		grip.tracker = name
		grip.pose = "grip"
		origin.add_child(grip)
		var aim := XRController3D.new()
		aim.tracker = name
		aim.pose = "aim"
		origin.add_child(aim)
		var vis := VRHand.new()
		vis.build(side)
		origin.add_child(vis)
		var arm := VRArm.new()
		arm.build(side)
		add_child(arm)
		arm.visible = false
		hands.append({"ctrl": grip, "aim": aim, "side": side, "vis": vis, "arm": arm})
		if not xr_on:
			vis.visible = false


func _build_fade() -> void:
	fade_quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(3, 3)
	fade_quad.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0)
	m.no_depth_test = true
	m.render_priority = 100
	fade_quad.material_override = m
	fade_quad.position = Vector3(0, 0, -0.15)
	fade_quad.visible = false
	cam.add_child(fade_quad)


## Development: plays the pinball table by itself for a while and reports how it went.
func _pinplay() -> void:
	var t: PinTable = room.pinball.table
	await get_tree().create_timer(1.5).timeout
	t.launch()
	var end := clock + float(args.get("pinplay", "20"))
	var flips := 0
	while clock < end:
		await get_tree().process_frame
		# flip whenever the ball is down near a flipper
		var l := t.in_play and t.ball.y > 640.0 and t.ball.x < 200.0
		var r := t.in_play and t.ball.y > 640.0 and t.ball.x >= 200.0
		if l != t.left_up or r != t.right_up:
			flips += 1
		t.flippers(l, r)
		if not t.in_play and not t.game_over:
			t.launch()
		if t.game_over:
			t.launch()
	print("PINPLAY: score ", t.score, " best ", t.best, " balls left ", t.balls_left, " flips ", flips)


func build_number() -> int:
	if FileAccess.file_exists("res://build.json"):
		var d = JSON.parse_string(FileAccess.open("res://build.json", FileAccess.READ).get_as_text())
		if d is Dictionary:
			return int(d.get("build", 0))
	return 0


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in settings:
				if d.has(k):
					settings[k] = d[k]
			settings.snap = int(settings.snap)
			settings.handroll = int(settings.handroll)
			settings.handtilt = int(settings.handtilt)


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


func _on_setting(key: String, value) -> void:
	settings[key] = value
	match key:
		"music", "effects":
			audio.set_volumes(float(settings.music), float(settings.effects))
		"lift", "reach":
			_apply_height()
		"topper":
			cab.set_topper_color(VRMenu.TOPPERS[value])
		"snap":
			settings.snap = int(value)
		"hud":
			screen.no_shake = value == "off"
	if key != "music" and key != "effects" and key != "lift" and key != "reach" and key != "haptics":
		audio.ui("click")
	_save_settings()


## The room and the machines are a fixed size; the player is what moves: "lift" raises or lowers the player, "reach" moves them
## nearer to or further from the machine they are playing.
func _apply_height() -> void:
	if xr_on:
		origin.position.y = float(settings.lift)
	if locked and calibrated:
		_place_player(cab.stand_world(), cab.look_world(), true)


func _on_code(action: String) -> void:
	if action == "pinball":
		if not progress.codes.has("pinball"):
			progress.codes.append("pinball")
			progress.save()
		room.pinball.table.bonus_balls = true       # the secret code gives the pinball machine five balls a game
		room.pinball.table.balls_left = 5
		audio.sfx("clear", 0.9)
		audio.sfx("chime", 0.8, 0.0, room.pinball.global_position + Vector3(0, 1.0, 0))


func _on_pinball_sound(n: String, pos: Vector3) -> void:
	var map := {"flip": ["click", 0.8], "flipper_hit": ["hit", 0.5], "launch": ["throw", 0.8], "bump": ["target", 0.8], "sling": ["hit", 0.6], "target": ["pickup", 0.7], "clear": ["clear", 0.9], "drain": ["hurt", 0.7], "over": ["doom", 0.8], "wall": ["ricochet", 0.25]}
	if map.has(n):
		audio.sfx(map[n][0], map[n][1], 0.04, pos)
	if n == "flip":
		_haptic(-1, 0.25, 0.03)
	elif n == "bump":
		_haptic(-1, 0.4, 0.05)
	elif n == "over":
		progress.pinball_best = maxi(progress.pinball_best, room.pinball.table.best)
		progress.save()
		room.hall.refresh()


## Every machine plays the same game: the ones nobody is using show its title screen, whichever one you lock on to goes live.
func _capture_attract() -> void:
	await get_tree().create_timer(1.2).timeout
	var img := cartridge.screen_texture().get_image()
	if img == null:
		return
	var tex := ImageTexture.create_from_image(img)
	for m in machines:
		m.attract_tex = tex
		if m != cab:
			m.set_live(null)


func _on_jukebox(cmd: String) -> void:
	audio.ambient_track = room.jukebox.current_id()
	audio.sfx("click", 0.7, 0.0, room.jukebox.global_position + Vector3(0, 1.1, 0.3))
	_haptic(-1, 0.2, 0.03)
	if state == "play":
		return                       # a game's own music is not interrupted; the choice applies when the game ends
	if cmd == "stop":
		audio.stop_music(0.4)
	else:
		audio.current = ""
		audio.play_music("ambient", 0.8)


func _on_menu_action(name: String) -> void:
	match name:
		"resume":
			_close_menu()
		"recentre":
			_close_menu()
			recenter()
		"quit":
			get_tree().quit()
		"story":
			_close_menu()
			if locked and state == "title":
				_begin_intro()
		"fight":
			_close_menu()
			start_game()
			for b in ZSEngine.BOSSES:
				if str(b.name) == str(settings.battle):
					game.skip_boss(str(b.id), 1)
					break
		"end":
			_close_menu()
			if state != "title":
				state = "title"
				game = null
				screen.g = null
				screen.mode = "title"
				audio.play_music("ambient", 1.0)


func _open_menu() -> void:
	menu_resume_state = state
	if state == "play":
		state = "paused"
		screen.mode = "paused"
	menu.set_open(true)
	menu.present(cam.global_position, -cam.global_transform.basis.z)
	audio.ui("page")


func _close_menu() -> void:
	menu.set_open(false)
	if menu_resume_state == "play" and state == "paused":
		state = "play"
		screen.mode = "play"
	audio.ui("back")


func _load_best() -> void:
	if FileAccess.file_exists(BEST_PATH):
		var f := FileAccess.open(BEST_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			best = int(d.get("best", 0))


func _save_best() -> void:
	var f := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"best": best}))


## The cartridge asks the app to pause or resume the running game.
func set_game_paused(on: bool) -> void:
	if on and state == "play":
		state = "paused"
		screen.mode = "paused"
	elif not on and state == "paused":
		state = "play"
		screen.mode = "play"


# ---- the game ------------------------------------------------------------------------------------
func start_game() -> void:
	game = ZSEngine.new(randi(), Callable(self, "_on_event"))
	game.start()
	screen.g = game
	screen.mode = "play"
	state = "play"
	acc = 0.0
	run_bosses = 0
	run_grenades = 0
	run_hurt_wave = false
	run_clean_wave = false
	run_assisted = false
	run_start = clock
	audio.want = "main"
	audio.wave = 1


func _on_event(type: String, data: Dictionary) -> void:
	audio.on_event(type, data, game)
	match type:
		"shot": _haptic(grab_hand_other(), 0.18, 0.04)
		"hurt":
			run_hurt_wave = true
			_haptic(-1, 0.9, 0.25)
		"wave":
			if int(data.get("wave", 1)) > 1 and not run_hurt_wave:
				run_clean_wave = true
			run_hurt_wave = false
		"throw": run_grenades += 1
		"explosion": _haptic(-1, 0.7, 0.2)
		"bossAttack": _haptic(-1, 0.35, 0.12)
		"pickup": _haptic(-1, 0.4, 0.08)
		"mutation": _haptic(-1, 0.9, 0.5)
		"bossDown":
			run_bosses += 1
			_haptic(-1, 1.0, 0.6)
		"over": _finish(data)
		"death": _haptic(-1, 1.0, 0.6)


func grab_hand_other() -> int:
	return 1 - grab_hand if grab_hand >= 0 else 1


func _finish(_d: Dictionary) -> void:
	state = "over"
	over_at = clock
	screen.final_score = game.score
	screen.final_wave = game.wave
	screen.final_kills = game.kills
	if game.practice:       # boss practice never counts toward scores, prizes or badges
		screen.mode = "over"
		audio.play_music("over", 1.0)
		return
	if game.score > best:
		best = game.score
		_save_best()
		audio.stinger("highscore")
	var fresh := progress.record_run(game.score, game.wave, game.kills, run_bosses, run_grenades, run_clean_wave, clock - run_start, run_assisted)
	room.prize_wall.set_unlocked(progress.unlocked())
	room.hall.refresh()
	if not fresh.is_empty():
		audio.sfx("goldheart", 0.9)
	screen.best = best
	screen.mode = "over"
	audio.play_music("over", 1.0)


func _haptic(side: int, amp: float, dur: float) -> void:
	if not xr_on or float(settings.haptics) <= 0.01:
		return
	for h in hands:
		if side == -1 or h.side == side:
			h.ctrl.trigger_haptic_pulse("haptic", 0.0, amp * float(settings.haptics), dur, 0.0)


# ---- per-frame --------------------------------------------------------------------------------------
func _fix_poses() -> void:
	for h in hands:
		var tr := XRServer.get_tracker(h.ctrl.tracker) as XRPositionalTracker
		if tr == null:
			continue
		for pair in [[h.ctrl, ["grip", "grip_pose", "default"]], [h.aim, ["aim", "aim_pose", "default"]]]:
			var node: XRController3D = pair[0]
			if tr.has_pose(node.pose):
				continue
			for n in pair[1]:
				if tr.has_pose(n):
					node.pose = n
					break


func _process(delta: float) -> void:
	clock += delta
	if xr_on and int(clock * 2.0) != int((clock - delta) * 2.0):
		_fix_poses()
	room.animate(clock)
	room.prize_wall.animate(delta)
	_calibrate(delta)
	var hs := _read_hands(delta)
	_pose_hands(hs)
	_menu_input(hs)
	_world_inputs(hs)
	var pg: Array = []
	for i in range(2):
		pg.append({"grab": hs[i].gripping and grab_hand != i and not menu.open, "xf": hs[i].vis_xf, "point": hs[i].palm})
	room.prize_wall.update(pg)
	_locomotion(hs, delta)
	_stick(hs, delta)
	_buttons(hs)
	if state == "play" and game != null:
		acc += minf(delta, 0.1)
		game.set_input(axis, fire_now)
		while acc >= TICK:
			game.step(TICK)
			acc -= TICK
	elif state == "title":
		screen.mode = "title"


func _calibrate(delta: float) -> void:
	if calibrated:
		return
	calibrate_timer += delta
	if calibrate_timer > 1.2:
		recenter()


## Stands the player in front of the machine wherever they happened to be standing, facing it, and sizes the machine to their height.
func recenter() -> void:
	calibrated = true
	if not xr_on:
		return
	_place_player(cab.stand_world(), cab.look_world(), true)


## Both hands as raw controller data (from the controllers in VR, simulated on the desktop).
func _read_hands(delta: float) -> Array:
	if xr_on:
		var out: Array = []
		for h in hands:
			var c: XRController3D = h.ctrl
			var a: XRController3D = h.aim
			if not (c.get_is_active() and c.get_has_tracking_data()):
				var ht := XRServer.get_tracker("/user/hand_tracking/" + ("left" if h.side == 0 else "right")) as XRHandTracker
				if ht != null and ht.has_tracking_data:
					out.append(_tracked_hand(ht, h.side))
				else:
					var gone := _blank_hand()
					gone.active = false
					gone.xf = c.global_transform
					out.append(gone)
				continue
			var grip_val := c.get_float("grip")
			var trig_val := c.get_float("trigger")
			var d := _blank_hand()
			d.xf = c.global_transform
			d.gripping = c.is_button_pressed("grip_click") or grip_val > 0.6
			d.trigger = c.is_button_pressed("trigger_click") or trig_val > 0.6
			d.grip_val = grip_val
			d.trig_val = trig_val
			d.stick = c.get_vector2("primary")
			d.a = c.is_button_pressed("ax_button")
			d.b = c.is_button_pressed("by_button")
			d.menu = c.is_button_pressed("menu_button")
			d.aim_origin = a.global_position
			d.aim_dir = -a.global_transform.basis.z
			out.append(d)
		return out
	_simulate_hands(delta)
	return sim_hands


func _simulate_hands(delta: float) -> void:
	if not demo:
		return
	demo_t += delta
	var pb := cab.panel.global_transform.basis
	# left hand holds the stick and swings it side to side
	var ball := cab.ball_world_position()
	var swing := sin(demo_t * 1.3)
	var target: Vector3 = cab.panel.global_transform * (Cabinet.STICK_LOCAL + Vector3(swing * 0.07, Cabinet.STICK_LENGTH + 0.03, 0.0))
	var lb := Basis(Vector3.UP, 0.0)
	var l := _blank_hand()
	l.xf = Transform3D(lb, target - lb * Vector3(HAND_ANCHOR, 0.0, -0.012))
	l.gripping = demo_t > 0.5
	l.grip_val = 1.0 if demo_t > 0.5 else 0.0
	l.trig_val = 1.0 if demo_t > 0.5 else 0.0
	sim_hands[0] = l
	# right hand: a pointing finger that taps FIRE
	var fire_pos: Vector3 = cab.panel.global_transform * (Cabinet.BUTTONS.fire.pos + Vector3(0, 0.0, 0.0))
	var on := fmod(demo_t, 3.0) < 2.2 and demo_t > 1.0
	var rb := Basis(Vector3.RIGHT, -1.0)
	var r := _blank_hand()
	var tip_target := fire_pos + Vector3(0, 0.012, 0) if on else fire_pos + Vector3(0, 0.10, 0.0)
	r.xf = Transform3D(rb, tip_target - rb * Vector3(0, 0, -0.15))
	r.grip_val = 1.0
	r.trig_val = 0.0
	r.a = fmod(demo_t, 7.0) > 6.7
	sim_hands[1] = r


## Bare hands (no controllers): the pose and finger curls come from the headset's hand tracking.
func _tracked_hand(ht: XRHandTracker, side: int) -> Dictionary:
	var o := origin.global_transform
	var j := func(i: int) -> Vector3: return o * ht.get_hand_joint_transform(i).origin
	# joint numbers: 0 palm, 1 wrist, 5 thumb tip, 7 index knuckle, 10 index tip, 12 middle knuckle, 15 / 20 / 25 middle, ring, little tips, 22 little knuckle
	var palm: Vector3 = j.call(0)
	var wrist: Vector3 = j.call(1)
	var f: Vector3 = (j.call(12) - wrist).normalized()
	var t: Vector3 = j.call(7) - j.call(22)
	t = (t - f * t.dot(f)).normalized()
	var d := _blank_hand()
	d.xf = Transform3D(Basis(f.cross(t), t, -f), palm)
	var curl := func(tip: int) -> float: return 1.0 - clampf((palm.distance_to(j.call(tip)) - 0.055) / 0.115, 0.0, 1.0)
	var idx: float = curl.call(10)
	var grip := (float(curl.call(15)) + float(curl.call(20)) + float(curl.call(25))) / 3.0
	d.trig_val = idx
	d.grip_val = grip
	d.gripping = grip > 0.6
	d.trigger = (j.call(5) as Vector3).distance_to(j.call(10)) < 0.028     # a pinch
	d.aim_origin = j.call(10)
	d.aim_dir = (j.call(10) - j.call(7)).normalized()
	d.thumb = 1.0 - clampf(((j.call(5) as Vector3).distance_to(j.call(7)) - 0.03) / 0.06, 0.0, 1.0)
	d.bare = true
	# the real bend of every finger joint, so the hand makes the same shape as yours
	var dir := func(a: int, b: int) -> Vector3: return ((j.call(b) as Vector3) - (j.call(a) as Vector3)).normalized()
	var bend := func(a: Vector3, b: Vector3) -> float: return acos(clampf(a.dot(b), -1.0, 1.0))
	var ang := {}
	for pair in [["index", 6], ["middle", 11], ["ring", 16], ["pinky", 21]]:
		var m: int = pair[1]
		ang[pair[0]] = [bend.call(dir.call(m, m + 1), dir.call(m + 1, m + 2)), bend.call(dir.call(m + 1, m + 2), dir.call(m + 2, m + 3)), bend.call(dir.call(m + 2, m + 3), dir.call(m + 3, m + 4))]
	ang["thumb"] = [bend.call(dir.call(2, 3), dir.call(3, 4)), bend.call(dir.call(3, 4), dir.call(4, 5))]
	d.angles = ang
	return d


var _key_last := ["", ""]
var _jb_last := ["", ""]


## Hands pressing the snack machine's keypad, and working the pinball machine's buttons and plunger.
func _world_inputs(hs: Array) -> void:
	var tips: Array = []
	var palms: Array = []
	for i in range(hs.size()):
		tips.append(hs[i].tip)
		palms.append(hs[i].palm)
		var k: String = room.vending.key_at(hs[i].tip)
		if k != "" and k != _key_last[i] and not menu.open:
			room.vending.press(k)
		_key_last[i] = k
	for i2 in range(hs.size()):
		var jb: String = room.jukebox.button_at(hs[i2].tip)
		if jb != "" and jb != _jb_last[i2] and not menu.open:
			room.jukebox.press(jb)
		_jb_last[i2] = jb
	var near := _head_floor().distance_to(room.pinball.stand_world()) < 1.5 and not menu.open
	room.pinball.interact(tips, palms, hs[0].trigger and near, hs[1].trigger and near, (hs[0].a or hs[1].a), near)


func _solid(p: Vector3, r: float) -> Vector3:
	var out := p
	for m in machines:
		out = m.constrain(out, r)
	return room.pinball.constrain(out, r)


## Works out the hand the player sees (solid against the machine) and the points that touch the controls.
func _pose_hands(hs: Array) -> void:
	for i in range(hs.size()):
		var h: Dictionary = hs[i]
		var vis: VRHand = hands[i].vis
		var xf: Transform3D = h.xf
		if not h.bare and (int(settings.handroll) != 0 or int(settings.handtilt) != 0):
			xf.basis = xf.basis * Basis.from_euler(Vector3(deg_to_rad(float(settings.handtilt)), 0.0, deg_to_rad(float(settings.handroll))))
		var sgn := vis.s
		h.grip = xf * Vector3(sgn * HAND_ANCHOR, 0.0, -0.012)      # where the stick ball is held
		# keep palm and finger out of the cabinet
		var pos := xf.origin
		var palm := _solid(pos, 0.04)
		var shift := palm - pos
		var tipw: Vector3 = xf * Vector3(0, 0, -0.15) + shift
		var tip2 := _solid(tipw, 0.011)
		var final_xf := xf
		final_xf.origin = pos + shift + (tip2 - tipw)
		var holding := grab_hand == i
		var idx_c: float = 1.0 if holding else h.trig_val
		var grip_c: float = 1.0 if holding else h.grip_val
		var thumb_c: float = h.thumb if h.thumb >= 0.0 else maxf(grip_c * 0.8, idx_c * 0.3)
		if h.bare and not h.angles.is_empty() and not holding:
			vis.set_tracked(h.angles)
		else:
			vis.clear_tracked()
		vis.set_pose(idx_c, grip_c, 0.9 if holding else thumb_c)
		vis.global_transform = final_xf
		vis.visible = (xr_on and h.active) or demo
		var arm: VRArm = hands[i].arm
		arm.visible = false          # no arms: the glove's gauntlet is all that shows
		if arm.visible:
			var cg := cam.global_transform
			var fwd := -cg.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
			var heading := Basis(Vector3.UP, atan2(-fwd.x, -fwd.z))
			var shoulder := cg.origin + heading * Vector3(sgn * 0.0 + (-0.19 if i == 0 else 0.19), -0.24, 0.02)
			arm.update(shoulder, final_xf * Vector3(0, 0, 0.078), heading)
		h.palm = final_xf.origin
		h.vis_xf = final_xf
		h.tip = final_xf * Vector3(0, 0, -0.15 + 0.05 * idx_c)


# ---- moving about the room (green light) --------------------------------------------------------------
func _set_locked(on: bool) -> void:
	locked = on
	if on:
		room.set_active(machines.find(cab))
	else:
		for m in machines:
			m.set_lock_light(false)
	selector.set_shown(not on)
	leave_t = 0.0
	leave_prompt.visible = false
	if on and state == "title" and not progress.codes.has("story_seen"):
		_begin_intro()
	if not on and state == "intro":
		screen.video.stop()
		screen.mode = "title"
		state = "title"
	if not on and (state == "over" or state == "title"):
		audio.play_music("ambient", 1.0)
	if not on and state == "play":
		state = "paused"
		screen.mode = "paused"


## The opening of the phone game: the JW Eds card, then the three comic clips, then the title.
func _begin_intro() -> void:
	state = "intro"
	screen.start_intro()
	audio.current = ""
	audio.play_music("story", 0.6)


func _on_intro_done() -> void:
	if state != "intro":
		return
	state = "title"
	if not progress.codes.has("story_seen"):
		progress.codes.append("story_seen")
		progress.save()
	audio.current = ""
	audio.play_music("home", 1.0)


func _head_floor() -> Vector3:
	var g := cam.global_position
	return Vector3(g.x, 0.0, g.z)


func _menu_input(hs: Array) -> void:
	var pressed: bool = hs[0].menu or hs[1].menu
	if pressed and not menu_prev_btn:
		if menu.open:
			_close_menu()
		else:
			_open_menu()
	menu_prev_btn = pressed
	if menu.open:
		var ph := 0 if settings.pointer == "left" else 1
		menu.point(hs[ph].aim_origin, hs[ph].aim_dir, hs[ph].trigger)


func _locomotion(hs: Array, delta: float) -> void:
	if menu.open:
		selector.aim(Vector3.ZERO, Vector3.UP)
		leave_prompt.visible = false
		return
	# the hand that points: the chosen pointer hand, or the other one while it squeezes its trigger
	var ph := 0 if settings.pointer == "left" else 1
	if hs[1 - ph].trig_val > hs[ph].trig_val + 0.15:
		ph = 1 - ph
	if locked:
		selector.aim(Vector3.ZERO, Vector3.UP)
		if xr_on or demo:
			_leave_gesture(hs, ph, delta)
		for i in range(2):
			trig_prev[i] = hs[i].trigger
		return
	if not xr_on and not demo:
		return
	var hover := selector.aim(hs[ph].aim_origin, hs[ph].aim_dir)
	for i in range(2):
		var down: bool = hs[i].trigger
		if down and not trig_prev[i] and i == ph and not tele_busy:
			if hover >= 0:
				_choose(str(selector.targets[hover].id))
			elif selector.floor_ok:
				_move_to(selector.floor_pos)
		trig_prev[i] = down
	if not xr_on:
		return
	# smooth walking with the left stick, snap turns (45 degrees) with the right stick
	var mv: Vector2 = hs[0].stick
	if mv.length() > 0.2:
		_stand_up()
		var fwd := -cam.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := fwd.cross(Vector3.UP)
		var step := (fwd * mv.y + right * mv.x) * float(settings.walk) * delta
		origin.position += step
		var hp := _head_floor()
		var clamped := room.collide(hp)
		origin.position += clamped - hp
	var tx: float = hs[1].stick.x
	if str(settings.turn) == "smooth":
		if absf(tx) > 0.18:
			_turn(-tx * deg_to_rad(float(settings.turnspeed)) * delta)
	elif absf(tx) > 0.6 and turn_ready:
		turn_ready = false
		_turn(-signf(tx) * deg_to_rad(float(settings.snap)))
	elif absf(tx) < 0.3:
		turn_ready = true


func _turn(angle: float) -> void:
	var hp := _head_floor()
	var r := Basis(Vector3.UP, angle)
	origin.rotation.y += angle
	origin.position = hp + r * (origin.position - hp)


## Walks to a spot beside something (a jukebox, the pinball machine...), facing it. The screen fades briefly so it is comfortable.
func teleport_to_spot(spot: Array, machine := false) -> void:
	tele_busy = true
	audio.ui("switch")
	fade_quad.visible = true
	var m := fade_quad.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.tween_method(func(v: float): m.albedo_color.a = v, 0.0, 1.0, 0.12)
	tw.tween_callback(func(): _place_player(spot[2], spot[3], machine))
	tw.tween_method(func(v: float): m.albedo_color.a = v, 1.0, 0.0, 0.2)
	tw.tween_callback(func():
		fade_quad.visible = false
		tele_busy = false)


## Point and move: lands you where the ring showed, keeping the way you were facing.
func _move_to(p: Vector3) -> void:
	tele_busy = true
	audio.ui("switch")
	fade_quad.visible = true
	var m := fade_quad.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.tween_method(func(v: float): m.albedo_color.a = v, 0.0, 1.0, 0.1)
	tw.tween_callback(func():
		_stand_up()
		var hp := _head_floor()
		origin.position += p - hp)
	tw.tween_method(func(v: float): m.albedo_color.a = v, 1.0, 0.0, 0.18)
	tw.tween_callback(func():
		fade_quad.visible = false
		tele_busy = false)


var seated := false


## Sit on a bean bag: the player is moved onto it, turned to face the table, and lowered to seated eye height.
func _sit(sd: Array) -> void:
	tele_busy = true
	audio.ui("switch")
	fade_quad.visible = true
	var m := fade_quad.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.tween_method(func(v: float): m.albedo_color.a = v, 0.0, 1.0, 0.12)
	tw.tween_callback(func():
		_place_player(sd[1], sd[2])
		seated = true
		origin.position.y = float(settings.lift) - float(sd[3]) if sd.size() > 3 else float(settings.lift) - 0.55)
	tw.tween_method(func(v: float): m.albedo_color.a = v, 1.0, 0.0, 0.2)
	tw.tween_callback(func():
		fade_quad.visible = false
		tele_busy = false)


func _stand_up() -> void:
	if seated:
		seated = false
		origin.position.y = float(settings.lift)


func _floor_ok(p: Vector3) -> bool:
	return room.collide(p).distance_to(Vector3(p.x, 0.0, p.z)) < 0.06


## What the player chose by pointing and pulling the trigger.
func _choose(id: String) -> void:
	_haptic(-1, 0.3, 0.05)
	if id.begins_with("m") and id.substr(1).is_valid_int():
		audio.ui("toggle")
		_enter_machine(int(id.substr(1)))
		return
	if id == "exit":
		audio.ui("switch")
		_open_menu()
		return
	if id.begins_with("sit"):
		for sd in room.seats:
			if sd[0] == id:
				_sit(sd)
				return
	for spot in room.spots:
		if str(spot[0]) == id:
			teleport_to_spot(spot)
			return


## The things in the room that can be pointed at: each machine, the pinball table, the jukebox, the snack machine, the shelves,
## the score board, the lounge and the door. Boxes are in each thing's own space so they turn with it.
func _selector_targets() -> Array:
	var out: Array = []
	var amber := Color(1.0, 0.7, 0.25)
	for i in range(machines.size()):
		var m: Cabinet = machines[i]
		var zf := maxf(m.front_z, m.deck_front_z) + 0.1
		var box := AABB(Vector3(-0.35, 0.0, m.back_z), Vector3(0.7, 2.05, zf - m.back_z))
		out.append({"id": "m%d" % i, "label": "PLAY", "xf": m.global_transform, "box": box, "colour": m.theme_color, "always": true})
	out.append({"id": "pinball", "label": "PLAY", "xf": room.pinball.global_transform, "box": AABB(Vector3(-0.38, 0.0, -0.8), Vector3(0.76, 2.0, 1.75)), "colour": Color(1.0, 0.85, 0.2), "always": true})
	for sd in room.seats:
		out.append({"id": sd[0], "label": "SIT", "xf": Transform3D(Basis.IDENTITY, sd[1]), "box": AABB(Vector3(-0.25, 0.0, -0.25), Vector3(0.5, 0.85, 0.5)), "colour": Color(1.0, 0.45, 0.85), "always": true})
	out.append({"id": "exit", "label": "EXIT", "xf": Transform3D(Basis.IDENTITY, Vector3(0, 0, ArcadeRoom.FRONT_Z)), "box": AABB(Vector3(-1.15, 0.0, -0.2), Vector3(2.3, 2.55, 0.4)), "colour": Color(0.4, 1.0, 0.55)})
	return out


## While held at a machine: point clearly away from it, hold the trigger for two seconds, and you step back from it.
func _leave_gesture(hs: Array, ph: int, delta: float) -> void:
	var o: Vector3 = hs[ph].aim_origin
	var d: Vector3 = hs[ph].aim_dir
	var to_machine := (cab.look_world() - o)
	var away := d.dot(to_machine.normalized()) < 0.2          # more than about 78 degrees off the screen
	if away:
		for t in selector.targets:
			if t.id == "m%d" % machines.find(cab):
				away = _ray_hits_target(o, d, t) == false
	var holding: bool = hs[ph].trigger
	if away and holding:
		leave_t = minf(2.0, leave_t + delta)
	else:
		leave_t = maxf(0.0, leave_t - delta * 2.0)
	leave_prompt.visible = away
	if away:
		var f := -cam.global_transform.basis.z
		f.y = 0.0
		leave_prompt.global_position = cam.global_position + f.normalized() * 0.9 + Vector3(0, -0.28, 0)
		leave_prompt.look_at(cam.global_position + Vector3(0, -0.28, 0), Vector3.UP, true)
		leave_fill.scale.x = maxf(0.001, leave_t / 2.0)
		leave_fill.position.x = -0.15 + 0.15 * (leave_t / 2.0)
		leave_label.text = "HOLD THE TRIGGER TO LEAVE THE MACHINE" if leave_t < 0.05 else "LEAVING..."
	if leave_t >= 2.0:
		leave_t = 0.0
		leave_prompt.visible = false
		audio.ui("toggle")
		_haptic(-1, 0.4, 0.08)
		_set_locked(false)


func _ray_hits_target(o: Vector3, d: Vector3, t: Dictionary) -> bool:
	var inv: Transform3D = (t.xf as Transform3D).affine_inverse()
	var hit = (t.box as AABB).intersects_ray(inv * o, (inv.basis * d).normalized())
	return hit != null


func _build_leave_prompt() -> void:
	leave_prompt = Node3D.new()
	add_child(leave_prompt)
	leave_prompt.visible = false
	var back := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.34, 0.016)
	back.mesh = qm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.1, 0.1, 0.16, 0.85)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.no_depth_test = true
	back.material_override = bm
	back.position = Vector3(0, -0.04, 0)
	leave_prompt.add_child(back)
	leave_fill = MeshInstance3D.new()
	var fm := QuadMesh.new()
	fm.size = Vector2(0.3, 0.010)
	leave_fill.mesh = fm
	var fmm := StandardMaterial3D.new()
	fmm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmm.albedo_color = Color(0.3, 1.0, 0.6)
	fmm.no_depth_test = true
	fmm.render_priority = 1
	leave_fill.material_override = fmm
	leave_fill.position = Vector3(-0.15, -0.04, 0.001)
	leave_prompt.add_child(leave_fill)
	leave_label = VRBuild.label(leave_prompt, "HOLD THE TRIGGER TO LEAVE THE MACHINE", 0.03, Vector3(0, 0.0, 0), Color(1, 1, 1), Vector3.ZERO, 6, font)
	leave_label.no_depth_test = true
	leave_label.render_priority = 5


func _place_player(pos: Vector3, look: Vector3, machine := false) -> void:
	if not xr_on:
		return
	var dir := look - pos
	dir.y = 0.0
	if machine and dir.length() > 0.01:
		pos -= dir.normalized() * float(settings.reach)       # positive = stand further back
	dir = look - pos
	var want_yaw := atan2(-dir.x, -dir.z)
	var f := cam.transform.basis * Vector3(0, 0, -1)
	f.y = 0.0
	var local_yaw := atan2(-f.x, -f.z)
	origin.rotation.y = want_yaw - local_yaw
	var head := Vector3(cam.position.x, 0.0, cam.position.z)
	origin.position = pos - Basis(Vector3.UP, origin.rotation.y) * head
	origin.position.y = float(settings.lift)
	seated = false


func _stick(hs: Array, delta: float) -> void:
	var ball := cab.ball_world_position()
	if grab_hand == -1:
		for i in range(2):
			var h: Dictionary = hs[i]
			if (h.gripping or h.trigger) and h.grip.distance_to(ball) < GRAB_RADIUS * cab.scale.x:
				grab_hand = i
				_haptic(i, 0.5, 0.06)
				audio.sfx("switch", 0.6)
				break
	if grab_hand >= 0:
		var h: Dictionary = hs[grab_hand]
		if not (h.gripping or h.trigger):
			grab_hand = -1
			audio.sfx("toggle", 0.5)
		else:
			var local := cab.to_panel(h.grip)
			var v := local - (Cabinet.STICK_LOCAL + Vector3(0, 0.03, 0))
			var up := maxf(v.y, 0.06)
			roll = clampf(atan2(v.x, up), -Cabinet.MAX_TILT, Cabinet.MAX_TILT)
			pitch = clampf(atan2(v.z, up), -Cabinet.MAX_TILT * 0.7, Cabinet.MAX_TILT * 0.7)
	if grab_hand == -1:
		var k := exp(-delta * 22.0)    # spring back to centre
		roll *= k
		pitch *= k
	cab.set_stick(roll, pitch)
	var raw := roll / Cabinet.MAX_TILT
	var m := 0.0 if absf(raw) < DEADZONE else signf(raw) * (absf(raw) - DEADZONE) / (1.0 - DEADZONE)
	# assist: thumbstick on either controller moves Joey too
	for h in hs:
		var sx: float = h.get("stick", Vector2.ZERO).x
		if locked and str(settings.assist) == "on" and absf(sx) > 0.25:
			m = sx
			run_assisted = true
	var prev := axis
	axis = clampf(m * 1.12, -1.0, 1.0)
	axis_seen = maxf(axis_seen, absf(axis))
	if absf(axis) > 0.55 and absf(prev) <= 0.55 and grab_hand >= 0:
		audio.sfx("switch", 0.5)
		_haptic(grab_hand, 0.35, 0.03)


func _buttons(hs: Array) -> void:
	var down := {"fire": false, "grenade": false, "menu": false, "pause": false}
	for i in range(hs.size()):
		var h: Dictionary = hs[i]
		for use_tip in [true, false]:
			var p: Vector3 = h.tip if use_tip else h.palm
			var hit := cab.button_at(cab.to_panel(p), 0.06 if use_tip else 0.08)
			if hit != "" and grab_hand != i and (hit != "menu" or use_tip):
				down[hit] = true
		if locked and not menu.open and str(settings.assist) == "on" and h.trigger and h.grip.distance_to(cab.ball_world_position()) > 0.2:
			down["fire"] = true       # assist: any trigger fires (the score is marked with an asterisk)
			if state == "play":
				run_assisted = true
		if h.get("a", false) and str(settings.assist) == "on":
			down["grenade"] = true
			if state == "play":
				run_assisted = true
		if h.get("b", false):
			down["pause"] = true
	for k in down:
		cab.button_pressed_visual(k, down[k])
	var fire_edge: bool = down.fire and not fire_now
	fire_now = down.fire
	if fire_edge:
		_haptic(-1, 0.25, 0.04)
		if state == "title":
			audio.ui("chime")
			start_game()
		elif state == "intro":
			screen.skip_intro()
		elif state == "over" and clock - over_at > 1.5:
			audio.ui("chime")
			start_game()
	if down.grenade and not grenade_prev:
		_haptic(-1, 0.3, 0.05)
		if state == "play" and game != null:
			game.throw_grenade()
		else:
			audio.ui("click")
	grenade_prev = down.grenade
	# the machine's MENU button pauses; pressed again while paused it opens the options board (the way to reach it with bare hands)
	if down.menu and not menu_prev:
		if menu.open:
			_close_menu()
		elif state == "play":
			audio.ui("back")
			state = "paused"
			screen.mode = "paused"
		elif state == "paused":
			_open_menu()
		else:
			_open_menu()
	menu_prev = down.menu
	# the B button on a controller toggles pause
	if down.pause and not pause_prev:
		audio.ui("back")
		if state == "play":
			state = "paused"
			screen.mode = "paused"
		elif state == "paused":
			state = "play"
			screen.mode = "play"
	pause_prev = down.pause


## Settling in at a machine: a quick fade, the player is placed exactly in front of it, then the screen powers up and the controls light.
func _enter_machine(i: int) -> void:
	tele_busy = true
	fade_quad.visible = true
	var fm := fade_quad.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.tween_method(func(v: float): fm.albedo_color.a = v, 0.0, 1.0, 0.14)
	tw.tween_callback(func():
		_select_machine(i)
		_place_player(cab.stand_world(), cab.look_world(), true)
		_set_locked(true)
		cab.screen_mat.albedo_color = Color(0.1, 0.1, 0.1)
		audio.sfx("power", 0.6, 0.0, cab.global_position + Vector3(0, 1.3, 0.3)))
	tw.tween_method(func(v: float): fm.albedo_color.a = v, 1.0, 0.0, 0.3)
	tw.tween_callback(func():
		fade_quad.visible = false
		tele_busy = false
		_haptic(-1, 0.35, 0.1))
	# the monitor warms up from dark to full brightness
	var sm := cab.screen_mat
	var tw2 := create_tween()
	tw2.tween_interval(0.16)
	tw2.tween_method(func(v: float): sm.albedo_color = Color(v, v, v), 0.1, 1.0, 0.8)


## Makes a machine the one in play: the live screen, the sound and the controls move to it.
func _select_machine(i: int) -> void:
	var m: Cabinet = machines[i]
	if m == cab:
		return
	grab_hand = -1
	roll = 0.0
	pitch = 0.0
	cab.set_stick(0.0, 0.0)
	cab.set_live(null)
	for k in cab.caps:
		cab.button_pressed_visual(k, false)
	cab = m
	cab.set_live(cartridge.screen_texture())
	cab.screen_mat.albedo_color = Color.WHITE
	cab.set_topper_color(VRMenu.TOPPERS[settings.topper])
	room.set_active(i)
	audio.move_to(cab)


# ---- a camera tour of the room, for a video ----------------------------------------------------------------
func _run_tour() -> void:
	room.prize_wall.set_unlocked(7, true)
	progress.last = {"score": 48210, "wave": 7, "kills": 212, "bosses": 3, "seconds": 400}
	progress.best = 61500
	progress.badges = ["first_boss", "score_10k", "wave_10"]
	room.hall.rows = [{"username": "SAMPLE ONE", "score": 912340}, {"username": "SAMPLE TWO", "score": 640200}, {"username": "SAMPLE THREE", "score": 233100}]
	room.hall.refresh()
	start_game()
	demo = true
	# [camera position, look-at point, seconds to get there, seconds to hold]
	var st := cab.stand_world()
	var stops := [
		[st + Vector3(0, 1.68, 0), cab.look_world() - Vector3(0, 0.1, 0), 0.1, 4.0],
		[st + Vector3(0.05, 1.55, 0.0), cab.panel.global_position + Vector3(0, 0.1, 0), 2.0, 3.0],
		[cab.to_global(Vector3(0.9, 1.5, 1.7)), cab.to_global(Vector3(0, 1.05, -0.3)), 2.5, 2.5],
		[cab.to_global(Vector3(1.3, 1.2, -0.3)), cab.to_global(Vector3(0, 1.0, -0.3)), 3.0, 2.5],
		[cab.to_global(Vector3(0.7, 1.3, -1.8)), cab.to_global(Vector3(0, 1.0, -0.4)), 3.0, 2.5],
		[cab.to_global(Vector3(-1.3, 1.2, -0.3)), cab.to_global(Vector3(0, 1.0, -0.3)), 3.0, 2.5],
		[cab.to_global(Vector3(0.0, 1.5, 1.7)), cab.to_global(Vector3(0, 1.1, -0.3)), 3.0, 2.0],
		[Vector3(0, 1.75, 0.3), Vector3(0, 1.3, 5.5), 3.5, 3.0],
		[Vector3(-0.8, 1.7, 0.2), Vector3(-3.1, 1.2, 4.2), 3.5, 3.0, "m1"],
		[Vector3(0.8, 1.7, 0.2), Vector3(3.1, 1.2, 4.2), 5.0, 3.0, "m5"],
		[Vector3(0, 1.7, 3.0), Vector3(0, 1.9, -0.55), 4.0, 3.0],
		[Vector3(-1.4, 1.6, 1.8), Vector3(-1.85, 1.2, -0.3), 3.0, 3.0],
		[Vector3(1.4, 1.6, 1.8), Vector3(1.8, 1.2, -0.05), 3.0, 3.0],
		[Vector3(0, 1.7, 0.9), Vector3(0, 1.3, -5.0), 3.0, 5.0],
		[Vector3(-1.6, 1.7, 1.2), Vector3(0, 0.4, 2.9), 3.5, 3.0, "sit1"],
		[Vector3(1.7, 1.1, 3.9), Vector3(0, 0.4, 2.9), 3.0, 3.5],
		[Vector3(0, 1.7, 4.6), Vector3(0, 1.1, 6.5), 3.5, 2.0, "pinball"],
		[Vector3(0, 1.65, 5.38), Vector3(0, 0.8, 6.3), 3.0, 4.0],
		[Vector3(-2.3, 1.6, 5.6), Vector3(-2.3, 1.6, 7.2), 3.5, 3.0],
		[Vector3(-2.3, 1.55, 6.3), Vector3(-2.3, 1.45, 7.2), 2.5, 3.0],
		[Vector3(2.2, 1.65, 5.2), Vector3(2.2, 1.85, 7.2), 3.5, 4.0],
	]
	var pos: Vector3 = stops[0][0]
	var look: Vector3 = stops[0][1]
	for stop in stops:
		selector.forced = -1
		selector.set_shown(false)
		if stop.size() > 4:
			for ti in range(selector.targets.size()):
				if selector.targets[ti].id == str(stop[4]):
					selector.forced = ti
			selector.set_shown(true)
		var p0 := pos
		var l0 := look
		var t := 0.0
		var dur: float = stop[2]
		while t < dur:
			await get_tree().process_frame
			t += get_process_delta_time()
			var k := smoothstep(0.0, 1.0, minf(t / dur, 1.0))
			cam.look_at_from_position(p0.lerp(stop[0], k), l0.lerp(stop[1], k), Vector3.UP)
		pos = stop[0]
		look = stop[1]
		await get_tree().create_timer(float(stop[3])).timeout
	get_tree().quit()


# ---- screenshots for development --------------------------------------------------------------------------
func _run_shots() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	await get_tree().create_timer(2.5).timeout
	var st := cab.stand_world()
	var views := {
		"head": [st + Vector3(0, 1.68, 0), cab.look_world() - Vector3(0, 0.1, 0)],
		"panel": [st + Vector3(0, 1.7, 0), cab.panel.global_position],
		"hands": [st + Vector3(0.05, 1.55, 0.0) + Vector3(0, 0, 0), cab.panel.global_position + Vector3(0, 0.1, 0)],
		"overview": [Vector3(0, 1.75, 0.3), Vector3(0, 1.3, 5.5)],
		"door": [Vector3(0, 1.7, 3.2), Vector3(0, 1.5, -0.55)],
		"outside": [Vector3(0, 1.7, 1.0), Vector3(0, 1.3, -5.0)],
		"cab_side": [cab.to_global(Vector3(1.25, 1.1, -0.3)), cab.to_global(Vector3(0, 1.0, -0.3))],
		"cab_sideL": [cab.to_global(Vector3(-1.25, 1.1, -0.3)), cab.to_global(Vector3(0, 1.0, -0.3))],
		"cab_back": [cab.to_global(Vector3(0.6, 1.4, -1.9)), cab.to_global(Vector3(0, 1.0, -0.4))],
		"cab_threeq": [cab.to_global(Vector3(1.3, 1.7, 1.5)), cab.to_global(Vector3(0, 1.1, -0.2))],
		"cab_front": [cab.to_global(Vector3(0.0, 1.6, 1.6)), cab.to_global(Vector3(0, 1.1, -0.2))],
		"cab_top": [cab.to_global(Vector3(0.9, 2.2, 0.7)), cab.to_global(Vector3(0, 1.2, -0.3))],
		"logo": [Vector3(2.0, 1.7, 1.6), Vector3(3.0, 2.0, -0.55)],
		"jukebox": [Vector3(-2.7, 1.6, 4.3), Vector3(-4.2, 1.3, 5.2)],
		"scare": [Vector3(0.6, 1.65, 2.2), Vector3(0, 1.1, -0.55)],
		"arc_l": [Vector3(0.3, 1.7, 2.6), Vector3(-3.0, 1.3, 2.0)],
		"arc_r": [Vector3(-0.3, 1.7, 2.6), Vector3(3.0, 1.3, 2.0)],
		"pinball": [Vector3(0, 1.7, 5.3), Vector3(0, 1.1, 7.2)],
		"pin_top": [Vector3(0, 1.55, 6.15), Vector3(0, 0.85, 7.3)],
		"pin_side": [Vector3(1.9, 1.3, 6.1), Vector3(0, 0.95, 7.3)],
		"keypad": [Vector3(3.4, 1.55, 6.6), Vector3(3.95, 1.35, 7.55)],
		"vend_front": [Vector3(3.0, 1.5, 5.2), Vector3(3.9, 1.1, 7.5)],
		"arms": [Vector3(0, 1.7, 5.4), Vector3(0, 1.4, 7.0)],
		"vending": [Vector3(2.6, 1.7, 5.6), Vector3(3.9, 1.0, 7.5)],
		"prizes": [Vector3(-2.65, 1.65, 6.5), Vector3(-2.65, 1.5, 8.0)],
		"hall": [Vector3(2.2, 1.65, 6.0), Vector3(2.2, 1.85, 8.1)],
		"bobbles": [Vector3(-2.65, 1.6, 6.9), Vector3(-2.65, 1.55, 8.0)],
		"bobble_a": [Vector3(-3.35, 1.5, 7.3), Vector3(-3.35, 1.4, 8.0)],
		"bobble_b": [Vector3(-2.0, 1.5, 7.3), Vector3(-2.0, 1.4, 8.0)],
		"bobble_c": [Vector3(-2.65, 1.95, 7.3), Vector3(-2.65, 1.9, 8.0)],
		"menu": [st + Vector3(0, 1.62, 0.0), cab.look_world()],
		"themed": [Vector3(-2.2, 1.6, 2.3), Vector3(-2.7, 1.1, 0.9)],
		"themed2": [Vector3(2.2, 1.6, 2.3), Vector3(2.7, 1.1, 0.9)],
	}
	for mi in range(machines.size()):
		var mc: Cabinet = machines[mi]
		views["m%d_R" % mi] = [mc.to_global(Vector3(1.1, 1.1, -0.3)), mc.to_global(Vector3(0, 1.0, -0.3))]
		views["m%d_L" % mi] = [mc.to_global(Vector3(-1.1, 1.1, -0.3)), mc.to_global(Vector3(0, 1.0, -0.3))]
	var plan: Array = String(args.get("views", "head,panel,overview,door,pinball")).split(",")
	if args.has("intro"):
		_begin_intro()
		await get_tree().create_timer(float(args.get("intro", "5"))).timeout
	if args.has("play") or args.has("demo"):
		if args.has("play"):
			start_game()
		demo = true
		await get_tree().create_timer(float(args.get("wait", "6"))).timeout
	if args.has("pinplay"):
		room.pinball.viewport.get_texture().get_image().save_png("%s/pin_viewport.png" % shot_dir)
	for v in plan:
		cam.look_at_from_position(views[v][0], views[v][1], Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [shot_dir, v])
		print("shot ", v, " draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), " tris ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit()
