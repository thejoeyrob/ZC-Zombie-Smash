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
	"fire": {"pos": Vector3(0.20, 0.0, 0.035), "radius": 0.036},
	"grenade": {"pos": Vector3(0.065, 0.0, -0.03), "radius": 0.031},
	"menu": {"pos": Vector3(0.0, 0.0, 0.115), "radius": 0.019},
	"lock": {"pos": Vector3(-0.285, 0.0, -0.115), "radius": 0.02},
}

var panel: Node3D
var stick_pivot: Node3D
var ball: MeshInstance3D
var ball_mat: StandardMaterial3D
var screen_mat: StandardMaterial3D
var caps := {}            # name -> MeshInstance3D
var pressed := {}         # name -> bool
var neon: Array = []
var theme_color := Color(0.1, 0.85, 0.35)
var side_art: Texture2D        # picture for the outside of both sides
var profile: Dictionary = {}   # outline of that picture (see CabProfile)
var attract_tex: Texture2D     # what the screen shows when nobody is playing
var lit := false               # a light that makes the controls glow (only the machine in use needs one)
var lamp_red: StandardMaterial3D
var lamp_green: StandardMaterial3D
var lock_cap_mat: StandardMaterial3D
var back_z := -0.79
var front_z := 0.02
var monitor_z := -0.30
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
		var e30 := CabProfile.edges_at(poly, 0.30)
		monitor_z = (CabProfile.z_of(e30.x) + CabProfile.z_of(e30.y)) / 2.0 - 0.06
		var e07 := CabProfile.edges_at(poly, 0.07)
		spire_z = (CabProfile.z_of(e07.x) + CabProfile.z_of(e07.y)) / 2.0
		_build_sides(poly, body)
	else:
		front_z = 0.02
		back_z = -0.79
		var profile_pts := PackedVector2Array([
			Vector2(-0.80, 0.0), Vector2(0.02, 0.0), Vector2(0.02, 0.97), Vector2(0.30, 1.0), Vector2(0.30, 1.04),
			Vector2(-0.02, 1.10), Vector2(-0.10, 1.60), Vector2(-0.04, 1.84), Vector2(-0.04, 1.96), Vector2(-0.70, 1.96), Vector2(-0.80, 1.84)])
		VRBuild.side_panel(self, profile_pts, -0.335, 0.04, body)
		VRBuild.side_panel(self, profile_pts, 0.335, 0.04, body)
	var mid_z := (front_z + back_z) / 2.0
	var depth := front_z - back_z
	# lower body: front, back and base
	VRBuild.box(self, Vector3(0.67, 0.95, 0.03), Vector3(0, 0.475, front_z - 0.012), body)
	VRBuild.box(self, Vector3(0.67, 0.16, 0.034), Vector3(0, 0.1, front_z - 0.004), dark)
	if detail:
		VRBuild.box(self, Vector3(0.28, 0.2, 0.034), Vector3(0, 0.62, front_z - 0.006), dark)
		VRBuild.box(self, Vector3(0.05, 0.012, 0.01), Vector3(-0.06, 0.66, front_z + 0.015), VRBuild.mat(Color(1, 0.8, 0.2), 0.4, 0.0, 1.5))
		VRBuild.box(self, Vector3(0.05, 0.012, 0.01), Vector3(0.06, 0.66, front_z + 0.015), VRBuild.mat(Color(1, 0.3, 0.2), 0.4, 0.0, 1.5))
		VRBuild.box(self, Vector3(0.6, 0.012, 0.012), Vector3(0, 0.98, front_z + 0.26), trim)
	VRBuild.box(self, Vector3(0.67, 1.9, 0.03), Vector3(0, 0.95, back_z + 0.015), body)
	VRBuild.box(self, Vector3(0.67, 0.03, depth), Vector3(0, 0.015, mid_z), dark)
	# control panel
	panel = Node3D.new()
	panel.position = Vector3(0, 1.035, front_z + 0.12)
	panel.rotation = Vector3(PANEL_TILT, 0, 0)
	add_child(panel)
	VRBuild.box(panel, Vector3(0.66, 0.04, 0.34), Vector3(0, -0.02, 0), VRBuild.mat(Color(0.07, 0.07, 0.1), 0.35, 0.2))
	var deco := VRBuild.mat(trim_color, 0.5, 0.0, 1.2)
	VRBuild.box(panel, Vector3(0.64, 0.004, 0.01), Vector3(0, 0.001, 0.15), deco)
	VRBuild.box(panel, Vector3(0.64, 0.004, 0.01), Vector3(0, 0.001, -0.15), deco)
	VRBuild.box(panel, Vector3(0.012, 0.004, 0.3), Vector3(-0.31, 0.001, 0), deco)
	VRBuild.box(panel, Vector3(0.012, 0.004, 0.3), Vector3(0.31, 0.001, 0), deco)
	# monitor: bezel, glass
	var mon := Node3D.new()
	mon.position = Vector3(0, 1.41, monitor_z)
	mon.rotation = Vector3(-0.17, 0, 0)
	add_child(mon)
	VRBuild.box(mon, Vector3(0.66, 0.8, 0.2), Vector3(0, 0, 0), dark)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = screen_tex
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	screen_mat = sm
	var screen_quad := VRBuild.quad(mon, Vector2(0.55, 0.66), Vector3(0, 0.0, 0.1005), sm)
	screen_quad.name = "ScreenQuad"
	if detail:
		var glass := StandardMaterial3D.new()
		glass.albedo_texture = VRBuild.scanline_texture()
		glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.uv1_scale = Vector3(1, 220, 1)
		glass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		VRBuild.quad(mon, Vector2(0.55, 0.66), Vector3(0, 0.0, 0.1015), glass)
		for off in [Vector3(0, 0.345, 0.099), Vector3(0, -0.345, 0.099)]:
			VRBuild.box(mon, Vector3(0.6, 0.03, 0.02), off, dark)
		for off in [Vector3(-0.29, 0, 0.099), Vector3(0.29, 0, 0.099)]:
			VRBuild.box(mon, Vector3(0.03, 0.7, 0.02), off, dark)
	# marquee on top
	var marq := Node3D.new()
	marq.position = Vector3(0, 1.855, spire_z + 0.1)
	marq.rotation = Vector3(-0.1, 0, 0)
	add_child(marq)
	VRBuild.box(marq, Vector3(0.67, 0.22, 0.12), Vector3.ZERO, dark)
	if marquee_tex != null:
		VRBuild.quad(marq, Vector2(0.64, 0.2), Vector3(0, 0, 0.0605), VRBuild.tex_mat(marquee_tex, 1.0, 0.5, true))
	else:
		VRBuild.quad(marq, Vector2(0.64, 0.2), Vector3(0, 0, 0.0605), VRBuild.unshaded(marquee_color))
		VRBuild.label(marq, marquee_text, 0.075, Vector3(0, 0, 0.062), Color(1, 1, 1), Vector3.ZERO, 6)
	if detail:
		for sx in [-0.26, 0.26]:
			VRBuild.box(self, Vector3(0.08, 0.1, 0.03), Vector3(sx, 1.68, monitor_z + 0.2), dark, Vector3(-0.1, 0, 0))
	if interactive:
		_build_controls()
		_build_traffic_light()
		VRBuild.label(panel, "LOCK", 0.026, Vector3(-0.285, 0.003, -0.07), Color(1, 1, 1, 0.8), Vector3(-PI / 2, 0, 0), 4)
		VRBuild.label(panel, "MENU", 0.035, Vector3(0.0, 0.003, 0.155), Color(1, 1, 1, 0.8), Vector3(-PI / 2, 0, 0), 4)
		VRBuild.label(panel, "FIRE", 0.05, Vector3(0.20, 0.003, 0.108), Color(1, 0.85, 0.85), Vector3(-PI / 2, 0, 0), 4)
		VRBuild.label(panel, "GRENADE", 0.032, Vector3(0.065, 0.003, 0.03), Color(0.8, 0.9, 1), Vector3(-PI / 2, 0, 0), 4)
		VRBuild.label(panel, "MOVE", 0.05, Vector3(-0.19, 0.003, 0.12), Color(1, 0.92, 0.7), Vector3(-PI / 2, 0, 0), 4)
		set_lit(lit)


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
	var plate := VRBuild.mat(Color(0.75, 0.78, 0.82), 0.25, 0.9)
	VRBuild.cylinder(panel, 0.055, 0.006, STICK_LOCAL + Vector3(0, 0.003, 0), plate, -1.0, Vector3.ZERO, 32)
	VRBuild.cylinder(panel, 0.04, 0.03, STICK_LOCAL + Vector3(0, 0.02, 0), VRBuild.mat(Color(0.02, 0.02, 0.025), 0.9), 0.016, Vector3.ZERO, 24)
	stick_pivot = Node3D.new()
	stick_pivot.position = STICK_LOCAL + Vector3(0, 0.03, 0)
	panel.add_child(stick_pivot)
	VRBuild.cylinder(stick_pivot, 0.0065, STICK_LENGTH, Vector3(0, STICK_LENGTH / 2.0, 0), VRBuild.mat(Color(0.85, 0.86, 0.9), 0.2, 1.0), -1.0, Vector3.ZERO, 12)
	ball_mat = VRBuild.mat(Color("#f5b800"), 0.28, 0.0)
	ball = VRBuild.sphere(stick_pivot, BALL_RADIUS, Vector3(0, STICK_LENGTH, 0), ball_mat, 24)
	var cfg := {
		"fire": [Color("#e3262a"), 0.022],
		"grenade": [Color("#1d6fe0"), 0.02],
		"menu": [Color("#d8d8d8"), 0.014],
		"lock": [Color("#e3262a"), 0.016],
	}
	for k in BUTTONS:
		var b: Dictionary = BUTTONS[k]
		var r: float = b.radius
		VRBuild.cylinder(panel, r + 0.007, 0.012, b.pos + Vector3(0, 0.004, 0), VRBuild.mat(Color(0.015, 0.015, 0.02), 0.5), -1.0, Vector3.ZERO, 32)
		var col: Color = cfg[k][0]
		var cap_mat := VRBuild.mat(col, 0.22, 0.0, 0.25)
		var cap := VRBuild.cylinder(panel, r, cfg[k][1], b.pos + Vector3(0, 0.012 + cfg[k][1] / 2.0, 0), cap_mat, r * 0.93, Vector3.ZERO, 32)
		if k == "lock":
			lock_cap_mat = cap_mat
		caps[k] = cap
		pressed[k] = false


