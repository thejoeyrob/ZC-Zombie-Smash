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

# development / screenshot helpers (desktop only)
var args := {}
var demo := false
var demo_t := 0.0
var shot_plan: Array = []
var shot_dir := "/tmp/claude-0/qvr"
var sim_hands: Array = [{"grip": Vector3.ZERO, "tip": Vector3.ZERO, "gripping": false, "trigger": false}, {"grip": Vector3.ZERO, "tip": Vector3.ZERO, "gripping": false, "trigger": false}]


func _ready() -> void:
	ZSEngine.setup()
	for a in OS.get_cmdline_user_args():
		var kv := a.lstrip("-").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_load_best()
	font = load("res://assets/fonts/font-barlow-condensed-900.woff2")
	_setup_xr()
	_build_screen()
	room = ArcadeRoom.new()
	var banner: Texture2D = load("res://assets/art/game-banner.webp")
	room.build(self, viewport.get_texture(), banner, font)
	cab = room.main_cabinet
	cab.position.z = -0.52
	_build_hands()
	audio = ZSAudio.new()
	add_child(audio)
	audio.setup(cab)
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
	cam.position = Vector3(0, 1.68, 0.0)
	cam.fov = 70.0
	cam.look_at_from_position(cam.position, Vector3(0, 1.38, -0.6), Vector3.UP)


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
		# a soft white arcade glove on each hand
		var glove := VRBuild.mat(Color(0.93, 0.93, 0.96), 0.6)
		VRBuild.sphere(grip, 0.043, Vector3(0, -0.01, -0.03), glove, 16)
		VRBuild.cylinder(grip, 0.034, 0.05, Vector3(0, -0.01, 0.025), VRBuild.mat(Color(0.8, 0.1, 0.15), 0.6), -1.0, Vector3(PI / 2, 0, 0), 14)
		var hand := {"ctrl": grip, "aim": aim, "side": side}
		hands.append(hand)
		if not xr_on:
			grip.visible = false


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
	audio.want = "main"
	audio.wave = 1


func _on_event(type: String, data: Dictionary) -> void:
	audio.on_event(type, data, game)
	match type:
		"shot": _haptic(grab_hand_other(), 0.18, 0.04)
		"hurt": _haptic(-1, 0.9, 0.25)
		"explosion": _haptic(-1, 0.7, 0.2)
		"bossAttack": _haptic(-1, 0.35, 0.12)
		"pickup": _haptic(-1, 0.4, 0.08)
		"mutation": _haptic(-1, 0.9, 0.5)
		"bossDown": _haptic(-1, 1.0, 0.6)
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
	if game.score > best:
		best = game.score
		_save_best()
		audio.stinger("highscore")
	screen.best = best
	screen.mode = "over"
	audio.play_music("over", 1.0)


func _haptic(side: int, amp: float, dur: float) -> void:
	if not xr_on:
		return
	for h in hands:
		if side == -1 or h.side == side:
			h.ctrl.trigger_haptic_pulse("haptic", 0.0, amp, dur, 0.0)


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
	_calibrate(delta)
	var hs := _read_hands(delta)
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
	var yaw := cam.rotation.y
	origin.rotation.y = -yaw
	var head := Vector3(cam.position.x, 0.0, cam.position.z)
	origin.position = -(Basis(Vector3.UP, origin.rotation.y) * head)
	var h := cam.global_position.y
	if h > 0.9:
		cab.scale = Vector3.ONE * clampf(h / 1.70, 0.8, 1.2)


## Returns both hands as {grip, tip, gripping, trigger}; from the controllers in VR, simulated on the desktop.
func _read_hands(delta: float) -> Array:
	if xr_on:
		var out: Array = []
		for h in hands:
			var c: XRController3D = h.ctrl
			var a: XRController3D = h.aim
			var grip_val := c.get_float("grip")
			var trig_val := c.get_float("trigger")
			out.append({
				"grip": c.global_position,
				"tip": a.global_transform * Vector3(0, 0, -0.06),
				"gripping": c.is_button_pressed("grip_click") or grip_val > 0.6,
				"trigger": c.is_button_pressed("trigger_click") or trig_val > 0.6,
				"stick": c.get_vector2("primary"),
				"a": c.is_button_pressed("ax_button"),
				"b": c.is_button_pressed("by_button"),
				"menu": c.is_button_pressed("menu_button"),
			})
		return out
	_simulate_hands(delta)
	return sim_hands


