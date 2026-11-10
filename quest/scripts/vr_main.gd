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
var emu: EmuLauncher            # the JW EDS machine's text-mode game menu
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
var pin_latch: Array = [null, null]      # world spot of the pinball flipper button each hand is holding (or null)
var grab_hand2 := -1            # the hand on the second (right) stick of a two-stick machine
var roll := 0.0
var pitch := 0.0
var roll2 := 0.0
var pitch2 := 0.0
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
var settings := {"music": 0.55, "effects": 0.8, "lift": 0.0, "reach": 0.0, "turn": "smooth", "turnspeed": 90, "snap": 45, "walk": 1.5, "haptics": 1.0, "topper": "yellow", "pointer": "right", "assist": "off", "handroll": 0, "handtilt": 0, "hud": "on", "battle": "JORDAN", "skin": "human_joeyrob", "body": "full", "handmode": "auto", "sharp": 1.3, "glow": "on", "auto": "on", "fps": "off"}
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
var _pinching := [false, false]
var _gripping := [false, false]
var social: ShackSession          # the multiplayer room session; every hook stays idle until a room is joined
var avatar: VRAvatar
var wrist: WristPanel
var _wrist_last := ""
var _skin_last := ["", ""]
var _skin_flick := 0.0
var _skin_a := false
var _eye_stand := 1.62


func _ready() -> void:
	ZSEngine.setup()
	for a in OS.get_cmdline_user_args():
		var kv := a.lstrip("-").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_load_best()
	progress.load_all()
	_load_settings()
	if VRAvatar.skin_index(str(settings.skin)) == 0 and str(settings.skin) != VRAvatar.SKINS[0].id:
		settings.skin = VRAvatar.SKINS[0].id            # an unknown saved outfit: start from the first
	if args.has("skin"):
		settings.skin = str(args.skin)
	if args.has("body"):
		settings.body = str(args.body)
	font = load("res://assets/fonts/font-barlow-condensed-900.woff2")
	_setup_xr()
	cam.cull_mask = 0xFFFFF & ~(1 << (VRAvatar.HEAD_LAYER - 1))      # your own head is not drawn in your own view
	_build_screen()
	cartridge = Cartridges.create(Cartridges.default_id(), self)
	room = ArcadeRoom.new()
	var banner: Texture2D = load("res://assets/art/game-banner.webp")
	room.build(self, cartridge.screen_texture(), banner, font, progress)
	machines = room.machines
	emu = EmuLauncher.new()
	add_child(emu)
	emu.build(self)
	for m in machines:
		if m.emu:
			emu.set_audio_position(m)               # the game's sound comes out of the JW EDS machine
			m.attract_tex = emu.screen_texture()
			m.set_live(null)
	cab = machines[room.player_index]
	cab.set_live(cartridge.screen_texture())
	room.set_active(room.player_index)
	room.prize_wall.set_unlocked(progress.unlocked(), true)
	room.pinball.set_enabled(true)      # the pinball machine is always playable
	room.pinball.table.best = progress.pinball_best
	room.pinball.table.bonus_balls = progress.codes.has("pinball")
	room.pinball2.set_enabled(true)
	room.board_game.event.connect(func(n):
		var m := {"roll": "throw", "hop": "click", "grenade": "clear", "zombie": "hurt", "heart": "pickup", "boss": "doom", "win": "chime"}
		if m.has(n):
			audio.sfx(m[n], 0.6, 0.02, room.board_game.global_position + Vector3(0, 0.3, 0)))
	room.pinball2.table.best = progress.pinball_best
	room.pinball2.table.bonus_balls = progress.codes.has("pinball")
	room.pinball2.sound.connect(_on_pinball_sound)
	room.vending.code_entered.connect(_on_code)
	room.vending.key_pressed.connect(func(k, ok): audio.sfx("key" if ok else "error", 0.7, 0.0, room.vending.global_position + Vector3(0, 1.3, 0.5)); _haptic(-1, 0.2, 0.03))
	room.pinball.sound.connect(_on_pinball_sound)
	room.door.scare.connect(func(kind): audio.sfx("doom" if kind != "stare" else "warn", 0.45, 0.0, Vector3(0, 1.4, -0.6)))
	room.prize_wall.grabbed.connect(func(_i, open): audio.sfx("pickup" if open else "switch", 0.7); _haptic(1, 0.35, 0.05))
	room.prize_wall.dropped.connect(func(_i): audio.sfx("toggle", 0.6))
	_build_hands()
	room.env.glow_enabled = str(settings.glow) == "on"
	_show_fps(str(settings.fps) == "on")
	_apply_tier()
	room.skins.set_equipped(str(settings.skin))
	room.skins.chosen.connect(func(id):
		_on_setting("skin", id)
		menu.set_value("skin", id))
	room.skins.sound.connect(func(k): audio.ui(k))
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
		get_tree().create_timer(2.0).timeout.connect(func():
			_open_menu()
			if str(args.menu) != "1":
				menu.show_page(str(args.menu)))
	if args.has("unlocked"):
		_set_locked(false)
	audio = ZSAudio.new()
	add_child(audio)
	audio.setup(cab)
	audio.set_volumes(float(settings.music), float(settings.effects))
	cab.set_topper_color(VRMenu.TOPPERS[settings.topper])
	audio.play_music("ambient", 0.01)
	room.jukebox.command.connect(_on_jukebox)
	audio.track_changed.connect(room.jukebox.show_track)
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

	social = ShackSession.new()
	add_child(social)
	social.setup(self)
	social.remote.launcher = emu                      # the host's games are offered to the room; guests see them in the same menu
	emu.set_remote(social.remote)
	var lobby_panel := LobbyPanel.new()
	menu._pages.friends.add_child(lobby_panel)
	lobby_panel.setup(social)



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
		iface.render_target_size_multiplier = _tier_sharp()          # draw each eye sharper than the headset's default, so far-away detail stays clean
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
	viewport.size = Vector2i(1029, int(ZSScreen.FULL_H * 3.0))         # the whole 343 x 522 phone screen, drawn three times sharper than on the phone
	viewport.msaa_2d = Viewport.MSAA_DISABLED       # already drawn three times sharper than it is shown, so edge smoothing here is wasted work
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
		"stick": Vector2.ZERO, "a": false, "b": false, "menu": false, "aim_origin": Vector3.ZERO, "aim_dir": Vector3.FORWARD, "active": true, "bare": false, "thumb": -1.0, "angles": {}, "idx_touch": false, "palm_up": 0.0}


