class_name EmuLauncher
extends Node
## The JW EDS machine's operating system: a text-mode, DOS-style menu on a 4:3 screen. It lists the game files the player has put on the headset
## (by cable, or over Wi-Fi from a phone or computer: press button C), and runs them in an open-source emulator core when the app has one
## (see EmuSession). Nothing is built in: game files stay in this app's own folder on the headset.
##
## Controls on the machine: STICK moves and picks, A opens, B rescans, C switches Wi-Fi transfer, START opens.
## In a game: stick = D-pad, A/B/C/D = the four face buttons, START = start, MENU = the pause menu (resume, reset, select, save, load, exit).

signal opened(path: String, system: String)

const SYSTEMS := {
	"md": "MEGA DRIVE", "gen": "MEGA DRIVE", "smd": "MEGA DRIVE", "bin": "MEGA DRIVE",
	"nes": "NES", "sfc": "SUPER NES", "smc": "SUPER NES", "gb": "GAME BOY", "gbc": "GAME BOY COLOR", "gba": "GAME BOY ADVANCE",
	"sms": "MASTER SYSTEM", "gg": "GAME GEAR", "pce": "PC ENGINE", "sgx": "PC ENGINE", "a26": "ATARI 2600", "a78": "ATARI 7800", "lnx": "ATARI LYNX", "zip": "ARCHIVE",
}
## Set to false for a store build: the machine then shows a plain notice and never looks at any files.
const ENABLED := true
const PACKAGE := "com.thejoeyrob.fattysgameshack"
const ROM_DIRS := ["user://roms", "/storage/emulated/0/Android/data/com.thejoeyrob.fattysgameshack/files/roms", "/sdcard/Android/data/com.thejoeyrob.fattysgameshack/files/roms", "/sdcard/ROMs"]
## The machine screen is the phone's whole screen (343 x 522), so the emulator picture and its menu sit in the middle of that shape.
const VIEW_H := 576.0 * 522.0 / 343.0
const COLS := 34
const ROWS := 15
const GREEN := Color(0.35, 1.0, 0.45)
const AMBER := Color(1.0, 0.75, 0.2)
const GREY := Color(0.75, 0.78, 0.8)
const PAUSE_ITEMS := ["RESUME GAME", "SAVE STATE", "LOAD STATE", "RESTART GAME", "EXIT TO LIBRARY"]

var viewport: SubViewport
var files: Array = []          # {name, file, path, system, size}
var index := 0
var top := 0
var status := ""
var hold := false              # true while nobody is at the machine: the game is paused
var session: EmuSession                ## the game being played right now: the local one, or a game streamed from the host of the room
var local_session: EmuSession
var remote: RemotePlay                 ## set when the app is in a room (guests see the host's games in the list)
var _audio_host: Node3D
var _wait_t := 0.0
var server: RomServer
var _label: RichTextLabel
var _shade: ColorRect
var _picture: TextureRect
var _t := 0.0
var _stick_prev := Vector2.ZERO
var _btn_prev := {}
var _view := "list"            # list | info | wifi | play | pause | diag | mini
var _mini: MiniArcade
var _info := {}
var _pause_index := 0
var _select_t := 0.0
var _pad := 0
var _font: Font
var _host: Node


func build(host: Node) -> void:
	_host = host
	_font = load("res://assets/fonts/DejaVuSansMono-Bold.ttf")
	viewport = SubViewport.new()
	viewport.size = Vector2i(576, int(VIEW_H))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.transparent_bg = false
	host.add_child(viewport)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.02, 0.0)
	bg.size = Vector2(576, VIEW_H)
	viewport.add_child(bg)
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.visible = false
	viewport.add_child(_picture)
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.72)
	_shade.size = Vector2(576, VIEW_H)
	_shade.visible = false
	viewport.add_child(_shade)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.size = Vector2(556, 672)
	_label.position = Vector2(14, 10 + (VIEW_H - 692.0) / 2.0)
	if _font != null:
		_label.add_theme_font_override("normal_font", _font)
		_label.add_theme_font_override("bold_font", _font)
	_label.add_theme_font_size_override("normal_font_size", 23)
	_label.add_theme_font_size_override("bold_font_size", 23)
	_label.add_theme_color_override("default_color", GREEN)
	viewport.add_child(_label)
	_legend_bg = ColorRect.new()
	_legend_bg.color = Color(0, 0.03, 0, 0.82)
	_legend_bg.size = Vector2(556, 200)
	_legend_bg.position = Vector2(10, VIEW_H - 218)
	_legend_bg.visible = false
	viewport.add_child(_legend_bg)
	_legend = RichTextLabel.new()
	_legend.bbcode_enabled = true
	_legend.scroll_active = false
	_legend.size = Vector2(540, 190)
	_legend.position = Vector2(18, VIEW_H - 212)
	if _font != null:
		_legend.add_theme_font_override("normal_font", _font)
		_legend.add_theme_font_override("bold_font", _font)
	_legend.add_theme_font_size_override("normal_font_size", 19)
	_legend.add_theme_color_override("default_color", GREEN)
	_legend.text = LEGEND
	_legend.visible = false
	viewport.add_child(_legend)
	session = EmuSession.new()
	host.add_child(session)
	local_session = session
	server = RomServer.new()
	host.add_child(server)
	server.uploaded.connect(func(n):
		status = "RECEIVED %s" % n.to_upper()
		rescan())
	server.changed.connect(_redraw)
	rescan()


