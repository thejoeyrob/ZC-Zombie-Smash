class_name ArcadeRoom
extends RefCounted
## The old-school arcade. A double door in the front wall opens onto a night car park. Six machines stand in a curve either side
## of the door (a place for each player of a party), the pinball machine faces the door from the back wall between the prize
## shelves and the hall of fame, and a snack machine waits in the far corner.

const HALF_W := 4.6
const FRONT_Z := -0.55
const BACK_Z := 8.2
const HEIGHT := 3.2
const ARC_CENTRE := Vector3(0, 0, 3.3)
const ARC_RADIUS := 3.15
# angle round the curve (negative = the right-hand side as you come in), and which boss's machine it is
const SLOTS := [[-84.0, "jordan"], [-62.0, "glowinghumanity"], [-41.0, "debo"], [-20.0, "caffeinatedsloth"], [20.0, "discoman"], [41.0, "fatamy"], [62.0, "drmantis"], [84.0, "joeyrob"]]
const PLAYER_SLOT := 4
const PURPLE := Color(0.19, 0.07, 0.29)    # the counters and shelves
const TRIM := Color(0.25, 0.17, 0.32)      # beams, posts and mouldings
const WAIN_H := 1.25                       # height of the panelled lower wall

var machines: Array = []        # Cabinet, in the order of SLOTS
var player_index := PLAYER_SLOT
var spots: Array = []           # [id, label, floor position, point to face, colour]
var flickers: Array = []        # [material, base, speed, phase, machine index]
var sign_labels: Array = []
var prize_wall: PrizeWall
var hall: HallBoard
var progress: VRProgress
var pinball: Pinball
var vending: VendingMachine
var jukebox: Jukebox
var door: DoorScene
var ball_mat_spin: Node3D
var blockers: Array = []        # circles [centre x, centre z, radius] the player cannot walk through
var _active := -1


func build(root: Node3D, screen_tex: Texture2D, banner: Texture2D, font: Font, prog: VRProgress) -> void:
	progress = prog
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.01, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.33, 0.68)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var wood := VRBuild.tex_mat(_art("wall90.jpg", null), 0.35, 0.8)
	var paper := wood
	wood.texture_repeat = true
	_shell(root, wood, paper, font)
	_lights(root)
	door = DoorScene.new()
	door.build(root, FRONT_Z, HALF_W, HEIGHT, wood, paper, font)
	_machines(root)
	_back_wall(root, font)
	_decor(root, font)
	_spots()
	VRBuild.merge_static(root)


func _art(file: String, fallback: Texture2D) -> Texture2D:
	var t = load("res://assets/art/" + file)
	return t if t != null else fallback


# ---- the room itself ---------------------------------------------------------------------------------
func _shell(root: Node3D, wood: StandardMaterial3D, paper: StandardMaterial3D, font: Font) -> void:
	var w := HALF_W * 2.0
	var d := BACK_Z - FRONT_Z
	var cz := (BACK_Z + FRONT_Z) / 2.0
	var carpet := VRBuild.tex_mat(_art("carpet.jpg", VRBuild.carpet_texture()), 0.0, 0.95)
	carpet.uv1_scale = Vector3(w / 1.4, d / 1.4, 1)
	carpet.texture_repeat = true
	VRBuild.quad(root, Vector2(w, d), Vector3(0, 0, cz), carpet, Vector3(-PI / 2, 0, 0))
	var ceiling := VRBuild.tex_mat(_art("ceiling90.jpg", null), 0.35, 0.9)
	ceiling.uv1_scale = Vector3(w / 2.4, d / 2.4, 1)
	ceiling.texture_repeat = true
	VRBuild.quad(root, Vector2(w, d), Vector3(0, HEIGHT, cz), ceiling, Vector3(PI / 2, 0, 0))
	# the back wall and the two side walls (the front wall, with the door, belongs to the door scene)
	var walls := [[Vector3(0, 0, BACK_Z), PI, w], [Vector3(-HALF_W, 0, cz), PI / 2, d], [Vector3(HALF_W, 0, cz), -PI / 2, d]]
	var neon_a := VRBuild.mat(Color(1.0, 0.2, 0.7), 0.4, 0.0, 2.2)
	var neon_b := VRBuild.mat(Color(0.1, 0.9, 1.0), 0.4, 0.0, 2.2)
	var trim := VRBuild.mat(TRIM, 0.55)
	var k := 0
	for wall in walls:
		var root_w := Node3D.new()
		root_w.position = wall[0]
		root_w.rotation.y = wall[1]
		root.add_child(root_w)
		var wm: StandardMaterial3D = wood.duplicate()
		wm.uv1_scale = Vector3(wall[2] / 2.4, HEIGHT / 2.4, 1)
		wm.texture_repeat = true
		VRBuild.quad(root_w, Vector2(wall[2], HEIGHT), Vector3(0, HEIGHT / 2.0, 0), wm)
		VRBuild.box(root_w, Vector3(wall[2], 0.035, 0.035), Vector3(0, HEIGHT - 0.12, 0.03), neon_a)      # neon tube along the top of the wall
		VRBuild.box(root_w, Vector3(wall[2], 0.035, 0.035), Vector3(0, 0.12, 0.03), neon_b)             # and along the floor
		VRBuild.box(root_w, Vector3(wall[2], 0.1, 0.05), Vector3(0, 0.05, 0.025), VRBuild.mat(Color(0.02, 0.02, 0.04), 0.6))   # black skirting
		k += 1
	# neon tubes across the ceiling instead of beams and panels
	for z in [0.8, 2.6, 4.4, 6.2, 7.8]:
		var tube := neon_a if int(z * 10.0) % 2 == 0 else neon_b
		VRBuild.box(root, Vector3(w, 0.03, 0.03), Vector3(0, HEIGHT - 0.04, z), tube)


