class_name Cabinet
extends Node3D
## An upright arcade machine built from simple shapes. Local axes: x right, y up, +z toward the player.
## The playable one has a live screen, a joystick that can be grabbed and three pushable buttons.

const PANEL_TILT := 0.23              # radians: control panel rises toward the back
const STICK_LOCAL := Vector3(-0.19, 0.0, 0.03)
const STICK_LENGTH := 0.125           # pivot to ball centre
const BALL_RADIUS := 0.029
const MAX_TILT := 0.40                # radians the stick can lean
const BUTTONS := {
	"fire": {"pos": Vector3(0.20, 0.0, 0.035), "radius": 0.036},
	"grenade": {"pos": Vector3(0.065, 0.0, -0.03), "radius": 0.031},
	"menu": {"pos": Vector3(0.0, 0.0, 0.115), "radius": 0.019},
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


func build(screen_tex: Texture2D, marquee_tex: Texture2D, body_color: Color, trim_color: Color, interactive: bool, marquee_text := "", marquee_color := Color(0.1, 0.1, 0.3)) -> void:
	theme_color = trim_color
	var body := VRBuild.mat(body_color, 0.55, 0.1)
	var dark := VRBuild.mat(Color(0.015, 0.015, 0.02), 0.6)
	var trim := VRBuild.mat(trim_color, 0.3, 0.0, 2.0)
	neon.append(trim)
	# sides (profile in z,y)
	var profile := PackedVector2Array([
		Vector2(-0.80, 0.0), Vector2(0.02, 0.0), Vector2(0.02, 0.97), Vector2(0.30, 1.0), Vector2(0.30, 1.04),
		Vector2(-0.02, 1.10), Vector2(-0.10, 1.60), Vector2(-0.04, 1.84), Vector2(-0.04, 1.96), Vector2(-0.70, 1.96), Vector2(-0.80, 1.84)])
	VRBuild.side_panel(self, profile, -0.335, 0.04, body)
	VRBuild.side_panel(self, profile, 0.335, 0.04, body)
	# edge neon (t-molding) along the front of both sides
	for sx in [-0.357, 0.357]:
		VRBuild.box(self, Vector3(0.012, 0.012, 0.28), Vector3(sx, 1.02, 0.16), trim, Vector3(-PANEL_TILT * 0.4, 0, 0))
		VRBuild.box(self, Vector3(0.012, 0.95, 0.012), Vector3(sx, 0.485, 0.02), trim)
		VRBuild.box(self, Vector3(0.012, 0.012, 0.8), Vector3(sx, 1.945, -0.38), trim)
	# lower body: front, back, bottom kick plate, coin door
	VRBuild.box(self, Vector3(0.63, 0.95, 0.03), Vector3(0, 0.475, 0.005), body)
	VRBuild.box(self, Vector3(0.63, 0.16, 0.034), Vector3(0, 0.1, 0.012), dark)
	VRBuild.box(self, Vector3(0.28, 0.2, 0.034), Vector3(0, 0.62, 0.015), dark)
	VRBuild.box(self, Vector3(0.05, 0.012, 0.01), Vector3(-0.06, 0.66, 0.034), VRBuild.mat(Color(1, 0.8, 0.2), 0.4, 0.0, 1.5))
	VRBuild.box(self, Vector3(0.05, 0.012, 0.01), Vector3(0.06, 0.66, 0.034), VRBuild.mat(Color(1, 0.3, 0.2), 0.4, 0.0, 1.5))
	VRBuild.box(self, Vector3(0.63, 1.9, 0.03), Vector3(0, 0.95, -0.795), body)
	VRBuild.box(self, Vector3(0.63, 0.03, 0.78), Vector3(0, 0.015, -0.4), dark)
	# control panel
	panel = Node3D.new()
	panel.position = Vector3(0, 1.035, 0.14)
	panel.rotation = Vector3(PANEL_TILT, 0, 0)
	add_child(panel)
	VRBuild.box(panel, Vector3(0.66, 0.04, 0.34), Vector3(0, -0.02, 0), VRBuild.mat(Color(0.07, 0.07, 0.1), 0.35, 0.2))
	var deco := VRBuild.mat(trim_color, 0.5, 0.0, 1.2)
	VRBuild.box(panel, Vector3(0.64, 0.004, 0.01), Vector3(0, 0.001, 0.15), deco)
	VRBuild.box(panel, Vector3(0.64, 0.004, 0.01), Vector3(0, 0.001, -0.15), deco)
	VRBuild.box(panel, Vector3(0.012, 0.004, 0.3), Vector3(-0.31, 0.001, 0), deco)
	VRBuild.box(panel, Vector3(0.012, 0.004, 0.3), Vector3(0.31, 0.001, 0), deco)
	# monitor: bezel, glass, marquee
	var mon := Node3D.new()
	mon.position = Vector3(0, 1.41, -0.30)
	mon.rotation = Vector3(-0.17, 0, 0)
	add_child(mon)
	VRBuild.box(mon, Vector3(0.64, 0.78, 0.2), Vector3(0, 0, 0), dark)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = screen_tex
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	screen_mat = sm
	var screen_quad := VRBuild.quad(mon, Vector2(0.55, 0.66), Vector3(0, 0.0, 0.1005), sm)
	screen_quad.name = "ScreenQuad"
	var glass := StandardMaterial3D.new()
	glass.albedo_texture = VRBuild.scanline_texture()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.uv1_scale = Vector3(1, 220, 1)
	glass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	VRBuild.quad(mon, Vector2(0.55, 0.66), Vector3(0, 0.0, 0.1015), glass)
	# frame lip so the glass reads as a recessed tube
	for off in [Vector3(0, 0.345, 0.099), Vector3(0, -0.345, 0.099)]:
		VRBuild.box(mon, Vector3(0.6, 0.03, 0.02), off, dark)
	for off in [Vector3(-0.29, 0, 0.099), Vector3(0.29, 0, 0.099)]:
		VRBuild.box(mon, Vector3(0.03, 0.7, 0.02), off, dark)
	var marq := Node3D.new()
	marq.position = Vector3(0, 1.855, -0.36)
	marq.rotation = Vector3(-0.1, 0, 0)
	add_child(marq)
	VRBuild.box(marq, Vector3(0.64, 0.2, 0.1), Vector3.ZERO, dark)
	if marquee_tex != null:
		VRBuild.quad(marq, Vector2(0.6, 0.17), Vector3(0, 0, 0.0505), VRBuild.tex_mat(marquee_tex, 1.1, 0.5, true))
	else:
		VRBuild.quad(marq, Vector2(0.6, 0.17), Vector3(0, 0, 0.0505), VRBuild.unshaded(marquee_color))
		VRBuild.label(marq, marquee_text, 0.075, Vector3(0, 0, 0.052), Color(1, 1, 1), Vector3.ZERO, 6)
	# speakers under the marquee
	for sx in [-0.26, 0.26]:
		VRBuild.box(self, Vector3(0.08, 0.1, 0.03), Vector3(sx, 1.66, -0.11), dark, Vector3(-0.1, 0, 0))
	# glow under the panel and a soft light on the player's side
	VRBuild.box(self, Vector3(0.6, 0.012, 0.012), Vector3(0, 0.98, 0.28), trim)
	if interactive:
		_build_controls()
		var l := OmniLight3D.new()
		l.position = Vector3(0, 1.45, 0.25)
		l.light_color = Color(0.7, 0.95, 0.8)
		l.light_energy = 0.9
		l.omni_range = 2.2
		add_child(l)
		VRBuild.label(panel, "MENU", 0.035, Vector3(0.0, 0.003, 0.155), Color(1, 1, 1, 0.8), Vector3(-PI / 2, 0, 0), 4)
		VRBuild.label(panel, "FIRE", 0.05, Vector3(0.20, 0.003, 0.108), Color(1, 0.85, 0.85), Vector3(-PI / 2, 0, 0), 4)
		VRBuild.label(panel, "GRENADE", 0.032, Vector3(0.065, 0.003, 0.03), Color(0.8, 0.9, 1), Vector3(-PI / 2, 0, 0), 4)
		VRBuild.label(panel, "MOVE", 0.05, Vector3(-0.19, 0.003, 0.12), Color(1, 0.92, 0.7), Vector3(-PI / 2, 0, 0), 4)


func _build_controls() -> void:
	# joystick: chrome plate, black boot, shaft, ball
	var plate := VRBuild.mat(Color(0.75, 0.78, 0.82), 0.25, 0.9)
	VRBuild.cylinder(panel, 0.055, 0.006, STICK_LOCAL + Vector3(0, 0.003, 0), plate, -1.0, Vector3.ZERO, 32)
	VRBuild.cylinder(panel, 0.04, 0.03, STICK_LOCAL + Vector3(0, 0.02, 0), VRBuild.mat(Color(0.02, 0.02, 0.025), 0.9), 0.016, Vector3.ZERO, 24)
	stick_pivot = Node3D.new()
	stick_pivot.position = STICK_LOCAL + Vector3(0, 0.03, 0)
	panel.add_child(stick_pivot)
	VRBuild.cylinder(stick_pivot, 0.0065, STICK_LENGTH, Vector3(0, STICK_LENGTH / 2.0, 0), VRBuild.mat(Color(0.85, 0.86, 0.9), 0.2, 1.0), -1.0, Vector3.ZERO, 12)
	ball_mat = VRBuild.mat(Color("#f5b800"), 0.28, 0.0)
	ball = VRBuild.sphere(stick_pivot, BALL_RADIUS, Vector3(0, STICK_LENGTH, 0), ball_mat, 24)
	# buttons
	var cfg := {
		"fire": [Color("#e3262a"), 0.022],
		"grenade": [Color("#1d6fe0"), 0.02],
		"menu": [Color("#d8d8d8"), 0.014],
	}
	for k in BUTTONS:
		var b: Dictionary = BUTTONS[k]
		var r: float = b.radius
		VRBuild.cylinder(panel, r + 0.007, 0.012, b.pos + Vector3(0, 0.004, 0), VRBuild.mat(Color(0.015, 0.015, 0.02), 0.5), -1.0, Vector3.ZERO, 32)
		var col: Color = cfg[k][0]
		var cap := VRBuild.cylinder(panel, r, cfg[k][1], b.pos + Vector3(0, 0.012 + cfg[k][1] / 2.0, 0), VRBuild.mat(col, 0.22, 0.0, 0.25), r * 0.93, Vector3.ZERO, 32)
		caps[k] = cap
		pressed[k] = false


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
