class_name ArcadeRoom
extends RefCounted
## The old-school arcade the machine stands in: neon, carpet, a bank of machines, posters and a prize counter.

const HALF_W := 3.6
const FRONT_Z := -1.65
const BACK_Z := 4.2
const HEIGHT := 2.9

var main_cabinet: Cabinet
var flickers: Array = []      # [material, base_energy, speed, phase]
var sign_labels: Array = []
var prize_wall: PrizeWall
var hall: HallBoard
var progress: VRProgress


func build(root: Node3D, screen_tex: Texture2D, banner: Texture2D, font: Font, prog: VRProgress) -> void:
	progress = prog
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.01, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.27, 0.5)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	_shell(root)
	_lights(root)
	_front_row(root, screen_tex, banner)
	_side_cabinets(root)
	_decor(root, font)


func _shell(root: Node3D) -> void:
	var w := HALF_W * 2.0
	var d := BACK_Z - FRONT_Z
	var cz := (BACK_Z + FRONT_Z) / 2.0
	# carpet
	var carpet := VRBuild.tex_mat(VRBuild.carpet_texture(), 0.0, 0.95)
	carpet.uv1_scale = Vector3(w / 1.4, d / 1.4, 1)
	carpet.texture_repeat = true
	VRBuild.quad(root, Vector2(w, d), Vector3(0, 0, cz), carpet, Vector3(-PI / 2, 0, 0))
	# ceiling
	var ceiling := VRBuild.mat(Color(0.03, 0.025, 0.06), 0.9)
	VRBuild.quad(root, Vector2(w, d), Vector3(0, HEIGHT, cz), ceiling, Vector3(PI / 2, 0, 0))
	# walls: lower wood panelling, upper dark violet
	var wood := VRBuild.mat(Color(0.20, 0.11, 0.07), 0.8)
	var paint := VRBuild.mat(Color(0.09, 0.05, 0.16), 0.9)
	var walls := [
		[Vector3(0, 0, FRONT_Z), 0.0, w],
		[Vector3(0, 0, BACK_Z), PI, w],
		[Vector3(-HALF_W, 0, cz), PI / 2, d],
		[Vector3(HALF_W, 0, cz), -PI / 2, d],
	]
	for wall in walls:
		var root_w := Node3D.new()
		root_w.position = wall[0]
		root_w.rotation.y = wall[1]
		root.add_child(root_w)
		VRBuild.quad(root_w, Vector2(wall[2], 1.1), Vector3(0, 0.55, 0), wood)
		VRBuild.quad(root_w, Vector2(wall[2], HEIGHT - 1.1), Vector3(0, 1.1 + (HEIGHT - 1.1) / 2.0, 0), paint)
		VRBuild.box(root_w, Vector3(wall[2], 0.06, 0.05), Vector3(0, 1.1, 0.02), VRBuild.mat(Color(0.35, 0.2, 0.1), 0.6))
		# neon strip near the ceiling, alternating colours
		var neon := VRBuild.mat(Color(1.0, 0.2, 0.7) if int(wall[1] * 10) % 2 == 0 else Color(0.1, 0.9, 1.0), 0.4, 0.0, 2.2)
		VRBuild.box(root_w, Vector3(wall[2] - 0.2, 0.03, 0.03), Vector3(0, HEIGHT - 0.28, 0.03), neon)
		VRBuild.box(root_w, Vector3(wall[2] - 0.2, 0.03, 0.03), Vector3(0, HEIGHT - 0.38, 0.03), neon)
	# ceiling light panels
	var panel_light := VRBuild.mat(Color(1, 0.9, 0.7), 0.5, 0.0, 1.5)
	for x in [-2.2, 0.0, 2.2]:
		for z in [-0.6, 1.4, 3.2]:
			VRBuild.box(root, Vector3(0.6, 0.04, 0.3), Vector3(x, HEIGHT - 0.03, z), panel_light)


