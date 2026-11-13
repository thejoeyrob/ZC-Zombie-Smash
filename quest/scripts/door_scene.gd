class_name DoorScene
extends Node3D
## The double door in the front wall, and the night car park outside it: era cars, street lights, and now and then a zombie
## who shambles past the glass as a shadow.

signal scare(kind: String)

const SHAPES := ["zombie-normal.webp", "zombie-runner.webp", "zombie-helmet.webp", "zombie-toxic.webp", "zombie-armored.webp", "zombie-berserker.webp", "zombie-brute.webp", "zombie-titan.webp", "zombie-fuse.webp", "zombie-bulwark.webp", "boss-jordan-stage1.webp", "boss-debo-stage1.webp", "boss-fatamy-stage1.webp"]

var zombie: MeshInstance3D
var zombie_mat: StandardMaterial3D
var zombie_mat_sh: ShaderMaterial
var _kind := "dash"
var _speed := 6.0
var _stopped := false
var _burst := 0
var glow_mat: StandardMaterial3D
var lamp_energy: Array = []
var _timer := 14.0
var _walking := false
var _dir := 1.0
var _x := 0.0
var _pause := 0.0
var _time := 0.0
var front_z := 0.0


func build(root: Node3D, wall_z: float, half_w: float, height: float, wood: Material, paper: Material, font: Font) -> void:
	front_z = wall_z
	position = Vector3(0, 0, wall_z)
	root.add_child(self)
	var door_w := 2.1
	var door_h := 2.35
	var wall_w := half_w - door_w / 2.0
	# the wall either side of the door and above it (the black neon wall painting, floor to ceiling)
	for side in [-1, 1]:
		var cx: float = side * (door_w / 2.0 + wall_w / 2.0)
		var wmat: StandardMaterial3D = wood.duplicate()
		wmat.uv1_scale = Vector3(3.0 * wall_w / 2.4, 2.0 * height / 2.4, 1)      # a box lays its six faces out in a 3 x 2 sheet, so scale up to keep the brick the same size as the other walls
		wmat.texture_repeat = true
		VRBuild.box(self, Vector3(wall_w, height, 0.12), Vector3(cx, height / 2.0, 0), wmat)
		# the same low green skirting as the other three walls, stopping at the door frame
		var sk_w: float = wall_w - 0.1
		var sk_x: float = side * (door_w / 2.0 + 0.1 + sk_w / 2.0)
		VRBuild.box(self, Vector3(sk_w, 0.13, 0.05), Vector3(sk_x, 0.065, 0.085), VRBuild.pbr("wood-green", Color(0.95, 1.0, 0.95), Vector2(sk_w / 0.7, 0.34), 1.8))
		VRBuild.box(self, Vector3(sk_w, 0.025, 0.065), Vector3(sk_x, 0.1425, 0.0925), VRBuild.pbr("wood-green", Color(0.8, 0.9, 0.8), Vector2(sk_w / 0.7, 0.1), 1.8))
	var tmat: StandardMaterial3D = wood.duplicate()
	tmat.uv1_scale = Vector3(3.0 * door_w / 2.4, 2.0 * (height - door_h) / 2.4, 1)
	tmat.texture_repeat = true
	VRBuild.box(self, Vector3(door_w, height - door_h, 0.12), Vector3(0, door_h + (height - door_h) / 2.0, 0), tmat)
	# frame
	var frame := VRBuild.pbr("wood-navy", Color(0.45, 0.47, 0.55), Vector2(1.0, 2.0), 1.2)
	for sx in [-1, 1]:
		VRBuild.box(self, Vector3(0.12, door_h, 0.2), Vector3(sx * (door_w / 2.0 + 0.04), door_h / 2.0, 0), frame)
	VRBuild.box(self, Vector3(door_w + 0.24, 0.12, 0.2), Vector3(0, door_h + 0.04, 0), frame)
	VRBuild.box(self, Vector3(door_w + 0.2, 0.04, 0.4), Vector3(0, 0.01, 0.05), VRBuild.mat(Color(0.5, 0.45, 0.35), 0.4, 0.5, 0.2, Color(0.5, 0.45, 0.35)))   # brass threshold
	# two leaves, each with a glass window
	var leaf := VRBuild.pbr("wood-green", Color(0.72, 0.8, 0.72), Vector2(1.0, 1.4), 2.2)       # green washed wood door leaves
	var inset := VRBuild.pbr("wood-green", Color(0.5, 0.56, 0.5), Vector2(1.0, 1.0), 2.6)       # the recessed panels are a shade darker
	var brass := VRBuild.pbr("metal", Color(1, 1, 1), Vector2(1, 2), 0.9)                     # brushed metal push bars and handles
	var glass := _glass_material()
	for side in [-1, 1]:
		var cx: float = side * (door_w / 4.0)
		var lw := door_w / 2.0 - 0.01
		# the bottom of the door: a recessed panel held in the frame, with raised mouldings round it, and a brushed-metal kick plate
		VRBuild.box(self, Vector3(lw - 0.2, 0.62, 0.04), Vector3(cx, 0.52, 0), inset)
		VRBuild.box(self, Vector3(lw, 0.1, 0.07), Vector3(cx, 0.05, 0), leaf)
		VRBuild.box(self, Vector3(0.1, 0.9, 0.07), Vector3(cx - lw / 2.0 + 0.05, 0.45, 0), leaf)
		VRBuild.box(self, Vector3(0.1, 0.9, 0.07), Vector3(cx + lw / 2.0 - 0.05, 0.45, 0), leaf)
		for fz in [1.0, -1.0]:
			VRBuild.box(self, Vector3(lw - 0.2, 0.025, 0.02), Vector3(cx, 0.835, fz * 0.04), leaf)
			VRBuild.box(self, Vector3(lw - 0.2, 0.025, 0.02), Vector3(cx, 0.205, fz * 0.04), leaf)
			VRBuild.box(self, Vector3(0.025, 0.65, 0.02), Vector3(cx - (lw - 0.2) / 2.0, 0.52, fz * 0.04), leaf)
			VRBuild.box(self, Vector3(0.025, 0.65, 0.02), Vector3(cx + (lw - 0.2) / 2.0, 0.52, fz * 0.04), leaf)
			VRBuild.box(self, Vector3(lw - 0.06, 0.2, 0.012), Vector3(cx, 0.1, fz * 0.041), brass)           # kick plate
		# a long brushed-metal pull handle on the street side, and three hinges on the outer edge
		for hy2 in [1.5, 0.74]:
			RuinedExterior.rod(self, Vector3(cx - side * (lw / 2.0 - 0.045), hy2, -0.04), Vector3(cx - side * (lw / 2.0 - 0.045), hy2, -0.1), 0.014, brass)
		RuinedExterior.rod(self, Vector3(cx - side * (lw / 2.0 - 0.045), 0.7, -0.1), Vector3(cx - side * (lw / 2.0 - 0.045), 1.54, -0.1), 0.019, brass)
		for hy3 in [0.35, 1.2, 2.0]:
			VRBuild.cylinder(self, 0.016, 0.16, Vector3(cx + side * (lw / 2.0 + 0.004), hy3, 0.0), brass, -1.0, Vector3.ZERO, 12)
		VRBuild.box(self, Vector3(0.09, door_h - 0.9, 0.07), Vector3(cx - lw / 2.0 + 0.045, 0.9 + (door_h - 0.9) / 2.0, 0), leaf)
		VRBuild.box(self, Vector3(0.09, door_h - 0.9, 0.07), Vector3(cx + lw / 2.0 - 0.045, 0.9 + (door_h - 0.9) / 2.0, 0), leaf)
		VRBuild.box(self, Vector3(lw, 0.09, 0.07), Vector3(cx, door_h - 0.045, 0), leaf)
		VRBuild.box(self, Vector3(lw, 0.08, 0.07), Vector3(cx, 0.94, 0), leaf)
		VRBuild.box(self, Vector3(0.04, door_h - 1.05, 0.05), Vector3(cx, 0.98 + (door_h - 1.05) / 2.0, 0), leaf)   # mullion
		VRBuild.quad(self, Vector2(lw - 0.15, door_h - 1.1), Vector3(cx, 0.98 + (door_h - 1.1) / 2.0 + 0.02, 0), glass)
		# push bar and handle plate on the inside
		# the push bar runs along the wooden lock rail, under the glass
		RuinedExterior.rod(self, Vector3(cx-0.31,0.94,0.13), Vector3(cx+0.31,0.94,0.13), 0.024, brass)
		for hx in [-0.27,0.27]:
			RuinedExterior.rod(self, Vector3(cx+hx,0.94,0.035), Vector3(cx+hx,0.94,0.13), 0.02, brass)
		for hy in [0.24,1.18,2.12]:
			RuinedExterior.rod(self, Vector3(cx+side*0.47,hy-0.05,0.05),Vector3(cx+side*0.47,hy+0.05,0.05),0.018,brass)
		VRBuild.box(self, Vector3(0.06, 0.34, 0.012), Vector3(cx - side * (lw / 2.0 - 0.045), 0.62, 0.041), brass)   # finger plate on the wooden stile
		# Fatty's Game Shack: a frosted-vinyl logo on the glass of each door, readable from inside and from the street
		var decal := VRBuild.tex_mat(_art("fatty-decal.png"), 0.25, 0.4)
		decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		VRBuild.quad(self, Vector2(0.72, 0.72), Vector3(cx, 1.62, 0.032), decal)
		VRBuild.quad(self, Vector2(0.72, 0.72), Vector3(cx, 1.62, -0.032), decal, Vector3(0, PI, 0))
		VRBuild.label(self, "PUSH", 0.07, Vector3(cx, 0.65, 0.04), Color(0.9, 0.8, 0.5, 0.8), Vector3.ZERO, 0, font)
	# the EXIT sign above the door: painted, lit, and not entirely serious about where it leads
	var exit_mat := VRBuild.tex_mat(_art("exit-sign.png"), 0.7, 0.5)
	exit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var back := VRBuild.mat(Color(0.08, 0.1, 0.09), 0.5, 0.4)
	var ey := door_h + 0.4
	for i in range(4):
		VRBuild.quad(self, Vector2(1.04, 0.52), Vector3(0, ey, 0.07 - i * 0.012), back)
	VRBuild.quad(self, Vector2(1.04, 0.52), Vector3(0, ey, 0.085), exit_mat)
	VRBuild.quad(self, Vector2(1.04, 0.52), Vector3(0, ey, 0.02), exit_mat, Vector3(0, PI, 0))
	var exit_light := OmniLight3D.new()
	exit_light.position = Vector3(0, ey, 0.5)
	exit_light.light_color = Color(0.4, 1.0, 0.55)
	exit_light.light_energy = 0.6
	exit_light.omni_range = 2.2
	add_child(exit_light)
	_build_scare()
	VRBuild.merge_static(self)


