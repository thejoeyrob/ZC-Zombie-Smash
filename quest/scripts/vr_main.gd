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
var teleporter: Teleporter
var fade_quad: MeshInstance3D
var lock_prev := false
var pause_prev := false
var turn_ready := true
var trig_prev := [false, false]
var tele_busy := false
const SETTINGS_PATH := "user://settings.json"
var settings := {"music": 0.55, "effects": 0.8, "height": 1.0, "snap": 45, "walk": 1.5, "haptics": 1.0, "topper": "yellow", "pointer": "right", "assist": "trigger fires", "hud": "on", "battle": "JORDAN"}
var progress := VRProgress.new()
var run_bosses := 0
var run_grenades := 0
var run_hurt_wave := false
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
	room = ArcadeRoom.new()
	var banner: Texture2D = load("res://assets/art/game-banner.webp")
	room.build(self, viewport.get_texture(), banner, font, progress)
	machines = room.machines
	cab = machines[room.player_index]
	cab.set_live(viewport.get_texture())
	room.set_active(room.player_index)
	room.prize_wall.set_unlocked(progress.unlocked(), true)
	room.pinball.set_enabled(progress.codes.has("pinball"))
	room.pinball.table.best = progress.pinball_best
	room.vending.code_entered.connect(_on_code)
	room.vending.key_pressed.connect(func(k, ok): audio.sfx("key" if ok else "error", 0.7, 0.0, room.vending.global_position + Vector3(0, 1.3, 0.5)); _haptic(-1, 0.2, 0.03))
	room.pinball.sound.connect(_on_pinball_sound)
	room.door.scare.connect(func(kind): audio.sfx("doom" if kind != "stare" else "warn", 0.45, 0.0, Vector3(0, 1.4, -0.6)))
	room.prize_wall.grabbed.connect(func(_i, open): audio.sfx("pickup" if open else "switch", 0.7); _haptic(1, 0.35, 0.05))
	room.prize_wall.dropped.connect(func(_i): audio.sfx("toggle", 0.6))
	_build_hands()
	teleporter = Teleporter.new()
	teleporter.build(self, room.spots)
	_build_fade()
	_load_settings()
	menu = VRMenu.new()
	menu.build(self, font, settings, build_number())
	# a small build number on the machine's panel and on the floor sign, so a new install is easy to recognise
	for m in machines:
		VRBuild.label(m.panel, "BUILD %d" % build_number(), 0.03, Vector3(0.27, 0.003, 0.105), Color(1, 1, 1, 0.55), Vector3(-PI / 2, 0, 0), 3)
	menu.changed.connect(_on_setting)
	menu.action.connect(_on_menu_action)
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
	audio.play_music("home", 0.01)
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
	viewport.size = Vector2i(686, 824)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)
	screen = ZSScreen.new()
	screen.scale = Vector2(2, 2)
	viewport.add_child(screen)
	screen.preload_all()


static func _blank_hand() -> Dictionary:
	return {"xf": Transform3D.IDENTITY, "grip": Vector3.ZERO, "gripping": false, "trigger": false, "grip_val": 0.0, "trig_val": 0.0,
		"stick": Vector2.ZERO, "a": false, "b": false, "menu": false, "aim_origin": Vector3.ZERO, "aim_dir": Vector3.FORWARD, "active": true, "bare": false, "thumb": -1.0}


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


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


func _on_setting(key: String, value) -> void:
	settings[key] = value
	match key:
		"music", "effects":
			audio.set_volumes(float(settings.music), float(settings.effects))
		"height":
			_apply_height()
		"topper":
			cab.set_topper_color(VRMenu.TOPPERS[value])
		"snap":
			settings.snap = int(value)
		"hud":
			screen.no_shake = value == "off"
	if key != "music" and key != "effects" and key != "height" and key != "haptics":
		audio.ui("click")
	_save_settings()


func _apply_height() -> void:
	for m in machines:
		m.scale = Vector3.ONE * clampf(base_scale * float(settings.height), 0.7, 1.4)


func _on_code(action: String) -> void:
	if action == "pinball":
		if not progress.codes.has("pinball"):
			progress.codes.append("pinball")
			progress.save()
		room.pinball.set_enabled(true)
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


func _on_menu_action(name: String) -> void:
	match name:
		"resume":
			_close_menu()
		"recentre":
			_close_menu()
			recenter()
		"quit":
			get_tree().quit()
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
				audio.play_music("home", 1.0)


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
	var fresh := progress.record_run(game.score, game.wave, game.kills, run_bosses, run_grenades, run_clean_wave, clock - run_start)
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
	var h := cam.global_position.y
	if h > 0.9:
		base_scale = clampf(h / 1.70, 0.8, 1.2)
		_apply_height()
	_place_player(cab.stand_world(), cab.look_world())


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
	return d


var _key_last := ["", ""]


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
		vis.set_pose(idx_c, grip_c, 0.9 if holding else thumb_c)
		vis.global_transform = final_xf
		vis.visible = (xr_on and h.active) or demo
		var arm: VRArm = hands[i].arm
		arm.visible = vis.visible
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
	teleporter.set_shown(not on)
	if not on and state == "play":
		state = "paused"
		screen.mode = "paused"


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
		teleporter.aim(Vector3.ZERO, Vector3.UP)
		return
	if locked or not xr_on and not demo:
		teleporter.aim(Vector3.ZERO, Vector3.UP)
		return
	# pointing: the right hand, or whichever hand is squeezing its trigger harder
	var ph := 1
	if hs[0].trig_val > hs[1].trig_val + 0.15:
		ph = 0
	var hover := teleporter.aim(hs[ph].aim_origin, hs[ph].aim_dir)
	for i in range(2):
		var down: bool = hs[i].trigger
		if down and not trig_prev[i] and i == ph and hover >= 0 and not tele_busy:
			teleport_to(hover)
		trig_prev[i] = down
	if not xr_on:
		return
	# smooth walking with the left stick, snap turns (45 degrees) with the right stick
	var mv: Vector2 = hs[0].stick
	if mv.length() > 0.2:
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
	if absf(tx) > 0.6 and turn_ready:
		turn_ready = false
		_turn(-signf(tx) * deg_to_rad(float(settings.snap)))
	elif absf(tx) < 0.3:
		turn_ready = true


