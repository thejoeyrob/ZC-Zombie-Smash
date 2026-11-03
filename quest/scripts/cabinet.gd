class_name Cabinet
extends Node3D
## An upright arcade machine. Local axes: x right, y up, +z toward the player.
## The body is cut to the outline of its side-art picture, so the artwork covers the whole side of the machine.
## Every machine has a stick, three buttons and a LOCK button; the one the player stands at shows the live game.

const PANEL_TILT := 0.23              # radians: control panel rises toward the back
const STICK_LOCAL := Vector3(-0.19, 0.0, 0.03)
const STICK_LENGTH := 0.125           # pivot to ball centre
const BALL_RADIUS := 0.029
const MAX_TILT := 0.40                # radians the stick can lean
const BUTTONS := {
	"fire": {"pos": Vector3(0.205, 0.0, 0.02), "radius": 0.052},
	"grenade": {"pos": Vector3(0.025, 0.0, 0.06), "radius": 0.03},
	# these two sit on the front of the lower cabinet either side of the coin door (their pos is (x, 0, -height) in that face's frame)
	"menu": {"pos": Vector3(0.155, 0.0, -0.56), "radius": 0.02, "front": true},
}

var panel: Node3D
var front_panel: Node3D      # frame of the front face of the lower body: local +y points out toward the player
var stick_pivot: Node3D
var ball: MeshInstance3D
var ball_mat: StandardMaterial3D
var screen_mat: StandardMaterial3D
var caps := {}            # name -> Node3D (a button's moving cap)
var pressed := {}         # name -> bool
var neon: Array = []
var theme_color := Color(0.1, 0.85, 0.35)
var side_art: Texture2D        # picture for the outside of both sides
var bezel_id := ""            # which boss's ornate screen frame this machine wears
var profile: Dictionary = {}   # outline of that picture (see CabProfile)
var attract_tex: Texture2D     # what the screen shows when nobody is playing
var lit := false               # a light that makes the controls glow (only the machine in use needs one)
var lamp_red: StandardMaterial3D
var lamp_green: StandardMaterial3D
var lock_cap_mat: StandardMaterial3D
var back_z := -0.79
var front_z := 0.02
var monitor_z := -0.30
var deck_front_z := 0.28
var deck_front_y := 0.82
var mon_node: Node3D
var _light: OmniLight3D


