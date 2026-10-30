class_name ZSAudio
extends Node
## Plays the pre-rendered Zombie Smash sound library (the same snd-*.wav and mus-*.wav files as the phone game).
## Effects come from the cabinet speakers (3D); music is a plain stereo bed with cross-fades.

const SFX_PATH := "res://assets/audio/snd-%s.wav"
const MUS_PATH := "res://assets/audio/mus-%s.wav"
const SFX_NAMES := ["click", "chime", "back", "toggle", "key", "error", "page", "pistol", "smg", "shotgun", "dmr", "burst", "hose", "rainbow",
	"bass", "beans", "laser", "remover", "purge", "hit", "kill", "ricochet", "bosshit", "throw", "explosion", "hurt", "breach", "pickup", "heart",
	"goldheart", "boost1", "boost2", "boost3", "power", "switch", "target", "clear", "alarm", "warn", "doom", "mutation"]
const MUSIC_NAMES := ["home", "story", "wave1", "wave2", "wave3", "warning", "boss", "finale", "disco", "over"]
const STING_LEN := {"victory": 6.0, "defeat": 6.6, "highscore": 7.0, "wavestart": 1.9}
# name -> [minimum gap in ms, most that may sound at once]
const LIMITS := {
	"pistol": [45, 3], "smg": [32, 3], "shotgun": [60, 2], "dmr": [60, 2], "burst": [70, 2], "hose": [40, 3], "rainbow": [60, 2], "bass": [90, 2],
	"beans": [25, 4], "laser": [60, 2], "remover": [60, 2], "purge": [60, 2], "hit": [55, 2], "kill": [50, 3], "ricochet": [90, 2], "bosshit": [90, 2],
	"explosion": [0, 2], "alarm": [0, 1], "warn": [120, 1], "doom": [0, 1], "mutation": [0, 1], "page": [0, 2],
}
const SPECIAL_SOUND := ["hose", "rainbow", "bass", "beans", "laser", "remover", "purge"]
const MUSIC_TRIM := 0.74

var music_volume := 0.55
var effects_volume := 0.8
var wave := 1
var boss_track := "boss"
var want := ""
var current := ""
var holding_until := 0.0

var _sfx: Dictionary = {}
var _music: Dictionary = {}
var _players: Array[AudioStreamPlayer3D] = []
var _live := {}
var _last := {}
var _decks: Array[AudioStreamPlayer] = []
var _deck := 0
var _resume := {}
var _sting_player: AudioStreamPlayer
var _speaker: Node3D
var _time := 0.0


func setup(speaker: Node3D) -> void:
	_speaker = speaker
	for n in SFX_NAMES:
		var s = load(SFX_PATH % n)
		if s != null:
			_sfx[n] = s
	for i in range(14):
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 4.0
		p.max_distance = 30.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.6
		speaker.add_child(p)
		_players.append(p)
	for i in range(2):
		var d := AudioStreamPlayer.new()
		d.volume_db = -80.0
		add_child(d)
		_decks.append(d)
	_sting_player = AudioStreamPlayer.new()
	add_child(_sting_player)


func _process(delta: float) -> void:
	_time += delta
	if holding_until > 0.0 and _time >= holding_until:
		holding_until = 0.0
		if want != "":
			play_music(want, 1.1)


func _db(linear: float) -> float:
	return linear_to_db(maxf(0.0001, linear))


func music_stream(track: String) -> AudioStreamWAV:
	if not _music.has(track):
		var s = load(MUS_PATH % track)
		if s == null:
			return null
		var loop: AudioStreamWAV = s.duplicate()
		var frames: int = loop.data.size() / (4 if loop.stereo else 2)
		if MUSIC_NAMES.has(track):
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_begin = 0
			loop.loop_end = frames
		_music[track] = loop
	return _music[track]


# ---- music -------------------------------------------------------------------------------------
func wave_track() -> String:
	return "wave1" if wave <= 3 else ("wave2" if wave <= 8 else "wave3")


func resolve(id: String) -> String:
	match id:
		"main": return wave_track()
		"menu": return "home"
		"entrance": return "warning"
		"boss": return boss_track
	return id


func set_boss(id: String) -> void:
	boss_track = "disco" if id == "discoman" else ("finale" if id == "drmantis" else "boss")


func play_music(id: String, fade := 0.9) -> void:
	want = id
	var track := resolve(id)
	if holding_until > 0.0 or track == current:
		return
	var s := music_stream(track)
	if s == null:
		return
	_remember()
	var old := _decks[_deck]
	_deck = 1 - _deck
	var nxt := _decks[_deck]
	nxt.stream = s
	nxt.volume_db = -80.0
	# pick the loop up where it was left (after a fanfare or a scene) so the opening bars do not keep coming back
	nxt.play(float(_resume.get(track, 0.0)))
	current = track
	_fade(nxt, 0.0, music_volume * MUSIC_TRIM, fade, false)
	_fade(old, -1.0, 0.0, fade, true)


