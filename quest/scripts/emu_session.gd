class_name EmuSession
extends Node
## One game running in an emulator core. The cores themselves are open-source libretro cores, run through the native "RetroCore" plugin
## (native/retro). This script finds the right core for a game file, starts it, runs it at the game's own speed, and passes the picture and the
## sound on. The game's saved data (battery saves) is kept in user://saves. Everything stays on the headset.
## When the plugin is not in the app (the store build), supported() is false and nothing here is used.

const CORES := {
	"NES": "fceumm", "SUPER NES": "snes9x2010", "MEGA DRIVE": "genesis_plus_gx", "MASTER SYSTEM": "genesis_plus_gx",
	"GAME GEAR": "genesis_plus_gx", "GAME BOY": "gambatte", "GAME BOY COLOR": "gambatte", "ATARI 2600": "stella2014",
	"GAME BOY ADVANCE": "gpsp", "PC ENGINE": "mednafen_pce_fast", "ATARI 7800": "prosystem", "ATARI LYNX": "handy",
}
# libretro joypad bits
const BTN_B := 0
const BTN_Y := 1
const BTN_SELECT := 2
const BTN_START := 3
const BTN_UP := 4
const BTN_DOWN := 5
const BTN_LEFT := 6
const BTN_RIGHT := 7
const BTN_A := 8
const BTN_X := 9
const BTN_L := 10
const BTN_R := 11

const SYSTEM_DIR := "user://system"
const SAVE_DIR := "user://saves"
const CACHE_DIR := "user://rom_cache"

var core_factory: Callable = func(): return EmuSession._make_native()
var core
var texture := ImageTexture.new()
var audio_player: AudioStreamPlayer3D
var running := false
var rom_name := ""
var system := ""
var aspect := 4.0 / 3.0
var volume := 1.0
## Remote play taps: when set, each finished picture (w, h, RGBA bytes) and each piece of sound (stereo samples, sample rate) is also handed to these.
var frame_tap: Callable
var audio_tap: Callable
var _rate := 32000.0
var _gen: AudioStreamGeneratorPlayback
var _acc := 0.0
var _save_t := 0.0
var _core_name := ""


static func _make_native():
	return ClassDB.instantiate("RetroCore") if ClassDB.class_exists("RetroCore") else null


static func supported() -> bool:
	return ClassDB.class_exists("RetroCore")


static func core_for(sys: String) -> String:
	return str(CORES.get(sys, ""))


static func lib_path(core_name: String) -> String:
	var file := "lib%s_libretro.so" % core_name
	if OS.get_name() == "Android":
		return file                              # the app's own library folder; the system finds it by name
	return ProjectSettings.globalize_path("res://bin/cores/" + file)


## Whether this game's system has a core in the app. On the headset this is only known for sure by trying, so it says yes when the plugin is there.
static func has_core(sys: String) -> bool:
	var c := core_for(sys)
	if c == "" or not supported():
		return false
	return OS.get_name() == "Android" or FileAccess.file_exists(lib_path(c))


func attach_audio(host: Node3D) -> void:
	audio_player = AudioStreamPlayer3D.new()
	audio_player.unit_size = 4.0
	audio_player.max_distance = 30.0
	audio_player.volume_db = 0.0
	host.add_child(audio_player)


## Starts a game. Returns "" on success, or a short plain message saying what went wrong.
func start(rom_path: String, sys: String) -> String:
	stop()
	var cname := core_for(sys)
	if cname == "":
		return "NO EMULATOR FOR %s" % sys
	if not supported() and not core_factory.is_valid():
		return "EMULATOR NOT IN THIS VERSION"
	var c = core_factory.call()
	if c == null:
		return "EMULATOR NOT IN THIS VERSION"
	var path := rom_path
	if path.get_extension().to_lower() == "zip":
		path = _unzip(path)
		if path == "":
			return "COULD NOT OPEN THE ZIP FILE"
	DirAccess.make_dir_recursive_absolute(SYSTEM_DIR)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if not c.load_core(lib_path(cname)):
		return "CORE ERROR: %s" % str(c.get_last_error()).to_upper().substr(0, 60)
	if not c.load_game(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(SYSTEM_DIR), ProjectSettings.globalize_path(SAVE_DIR)):
		var why := str(c.get_last_error()).to_upper().substr(0, 60)
		c.unload()
		return "GAME ERROR: %s" % why
	core = c
	system = sys
	_core_name = cname
	rom_name = rom_path.get_file().get_basename()
	aspect = float(c.get_aspect())
	var ram_file := _ram_path()
	if FileAccess.file_exists(ram_file):
		var f := FileAccess.open(ram_file, FileAccess.READ)
		c.set_save_ram(f.get_buffer(f.get_length()))
	_setup_audio(float(c.get_sample_rate()))
	_acc = 0.0
	_save_t = 0.0
	running = true
	return ""


