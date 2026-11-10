extends SceneTree
## Runs a real emulator core through the real plug-in (desktop build of the plug-in + the NES core) on a tiny test program, and checks that it
## loads, runs, and produces a picture. Skipped when the plug-in is not built. Usage: godot --headless -s tests/real_core_test.gd -- /path/to/test.nes
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failed += 1
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	if not EmuSession.supported():
		print("REAL CORE SKIPPED (plug-in not built: %s)" % EmuSession.plugin_status())
		quit(0)
		return
	var args := OS.get_cmdline_user_args()
	var rom := args[0] if args.size() > 0 else "/tmp/claude-0/roms/test.nes"
	var s := EmuSession.new()
	root.add_child(s)
	var err := s.start(rom, "NES")
	check(err == "", "The real core should start the game (said: %s)" % err)
	if err == "":
		var frames := 0
		for i in range(120):
			s.tick(1.0 / 60.0, 0)
			frames += 1
		check(s.running, "The game should still be running")
		check(s.texture.get_width() >= 240 and s.texture.get_height() >= 224, "The picture should be a NES screen (got %dx%d)" % [s.texture.get_width(), s.texture.get_height()])
		check(s.aspect > 1.0, "A picture shape should be reported (%f)" % s.aspect)
		s.reset()
		s.tick(1.0 / 60.0, (1 << EmuSession.BTN_START))
		s.stop()
		print("real core ran %d frames, picture %dx%d, aspect %.2f" % [frames, s.texture.get_width(), s.texture.get_height(), s.aspect])
	print("REAL CORE PASS" if failed == 0 else "REAL CORE FAILED")
	quit(failed)