func _remember() -> void:
	if current == "":
		return
	var d := _decks[_deck]
	if d.playing and d.stream != null:
		_resume[current] = d.get_playback_position()


## Fades in linear gain (a straight dB fade swells late, which makes the start of a track jump out).
func _fade(deck: AudioStreamPlayer, from_lin: float, to_lin: float, dur: float, stop_after: bool) -> void:
	if from_lin < 0.0:
		from_lin = db_to_linear(deck.volume_db) if deck.volume_db > -79.0 else 0.0
	var tw := create_tween()
	tw.tween_method(func(v: float): deck.volume_db = _db(v) if v > 0.0005 else -80.0, from_lin, to_lin, maxf(0.05, dur))
	if stop_after:
		tw.tween_callback(func(): if deck != _decks[_deck]: deck.stop())


func stop_music(fade := 0.5) -> void:
	want = ""
	_remember()
	current = ""
	for d in _decks:
		_fade(d, -1.0, 0.0, fade, false)
		get_tree().create_timer(fade + 0.05).timeout.connect(func(): if current == "": d.stop())


## A fanfare that owns the music until it is over (victory, defeat, high score).
func stinger(name: String) -> void:
	var s: AudioStreamWAV = music_stream(name)
	if s == null:
		return
	_remember()
	for d in _decks:
		_fade(d, -1.0, 0.0, 0.25, false)
	current = ""
	_sting_player.stream = s
	_sting_player.volume_db = _db(music_volume * 1.1)
	_sting_player.play()
	holding_until = _time + float(STING_LEN.get(name, s.get_length())) + 0.06


## A short flourish over the music (new wave).
func sting(name: String) -> void:
	var s: AudioStreamWAV = music_stream(name)
	if s == null or holding_until > 0.0:
		return
	_sting_player.stream = s
	_sting_player.volume_db = _db(effects_volume * 0.9)
	_sting_player.play()


# ---- effects -----------------------------------------------------------------------------------
func sfx(name: String, volume := 1.0, rate_spread := 0.0) -> void:
	if not _sfx.has(name):
		return
	var now := _time * 1000.0
	var lim: Array = LIMITS.get(name, [25, 3])
	if now - float(_last.get(name, -1.0e9)) < float(lim[0]):
		return
	if int(_live.get(name, 0)) >= int(lim[1]):
		return
	for p in _players:
		if not p.playing:
			_last[name] = now
			p.stream = _sfx[name]
			p.volume_db = _db(volume * effects_volume)
			p.pitch_scale = 1.0 + (randf() * 2.0 - 1.0) * rate_spread
			_live[name] = int(_live.get(name, 0)) + 1
			p.play()
			var done := func(): _live[name] = maxi(0, int(_live.get(name, 1)) - 1)
			get_tree().create_timer(p.stream.get_length() / p.pitch_scale + 0.02).timeout.connect(done)
			return


func ui(name: String, volume := 1.0) -> void:
	sfx(name, volume)


# ---- the game's events (port of event() in game.js) ----------------------------------------------
func on_event(type: String, data: Dictionary, g: ZSEngine) -> void:
	if type == "entrance" or type == "fight":
		set_boss(data.get("id", ""))
	if type == "wave":
		wave = int(data.wave)
	if type == "music":
		var arrival: bool = g.scene != null and g.scene.kind == "arrival"
		play_music("entrance" if arrival else str(data.track))
		return
	var name := ""
	var vol := 1.0
	match type:
		"shot":
			var sid: String = data.get("id", "")
			name = sid if SPECIAL_SOUND.has(sid) else str(data.get("gun", "pistol"))
			vol = 0.85
		"kill": name = "kill"; vol = 0.9
		"hit": name = "bosshit" if data.get("boss", false) else "hit"; vol = 0.7
		"ricochet": name = "ricochet"; vol = 0.8
		"target": name = "target"
		"boost":
			var m := int(data.get("multiplier", 0))
			name = "power" if m == 0 else ("boost3" if m >= 10 else ("boost2" if m >= 4 else "boost1"))
		"breach": name = "breach"
		"clear": name = "clear"; vol = 0.9
		"hurt": name = "hurt"
		"pickup":
			var pt: String = data.get("type", "")
			name = "heart" if pt == "heart" else ("goldheart" if pt == "goldheart" else "pickup")
		"throw": name = "throw"
		"explosion": name = "explosion"
		"entrance": name = "alarm"; vol = 0.8
		"panel": name = "page"
		"mutation": name = "mutation"
		"bossAttack": name = "warn"
		"weaponUse": name = "switch"
	if type == "bossDown":
		stinger("victory")
	elif type == "death":
		stinger("defeat")
	elif type == "wave" and int(data.wave) > 1:
		sting("wavestart")
	elif name != "":
		sfx(name, vol, 0.04 if (name == "hit" or name == "kill" or name == "pistol" or name == "smg") else 0.0)
	if type == "fight":
		sfx("doom")