func _lights(root: Node3D) -> void:
	var specs := [
		[Vector3(-2.6, 2.7, 1.8), Color(1.0, 0.3, 0.75), 1.3, 6.0],
		[Vector3(2.6, 2.7, 1.8), Color(0.2, 0.85, 1.0), 1.3, 6.0],
		[Vector3(0.0, 2.8, 5.8), Color(1.0, 0.75, 0.45), 1.0, 6.5],
	]
	for s in specs:
		var l := OmniLight3D.new()
		l.position = s[0]
		l.light_color = s[1]
		l.light_energy = s[2]
		l.omni_range = s[3]
		root.add_child(l)


# ---- the six machines in a curve ---------------------------------------------------------------------
func _machines(root: Node3D) -> void:
	var bosses := {}
	for b in ZSEngine.BOSSES:
		bosses[b.id] = b
	var art_key := {"discoman": "disco", "drmantis": "mantis"}
	bosses["joeyrob"] = {"name": "JOEY ROB", "accent": "#7fd64a"}
	for i in range(SLOTS.size()):
		var a := deg_to_rad(float(SLOTS[i][0]))
		var id: String = SLOTS[i][1]
		var key: String = art_key.get(id, id)
		var pos := ARC_CENTRE + Vector3(sin(a) * ARC_RADIUS, 0, -cos(a) * ARC_RADIUS)
		var to_centre := ARC_CENTRE - pos
		var yaw := atan2(to_centre.x, to_centre.z)
		var c := Cabinet.new()
		c.position = pos
		c.rotation.y = yaw
		root.add_child(c)
		var accent := Color.html(str(bosses[id].accent))
		c.profile = CabProfile.get_profile("fatamy" if key == "joeyrob" else key)
		c.side_art = _art("side-%s.png" % key, null)
		var arena: Texture2D = _art("arena-%s.webp" % ("jordan" if id == "joeyrob" else id), null)
		c.build(arena, _art("marquee-%s.jpg" % key, null), accent.darkened(0.8), accent, true, str(bosses[id].name))
		VRBuild.quad(c, Vector2(2.3, 2.3), Vector3(0, 0.012, 0.85), _pool(accent), Vector3(-PI / 2, 0, 0))     # a soft pool of the machine's colour on the floor
		c.set_lock_light(i == player_index)      # red = somebody is playing here, green = free
		c.set_lit(i == player_index)
		machines.append(c)
		flickers.append([c.screen_mat, 1.0, 0.7 + i * 0.13, i * 1.7, i])
		blockers.append([pos.x - sin(yaw) * 0.3, pos.z - cos(yaw) * 0.3, 0.7])
	# a round rug and rings of light in the middle of the curve
	for ring_spec in [[2.14, 2.22, Color(1.0, 0.3, 0.75)], [1.5, 1.56, Color(0.2, 0.9, 1.0)]]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = ring_spec[0]
		tm.outer_radius = ring_spec[1]
		tm.rings = 64
		tm.ring_segments = 6
		ring.mesh = tm
		ring.scale = Vector3(1, 0.1, 1)
		ring.position = ARC_CENTRE + Vector3(0, 0.02, 0)
		ring.material_override = VRBuild.mat(ring_spec[2], 0.4, 0.0, 2.6)
		root.add_child(ring)
	_active = player_index