func _setup_audio(rate: float) -> void:
	_rate = rate
	if audio_player == null:
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = rate
	gen.buffer_length = 0.15
	audio_player.stream = gen
	audio_player.play()
	_gen = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback


## Runs the game for delta seconds of real time. pad: the buttons held, as libretro joypad bits.
func tick(delta: float, pad: int) -> void:
	if not running or core == null:
		return
	var step := 1.0 / maxf(float(core.get_fps()), 30.0)
	_acc += minf(delta, 0.1)
	var n := 0
	core.set_pad(0, pad)
	while _acc >= step and n < 3:
		core.run()
		_acc -= step
		n += 1
	if n == 3:
		_acc = 0.0                                   # fell behind: skip ahead instead of racing to catch up
	if core.take_frame_ready():
		var w: int = core.get_width()
		var h: int = core.get_height()
		var bytes: PackedByteArray = core.get_frame()
		if w > 0 and h > 0 and bytes.size() == w * h * 4:
			texture.set_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes))
			if frame_tap.is_valid():
				frame_tap.call(w, h, bytes)
	_push_audio()
	_save_t += delta
	if _save_t > 20.0:
		_save_t = 0.0
		save_ram()


func _push_audio() -> void:
	var a: PackedVector2Array = core.take_audio()
	if audio_tap.is_valid() and not a.is_empty():
		audio_tap.call(a, _rate)
	if _gen == null or a.is_empty():
		return
	var room := _gen.get_frames_available()
	if a.size() > room:
		a = a.slice(a.size() - room)
	if volume < 0.99:
		for i in range(a.size()):
			a[i] = a[i] * volume
	_gen.push_buffer(a)


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)


func reset() -> void:
	if core != null:
		core.reset()


func save_ram() -> void:
	if core == null:
		return
	var ram: PackedByteArray = core.get_save_ram()
	if ram.is_empty():
		return
	var f := FileAccess.open(_ram_path(), FileAccess.WRITE)
	if f != null:
		f.store_buffer(ram)


func save_state() -> bool:
	if core == null:
		return false
	var st: PackedByteArray = core.save_state()
	if st.is_empty():
		return false
	var f := FileAccess.open(_state_path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(st)
	return true


func load_state() -> bool:
	if core == null or not FileAccess.file_exists(_state_path()):
		return false
	var f := FileAccess.open(_state_path(), FileAccess.READ)
	return bool(core.load_state(f.get_buffer(f.get_length())))


func has_state() -> bool:
	return FileAccess.file_exists(_state_path())


func stop() -> void:
	if core != null:
		save_ram()
		core.unload()
		core = null
	running = false
	_gen = null
	if audio_player != null:
		audio_player.stop()


func _ram_path() -> String:
	return "%s/%s.%s.srm" % [SAVE_DIR, rom_name, _core_name]


func _state_path() -> String:
	return "%s/%s.%s.state" % [SAVE_DIR, rom_name, _core_name]


## Opens a zip and takes out the first game file in it (cores want the plain file).
static func _unzip(zip_path: String) -> String:
	var z := ZIPReader.new()
	if z.open(ProjectSettings.globalize_path(zip_path)) != OK:
		return ""
	var wanted := ["md", "gen", "smd", "bin", "nes", "sfc", "smc", "gb", "gbc", "gba", "sms", "gg", "pce", "sgx", "a26", "a78", "lnx"]
	for f in z.get_files():
		if wanted.has(f.get_extension().to_lower()):
			DirAccess.make_dir_recursive_absolute(CACHE_DIR)
			var out := "%s/%s" % [CACHE_DIR, f.get_file()]
			var w := FileAccess.open(out, FileAccess.WRITE)
			if w == null:
				break
			w.store_buffer(z.read_file(f))
			w.close()
			z.close()
			return out
	z.close()
	return ""


## The buttons of the arcade machine as a libretro pad. stick: -1..1 (y: up is negative). buttons: a b c d start. select_now: the SELECT button, from the menu.
static func pad_from(stick: Vector2, b: Dictionary, select_now: bool, sys: String) -> int:
	var m := 0
	if stick.x < -0.4: m |= 1 << BTN_LEFT
	if stick.x > 0.4: m |= 1 << BTN_RIGHT
	if stick.y < -0.4: m |= 1 << BTN_UP
	if stick.y > 0.4: m |= 1 << BTN_DOWN
	var start: bool = bool(b.get("start", false))
	var a: bool = bool(b.get("a", false))
	var bb: bool = bool(b.get("b", false))
	var shoulder := sys == "SUPER NES" and start and (a or bb)     # holding START turns A and B into the L and R shoulder buttons on the Super NES
	if a: m |= (1 << BTN_L) if shoulder else (1 << BTN_B)
	if bb: m |= (1 << BTN_R) if shoulder else (1 << BTN_A)
	if b.get("c", false): m |= 1 << BTN_Y
	if b.get("d", false): m |= 1 << BTN_X
	if start and not shoulder: m |= 1 << BTN_START
	if select_now: m |= 1 << BTN_SELECT
	return m
