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
		wmat.uv1_scale = Vector3(wall_w / 2.4, height / 2.4, 1)
		wmat.texture_repeat = true
		VRBuild.box(self, Vector3(wall_w, height, 0.12), Vector3(cx, height / 2.0, 0), wmat)
	var tmat: StandardMaterial3D = wood.duplicate()
	tmat.uv1_scale = Vector3(door_w / 2.4, (height - door_h) / 2.4, 1)
	tmat.texture_repeat = true
	VRBuild.box(self, Vector3(door_w, height - door_h, 0.12), Vector3(0, door_h + (height - door_h) / 2.0, 0), tmat)
	# frame
	var frame := RuinedExterior.surface("materials", 3, Color(0.24,0.26,0.28), 0.7)
	for sx in [-1, 1]:
		VRBuild.box(self, Vector3(0.12, door_h, 0.2), Vector3(sx * (door_w / 2.0 + 0.04), door_h / 2.0, 0), frame)
	VRBuild.box(self, Vector3(door_w + 0.24, 0.12, 0.2), Vector3(0, door_h + 0.04, 0), frame)
	VRBuild.box(self, Vector3(door_w + 0.2, 0.04, 0.4), Vector3(0, 0.01, 0.05), VRBuild.mat(Color(0.5, 0.45, 0.35), 0.4, 0.5, 0.2, Color(0.5, 0.45, 0.35)))   # brass threshold
	# two leaves, each with a glass window
	var leaf := RuinedExterior.surface("materials", 3, Color(0.18,0.21,0.23), 0.65)
	var brass := RuinedExterior.surface("materials", 3, Color(0.75,0.77,0.79), 0.8)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 0.65, 0.9, 0.07)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1, 1]:
		var cx: float = side * (door_w / 4.0)
		var lw := door_w / 2.0 - 0.01
		VRBuild.box(self, Vector3(lw, 0.9, 0.07), Vector3(cx, 0.45, 0), leaf)                       # bottom panel
		VRBuild.box(self, Vector3(0.09, door_h - 0.9, 0.07), Vector3(cx - lw / 2.0 + 0.045, 0.9 + (door_h - 0.9) / 2.0, 0), leaf)
		VRBuild.box(self, Vector3(0.09, door_h - 0.9, 0.07), Vector3(cx + lw / 2.0 - 0.045, 0.9 + (door_h - 0.9) / 2.0, 0), leaf)
		VRBuild.box(self, Vector3(lw, 0.09, 0.07), Vector3(cx, door_h - 0.045, 0), leaf)
		VRBuild.box(self, Vector3(lw, 0.08, 0.07), Vector3(cx, 0.94, 0), leaf)
		VRBuild.box(self, Vector3(0.04, door_h - 1.05, 0.05), Vector3(cx, 0.98 + (door_h - 1.05) / 2.0, 0), leaf)   # mullion
		VRBuild.quad(self, Vector2(lw - 0.15, door_h - 1.1), Vector3(cx, 0.98 + (door_h - 1.1) / 2.0 + 0.02, 0), glass)
		# push bar and handle plate on the inside
		RuinedExterior.rod(self, Vector3(cx-0.31,1.02,0.13), Vector3(cx+0.31,1.02,0.13), 0.024, brass)
		for hx in [-0.27,0.27]:
			RuinedExterior.rod(self, Vector3(cx+hx,1.02,0.04), Vector3(cx+hx,1.02,0.13), 0.02, brass)
		for hy in [0.24,1.18,2.12]:
			RuinedExterior.rod(self, Vector3(cx+side*0.47,hy-0.05,0.05),Vector3(cx+side*0.47,hy+0.05,0.05),0.018,brass)
		VRBuild.box(self, Vector3(0.1, 0.5, 0.03), Vector3(cx - side * (lw / 2.0 - 0.1), 1.02, 0.06), brass)
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
	_build_outside(font)


static func _art(file: String) -> Texture2D:
	var t = load("res://assets/art/%s" % file)
	return t if t is Texture2D else null


## Things that move out there so the night never sits still: drifting fog, a fire burning behind the buildings, rising embers,
## a failing street light and a few far-off figures shuffling along the road.
func _build_night_life() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.width = 512
	nt.height = 256
	nt.seamless = true
	var fsh := Shader.new()
	fsh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D noise_tex : repeat_enable;
