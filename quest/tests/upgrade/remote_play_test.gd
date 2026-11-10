extends SceneTree
## Remote play with stand-in emulator cores and no network: the host lists its games, a guest picks one, the host runs it and streams the
## picture and sound, the guest's buttons reach the game, and the game file itself is never sent anywhere.
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failed += 1

class FakeCore:
	extends RefCounted
	var frames := 0
	var pad := 0
	var ready := false
	var loaded := false
	func load_core(path: String) -> bool: return true
	func load_game(rom: String, sysd: String, saved: String) -> bool:
		loaded = FileAccess.file_exists(rom)
		return loaded
	func unload() -> void: loaded = false
	func get_last_error() -> String: return ""
	func get_fps() -> float: return 60.0
	func get_sample_rate() -> float: return 32040.0
	func get_aspect() -> float: return 4.0 / 3.0
	func get_width() -> int: return 256
	func get_height() -> int: return 224
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
		b.resize(256 * 224 * 4)
		for i in range(256 * 224):
			b[i * 4] = (frames * 4 + (i % 256)) % 256
			b[i * 4 + 1] = (i / 256) % 256
			b[i * 4 + 2] = 90 + (pad & 63)
			b[i * 4 + 3] = 255
		return b
	func take_audio() -> PackedVector2Array:
		var a := PackedVector2Array()
		for i in range(534):
			a.append(Vector2(sin(float(i) * 0.1) * 0.3, sin(float(i) * 0.1) * 0.3))
		return a
	func get_save_ram() -> PackedByteArray: return PackedByteArray()
	func set_save_ram(d: PackedByteArray) -> void: pass
	func reset() -> void: frames = 0