static var _pool_tex: GradientTexture2D


## A soft, round pool of coloured light (additive, no hard edge) for the floor in front of a machine.
func _pool(col: Color) -> StandardMaterial3D:
	if _pool_tex == null:
		_pool_tex = GradientTexture2D.new()
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		_pool_tex.gradient = g
		_pool_tex.fill = GradientTexture2D.FILL_RADIAL
		_pool_tex.fill_from = Vector2(0.5, 0.5)
		_pool_tex.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _pool_tex
	m.albedo_color = Color(col.r, col.g, col.b, 0.28)
	return m


func _mirror_ball_material() -> StandardMaterial3D:
	var m := VRBuild.tex_mat(VRBuild.grid_texture(Color(0.75, 0.78, 0.85), Color(0.35, 0.38, 0.5), 8), 0.5, 0.15)
	m.metallic = 0.85
	m.uv1_scale = Vector3(8, 4, 1)
	m.texture_repeat = true
	return m


## Marks which machine somebody is playing at: its light goes red and it gets the glow, the others show green.
func set_active(i: int) -> void:
	_active = i
	for k in range(machines.size()):
		machines[k].set_lock_light(k == i)
		machines[k].set_lit(k == i)
		if k != i:
			machines[k].set_live(null)


# ---- the back wall: prizes, pinball, hall of fame, vending ------------------------------------------------------
func _back_wall(root: Node3D, font: Font) -> void:
	prize_wall = PrizeWall.new()
	prize_wall.build(root, Vector3(-2.65, 0.0, BACK_Z - 0.2), PI, font)
	hall = HallBoard.new()
	hall.build(root, font, progress, Vector3(2.2, 1.85, BACK_Z - 0.08), PI)
	# the pinball machine between them, facing the door
	pinball = Pinball.new()
	pinball.position = Vector3(0, 0, BACK_Z - 0.82)
	pinball.rotation.y = PI
	root.add_child(pinball)
	pinball.build(font)
	_neon_sign(root, "neon-arcade.png", Vector3(0, 2.7, BACK_Z - 0.04), PI, Vector2(2.6, 0.78))
	_neon_sign(root, "neon-scores.png", Vector3(2.2, 2.78, BACK_Z - 0.04), PI, Vector2(1.9, 0.57))
	# the snack machine in the far corner on the left as you come in
	vending = VendingMachine.new()
	vending.position = Vector3(HALF_W - 0.42, 0, 5.1)       # against the right-hand wall, mirroring the jukebox
	vending.rotation.y = -PI / 2.0
	root.add_child(vending)
	vending.build(font)
	blockers.append([vending.position.x, vending.position.z, 0.75])
	blockers.append([0.0, BACK_Z - 1.05, 0.62])
	blockers.append([0.0, BACK_Z - 1.6, 0.42])