uniform vec2 speed = vec2(0.01, 0.0);
uniform float strength = 0.4;
uniform vec4 col : source_color = vec4(0.18, 0.2, 0.3, 1.0);
void fragment() {
	float n = texture(noise_tex, UV * vec2(2.0, 1.0) + speed * TIME).r;
	float m = smoothstep(0.35, 0.85, n) * strength;
	float edge = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.7, UV.y);
	ALBEDO = col.rgb;
	ALPHA = m * edge;
}
"""
	for i in range(5):
		var fm := ShaderMaterial.new()
		fm.shader = fsh
		fm.set_shader_parameter("noise_tex", nt)
		fm.set_shader_parameter("speed", Vector2(0.012 + i * 0.004, 0.0) * (1.0 if i % 2 == 0 else -1.0))
		fm.set_shader_parameter("strength", 0.55)
		var q := VRBuild.quad(self, Vector2(60, 5.5), Vector3(0, 1.4 + i * 0.25, -2.5 - i * 4.0), fm)
		q.set_meta("dynamic", true)
	# the fire behind the buildings: a big soft orange glow and a light that flickers like flames
	var gtex := GradientTexture2D.new()
	var gg := Gradient.new()
	gg.colors = PackedColorArray([Color(1.0, 0.55, 0.15, 0.95), Color(0.9, 0.3, 0.05, 0.4), Color(0.5, 0.1, 0.0, 0.0)])
	gg.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gtex.gradient = gg
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	var fire_mat := StandardMaterial3D.new()
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire_mat.albedo_texture = gtex
	_fire_glow = VRBuild.quad(self, Vector2(16, 12), Vector3(9.0, 5.0, -26.5), fire_mat)
	_fire_glow.set_meta("dynamic", true)
	_fire_mat = fire_mat
	_fire_light = OmniLight3D.new()
	_fire_light.position = Vector3(9.0, 4.0, -20.0)
	_fire_light.light_color = Color(1.0, 0.5, 0.18)
	_fire_light.light_energy = 1.5
	_fire_light.omni_range = 30.0
	add_child(_fire_light)
	# embers drifting up from it
	_embers = CPUParticles3D.new()
	_embers.position = Vector3(9.0, 7.0, -24.0)
	_embers.amount = 60
	_embers.lifetime = 7.0
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_embers.emission_box_extents = Vector3(3.0, 0.3, 1.5)
	_embers.direction = Vector3(-0.3, 1.0, 0.2)
	_embers.spread = 25.0
	_embers.initial_velocity_min = 0.6
	_embers.initial_velocity_max = 1.6
	_embers.gravity = Vector3(0.1, 0.05, 0)
	_embers.scale_amount_min = 0.5
	_embers.scale_amount_max = 1.3
	var em := QuadMesh.new()
	em.size = Vector2(0.07, 0.07)
	var emm := StandardMaterial3D.new()
	emm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emm.albedo_color = Color(1.0, 0.55, 0.15)
	emm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	emm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	emm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	em.material = emm
	_embers.mesh = em
	add_child(_embers)
	# a street light that is failing: it dips and gutters, now and then goes out
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(-4.2, 4.2, -9.0)
	_lamp.light_color = Color(0.85, 0.9, 1.0)
	_lamp.light_energy = 1.4
	_lamp.omni_range = 9.0
	add_child(_lamp)
	var pole := VRBuild.mat(Color(0.03, 0.03, 0.04), 0.6)
	VRBuild.cylinder(self, 0.06, 4.2, Vector3(-4.2, 2.1, -9.0), pole, -1.0, Vector3.ZERO, 8)
	_lamp_bulb = VRBuild.mat(Color(1.0, 1.0, 1.0), 0.4, 0.0, 4.0)
	_lamp_bulb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	VRBuild.box(self, Vector3(0.5, 0.08, 0.22), Vector3(-4.2, 4.22, -9.0), _lamp_bulb)
	# far-off figures: small, grey in the fog, shuffling along the far pavement, never close
	for i in range(4):
		var dm := ShaderMaterial.new()
		dm.shader = zombie_mat_sh.shader
		dm.set_shader_parameter("tex", load("res://assets/art/" + SHAPES[(i * 3) % SHAPES.size()]))
		dm.set_shader_parameter("fog", 0.75)
		var wq := VRBuild.quad(self, Vector2(1.7, 1.7), Vector3(0, 0.9, -13.0 - i * 2.2), dm)
		wq.set_meta("dynamic", true)
		_walkers.append({"node": wq, "mat": dm, "x": randf_range(-11.0, 11.0), "dir": 1.0 if i % 2 == 0 else -1.0, "speed": randf_range(0.25, 0.5), "z": -13.0 - i * 2.2, "ph": randf() * 6.0})


func _build_outside(font: Font) -> void:
	RuinedExterior.build(self)
	# the night sky and moon
	var sky := StandardMaterial3D.new()
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.0, 0.0, 0.015), Color(0.012, 0.02, 0.07), Color(0.04, 0.05, 0.13)])
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	sky.albedo_texture = gt
	VRBuild.quad(self, Vector2(220, 80), Vector3(0, 30, -60), sky)
	var moon := VRBuild.mat(Color(0.85, 0.9, 1.0), 0.5, 0.0, 3.0)
	moon.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	VRBuild.sphere(self, 1.8, Vector3(-14, 22, -55), moon, 20)

	# a porch light just outside the door, so whatever passes the glass is a black shape against a pool of cold light
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var rt := GradientTexture2D.new()
	var rg := Gradient.new()
	rg.colors = PackedColorArray([Color(0.8, 0.9, 1.0, 0.8), Color(0.3, 0.4, 0.75, 0.0)])
	rt.gradient = rg
	rt.fill = GradientTexture2D.FILL_RADIAL
	rt.fill_from = Vector2(0.5, 0.5)
	rt.fill_to = Vector2(1.0, 0.5)
	haze.albedo_texture = rt
	glow_mat = haze
	VRBuild.quad(self, Vector2(4.2, 3.2), Vector3(0, 1.25, -1.35), haze)
	var bulb := VRBuild.mat(Color(0.9, 0.95, 1.0), 0.4, 0.0, 4.0)
	bulb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	VRBuild.box(self, Vector3(0.5, 0.06, 0.2), Vector3(0, 2.75, -0.45), bulb)
	var porch := OmniLight3D.new()
	porch.position = Vector3(0, 2.4, -0.9)
	porch.light_color = Color(0.75, 0.85, 1.0)
	porch.light_energy = 0.45
	porch.omni_range = 5.0
	add_child(porch)
	var zsh := Shader.new()
	zsh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 fog_col : source_color = vec4(0.05, 0.07, 0.12, 1.0);
uniform vec4 rim_col : source_color = vec4(0.9, 0.35, 0.1, 1.0);
uniform float fog = 0.0;
uniform float sway = 0.0;
uniform float lunge = 0.0;
uniform float t = 0.0;
varying float vy;
void vertex() {
	float top = 1.0 - UV.y;
	VERTEX.x += sway * top * top * 0.22 + sin(t * 3.0 + top * 4.0) * 0.012 * top;
	VERTEX.y += sin(t * 5.0) * 0.01 * top;
	vy = top;
}
void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.35) discard;
	// dark silhouette: just a faint glint along the edge where the fire behind the buildings catches it
	float edge = 1.0 - c.a;
	vec3 body = mix(vec3(0.0), fog_col.rgb, fog);
	float glint = smoothstep(0.35, 0.9, texture(tex, UV + vec2(0.012, 0.0)).a) - smoothstep(0.35, 0.9, texture(tex, UV - vec2(0.012, 0.0)).a);
	body += rim_col.rgb * clamp(glint, 0.0, 1.0) * 0.5 * (1.0 - fog);
	ALBEDO = body;
}
"""
	zombie_mat_sh = ShaderMaterial.new()
	zombie_mat_sh.shader = zsh
	zombie = VRBuild.quad(self, Vector2(1.6, 1.6), Vector3(8, 1.0, -0.6), zombie_mat_sh)
	zombie.visible = false
	zombie.set_meta("dynamic", true)
	VRBuild.merge_static(self)
	_build_night_life()