func screen_texture() -> Texture2D:
	return viewport.get_texture() if viewport != null else null


func set_audio_position(host: Node3D) -> void:
	_audio_host = host
	local_session.attach_audio(host)


## The room's remote play: its game list shows up in this menu for guests, and the game picked from it is played here, running on the host.
func set_remote(r: RemotePlay) -> void:
	remote = r
	r.library_changed.connect(func(): rescan())
	r.guest_ended.connect(_remote_ended)
	if _audio_host != null:
		r.guest_session.attach_audio(_audio_host)


func rescan() -> void:
	files.clear()
	if not ENABLED:
		_redraw()
		return
	var seen := {}
	for d in ROM_DIRS:
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		for f in dir.get_files():
			var ext := f.get_extension().to_lower()
			if SYSTEMS.has(ext) and not seen.has(f):
				seen[f] = true
				var path: String = d + "/" + f
				var fa := FileAccess.open(path, FileAccess.READ)
				var size := fa.get_length() if fa != null else 0
				var sys: String = SYSTEMS[ext]
				if ext == "bin":
					sys = "ATARI 2600" if size <= 65536 else "MEGA DRIVE"      # an Atari 2600 cartridge is at most 64 KB; Mega Drive games are bigger
				if ext == "zip":
					sys = _zip_system(path)
				files.append({"name": f.get_basename().to_upper(), "file": f, "path": path, "system": sys, "size": size})
	files.sort_custom(func(a, b): return str(a.name) < str(b.name))
	# our own games come first: they need no emulator and no game files
	var own: Array = []
	for id in MiniArcade.IDS:
		own.append({"name": str(MiniArcade.NAMES[id]), "file": "", "path": "", "system": "BUILT-IN", "size": 0, "mini": id})
	files = own + files
	# in somebody else's room, the host's games are listed too (marked with @): they run on the host's headset, nothing is copied here
	if remote != null and remote.is_guest():
		for i in range(remote.library.size()):
			var g: Dictionary = remote.library[i]
			files.append({"name": "@" + str(g.n).to_upper(), "file": str(g.n), "path": "", "system": str(g.s), "size": 0, "remote": true, "game": i})
	index = clampi(index, 0, maxi(files.size() - 1, 0))
	_redraw()


## A zip holds one game: say which system it is for by looking at the file inside.
static func _zip_system(path: String) -> String:
	var z := ZIPReader.new()
	if z.open(ProjectSettings.globalize_path(path)) != OK:
		return "ARCHIVE"
	for f in z.get_files():
		var e := f.get_extension().to_lower()
		if SYSTEMS.has(e) and e != "zip":
			var sys: String = SYSTEMS[e]
			if e == "bin":
				sys = "ATARI 2600" if z.read_file(f).size() <= 65536 else "MEGA DRIVE"
			z.close()
			return sys
	z.close()
	return "ARCHIVE"


func rom_folder_hint() -> String:
	return ProjectSettings.globalize_path("user://roms")


## Whether a game is on screen (or about to be): the VR controllers' sticks, triggers and menu button then belong to the game.
func in_game() -> bool:
	return _view == "play" or _view == "pause" or _view == "remote_wait" or _view == "mini"


