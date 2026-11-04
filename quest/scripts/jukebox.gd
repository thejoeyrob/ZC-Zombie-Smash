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
	var neon_tex := _art("jukebox-neon.png")
	var size := Vector2(0.9, 1.95)
	var cy := 0.975
	# a solid body: the arch outline (straight sides, a half-round top, a little foot) extruded 0.5 m deep, in chrome and red enamel
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var hw := size.x / 2.0
	var arch_r := hw
	var arch_c := size.y - arch_r                  # the centre of the half-round top
	pts.append(Vector2(-hw, 0.0)); uvs.append(Vector2(0.0, 1.0))
	pts.append(Vector2(-hw, arch_c)); uvs.append(Vector2(0.0, 1.0 - arch_c / size.y))
	for i in range(1, 24):
		var a2 := PI - PI * float(i) / 24.0
		var q := Vector2(cos(a2) * arch_r, arch_c + sin(a2) * arch_r)
		pts.append(q); uvs.append(Vector2((q.x + hw) / size.x, 1.0 - q.y / size.y))
	pts.append(Vector2(hw, arch_c)); uvs.append(Vector2(1.0, 1.0 - arch_c / size.y))
	pts.append(Vector2(hw, 0.0)); uvs.append(Vector2(1.0, 1.0))
	var enamel := VRBuild.pbr("leather-red", Color(0.9, 0.55, 0.6), Vector2(1.2, 2.0), 1.4)
	enamel.metallic = 0.25
	enamel.roughness = 0.35
	var chrome := VRBuild.pbr("metal", Color(1, 1, 1), Vector2(1, 2), 0.9)
	chrome.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := Node3D.new()
	body.position = Vector3(0, 0, FRONT_Z - 0.008)
	body.rotation.y = -PI / 2.0
	add_child(body)
	# slab thickness runs along local x, which the rotation turns into depth; two slabs back to back make it 0.5 m deep with the front face textured
	VRBuild.picture_slab(body, pts, uvs, -0.25, 0.5, -1.0, enamel, enamel, false)
	var rim := Node3D.new()
	add_child(rim)
	# chrome bands round the arch at the front, so the solid reads as a real cabinet and not a cut-out
	for i in range(0, 24):
		var a0 := PI - PI * float(i) / 24.0
		var a1 := PI - PI * float(i + 1) / 24.0
		var p0 := Vector3(cos(a0) * (arch_r + 0.012), arch_c + sin(a0) * (arch_r + 0.012), FRONT_Z + 0.004)
		var p1 := Vector3(cos(a1) * (arch_r + 0.012), arch_c + sin(a1) * (arch_r + 0.012), FRONT_Z + 0.004)
		var mid := (p0 + p1) / 2.0
		var seg := VRBuild.box(rim, Vector3(p0.distance_to(p1) + 0.004, 0.035, 0.03), mid, chrome, Vector3(0, 0, atan2(p1.y - p0.y, p1.x - p0.x)))
	for sx in [-1.0, 1.0]:
		VRBuild.box(rim, Vector3(0.035, arch_c, 0.03), Vector3(sx * (hw + 0.012), arch_c / 2.0, FRONT_Z + 0.004), chrome)
	# the front picture: only the arch is shown (transparent outside), standing just clear of the body
	if front_tex != null:
		var fm := VRBuild.tex_mat(front_tex, 0.18, 0.4)
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		fm.alpha_scissor_threshold = 0.5
		fm.metallic_specular = 0.6
		fm.normal_enabled = false
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
