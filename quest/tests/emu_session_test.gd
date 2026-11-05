extends SceneTree
## Runs the whole emulator pipeline with a stand-in core (a script that draws a moving pattern and a tone), so the menu, launching, picture, sound,
## pause menu, saves and pad mapping can be checked without a real emulator core.
class FakeCore:
	extends RefCounted
	var w := 256
	var h := 224
	var frames := 0
	var pad := 0
	var ram := PackedByteArray([1, 2, 3, 4])
	var ready := false
	var loaded := false
	var last_error := ""
	func load_core(path: String) -> bool: return true
	func load_game(rom: String, sysd: String, saved: String) -> bool:
		loaded = FileAccess.file_exists(rom)
		last_error = "" if loaded else "missing"
		return loaded
	func unload() -> void: loaded = false
	func get_last_error() -> String: return last_error
	func get_fps() -> float: return 60.0
	func get_sample_rate() -> float: return 32040.0
	func get_aspect() -> float: return 4.0 / 3.0
	func get_width() -> int: return w
	func get_height() -> int: return h
	func set_pad(p: int, m: int) -> void: pad = m
	func run() -> void:
		frames += 1
		ready = true
	func take_frame_ready() -> bool:
		var r := ready
		ready = false
		return r
	func get_frame() -> PackedByteArray:
		var b := PackedByteArray()
		b.resize(w * h * 4)
		for i in range(w * h):
			b[i * 4] = (frames * 4 + (i % w)) % 256
			b[i * 4 + 1] = 40 + (pad & 255)
			b[i * 4 + 2] = 90
			b[i * 4 + 3] = 255
		return b
	func take_audio() -> PackedVector2Array:
		var a := PackedVector2Array()
		for i in range(534):
			a.append(Vector2(sin(float(i) * 0.1) * 0.2, sin(float(i) * 0.1) * 0.2))
		return a
	func get_save_ram() -> PackedByteArray: return ram
	func set_save_ram(d: PackedByteArray) -> void: ram = d
	func save_state() -> PackedByteArray: return PackedByteArray([9, 9, 9])
	func load_state(d: PackedByteArray) -> bool: return d.size() == 3
	func reset() -> void: frames = 0


func _initialize() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	DirAccess.make_dir_recursive_absolute("user://roms")
	var rom := FileAccess.open("user://roms/Fake Game.nes", FileAccess.WRITE)
	rom.store_buffer(PackedByteArray([0x4E, 0x45, 0x53, 0x1A, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
	rom.close()
	var bad := 0
	var emu := EmuLauncher.new()
	root.add_child(emu)
	emu.build(root)
	var host := Node3D.new()
	root.add_child(host)
	emu.set_audio_position(host)
	emu.session.core_factory = func(): return FakeCore.new()
	emu.rescan()
	print("files found: ", emu.files.size(), "  ", emu.files[0].name if emu.files.size() > 0 else "")
	if emu.files.size() != 1 or emu.files[0].system != "NES": bad += 1
	# pad mapping
	var pad := EmuSession.pad_from(Vector2(-1, 0), {"a": true, "d": true}, false, "NES")
	var want := (1 << EmuSession.BTN_LEFT) | (1 << EmuSession.BTN_B) | (1 << EmuSession.BTN_X)
	print("pad ", pad, " want ", want)
	if pad != want: bad += 1
	var snes := EmuSession.pad_from(Vector2.ZERO, {"start": true, "a": true}, false, "SUPER NES")
	if snes != (1 << EmuSession.BTN_L): bad += 1
	# open the game (A on the stick menu)
	emu.set_input(Vector2.ZERO, {"a": true})
	emu.set_input(Vector2.ZERO, {})
	print("view after launch: ", emu._view, " running=", emu.session.running)
	if emu._view != "play" or not emu.session.running: bad += 1
	# play for a second and a half with the fire button held
	for i in range(90):
		emu.set_input(Vector2.ZERO, {"b": true})
		emu.tick(1.0 / 60.0)
		await process_frame
	var fc: FakeCore = emu.session.core
	print("frames run: ", fc.frames, "  texture ", emu.session.texture.get_width(), "x", emu.session.texture.get_height(), "  pad ", fc.pad)
	if fc.frames < 80 or fc.frames > 100: bad += 1
	if emu.session.texture.get_width() != 256 or fc.pad != (1 << EmuSession.BTN_A): bad += 1
	# pause menu: MENU opens, the game stops, RESUME comes back
	emu.set_input(Vector2.ZERO, {"menu": true})
	emu.set_input(Vector2.ZERO, {})
	var before := fc.frames
	for i in range(30):
		emu.tick(1.0 / 60.0)
		await process_frame
	print("paused: view=", emu._view, " frames moved while paused: ", fc.frames - before)
	if emu._view != "pause" or fc.frames != before: bad += 1
	emu._pause_index = 3
	emu.set_input(Vector2.ZERO, {"a": true})
	emu.set_input(Vector2.ZERO, {})
	print("save state: ", emu.status, "  has_state=", emu.session.has_state())
	emu.set_input(Vector2.ZERO, {"menu": true})      # back into the pause menu
	emu.set_input(Vector2.ZERO, {})
	emu.tick(0.2)
	emu.session.save_ram()
	print("ram file written: ", FileAccess.file_exists("user://saves/Fake Game.fceumm.srm") or FileAccess.file_exists(emu.session._ram_path()))
	# nobody at the machine: the game holds still
	emu.hold = true
	var h0 := fc.frames
	for i in range(20):
		emu.tick(1.0 / 60.0)
	if fc.frames != h0: bad += 1
	emu.hold = false
	# exit the game from the pause menu (it is still open from the step above)
	emu._pause_index = 5
	emu.set_input(Vector2.ZERO, {"a": true})
	emu.set_input(Vector2.ZERO, {})
	print("after exit: view=", emu._view, " running=", emu.session.running)
	if emu._view != "list" or emu.session.running: bad += 1
	# Wi-Fi view
	emu.set_input(Vector2.ZERO, {"c": true})
	emu.set_input(Vector2.ZERO, {})
	print("wifi view: ", emu._view, " server on=", emu.server.running, " pin=", emu.server.pin)
	if emu._view != "wifi" or not emu.server.running: bad += 1
	emu.set_input(Vector2.ZERO, {"a": true})
	emu.set_input(Vector2.ZERO, {})
	if emu.server.running: bad += 1
	# a game with no emulator core says so plainly
	var plain := EmuSession.new()
	root.add_child(plain)
	print("no core message: ", plain.start("user://roms/Fake Game.nes", "PC ENGINE"))
	if plain.start("user://roms/Fake Game.nes", "PC ENGINE") == "": bad += 1
	DirAccess.remove_absolute("user://roms/Fake Game.nes")
	print("EMU SESSION TEST OK" if bad == 0 else "EMU SESSION TEST FAILED (%d)" % bad)
	quit()