## Stands in for the room: whatever one side sends, the other side gets (the host is voice id 0 for the server's purposes, the guest is 2).
class FakeSession:
	extends RefCounted
	var online := true
	var host_id := "h"
	var self_id := "h"
	var vids := {2: "g"}
	var peer: RemotePlay
	var my_vid := 0
	var sound_packets := 0
	var picture_packets := 0
	var bytes_sent := 0
	func send(d: Dictionary) -> void:
		var m := d.duplicate()
		if m.type in ["emu_play", "emu_stop"]:
			m["from"] = my_vid
		peer.on_message(m)
	func send_binary(b: PackedByteArray) -> void:
		bytes_sent += b.size()
		if b.size() == 0:
			return
		if int(b[0]) == RemotePlay.KIND_BUTTONS:
			var out := PackedByteArray([RemotePlay.KIND_BUTTONS, my_vid])
			out.append_array(b.slice(1))
			peer.on_binary(out)
		else:
			if int(b[0]) == RemotePlay.KIND_SOUND:
				sound_packets += 1
			else:
				picture_packets += 1
			peer.on_binary(b.slice(0, 1) + b.slice(2))       # the server drops the target byte

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://roms")
	var rom := FileAccess.open("user://roms/Fake Game.nes", FileAccess.WRITE)
	rom.store_buffer(PackedByteArray([0x4E, 0x45, 0x53, 0x1A, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
	rom.close()
	var host := RemotePlay.new()
	var guest := RemotePlay.new()
	var hs := FakeSession.new()
	var gs := FakeSession.new()
	gs.host_id = "h"
	gs.self_id = "g"
	gs.my_vid = 2
	hs.peer = guest
	gs.peer = host
	host.session = hs
	guest.session = gs
	host.core_factory = func(): return FakeCore.new()
	host.launcher = {"files": [{"name": "FAKE GAME", "file": "Fake Game.nes", "path": "user://roms/Fake Game.nes", "system": "NES", "size": 16}, {"name": "NO CORE", "file": "x.zzz", "path": "user://roms/x.zzz", "system": "VIC 20", "size": 1}]}
	root.add_child(host)
	root.add_child(guest)
	await process_frame
	# the host's list: only games that have a core, names and systems only
	host._publish_t = 0.0
	host._publish_if_changed(0.1)
	check(guest.library.size() == 1 and guest.library[0].n == "FAKE GAME" and guest.library[0].s == "NES", "The guest should see the host's list (got %s)" % str(guest.library))
	check(not JSON.stringify(guest.library).contains("path") and not JSON.stringify(guest.library).contains("roms"), "The list must not carry file paths")
	# the guest asks for the game
	var err := guest.guest_session.start_remote(0, "NES")
	check(err == "" and guest.guest_session.waiting is bool, "Asking should start waiting")
	check(host.streams.size() == 1, "The host should now be running the game for the guest")
	check(guest.guest_session.running and not guest.guest_session.waiting, "The guest should be told yes")
	# play for two seconds: the guest holds buttons
	var pad := (1 << EmuSession.BTN_A) | (1 << EmuSession.BTN_RIGHT) | (1 << EmuSession.BTN_START)
	for i in range(120):
		guest.guest_session.tick(1.0 / 60.0, pad)
		guest.guest_session.pump(1.0 / 60.0)
		host._pump_streams(1.0 / 60.0)
	var st: Dictionary = host.streams[2]
	check((st.sess.core as FakeCore).pad == pad, "The guest's buttons must reach the game (core saw %d, wanted %d)" % [(st.sess.core as FakeCore).pad, pad])
	check(guest.guest_session.pictures >= 30, "Pictures should arrive about thirty a second (got %d)" % guest.guest_session.pictures)
	check(guest.guest_session.texture.get_width() == 256 and guest.guest_session.texture.get_height() == 224, "The picture should be the game's size")
	check(hs.sound_packets > 20, "Sound should be sent (got %d pieces)" % hs.sound_packets)
	var per_second := float(hs.bytes_sent) / 2.0
	print("host sends about %d KB a second" % int(per_second / 1024.0))
	check(per_second < 600000.0, "The stream should stay under about 600 KB/s (got %d)" % int(per_second))
	# the picture the guest holds really is the game's picture (colour channel carries the buttons)
	var img := guest.guest_session.texture.get_image()
	check(img != null and abs(int(img.get_pixel(10, 10).b * 255.0) - (90 + (pad & 63))) < 24, "The picture should show the game")
	# leaving ends the game on the host
	guest.guest_session.stop()
	check(host.streams.is_empty(), "Leaving should stop the host's copy of the game")
	# when sharing is off the host says no
	host.share = false
	guest.guest_session.ended_message = ""
	host._published = ""
	host._publish_t = 0.0
	host._publish_if_changed(0.1)
	check(guest.library.is_empty(), "With sharing off the list is empty")
	host.share = true
	host._publish_t = 0.0
	host._publish_if_changed(0.1)
	host.share = false
	guest.guest_session.start_remote(0, "NES")
	check(not guest.guest_session.running and guest.guest_session.ended_message.contains("OFF"), "Sharing off: the guest is told no (got '%s')" % guest.guest_session.ended_message)
	# a guest who leaves the room ends their game
	host.share = true
	host._publish_t = 0.0
	host._published = ""
	host._publish_if_changed(0.1)
	guest.guest_session.start_remote(0, "NES")
	check(host.streams.size() == 1, "Second game started")
	hs.vids = {}
	host._pump_streams(1.0 / 60.0)
	check(host.streams.is_empty(), "A guest who left the room has their game stopped")
	# the guest's JW EDS menu: the host's game is listed with an @, opening it plays it, leaving goes back to the list
	hs.vids = {2: "g"}
	host.share = true
	host._published = ""
	host._publish_t = 0.0
	host._publish_if_changed(0.1)
	var emu := EmuLauncher.new()
	root.add_child(emu)
	emu.build(root)
	emu.set_remote(guest)
	emu.rescan()
	var listed := emu.files.filter(func(f): return f.get("remote", false))
	check(listed.size() == 1 and str(listed[0].name) == "@FAKE GAME", "The menu should list the host's game with an @ (got %s)" % str(emu.files.map(func(f): return f.name)))
	emu._launch(listed[0])
	check(emu._view == "remote_wait" or emu._view == "play", "Opening a host game should start connecting (view %s)" % emu._view)
	for i in range(200):
		emu.tick(1.0 / 60.0)
		host._pump_streams(1.0 / 60.0)
		guest._process(1.0 / 60.0)
	check(emu._view == "play" and emu.session is RemoteGuestSession and emu.session.pictures > 10, "The game should be playing in the menu (view %s)" % emu._view)
	emu.set_input(Vector2(0.9, 0.0), {"a": true})
	for i in range(30):
		emu.tick(1.0 / 60.0)
		host._pump_streams(1.0 / 60.0)
		guest._process(1.0 / 60.0)
	var held: int = (host.streams[2].sess.core as FakeCore).pad
	check((held & (1 << EmuSession.BTN_RIGHT)) != 0 and (held & (1 << EmuSession.BTN_B)) != 0, "The stick and button from the guest's machine reach the host's game (pad %d)" % held)
	emu._end_game()
	check(emu._view == "list" and emu.session == emu.local_session and host.streams.is_empty(), "Ending the game goes back to the list and frees the host")
	print("REMOTE PLAY PASS" if failed == 0 else "REMOTE PLAY FAILED")
	quit(failed)