func _lights(root: Node3D) -> void:
	var specs := [
		[Vector3(-2.2, 2.3, 0.6), Color(1.0, 0.3, 0.75), 1.4, 5.5],
		[Vector3(2.2, 2.3, 0.6), Color(0.2, 0.85, 1.0), 1.4, 5.5],
		[Vector3(0.0, 2.4, 2.8), Color(1.0, 0.75, 0.45), 1.0, 5.5],
	]
	for s in specs:
		var l := OmniLight3D.new()
		l.position = s[0]
		l.light_color = s[1]
		l.light_energy = s[2]
		l.omni_range = s[3]
		root.add_child(l)


func _front_row(root: Node3D, screen_tex: Texture2D, banner: Texture2D) -> void:
	var names := ["ASTRO BLAST", "DISCO DASH", "PIN WIZARD", "", "ROAD RIOT", "GALAXY GRAB", "KING KONGA"]
	var bodies := [Color(0.14, 0.06, 0.28), Color(0.28, 0.05, 0.2), Color(0.05, 0.16, 0.28), Color(0.12, 0.12, 0.14), Color(0.28, 0.14, 0.04), Color(0.06, 0.24, 0.18), Color(0.25, 0.04, 0.06)]
	var trims := [Color(0.2, 0.9, 1), Color(1, 0.3, 0.8), Color(1, 0.85, 0.2), Color(0.2, 1, 0.45), Color(1, 0.55, 0.1), Color(0.6, 0.4, 1), Color(1, 0.3, 0.3)]
	var arts := ["arena-glowinghumanity.webp", "arena-discoman.webp", "arena-debo.webp", "", "arena-caffeinatedsloth.webp", "arena-fatamy.webp", "arena-drmantis.webp"]
	for i in range(7):
		var x := (i - 3) * 0.86
		var c := Cabinet.new()
		c.position = Vector3(x, 0, -0.42 if i == 3 else -0.42)
		root.add_child(c)
		if i == 3:
			c.build(screen_tex, banner, bodies[i], trims[i], true)
			main_cabinet = c
		else:
			var art: Texture2D = load("res://assets/art/" + arts[i])
			var tex_for_screen := art
			c.build(tex_for_screen, null, bodies[i], trims[i], false, names[i], bodies[i].lightened(0.15))
			flickers.append([c.screen_mat, 1.0, 0.7 + i * 0.13, i * 1.7])
	# a plain back wall behind the bank
	VRBuild.box(root, Vector3(HALF_W * 2.0, HEIGHT, 0.05), Vector3(0, HEIGHT / 2.0, FRONT_Z - 0.03), VRBuild.mat(Color(0.05, 0.03, 0.09), 0.9))


func _side_cabinets(root: Node3D) -> void:
	var arts := ["arena-jordan.webp", "arena-debo.webp", "arena-discoman.webp", "arena-glowinghumanity.webp", "arena-fatamy.webp", "arena-caffeinatedsloth.webp"]
	var names := ["TURBO TUNNEL", "SPACE SIEGE", "SLAM DUNK JAM", "NINJA NIGHT", "PAC PARADE", "HOT LAPS"]
	var colors := [Color(0.2, 0.05, 0.3), Color(0.04, 0.2, 0.28), Color(0.3, 0.12, 0.04), Color(0.22, 0.04, 0.22), Color(0.05, 0.25, 0.12), Color(0.28, 0.05, 0.08)]
	var trims := [Color(1, 0.3, 0.9), Color(0.3, 0.9, 1), Color(1, 0.7, 0.2), Color(0.8, 0.4, 1), Color(0.4, 1, 0.5), Color(1, 0.4, 0.3)]
	var k := 0
	for side in [-1, 1]:
		for z in [0.9, 1.9, 2.9]:
			var c := Cabinet.new()
			c.position = Vector3(side * 3.1, 0, z)
			c.rotation.y = -side * PI / 2.0
			root.add_child(c)
			var art: Texture2D = load("res://assets/art/" + arts[k])
			c.build(art, null, colors[k], trims[k], false, names[k], colors[k].lightened(0.2))
			flickers.append([c.screen_mat, 1.0, 0.5 + k * 0.11, k * 2.3])
			k += 1


