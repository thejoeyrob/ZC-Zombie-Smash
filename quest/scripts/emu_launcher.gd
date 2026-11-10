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
const PAUSE_ITEMS := ["RESUME", "RESET GAME", "PRESS SELECT", "SAVE STATE", "LOAD STATE", "EXIT GAME"]

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
var _view := "list"            # list | info | wifi | play | pause
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
	return _view == "play" or _view == "pause" or _view == "remote_wait"


const LEGEND := "[color=#ffffff]CONTROLLERS[/color]\nTHUMBSTICK ...... MOVE\nA  B  X  Y ...... BUTTONS\nGRIPS ........... L  AND  R\nTHUMBSTICK PRESS  SELECT (LEFT)\n                  START  (RIGHT)\n[color=#ffbf33]LEFT MENU BUTTON  PAUSE MENU[/color]"
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
	elif c and ENABLED:
		if server.start():
			_view = "wifi"
		else:
			status = "WI-FI TRANSFER NOT AVAILABLE"
	if up or down or a or b or c or start or menu:
		_redraw()


func _launch(f: Dictionary) -> void:
	_info = f
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
			session.reset()
			_view = "play"
		2:
			_select_t = 0.25
			_view = "play"
		3:
			status = "STATE SAVED" if session.save_state() else "COULD NOT SAVE"
			_view = "play"
		4:
			status = "STATE LOADED" if session.load_state() else "NO SAVED STATE"
			_view = "play"
		5:
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
	var cursor := "_" if int(_t * 2.0) % 2 == 0 else " "
	var t := ""
	if _view == "pause":
		t += "[color=#ffffff]GAME PAUSED[/color]\n[color=#9aa]%s[/color]\n\n" % str(session.rom_name).to_upper().substr(0, 32)
		for i in range(PAUSE_ITEMS.size()):
			var line := _pad_s(PAUSE_ITEMS[i], COLS)
			if i == _pause_index:
				t += "[bgcolor=#40ff60][color=#001a00]%s[/color][/bgcolor]\n" % line
			else:
				t += line + "\n"
		t += "\n[color=#9aa]THUMBSTICK UP/DOWN, THEN A  CHOOSE\nB OR LEFT MENU BUTTON  BACK TO GAME[/color]\n"
		if status != "":
			t += "\n[color=#ffbf33]%s[/color]" % status
		_label.text = t
		return
	t += "[color=#ffffff]JW EDS ARCADE OS  Version 1.1[/color]\n"
	t += "[color=#9aa]Copyright (c) JW EDS. All rights reserved.[/color]\n\n"
	if _view == "remote_wait":
		t += "[color=#ffffff]CONNECTING TO THE HOST'S MACHINE[/color]\n\n%s\n\nASKING THE HOST TO START THE GAME%s\n" % [str(_info.get("name", "")), ".".repeat(1 + int(_t * 2.0) % 3)]
		_label.text = t
		return
	if _view == "wifi":
		var addr := server.address()
		t += "[color=#ffffff]WI-FI GAME TRANSFER[/color]\n\n"
		if addr == "":
			t += "[color=#ffbf33]NOT CONNECTED TO A NETWORK.\nJOIN WI-FI IN THE QUEST SETTINGS.[/color]\n\n"
		else:
			t += "ON A PHONE OR COMPUTER ON THE\nSAME WI-FI, OPEN:\n\n[color=#ffffff]%s[/color]\n\nTHEN TYPE THE PIN:\n\n[color=#ffffff]       %s[/color]\n\n" % [addr, server.pin]
		t += "RECEIVED THIS TIME: %d\n" % server.received
		if server.last_name != "":
			t += "[color=#9aa]LAST: %s[/color]\n" % server.last_name.to_upper().substr(0, 30)
		t += "\n[color=#9aa]ANY BUTTON  STOP AND GO BACK%s[/color]" % cursor
		_label.text = t
		return
	if _view == "info":
		var f: Dictionary = _info
		t += "C:\\GAMES\\%s\n\n" % str(f.file).to_upper()
		t += "[color=#ffffff]TITLE ......  %s[/color]\n" % str(f.name).substr(0, 24)
		t += "SYSTEM ....  %s\n" % str(f.system)
		t += "SIZE ......  %s\n\n" % _size_text(int(f.size))
		if f.has("error"):
			t += "[color=#ffbf33]%s[/color]\n\n" % str(f.error)
		else:
			if EmuSession.core_for(str(f.system)) == "":
				t += "[color=#ffbf33]NO EMULATOR FOR %s.[/color]\n\n" % str(f.system)
			else:
				t += "[color=#ffbf33]EMULATOR %s[/color]\n\n" % EmuSession.plugin_status()
		t += "PRESS ANY BUTTON TO RETURN%s" % cursor
		_label.text = t
		return
	t += "C:\\GAMES> DIR\n\n"
	if not ENABLED:
		t += "[color=#ffbf33]GAME LIBRARY NOT AVAILABLE\nIN THIS VERSION[/color]\n"
	elif files.is_empty():
		t += "[color=#ffbf33]FILE NOT FOUND[/color]\n\n"
		t += "ADD YOUR OWN GAME FILES:\n[color=#ffffff]PRESS C  (OVER WI-FI)[/color]\nOR COPY THEM BY CABLE TO\n[color=#ffffff]Android/data/%s/\nfiles/roms[/color]\n\n" % PACKAGE
		t += "SUPPORTED: NES SFC SMC MD GEN SMD\nGB GBC GBA SMS GG PCE A26 A78 LNX\n(AND ZIP)\n\n[color=#9aa]EMULATOR: %s[/color]\n" % EmuSession.plugin_status()
	else:
		t += "[color=#9aa]%s  %s[/color]\n" % [_pad_s("NAME", 22), "SYSTEM"]
		var last: int = mini(files.size(), top + ROWS)
		for i in range(top, last):
			var f2: Dictionary = files[i]
			var mark := "" if (f2.get("remote", false) or EmuSession.has_core(str(f2.system))) else "*"
			var line := "%s  %s%s" % [_pad_s(str(f2.name), 22), str(f2.system), mark]
			if i == index:
				t += "[bgcolor=#40ff60][color=#001a00]%s[/color][/bgcolor]\n" % _pad_s(line, COLS)
			else:
				t += line + "\n"
		t += "\n[color=#9aa]%d FILE(S)   * = NO EMULATOR\nEMULATOR: %s[/color]\n" % [files.size(), EmuSession.plugin_status()]
	t += "[color=#ffbf33]%s[/color]\n" % status if status != "" else "\n"
	t += "[color=#9aa]STICK PICK  A OPEN  B RESCAN\nX (OR C) WI-FI TRANSFER[/color]\nC:\\GAMES>%s" % cursor
	_label.text = t


static func _size_text(n: int) -> String:
	if n >= 1048576:
		return "%.1f MB" % (float(n) / 1048576.0)
	return "%d KB" % maxi(1, n / 1024)