func _simulate_hands(delta: float) -> void:
	if not demo:
		return
	demo_t += delta
	# left hand grabs the stick and swings it side to side; right hand sits on the FIRE button for a while
	var ball := cab.ball_world_position()
	var swing := sin(demo_t * 1.3)
	sim_hands[0] = {"grip": cab.panel.global_transform * (Cabinet.STICK_LOCAL + Vector3(swing * 0.07, Cabinet.STICK_LENGTH + 0.03, 0.0)), "tip": ball,
		"gripping": demo_t > 0.5, "trigger": false, "stick": Vector2.ZERO, "a": false, "b": false, "menu": false}
	var fire_pos: Vector3 = cab.panel.global_transform * (Cabinet.BUTTONS.fire.pos + Vector3(0, 0.02, 0))
	var on := fmod(demo_t, 3.0) < 2.2 and demo_t > 1.0
	sim_hands[1] = {"grip": fire_pos + Vector3(0, 0.05, 0.04), "tip": fire_pos if on else fire_pos + Vector3(0, 0.12, 0), "gripping": false, "trigger": false,
		"stick": Vector2.ZERO, "a": fmod(demo_t, 7.0) > 6.7, "b": false, "menu": false}


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
		if absf(sx) > 0.25:
			m = sx
	var prev := axis
	axis = clampf(m * 1.12, -1.0, 1.0)
	axis_seen = maxf(axis_seen, absf(axis))
	if absf(axis) > 0.55 and absf(prev) <= 0.55 and grab_hand >= 0:
		audio.sfx("switch", 0.5)
		_haptic(grab_hand, 0.35, 0.03)


func _buttons(hs: Array) -> void:
	var down := {"fire": false, "grenade": false, "menu": false}
	for i in range(hs.size()):
		var h: Dictionary = hs[i]
		for use_tip in [true, false]:
			var p: Vector3 = h.tip if use_tip else h.grip
			var hit := cab.button_at(cab.to_panel(p), 0.05 if use_tip else 0.065)
			if hit != "" and grab_hand != i:
				down[hit] = true
		if h.trigger and h.grip.distance_to(cab.ball_world_position()) > 0.2:
			down["fire"] = true       # assist: any trigger fires
		if h.get("a", false):
			down["grenade"] = true
		if h.get("b", false) or h.get("menu", false):
			down["menu"] = true
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
	if down.menu and not menu_prev:
		audio.ui("back")
		if state == "play":
			state = "paused"
			screen.mode = "paused"
		elif state == "paused":
			state = "play"
			screen.mode = "play"
	menu_prev = down.menu


# ---- screenshots for development --------------------------------------------------------------------------
func _run_shots() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	await get_tree().create_timer(2.5).timeout
	var views := {
		"head": [Vector3(0, 1.68, 0.0), Vector3(0, 1.38, -0.6)],
		"panel": [Vector3(0, 1.7, 0.0), Vector3(0, 1.0, -0.42)],
		"wide": [Vector3(1.6, 1.9, 3.3), Vector3(0, 1.2, -0.8)],
		"left": [Vector3(0.4, 1.7, 0.2), Vector3(-2.8, 1.3, 1.9)],
		"back": [Vector3(0, 1.7, 0.0), Vector3(0, 1.6, 4.0)],
	}
	var plan: Array = String(args.get("views", "head,panel,wide,left,back")).split(",")
	if args.has("play"):
		start_game()
		demo = true
		await get_tree().create_timer(float(args.get("wait", "6"))).timeout
	for v in plan:
		cam.look_at_from_position(views[v][0], views[v][1], Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [shot_dir, v])
		print("shot ", v, " draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), " tris ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit()
