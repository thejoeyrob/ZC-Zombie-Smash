class_name ArcadeRoom
extends RefCounted
## The old-school arcade. A double door in the front wall opens onto a night car park. Six machines stand in a curve either side
## of the door (a place for each player of a party), the pinball machine faces the door from the back wall between the prize
## shelves and the hall of fame, and a snack machine waits in the far corner.

const HALF_W := 4.0
const FRONT_Z := -0.55
const BACK_Z := 7.3
const HEIGHT := 3.2
const ARC_CENTRE := Vector3(0, 0, 2.9)
const ARC_RADIUS := 2.7
# angle round the curve (negative = the right-hand side as you come in), and which boss's machine it is
# [x, z, yaw in degrees, which boss]: four machines along each side wall, each turned a little toward the lounge so its painted side faces the door
const SLOTS := [[-3.13, 1.2, 74.0, "joeyrob"], [-3.13, 5.1, 106.0, "drmantis"],
	[3.13, 1.2, -74.0, "discoman"], [3.13, 5.1, -106.0, "fatamy"]]
# display machines built from the red cabinet model: [x, z, yaw degrees, variation]. They are for atmosphere; the playable machines are SLOTS.
const RETRO := [[-3.13, 3.15, 90.0, "mortalkombat"], [3.13, 3.15, -90.0, "pacman"],
	[-2.05, 6.43, 180.0, "galaga"], [-2.85, 6.43, 180.0, "asteroids"], [-3.65, 6.43, 180.0, "centipede"]]
const PLAYER_SLOT := 0
const PURPLE := Color(0.19, 0.07, 0.29)    # the counters and shelves
const TRIM := Color(0.25, 0.17, 0.32)      # beams, posts and mouldings
const WAIN_H := 1.25                       # height of the panelled lower wall

var machines: Array = []        # Cabinet, in the order of SLOTS
var player_index := PLAYER_SLOT
var seats: Array = []           # [id, bean bag position, point to face] for each bean bag you can sit on
var spots: Array = []           # [id, label, floor position, point to face, colour]
var flickers: Array = []        # [material, base, speed, phase, machine index]
var sign_labels: Array = []
var prize_wall: PrizeWall
var hall: HallBoard
var progress: VRProgress
var pinball: Pinball
var pinball2: Pinball
var board_game: BoardGame
var vending: VendingMachine
var jukebox: Jukebox
var door: DoorScene
var ball_mat_spin: Node3D
var blockers: Array = []        # circles [centre x, centre z, radius] the player cannot walk through
var _active := -1


func build(root: Node3D, screen_tex: Texture2D, banner: Texture2D, font: Font, prog: VRProgress) -> void:
	progress = prog
	_font_ref = font
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
	# real dark brick walls with neon tubes, like a proper old arcade
	# real dark brick: a photographed medieval brick set (colour, bumps and roughness), darkened for the late-night mood
	var wood := VRBuild.pbr("brick", Color(0.5, 0.44, 0.5), Vector2.ONE, 2.4)
	var paper := wood
	wood.texture_repeat = true
	_shell(root, wood, paper, font)
	_lights(root)
	door = DoorScene.new()
	door.build(root, FRONT_Z, HALF_W, HEIGHT, wood, paper, font)
	_machines(root)
	_retro(root)
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
	var carpet := VRBuild.pbr("tiles-bw", Color(0.58, 0.58, 0.6), Vector2(w / 1.6, d / 1.6), 0.9)       # black and white worn floor tiles
	VRBuild.quad(root, Vector2(w, d), Vector3(0, 0, cz), carpet, Vector3(-PI / 2, 0, 0))
	var ceiling := VRBuild.pbr("tiles", Color(0.22, 0.22, 0.3), Vector2(w / 2.4, d / 2.4), 0.8)      # dark ceiling tiles
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
		if k == 0:
			# the back wall (shelves, pinball, high scores) is lighter, warmer brick so everything on it pops
			wm = VRBuild.pbr("brick-light", Color(0.85, 0.62, 0.52), Vector2.ONE, 2.4)
		wm.uv1_scale = Vector3(wall[2] / 2.4, HEIGHT / 2.4, 1)
		wm.texture_repeat = true
		VRBuild.quad(root_w, Vector2(wall[2], HEIGHT), Vector3(0, HEIGHT / 2.0, 0), wm)
		VRBuild.neon_tube(root_w, wall[2], Vector3(0, HEIGHT - 0.12, 0.04), Color(1.0, 0.2, 0.7))      # neon tube along the top of the wall
		VRBuild.neon_tube(root_w, wall[2], Vector3(0, 0.12, 0.04), Color(0.1, 0.9, 1.0))             # and along the floor
		VRBuild.box(root_w, Vector3(wall[2], 0.1, 0.05), Vector3(0, 0.05, 0.025), VRBuild.pbr("wood-green", Color(0.8, 0.9, 0.8), Vector2(wall[2] / 0.9, 0.12), 1.4))   # green washed wood skirting
		k += 1
	# neon tubes across the ceiling instead of beams and panels
	for z in [1.4, 3.4, 5.4]:
		var tube_col := Color(1.0, 0.2, 0.7) if int(z * 10.0) % 2 == 0 else Color(0.1, 0.9, 1.0)
		VRBuild.neon_tube(root, w, Vector3(0, HEIGHT - 0.05, z), tube_col, Vector3.ZERO, 0.02)


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
var _font_ref: Font