static func _art(file: String) -> Texture2D:
	var t = load("res://assets/art/%s" % file)
	return t if t is Texture2D else null


# Smoked panes use an inexpensive view-dependent sheen, with no exterior world,
# reflection cameras, transparent layers, particles or roaming actors.
var allowed := true
var _elapsed := 0.0
var _impact := false
var _pane_material: ShaderMaterial
var _scare_textures: Array[Texture2D] = []
var force_approach := false

func _glass_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
void fragment() {
 float fresnel = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
 float streak = (1.0 - smoothstep(0.0, 0.10, abs(UV.x - UV.y * 0.32 - 0.28)));
 ALBEDO = vec3(0.025, 0.045, 0.065) + vec3(0.06, 0.10, 0.13) * (fresnel + streak * 0.3);
 ROUGHNESS = 0.24;
 METALLIC = 0.65;
 SPECULAR = 0.6;
}
"""
	_pane_material = ShaderMaterial.new()
	_pane_material.shader = shader
	return _pane_material

func _build_scare() -> void:
	for file in ["zombie-brute.webp", "zombie-berserker.webp", "zombie-toxic.webp"]:
		_scare_textures.append(_art(file))
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float reveal = 0.0;
varying vec3 local_pos;
void vertex() { local_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec4 c = texture(tex, UV);
 // Keep the apparition within the glazed opening, never through the timber.
 if (c.a < 0.5 || local_pos.y < 1.0 || local_pos.y > 2.25 || abs(local_pos.x) > 0.95 || abs(local_pos.x) < 0.08) discard;
 ALBEDO = c.rgb * reveal;
}
"""
	zombie_mat_sh = ShaderMaterial.new()
	zombie_mat_sh.shader = shader
	zombie_mat_sh.set_shader_parameter("tex", _scare_textures[0])
	zombie = VRBuild.quad(self, Vector2(1.6, 1.6), Vector3(0, 1.5, 0.012), zombie_mat_sh)
	zombie.set_meta("dynamic", true)
	zombie.visible = false
	_timer = randf_range(90.0, 180.0)