func _decor(root: Node3D, font: Font) -> void:
	# big neon sign above the bank of machines
	var sign_back := VRBuild.box(root, Vector3(3.6, 0.62, 0.05), Vector3(0, 2.52, FRONT_Z + 0.04), VRBuild.mat(Color(0.02, 0.01, 0.04), 0.9))
	var l1 := VRBuild.label(root, "ZOMBIE SMASH", 0.5, Vector3(0, 2.52, FRONT_Z + 0.075), Color(0.4, 1.0, 0.45), Vector3.ZERO, 14, font)
	sign_labels.append(l1)
	# back wall: prizes on the left, the hall of fame on the right
	var counter := VRBuild.mat(Color(0.22, 0.1, 0.05), 0.6)
	VRBuild.box(root, Vector3(3.4, 1.0, 0.6), Vector3(-1.75, 0.5, BACK_Z - 0.4), counter)
	VRBuild.box(root, Vector3(3.5, 0.06, 0.7), Vector3(-1.75, 1.02, BACK_Z - 0.4), VRBuild.mat(Color(0.5, 0.3, 0.15), 0.4))
	VRBuild.box(root, Vector3(3.4, 0.04, 0.4), Vector3(-1.75, 1.0, BACK_Z - 0.18), VRBuild.mat(Color(1.0, 0.8, 0.3), 0.3, 0.0, 1.0))
	VRBuild.box(root, Vector3(3.2, 0.75, 0.3), Vector3(1.9, 0.375, BACK_Z - 0.2), counter)
	prize_wall = PrizeWall.new()
	prize_wall.build(root, Vector3(-1.75, 0.0, BACK_Z - 0.2), PI, font)
	hall = HallBoard.new()
	hall.build(root, font, progress, Vector3(1.9, 1.85, BACK_Z - 0.08), PI)
	# posters on the side walls
	var posters := ["boss-jordan-stage1.webp", "boss-discoman-stage1.webp", "boss-fatamy-stage1.webp", "boss-debo-stage1.webp", "boss-drmantis-stage1.webp", "boss-caffeinatedsloth-stage1.webp"]
	var k := 0
	for side in [-1, 1]:
		for z in [0.0, 1.5, 3.0]:
			var holder := Node3D.new()
			holder.position = Vector3(side * (HALF_W - 0.03), 2.15, z + 0.4)
			holder.rotation.y = -side * PI / 2.0
			root.add_child(holder)
			VRBuild.box(holder, Vector3(0.62, 0.8, 0.03), Vector3.ZERO, VRBuild.mat(Color(0.8, 0.65, 0.2), 0.3, 0.7))
			var t: Texture2D = load("res://assets/art/" + posters[k])
			VRBuild.quad(holder, Vector2(0.56, 0.72), Vector3(0, 0, 0.017), VRBuild.tex_mat(t, 0.5, 0.6, false, Color(0.9, 0.9, 0.9)))
			k += 1
	# stools
	var seat := VRBuild.mat(Color(0.7, 0.1, 0.15), 0.5)
	var leg := VRBuild.mat(Color(0.8, 0.8, 0.85), 0.2, 0.9)
	for sx in [-1.4, 1.4]:
		VRBuild.cylinder(root, 0.17, 0.07, Vector3(sx, 0.6, 1.0), seat)
		VRBuild.cylinder(root, 0.02, 0.58, Vector3(sx, 0.3, 1.0), leg)
		VRBuild.cylinder(root, 0.17, 0.02, Vector3(sx, 0.02, 1.0), leg)


func animate(t: float) -> void:
	for f in flickers:
		var m: StandardMaterial3D = f[0]
		var k: float = 0.78 + 0.22 * sin(t * f[2] + f[3]) + (0.06 if int(t * 7.0 + f[3]) % 17 == 0 else 0.0)
		m.albedo_color = Color(k, k, k)
	for l in sign_labels:
		var on := 0.75 + 0.25 * (1.0 if int(t * 3.0) % 11 != 0 else 0.4)
		l.modulate.a = on