func build(screen_tex: Texture2D, marquee_tex: Texture2D, body_color: Color, trim_color: Color, interactive: bool, marquee_text := "", marquee_color := Color(0.1, 0.1, 0.3), detail := true) -> void:
	detail = detail or interactive
	theme_color = trim_color
	attract_tex = screen_tex
	var body := VRBuild.mat(body_color, 0.55, 0.1)
	var dark := VRBuild.mat(Color(0.015, 0.015, 0.02), 0.6)
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trim := VRBuild.mat(trim_color, 0.3, 0.0, 2.0)
	neon.append(trim)
	var poly: Array = profile.get("poly", [])
	var spire_z := -0.62
	if not poly.is_empty():
		back_z = CabProfile.z_of(float(profile.get("back_body", 0.05))) + 0.01
		front_z = CabProfile.z_of(float(profile.get("front_body", 0.9))) - 0.005
		# the control deck's front lip sits at the furthest point the side panels reach at deck height, never beyond it
		var bulge_v := 0.60
		var bulge_u := 0.0
		for i in range(40, 80):
			var vv := float(i) / 100.0
			var uu: float = CabProfile.edges_at(poly, vv).y
			if uu > bulge_u + 0.001:
				bulge_u = uu
				bulge_v = vv
		var deck_y := clampf(CabProfile.y_of(bulge_v), 0.78, 0.92)
		var vf := 1.0 - deck_y / CabProfile.H_M
		var reach := 1.0
		for k in range(-3, 4):
			reach = minf(reach, CabProfile.edges_at(poly, vf + float(k) * 0.01).y)
		deck_front_z = CabProfile.z_of(minf(reach, float(profile.get("front_body", 0.9)) + 0.04)) - 0.012
		deck_front_y = deck_y
		front_z = minf(front_z, deck_front_z)
		_build_sides(poly, body)
	else:
		front_z = 0.02
		back_z = -0.79
		deck_front_z = front_z + 0.3
		deck_front_y = 0.95
		var profile_pts := PackedVector2Array([
			Vector2(-0.80, 0.0), Vector2(0.02, 0.0), Vector2(0.02, 0.97), Vector2(0.30, 1.0), Vector2(0.30, 1.04),
			Vector2(-0.02, 1.10), Vector2(-0.10, 1.60), Vector2(-0.04, 1.84), Vector2(-0.04, 1.96), Vector2(-0.70, 1.96), Vector2(-0.80, 1.84)])
		VRBuild.side_panel(self, profile_pts, -0.335, 0.04, body)
		VRBuild.side_panel(self, profile_pts, 0.335, 0.04, body)
	var mid_z := (front_z + back_z) / 2.0
	var depth := front_z - back_z
	# lower body: the front is painted in the game's colour, with a chrome coin door and kick plate and glowing edge trim
	var chrome := VRBuild.pbr("metal", Color(1, 1, 1), Vector2(1, 1), 0.8)    # brushed steel
	var black_tex := VRBuild.pbr("plate-blue", Color(0.34, 0.34, 0.42), Vector2(1.0, 1.4), 0.9)    # worn, dark blue steel plate
	var front_paint := black_tex
	var body_h := deck_front_y - 0.05          # the lower body stops just under the control deck's front lip
	VRBuild.box(self, Vector3(0.67, body_h, 0.03), Vector3(0, body_h / 2.0, front_z - 0.012), front_paint)
	VRBuild.box(self, Vector3(0.65, 0.12, 0.036), Vector3(0, 0.07, front_z - 0.004), black_tex)             # kick plate
	VRBuild.box(self, Vector3(0.65, 0.02, 0.04), Vector3(0, 0.14, front_z - 0.002), dark)
	if detail:
		# the coin slot: a flat black door with an orange, lit coin insert
		var orange := VRBuild.mat(Color(1.0, 0.5, 0.05), 0.3, 0.0, 3.2)
		VRBuild.box(self, Vector3(0.12, 0.2, 0.01), Vector3(0, 0.6, front_z + 0.008), black_tex)
		VRBuild.box(self, Vector3(0.062, 0.115, 0.006), Vector3(0, 0.625, front_z + 0.015), orange)         # glowing bezel
		VRBuild.box(self, Vector3(0.012, 0.07, 0.008), Vector3(0, 0.63, front_z + 0.02), dark)             # the slot itself
		VRBuild.box(self, Vector3(0.04, 0.012, 0.008), Vector3(0, 0.555, front_z + 0.016), orange)         # lit tab under it
		var coin_light := OmniLight3D.new()
		coin_light.position = Vector3(0, 0.62, front_z + 0.12)
		coin_light.light_color = Color(1.0, 0.55, 0.15)
		coin_light.light_energy = 0.25
		coin_light.omni_range = 0.6
		add_child(coin_light)
		for sx in [-0.325, 0.325]:       # glowing trim down both front edges
			VRBuild.box(self, Vector3(0.016, body_h, 0.018), Vector3(sx, body_h / 2.0, front_z - 0.004), trim)
	VRBuild.box(self, Vector3(0.67, 1.9, 0.03), Vector3(0, 0.95, back_z + 0.015), black_tex)             # the back board: flat black
	VRBuild.box(self, Vector3(0.67, 0.03, depth), Vector3(0, 0.015, mid_z), dark)
	# control panel: one flat, textured painted surface in the theme colour, edged in chrome
	panel = Node3D.new()
	# placed so that its front lip lands exactly on (deck_front_z, deck_front_y)
	panel.position = Vector3(0, deck_front_y + 0.0553, deck_front_z - 0.183)
	panel.rotation = Vector3(PANEL_TILT, 0, 0)
	add_child(panel)
	var panel_col := trim_color.darkened(0.48)
	var pm := VRBuild.pbr("leather-black", Color(1.4, 1.4, 1.4), Vector2(1.6, 1.0), 1.0)       # the control deck is wrapped in black leather
	VRBuild.box(panel, Vector3(0.66, 0.04, 0.34), Vector3(0, -0.02, 0), pm)
	VRBuild.box(panel, Vector3(0.68, 0.026, 0.022), Vector3(0, -0.012, 0.18), chrome)                # front lip
	VRBuild.box(panel, Vector3(0.016, 0.026, 0.34), Vector3(-0.337, -0.012, 0.0), chrome)           # side lips
	VRBuild.box(panel, Vector3(0.016, 0.026, 0.34), Vector3(0.337, -0.012, 0.0), chrome)
	VRBuild.box(panel, Vector3(0.68, 0.02, 0.012), Vector3(0, -0.012, -0.176), dark)                 # joint with the monitor
	# underside of the deck so it reads as a solid shelf, closed at the sides by the cabinet walls
	VRBuild.box(panel, Vector3(0.66, 0.12, 0.3), Vector3(0, -0.08, -0.02), front_paint)
	# monitor: bezel, glass
	var mon := Node3D.new()
	var rear_z := panel.position.z - 0.168
	var rear_y := panel.position.y + 0.03
	monitor_z = rear_z - 0.166
	mon.position = Vector3(0, rear_y + 0.377, monitor_z)
	mon.rotation = Vector3(-0.17, 0, 0)
	mon_node = mon
	add_child(mon)
	VRBuild.box(mon, Vector3(0.66, 0.8, 0.2), Vector3(0, 0, 0), dark)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = screen_tex
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.35, 1.35, 1.35)       # a lit tube: brighter than a plain picture
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	screen_mat = sm
	var screen_quad := VRBuild.quad(mon, Vector2(0.53, 0.64), Vector3(0, 0.0, 0.1005), sm)
	screen_quad.name = "ScreenQuad"
	# the black border round the picture, with a bevel, like the glass of a real tube
	var black := VRBuild.mat(Color(0.004, 0.004, 0.006), 0.22, 0.1)
	for off in [Vector3(0, 0.34, 0.1), Vector3(0, -0.34, 0.1)]:
		VRBuild.box(mon, Vector3(0.66, 0.12, 0.012), off, black)
	for off in [Vector3(-0.31, 0, 0.1), Vector3(0.31, 0, 0.1)]:
		VRBuild.box(mon, Vector3(0.06, 0.8, 0.012), off, black)
	VRBuild.box(mon, Vector3(0.58, 0.012, 0.02), Vector3(0, 0.322, 0.098), black, Vector3(0.5, 0, 0))
	VRBuild.box(mon, Vector3(0.58, 0.012, 0.02), Vector3(0, -0.322, 0.098), black, Vector3(-0.5, 0, 0))
	VRBuild.box(mon, Vector3(0.012, 0.64, 0.02), Vector3(-0.268, 0, 0.098), black, Vector3(0, 0.5, 0))
	VRBuild.box(mon, Vector3(0.012, 0.64, 0.02), Vector3(0.268, 0, 0.098), black, Vector3(0, -0.5, 0))
	var bz = load("res://assets/art/bezel-%s.jpg" % bezel_id) if bezel_id != "" else null
	var bzd := _bezel_data()
	if bz != null and bzd.has(bezel_id):
		var d: Dictionary = bzd[bezel_id]
		var w: Array = d.win
		var win_uv := Rect2(float(w[0]) / float(d.w), float(w[1]) / float(d.h), float(w[2] - w[0]) / float(d.w), float(w[3] - w[1]) / float(d.h))
		var bm := VRBuild.tex_mat(bz, 0.12, 0.45)
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		VRBuild.frame9(mon, bz, win_uv, Vector2(0.66, 0.80), Vector2(0.53, 0.64), Vector3(0, 0, 0.1125), bm)
	# the glass over all of it: a faint scanline mesh and a soft diagonal reflection
	var glass := StandardMaterial3D.new()
	glass.albedo_texture = VRBuild.scanline_texture()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.uv1_scale = Vector3(1, 220, 1)
	glass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	VRBuild.quad(mon, Vector2(0.53, 0.64), Vector3(0, 0.0, 0.1012), glass)
	var sheen := StandardMaterial3D.new()
	sheen.albedo_texture = _sheen()
	sheen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sheen.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sheen.cull_mode = BaseMaterial3D.CULL_DISABLED
	VRBuild.quad(mon, Vector2(0.64, 0.78), Vector3(0, 0.0, 0.1065), sheen)
	VRBuild.box(mon, Vector3(0.68, 0.016, 0.014), Vector3(0, 0.398, 0.103), chrome)
	VRBuild.box(mon, Vector3(0.68, 0.016, 0.014), Vector3(0, -0.398, 0.103), chrome)
	# marquee: the header bar sits in the tall part of the side outline, its face flush with the front of that part
	var marq := Node3D.new()
	marq.rotation = Vector3(-0.1, 0, 0)
	marq.position = Vector3(0, mon.position.y + 0.394 + 0.125, monitor_z + 0.03 - 0.06)
	# the header is the front-most thing at the top: its picture stands clear of the screen glass, never behind it
	marq.position = Vector3(0, mon.position.y + 0.394 + 0.125 + 0.02, monitor_z + 0.1 + 0.05 - 0.0605)
	add_child(marq)
	VRBuild.box(marq, Vector3(0.67, 0.22, 0.12), Vector3.ZERO, dark)
	if marquee_tex != null:
		VRBuild.quad(marq, Vector2(0.64, 0.2), Vector3(0, 0, 0.0605), VRBuild.tex_mat(marquee_tex, 1.0, 0.5, true))
	else:
		VRBuild.quad(marq, Vector2(0.64, 0.2), Vector3(0, 0, 0.0605), VRBuild.unshaded(marquee_color))
		VRBuild.label(marq, marquee_text, 0.075, Vector3(0, 0, 0.062), Color(1, 1, 1), Vector3.ZERO, 6)
	if interactive:
		front_panel = Node3D.new()
		front_panel.position = Vector3(0, 0, front_z + 0.004)
		front_panel.rotation = Vector3(PI / 2, 0, 0)
		add_child(front_panel)
		_build_controls()
		_build_decals()
		set_lit(lit)
	for n in [self, panel, mon, marq, front_panel]:
		VRBuild.merge_static(n)