const LEGEND := "[color=#ffffff]CLASSIC CONTROLS[/color]\nLEFT STICK   MOVE / D-PAD\nA  B  X  Y   GAME BUTTONS\nGRIPS  L / R\nLEFT STICK CLICK  SELECT\nRIGHT STICK CLICK  START\n[color=#ffbf33]LEFT MENU  PAUSE / EXIT[/color]"
var _legend: RichTextLabel
var _legend_bg: ColorRect
var _legend_t := 0.0


## stick: -1..1 each way (y: up is negative); a/b/c/d/start/menu are the machine's buttons (and the Quest controllers' buttons, see vr_main).
func set_input(stick: Vector2, buttons: Dictionary) -> void:
	var up := stick.y < -0.55 and _stick_prev.y >= -0.55
	var down := stick.y > 0.55 and _stick_prev.y <= 0.55
	_stick_prev = stick
	var press := func(k: String) -> bool:
		var d: bool = bool(buttons.get(k, false))
		var was: bool = bool(_btn_prev.get(k, false))
		_btn_prev[k] = d
		return d and not was
	var a: bool = press.call("a")
	var b: bool = press.call("b")
	var c: bool = press.call("c")
	var start: bool = press.call("start")
	var menu: bool = press.call("menu")
	var dbtn: bool = press.call("d")
	if _view == "diag":
		if a or b or c or dbtn or start or menu:
			_view = "list"
			_redraw()
		return
	if _view == "mini":
		_mini.set_input(stick, buttons)
		return
	if _view == "play":
		_pad = EmuSession.pad_from(stick, buttons, _select_t > 0.0, session.system)
		if menu:
			_view = "pause"
			_pause_index = 0
			_redraw()
		return
	_pad = 0
	if _view == "pause":
		if up and _pause_index > 0:
			_pause_index -= 1
		elif down and _pause_index < PAUSE_ITEMS.size() - 1:
			_pause_index += 1
		if menu or b:
			_view = "play"
		elif a or start:
			_pause_choice(_pause_index)
		if up or down or a or start or b or menu:
			_redraw()
		return
	if _view == "info":
		if a or b or start or menu or c:
			_view = "list"
			_redraw()
		return
	if _view == "wifi":
		if a or b or c or start or menu:
			server.stop()
			_view = "list"
			rescan()
		return
	if up and index > 0:
		index -= 1
	elif down and index < files.size() - 1:
		index += 1
	if index < top:
		top = index
	elif index >= top + ROWS:
		top = index - ROWS + 1
	if (a or start) and not files.is_empty():
		_launch(files[index])
	elif b or menu:
		rescan()
		status = "DISK RESCANNED"
	elif dbtn:
		_view = "diag"
	elif c and ENABLED:
		if server.start():
			_view = "wifi"
		else:
			status = "WI-FI TRANSFER NOT AVAILABLE"
	if up or down or a or b or c or dbtn or start or menu:
		_redraw()


func _launch(f: Dictionary) -> void:
	_info = f
	if f.has("mini"):
		_start_mini(str(f.mini))
		return
	if f.get("remote", false):
		_launch_remote(f)
		return
	session = local_session
	opened.emit(str(f.path), str(f.system))
	var err := session.start(str(f.path), str(f.system))
	if err == "":
		_view = "play"
		_picture.visible = true
		_picture.texture = session.texture
		_label.visible = false
		_fit_picture()
		_legend_t = 8.0
	else:
		_info = f.duplicate()
		_info["error"] = err
		_view = "info"


func _start_mini(id: String) -> void:
	if _mini == null:
		_mini = MiniArcade.new()
		_mini.exited.connect(_end_mini)
		viewport.add_child(_mini)
	_mini.visible = true
	_mini.start(id, _font)
	_label.visible = false
	_view = "mini"
	_legend_t = 0.0
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _end_mini() -> void:
	if _mini != null:
		_mini.visible = false
	_label.visible = true
	_view = "list"
	rescan()


func _launch_remote(f: Dictionary) -> void:
	if remote == null:
		return
	var rs: RemoteGuestSession = remote.guest_session
	rs.volume = local_session.volume
	if rs.audio_player == null and _audio_host != null:
		rs.attach_audio(_audio_host)
	var err := rs.start_remote(int(f.game), str(f.system))
	if err != "":
		_info = f.duplicate()
		_info["error"] = err
		_view = "info"
		return
	session = rs
	_view = "remote_wait"
	_wait_t = 0.0
	status = ""
	_redraw()