func _decor(root: Node3D, font: Font) -> void:
	# two matching wall plates beside the door: the JW Eds sign on the right, the Zombie Smash poster on the left
	_plate(root, Vector3(2.95, 2.0, FRONT_Z + 0.04), "jw-logo.png", Vector2(1.26, 0.53), true)
	_plate(root, Vector3(-2.95, 2.0, FRONT_Z + 0.04), "zs-poster.png", Vector2(1.42, 0.7), false)
	# the jukebox against the left wall
	jukebox = Jukebox.new()
	jukebox.position = Vector3(-HALF_W + 0.38, 0, 5.1)
	jukebox.rotation.y = PI / 2.0
	root.add_child(jukebox)
	jukebox.build(font)
	blockers.append([jukebox.position.x, jukebox.position.z, 0.65])
	# glowing wall art in the manner of a real arcade: pixel sprites and hexagon light fixtures
	_neon_sign(root, "wallart-chase.png", Vector3(-HALF_W + 0.04, 2.55, 5.1), PI / 2.0, Vector2(2.6, 0.62))
	_neon_sign(root, "wallart-invaders.png", Vector3(HALF_W - 0.04, 2.6, 5.1), -PI / 2.0, Vector2(2.0, 0.5))
	_neon_sign(root, "wallart-pad.png", Vector3(-2.0, 2.75, BACK_Z - 0.04), PI, Vector2(0.75, 0.43))
	_neon_sign(root, "wallart-stick.png", Vector3(2.0, 2.75, BACK_Z - 0.04), PI, Vector2(0.5, 0.5))
	_neon_sign(root, "wallart-heart.png", Vector3(-HALF_W + 0.04, 2.3, 7.3), PI / 2.0, Vector2(0.6, 0.52))
	for hx in [[-2.2, 2.2, "hex-blue.png"], [2.3, 4.6, "hex-pink.png"], [-1.0, 6.8, "hex-blue.png"]]:
		var hm := VRBuild.tex_mat(_art(hx[2], null), 0.0, 0.5, true)
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		VRBuild.quad(root, Vector2(2.6, 2.6), Vector3(hx[0], HEIGHT - 0.03, hx[1]), hm, Vector3(PI / 2, 0, 0))
	_neon_sign(root, "neon-gameon.png", Vector3(-HALF_W + 0.04, 2.92, 3.8), PI / 2.0, Vector2(1.3, 0.39))
	_neon_sign(root, "neon-player1.png", Vector3(HALF_W - 0.04, 2.92, 3.8), -PI / 2.0, Vector2(1.3, 0.39))
	# the boss arenas as framed pictures between the posters
	var arenas := ["arena-jordan.webp", "arena-debo.webp", "arena-fatamy.webp", "arena-drmantis.webp"]
	var ai := 0
	for side in [-1, 1]:
		for z in ([2.95] if side == 1 else [2.95, 4.7]):
			var fr := Node3D.new()
			fr.position = Vector3(side * (HALF_W - 0.04), 1.75, z)
			fr.rotation.y = -side * PI / 2.0
			root.add_child(fr)
			var at: Texture2D = load("res://assets/art/" + arenas[ai])
			VRBuild.box(fr, Vector3(0.8, 0.52, 0.03), Vector3.ZERO, VRBuild.mat(Color(0.04, 0.03, 0.06), 0.4, 0.4))
			VRBuild.quad(fr, Vector2(0.75, 0.47), Vector3(0, 0, 0.017), VRBuild.tex_mat(at, 0.3, 0.6))
			ai += 1
	# six posters, three on each side wall
	var posters := ["poster-1.jpg", "poster-2.jpg", "poster-3.jpg", "poster-4.jpg", "poster-5.jpg", "poster-6.jpg"]
	var k := 0
	for side in [-1, 1]:
		for z in [1.3, 3.8, 6.3]:
			var holder := Node3D.new()
			holder.position = Vector3(side * (HALF_W - 0.04), 2.1, z)
			holder.rotation.y = -side * PI / 2.0
			root.add_child(holder)
			var t: Texture2D = load("res://assets/art/" + posters[k])
			VRBuild.box(holder, Vector3(0.82, 1.2, 0.03), Vector3.ZERO, VRBuild.mat(Color(0.03, 0.02, 0.05), 0.5))
			VRBuild.quad(holder, Vector2(0.8, 1.18), Vector3(0, 0, 0.017), VRBuild.tex_mat(t, 0.45, 0.6, false, Color(1, 1, 1)))
			k += 1


## A glowing neon tube sign on a wall (yaw turns it to face into the room).
func _neon_sign(root: Node3D, file: String, pos: Vector3, yaw: float, size: Vector2) -> void:
	var t = load("res://assets/art/" + file)
	if t == null:
		return
	var m := VRBuild.tex_mat(t, 0.0, 0.5, true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	root.add_child(holder)
	VRBuild.quad(holder, size, Vector3(0, 0, 0.02), m)


## A wall-mounted plate on brushed steel standoffs with its own spotlight.
func _plate(root: Node3D, pos: Vector3, file: String, art_size: Vector2, transparent: bool) -> void:
	var tex = load("res://assets/art/" + file)
	var plate := Node3D.new()
	plate.position = pos
	root.add_child(plate)
	var steel := RuinedExterior.surface("materials", 3, Color(0.95, 0.96, 1.0), 0.2)
	var charcoal := VRBuild.mat(Color(0.05, 0.05, 0.07), 0.35, 0.3)
	VRBuild.box(plate, Vector3(1.5, 0.74, 0.03), Vector3(0, 0, 0.03), charcoal)
	for sx in [-0.7, 0.7]:
		for sy in [-0.33, 0.33]:
			VRBuild.cylinder(plate, 0.012, 0.03, Vector3(sx, sy, 0.0), steel, -1.0, Vector3(PI / 2, 0, 0), 12)
			VRBuild.cylinder(plate, 0.018, 0.008, Vector3(sx, sy, 0.047), steel, -1.0, Vector3(PI / 2, 0, 0), 12)
	VRBuild.box(plate, Vector3(1.54, 0.012, 0.04), Vector3(0, 0.375, 0.03), steel)
	VRBuild.box(plate, Vector3(1.54, 0.012, 0.04), Vector3(0, -0.375, 0.03), steel)
	if tex != null:
		var lm := VRBuild.tex_mat(tex, 0.45, 0.4)
		if transparent:
			lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lm.emission_enabled = true
		lm.emission_texture = tex
		lm.emission_energy_multiplier = 0.5
		VRBuild.quad(plate, art_size, Vector3(0, 0, 0.047), lm)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 0.55, 0.5)
	spot.rotation = Vector3(-1.1, 0, 0)
	spot.spot_range = 2.2
	spot.spot_angle = 38.0
	spot.light_energy = 2.2
	spot.light_color = Color(1.0, 0.95, 0.85)
	plate.add_child(spot)
	VRBuild.box(plate, Vector3(0.1, 0.05, 0.22), Vector3(0, 0.45, 0.14), charcoal)