func _machines(root: Node3D) -> void:
	var bosses := {}
	for b in ZSEngine.BOSSES:
		bosses[b.id] = b
	var art_key := {"discoman": "disco", "drmantis": "mantis"}
	bosses["joeyrob"] = {"name": "JOEY ROB", "accent": "#7fd64a"}
	for i in range(SLOTS.size()):
		var id: String = SLOTS[i][3]
		var key: String = art_key.get(id, id)
		var pos := Vector3(float(SLOTS[i][0]), 0, float(SLOTS[i][1]))
		var yaw := deg_to_rad(float(SLOTS[i][2]))
		var c := Cabinet.new()
		c.position = pos
		c.rotation.y = yaw
		root.add_child(c)
		var accent := Color.html(str(bosses[id].accent))
		c.bezel_id = id
		c.profile = CabProfile.get_profile("standard")
		c.side_art = _art("side-%s-flat.png" % ("fatamy" if key == "joeyrob" and false else key), _art("side-%s.png" % key, null))
		c.side_text = id in ["joeyrob"]       # these two sides have writing on them: keep it readable on both
		var arena: Texture2D = _art("arena-%s.webp" % ("jordan" if id == "joeyrob" else id), null)
		c.build(arena, _art("marquee-%s.jpg" % key, null), accent.darkened(0.8), accent, true, str(bosses[id].name))
		c.set_lock_light(i == player_index)      # red = somebody is playing here, green = free
		c.set_lit(i == player_index)
		machines.append(c)
		flickers.append([c.screen_mat, 1.0, 0.7 + i * 0.13, i * 1.7, i])
		blockers.append([pos.x - sin(yaw) * 0.3, pos.z - cos(yaw) * 0.3, 0.7])
	# a round rug and rings of light in the middle of the curve
	_lounge(root, _font_ref)
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