func _remote_ended(message: String) -> void:
	if remote == null or session != remote.guest_session:
		return
	_back_to_list(message)


func _back_to_list(message: String) -> void:
	session = local_session
	_picture.visible = false
	_label.visible = true
	_view = "list"
	status = message
	rescan()


func _fit_picture() -> void:
	# the screen has the same shape as the Zombie Smash screen on the other machines (the phone app's 343 x 412): the game's picture fills the width
	# and is centred up and down, with black above and below
	var asp := clampf(session.aspect, 0.8, 2.4)
	var vw := 576.0
	var vh := VIEW_H
	var w := vw
	var h := vw / asp
	if h > vh:
		h = vh
		w = vh * asp
	_picture.size = Vector2(w, h)
	_picture.position = Vector2((vw - w) / 2.0, (vh - h) / 2.0)


func _pause_choice(i: int) -> void:
	match i:
		0:
			_view = "play"
		1:
			status = "STATE SAVED" if session.save_state() else "SAVE FAILED"
			_view = "play"
		2:
			status = "STATE LOADED" if session.load_state() else "NO SAVED STATE"
			_view = "play"
		3:
			session.reset()
			_view = "play"
		4:
			_end_game()


func _end_game() -> void:
	session.stop()
	session = local_session
	_picture.visible = false
	_label.visible = true
	_view = "list"
	rescan()


func tick(delta: float) -> void:
	_t += delta
	if _select_t > 0.0:
		_select_t -= delta
	if _legend_t > 0.0 and _view == "play" and not hold:
		_legend_t -= delta
	var show_legend := _legend_t > 0.0 and _view == "play"
	if _legend != null and (_legend.visible != show_legend):
		_legend.visible = show_legend
		_legend_bg.visible = show_legend
	if _view == "mini":
		if not hold:
			_mini.tick(delta)
		return
	# the screen only redraws every frame while a game is running at the machine; the menu just redraws when it changes (twice a second)
	var live := (_view == "play" and session.running and not hold) or (_view == "pause" and session.running)
	if live:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	elif viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _view == "remote_wait":
		_wait_t += delta
		var rs := session as RemoteGuestSession
		if rs != null and rs.running:
			_view = "play"
			_picture.visible = true
			_picture.texture = session.texture
			_label.visible = false
			_fit_picture()
			_legend_t = 8.0
		elif rs == null or (not rs.waiting and not rs.running) or _wait_t > 10.0:
			var why := rs.ended_message if (rs != null and rs.ended_message != "") else "THE HOST DID NOT ANSWER"
			if rs != null:
				rs.stop()
			_back_to_list(why)
		elif int(_t * 2.0) != int((_t - delta) * 2.0):
			_redraw()
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	if (_view == "play" or _view == "pause") and session is RemoteGuestSession and not session.running:
		_back_to_list((session as RemoteGuestSession).ended_message)
		return
	if (_view == "play" or _view == "pause") and session.running:
		if session is RemoteGuestSession:
			session.tick(delta, 0 if (hold or _view == "pause") else _pad)
		elif _view == "play" and not hold:
			session.tick(delta, _pad)
		_shade.visible = _view == "pause"
		_label.visible = _view == "pause"
		if _view == "pause" and int(_t * 2.0) != int((_t - delta) * 2.0):
			_redraw()
		return
	_shade.visible = false
	if int(_t * 2.0) != int((_t - delta) * 2.0):
		_redraw()
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if session != null:
			session.save_ram()


func _pad_s(s: String, n: int) -> String:
	return s.substr(0, n).rpad(n)