func _build_hands() -> void:
	avatar = VRAvatar.new()
	add_child(avatar)
	avatar.build(true)
	avatar.apply_skin(str(settings.skin))
	avatar.set_body_mode(str(settings.body))
	wrist = WristPanel.new()
	wrist.build(font)
	add_child(wrist)
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
		vis.build(side, avatar.hand_look())
		origin.add_child(vis)
		hands.append({"ctrl": grip, "aim": aim, "side": side, "vis": vis})
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
		"skin":
			_apply_skin(str(value))
		"body":
			avatar.set_body_mode(str(value))
		"sharp":
			_apply_sharpness()
		"glow":
			room.env.glow_enabled = value == "on"
		"auto":
			q_tier = 1
			_apply_tier()
		"fps":
			_show_fps(str(value) == "on")
	if key != "music" and key != "effects" and key != "lift" and key != "reach" and key != "haptics":
		audio.ui("click")
	_save_settings()


func _apply_skin(id: String) -> void:
	if social != null and social.online:
		social.send({"type": "appearance", "skin": id})
	settings.skin = id
	avatar.apply_skin(id)
	avatar.set_body_mode(str(settings.body))
	for h in hands:
		h.vis.rebuild(avatar.hand_look())
	room.skins.set_equipped(id)


func _apply_sharpness() -> void:
	_apply_tier()


## ---- keeping the picture smooth ---------------------------------------------------------------------------------------------
## The headset must draw a new picture every 1/72 of a second. If it falls behind, the picture judders. So the game watches how long
## frames take and, when they run long, steps the picture quality down a notch (a little less sharp, then lighter edge smoothing);
## when there is plenty of room it steps back up, never past the player's own Sharpness setting.
const TIERS := [
	{"sharp": 1.6, "msaa": 4}, {"sharp": 1.3, "msaa": 4}, {"sharp": 1.15, "msaa": 4}, {"sharp": 1.0, "msaa": 4},
	{"sharp": 0.9, "msaa": 2}, {"sharp": 0.8, "msaa": 2}, {"sharp": 0.7, "msaa": 0}]
var q_tier := 1
var fps_now := 0.0
var _perf_sum := 0.0
var _perf_n := 0
var _perf_t := 0.0
var _fast_s := 0.0
var _slow_s := 0.0
var _perf_age := 0.0
var _rate_set := false
var fps_label: Label3D


func _tier_sharp() -> float:
	var want := clampf(float(settings.sharp), 0.7, 1.6)
	if str(settings.auto) != "on":
		return want
	return minf(want, float(TIERS[clampi(q_tier, 0, TIERS.size() - 1)].sharp))


func _apply_tier() -> void:
	if not xr_on:
		return
	var iface := XRServer.find_interface("OpenXR")
	if iface != null:
		iface.render_target_size_multiplier = _tier_sharp()
	var t: Dictionary = TIERS[clampi(q_tier, 0, TIERS.size() - 1)]
	var msaa := int(t.msaa) if str(settings.auto) == "on" else 4
	get_viewport().msaa_3d = Viewport.MSAA_4X if msaa >= 4 else (Viewport.MSAA_2X if msaa == 2 else Viewport.MSAA_DISABLED)


func _show_fps(on: bool) -> void:
	if on and fps_label == null and cam != null:
		fps_label = VRBuild.label(cam, "", 0.03, Vector3(-0.17, -0.19, -0.6), Color(0.6, 1.0, 0.7), Vector3.ZERO, 6, font, true)
	if fps_label != null:
		fps_label.visible = on


func _perf_tick(delta: float) -> void:
	_perf_age += delta
	_perf_sum += delta
	_perf_n += 1
	_perf_t += delta
	if _perf_age > 2.0 and not _rate_set and xr_on:
		_rate_set = true
		var iface := XRServer.find_interface("OpenXR")
		if iface != null and iface.has_method("get_available_display_refresh_rates"):
			var rates = iface.get_available_display_refresh_rates()
			if rates is Array and rates.has(72.0):
				iface.display_refresh_rate = 72.0        # a steady 72 beats an unsteady 90 or 120
	if _perf_t < 1.0:
		return
	var avg := _perf_sum / float(_perf_n)
	fps_now = 1.0 / maxf(avg, 0.0001)
	_perf_sum = 0.0
	_perf_n = 0
	_perf_t = 0.0
	if fps_label != null and fps_label.visible:
		fps_label.text = "%d fps  q%d  x%.2f" % [int(round(fps_now)), q_tier, _tier_sharp()]
	if not xr_on or str(settings.auto) != "on" or _perf_age < 6.0:
		return
	if avg > 0.0158 and q_tier < TIERS.size() - 1:       # slower than about 63 frames a second
		_slow_s += 1.0
		_fast_s = 0.0
		if _slow_s >= 2.0:
			_slow_s = 0.0
			q_tier += 1
			_apply_tier()
	elif avg < 0.0128:                                    # comfortably faster than 72
		_slow_s = 0.0
		_fast_s += 1.0
		var ceiling := 0
		for i in range(TIERS.size()):
			if float(TIERS[i].sharp) <= float(settings.sharp) + 0.001:
				ceiling = i
				break
		if _fast_s >= 12.0 and q_tier > ceiling:
			_fast_s = 0.0
			q_tier -= 1
			_apply_tier()
	else:
		_slow_s = 0.0
		_fast_s = 0.0


## The room and the machines are a fixed size; the player is what moves: "lift" raises or lowers the player, "reach" moves them
## nearer to or further from the machine they are playing.
var _reach_dirty := false
var walk_out_t := 0.0


func _apply_height() -> void:
	if xr_on:
		origin.position.y = float(settings.lift)
	if locked and calibrated:
		if menu != null and menu.open:
			_reach_dirty = true         # applied when the board closes, so it never moves under you while you use it
		else:
			_place_player(cab.stand_world(), cab.look_world(), true)