# ---- the social corner: a tall table with an old Chutes & Ladders board, and six leather-topped bar stools -------------------
func _lounge(root: Node3D, font_ref: Font = null) -> void:
	var c := ARC_CENTRE
	var brushed := VRBuild.pbr("metal", Color(1, 1, 1), Vector2(1, 3), 0.9)                       # brushed steel poles
	var black_metal := VRBuild.mat(Color(0.025, 0.025, 0.03), 0.38, 0.85)                          # black metal bases
	var cols := ["pink", "cyan", "amber", "green", "purple", "red"]
	var tints := {"pink": Color(1.0, 0.42, 0.7), "cyan": Color(0.35, 0.85, 1.0), "amber": Color(1.0, 0.62, 0.12), "green": Color(0.5, 0.95, 0.3), "purple": Color(0.7, 0.45, 1.0), "red": Color(1.0, 0.18, 0.18)}
	# six stools: one each side of the table, two on each long side
	var spots_xz := [Vector2(-0.95, 0.0), Vector2(0.95, 0.0), Vector2(-0.24, -0.86), Vector2(0.24, -0.86), Vector2(-0.24, 0.86), Vector2(0.24, 0.86)]
	for i in range(spots_xz.size()):
		var sp: Vector2 = spots_xz[i]
		var stool := Node3D.new()
		stool.position = c + Vector3(sp.x, 0, sp.y)
		root.add_child(stool)
		VRBuild.cylinder(stool, 0.19, 0.022, Vector3(0, 0.011, 0), black_metal, 0.2, Vector3.ZERO, 36)         # black metal base
		VRBuild.cylinder(stool, 0.032, 0.62, Vector3(0, 0.33, 0), brushed, -1.0, Vector3.ZERO, 24)               # brushed metal support pole
		var ring := MeshInstance3D.new()                                                                          # foot rest
		var tm := TorusMesh.new()
		tm.inner_radius = 0.125
		tm.outer_radius = 0.142
		tm.rings = 32
		tm.ring_segments = 10
		ring.mesh = tm
		ring.material_override = brushed
		ring.position = Vector3(0, 0.27, 0)
		stool.add_child(ring)
		for k in range(4):                                                                                        # four struts holding the ring
			var ang := TAU * float(k) / 4.0 + 0.4
			VRBuild.cylinder(stool, 0.006, 0.15, Vector3(sin(ang) * 0.065, 0.27, cos(ang) * 0.065), brushed, -1.0, Vector3(cos(ang) * PI / 2.0, 0, -sin(ang) * PI / 2.0), 8)
		VRBuild.cylinder(stool, 0.07, 0.025, Vector3(0, 0.63, 0), black_metal, 0.04, Vector3.ZERO, 24)           # the seat plate
		var lm := VRBuild.pbr("leather-neutral", tints[cols[i]], Vector2(1.6, 1.6), 1.6)   # the same grained leather in each colour
		lm.clearcoat_enabled = true
		lm.clearcoat = 0.25
		VRBuild.cylinder(stool, 0.185, 0.07, Vector3(0, 0.68, 0), lm, 0.175, Vector3.ZERO, 40)                    # leather seat top
		var dome := VRBuild.sphere(stool, 0.178, Vector3(0, 0.715, 0), lm, 32)                                    # the padded dome
		dome.scale = Vector3(1.0, 0.2, 1.0)
		seats.append(["sit%d" % i, stool.position, c + Vector3(0, 0.9, 0), 0.22])
		blockers.append([stool.position.x, stool.position.z, 0.22])
	# the tall table
	var table := Node3D.new()
	table.position = c
	root.add_child(table)
	VRBuild.cylinder(table, 0.3, 0.025, Vector3(0, 0.0125, 0), black_metal, 0.32, Vector3.ZERO, 40)             # black metal base
	VRBuild.cylinder(table, 0.05, 0.98, Vector3(0, 0.5, 0), brushed, -1.0, Vector3.ZERO, 28)                    # brushed metal pole
	VRBuild.cylinder(table, 0.12, 0.03, Vector3(0, 0.965, 0), black_metal, 0.08, Vector3.ZERO, 28)              # the plate under the top
	var wood_edge := VRBuild.pbr("wood-navy", Color(0.75, 0.7, 0.65), Vector2(1.2, 0.2), 1.2)                    # old worn painted wood
	VRBuild.box(table, Vector3(0.84, 0.05, 0.84), Vector3(0, 1.0, 0), wood_edge)                                  # the board's wooden frame and body
	VRBuild.box(table, Vector3(0.86, 0.012, 0.86), Vector3(0, 0.972, 0), black_metal)
	var game := VRBuild.tex_mat(_art("boardgame-zs.jpg", null), 0.0, 0.7)
	game.normal_enabled = true
	game.normal_texture = _art("pbr-wood-navy-n.png", null)
	game.normal_scale = 0.3
	VRBuild.quad(table, Vector2(0.76, 0.76), Vector3(0, 1.0262, 0), game, Vector3(-PI / 2, 0, 0))                # the board's artwork
	board_game = BoardGame.new()                                                                                    # the playable game: pieces, die and rules
	board_game.position = c + Vector3(0, 1.028, 0)
	root.add_child(board_game)
	board_game.build(font_ref)
	blockers.append([c.x, c.z, 0.5])


