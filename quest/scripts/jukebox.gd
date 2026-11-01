class_name Jukebox
extends Node3D
## A chrome-and-neon jukebox. Touch PREV, NEXT or PLAY/STOP with a fingertip. It plays the arcade's own tracks through the room.
## (Spotify is not connected: that needs a Spotify developer app and a native plugin, which is a separate job.)

signal command(name: String)

const TRACKS := [
	["arcade", "AIR GUITAR HERO"], ["home", "HOLD THE LINE"], ["wave1", "SUNNY HORDE"], ["wave2", "NIGHT SHIFT"], ["wave3", "LAST STAND"],
	["disco", "DISCO MAN"], ["boss", "BOSS RUSH"], ["finale", "MANTIS LAB"], ["story", "THE OPENING"],
]
const BUTTONS := {"prev": Vector3(-0.2, 0.723, 0.0), "play": Vector3(0.0, 0.723, 0.0), "next": Vector3(0.2, 0.723, 0.0)}
const FRONT_Z := 0.25

var index := 0
var playing := true
var display: Label3D
var status: Label3D
var _btn_nodes := {}
var _neon: StandardMaterial3D
var _t := 0.0
var _font: Font


static func _art(file: String) -> Texture2D:
	var t = load("res://assets/art/%s" % file)
	return t if t is Texture2D else null


## The whole machine is painted artwork: a rendered front, a neon layer that glows and breathes, and a stack of
## silhouette slices that give the cabinet its depth. Only the buttons and the display are separate pieces.
func build(font: Font) -> void:
	_font = font
	var front_tex := _art("jukebox-front.png")
	var side_tex := _art("jukebox-side.png")
	var neon_tex := _art("jukebox-neon.png")
	var size := Vector2(0.9, 1.95)
	var cy := 0.975
	if side_tex != null:
		var sm := VRBuild.tex_mat(side_tex, 0.0, 0.55)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		sm.alpha_scissor_threshold = 0.5
		for i in range(26):
			VRBuild.quad(self, size, Vector3(0, cy, FRONT_Z - 0.012 - float(i) * 0.015), sm)
	if front_tex != null:
		var fm := VRBuild.tex_mat(front_tex, 0.18, 0.4)
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		fm.alpha_scissor_threshold = 0.5
		fm.metallic_specular = 0.6
		VRBuild.quad(self, size, Vector3(0, cy, FRONT_Z), fm)
	if neon_tex != null:
		_neon = VRBuild.tex_mat(neon_tex, 0.0, 0.5, true)
		_neon.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_neon.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		VRBuild.quad(self, size, Vector3(0, cy, FRONT_Z + 0.004), _neon)
	# the name of the record, on the green display in the painted selector plate
	display = VRBuild.label(self, "", 0.05, Vector3(0, 0.842, FRONT_Z + 0.008), Color(0.5, 1.0, 0.6), Vector3.ZERO, 0, _font)
	status = VRBuild.label(self, "", 0.03, Vector3(0, 0.79, FRONT_Z + 0.008), Color(0.9, 0.9, 0.7), Vector3.ZERO, 0, _font)
	for k in BUTTONS:
		var bn := Node3D.new()
		bn.position = Vector3(BUTTONS[k].x, BUTTONS[k].y, FRONT_Z + 0.006)
		add_child(bn)
		var bt := _art("jukebox-btn-%s.png" % k)
		if bt != null:
			var bm := VRBuild.tex_mat(bt, 0.15, 0.3)
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			VRBuild.quad(bn, Vector2(0.104, 0.104), Vector3.ZERO, bm)
		_btn_nodes[k] = bn
	var l := OmniLight3D.new()
	l.position = Vector3(0, 1.4, 0.8)
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
		tw.tween_property(n, "position:z", FRONT_Z - 0.004, 0.04)
		tw.tween_property(n, "position:z", FRONT_Z + 0.006, 0.12)
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
	if _neon != null:
		var k := 0.75 + 0.25 * sin(_t * (3.0 if playing else 1.0)) if playing else 0.35
		_neon.albedo_color = Color(k, k, k, 1.0)
