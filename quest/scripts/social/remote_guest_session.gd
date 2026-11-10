class_name RemoteGuestSession
extends EmuSession
## A game that is really running on the HOST's headset, shown on the guest's machine. It looks like an ordinary EmuSession to the emulator
## menu (picture texture, running, aspect, tick, stop...) but the picture and sound arrive over the room and the buttons go back.

var remote: RemotePlay
var waiting := false                   # asked, no answer yet
var ended_message := ""                # why it ended, for the menu to show
var _pad_now := 0
var _pad_sent := -1
var _pad_t := 0.0
var _rgen_rate := 22050.0
var pictures := 0


## The menu asks to play game number idx of the host's list.
func start_remote(idx: int, sys: String) -> String:
	stop()
	if remote == null or not remote.is_guest():
		return "NOT IN A ROOM"
	if idx < 0 or idx >= remote.library.size():
		return "NOT IN THE HOST'S LIST"
	system = sys
	rom_name = str(remote.library[idx].n)
	ended_message = ""
	waiting = true
	running = false
	pictures = 0
	remote.request_game(idx)
	return ""


## The host said yes: from now on pictures and sound will come.
func begin(rate: float, asp: float) -> void:
	if not waiting:
		return
	waiting = false
	running = true
	aspect = clampf(asp, 0.8, 2.4)
	_rgen_rate = rate
	_setup_audio(rate)
	_pad_sent = -1


## The host said no, or the game ended: message is why (empty when the guest chose to leave).
func finish(message: String) -> void:
	var was := running or waiting
	waiting = false
	running = false
	ended_message = message
	if audio_player != null:
		audio_player.stop()
	_gen = null
	if was and message != "":
		remote.guest_ended.emit(message)


func on_picture(jpeg: PackedByteArray) -> void:
	if not running:
		return
	var img := Image.new()
	if img.load_jpg_from_buffer(jpeg) != OK or img.get_width() <= 0:
		return
	if texture.get_width() == img.get_width() and texture.get_height() == img.get_height():
		texture.update(img)
	else:
		texture.set_image(img)
	pictures += 1


func on_sound(bytes: PackedByteArray, rate: float) -> void:
	if not running or _gen == null:
		return
	var a := VoiceChat.decode(bytes)
	var room := _gen.get_frames_available()
	if a.size() > room:
		a = a.slice(a.size() - room)
	if volume < 0.99:
		for i in range(a.size()):
			a[i] = a[i] * volume
	_gen.push_buffer(a)


## The menu calls this every frame with the buttons held (a libretro pad); the host only hears about changes (and a reminder now and then).
func tick(delta: float, pad: int) -> void:
	_pad_now = pad


func pump(delta: float) -> void:
	if not running or remote == null or not remote.is_guest():
		return
	_pad_t += delta
	if _pad_now != _pad_sent or _pad_t > 0.25:
		_pad_sent = _pad_now
		_pad_t = 0.0
		remote.session.send_binary(PackedByteArray([RemotePlay.KIND_BUTTONS, _pad_now & 255, (_pad_now >> 8) & 255]))


func stop() -> void:
	if running or waiting:
		if remote != null:
			remote.stop_guest()
	running = false
	waiting = false
	if audio_player != null:
		audio_player.stop()
	_gen = null


func reset() -> void:
	pass                                   # the game is the host's: it cannot be reset from here


func save_ram() -> void:
	pass


func save_state() -> bool:
	return false


func load_state() -> bool:
	return false