# ---- the back wall: prizes, pinball, hall of fame, vending ------------------------------------------------------
func _back_wall(root: Node3D, font: Font) -> void:
	prize_wall = PrizeWall.new()          # the prize shelves are gone: the object stays (empty) so the rest of the game can keep talking to it
	hall = HallBoard.new()
	hall.build(root, font, progress, Vector3(2.95, 1.85, BACK_Z - 0.08), PI)
	hall.scale = Vector3(0.74, 0.74, 1.0)       # a little smaller, to leave room for the Zombie Smash promo corner
	# the pinball machine between them, facing the door
	pinball = Pinball.new()
	pinball.position = Vector3(0, 0, BACK_Z - 0.82)
	pinball.rotation.y = PI
	root.add_child(pinball)
	pinball.build(font)
	# a second pinball machine, a little way along the back wall
	pinball2 = Pinball.new()
	pinball2.position = Vector3(-1.05, 0, BACK_Z - 0.82)
	pinball2.rotation.y = PI
	root.add_child(pinball2)
	pinball2.build(font)
	blockers.append([-1.05, BACK_Z - 1.05, 0.62])
	blockers.append([-1.05, BACK_Z - 1.6, 0.25])
	_neon_sign(root, "neon-arcade.png", Vector3(0, 2.7, BACK_Z - 0.04), PI, Vector2(2.6, 0.78))
	_neon_sign(root, "neon-scores.png", Vector3(2.95, 2.62, BACK_Z - 0.04), PI, Vector2(1.5, 0.45))
	# the snack machine beside the door
	vending = VendingMachine.new()
	vending.position = Vector3(1.8, 0, -0.05)       # beside the door, inside on the right
	vending.rotation.y = 0.0
	root.add_child(vending)
	vending.build(font)
	blockers.append([vending.position.x, vending.position.z, 0.75])
	blockers.append([0.0, BACK_Z - 1.05, 0.62])
	blockers.append([0.0, BACK_Z - 1.6, 0.25])


func _decor(root: Node3D, font: Font) -> void:
	# two matching wall plates beside the door: the JW Eds sign on the right, the Zombie Smash poster on the left
	_signboard(root, Vector3(2.95, 2.6, FRONT_Z), 0.0, "jw-logo.png", Vector2(1.26, 0.53), Color(0.2, 0.85, 1.0), true)
	_signboard(root, Vector3(-2.95, 2.6, FRONT_Z), 0.0, "zs-poster.png", Vector2(1.42, 0.7), Color(0.6, 1.0, 0.2), false)
	# the Zombie Smash promo corner on the back wall next to the pinball machine: a lit poster and a life-size Joey Rob cut-out
	_signboard(root, Vector3(1.12, 2.0, BACK_Z), PI, "zs-poster.png", Vector2(1.3, 0.64), Color(0.6, 1.0, 0.2), false)

	# the jukebox against the left wall
	jukebox = Jukebox.new()
	jukebox.position = Vector3(-1.85, 0, -0.3)      # beside the door, inside on the left
	jukebox.rotation.y = 0.0
	root.add_child(jukebox)
	jukebox.build(font)
	blockers.append([jukebox.position.x, jukebox.position.z, 0.65])
	# four framed posters, only in the gaps on the side walls between the machines
	_frame(root, _art("poster-fire.jpg", null), Vector3(-HALF_W + 0.04, 2.0, 2.18), 1.0)
	_frame(root, _art("poster-neon.jpg", null), Vector3(-HALF_W + 0.04, 2.0, 4.12), 1.0)
	_frame(root, _art("poster-mantis.jpg", null), Vector3(HALF_W - 0.04, 2.0, 2.18), -1.0)
	_frame(root, _art("poster-radiant.jpg", null), Vector3(HALF_W - 0.04, 2.0, 4.12), -1.0)


## A picture hung flat on a side wall (side: +1 left wall, -1 right wall): no frame, just the artwork on a thin dark backing with a soft shadow.
func _frame(root: Node3D, t: Texture2D, pos: Vector3, side: float) -> void:
	var holder := Node3D.new()
	var wall_x := -HALF_W + 0.04 if side > 0.0 else HALF_W - 0.04
	holder.position = Vector3(wall_x, pos.y, pos.z)
	holder.rotation.y = side * PI / 2.0
	root.add_child(holder)
	var h := 1.08
	var w := minf(0.9, h * float(t.get_width()) / float(t.get_height()))
	VRBuild.box(holder, Vector3(w + 0.016, h + 0.016, 0.012), Vector3(0, 0, 0.004), VRBuild.mat(Color(0.02, 0.015, 0.03), 0.6))
	VRBuild.quad(holder, Vector2(w, h), Vector3(0, 0, 0.012), VRBuild.tex_mat(t, 0.8, 0.5))


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