static var _decal_mats := {}


func _decal(parent: Node3D, file: String, size: float, pos: Vector3, rot := Vector3.ZERO, roll := 0.0) -> void:
	if not _decal_mats.has(file):
		var t = load("res://assets/art/%s" % file)
		if t == null:
			return
		var m := VRBuild.tex_mat(t, 0.0, 0.45)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		_decal_mats[file] = m
	var q := VRBuild.quad(parent, Vector2(size, size), pos, _decal_mats[file], rot)
	q.rotate_object_local(Vector3(0, 0, 1), roll)


## Instruction stickers: just the word, die-cut with a white border, sitting on the far side of each control (never under the hand).
func _build_decals() -> void:
	var flat := Vector3(-PI / 2, 0, 0)
	_word(panel, "move", 0.13, Vector3(-0.19, 0.0015, -0.1), flat)
	_word(panel, "fire", 0.11, Vector3(0.205, 0.0015, -0.085), flat)
	_word(panel, "grenade", 0.12, Vector3(0.025, 0.0015, -0.04), flat)
	var up := 0.6 + 0.07
	_word(self, "menu", 0.095, Vector3(0.155, up, front_z + 0.0075), Vector3.ZERO)


func _word(parent: Node3D, name: String, width: float, pos: Vector3, rot: Vector3) -> void:
	var file := "word-%s.png" % name
	if not _decal_mats.has(file):
		var t = load("res://assets/art/%s" % file)
		if t == null:
			return
		var m := VRBuild.tex_mat(t, 0.0, 0.45)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		_decal_mats[file] = m
		_decal_aspect[file] = float(t.get_height()) / float(t.get_width())
	VRBuild.quad(parent, Vector2(width, width * float(_decal_aspect[file])), pos, _decal_mats[file], rot)