# ---- where the player can jump to --------------------------------------------------------------------------------
func _spots() -> void:
	for i in range(machines.size()):
		var m: Cabinet = machines[i]
		spots.append(["m%d" % i, "PLAY", m.stand_world(), m.look_world(), m.theme_color])
	spots.append(["pinball", "PINBALL", pinball.stand_world(), pinball.look_world(), Color(1.0, 0.85, 0.2)])
	spots.append(["prizes_a", "PRIZES", Vector3(-3.3, 0, BACK_Z - 1.55), Vector3(-3.3, 1.5, BACK_Z), Color(1.0, 0.35, 0.75)])
	spots.append(["prizes_b", "PRIZES", Vector3(-2.0, 0, BACK_Z - 1.55), Vector3(-2.0, 1.5, BACK_Z), Color(1.0, 0.35, 0.75)])
	spots.append(["hall", "HALL OF FAME", Vector3(2.2, 0, BACK_Z - 2.2), Vector3(2.2, 1.8, BACK_Z), Color(1.0, 0.82, 0.25)])
	spots.append(["vending", "SNACKS", Vector3(HALF_W - 1.5, 0, 5.1), Vector3(vending.position.x, 1.0, vending.position.z), Color(1.0, 0.45, 0.4)])
	spots.append(["jukebox", "JUKEBOX", Vector3(-2.95, 0, 5.1), Vector3(jukebox.position.x, 1.2, jukebox.position.z), Color(1.0, 0.7, 0.3)])
	spots.append(["exit", "EXIT", Vector3(0, 0, 0.75), Vector3(0, 1.4, FRONT_Z), Color(0.3, 1.0, 0.45)])


## Keeps a walking player out of walls, machines and counters.
func collide(p: Vector3) -> Vector3:
	var out := Vector3(clampf(p.x, -HALF_W + 0.35, HALF_W - 0.35), 0.0, clampf(p.z, FRONT_Z + 0.5, BACK_Z - 0.4))
	for b in blockers:
		var d := Vector2(out.x - b[0], out.z - b[1])
		var r: float = float(b[2]) + 0.2
		if d.length() < r:
			var n := d.normalized() if d.length() > 0.001 else Vector2(0, 1)
			out.x = b[0] + n.x * r
			out.z = b[1] + n.y * r
	if out.z > BACK_Z - 0.7 and out.x < -0.8:
		out.z = BACK_Z - 0.7
	if out.z > BACK_Z - 0.7 and out.x > 0.8 and out.x < 3.4:
		out.z = BACK_Z - 0.7
	return out


func animate(t: float) -> void:
	for f in flickers:
		if f[4] == _active:
			continue
		var m: StandardMaterial3D = f[0]
		var k: float = 0.78 + 0.22 * sin(t * f[2] + f[3]) + (0.06 if int(t * 7.0 + f[3]) % 17 == 0 else 0.0)
		m.albedo_color = Color(k, k, k)
	if ball_mat_spin != null:
		ball_mat_spin.rotation.y = t * 0.4
	for l in sign_labels:
		var on := 0.75 + 0.25 * (1.0 if int(t * 3.0) % 11 != 0 else 0.4)
		l.modulate.a = on
