class_name EmuLauncher
extends Node
## The JW EDS machine's operating system: a text-mode, DOS-style menu on a 4:3 screen. It lists the game files the player has put on the
## headset, up and down on the stick to choose, button A to open. Nothing is built in: files stay in this app's own folder on the headset.
##
## IMPORTANT: this is the front end only. Opening a game identifies it (Mega Drive, NES, SNES, Game Boy...) and shows its details, but no emulator
## core is installed yet, so it cannot run the game. Cores can be added later behind the same menu (see CARTRIDGES.md).

signal opened(path: String, system: String)

const SYSTEMS := {
	"md": "MEGA DRIVE", "gen": "MEGA DRIVE", "smd": "MEGA DRIVE", "bin": "MEGA DRIVE",
	"nes": "NES", "sfc": "SUPER NES", "smc": "SUPER NES", "gb": "GAME BOY", "gbc": "GAME BOY COLOR", "gba": "GAME BOY ADVANCE",
	"sms": "MASTER SYSTEM", "gg": "GAME GEAR", "pce": "PC ENGINE",
}
const PACKAGE := "com.thejoeyrob.fattysgameshack"
const ROM_DIRS := ["user://roms", "/storage/emulated/0/Android/data/com.thejoeyrob.fattysgameshack/files/roms", "/sdcard/Android/data/com.thejoeyrob.fattysgameshack/files/roms", "/sdcard/ROMs"]
const COLS := 34
const ROWS := 12
const GREEN := Color(0.35, 1.0, 0.45)
const AMBER := Color(1.0, 0.75, 0.2)
const GREY := Color(0.75, 0.78, 0.8)

var viewport: SubViewport
var files: Array = []          # {name, path, system, size}
var index := 0
var top := 0
var status := ""
var _label: RichTextLabel
var _t := 0.0
var _stick_prev := Vector2.ZERO
var _btn_prev := {}
var _view := "list"            # list | info
var _info := {}
var _font: Font


func build(host: Node) -> void:
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
	var scan := ColorRect.new()     # faint scanlines
	scan.size = Vector2(640, 480)
	scan.color = Color(0, 0, 0, 0)
	viewport.add_child(scan)
	rescan()


func screen_texture() -> Texture2D:
	return viewport.get_texture() if viewport != null else null


func rescan() -> void:
	files.clear()
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
				files.append({"name": f.get_basename().to_upper(), "file": f, "path": path, "system": SYSTEMS[ext], "size": size})
	files.sort_custom(func(a, b): return str(a.name) < str(b.name))
	index = clampi(index, 0, maxi(files.size() - 1, 0))
	_redraw()


func rom_folder_hint() -> String:
	return ProjectSettings.globalize_path("user://roms")


## stick: -1..1 each way (y: up is negative); a/b/start/menu are the machine's buttons.
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
	var start: bool = press.call("start")
	var menu: bool = press.call("menu")
	if _view == "info":
		if a or b or start or menu:
			_view = "list"
			_redraw()
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
		var f: Dictionary = files[index]
		_info = f
		_view = "info"
		opened.emit(str(f.path), str(f.system))
	elif b or menu:
		rescan()
		status = "DISK RESCANNED"
	if up or down or a or start or b or menu:
		_redraw()


func tick(delta: float) -> void:
	_t += delta
	if int(_t * 2.0) != int((_t - delta) * 2.0):
		_redraw()


func _pad(s: String, n: int) -> String:
	return s.substr(0, n).rpad(n)


func _redraw() -> void:
	if _label == null:
		return
	var cursor := "_" if int(_t * 2.0) % 2 == 0 else " "
	var t := ""
	t += "[color=#ffffff]JW EDS ARCADE OS  Version 1.0[/color]\n"
	t += "[color=#9aa]Copyright (c) JW EDS. All rights reserved.[/color]\n\n"
	if _view == "info":
		var f: Dictionary = _info
		t += "C:\\GAMES\\%s\n\n" % str(f.file).to_upper()
		t += "[color=#ffffff]TITLE ......  %s[/color]\n" % str(f.name)
		t += "SYSTEM ....  %s\n" % str(f.system)
		t += "SIZE ......  %s\n" % _size_text(int(f.size))
		t += "PATH ......  %s\n\n" % str(f.path).replace("user://", "")
		t += "[color=#ffbf33]NO EMULATOR CORE INSTALLED FOR THIS SYSTEM.\nTHE FILE WAS FOUND BUT CANNOT RUN YET.[/color]\n\n"
		t += "PRESS ANY BUTTON TO RETURN%s" % cursor
		_label.text = t
		return
	t += "C:\\GAMES> DIR\n\n"
	if files.is_empty():
		t += "[color=#ffbf33]FILE NOT FOUND[/color]\n\n"
		t += "PUT YOUR OWN GAME FILES IN THE\nFOLDER:\n[color=#ffffff]Android/data/%s/\nfiles/roms[/color]\n\n" % PACKAGE
		t += "SUPPORTED: MD GEN SMD BIN NES SFC SMC\nGB GBC GBA SMS GG PCE\n\n"
		t += "FILES STAY ON THIS HEADSET.\n"
	else:
		t += "[color=#9aa]%s  %s[/color]\n" % [_pad("NAME", 22), "SYSTEM"]
		var last: int = mini(files.size(), top + ROWS)
		for i in range(top, last):
			var f2: Dictionary = files[i]
			var line := "%s  %s" % [_pad(str(f2.name), 22), str(f2.system)]
			if i == index:
				t += "[bgcolor=#40ff60][color=#001a00]%s[/color][/bgcolor]\n" % _pad(line, COLS)
			else:
				t += line + "\n"
		t += "\n[color=#9aa]%d FILE(S)[/color]\n" % files.size()
	t += "\n[color=#ffbf33]%s[/color]\n" % status if status != "" else "\n"
	t += "[color=#9aa]STICK UP/DOWN  SELECT\nA  OPEN     B  RESCAN[/color]\nC:\\GAMES>%s" % cursor
	_label.text = t


static func _size_text(n: int) -> String:
	if n >= 1048576:
		return "%.1f MB" % (float(n) / 1048576.0)
	return "%d KB" % maxi(1, n / 1024)
