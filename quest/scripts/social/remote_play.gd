class_name RemotePlay
extends Node
## Remote play in a room, like "remote play together": the HOST runs the games on their own headset and streams the picture and sound to a
## guest who picked one from the host's collection; the guest sends back only their buttons. Game files never leave the host's headset and
## nothing is kept by the guest, so a guest plays the host's collection only while they are in the host's room.
##
## Wire format (all through the room server, which only passes these between the host and one guest):
##   JSON  host -> everyone   {"type":"library","games":[{"n":name,"s":system}]}   the host's list (names only)
##   JSON  guest -> host      {"type":"emu_play","game":index}  /  {"type":"emu_stop"}      (the server adds "from": the guest's voice id)
##   JSON  host -> guest      {"type":"emu_ok","to":vid,"rate":22050,"aspect":1.33}  /  emu_no / emu_end with a "message"
##   binary host -> guest     [0xE1, guest vid, ...jpeg]  one picture      [0xE2, guest vid, rate/1000, ...mu-law]  a piece of sound
##   binary guest -> host     [0xE3, lo, hi]  the guest's buttons as a libretro pad (the server adds the guest's vid after the kind byte)

signal library_changed
signal guest_ended(message: String)

const KIND_PICTURE := 0xE1
const KIND_SOUND := 0xE2
const KIND_BUTTONS := 0xE3
const MAX_STREAMS := 2                 # games the host runs for guests at once (each is a whole emulator on the headset)
const PICTURE_FPS := 30.0
const SOUND_RATE := 22050
const MAX_PICTURE := 15000             # bytes: the server passes 16000 at most

var session                            # the ShackSession (send / send_binary / online / self_id / host_id / vids)
var launcher                           # the EmuLauncher: where the host's own games are listed
var share := true                      # the host's switch: let guests play my games
var core_factory: Callable             # tests give a stand-in emulator core here; the app uses the real plug-in

# ---- the guest's side ----
var library: Array = []                # the host's games: [{n, s}]
var guest_session: RemoteGuestSession

# ---- the host's side ----
var streams := {}                      # guest voice id -> {sess: EmuSession, pad: int, send_t: float, frame: Image, rate_phase: float, snd: PackedFloat32Array, name: String}
var _published := ""
var _publish_t := 0.0
var _list: Array = []                  # the files behind the list that was published (same order)


func _ready() -> void:
	guest_session = RemoteGuestSession.new()
	guest_session.remote = self
	add_child(guest_session)


func is_host() -> bool:
	return session != null and session.online and str(session.host_id) == str(session.self_id)


func is_guest() -> bool:
	return session != null and session.online and not is_host()


func reset() -> void:
	for vid in streams.keys():
		_close_stream(int(vid), "")
	streams.clear()
	library = []
	_published = ""
	if guest_session != null and guest_session.running:
		guest_session.finish("")
	library_changed.emit()


# ---------------------------------------------------------------------------------------------------------------- messages
func on_message(d: Dictionary) -> void:
	match str(d.get("type", "")):
		"library":
			if is_host():
				return
			var games: Array = []
			for g in d.get("games", []):
				if g is Dictionary:
					games.append({"n": str(g.get("n", "")).left(28), "s": str(g.get("s", "")).left(18)})
			library = games
			library_changed.emit()
		"emu_play":
			_on_play(int(d.get("from", 0)), int(d.get("game", -1)))
		"emu_stop":
			_close_stream(int(d.get("from", 0)), "")
		"emu_ok":
			guest_session.begin(float(d.get("rate", SOUND_RATE)), float(d.get("aspect", 4.0 / 3.0)))
		"emu_no":
			guest_session.finish("HOST: " + str(d.get("message", "NOT AVAILABLE")).to_upper())
		"emu_end":
			guest_session.finish(str(d.get("message", "")).to_upper())


func on_binary(raw: PackedByteArray) -> void:
	if raw.size() < 2:
		return
	match int(raw[0]):
		KIND_PICTURE:
			guest_session.on_picture(raw.slice(1))
		KIND_SOUND:
			if raw.size() > 2:
				guest_session.on_sound(raw.slice(2), float(raw[1]) * 1000.0)
		KIND_BUTTONS:                                   # from the server: [kind, guest vid, lo, hi]
			if raw.size() >= 4 and streams.has(int(raw[1])):
				streams[int(raw[1])].pad = int(raw[2]) | (int(raw[3]) << 8)


# ---------------------------------------------------------------------------------------------------------------- the host
## The games a guest may be offered: the host's own files that have a core in this app.
func _shareable() -> Array:
	var out: Array = []
	if launcher == null or not share:
		return out
	for f in launcher.files:
		if f.get("remote", false) or EmuSession.core_for(str(f.system)) == "" or not (core_factory.is_valid() or EmuSession.has_core(str(f.system))) or str(f.path) == "":
			continue
		out.append(f)
	return out


func _publish_if_changed(delta: float) -> void:
	_publish_t -= delta
	if _publish_t > 0.0 or not is_host():
		return
	_publish_t = 2.0
	var list := _shareable()
	var names: Array = []
	for f in list:
		names.append({"n": str(f.name).left(28), "s": str(f.system)})
	var sig := JSON.stringify(names)
	if sig == _published:
		return
	_published = sig
	_list = list
	session.send({"type": "library", "games": names})