func _process(delta: float) -> void:
	_time += delta
	_night(delta)
	if zombie == null:
		return
	if not _walking:
		_timer -= delta
		if _timer <= 0.0:
			_start_pass()
		return
	zombie_mat_sh.set_shader_parameter("t", _time)
	if _pause > 0.0:
		zombie.position = Vector3(_x, _y, _z)
		return
	match _kind:
		"approach":
			_approach(delta)
		_:
			_pass_by(delta)


## The slow one: it comes out of the dark at the far end of the road, shambling toward the glass, stops right outside it,
## jerks closer, slams and then goes back into the fog.
func _approach(delta: float) -> void:
	_appr += delta
	var t := _appr
	var walk := 3.2                       # seconds of walking
	var k := clampf(t / walk, 0.0, 1.0)
	var near := 0.62
	if t < walk:
		var e := k * k * (3.0 - 2.0 * k)
		_z = lerpf(-11.0, -near, e * 0.98 + k * 0.02)
		var step := sin(t * 5.2)
		zombie.position = Vector3(_x + sin(t * 1.3) * 0.25 + step * 0.03, _y + absf(step) * 0.05, _z)
		zombie.rotation.z = sin(t * 2.6) * 0.07 + 0.06 * sin(t * 5.2)
		zombie_mat_sh.set_shader_parameter("sway", sin(t * 2.6) * 0.5)
		zombie_mat_sh.set_shader_parameter("fog", clampf(1.0 - (_z + 11.0) / 8.0, 0.0, 0.85))
		(zombie.mesh as QuadMesh).size = Vector2.ONE * (_size * (0.45 + 0.55 * clampf((_z + 11.0) / 10.4, 0.0, 1.0)))
	elif t < walk + 1.0:
		# it stops, head hanging; a long beat of stillness
		zombie.position = Vector3(_x, _y, -near)
		zombie.rotation.z = sin(t * 9.0) * 0.012
		zombie_mat_sh.set_shader_parameter("sway", sin(t * 1.4) * 0.1)
		zombie_mat_sh.set_shader_parameter("fog", 0.0)
	elif t < walk + 1.45:
		# the lunge at the glass
		var j := (t - walk - 1.0) / 0.45
		zombie.position = Vector3(_x, _y - 0.03 * j, -near + 0.38 * j)
		(zombie.mesh as QuadMesh).size = Vector2.ONE * (_size * (1.0 + 0.9 * j * j))
		zombie.rotation.z = sin(t * 38.0) * 0.05 * j
		zombie_mat_sh.set_shader_parameter("sway", 0.0)
		if not _stopped:
			_stopped = true
			scare.emit("stare")
	elif t < walk + 3.1:
		# it hammers on the glass, shaking, then drags itself back
		var j2 := t - walk - 1.45
		zombie.position = Vector3(_x + sin(t * 55.0) * 0.045 * maxf(0.0, 1.0 - j2), _y - 0.03, -near + 0.38 - 0.1 * j2)
		zombie.rotation.z = sin(t * 30.0) * 0.04 * maxf(0.0, 1.0 - j2)
	else:
		var j3 := (t - walk - 3.1) / 1.2
		zombie.position = Vector3(_x, _y, -near + 0.28 - 9.0 * j3 * j3)
		zombie_mat_sh.set_shader_parameter("fog", clampf(j3, 0.0, 0.9))
		(zombie.mesh as QuadMesh).size = Vector2.ONE * (_size * (1.9 - 1.2 * j3))
		if j3 >= 1.0:
			_end_pass()


