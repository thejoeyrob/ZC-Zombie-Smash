class_name ShackAnnex
extends RefCounted
## The sports hall behind the arcade's back wall (through the gate in the back-left corner): darts along the left wall, three axe-throwing lanes
## at the far end, and two bowling lanes down the right side. This builds the walls, floor, lights and the fixed scenery; the games themselves
## (darts_game.gd, axe_game.gd, bowling_game.gd) add the things you pick up and throw.

const Z0 := 7.3                    # the arcade's back wall, which is the front wall of the hall
const DEPTH := 14.0
const Z1 := Z0 + DEPTH             # the far wall
const HALF_W := 4.0
const HEIGHT := 3.4
const GATE_X := 0.0                # the wide opening in the arcade's back wall, between the two pinball machines (world x of its middle)
const GATE_W := 2.4
const GATE_H := 2.6

# darts: two boards on the left wall, throw line (the oche) 2.37 m in front of each
const DART_FACE_X := -HALF_W + 0.07
const DART_Z := [9.7, 11.55]
const DART_Y := 1.73
const OCHE_X := DART_FACE_X + 2.37
# axe throwing: three lanes at the far end, throw line 3.66 m (12 feet) from the targets
const AXE_FACE_Z := Z1 - 0.08
const AXE_X := [-3.0, -1.75, -0.5]
const AXE_Y := 1.52
const AXE_LINE_Z := AXE_FACE_Z - 3.66
# bowling: two lanes down the right side
const LANE_X := [1.3, 2.95]
const LANE_W := 1.05
const GUTTER_W := 0.24
const FOUL_Z := 9.7
const HEAD_PIN_Z := 19.9

var node: Node3D
var font: Font
var lights: Array = []


func build(parent: Node3D, f: Font) -> void:
	font = f
	node = Node3D.new()
	node.name = "Annex"
	parent.add_child(node)
	_shell()
	_gate_trim()
	_darts_scenery()
	_axe_scenery()
	_bowling_scenery()
	_lobby_signs()
	VRBuild.merge_static(node, true)


func set_active(on: bool) -> void:
	node.visible = on


# ---- the hall -----------------------------------------------------------------------------------------
func _shell() -> void:
	var cz := (Z0 + Z1) / 2.0
	var floor_m := VRBuild.pbr("tiles-bw", Color(0.62, 0.62, 0.68), Vector2(HALF_W * 2.0 / 1.6, DEPTH / 1.6), 0.9)
	VRBuild.quad(node, Vector2(HALF_W * 2.0, DEPTH), Vector3(0, 0, cz), floor_m, Vector3(-PI / 2, 0, 0))
	var ceil_m := VRBuild.pbr("tiles", Color(0.2, 0.2, 0.28), Vector2(HALF_W * 2.0 / 2.4, DEPTH / 2.4), 0.8)
	VRBuild.quad(node, Vector2(HALF_W * 2.0, DEPTH), Vector3(0, HEIGHT, cz), ceil_m, Vector3(PI / 2, 0, 0))
	var brick := VRBuild.pbr("brick-light", Color(0.55, 0.42, 0.4), Vector2(1, 1), 1.2)
	var walls := [[Vector3(0, 0, Z1), PI, HALF_W * 2.0], [Vector3(-HALF_W, 0, cz), PI / 2, DEPTH], [Vector3(HALF_W, 0, cz), -PI / 2, DEPTH]]
	for w in walls:
		var holder := Node3D.new()
		holder.position = w[0]
		holder.rotation.y = w[1]
		node.add_child(holder)
		var wm: StandardMaterial3D = brick.duplicate()
		wm.uv1_scale = Vector3(float(w[2]) / 2.4, HEIGHT / 2.4, 1)
		VRBuild.quad(holder, Vector2(w[2], HEIGHT), Vector3(0, HEIGHT / 2.0, 0), wm)
		VRBuild.neon_tube(holder, w[2], Vector3(0, HEIGHT - 0.1, 0.04), Color(0.1, 0.9, 1.0) if int(w[1] * 10) % 2 == 0 else Color(1.0, 0.2, 0.7))
		VRBuild.box(holder, Vector3(w[2], 0.13, 0.05), Vector3(0, 0.065, 0.025), VRBuild.pbr("wood-green", Color(0.9, 0.95, 0.9), Vector2(float(w[2]) / 0.7, 0.34), 1.6))
	# the hall's side of the arcade's back wall: plain brick facing into the hall, with the gate cut out of it
	var gl := GATE_X - GATE_W / 2.0
	var gr := GATE_X + GATE_W / 2.0
	for piece in [[-HALF_W, gl, 0.0, HEIGHT], [gl, gr, GATE_H, HEIGHT], [gr, HALF_W, 0.0, HEIGHT]]:
		var w: float = float(piece[1]) - float(piece[0])
		var h: float = float(piece[3]) - float(piece[2])
		var fm: StandardMaterial3D = brick.duplicate()
		fm.uv1_scale = Vector3(w / 2.4, h / 2.4, 1)
		VRBuild.quad(node, Vector2(w, h), Vector3((float(piece[0]) + float(piece[1])) / 2.0, float(piece[2]) + h / 2.0, Z0 + 0.012), fm)
	VRBuild.neon_tube(node, HALF_W * 2.0 - GATE_W, Vector3((gr + HALF_W) / 2.0 - HALF_W * 0.0 - (HALF_W - gr) / 2.0 + (HALF_W - gr) / 2.0, HEIGHT - 0.1, Z0 + 0.04), Color(1.0, 0.2, 0.7))
	for z in [9.4, 13.0, 16.6, 19.6]:
		VRBuild.neon_tube(node, HALF_W * 2.0, Vector3(0, HEIGHT - 0.05, z), Color(0.15, 0.4, 1.0), Vector3.ZERO, 0.02)      # blue neon across the ceiling
	for p in [[Vector3(-2.2, 3.0, 9.0), Color(1.0, 0.3, 0.75), 1.1], [Vector3(2.2, 3.0, 12.0), Color(0.3, 0.85, 1.0), 1.1], [Vector3(-1.6, 3.0, 16.0), Color(1.0, 0.8, 0.5), 1.1], [Vector3(2.2, 3.0, 18.5), Color(1.0, 0.85, 0.6), 1.0]]:
		var l := OmniLight3D.new()
		l.position = p[0]
		l.light_color = p[1]
		l.light_energy = p[2]
		l.omni_range = 7.5
		node.add_child(l)
		lights.append(l)