func _on_play(vid: int, idx: int) -> void:
	if not is_host() or vid <= 0:
		return
	if not share:
		_reply(vid, "emu_no", "Sharing is off")
		return
	if streams.has(vid):
		_close_stream(vid, "")
	if idx < 0 or idx >= _list.size():
		_reply(vid, "emu_no", "No such game")
		return
	if streams.size() >= MAX_STREAMS:
		_reply(vid, "emu_no", "Host is busy with other players")
		return
	var f: Dictionary = _list[idx]
	var s := EmuSession.new()
	if core_factory.is_valid():
		s.core_factory = core_factory
	add_child(s)
	var err := s.start(str(f.path), str(f.system))
	if err != "":
		s.queue_free()
		_reply(vid, "emu_no", err)
		return
	var st := {"sess": s, "pad": 0, "send_t": 0.0, "frame": null, "rate_phase": 0.0, "snd": PackedFloat32Array(), "name": str(f.name)}
	streams[vid] = st
	s.frame_tap = func(w: int, h: int, bytes: PackedByteArray) -> void:
		st.frame = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	s.audio_tap = func(a: PackedVector2Array, rate: float) -> void:
		_take_sound(st, a, rate)
	_reply(vid, "emu_ok", "", SOUND_RATE, s.aspect)


func _reply(vid: int, kind: String, msg: String, rate := 0, aspect := 1.333) -> void:
	session.send({"type": kind, "to": vid, "message": msg, "rate": rate, "aspect": aspect})


func _close_stream(vid: int, message: String) -> void:
	if not streams.has(vid):
		return
	var st: Dictionary = streams[vid]
	(st.sess as EmuSession).stop()
	(st.sess as EmuSession).queue_free()
	streams.erase(vid)
	if message != "" and session != null:
		session.send({"type": "emu_end", "to": vid, "message": message})


## Sound from a game for a guest: mixed to mono, brought to 22 kHz, squeezed to one byte a sample, and sent in short pieces.
func _take_sound(st: Dictionary, a: PackedVector2Array, rate: float) -> void:
	var step := rate / float(SOUND_RATE)
	var snd: PackedFloat32Array = st.snd
	var ph: float = st.rate_phase
	var acc := 0.0
	var n := 0
	for v in a:
		acc += (v.x + v.y) * 0.5
		n += 1
		ph += 1.0
		if ph >= step:
			ph -= step
			snd.append(acc / float(n))
			acc = 0.0
			n = 0
	st.rate_phase = ph
	st.snd = snd


func _pump_streams(delta: float) -> void:
	var gone: Array = []
	for vid in streams.keys():
		var st: Dictionary = streams[vid]
		if not session.vids.has(int(vid)):
			gone.append(int(vid))                       # the guest left the room
			continue
		var s: EmuSession = st.sess
		s.tick(delta, int(st.pad))
		# sound: pieces of about 20 ms
		var snd: PackedFloat32Array = st.snd
		while snd.size() >= 441:
			var piece := snd.slice(0, 441)
			snd = snd.slice(441)
			var pkt := PackedByteArray([KIND_SOUND, int(vid), SOUND_RATE / 1000])
			pkt.append_array(VoiceChat.encode(piece))
			session.send_binary(pkt)
		st.snd = snd
		# picture: thirty a second
		st.send_t += delta
		if st.send_t >= 1.0 / PICTURE_FPS and st.frame != null:
			st.send_t = 0.0
			var jpg := _encode_picture(st.frame)
			st.frame = null
			if jpg.size() > 0:
				var pk := PackedByteArray([KIND_PICTURE, int(vid)])
				pk.append_array(jpg)
				session.send_binary(pk)
	for vid in gone:
		_close_stream(int(vid), "")


static func _encode_picture(img: Image) -> PackedByteArray:
	var im := img
	for q in [0.6, 0.45, 0.3]:
		var jpg := im.save_jpg_to_buffer(q)
		if jpg.size() <= MAX_PICTURE:
			return jpg
		if q == 0.3:
			im = img.duplicate()
			im.resize(maxi(im.get_width() * 3 / 4, 64), maxi(im.get_height() * 3 / 4, 64), Image.INTERPOLATE_BILINEAR)
			return im.save_jpg_to_buffer(0.4)
	return PackedByteArray()


func _process(delta: float) -> void:
	if session == null:
		return
	_publish_if_changed(delta)
	if not streams.is_empty():
		if is_host():
			_pump_streams(delta)
		else:
			reset()
	# a guest's button state goes to the host while a remote game is running
	if guest_session != null:
		guest_session.pump(delta)


# ---------------------------------------------------------------------------------------------------------------- the guest
func request_game(idx: int) -> void:
	if is_guest() and idx >= 0 and idx < library.size():
		session.send({"type": "emu_play", "game": idx})


func stop_guest() -> void:
	if is_guest():
		session.send({"type": "emu_stop"})