func _on_code(action: String) -> void:
	if action == "pinball":
		if not progress.codes.has("pinball"):
			progress.codes.append("pinball")
			progress.save()
		room.pinball.table.bonus_balls = true       # the secret code gives the pinball machine five balls a game
		room.pinball.table.balls_left = 5
		room.pinball2.table.bonus_balls = true
		audio.sfx("clear", 0.9)
		audio.sfx("chime", 0.8, 0.0, room.pinball.global_position + Vector3(0, 1.0, 0))


func _on_pinball_sound(n: String, pos: Vector3) -> void:
	var map := {"flip": ["click", 0.8], "flipper_hit": ["hit", 0.5], "launch": ["throw", 0.8], "bump": ["target", 0.8], "sling": ["hit", 0.6], "target": ["pickup", 0.7], "clear": ["clear", 0.9], "drain": ["hurt", 0.7], "over": ["doom", 0.8], "wall": ["ricochet", 0.25],
		"ramp": ["pickup", 0.9], "portal_in": ["switch", 0.9], "portal_out": ["throw", 0.7], "multiball": ["clear", 1.0], "drain_lite": ["hurt", 0.4], "save": ["switch", 0.7]}
	if map.has(n):
		audio.sfx(map[n][0], map[n][1], 0.04, pos)
	if n == "flip":
		_haptic(-1, 0.25, 0.03)
	elif n == "bump":
		_haptic(-1, 0.4, 0.05)
	elif n == "sling" or n == "flipper_hit":
		_haptic(-1, 0.3, 0.04)
	elif n == "launch" or n == "ramp" or n == "portal_in" or n == "portal_out":
		_haptic(-1, 0.5, 0.07)
	elif n == "multiball":
		_haptic(-1, 1.0, 0.4)
	elif n == "over":
		progress.pinball_best = maxi(progress.pinball_best, maxi(room.pinball.table.best, room.pinball2.table.best))
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
		if m.emu:
			continue
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
	if _reach_dirty and locked:
		_reach_dirty = false
		_place_player(cab.stand_world(), cab.look_world(), true)
	# closing the options (RESUME, or any way out) carries on a game that was paused, as long as you are at its machine
	if (menu_resume_state == "play" or game != null) and state == "paused" and locked:
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
	_perf_tick(delta)
	if xr_on and int(clock * 2.0) != int((clock - delta) * 2.0):
		_fix_poses()
	room.animate(clock)
	room.prize_wall.animate(delta)
	selector.relabel("dice", "STEADY" if room.board_game.hint() != "" else "")
	selector.relabel("dash", "DASH +2" if room.board_game.hint() != "" else "")
	_calibrate(delta)
	var hs := _read_hands(delta)
	_pose_hands(hs)
	_update_avatar(hs, delta)
	_menu_input(hs)
	_world_inputs(hs)
	if social != null:
		social.tick(hs, delta)
	var pg: Array = []
	for i in range(2):
		pg.append({"grab": hs[i].gripping and grab_hand != i and grab_hand2 != i and not menu.open, "xf": hs[i].vis_xf, "point": hs[i].palm})
	room.prize_wall.update(pg)
	_locomotion(hs, delta)
	if locked and not menu.open:
		_stick(hs, delta)
		_stick2(hs, delta)
		_buttons(hs)
	else:
		axis = 0.0
		fire_now = false
		grab_hand = -1
		grab_hand2 = -1
	emu.hold = not (cab.emu and locked and not menu.open)       # the game only runs while somebody is playing at its machine
	emu.session.set_volume(0.0 if emu.hold else float(settings.effects))
	emu.tick(delta)
	if cab.emu:
		pass
	elif state == "play" and game != null:
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
	if xr_on and not seated:
		_eye_stand = clampf(cam.position.y, 1.2, 2.1)
	avatar._inited = false
	if not xr_on:
		return
	_place_player(cab.stand_world(), cab.look_world(), true)


## The body follows the head and the two hands.
func _update_avatar(hs: Array, delta: float) -> void:
	var wr: Array = []
	var act: Array = []
	for i in range(2):
		wr.append(hs[i].wrist if hs[i].bare and hs[i].has("wrist") else (hs[i].vis_xf as Transform3D) * Vector3(0, -0.004, 0.075))
		act.append(bool(hs[i].active) or demo)
	var head := cam.global_transform
	# body size: set from your eye height while you stand upright, so a taller player gets a taller body
	if not seated and (-head.basis.z).y > -0.4 and head.origin.y > 1.2:
		pass # Body size is calibrated explicitly; looking down or height lift must not resize the body.
	avatar.scale_k = clampf(_eye_stand / 1.62, 0.8, 1.3)
	avatar.tracked_fingers = [hs[0].angles, hs[1].angles]
	avatar.hand_poses = [hs[0].vis_xf, hs[1].vis_xf]
	avatar.finger_curls = [float(hs[0].trig_val), float(hs[0].grip_val), clampf(float(hs[0].thumb), 0, 1), float(hs[1].trig_val), float(hs[1].grip_val), clampf(float(hs[1].thumb), 0, 1)]
	avatar.update(head, wr, act, delta, seated)
	if avatar.human != null:
		for i in range(2):
			hands[i].vis.visible = false
			if hs[i].active and not hs[i].bare:
				hs[i].tip = avatar.human.fingertip(i)
				hs[i].palm = avatar.human.palm(i)
	var gaunt: bool = avatar.show_body == "hands"
	for h in hands:
		h.vis.set_gauntlet(gaunt)
	# the avatar locker: its screen only draws while you are near; fingers press its buttons, the left stick flicks through outfits, A wears one
	var sm: SkinMachine = room.skins
	var snear := _head_floor().distance_to(sm.global_position) < 1.9 and not menu.open
	sm.animate(delta, snear or _head_floor().distance_to(sm.global_position) < 5.0 and not xr_on)
	if snear:
		for i in range(2):
			var kb: String = sm.button_at(hs[i].tip)
			if kb != "" and kb != _skin_last[i]:
				sm.press(kb)
				_haptic(i, 0.3, 0.04)
			_skin_last[i] = kb
		_skin_flick = maxf(0.0, _skin_flick - delta)
		var sx: float = hs[0].stick.x
		if absf(sx) > 0.7 and _skin_flick <= 0.0:
			sm.press("next" if sx > 0.0 else "prev")
			_skin_flick = 0.35
		if (hs[1].a or hs[0].a) and not _skin_a:
			sm.press("select")
		_skin_a = hs[1].a or hs[0].a
	# the left palm turned up shows the wrist panel (bare hands only)
	var l: Dictionary = hs[0]
	wrist.update(l.palm, float(l.palm_up) if l.bare else 0.0, head.origin, bool(l.active) and l.bare, delta)
	if wrist.shown:
		var tip: Vector3 = hs[1].tip
		var b: String = wrist.button_at(tip)
		if b != "" and b != _wrist_last:
			wrist.flash(b)
			audio.ui("click")
			match b:
				"menu":
					if menu.open:
						_close_menu()
					else:
						_open_menu()
				"turn_l":
					_turn(deg_to_rad(float(settings.snap)))
				"turn_r":
					_turn(-deg_to_rad(float(settings.snap)))
				"recentre":
					recenter()
		_wrist_last = b
	else:
		_wrist_last = ""


