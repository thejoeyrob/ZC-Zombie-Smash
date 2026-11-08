extends SceneTree
## The room client against the real room server (started here on a loopback port): create a room, a second client joins by its code, both see two
## members, the board snapshot with four seats is accepted, and the server and client agree on the protocol. Needs node on the path.
class Stub extends Node3D:
	var avatar
	var machines := []
	var room
	var seated := false
	var hs := []
	var font := ThemeDB.fallback_font
	func _set_locked(_v): pass
	func _stand_up(): pass
	func _place_player(_p, _c): pass
class Obj extends RefCounted:
	var authority := true
	var local_id := ""
	var network_remote := false
	var table
	var snaps := 0
	var skin_id := "human_joeyrob"
	func apply_snapshot(_s): snaps += 1
	func set_lock_light(_v): pass
	var pinball
	var pinball2
	var board_game
	var seats := []

func _make() -> ShackSession:
	var s := ShackSession.new()
	var m := Stub.new()
	get_root().add_child(m)
	var room := ArcadeRoom.new()
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	room.build(m, ImageTexture.create_from_image(img), ImageTexture.create_from_image(img), ThemeDB.fallback_font, VRProgress.new())
	m.room = room
	m.machines = room.machines
	var av := VRAvatar.new()
	m.add_child(av)
	av.build(true)
	av.apply_skin("human_joeyrob")
	m.avatar = av
	m.add_child(s)
	s.main = m
	s.endpoint = "ws://127.0.0.1:%d/shack" % port
	return s

var port := 18765

func _initialize() -> void:
	_run.call_deferred()

func _wait(cond: Callable, seconds := 6.0) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await create_timer(0.05).timeout
		t += 0.05
	return false

func _run() -> void:
	await process_frame
	ZSEngine.setup()
	var server_dir := ProjectSettings.globalize_path("res://").path_join("../server").simplify_path()
	var pid := OS.create_process("sh", ["-c", "PORT=%d exec node %s" % [port, server_dir.path_join("server.mjs")]], false)
	await create_timer(1.0).timeout
	var failures := 0
	var a := _make()
	a.connect_room("", "ALICE")
	var ok := await _wait(func(): return a.online and a.code != "")
	if not ok:
		push_error("host never got a room")
		failures += 1
	var b := _make()
	b.connect_room(a.code, "BOB")
	ok = await _wait(func(): return b.online and b.members.size() == 2 and a.members.size() == 2)
	if not ok:
		push_error("second client did not join: " + b.status)
		failures += 1
	print("room ", a.code, " members ", a.members.size(), " status ", a.status)
	# voice: the sound codec round-trips, and a piece sent by one client is heard by the other
	var tone := PackedFloat32Array()
	for i in range(640):
		tone.append(0.4 * sin(TAU * 440.0 * float(i) / 16000.0))
	var back := VoiceChat.decode(VoiceChat.encode(tone))
	var worst := 0.0
	for i in range(640):
		worst = maxf(worst, absf(back[i].x - tone[i]))
	print("voice codec worst error ", worst)
	if worst > 0.03:
		push_error("voice codec too lossy")
		failures += 1
	ok = await _wait(func(): return b.guest_for_vid(a.vid) != null and a.guest_for_vid(b.vid) != null)
	if not ok:
		push_error("guests were not made for voice")
		failures += 1
	for i in range(5):
		a.voice.send_pcm(tone)
		await create_timer(0.05).timeout
	ok = await _wait(func(): return b.voice.received > 0)
	print("voice pieces sent ", a.voice.sent, " heard ", b.voice.received, " speakers ", b.voice.players.size())
	if not ok or b.voice.players.size() != 1:
		push_error("voice was not heard")
		failures += 1
	a.leave()
	b.leave()
	OS.kill(pid)
	print("LOBBY CLIENT PASS" if failures == 0 else "LOBBY CLIENT FAILED")
	quit(failures)
