class_name DoorScene
extends Node3D
## The double door in the front wall, and the night car park outside it: era cars, street lights, and now and then a zombie
## who shambles past the glass as a shadow.

signal scare(kind: String)

const SHAPES := ["zombie-normal.webp", "zombie-runner.webp", "zombie-helmet.webp", "zombie-toxic.webp", "zombie-armored.webp", "zombie-berserker.webp", "zombie-brute.webp", "zombie-titan.webp", "zombie-fuse.webp", "zombie-bulwark.webp", "boss-jordan-stage1.webp", "boss-debo-stage1.webp", "boss-fatamy-stage1.webp"]

var zombie: MeshInstance3D
var zombie_mat: StandardMaterial3D
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
	zombie_mat = StandardMaterial3D.new()
	zombie_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zombie_mat.albedo_color = Color(0, 0, 0)
	zombie_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	zombie_mat.alpha_scissor_threshold = 0.4
	zombie_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	zombie = VRBuild.quad(self, Vector2(1.6, 1.6), Vector3(8, 1.0, -0.6), zombie_mat)
	zombie.visible = false
	zombie.set_meta("dynamic", true)
	VRBuild.merge_static(self)


func _process(delta: float) -> void:
	_time += delta
	if zombie == null:
		return
	if not _walking:
		_timer -= delta
		if _timer <= 0.0:
			_start_pass()
		return
	if _pause > 0.0:
		_pause -= delta
		if _kind == "lurch":
			zombie.scale.x = -_dir * (1.0 if int(_time * 14.0) % 2 == 0 else 0.97)     # a twitch while it stares at the glass
	else:
		_x += _dir * _speed * delta
		if _kind == "lurch" and not _stopped and absf(_x) < 0.5:
			_stopped = true
			_pause = 0.35
			_speed = 9.5
			zombie.scale.x = _dir
			scare.emit("stare")
	var bob := sin(_time * (14.0 if _speed > 5.0 else 6.0)) * (0.045 if _kind != "crawl" else 0.02)
	zombie.position = Vector3(_x, _y + bob, _z)
	zombie.rotation.z = sin(_time * 9.0) * (0.09 if _speed > 5.0 else 0.04) + (0.0 if _kind != "dash" else -0.08 * _dir)
	if _pause <= 0.0 and absf(_x) < 6.0 and absf(_x) > 5.7 and false:
		pass
	if absf(_x) > 6.2 and _pause <= 0.0 and signf(_x) == _dir:
		_walking = false
		zombie.visible = false
		if _burst > 0:
			_burst -= 1
			_timer = randf_range(0.6, 2.2)
		else:
			_timer = randf_range(9.0, 55.0)


## Development: freeze a zombie of the given picture in front of the glass.
func debug_show(file: String, at_x := 0.0, size := 1.9) -> void:
	_walking = true
	_pause = 9999.0
	_kind = "dash"
	zombie_mat.albedo_texture = load("res://assets/art/" + file)
	(zombie.mesh as QuadMesh).size = Vector2(size, size)
	_x = at_x
	_y = 0.95
	_z = -0.7
	zombie.scale = Vector3(-1, 1, 1)
	zombie.visible = true


func _start_pass() -> void:
	_walking = true
	_dir = 1.0 if randf() < 0.5 else -1.0
	var r := randf()
	_kind = "dash" if r < 0.45 else ("lurch" if r < 0.75 else ("crawl" if r < 0.9 else "tall"))
	var file: String = SHAPES[randi() % SHAPES.size()]
	var tex = load("res://assets/art/" + file)
	zombie_mat.albedo_texture = tex
	var size := 1.5 + randf() * 0.6
	_z = randf_range(-0.55, -0.9)
	_y = 0.9
	_speed = randf_range(6.5, 9.0)
	match _kind:
		"lurch":
			_speed = randf_range(3.0, 4.0)
			size += 0.2
		"crawl":
			_speed = randf_range(3.2, 4.5)
			size *= 0.75
			_y = 0.55
		"tall":
			size = 2.4 + randf() * 0.4
			_y = 1.25
			_speed = randf_range(5.0, 7.0)
	(zombie.mesh as QuadMesh).size = Vector2(size, size)
	zombie.scale = Vector3(-_dir, 1, 1)
	_x = -6.0 * _dir
	_pause = 0.0
	_stopped = false
	zombie.visible = true
	if randf() < 0.22:
		_burst = 1            # sometimes a second one follows straight after
	scare.emit(_kind)


var _y := 0.9
var _z := -0.7