## Traffic light: red = locked to the machine (in play), green = free to move about the room.
func _build_traffic_light() -> void:
	var housing := VRBuild.mat(Color(0.03, 0.03, 0.04), 0.5, 0.3)
	var holder := Node3D.new()
	holder.position = Vector3(-0.405, 1.42, monitor_z + 0.24)
	add_child(holder)
	VRBuild.box(holder, Vector3(0.07, 0.19, 0.05), Vector3.ZERO, housing)
	VRBuild.box(holder, Vector3(0.012, 0.06, 0.012), Vector3(0, -0.12, -0.005), housing)
	lamp_red = VRBuild.mat(Color(0.35, 0.02, 0.02), 0.3, 0.0, 0.0)
	lamp_green = VRBuild.mat(Color(0.02, 0.3, 0.05), 0.3, 0.0, 0.0)
	VRBuild.cylinder(holder, 0.026, 0.012, Vector3(0, 0.048, 0.027), lamp_red, -1.0, Vector3(PI / 2, 0, 0), 24)
	VRBuild.cylinder(holder, 0.026, 0.012, Vector3(0, -0.048, 0.027), lamp_green, -1.0, Vector3(PI / 2, 0, 0), 24)
	VRBuild.label(holder, "LOCK", 0.022, Vector3(0, 0.0, 0.0275), Color(1, 1, 1, 0.8), Vector3.ZERO, 3)
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
		[Vector3(0, 0.50, zc), Vector3(0.32, 0.50, zh)],                                                  # lower body below the panel
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
	var cap: MeshInstance3D = caps[name]
	cap.position.y += -0.011 if down else 0.011


## Which button (if any) is under a point given in panel-local coordinates. Returns "" when none.
func button_at(local: Vector3, reach_above := 0.05) -> String:
	for k in BUTTONS:
		var b: Dictionary = BUTTONS[k]
		var d := Vector2(local.x - b.pos.x, local.z - b.pos.z).length()
		if d <= float(b.radius) + 0.012 and local.y > -0.015 and local.y < reach_above:
			return k
	return ""