## A neon tube sign (picture made by tools/make_sports_neon.py), lit and see-through round the tubes; `height` is its height in metres, the width follows the picture.
func _neon(file: String, pos: Vector3, yaw: float, height: float) -> void:
	var t = load("res://assets/art/" + file)
	if t == null:
		return
	var m := VRBuild.tex_mat(t, 0.0, 0.5, true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	node.add_child(holder)
	var aspect: float = float(t.get_width()) / float(t.get_height())
	VRBuild.quad(holder, Vector2(height * aspect, height), Vector3(0, 0, 0.02), m)


func _gate_trim() -> void:
	var trim := VRBuild.mat(Color(0.25, 0.17, 0.32), 0.55)
	var glow := VRBuild.mat(Color(0.1, 0.9, 1.0), 0.4, 0.0, 2.2)
	for sx in [-1.0, 1.0]:
		VRBuild.box(node, Vector3(0.1, GATE_H, 0.34), Vector3(GATE_X + sx * (GATE_W / 2.0 + 0.05), GATE_H / 2.0, Z0), trim)
		VRBuild.box(node, Vector3(0.025, GATE_H, 0.02), Vector3(GATE_X + sx * (GATE_W / 2.0), GATE_H / 2.0, Z0 - 0.17), glow)
	VRBuild.box(node, Vector3(GATE_W + 0.3, 0.1, 0.34), Vector3(GATE_X, GATE_H + 0.05, Z0), trim)
	VRBuild.box(node, Vector3(GATE_W, 0.025, 0.02), Vector3(GATE_X, GATE_H - 0.01, Z0 - 0.17), glow)


func _lobby_signs() -> void:
	VRBuild.label(node, "THE SHACK EXTRA", 0.3, Vector3(GATE_X, 3.02, Z0 + 0.06), Color(1.0, 0.85, 0.3), Vector3.ZERO, 6, font, true)
	VRBuild.label(node, "DARTS   ODIN'S AXE TOSS   STRIKERS", 0.14, Vector3(GATE_X, 2.8, Z0 + 0.06), Color(0.5, 0.95, 1.0), Vector3.ZERO, 4, font, true)
	VRBuild.label(node, "THE SHACK EXTRA", 0.3, Vector3(GATE_X, 3.02, Z0 - 0.19), Color(1.0, 0.85, 0.3), Vector3(0, PI, 0), 6, font, true)
	VRBuild.label(node, "DARTS • ODIN'S AXE TOSS • STRIKERS", 0.14, Vector3(GATE_X, 2.8, Z0 - 0.19), Color(0.5, 0.95, 1.0), Vector3(0, PI, 0), 4, font, true)
	VRBuild.label(node, "PICK UP: GRIP OR TRIGGER NEAR IT   •   THROW: LET GO", 0.06, Vector3(2.7, 1.7, Z0 + 0.04), Color(0.9, 0.9, 0.8), Vector3.ZERO, 3, font, true)


# ---- darts ---------------------------------------------------------------------------------------------
func _darts_scenery() -> void:
	_neon("neon-darts.png", Vector3(-HALF_W + 0.04, 2.95, (DART_Z[0] + DART_Z[1]) / 2.0), PI / 2.0, 0.72)       # DARTS in red tube with a dartboard and dart
	var wood := VRBuild.mat(Color(0.12, 0.07, 0.05), 0.5)
	var rubber := VRBuild.mat(Color(0.05, 0.05, 0.06), 0.8)
	for bz in DART_Z:
		# the cabinet round the board, with its doors open
		VRBuild.box(node, Vector3(0.05, 1.0, 0.86), Vector3(-HALF_W + 0.025, DART_Y, bz), wood)
		VRBuild.box(node, Vector3(0.05, 0.05, 0.86), Vector3(-HALF_W + 0.05, DART_Y + 0.5, bz), wood)
		VRBuild.box(node, Vector3(0.05, 0.05, 0.86), Vector3(-HALF_W + 0.05, DART_Y - 0.5, bz), wood)
		VRBuild.cylinder(node, 0.3, 0.02, Vector3(-HALF_W + 0.055, DART_Y, bz), rubber, 0.3, Vector3(0, 0, PI / 2), 36)       # the surround
		# the board: a cork-faced disc (the picture is the whole face, radius 225 mm)
		var face := VRBuild.tex_mat(load("res://assets/art/dartboard.png"), 0.0, 0.7)
		face.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		face.alpha_scissor_threshold = 0.5
		VRBuild.cylinder(node, 0.225, 0.04, Vector3(DART_FACE_X - 0.02, DART_Y, bz), VRBuild.mat(Color(0.3, 0.22, 0.14), 0.9), 0.225, Vector3(0, 0, PI / 2), 36)
		VRBuild.quad(node, Vector2(0.45, 0.45), Vector3(DART_FACE_X + 0.002, DART_Y, bz), face, Vector3(0, PI / 2, 0))
		# the line you stand behind, a toe-board, and a rubber mat
		VRBuild.box(node, Vector3(0.04, 0.025, 0.9), Vector3(OCHE_X, 0.0125, bz), VRBuild.mat(Color(0.9, 0.9, 0.85), 0.5, 0.2))
		VRBuild.box(node, Vector3(1.4, 0.008, 1.0), Vector3(OCHE_X + 0.65, 0.004, bz), rubber)
		VRBuild.label(node, "OCHE", 0.05, Vector3(OCHE_X + 0.09, 0.012, bz - 0.35), Color(1, 1, 0.9), Vector3(-PI / 2, PI / 2, 0), 2, font, true)


# ---- axe throwing ----------------------------------------------------------------------------------------
func _axe_scenery() -> void:
	var post := VRBuild.mat(Color(0.12, 0.1, 0.1), 0.5, 0.6)
	var cage := VRBuild.mat(Color(0.2, 0.2, 0.24, 0.5), 0.5, 0.5)
	cage.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rubber := VRBuild.mat(Color(0.06, 0.05, 0.05), 0.85)
	# the backing wall of dark wood behind the three targets
	VRBuild.box(node, Vector3(HALF_W * 0.95, 2.6, 0.06), Vector3(-1.75, 1.35, Z1 - 0.03), VRBuild.pbr("wood-navy", Color(0.5, 0.45, 0.42), Vector2(3.0, 1.0), 1.0))
	var tex = load("res://assets/art/axe-target.png")
	for i in range(AXE_X.size()):
		var x: float = AXE_X[i]
		var tm := VRBuild.tex_mat(tex, 0.0, 0.85)
		VRBuild.box(node, Vector3(1.2, 1.2, 0.07), Vector3(x, AXE_Y, AXE_FACE_Z - 0.035), VRBuild.mat(Color(0.45, 0.3, 0.18), 0.9))
		VRBuild.quad(node, Vector2(1.2, 1.2), Vector3(x, AXE_Y, AXE_FACE_Z - 0.0705), tm, Vector3(0, PI, 0))
		VRBuild.box(node, Vector3(0.06, 1.5, 0.06), Vector3(x - 0.62, 0.75, AXE_FACE_Z - 0.4), post)
		# the throwing line and a rubber mat for each lane
		VRBuild.box(node, Vector3(1.0, 0.012, 0.05), Vector3(x, 0.006, AXE_LINE_Z), VRBuild.mat(Color(0.95, 0.9, 0.2), 0.5))
		VRBuild.box(node, Vector3(1.05, 0.008, 1.2), Vector3(x, 0.004, AXE_LINE_Z - 0.55), rubber)
	# cage dividers between the lanes, from the line to the targets
	for k in range(AXE_X.size() + 1):
		var x: float = (AXE_X[0] - 0.625) + k * (AXE_X[1] - AXE_X[0])
		VRBuild.box(node, Vector3(0.04, 2.3, 0.04), Vector3(x, 1.15, AXE_LINE_Z + 0.2), post)
		VRBuild.box(node, Vector3(0.04, 2.3, 0.04), Vector3(x, 1.15, AXE_FACE_Z - 0.1), post)
		VRBuild.box(node, Vector3(0.012, 1.6, AXE_FACE_Z - AXE_LINE_Z - 0.3), Vector3(x, 1.5, (AXE_FACE_Z + AXE_LINE_Z) / 2.0 + 0.05), cage)
	_neon("neon-odin.png", Vector3(-1.75, 2.95, Z1 - 0.06), PI, 0.72)       # ODIN'S AXE TOSS, in amber tube with the Norse knot


# ---- bowling -----------------------------------------------------------------------------------------------
func _bowling_scenery() -> void:
	var lane_len := HEAD_PIN_Z + 1.0 - FOUL_Z
	var lane_m := VRBuild.tex_mat(load("res://assets/art/lane-wood.png"), 0.0, 0.18)
	lane_m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var gutter_m := VRBuild.mat(Color(0.05, 0.05, 0.07), 0.45, 0.4)
	var rail_m := VRBuild.mat(Color(0.08, 0.08, 0.1), 0.4, 0.5)
	var approach_m: StandardMaterial3D = lane_m.duplicate()
	approach_m.uv1_scale = Vector3(3.6, 0.45, 1)
	approach_m.texture_repeat = true
	# the approach: bare wood between the gate wall and the foul line
	VRBuild.quad(node, Vector2(3.8, FOUL_Z - Z0 - 0.3), Vector3(2.1, 0.004, (FOUL_Z + Z0 + 0.3) / 2.0), approach_m, Vector3(-PI / 2, 0, 0))
	for lx in LANE_X:
		# the lane surface (the picture runs from the foul line, bottom, to the pins, top)
		var q := VRBuild.quad(node, Vector2(LANE_W, lane_len), Vector3(lx, 0.006, FOUL_Z + lane_len / 2.0), lane_m, Vector3(-PI / 2, 0, PI))
		q.name = "Lane"
		for sx in [-1.0, 1.0]:
			VRBuild.box(node, Vector3(GUTTER_W, 0.02, lane_len), Vector3(lx + sx * (LANE_W / 2.0 + GUTTER_W / 2.0), -0.07, FOUL_Z + lane_len / 2.0), gutter_m)
			VRBuild.box(node, Vector3(0.06, 0.22, lane_len), Vector3(lx + sx * (LANE_W / 2.0 + GUTTER_W + 0.03), 0.03, FOUL_Z + lane_len / 2.0), rail_m)
		VRBuild.box(node, Vector3(LANE_W + 2.0 * GUTTER_W + 0.12, 0.02, 0.03), Vector3(lx, 0.012, FOUL_Z), VRBuild.mat(Color(0.1, 0.06, 0.04), 0.5))
	# the pin deck's back: a dark pit, and the masking unit above it with the big score screens
	VRBuild.box(node, Vector3(HALF_W - 0.45, 0.5, 1.0), Vector3(2.15, 0.0, HEAD_PIN_Z + 1.1), VRBuild.mat(Color(0.03, 0.03, 0.04), 0.7))
	VRBuild.box(node, Vector3(HALF_W - 0.45, 1.5, 0.12), Vector3(2.15, 2.5, Z1 - 0.45), VRBuild.mat(Color(0.08, 0.06, 0.12), 0.45, 0.4))
	_neon("neon-strikers.png", Vector3(2.15, 3.0, Z1 - 0.52), PI, 0.62)       # STRIKERS over the pin deck
	_neon("neon-strikers.png", Vector3(HALF_W - 0.04, 2.35, (FOUL_Z + HEAD_PIN_Z) / 2.0), -PI / 2.0, 0.95)       # and along the wall beside the lanes
	# the ball return between the two lanes: a low hooded box
	var mid_x: float = (LANE_X[0] + LANE_X[1]) / 2.0
	VRBuild.box(node, Vector3(0.28, 0.5, 0.7), Vector3(mid_x, 0.25, FOUL_Z - 0.55), VRBuild.mat(Color(0.12, 0.1, 0.16), 0.4, 0.5))
	VRBuild.box(node, Vector3(0.3, 0.02, 0.72), Vector3(mid_x, 0.51, FOUL_Z - 0.55), VRBuild.mat(Color(1.0, 0.3, 0.7), 0.3, 0.0, 1.6))