func _process(delta: float) -> void:
	if zombie == null:
		return
	if not allowed:
		if _walking:
			_end_pass()
		return
	if not _walking:
		_timer -= delta
		if _timer <= 0.0:
			_start_pass()
		return
	_elapsed += delta
	# Silent irregular pause, 140 ms reveal/lunge, a single impact, then withdraw.
	var t := _elapsed - _pause
	if t < 0.0:
		return
	var arrival := clampf(t / 0.14, 0.0, 1.0)
	var retreat := clampf((t - 0.65) / 0.35, 0.0, 1.0)
	zombie.visible = true
	zombie.scale = Vector3.ONE * lerpf(0.45, 1.45, arrival * arrival) * (1.0 - retreat * 0.6)
	zombie.position = Vector3(_x, 1.55 - arrival * 0.08, 0.012)
	zombie.rotation.z = _dir * (0.16 - arrival * 0.1)
	zombie_mat_sh.set_shader_parameter("reveal", (0.05 + arrival * 0.9) * (1.0 - retreat))
	if arrival >= 1.0 and not _impact:
		_impact = true
		scare.emit("stare")
	if t >= 1.0:
		_end_pass()

func _start_pass() -> void:
	_walking = true
	_elapsed = 0.0
	_impact = false
	_pause = randf_range(0.1, 0.8)
	_dir = -1.0 if randf() < 0.5 else 1.0
	_x = _dir * randf_range(0.12, 0.4)
	zombie_mat_sh.set_shader_parameter("tex", _scare_textures.pick_random())

func _end_pass() -> void:
	_walking = false
	zombie.visible = false
	_timer = randf_range(150.0, 360.0)

func debug_show(file: String, at_x := 0.0, size := 1.9) -> void:
	_start_pass()
	zombie_mat_sh.set_shader_parameter("tex", _art(file))
	_x = at_x
	_pause = 0.0