## Both hands as raw controller data (from the controllers in VR, simulated on the desktop).
func _read_hands(delta: float) -> Array:
	if xr_on:
		var out: Array = []
		var hm := str(settings.handmode)          # auto: controllers when held, bare hands when put down; or force one of them
		for h in hands:
			var c: XRController3D = h.ctrl
			var a: XRController3D = h.aim
			var have_ctrl: bool = c.get_is_active() and c.get_has_tracking_data()
			if hm == "controllers" and not have_ctrl:
				var off := _blank_hand()
				off.active = false
				off.xf = c.global_transform
				out.append(off)
				continue
			if not have_ctrl or hm == "hands":
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
			_gripping[h.side] = c.is_button_pressed("grip_click") or grip_val > (0.38 if _gripping[h.side] else 0.65)
			d.gripping = _gripping[h.side]
			d.trigger = c.is_button_pressed("trigger_click") or trig_val > 0.6
			d.grip_val = grip_val
			d.trig_val = trig_val
			d.stick = c.get_vector2("primary")
			d.a = c.is_button_pressed("ax_button")
			d.b = c.is_button_pressed("by_button")
			d.menu = c.is_button_pressed("menu_button")
			# the controller senses where your fingers rest, so the hand can copy them: thumb on a button or stick, index on the trigger
			var thumb_on: bool = c.is_button_pressed("ax_touch") or c.is_button_pressed("by_touch") or c.is_button_pressed("primary_touch") or d.a or d.b
			d.idx_touch = c.is_button_pressed("trigger_touch") or trig_val > 0.05
			d.thumb = (0.9 if grip_val > 0.5 else 0.6) if thumb_on else (0.0 if grip_val > 0.5 else 0.12)      # lifted thumb with a closed fist = thumbs up
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
	if f.length_squared() < 0.5 or t.length_squared() < 0.5:
		d.active = false
		return d
	d.xf = Transform3D(Basis(f.cross(t), t, -f).orthonormalized(), palm)
	var curl := func(tip: int) -> float: return 1.0 - clampf((palm.distance_to(j.call(tip)) - 0.055) / 0.115, 0.0, 1.0)
	var idx: float = curl.call(10)
	var grip := (float(curl.call(15)) + float(curl.call(20)) + float(curl.call(25))) / 3.0
	d.trig_val = idx
	d.grip_val = grip
	d.gripping = grip > 0.6
	_pinching[side] = (j.call(5) as Vector3).distance_to(j.call(10)) < (0.036 if _pinching[side] else 0.023)
	d.trigger = _pinching[side]
	d.aim_origin = j.call(10)
	d.aim_dir = (j.call(10) - j.call(7)).normalized()
	d.thumb = 1.0 - clampf(((j.call(5) as Vector3).distance_to(j.call(7)) - 0.03) / 0.06, 0.0, 1.0)
	d.bare = true
	d.wrist = wrist
	d.tracked_tip = j.call(10)
	d.tracked_palm = palm
	var nrm: Vector3 = ((j.call(7) as Vector3) - (j.call(22) as Vector3)).cross(f) * (1.0 if side == 0 else -1.0)
	d.palm_up = clampf(nrm.normalized().y, 0.0, 1.0) if nrm.length() > 0.0001 else 0.0
	d.idx_touch = false
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
	var d1 := _head_floor().distance_to(room.pinball.stand_world())
	var d2 := _head_floor().distance_to(room.pinball2.stand_world())
	var near: bool = d1 < 1.5 and d1 <= d2 and not menu.open and not locked and (social == null or social.owns("pinball"))
	var near2: bool = d2 < 1.5 and d2 < d1 and not menu.open and not locked and (social == null or social.owns("pinball2"))
	# only the machine you are standing at listens to you; hands that hold its sides by the flipper buttons stay on them
	pin_latch = [null, null]
	var flips := [false, false, false, false]
	for k in range(2):
		var pb: Pinball = room.pinball if k == 0 else room.pinball2
		var here: bool = near if k == 0 else near2
		if not here or locked:
			pb.release_hands()
			continue
		var res: Dictionary = pb.latch(hs)
		for i in range(2):
			if res.spot[i] != null:
				pin_latch[i] = res.spot[i]
		flips[k * 2] = res.left or (hs[0].active and not hs[0].bare and hs[0].trigger)         # standing at the table, the controller triggers are the flippers
		flips[k * 2 + 1] = res.right or (hs[1].active and not hs[1].bare and hs[1].trigger)
	room.pinball.interact(tips, palms, flips[0], flips[1], (hs[0].a or hs[1].a), near, hs)
	room.pinball2.interact(tips, palms, flips[2], flips[3], (hs[0].a or hs[1].a), near2, hs)


func _solid(p: Vector3, r: float) -> Vector3:
	var out := p
	for m in machines:
		out = m.constrain(out, r)
	return room.pinball2.constrain(room.pinball.constrain(out, r), r)