func _redraw() -> void:
	if _label == null:
		return
	var t := "[color=#e7fff0]FATTY'S CLASSIC ARCADE[/color]\n"
	t += "[color=#83bca1]JW EDS	GAME LIBRARY[/color]\n\n"
	if _view == "pause":
		t += "[color=#ffffff]PAUSED[/color]\n%s\n\n" % str(session.rom_name).to_upper().substr(0, 30)
		for i in range(PAUSE_ITEMS.size()):
			var line: String = PAUSE_ITEMS[i]
			t += ("[bgcolor=#33d884][color=#04190e]> %s[/color][/bgcolor]\n" if i == _pause_index else "  %s\n") % line
		t += "\n[color=#b4dac5]STICK = MOVE   A = SELECT\nB / MENU = RESUME[/color]"
		if status != "":
			t += "\n[color=#ffcf77]%s[/color]" % status
		_label.text = t
		return
	if _view == "remote_wait":
		_label.text = t + "[color=#ffffff]CONNECTING TO ROOM HOST...[/color]\n\n%s" % str(_info.get("name", ""))
		return
	if _view == "wifi":
		var addr := server.address()
		t += "[color=#ffffff]ADD GAMES BY WI-FI[/color]\n\n"
		if addr == "":
			t += "[color=#ffcf77]CONNECT THE QUEST TO WI-FI.[/color]\n"
		else:
			t += "OPEN THIS ON YOUR PHONE\n(SAME WI-FI NETWORK):\n\n[color=#ffffff]%s[/color]\n\n" % addr
			t += "ENTER PIN: [color=#ffffff]%s[/color]\n" % server.pin
		t += "\nRECEIVED: %d\n\n[color=#b4dac5]A / B / X TO FINISH[/color]" % server.received
		_label.text = t
		return
	if _view == "diag":
		t += "[color=#ffffff]EMULATOR CHECK[/color]\n"
		t += "PLUG-IN: %s\n" % EmuSession.plugin_status()
		var rep := EmuSession.core_report(true)
		t += "CORES WORKING: %d OF %d\n" % [rep.ok, rep.total]
		for l in rep.lines:
			t += "[color=#ffcf77]%s[/color]\n" % str(l).left(110)
		t += "\n[color=#b4dac5]LOG:[/color]\n"
		for l in EmuSession.log_hint(5):
			t += "[color=#9aa]%s[/color]\n" % l
		t += "\n[color=#b4dac5]ANY BUTTON = BACK[/color]"
		_label.text = t
		return
	if _view == "info":
		t += "[color=#ffffff]%s[/color]\n%s\n\n" % [str(_info.get("name", "GAME")).substr(0, 26), str(_info.get("system", ""))]
		t += "[color=#ffcf77]%s[/color]\n\n" % str(_info.get("error", EmuSession.plugin_status()))
		t += "[color=#b4dac5]ANY BUTTON = BACK[/color]"
		_label.text = t
		return
	if not ENABLED:
		t += "[color=#ffcf77]EMULATOR UNAVAILABLE IN THIS BUILD.\nREINSTALL AN EMULATOR-ENABLED APK.[/color]"
		_label.text = t
		return
	t += "[color=#b4dac5]LEFT STICK = CHOOSE  A = PLAY[/color]\n\n"
	if files.is_empty():
		t += "[color=#ffcf77]NO GAMES INSTALLED[/color]\n\n"
		t += "PRESS X TO TRANSFER YOUR\nOWN GAME FILES OVER WI-FI\n\n"
		t += "OR COPY FILES TO THE QUEST\nAPP'S ROMS FOLDER.\n\n"
	else:
		var last: int = mini(files.size(), top + ROWS)
		for i in range(top, last):
			var f: Dictionary = files[i]
			var title := str(f.name).substr(0, 25)
			var available := bool(f.get("remote", false)) or f.has("mini") or EmuSession.has_core(str(f.system))
			var line := "%s%s" % [title, "" if available else "  [NO CORE]"]
			if i == index:
				t += "[bgcolor=#33d884][color=#04190e]> %s[/color][/bgcolor]\n" % line
			else:
				t += "  %s\n" % line
		t += "\n[color=#b4dac5]%d GAMES FOUND[/color]\n" % files.size()
	t += "\n[color=#b4dac5]X = ADD GAMES   B = REFRESH   Y = CHECK[/color]\n"
	var cr := EmuSession.core_report()
	var ok_all: bool = EmuSession.plugin_status() == "READY" and int(cr.ok) == int(cr.total) and int(cr.total) > 0
	t += "[color=#b4dac5]EMULATOR: %s[/color]" % (("READY  CORES %d/%d" % [cr.ok, cr.total]) if ok_all else ("PROBLEM - PRESS Y  (%s)" % EmuSession.plugin_status()))
	if status != "":
		t += "\n[color=#ffcf77]%s[/color]" % status
	_label.text = t


static func _size_text(n: int) -> String:
	if n >= 1048576:
		return "%.1f MB" % (float(n) / 1048576.0)
	return "%d KB" % maxi(1, n / 1024)