## The others cross the glass at speed. The picture faces the viewer, so it leans into its run and lurches instead of sliding.
func _pass_by(delta: float) -> void:
	_x += _dir * _speed * delta
	var step := sin(_time * (13.0 if _speed > 5.0 else 6.5))
	zombie.position = Vector3(_x, _y + absf(step) * (0.07 if _kind != "crawl" else 0.025), _z)
	zombie.rotation.z = -_dir * (0.22 if _speed > 5.0 else 0.12) + step * 0.06
	zombie_mat_sh.set_shader_parameter("sway", -_dir * (0.6 + 0.4 * step))
	zombie_mat_sh.set_shader_parameter("fog", 0.0)
	if absf(_x) > 6.2 and signf(_x) == _dir:
		_end_pass()


func _end_pass() -> void:
	_walking = false
	zombie.visible = false
	if _burst > 0:
		_burst -= 1
		_timer = randf_range(0.6, 2.2)
	else:
		_timer = randf_range(14.0, 45.0)


## Everything out there that moves by itself.
func _night(delta: float) -> void:
	if _fire_light != null:
		var f := 0.8 + 0.2 * sin(_time * 7.0) + 0.12 * sin(_time * 13.3 + 1.0) + 0.1 * sin(_time * 3.1)
		_fire_light.light_energy = 1.5 * f
		_fire_mat.albedo_color = Color(1, 1, 1, clampf(0.65 + 0.3 * f, 0.0, 1.0))
	if _lamp != null:
		_lamp_out = maxf(0.0, _lamp_out - delta)
		if _lamp_out <= 0.0 and randf() < delta * 0.06:
			_lamp_out = randf_range(0.15, 1.1)
		var flick := 1.0 if int(_time * 23.0) % 5 != 0 else 0.55
		var level := 0.0 if _lamp_out > 0.0 and int(_time * 40.0) % 3 != 0 else flick
		_lamp.light_energy = 1.4 * level
		_lamp_bulb.emission_energy_multiplier = 4.0 * level
		_lamp_bulb.albedo_color = Color(1, 1, 1) * (0.25 + 0.75 * level)
	for w in _walkers:
		w.x += w.dir * w.speed * delta
		if absf(w.x) > 13.0:
			w.dir = -w.dir
			w.x = clampf(w.x, -13.0, 13.0)
		var step := sin(_time * 3.0 + w.ph)
		(w.node as MeshInstance3D).position = Vector3(w.x, 0.9 + absf(step) * 0.03, w.z)
		(w.node as MeshInstance3D).rotation.z = -w.dir * 0.1 + step * 0.04
		(w.mat as ShaderMaterial).set_shader_parameter("sway", -w.dir * 0.4 * step)
		(w.mat as ShaderMaterial).set_shader_parameter("t", _time + w.ph)