## Works out the hand the player sees (solid against the machine) and the points that touch the controls.
func _pose_hands(hs: Array) -> void:
	for i in range(hs.size()):
		var h: Dictionary = hs[i]
		var vis: VRHand = hands[i].vis
		var xf: Transform3D = h.xf
		if not h.active:
			_pinching[i] = false
			_gripping[i] = false
			if grab_hand == i:
				grab_hand = -1
			if grab_hand2 == i:
				grab_hand2 = -1
			pin_latch[i] = null
		if not h.bare and (int(settings.handroll) != 0 or int(settings.handtilt) != 0):
			xf.basis = xf.basis * Basis.from_euler(Vector3(deg_to_rad(float(settings.handtilt)), 0.0, deg_to_rad(float(settings.handroll)) * (1.0 if i == 0 else -1.0)))
		var sgn := vis.s
		h.grip = xf * Vector3(sgn * HAND_ANCHOR, 0.0, -0.012)      # where the stick ball is held
		# keep palm and finger out of the cabinet
		var pos := xf.origin
		var palm := _solid(pos, 0.04)
		var shift := (palm - pos).limit_length(0.04)
		var tipw: Vector3 = xf * Vector3(0, 0, -0.15) + shift
		var tip2 := _solid(tipw, 0.011)
		var final_xf := xf
		final_xf.origin = pos + shift + (tip2 - tipw).limit_length(0.02)
		var holding := grab_hand == i or grab_hand2 == i
		var pin_hold: Variant = pin_latch[i]
		if grab_hand == i:
			final_xf.origin = cab.ball_world_position() - final_xf.basis * Vector3(sgn * HAND_ANCHOR, 0.0, -0.012)
		elif grab_hand2 == i:
			final_xf.origin = cab.ball2_world_position() - final_xf.basis * Vector3(sgn * HAND_ANCHOR, 0.0, -0.012)
		elif pin_hold != null:
			final_xf.origin = (pin_hold as Vector3) - final_xf.basis * Vector3(0.0, 0.0, -0.15)
		var idx_c: float = 1.0 if holding else maxf(h.trig_val, 0.3 if (h.idx_touch and not h.bare) else 0.0)
		var grip_c: float = 1.0 if holding else h.grip_val
		var thumb_c: float = h.thumb if h.thumb >= 0.0 else maxf(grip_c * 0.8, idx_c * 0.3)
		if holding:
			thumb_c = 0.9
		if h.bare and not h.angles.is_empty() and not holding:
			vis.set_tracked(h.angles)
		else:
			vis.clear_tracked()
		vis.set_pose(idx_c, grip_c, 0.9 if holding else thumb_c)
		vis.global_transform = final_xf
		vis.visible = (xr_on and h.active) or demo
		h.palm = final_xf.origin
		h.vis_xf = final_xf
		h.tip = final_xf * Vector3(0, 0, -0.15 + 0.05 * idx_c)
		if h.bare and h.has("tracked_tip"):
			# sensor contact points stay exact: a cabinet's visual constraint cannot move a real poke
			h.tip = h.tracked_tip
			h.palm = h.tracked_palm
		if not h.active:
			h.tip = Vector3(100, 100, 100)
			h.palm = h.tip


# ---- moving about the room (green light) --------------------------------------------------------------
func _set_locked(on: bool) -> void:
	if not on and locked and social != null and social.online and not social.granted and social.owns("m%d" % machines.find(cab)):
		social.send({"type": "release"})
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
		var poked := false
		var mn: Vector3 = menu.global_transform.basis.z.normalized()
		for i in range(2):
			# bare hands can simply touch the board with a fingertip
			if hs[i].bare and hs[i].active:
				var dz: float = ((hs[i].tip as Vector3) - menu.global_position).dot(mn)
				if dz > -0.08 and dz < 0.1 and menu.point((hs[i].tip as Vector3) + mn * 0.15, -mn, dz < 0.014, false):
					poked = true
					break
		if not poked:
			var ph := 0 if settings.pointer == "left" else 1
			if hs[ph].active:
				menu.point(hs[ph].aim_origin, hs[ph].aim_dir, hs[ph].trigger)
			else:
				menu._release()
				menu.beam.visible = false
				menu.dot.visible = false


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
		# walking away is the quick way out: push the left stick for a moment and you are free again
		var mvl: Vector2 = hs[0].stick
		if xr_on and mvl.length() > 0.65 and str(settings.assist) != "on":
			walk_out_t += delta
		else:
			walk_out_t = 0.0
		if walk_out_t > 0.4:
			walk_out_t = 0.0
			audio.ui("toggle")
			_set_locked(false)
		for i in range(2):
			trig_prev[i] = hs[i].trigger
		return
	if not xr_on and not demo:
		return
	if not hs[ph].active:
		selector.aim(Vector3.ZERO, Vector3.UP)
		return
	var hover := selector.aim(hs[ph].aim_origin, hs[ph].aim_dir)
	for i in range(2):
		var down: bool = hs[i].trigger
		if down and not trig_prev[i] and i == ph and not tele_busy:
			# free movement only: pointing never moves you anywhere. It only starts the thing you are standing at.
			if hover >= 0 and _within_reach(str(selector.targets[hover].id)):
				_choose(str(selector.targets[hover].id))
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
	if social != null and social.online and str(spot[0]) in ["pinball", "pinball2"] and not social.granted:
		social.claim(str(spot[0]))
		return
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


## Sit on a stool: you take that seat's board game piece (or your old seat back, if it is free), and the view moves in over the table:
## shuffled forward off the stool and lowered to seated eye height.
func _sit(sd_in: Array) -> void:
	if social != null and social.online and not social.granted:
		social.sit(int(str(sd_in[0]).substr(3)))
		return
	var bg: BoardGame = room.board_game
	var want := int(str(sd_in[0]).substr(3))
	var seat := want if social != null and social.online else bg.seat_for("local", want)
	var sd: Array = room.seats[seat] if seat < room.seats.size() else sd_in
	tele_busy = true
	audio.ui("switch")
	fade_quad.visible = true
	var m := fade_quad.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.tween_method(func(v: float): m.albedo_color.a = v, 0.0, 1.0, 0.12)
	tw.tween_callback(func():
		var stool: Vector3 = sd[1]
		var to_table: Vector3 = Vector3(sd[2].x, 0.0, sd[2].z) - Vector3(stool.x, 0.0, stool.z)
		_place_player(stool + to_table.normalized() * 0.28, sd[2], false, true)     # leaning in over the table
		if social == null or not social.online:
			bg.take_seat(seat, "local")
		seated = true
		origin.position.y = float(settings.lift) - float(sd[3]) if sd.size() > 3 else float(settings.lift) - 0.55)
	tw.tween_method(func(v: float): m.albedo_color.a = v, 1.0, 0.0, 0.2)
	tw.tween_callback(func():
		fade_quad.visible = false
		tele_busy = false)


