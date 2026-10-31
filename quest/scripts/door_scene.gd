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
	# the wall either side of the door and above it
	for side in [-1, 1]:
		var cx: float = side * (door_w / 2.0 + wall_w / 2.0)
		VRBuild.box(self, Vector3(wall_w, 1.1, 0.12), Vector3(cx, 0.55, 0), wood)
		VRBuild.box(self, Vector3(wall_w, height - 1.1, 0.12), Vector3(cx, 1.1 + (height - 1.1) / 2.0, 0), paper)
	VRBuild.box(self, Vector3(door_w, height - door_h, 0.12), Vector3(0, door_h + (height - door_h) / 2.0, 0), paper)
	# frame
	var frame := VRBuild.mat(Color(0.93, 0.84, 0.78), 0.5)
	for sx in [-1, 1]:
		VRBuild.box(self, Vector3(0.12, door_h, 0.2), Vector3(sx * (door_w / 2.0 + 0.04), door_h / 2.0, 0), frame)
	VRBuild.box(self, Vector3(door_w + 0.24, 0.12, 0.2), Vector3(0, door_h + 0.04, 0), frame)
	VRBuild.box(self, Vector3(door_w + 0.2, 0.04, 0.4), Vector3(0, 0.01, 0.05), VRBuild.mat(Color(0.5, 0.45, 0.35), 0.4, 0.5, 0.2, Color(0.5, 0.45, 0.35)))   # brass threshold
	# two leaves, each with a glass window
	var leaf := VRBuild.mat(Color(0.82, 0.5, 0.6), 0.45)
	var brass := VRBuild.mat(Color(0.85, 0.65, 0.25), 0.25, 0.5, 0.2, Color(0.85, 0.65, 0.25))
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
		VRBuild.box(self, Vector3(0.62, 0.05, 0.05), Vector3(cx + side * -0.0, 1.02, 0.09), brass)
		VRBuild.box(self, Vector3(0.1, 0.5, 0.03), Vector3(cx - side * (lw / 2.0 - 0.1), 1.02, 0.06), brass)
		VRBuild.label(self, "PUSH", 0.07, Vector3(cx, 0.65, 0.04), Color(0.9, 0.8, 0.5, 0.8), Vector3.ZERO, 0, font)
	# EXIT sign and neon title above the door
	VRBuild.box(self, Vector3(0.7, 0.24, 0.08), Vector3(0, door_h + 0.32, 0.08), VRBuild.mat(Color(0.02, 0.2, 0.05), 0.5, 0.0, 1.6, Color(0.1, 1.0, 0.3)))
	VRBuild.label(self, "EXIT", 0.18, Vector3(0, door_h + 0.32, 0.125), Color(0.85, 1.0, 0.85), Vector3.ZERO, 3, font)
	var title := VRBuild.label(self, "ZOMBIE SMASH ARCADE", 0.2, Vector3(0, height - 0.3, 0.09), Color(0.4, 1.0, 0.45), Vector3.ZERO, 10, font)
	title.name = "DoorTitle"
	_build_outside(font)


func _build_outside(font: Font) -> void:
	# ground: pavement by the door, a kerb, then tarmac with bay lines
	var path := VRBuild.mat(Color(0.12, 0.12, 0.16), 0.9)
	var tarmac := VRBuild.mat(Color(0.025, 0.025, 0.04), 0.95)
	var line := VRBuild.mat(Color(0.8, 0.8, 0.75), 0.7, 0.0, 0.2)
	VRBuild.quad(self, Vector2(40, 2.2), Vector3(0, 0.0, -1.1), path, Vector3(-PI / 2.0, 0, 0))
	VRBuild.box(self, Vector3(40, 0.14, 0.2), Vector3(0, -0.07, -2.3), VRBuild.mat(Color(0.4, 0.4, 0.42), 0.8))
	VRBuild.quad(self, Vector2(90, 60), Vector3(0, -0.14, -32.0), tarmac, Vector3(-PI / 2.0, 0, 0))
	for i in range(-7, 8):
		VRBuild.box(self, Vector3(0.08, 0.01, 5.0), Vector3(i * 2.8, -0.135, -7.6), line)
	VRBuild.box(self, Vector3(40, 0.01, 0.08), Vector3(0, -0.135, -5.2), line)
	# sky, moon and a skyline
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bld := VRBuild.mat(Color(0.012, 0.014, 0.03), 0.9)
	var win := VRBuild.mat(Color(1.0, 0.78, 0.3), 0.5, 0.0, 0.9)
	for i in range(14):
		var bx := -60.0 + i * 9.0 + rng.randf() * 3.0
		var bh := 6.0 + rng.randf() * 16.0
		VRBuild.box(self, Vector3(6.0 + rng.randf() * 4.0, bh, 5.0), Vector3(bx, bh / 2.0 - 0.14, -48.0 - rng.randf() * 6.0), bld)
		for k in range(int(bh / 3.0)):
			if rng.randf() < 0.35:
				VRBuild.quad(self, Vector2(0.9, 1.1), Vector3(bx + rng.randf_range(-2, 2), 1.5 + k * 3.0, -45.4), win)
	# cars of the 1980s: boxy sedans, a hatchback, a pickup, an estate with wood panels, a van
	var cars := [
		[Vector3(-6.2, 0, -7.4), PI, "sedan", Color(0.7, 0.1, 0.12)], [Vector3(-3.4, 0, -7.4), PI, "hatch", Color(0.15, 0.3, 0.7)],
		[Vector3(-0.6, 0, -7.6), PI, "estate", Color(0.75, 0.7, 0.55)], [Vector3(2.2, 0, -7.4), PI, "pickup", Color(0.1, 0.45, 0.25)],
		[Vector3(5.0, 0, -7.4), PI, "sedan", Color(0.85, 0.75, 0.15)], [Vector3(8.0, 0, -7.6), PI, "van", Color(0.9, 0.9, 0.92)],
		[Vector3(-9.0, 0, -7.4), PI, "hatch", Color(0.45, 0.15, 0.55)], [Vector3(-4.8, 0, -13.5), 0.0, "sedan", Color(0.2, 0.2, 0.22)],
		[Vector3(1.4, 0, -13.5), 0.0, "estate", Color(0.55, 0.12, 0.1)], [Vector3(6.6, 0, -13.5), 0.0, "pickup", Color(0.15, 0.2, 0.55)],
	]
	for c in cars:
		_car(c[0], c[1], c[2], c[3])
	# street lights with a warm glow
	for lx in [-5.5, 0.4, 6.0]:
		_lamp_post(Vector3(lx, 0, -3.6))
	# a porch light just outside the door, so whatever passes the glass is a black shape against a pool of cold light
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var rt := GradientTexture2D.new()
	var rg := Gradient.new()
	rg.colors = PackedColorArray([Color(0.8, 0.9, 1.0, 0.95), Color(0.3, 0.4, 0.75, 0.0)])
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


