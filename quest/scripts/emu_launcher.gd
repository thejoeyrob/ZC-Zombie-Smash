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
	"sms": "MASTER SYSTEM", "gg": "GAME GEAR", "pce": "PC ENGINE", "zip": "ARCHIVE",
}
## Set to false for a store build: the machine then shows a plain notice and never looks at any files.
const ENABLED := true
const PACKAGE := "com.thejoeyrob.fattysgameshack"
const ROM_DIRS := ["user://roms", "/storage/emulated/0/Android/data/com.thejoeyrob.fattysgameshack/files/roms", "/sdcard/Android/data/com.thejoeyrob.fattysgameshack/files/roms", "/sdcard/ROMs"]
const COLS := 34
const ROWS := 11
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
var session: EmuSession
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
	viewport.size = Vector2i(640, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	host.add_child(viewport)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.02, 0.0)
	bg.size = Vector2(640, 480)
	viewport.add_child(bg)
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.visible = false
	viewport.add_child(_picture)
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.72)
	_shade.size = Vector2(640, 480)
	_shade.visible = false
	viewport.add_child(_shade)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.size = Vector2(620, 460)
	_label.position = Vector2(14, 10)
	if _font != null:
		_label.add_theme_font_override("normal_font", _font)
		_label.add_theme_font_override("bold_font", _font)
	_label.add_theme_font_size_override("normal_font_size", 21)
	_label.add_theme_font_size_override("bold_font_size", 21)
	_label.add_theme_color_override("default_color", GREEN)
	viewport.add_child(_label)
	session = EmuSession.new()
	host.add_child(session)
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
	session.attach_audio(host)


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
				if ext == "zip":
					sys = _zip_system(path)
				files.append({"name": f.get_basename().to_upper(), "file": f, "path": path, "system": sys, "size": size})
	files.sort_custom(func(a, b): return str(a.name) < str(b.name))
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
			z.close()
			return SYSTEMS[e]
	z.close()
	return "ARCHIVE"


func rom_folder_hint() -> String:
	return ProjectSettings.globalize_path("user://roms")


## stick: -1..1 each way (y: up is negative); a/b/c/d/start/menu are the machine's buttons.
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
	opened.emit(str(f.path), str(f.system))
	var err := session.start(str(f.path), str(f.system))
	if err == "":
		_view = "play"
		_picture.visible = true
		_picture.texture = session.texture
		_label.visible = false
		_fit_picture()
	else:
		_info = f.duplicate()
		_info["error"] = err
		_view = "info"


func _fit_picture() -> void:
	var asp := clampf(session.aspect, 0.8, 2.4)
	var w := 640.0
	var h := 640.0 / asp
	if h > 480.0:
		h = 480.0
		w = 480.0 * asp
	_picture.size = Vector2(w, h)
	_picture.position = Vector2((640.0 - w) / 2.0, (480.0 - h) / 2.0)


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
	_picture.visible = false
	_label.visible = true
	_view = "list"
	rescan()


func tick(delta: float) -> void:
	_t += delta
	if _select_t > 0.0:
		_select_t -= delta
	if (_view == "play" or _view == "pause") and session.running:
		if _view == "play" and not hold:
			session.tick(delta, _pad)
		_shade.visible = _view == "pause"
		_label.visible = _view == "pause"
		if _view == "pause" and int(_t * 2.0) != int((_t - delta) * 2.0):
			_redraw()
		return
	_shade.visible = false
	if int(_t * 2.0) != int((_t - delta) * 2.0):
		_redraw()


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
		t += "\n[color=#9aa]STICK UP/DOWN  A CHOOSE\nMENU/B  BACK TO THE GAME[/color]\n"
		if status != "":
			t += "\n[color=#ffbf33]%s[/color]" % status
		_label.text = t
		return
	t += "[color=#ffffff]JW EDS ARCADE OS  Version 1.1[/color]\n"
	t += "[color=#9aa]Copyright (c) JW EDS. All rights reserved.[/color]\n\n"
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
			t += "[color=#ffbf33]NO EMULATOR FOR THIS FILE.[/color]\n\n"
		t += "PRESS ANY BUTTON TO RETURN%s" % cursor
		_label.text = t
		return
	t += "C:\\GAMES> DIR\n\n"
	if not ENABLED:
		t += "[color=#ffbf33]GAME LIBRARY NOT AVAILABLE\nIN THIS VERSION[/color]\n"
	elif files.is_empty():
		t += "[color=#ffbf33]FILE NOT FOUND[/color]\n\n"
		t += "ADD YOUR OWN GAME FILES:\n[color=#ffffff]PRESS C  (OVER WI-FI)[/color]\nOR COPY THEM BY CABLE TO\n[color=#ffffff]Android/data/%s/\nfiles/roms[/color]\n\n" % PACKAGE
		t += "SUPPORTED: NES SFC SMC MD GEN SMD\nGB GBC SMS GG (AND ZIP)\n"
	else:
		t += "[color=#9aa]%s  %s[/color]\n" % [_pad_s("NAME", 22), "SYSTEM"]
		var last: int = mini(files.size(), top + ROWS)
		for i in range(top, last):
			var f2: Dictionary = files[i]
			var mark := "" if EmuSession.has_core(str(f2.system)) else "*"
			var line := "%s  %s%s" % [_pad_s(str(f2.name), 22), str(f2.system), mark]
			if i == index:
				t += "[bgcolor=#40ff60][color=#001a00]%s[/color][/bgcolor]\n" % _pad_s(line, COLS)
			else:
				t += line + "\n"
		t += "\n[color=#9aa]%d FILE(S)   * = NO EMULATOR[/color]\n" % files.size()
	t += "[color=#ffbf33]%s[/color]\n" % status if status != "" else "\n"
	t += "[color=#9aa]STICK PICK  A OPEN  B RESCAN\nC WI-FI TRANSFER[/color]\nC:\\GAMES>%s" % cursor
	_label.text = t


static func _size_text(n: int) -> String:
	if n >= 1048576:
		return "%.1f MB" % (float(n) / 1048576.0)
	return "%d KB" % maxi(1, n / 1024)