func _stand_up() -> void:
	if seated:
		seated = false
		if social != null and social.online:
			social.send({"type": "stand"})
		else:
			room.board_game.leave_seat("local")
		origin.position.y = float(settings.lift)


func _floor_ok(_p: Vector3) -> bool:
	return false                     # no point-and-move landing ring: you walk


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
	if id in ["dice", "dash"]:
		if social != null and social.online:
			social.send({"type": "roll", "dash": id == "dash"})
		else:
			room.board_game.roll_human(id == "dash")
		return
	if id.begins_with("sit"):
		for sd in room.seats:
			if sd[0] == id:
				_sit(sd)
				return
	if id in ["pinball", "pinball2"] and social != null and social.online and not social.granted:
		social.claim(id)


## You can only start something by pointing at it when you have walked up to it yourself.
func _within_reach(id: String) -> bool:
	var hp := _head_floor()
	if id.begins_with("m") and id.substr(1).is_valid_int():
		return hp.distance_to((machines[int(id.substr(1))] as Cabinet).stand_world()) < 1.5
	if id == "pinball":
		return hp.distance_to(room.pinball.stand_world()) < 2.2
	if id == "pinball2":
		return hp.distance_to(room.pinball2.stand_world()) < 2.2
	if id.begins_with("sit"):
		for sd in room.seats:
			if sd[0] == id:
				return hp.distance_to(Vector3(sd[1].x, 0.0, sd[1].z)) < 1.8
		return false
	return true


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
	out.append({"id": "dice", "label": "", "xf": Transform3D(Basis.IDENTITY, ArcadeRoom.ARC_CENTRE), "box": AABB(Vector3(-0.42, 1.03, -0.42), Vector3(0.42, 0.1, 0.84)), "colour": Color(0.4, 1.0, 0.3), "always": true})
	out.append({"id": "dash", "label": "", "xf": Transform3D(Basis.IDENTITY, ArcadeRoom.ARC_CENTRE), "box": AABB(Vector3(0, 1.03, -0.42), Vector3(0.42, 0.1, 0.84)), "colour": Color(1, 0.65, 0.2), "always": true})
	out.append({"id": "pinball2", "label": "PLAY", "xf": room.pinball2.global_transform, "box": AABB(Vector3(-0.38, 0.0, -0.8), Vector3(0.76, 2.0, 1.75)), "colour": Color(1.0, 0.85, 0.2), "always": true})
	out.append({"id": "pinball", "label": "PLAY", "xf": room.pinball.global_transform, "box": AABB(Vector3(-0.38, 0.0, -0.8), Vector3(0.76, 2.0, 1.75)), "colour": Color(1.0, 0.85, 0.2), "always": true})
	for sd in room.seats:
		out.append({"id": sd[0], "label": "SIT", "xf": Transform3D(Basis.IDENTITY, sd[1]), "box": AABB(Vector3(-0.25, 0.0, -0.25), Vector3(0.5, 0.85, 0.5)), "colour": Color(1.0, 0.45, 0.85), "always": true})
	out.append({"id": "skins", "label": "AVATARS", "xf": room.skins.global_transform, "box": AABB(Vector3(-0.42, 0.0, -0.3), Vector3(0.84, 2.0, 1.3)), "colour": Color(0.3, 0.9, 1.0), "always": true})
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
	leave_prompt.visible = away and not demo
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


func _place_player(pos: Vector3, look: Vector3, machine := false, preserve_seat := false) -> void:
	avatar._inited = false
	grab_hand = -1
	grab_hand2 = -1
	pin_latch = [null, null]
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
	if seated and not preserve_seat:
		if social != null and social.online:
			social.send({"type": "stand"})
		else:
			room.board_game.leave_seat("local")
	seated = false


## A hand that has taken hold of a stick keeps it until the fingers really open (or the hand is pulled well away).
func _released(h: Dictionary, dist: float) -> bool:
	if not h.active or dist > 0.24:
		return true
	return not (h.gripping or h.trigger or float(h.grip_val) > 0.3 or float(h.trig_val) > 0.3)


func _stick(hs: Array, delta: float) -> void:
	var ball := cab.ball_world_position()
	if grab_hand == -1:
		for i in range(2):
			var h: Dictionary = hs[i]
			if h.gripping and i != grab_hand2 and h.active and h.grip.distance_to(ball) < GRAB_RADIUS * cab.scale.x:
				grab_hand = i
				_haptic(i, 0.5, 0.06)
				audio.sfx("switch", 0.6)
				break
	if grab_hand >= 0:
		var h: Dictionary = hs[grab_hand]
		if _released(h, h.grip.distance_to(ball)):
			grab_hand = -1
			audio.sfx("toggle", 0.5)
		else:
			var local := cab.to_panel(h.grip)
			var v := local - (Cabinet.STICK_LOCAL + Vector3(0, 0.03, 0))
			var up := maxf(v.y, 0.06)
			roll = clampf(atan2(v.x, up), -Cabinet.MAX_TILT, Cabinet.MAX_TILT)
			pitch = clampf(atan2(v.z, up), -Cabinet.MAX_TILT * 0.7, Cabinet.MAX_TILT * 0.7) if cab.emu else 0.0       # only the emulator stick goes every way
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


## The right-hand stick of a two-stick machine: pushed away from you it fires, pulled toward you it throws a grenade.
func _stick2(hs: Array, delta: float) -> void:
	if not cab.dual:
		return
	var ball2 := cab.ball2_world_position()
	if grab_hand2 == -1:
		for i in range(2):
			var h: Dictionary = hs[i]
			if (h.gripping or h.trigger) and i != grab_hand and h.grip.distance_to(ball2) < GRAB_RADIUS * cab.scale.x:
				grab_hand2 = i
				_haptic(i, 0.5, 0.06)
				audio.sfx("switch", 0.6)
				break
	if grab_hand2 >= 0:
		var h2: Dictionary = hs[grab_hand2]
		if _released(h2, h2.grip.distance_to(ball2)):
			grab_hand2 = -1
			audio.sfx("toggle", 0.5)
		else:
			var local := cab.to_panel(h2.grip)
			var v := local - (Cabinet.STICK2_LOCAL + Vector3(0, 0.03, 0))
			var up := maxf(v.y, 0.06)
			roll2 = 0.0           # the fire stick only goes forward and back
			pitch2 = clampf(atan2(v.z, up), -Cabinet.MAX_TILT * 0.7, Cabinet.MAX_TILT * 0.7)
	if grab_hand2 == -1:
		var k := exp(-delta * 22.0)
		roll2 *= k
		pitch2 *= k
	cab.set_stick2(roll2, pitch2)