func _turn(angle: float) -> void:
	var hp := _head_floor()
	var r := Basis(Vector3.UP, angle)
	origin.rotation.y += angle
	origin.position = hp + r * (origin.position - hp)


## Jumps to a floor marker, facing the way its arrow points. The screen fades for a moment so it is comfortable.
func teleport_to(idx: int) -> void:
	tele_busy = true
	audio.ui("switch")
	fade_quad.visible = true
	var m := fade_quad.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.tween_method(func(v: float): m.albedo_color.a = v, 0.0, 1.0, 0.12)
	tw.tween_callback(func(): _place_player(teleporter.spots[idx][2], teleporter.spots[idx][3]))
	tw.tween_method(func(v: float): m.albedo_color.a = v, 1.0, 0.0, 0.2)
	tw.tween_callback(func():
		fade_quad.visible = false
		tele_busy = false
		if str(teleporter.spots[idx][0]) == "exit":
			_open_menu())


func _place_player(pos: Vector3, look: Vector3) -> void:
	if not xr_on:
		return
	var dir := look - pos
	var want_yaw := atan2(-dir.x, -dir.z)
	var f := cam.transform.basis * Vector3(0, 0, -1)
	f.y = 0.0
	var local_yaw := atan2(-f.x, -f.z)
	origin.rotation.y = want_yaw - local_yaw
	var head := Vector3(cam.position.x, 0.0, cam.position.z)
	origin.position = pos - Basis(Vector3.UP, origin.rotation.y) * head


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
		if locked and absf(sx) > 0.25:
			m = sx
	var prev := axis
	axis = clampf(m * 1.12, -1.0, 1.0)
	axis_seen = maxf(axis_seen, absf(axis))
	if absf(axis) > 0.55 and absf(prev) <= 0.55 and grab_hand >= 0:
		audio.sfx("switch", 0.5)
		_haptic(grab_hand, 0.35, 0.03)


func _buttons(hs: Array) -> void:
	var down := {"fire": false, "grenade": false, "menu": false, "lock": false, "pause": false}
	for i in range(hs.size()):
		var h: Dictionary = hs[i]
		for use_tip in [true, false]:
			var p: Vector3 = h.tip if use_tip else h.palm
			var hit := cab.button_at(cab.to_panel(p), 0.032 if use_tip else 0.07)
			if hit != "" and grab_hand != i and (hit != "lock" or use_tip):
				down[hit] = true
			if not locked and use_tip:
				for m in machines:
					if m != cab and m.button_at(m.to_panel(p), 0.032) == "lock":
						down["lock"] = true
		if locked and not menu.open and settings.assist == "trigger fires" and h.trigger and h.grip.distance_to(cab.ball_world_position()) > 0.2:
			down["fire"] = true       # assist: any trigger fires
		if h.get("a", false):
			down["grenade"] = true
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
	if down.lock and not lock_prev:
		_press_lock()
	lock_prev = down.lock


## A machine's LOCK button: red keeps you at that machine, green lets you walk and teleport.
func _press_lock() -> void:
	_haptic(-1, 0.4, 0.06)
	if locked:
		audio.ui("toggle")
		_set_locked(false)
		return
	# going back to red: you must be standing at a machine; the player is placed exactly in front of it
	var best := -1
	var best_d := 1.4
	for i in range(machines.size()):
		var d := _head_floor().distance_to(machines[i].stand_world())
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		audio.ui("error")
		return
	audio.ui("toggle")
	_select_machine(best)
	_place_player(cab.stand_world(), cab.look_world())
	_set_locked(true)


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
	cab.set_live(viewport.get_texture())
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
		[Vector3(0, 1.75, 0.3), Vector3(0, 1.3, 5.5), 3.5, 2.5],
		[Vector3(0.3, 1.7, 2.6), Vector3(-3.0, 1.3, 2.0), 3.0, 2.5],
		[Vector3(-0.3, 1.7, 2.6), Vector3(3.0, 1.3, 2.0), 4.0, 2.5],
		[Vector3(0, 1.7, 3.2), Vector3(0, 1.5, -0.55), 3.0, 3.0],
		[Vector3(0, 1.7, 1.0), Vector3(0, 1.3, -5.0), 2.5, 5.0],
		[Vector3(0, 1.7, 5.3), Vector3(0, 1.1, 7.2), 4.0, 3.0],
		[Vector3(2.6, 1.7, 5.6), Vector3(3.9, 1.0, 7.5), 3.0, 3.0],
		[Vector3(-2.65, 1.6, 6.5), Vector3(-2.65, 1.5, 8.0), 3.5, 2.5],
		[Vector3(-3.35, 1.5, 7.3), Vector3(-3.35, 1.4, 8.0), 2.5, 2.5],
		[Vector3(-2.0, 1.5, 7.3), Vector3(-2.0, 1.4, 8.0), 2.5, 2.5],
		[Vector3(2.2, 1.65, 6.0), Vector3(2.2, 1.85, 8.1), 3.5, 4.0],
	]
	var pos: Vector3 = stops[0][0]
	var look: Vector3 = stops[0][1]
	for stop in stops:
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
	var plan: Array = String(args.get("views", "head,panel,overview,door,pinball")).split(",")
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