## The display machines (red cabinet model) with the art of famous retro games, for atmosphere. Not playable.
func _retro(root: Node3D) -> void:
	var looks := {
		"mortalkombat": {"side": "retro-mk-side.jpg", "marquee": "retro-mk-marquee.jpg", "screen": "", "trim": Color(0.75, 0.05, 0.05), "btn_a": Color(0.9, 0.1, 0.1), "btn_b": Color(0.1, 0.1, 0.12), "btn_c": Color(1, 0.8, 0.1), "mirror": false},
		"galaga": {"side": "retro-galaga-side.jpg", "marquee": "retro-galaga-marquee.jpg", "screen": "retro-galaga-screen.jpg", "trim": Color(0.2, 0.3, 0.9), "btn_a": Color(0.9, 0.1, 0.1), "btn_b": Color(0.2, 0.5, 1), "btn_c": Color(1, 1, 1), "mirror": true},
		"asteroids": {"side": "retro-asteroids-side.jpg", "marquee": "retro-asteroids-marquee.jpg", "screen": "", "trim": Color(0.1, 0.35, 0.9), "btn_a": Color(0.9, 0.1, 0.1), "btn_b": Color(1, 1, 1), "btn_c": Color(1, 1, 1), "mirror": true},
		"centipede": {"side": "", "marquee": "retro-centipede-marquee.jpg", "screen": "", "trim": Color(0.2, 0.75, 0.25), "btn_a": Color(0.9, 0.1, 0.1), "btn_b": Color(1, 0.85, 0.1), "btn_c": Color(0.3, 0.6, 1), "mirror": true},
		"pacman": {"side": "retro-pacman-side.jpg", "marquee": "retro-pacman-marquee.jpg", "screen": "retro-pacman-screen.jpg", "trim": Color(1.0, 0.85, 0.05), "btn_a": Color(1, 0.2, 0.1), "btn_b": Color(1, 0.85, 0.1), "btn_c": Color(0.3, 0.6, 1), "mirror": false},
	}
	for r in RETRO:
		var look: Dictionary = looks[r[3]]
		var m := ModelMachine.new()
		m.position = Vector3(float(r[0]), 0, float(r[1]))
		m.rotation.y = deg_to_rad(float(r[2]))
		root.add_child(m)
		m.build({"side": _art(look.side, null) if look.side != "" else null, "marquee": _art(look.marquee, null), "screen": _art(look.screen, null) if look.screen != "" else null,
			"trim": look.trim, "btn_a": look.btn_a, "btn_b": look.btn_b, "btn_c": look.btn_c, "mirror_right": look.mirror})
		blockers.append([m.position.x - sin(deg_to_rad(float(r[2]))) * 0.3, m.position.z - cos(deg_to_rad(float(r[2]))) * 0.3, 0.7])


## A sign that stands proud of the brick: a brushed-steel frame on four standoffs, a lit face, and a soft glow on the wall behind it.
## yaw 0 faces +z (the front wall), PI faces -z (the back wall).
func _signboard(root: Node3D, pos: Vector3, yaw: float, file: String, art_size: Vector2, glow: Color, transparent: bool) -> void:
	var tex = load("res://assets/art/" + file)
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	root.add_child(holder)
	var steel := VRBuild.pbr("metal", Color(0.9, 0.9, 0.95), Vector2(2, 1), 0.9)
	var dark := VRBuild.pbr("plate-blue", Color(0.2, 0.2, 0.26), Vector2(1, 1), 0.9)
	var w := art_size.x + 0.1
	var h := art_size.y + 0.1
	var off := 0.075                                   # how far the sign stands from the wall
	# the glow on the brick behind the sign (additive, no hard edge)
	var halo := _pool(glow)
	halo.albedo_color = Color(glow.r, glow.g, glow.b, 0.65)
	VRBuild.quad(holder, Vector2(w * 1.9, h * 2.3), Vector3(0, 0, 0.012), halo)
	# four standoffs
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			VRBuild.cylinder(holder, 0.013, off, Vector3(sx * (w / 2.0 - 0.05), sy * (h / 2.0 - 0.05), off / 2.0), steel, -1.0, Vector3(PI / 2, 0, 0), 12)
			VRBuild.cylinder(holder, 0.022, 0.012, Vector3(sx * (w / 2.0 - 0.05), sy * (h / 2.0 - 0.05), off + 0.012), steel, 0.02, Vector3(PI / 2, 0, 0), 12)
	# the sign body: a deep dark back, a steel frame round the face
	VRBuild.box(holder, Vector3(w, h, 0.045), Vector3(0, 0, off + 0.0225), dark)
	VRBuild.box(holder, Vector3(w + 0.03, 0.035, 0.07), Vector3(0, h / 2.0, off + 0.035), steel)
	VRBuild.box(holder, Vector3(w + 0.03, 0.035, 0.07), Vector3(0, -h / 2.0, off + 0.035), steel)
	VRBuild.box(holder, Vector3(0.035, h, 0.07), Vector3(-w / 2.0, 0, off + 0.035), steel)
	VRBuild.box(holder, Vector3(0.035, h, 0.07), Vector3(w / 2.0, 0, off + 0.035), steel)
	if tex != null:
		var fm := VRBuild.tex_mat(tex, 0.55, 0.4)
		if transparent:
			fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.emission_enabled = true
		fm.emission_texture = tex
		fm.emission_energy_multiplier = 0.7
		VRBuild.quad(holder, art_size, Vector3(0, 0, off + 0.047), fm)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, h / 2.0 + 0.2, 0.55)
	spot.rotation = Vector3(-1.2, 0, 0)
	spot.spot_range = 2.4
	spot.spot_angle = 40.0
	spot.light_energy = 1.6
	spot.light_color = Color(1.0, 0.95, 0.85)
	holder.add_child(spot)