const WEAPON_BUTTONS := {"w_smg": "smg", "w_shotgun": "shotgun", "w_dmr": "dmr", "w_burst": "burst"}
var weapon_prev := {}


func _buttons(hs: Array) -> void:
	var down := {"fire": false, "grenade": false, "menu": false, "pause": false}
	for bk in cab.button_defs:
		if not down.has(bk):
			down[bk] = false
	for i in range(hs.size()):
		var h: Dictionary = hs[i]
		for use_tip in [true, false]:
			var p: Vector3 = h.tip if use_tip else h.palm
			var hit := cab.button_at(cab.to_panel(p), 0.06 if use_tip else 0.08)
			if hit != "" and grab_hand != i and grab_hand2 != i and (hit != "menu" or use_tip):
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
	# the joystick does everything: left and right to move, push it away from you to fire, pull it toward you for a grenade
	var stick_fp := (pitch2 if cab.dual else pitch) / (Cabinet.MAX_TILT * 0.7)
	var stick_held: bool = (grab_hand2 >= 0) if cab.dual else (grab_hand >= 0)
	if locked and cab.dual and stick_held and not cab.emu:
		if stick_fp < -0.62:
			down["fire"] = true
		elif stick_fp > 0.62:
			down["grenade"] = true
	for k in down:
		cab.button_pressed_visual(k, down[k])
	if cab.emu:
		var st := Vector2(axis, pitch / (Cabinet.MAX_TILT * 0.7))
		if locked:
			emu.set_input(st, down)
		fire_now = false
		return
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
		elif state == "paused" and game != null and not menu.open:
			audio.ui("chime")                          # FIRE carries on a paused game
			state = "play"
			screen.mode = "play"
	# the four weapon buttons: each puts that stored weapon in your hand (what is loaded shows in the screen's bottom bar)
	for wk in WEAPON_BUTTONS:
		var wd: bool = down.get(wk, false)
		if wd and not weapon_prev.get(wk, false):
			if state == "play" and game != null and game.use_stored(WEAPON_BUTTONS[wk]):
				audio.sfx("pickup", 0.7, 0.0, cab.global_position + Vector3(0, 1.1, 0.3))
				_haptic(-1, 0.35, 0.06)
			else:
				audio.ui("click")
		weapon_prev[wk] = wd
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
	if social != null and social.online and not social.granted and not social.owns("m%d" % i):
		social.claim("m%d" % i)
		return
	# you are already standing at the machine: no fade, no move. It just switches on.
	_select_machine(i)
	_set_locked(true)
	var target_mat: StandardMaterial3D = (machines[i] as Cabinet).screen_mat
	target_mat.albedo_color = Color(0.1, 0.1, 0.1)
	audio.sfx("power", 0.6, 0.0, cab.global_position + Vector3(0, 1.3, 0.3))
	_haptic(-1, 0.35, 0.1)
	var tw2 := create_tween()
	tw2.tween_method(func(v: float): target_mat.albedo_color = Color(v, v, v), 0.1, 1.35, 0.8)


func _select_machine(i: int) -> void:
	var m: Cabinet = machines[i]
	if m == cab:
		return
	grab_hand = -1
	grab_hand2 = -1
	roll = 0.0
	pitch = 0.0
	roll2 = 0.0
	pitch2 = 0.0
	cab.set_stick(0.0, 0.0)
	cab.set_stick2(0.0, 0.0)
	cab.set_live(null)
	for k in cab.caps:
		cab.button_pressed_visual(k, false)
	cab = m
	cab.set_live(emu.screen_texture() if cab.emu else cartridge.screen_texture())
	cab.screen_mat.albedo_color = Color(1.35, 1.35, 1.35)
	cab.set_topper_color(VRMenu.TOPPERS[settings.topper])
	room.set_active(i)
	audio.move_to(cab)