## Development: freeze a zombie of the given picture in front of the glass.
func debug_show(file: String, at_x := 0.0, size := 1.9) -> void:
	_walking = true
	_pause = 9999.0
	_kind = "dash"
	zombie_mat_sh.set_shader_parameter("tex", load("res://assets/art/" + file))
	(zombie.mesh as QuadMesh).size = Vector2(size, size)
	_x = at_x
	_y = 0.95
	_z = -0.7
	zombie.scale = Vector3.ONE
	zombie.visible = true


func _start_pass() -> void:
	_walking = true
	_dir = 1.0 if randf() < 0.5 else -1.0
	var r := randf()
	_kind = "approach" if (r < 0.5 or force_approach) else ("dash" if r < 0.8 else ("crawl" if r < 0.92 else "tall"))
	var file: String = SHAPES[randi() % SHAPES.size()]
	zombie_mat_sh.set_shader_parameter("tex", load("res://assets/art/" + file))
	_size = 1.5 + randf() * 0.6
	_z = randf_range(-0.55, -0.9)
	_y = 0.9
	_speed = randf_range(6.5, 9.0)
	_stopped = false
	_appr = 0.0
	match _kind:
		"approach":
			_x = randf_range(-0.7, 0.7)
			_size = 1.9
		"crawl":
			_speed = randf_range(3.2, 4.5)
			_size *= 0.75
			_y = 0.55
		"tall":
			_size = 2.4 + randf() * 0.4
			_y = 1.25
			_speed = randf_range(5.0, 7.0)
	if _kind != "approach":
		_x = -6.0 * _dir
	(zombie.mesh as QuadMesh).size = Vector2(_size, _size)
	zombie.scale = Vector3.ONE
	zombie.rotation = Vector3.ZERO
	zombie.position = Vector3(_x, _y, _z)
	zombie.visible = true
	_pause = 0.0
	if randf() < 0.22 and _kind != "approach":
		_burst = 1
	scare.emit("approach" if _kind == "approach" else _kind)


var _size := 1.8
var force_approach := false
var _y := 0.9
var _z := -0.7
var _fire_glow: MeshInstance3D
var _fire_mat: StandardMaterial3D
var _fire_light: OmniLight3D
var _embers: CPUParticles3D
var _lamp: OmniLight3D
var _lamp_bulb: StandardMaterial3D
var _walkers: Array = []
var _lamp_out := 0.0
var _appr := 0.0
