class_name Jukebox
extends Node3D
## A chrome-and-neon jukebox. Touch PREV, NEXT or PLAY/STOP with a fingertip. It plays the arcade's own tracks through the room.
## (Spotify is not connected: that needs a Spotify developer app and a native plugin, which is a separate job.)

signal command(name: String)

const TRACKS := [
	["arcade", "AIR GUITAR HERO"], ["home", "HOLD THE LINE"], ["wave1", "SUNNY HORDE"], ["wave2", "NIGHT SHIFT"], ["wave3", "LAST STAND"],
	["disco", "DISCO MAN"], ["boss", "BOSS RUSH"], ["finale", "MANTIS LAB"], ["story", "THE OPENING"],
]
const BUTTONS := {"prev": Vector3(-0.2, 1.12, 0.0), "play": Vector3(0.0, 1.12, 0.0), "next": Vector3(0.2, 1.12, 0.0)}

var index := 0
var playing := true
var display: Label3D
var status: Label3D
var _btn_nodes := {}
var _tubes: Array = []
var _t := 0.0
var _font: Font


func build(font: Font) -> void:
	_font = font
	var chrome := RuinedExterior.surface("materials", 3, Color(0.98, 0.98, 1.0), 0.25)
	var body := VRBuild.mat(Color(0.5, 0.06, 0.16), 0.3, 0.2)
	var dark := VRBuild.mat(Color(0.03, 0.03, 0.04), 0.5)
	var glass := VRBuild.mat(Color(1.0, 0.7, 0.3), 0.3, 0.0, 1.8)
	# cabinet: base, shoulders, a half-round crown
	VRBuild.box(self, Vector3(0.9, 0.2, 0.55), Vector3(0, 0.1, 0), dark)
	VRBuild.box(self, Vector3(0.84, 1.1, 0.5), Vector3(0, 0.75, 0), body)
	VRBuild.box(self, Vector3(0.94, 0.05, 0.56), Vector3(0, 1.3, 0), chrome)
	var crown := VRBuild.cylinder(self, 0.42, 0.5, Vector3(0, 1.62, 0), body, -1.0, Vector3(PI / 2, 0, 0), 32)
	crown.scale = Vector3(1, 1, 1)
	VRBuild.box(self, Vector3(0.84, 0.32, 0.5), Vector3(0, 1.46, 0), body)
	# the lit window with the record mechanism, and rainbow tubes round the crown
	VRBuild.box(self, Vector3(0.62, 0.5, 0.02), Vector3(0, 1.58, 0.255), glass)
	VRBuild.cylinder(self, 0.16, 0.012, Vector3(0, 1.58, 0.27), VRBuild.mat(Color(0.05, 0.05, 0.06), 0.3, 0.0, 0.0), -1.0, Vector3(PI / 2, 0, 0), 28)
	VRBuild.cylinder(self, 0.05, 0.014, Vector3(0, 1.58, 0.274), chrome, -1.0, Vector3(PI / 2, 0, 0), 16)
	for k in range(5):
		var col := Color.from_hsv(float(k) / 5.0, 0.9, 1.0)
		var m := VRBuild.mat(col, 0.3, 0.0, 2.6)
		_tubes.append(m)
		for sd in [-1.0, 1.0]:
			VRBuild.box(self, Vector3(0.012, 0.46, 0.012), Vector3(sd * (0.33 + k * 0.016), 1.58, 0.27), m)
	# a grille and a record display
	VRBuild.box(self, Vector3(0.7, 0.44, 0.02), Vector3(0, 0.55, 0.255), dark)
	for g in range(7):
		VRBuild.box(self, Vector3(0.66, 0.012, 0.012), Vector3(0, 0.38 + g * 0.06, 0.268), chrome)
	# the selection panel: a name display and three chunky buttons
	VRBuild.box(self, Vector3(0.74, 0.3, 0.1), Vector3(0, 1.1, 0.2), chrome)
	VRBuild.box(self, Vector3(0.6, 0.1, 0.012), Vector3(0, 1.2, 0.255), VRBuild.mat(Color(0.02, 0.04, 0.02), 0.3, 0.0, 0.5, Color(0.2, 0.9, 0.3)))
	display = VRBuild.label(self, "", 0.045, Vector3(0, 1.2, 0.264), Color(0.5, 1.0, 0.6), Vector3.ZERO, 0, _font)
	status = VRBuild.label(self, "", 0.026, Vector3(0, 1.145, 0.264), Color(0.9, 0.9, 0.7), Vector3.ZERO, 0, _font)
	var names := {"prev": "<", "play": "||", "next": ">"}
	for k in BUTTONS:
		var bn := Node3D.new()
		bn.position = Vector3(BUTTONS[k].x, 1.06, 0.255)
		add_child(bn)
		VRBuild.cylinder(bn, 0.036, 0.016, Vector3(0, 0, 0.0), VRBuild.mat(Color(0.9, 0.82, 0.3), 0.15, 0.6, 0.3, Color(0.9, 0.8, 0.2)), 0.034, Vector3(PI / 2, 0, 0), 24)
		VRBuild.label(bn, names[k], 0.04, Vector3(0, 0, 0.011), Color(0.1, 0.05, 0.0), Vector3.ZERO, 0, _font)
		_btn_nodes[k] = bn
	VRBuild.label(self, "JUKEBOX", 0.1, Vector3(0, 1.9, 0.05), Color(1.0, 0.85, 0.3), Vector3.ZERO, 8, _font)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 1.4, 0.7)
	l.light_color = Color(1.0, 0.65, 0.5)
	l.light_energy = 0.9
	l.omni_range = 2.6
	add_child(l)
	_refresh()


func current_id() -> String:
	return TRACKS[index][0]


func _refresh() -> void:
	display.text = TRACKS[index][1]
	status.text = ("NOW PLAYING" if playing else "STOPPED") + "   %d / %d" % [index + 1, TRACKS.size()]


func button_at(world: Vector3) -> String:
	var p := to_local(world)
	if p.z < 0.2 or p.z > 0.4:
		return ""
	for k in BUTTONS:
		var n: Node3D = _btn_nodes[k]
		if absf(p.x - n.position.x) < 0.045 and absf(p.y - n.position.y) < 0.045:
			return k
	return ""


func press(name: String) -> void:
	var n: Node3D = _btn_nodes.get(name)
	if n != null:
		var tw := create_tween()
		tw.tween_property(n, "position:z", 0.245, 0.04)
		tw.tween_property(n, "position:z", 0.255, 0.12)
	match name:
		"prev":
			index = posmod(index - 1, TRACKS.size())
			playing = true
		"next":
			index = posmod(index + 1, TRACKS.size())
			playing = true
		"play":
			playing = not playing
	_refresh()
	command.emit("play" if playing else "stop")


func _process(delta: float) -> void:
	_t += delta
	for i in range(_tubes.size()):
		var m: StandardMaterial3D = _tubes[i]
		var h := fmod(_t * 0.15 + float(i) / 5.0, 1.0)
		var c := Color.from_hsv(h, 0.9, 1.0)
		m.albedo_color = c
		m.emission = c
		m.emission_energy_multiplier = 2.4 if playing else 0.5