## A life-size cardboard cut-out of Joey Rob: the printed face, a plain cardboard back and edge, a white die-cut border, and a strut behind.
func _cutout(root: Node3D, pos: Vector3, yaw: float) -> void:
	var tex = _art("cutout-joey.png", null)
	if tex == null:
		return
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	root.add_child(holder)
	var h := 1.78
	var w := h * float(tex.get_width()) / float(tex.get_height())
	var card := VRBuild.pbr("leather-neutral", Color(0.62, 0.45, 0.28), Vector2(2, 2), 0.6)       # brown cardboard
	card.albedo_texture = null
	card.albedo_color = Color(0.58, 0.42, 0.26)
	card.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	card.alpha_scissor_threshold = 0.5
	card.albedo_texture = tex
	card.albedo_color = Color(0.45, 0.32, 0.2)
	card.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(7):                                # the thickness of the board, a stack of thin slices
		VRBuild.quad(holder, Vector2(w, h), Vector3(0, h / 2.0, -0.004 - float(i) * 0.0035), card)
	var print_m := VRBuild.tex_mat(tex, 0.12, 0.7)
	print_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	print_m.alpha_scissor_threshold = 0.5
	VRBuild.quad(holder, Vector2(w, h), Vector3(0, h / 2.0, 0.002), print_m)
	var strut := VRBuild.mat(Color(0.5, 0.36, 0.22), 0.9)
	VRBuild.box(holder, Vector3(0.5, 1.1, 0.012), Vector3(0, 0.55, -0.34), strut, Vector3(-0.3, 0, 0))     # the easel strut propping it up
	# a small spotlight picks it out
	var spot := SpotLight3D.new()
	spot.position = Vector3(0.2, 2.9, 1.3)
	spot.look_at_from_position(Vector3(0.2, 2.9, 1.3), Vector3(0, 1.0, 0), Vector3.UP)
	spot.spot_range = 4.0
	spot.spot_angle = 30.0
	spot.light_energy = 2.2
	spot.light_color = Color(1.0, 0.92, 0.8)
	holder.add_child(spot)
	blockers.append([pos.x, pos.z, 0.5])


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
	spots.append(["pinball2", "PINBALL", pinball2.stand_world(), pinball2.look_world(), Color(1.0, 0.85, 0.2)])
	spots.append(["hall", "HALL OF FAME", Vector3(2.95, 0, BACK_Z - 2.2), Vector3(2.95, 1.8, BACK_Z), Color(1.0, 0.82, 0.25)])
	spots.append(["vending", "SNACKS", Vector3(1.8, 0, 1.3), Vector3(vending.position.x, 1.0, vending.position.z), Color(1.0, 0.45, 0.4)])
	spots.append(["jukebox", "JUKEBOX", Vector3(-1.85, 0, 1.3), Vector3(jukebox.position.x, 1.2, jukebox.position.z), Color(1.0, 0.7, 0.3)])
	spots.append(["lounge", "LOUNGE", ARC_CENTRE + Vector3(0, 0, -1.7), ARC_CENTRE + Vector3(0, 0.4, 0), Color(1.0, 0.45, 0.85)])
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