# ---- a camera tour of the room, for a video ----------------------------------------------------------------
func _run_tour() -> void:
	room.board_game.auto_human = true
	room.board_game.take_seat(0, "local")
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
		[Vector3(0.8, 1.7, 0.2), Vector3(3.1, 1.2, 4.2), 5.0, 3.0, "m3"],
		[Vector3(0, 1.7, 3.0), Vector3(0, 1.9, -0.55), 4.0, 3.0],
		[Vector3(3.0, 1.6, 5.1), room.jukebox.global_position + Vector3(0, 1.2, 0), 3.0, 2.5],
		[Vector3(1.3, 1.6, 1.6), room.vending.global_position + Vector3(0, 1.2, 0), 3.0, 2.5],
		[Vector3(0.9, 1.5, 1.4), Vector3(0, 1.0, ArcadeRoom.FRONT_Z), 3.0, 2.5],
		[Vector3(0, 1.7, 0.9), Vector3(0, 1.3, -5.0), 3.0, 3.0],
		[Vector3(-2.4, 1.5, 3.7), Vector3(-3.1, 1.1, 3.15), 3.5, 2.5],
		[Vector3(2.4, 1.5, 3.7), Vector3(3.1, 1.1, 3.15), 3.0, 2.5],
		[machines[4].to_global(Vector3(-1.1, 1.1, -0.3)), machines[4].to_global(Vector3(0, 1.0, -0.3)), 3.0, 2.5],
		[Vector3(-1.2, 1.7, 1.0), ArcadeRoom.ARC_CENTRE + Vector3(0, 0.6, 0), 3.5, 2.5, "sit0"],
		[ArcadeRoom.ARC_CENTRE + Vector3(0, 1.38, -0.62), ArcadeRoom.ARC_CENTRE + Vector3(0, 0.95, 0.05), 3.0, 18.0, "dice"],
		[Vector3(1.7, 1.1, 3.9), ArcadeRoom.ARC_CENTRE + Vector3(0, 1.0, 0), 3.0, 3.0],
		[Vector3(0, 1.7, 3.6), Vector3(0, 1.5, 7.3), 3.5, 3.5],
		[room.pinball.stand_world() + Vector3(0, 1.65, 0), room.pinball.look_world(), 3.0, 3.5],
		[room.pinball2.stand_world() + Vector3(0, 1.65, 0), room.pinball2.look_world(), 3.5, 3.5],
		[Vector3(0, 1.7, 5.2), Vector3(0, 1.75, 7.3), 3.0, 4.0],
		[Vector3(-1.3, 1.7, 5.4), Vector3(-3.25, 1.85, ArcadeRoom.BACK_Z), 3.0, 4.0],
		[Vector3(-1.85, 1.6, 1.5), Vector3(-1.85, 1.3, -0.1), 3.5, 2.2, "skins", "next"],
		[Vector3(-1.85, 1.6, 1.5), Vector3(-1.85, 1.3, -0.1), 0.1, 2.2, "skins", "next"],
		[Vector3(-1.85, 1.6, 1.5), Vector3(-1.85, 1.3, -0.1), 0.1, 2.2, "skins", "next"],
		[Vector3(-1.85, 1.6, 1.5), Vector3(-1.85, 1.3, -0.1), 0.1, 2.2, "skins", "select"],
	]
	if args.has("tourpart"):                         # render only some of the stops, e.g. --tourpart=5-8 (long renders are made in pieces)
		var ab: PackedStringArray = str(args.tourpart).split("-")
		stops = stops.slice(int(ab[0]), int(ab[1]) + 1)
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
		if stop.size() > 5:
			room.skins.press(str(stop[5]))
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
		"table": [Vector3(0.0, 1.75, 4.15), Vector3(0, 1.0, 2.95)],
		"backleft": [Vector3(0.6, 1.7, 4.6), Vector3(-2.4, 1.1, 7.2)],
		"promo": [Vector3(0.2, 1.7, 4.9), Vector3(1.2, 1.35, 7.2)],
		"backwall": [Vector3(0, 1.7, 3.4), Vector3(0, 1.5, 7.3)],
		"jw_threeq": [machines[4].to_global(Vector3(-1.3, 1.7, 1.5)), machines[4].to_global(Vector3(0, 1.1, -0.2))],
		"jw_deck": [machines[4].to_global(Vector3(0.0, 1.55, 0.9)), machines[4].to_global(Vector3(0, 0.95, 0.1))],
		"zs_deck": [machines[0].to_global(Vector3(0.0, 1.55, 0.9)), machines[0].to_global(Vector3(0, 0.95, 0.1))],
		"zs_threeq": [machines[0].to_global(Vector3(1.3, 1.7, 1.5)), machines[0].to_global(Vector3(0, 1.1, -0.2))],
		"cab_sideL": [cab.to_global(Vector3(-1.25, 1.1, -0.3)), cab.to_global(Vector3(0, 1.0, -0.3))],
		"cab_back": [cab.to_global(Vector3(0.6, 1.4, -1.9)), cab.to_global(Vector3(0, 1.0, -0.4))],
		"cab_threeq": [cab.to_global(Vector3(1.3, 1.7, 1.5)), cab.to_global(Vector3(0, 1.1, -0.2))],
		"cab_front": [cab.to_global(Vector3(0.0, 1.6, 1.6)), cab.to_global(Vector3(0, 1.1, -0.2))],
		"cab_top": [cab.to_global(Vector3(0.9, 2.2, 0.7)), cab.to_global(Vector3(0, 1.2, -0.3))],
		"logo": [Vector3(2.0, 1.7, 1.6), Vector3(3.0, 2.0, -0.55)],
		"jukebox": [Vector3(3.0, 1.6, 5.1), Vector3(3.3, 1.2, 6.9)],
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
		"menu_far": [st + Vector3(0, 1.55, 0.0) + (st - cab.look_world()).normalized() * Vector3(1, 0, 1) * 0.55, cab.look_world()],
		"themed": [Vector3(-2.2, 1.6, 2.3), Vector3(-2.7, 1.1, 0.9)],
		"themed2": [Vector3(2.2, 1.6, 2.3), Vector3(2.7, 1.1, 0.9)],
	}
	for mi in range(machines.size()):
		var mc: Cabinet = machines[mi]
		views["m%d_R" % mi] = [mc.to_global(Vector3(1.1, 1.1, -0.3)), mc.to_global(Vector3(0, 1.0, -0.3))]
		views["m%d_L" % mi] = [mc.to_global(Vector3(-1.1, 1.1, -0.3)), mc.to_global(Vector3(0, 1.0, -0.3))]
	var jb: Vector3 = room.jukebox.global_position
	var vd: Vector3 = room.vending.global_position
	var tc: Vector3 = ArcadeRoom.ARC_CENTRE
	views["locker"] = [Vector3(-1.85, 1.6, 1.5), Vector3(-1.85, 1.2, -0.1)]
	views["locker_wide"] = [Vector3(1.2, 1.7, 4.4), Vector3(3.3, 1.0, 7.0)]
	views["body_down"] = [Vector3(0.3, 1.65, 1.2), Vector3(0.3, 0.0, 1.45)]
	views["body_fwd"] = [Vector3(0.3, 1.65, 1.2), Vector3(0.3, 1.2, 0.0)]
	views["juke_side"] = [jb + Vector3(1.3, 1.4, 1.2), jb + Vector3(0, 1.0, 0)]
	views["vend_top"] = [vd + Vector3(-0.9, 2.3, 1.3), vd + Vector3(0, 1.9, 0)]
	views["door_in"] = [Vector3(0.9, 1.5, 1.4), Vector3(0, 1.0, ArcadeRoom.FRONT_Z)]
	views["door_out"] = [Vector3(-0.8, 1.5, ArcadeRoom.FRONT_Z - 1.6), Vector3(0, 1.1, ArcadeRoom.FRONT_Z)]
	views["wall_graze"] = [Vector3(3.3, 1.5, 6.6), Vector3(-2.0, 1.2, 7.3)]
	views["floor_graze"] = [Vector3(0, 1.2, 0.4), Vector3(0, 0.0, 3.0)]
	views["seated"] = [tc + Vector3(0, 1.38, -0.62), tc + Vector3(0, 0.95, 0.05)]
	views["skirt_door"] = [Vector3(-2.6, 0.7, 1.0), Vector3(-2.6, 0.1, ArcadeRoom.FRONT_Z)]
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