static var _decal_aspect := {}


static var _bezel_json := {}


static func _bezel_data() -> Dictionary:
	if _bezel_json.is_empty():
		var f := FileAccess.open("res://data/bezels.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_bezel_json = d
	return _bezel_json


func _build_sides(poly: Array, body: Material) -> void:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for p in poly:
		pts.append(Vector2(CabProfile.z_of(float(p[0])), CabProfile.y_of(float(p[1]))))
		uvs.append(Vector2(float(p[0]), float(p[1])))
	var picture: Material
	if side_art != null:
		var pm := VRBuild.tex_mat(side_art, 0.18, 0.55)
		pm.cull_mode = BaseMaterial3D.CULL_DISABLED
		picture = pm
	else:
		picture = body
	var dark := VRBuild.mat(Color(0.03, 0.03, 0.05), 0.7)
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	# the picture reads the right way round from outside on the left side; it is mirrored on the right
	VRBuild.picture_slab(self, pts, uvs, -0.335, 0.04, -1.0, picture, dark, false)
	VRBuild.picture_slab(self, pts, uvs, 0.335, 0.04, 1.0, picture, dark, true)


func _sheen() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(0.8, 0.9, 1.0, 0.05), Color(1, 1, 1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.28, 0.4, 0.62, 0.72, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(1.0, 1.0)
	return t


func set_lit(on: bool) -> void:
	lit = on
	if _light == null:
		_light = OmniLight3D.new()
		_light.position = Vector3(0, 1.45, front_z + 0.25)
		_light.light_color = Color(0.7, 0.95, 0.8)
		_light.omni_range = 2.0
		add_child(_light)
	_light.light_energy = 0.9 if on else 0.0
	_light.visible = on


## Show the live game (a texture from the game screen) or go back to the attract picture.
func set_live(tex: Texture2D) -> void:
	screen_mat.albedo_texture = tex if tex != null else attract_tex


func stand_world() -> Vector3:
	var p := to_global(Vector3(0, 0, panel.position.z + 0.38))
	return Vector3(p.x, 0.0, p.z)


func look_world() -> Vector3:
	return to_global(Vector3(0, 1.4, monitor_z))


func _build_controls() -> void:
	var chrome := VRBuild.pbr("metal", Color(1, 1, 1), Vector2(1, 1), 0.8)
	var brass := VRBuild.mat(Color(0.8, 0.6, 0.22), 0.25, 0.9)
	var black := VRBuild.mat(Color(0.012, 0.012, 0.016), 0.35, 0.2)
	var rubber := VRBuild.mat(Color(0.02, 0.02, 0.025), 0.9)
	var steel := VRBuild.mat(Color(0.88, 0.89, 0.94), 0.15, 0.9)
	# the joystick: a square steel mounting plate with four screws, a chrome dish, a rubber boot, a polished shaft and a ball
	VRBuild.box(panel, Vector3(0.15, 0.004, 0.15), STICK_LOCAL + Vector3(0, 0.002, 0), steel)
	for dx in [-0.062, 0.062]:
		for dz in [-0.062, 0.062]:
			VRBuild.cylinder(panel, 0.007, 0.006, STICK_LOCAL + Vector3(dx, 0.006, dz), black, 0.006, Vector3.ZERO, 6)
			VRBuild.cylinder(panel, 0.0035, 0.007, STICK_LOCAL + Vector3(dx, 0.0065, dz), chrome, -1.0, Vector3.ZERO, 6)
	VRBuild.cylinder(panel, 0.062, 0.008, STICK_LOCAL + Vector3(0, 0.008, 0), brass, 0.058, Vector3.ZERO, 44)
	VRBuild.cylinder(panel, 0.052, 0.012, STICK_LOCAL + Vector3(0, 0.011, 0), chrome, 0.048, Vector3.ZERO, 44)
	VRBuild.cylinder(panel, 0.044, 0.012, STICK_LOCAL + Vector3(0, 0.012, 0), black, -1.0, Vector3.ZERO, 44)
	VRBuild.cylinder(panel, 0.038, 0.034, STICK_LOCAL + Vector3(0, 0.03, 0), rubber, 0.012, Vector3.ZERO, 28)         # dust boot
	for k in range(4):
		VRBuild.cylinder(panel, 0.034 - k * 0.0045, 0.0035, STICK_LOCAL + Vector3(0, 0.016 + k * 0.0075, 0), VRBuild.mat(Color(0.05, 0.05, 0.06), 0.8), -1.0, Vector3.ZERO, 24)   # its ribs
	stick_pivot = Node3D.new()
	stick_pivot.position = STICK_LOCAL + Vector3(0, 0.03, 0)
	panel.add_child(stick_pivot)
	VRBuild.cylinder(stick_pivot, 0.007, STICK_LENGTH, Vector3(0, STICK_LENGTH / 2.0, 0), steel, -1.0, Vector3.ZERO, 14)
	VRBuild.cylinder(stick_pivot, 0.016, 0.005, Vector3(0, 0.022, 0), chrome, -1.0, Vector3.ZERO, 20)
	VRBuild.cylinder(stick_pivot, 0.011, 0.012, Vector3(0, STICK_LENGTH - 0.026, 0), black, 0.009, Vector3.ZERO, 16)    # the ball's collar
	ball_mat = VRBuild.pbr("leather-cream", Color("#f5b800"), Vector2(1.5, 1.5), 0.7)      # a leather-covered topper, any colour
	ball_mat.rim_enabled = true
	ball_mat.rim = 0.3
	ball_mat.clearcoat_enabled = true
	ball_mat.clearcoat = 1.0
	ball_mat.clearcoat_roughness = 0.05
	ball = VRBuild.sphere(stick_pivot, BALL_RADIUS, Vector3(0, STICK_LENGTH, 0), ball_mat, 40)
	# buttons: a black bezel with a brass ring, a recessed dish, a lit inner lamp under a glossy domed cap
	var cfg := {
		"fire": [Color("#e3262a"), 0.03],
		"grenade": [Color("#1d6fe0"), 0.02],
		"menu": [Color("#d8d8d8"), 0.014],
		"lock": [Color("#e3262a"), 0.016],
	}
	for k in BUTTONS:
		var b: Dictionary = BUTTONS[k]
		var r: float = b.radius
		var col: Color = cfg[k][0]
		var panel: Node3D = front_panel if b.get("front", false) else self.panel
		VRBuild.cylinder(panel, r + 0.016, 0.003, b.pos + Vector3(0, 0.0015, 0), black, -1.0, Vector3.ZERO, 40)         # cut-out in the deck
		VRBuild.cylinder(panel, r + 0.012, 0.008, b.pos + Vector3(0, 0.005, 0), brass, r + 0.01, Vector3.ZERO, 40)        # brass ring
		VRBuild.cylinder(panel, r + 0.006, 0.012, b.pos + Vector3(0, 0.008, 0), chrome, r + 0.004, Vector3.ZERO, 40)      # chrome collar
		VRBuild.cylinder(panel, r + 0.001, 0.014, b.pos + Vector3(0, 0.0085, 0), black, -1.0, Vector3.ZERO, 40)           # dark well
		VRBuild.cylinder(panel, r * 0.97, 0.002, b.pos + Vector3(0, 0.0125, 0), VRBuild.mat(col.darkened(0.2), 0.3, 0.0, 1.2, col), -1.0, Vector3.ZERO, 36)  # the lamp under the cap
		var cap_mat := VRBuild.mat(col.lightened(0.05), 0.08, 0.0, 0.5, col)
		if k == "fire":
			var ft = load("res://assets/art/fire-cap.jpg")
			if ft != null:
				cap_mat.albedo_texture = ft
				cap_mat.albedo_color = Color.WHITE
		cap_mat.rim_enabled = true
		cap_mat.rim = 0.4
		cap_mat.clearcoat_enabled = true
		cap_mat.clearcoat = 1.0
		cap_mat.clearcoat_roughness = 0.04
		var cap := Node3D.new()
		cap.position = b.pos + Vector3(0, 0.013, 0)
		panel.add_child(cap)
		VRBuild.cylinder(cap, r * 0.95, 0.011, Vector3(0, 0.0055, 0), cap_mat, r * 0.95, Vector3.ZERO, 40)
		var dome := VRBuild.sphere(cap, r * 0.95, Vector3(0, 0.011, 0), cap_mat, 40)
		dome.scale = Vector3(1.0, 0.42, 1.0)
		VRBuild.sphere(cap, r * 0.22, Vector3(-r * 0.32, 0.011 + r * 0.33, -r * 0.32), VRBuild.mat(Color(1, 1, 1), 0.1, 0.0, 1.8), 10)    # the glint of a window
		if k == "lock":
			lock_cap_mat = cap_mat
		caps[k] = cap
		pressed[k] = false


## Traffic light: red = locked to the machine (in play), green = free to move about the room. It sits in the left bezel of the monitor.
func _build_traffic_light() -> void:
	var housing := VRBuild.mat(Color(0.02, 0.02, 0.03), 0.4, 0.3)
	var holder := Node3D.new()
	holder.position = Vector3(-0.3, 0.0, 0.109)
	mon_node.add_child(holder)
	VRBuild.box(holder, Vector3(0.054, 0.17, 0.014), Vector3.ZERO, housing)
	lamp_red = VRBuild.mat(Color(0.35, 0.02, 0.02), 0.3, 0.0, 0.0)
	lamp_green = VRBuild.mat(Color(0.02, 0.3, 0.05), 0.3, 0.0, 0.0)
	VRBuild.cylinder(holder, 0.021, 0.012, Vector3(0, 0.045, 0.008), lamp_red, -1.0, Vector3(PI / 2, 0, 0), 24)
	VRBuild.cylinder(holder, 0.021, 0.012, Vector3(0, -0.045, 0.008), lamp_green, -1.0, Vector3(PI / 2, 0, 0), 24)
	set_lock_light(true)


func set_lock_light(locked: bool) -> void:
	if lamp_red == null:
		return
	for pair in [[lamp_red, locked, Color(1.0, 0.1, 0.08)], [lamp_green, not locked, Color(0.15, 1.0, 0.3)]]:
		var m: StandardMaterial3D = pair[0]
		m.emission_enabled = pair[1]
		m.emission = pair[2]
		m.emission_energy_multiplier = 3.0
		m.albedo_color = pair[2] if pair[1] else pair[2].darkened(0.85)
	if lock_cap_mat != null:
		lock_cap_mat.albedo_color = Color("#e3262a") if locked else Color("#22c24a")
		lock_cap_mat.emission_enabled = true
		lock_cap_mat.emission = lock_cap_mat.albedo_color


# ---- solid parts, so hands cannot pass through the machine --------------------------------------
## Pushes a sphere (world position, radius) out of the cabinet's solid volumes; returns the corrected world position.
func constrain(world: Vector3, radius: float) -> Vector3:
	var p := to_local(world)
	if absf(p.x) > 1.0 or p.z < back_z - 1.0 or p.z > front_z + 1.0 or p.y > 2.4:
		return world
	var zc := (back_z + front_z) / 2.0
	var zh := (front_z - back_z) / 2.0
	var mon_front := monitor_z + 0.1
	var boxes := [
		[Vector3(0, (deck_front_y - 0.05) / 2.0, zc), Vector3(0.32, (deck_front_y - 0.05) / 2.0, zh)],        # lower body below the control deck
		[Vector3(0, 1.38, (back_z + mon_front) / 2.0), Vector3(0.32, 0.44, (mon_front - back_z) / 2.0)],  # monitor block
		[Vector3(-0.335, 0.52, zc), Vector3(0.022, 0.52, zh)],                                           # left side
		[Vector3(0.335, 0.52, zc), Vector3(0.022, 0.52, zh)],                                            # right side
		[Vector3(0, 1.88, (back_z + mon_front) / 2.0), Vector3(0.34, 0.12, (mon_front - back_z) / 2.0)], # marquee and top
	]
	for b in boxes:
		p = _push_box(p, b[0], b[1] + Vector3.ONE * radius)
	var q := panel.transform.affine_inverse() * p
	var inside := absf(q.x) < 0.33 + radius and absf(q.z) < 0.17 + radius and q.y < radius and q.y > -0.05 - radius
	if inside:
		q.y = radius
		p = panel.transform * q
	return to_global(p)


func _push_box(p: Vector3, c: Vector3, half: Vector3) -> Vector3:
	var d := p - c
	if absf(d.x) >= half.x or absf(d.y) >= half.y or absf(d.z) >= half.z:
		return p
	var pen := Vector3(half.x - absf(d.x), half.y - absf(d.y), half.z - absf(d.z))
	var out := p
	if pen.z <= pen.x and pen.z <= pen.y and d.z > 0.0:
		out.z = c.z + half.z
	elif pen.y <= pen.x and pen.y <= pen.z and d.y > 0.0:
		out.y = c.y + half.y
	elif pen.x <= pen.y and pen.x <= pen.z:
		out.x = c.x + half.x * signf(d.x)
	else:
		out.z = c.z + half.z
	return out


func set_topper_color(c: Color) -> void:
	if ball_mat != null:
		ball_mat.albedo_color = c


func ball_world_position() -> Vector3:
	return ball.global_position


## Converts a world position into the panel's local space.
func to_panel(world: Vector3) -> Vector3:
	return panel.global_transform.affine_inverse() * world


## Leans the stick. roll > 0 leans right (+x), pitch > 0 leans toward the player (+z).
func set_stick(roll: float, pitch: float) -> void:
	stick_pivot.rotation = Vector3(pitch, 0.0, -roll)


func button_pressed_visual(name: String, down: bool) -> void:
	if not caps.has(name) or pressed[name] == down:
		return
	pressed[name] = down
	var cap: Node3D = caps[name]
	cap.position.y += -0.011 if down else 0.011


## Which button (if any) is under a point given in panel-local coordinates. Returns "" when none.
func button_at(local: Vector3, reach_above := 0.05) -> String:
	var in_cab := panel.transform * local
	for k in BUTTONS:
		var b: Dictionary = BUTTONS[k]
		var q := local
		var reach := reach_above
		if b.get("front", false):
			if front_panel == null:
				continue
			q = front_panel.transform.affine_inverse() * in_cab
			reach = minf(reach_above, 0.04)
		var d := Vector2(q.x - b.pos.x, q.z - b.pos.z).length()
		if d <= maxf(float(b.radius), 0.04) + 0.015 and q.y > -0.03 and q.y < reach:
			return k
	return ""