func _car(pos: Vector3, yaw: float, kind: String, col: Color) -> void:
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = yaw
	add_child(c)
	var paint := VRBuild.mat(col * 0.5, 0.3, 0.6)
	var glass := VRBuild.mat(Color(0.05, 0.07, 0.1), 0.1, 0.5, 0.2, Color(0.05, 0.07, 0.1))
	var dark := VRBuild.mat(Color(0.02, 0.02, 0.02), 0.8)
	var head := VRBuild.mat(Color(1.0, 0.95, 0.8), 0.3, 0.0, 1.4)
	var tail := VRBuild.mat(Color(1.0, 0.08, 0.05), 0.3, 0.0, 1.2)
	var len := 4.3
	var wid := 1.7
	var base_h := 0.6
	var cab_len := 2.1
	var cab_z := -0.2
	var cab_h := 0.55
	match kind:
		"hatch":
			len = 3.7
			cab_len = 2.3
			cab_z = -0.35
		"estate":
			len = 4.6
			cab_len = 3.0
			cab_z = -0.5
		"pickup":
			len = 4.6
			cab_len = 1.3
			cab_z = 0.6
		"van":
			len = 4.4
			cab_len = 4.0
			cab_h = 0.95
			cab_z = -0.1
	VRBuild.box(c, Vector3(wid, base_h, len), Vector3(0, 0.25 + base_h / 2.0, 0), paint)
	VRBuild.box(c, Vector3(wid - 0.15, cab_h, cab_len), Vector3(0, 0.25 + base_h + cab_h / 2.0, cab_z), glass)
	VRBuild.box(c, Vector3(wid - 0.1, 0.05, cab_len + 0.1), Vector3(0, 0.25 + base_h + cab_h + 0.02, cab_z), paint)
	if kind == "pickup":
		VRBuild.box(c, Vector3(wid, 0.4, 1.9), Vector3(0, 0.25 + base_h + 0.1, -1.3), paint)
		VRBuild.box(c, Vector3(wid - 0.2, 0.3, 1.7), Vector3(0, 0.25 + base_h + 0.3, -1.3), dark)
	if kind == "estate":
		VRBuild.box(c, Vector3(wid + 0.02, 0.18, len - 0.4), Vector3(0, 0.25 + base_h / 2.0, 0), VRBuild.mat(Color(0.35, 0.2, 0.1), 0.6))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			VRBuild.cylinder(c, 0.31, 0.22, Vector3(sx * (wid / 2.0 - 0.02), 0.31, sz * (len / 2.0 - 0.8)), dark, -1.0, Vector3(0, 0, PI / 2.0), 14)
		VRBuild.box(c, Vector3(0.3, 0.12, 0.05), Vector3(sx * 0.55, 0.62, len / 2.0 + 0.01), head)
		VRBuild.box(c, Vector3(0.3, 0.12, 0.05), Vector3(sx * 0.55, 0.62, -len / 2.0 - 0.01), tail)
	VRBuild.box(c, Vector3(wid + 0.05, 0.12, 0.12), Vector3(0, 0.38, len / 2.0 + 0.03), VRBuild.mat(Color(0.7, 0.7, 0.72), 0.3, 0.5, 0.2, Color(0.7, 0.7, 0.72)))
	VRBuild.merge_static(c)


func _lamp_post(pos: Vector3) -> void:
	var metal := VRBuild.mat(Color(0.12, 0.12, 0.14), 0.5, 0.5, 0.2, Color(0.12, 0.12, 0.14))
	VRBuild.cylinder(self, 0.07, 5.2, pos + Vector3(0, 2.6, 0), metal)
	VRBuild.box(self, Vector3(0.12, 0.1, 1.0), pos + Vector3(0, 5.2, 0.45), metal)
	var lamp := VRBuild.mat(Color(1.0, 0.85, 0.5), 0.4, 0.0, 3.5)
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	VRBuild.box(self, Vector3(0.3, 0.08, 0.5), pos + Vector3(0, 5.12, 0.85), lamp)
	var pool := VRBuild.mat(Color(1.0, 0.85, 0.5, 0.14), 0.5, 0.0, 1.0)
	pool.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	VRBuild.quad(self, Vector2(7, 7), pos + Vector3(0, -0.13, 0.85), pool, Vector3(-PI / 2.0, 0, 0))


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
