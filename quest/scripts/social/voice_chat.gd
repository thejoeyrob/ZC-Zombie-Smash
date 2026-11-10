class_name VoiceChat
extends Node
## Voice for rooms. The microphone is read once per frame, turned into 16 kHz mono, squeezed to one byte per sample (mu-law), cut into 40 ms pieces
## and sent to the room server, which hands each piece to everyone else in the room. Each other person's voice comes out of a speaker at their head,
## so voices come from where people stand. Quiet gaps are not sent. Nothing is recorded or kept anywhere.

const RATE := 16000
const CHUNK := 640                 # 40 ms of sound
const GATE := 0.012                # below this loudness it is background hiss, not speech
const HANG := 0.4                  # keep sending this long after the last loud piece so word endings are not cut off
const BIAS := 0x84
const CLIP := 32635

var session
var enabled := true                # the player's own switch (menu: VOICE ON / OFF)
var mic_ready := false
var talking := false
var capture: AudioEffectCapture
var mic_player: AudioStreamPlayer
var players := {}                  # voice id -> speaker at that person's head
var sent := 0
var received := 0
var _acc := PackedFloat32Array()
var _sum := 0.0
var _cnt := 0
var _phase := 0.0
var _hang := 0.0


static func encode(samples: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(samples.size())
	for i in range(samples.size()):
		var s := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		var sign := 0
		if s < 0:
			sign = 0x80
			s = -s
		s = mini(s, CLIP) + BIAS
		var exponent := 7
		var mask := 0x4000
		while exponent > 0 and (s & mask) == 0:
			exponent -= 1
			mask >>= 1
		var mantissa := (s >> (exponent + 3)) & 0x0F
		out[i] = (~(sign | (exponent << 4) | mantissa)) & 0xFF
	return out


static func decode(bytes: PackedByteArray, from := 0) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(maxi(bytes.size() - from, 0))
	for i in range(from, bytes.size()):
		var b := (~int(bytes[i])) & 0xFF
		var sample := (((b & 0x0F) << 3) + BIAS) << ((b >> 4) & 7)
		sample -= BIAS
		var v := float(-sample if (b & 0x80) != 0 else sample) / 32768.0
		out[i - from] = Vector2(v, v)
	return out


func _process(_delta: float) -> void:
	if session == null:
		return
	if session.online and enabled and not mic_ready:
		_start_mic()
	if capture != null:
		_read_mic(_delta)


## Starts the microphone. On the headset the first time asks the player's permission (Quest shows its own prompt).
func _start_mic() -> void:
	if DisplayServer.get_name() == "headless":
		return                                          # tests: no microphone to open
	if OS.get_name() == "Android" and not "android.permission.RECORD_AUDIO" in OS.get_granted_permissions():
		OS.request_permission("RECORD_AUDIO")
		return
	if capture == null:
		var bus := AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus, "VoiceMic")
		AudioServer.set_bus_mute(bus, true)              # you never hear your own microphone
		capture = AudioEffectCapture.new()
		capture.buffer_length = 0.5
		AudioServer.add_bus_effect(bus, capture)
		mic_player = AudioStreamPlayer.new()
		mic_player.stream = AudioStreamMicrophone.new()
		mic_player.bus = "VoiceMic"
		add_child(mic_player)
	mic_player.play()
	mic_ready = true


func _read_mic(delta: float) -> void:
	var n := capture.get_frames_available()
	if n <= 0:
		return
	var buffer := capture.get_buffer(n)
	if not (enabled and session.online):
		_acc.clear()
		return
	var step := AudioServer.get_mix_rate() / float(RATE)
	for f in buffer:
		_sum += (f.x + f.y) * 0.5
		_cnt += 1
		_phase += 1.0
		if _phase >= step:
			_phase -= step
			_acc.append(_sum / float(_cnt))
			_sum = 0.0
			_cnt = 0
	while _acc.size() >= CHUNK:
		var piece := _acc.slice(0, CHUNK)
		_acc = _acc.slice(CHUNK)
		var level := 0.0
		for v in piece:
			level += v * v
		level = sqrt(level / float(CHUNK))
		if level > GATE:
			_hang = HANG
		talking = _hang > 0.0
		_hang -= float(CHUNK) / float(RATE)
		if talking:
			send_pcm(piece)


## Sends one piece of sound (16 kHz mono, -1..1).
func send_pcm(samples: PackedFloat32Array) -> void:
	if session == null or not session.online:
		return
	var pkt := PackedByteArray([1])                  # kind 1 = voice (the room server tells voice from remote-play pictures by this first byte)
	pkt.append_array(encode(samples))
	session.send_binary(pkt)
	sent += 1


## A piece of someone's voice arrived: the first byte says whose, the rest is the sound.
func receive(raw: PackedByteArray) -> void:
	if raw.size() < 2 or raw.size() > 2049:
		return
	received += 1
	var vid := int(raw[0])
	var speaker: AudioStreamPlayer3D = _speaker_for(vid)
	if speaker == null:
		return
	var guest = session.guest_for_vid(vid)
	if guest != null and guest.poses.size() > 0:
		speaker.global_position = (guest.poses[0] as Transform3D).origin
	var playback := speaker.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames := decode(raw, 1)
	if playback.get_frames_available() >= frames.size():
		playback.push_buffer(frames)


func _speaker_for(vid: int) -> AudioStreamPlayer3D:
	var guest = session.guest_for_vid(vid)
	if guest == null:
		return null
	if players.has(vid) and is_instance_valid(players[vid]):
		return players[vid]
	var speaker := AudioStreamPlayer3D.new()
	speaker.unit_size = 3.0
	speaker.max_distance = 25.0
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = RATE
	stream.buffer_length = 0.5
	speaker.stream = stream
	guest.add_child(speaker)
	speaker.play()
	players[vid] = speaker
	return speaker


func reset() -> void:
	for p in players.values():
		if is_instance_valid(p):
			p.queue_free()
	players.clear()
	_acc.clear()
	talking = false
