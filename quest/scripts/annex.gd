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
const GATE_X := 0.0                # the opening in the arcade's back wall, between the two pinball machines (world x of its middle)
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
	VRBuild.merge_static(node)


func set_active(on: bool) -> void:
	node.visible = on


# ---- the hall -----------------------------------------------------------------------------------------
func _shell() -> void:
	var cz := (Z0 + Z1) / 2.0
	var floor_m := VRBuild.pbr("concrete", Color(0.8, 0.8, 0.84), Vector2(HALF_W * 2.0 / 3.0, DEPTH / 3.0), 0.7)
	VRBuild.quad(node, Vector2(HALF_W * 2.0, DEPTH), Vector3(0, 0, cz), floor_m, Vector3(-PI / 2, 0, 0))
	VRBuild.quad(node, Vector2(HALF_W * 2.0, DEPTH), Vector3(0, HEIGHT, cz), VRBuild.mat(Color(0.07, 0.07, 0.08), 0.9), Vector3(PI / 2, 0, 0))
	var plaster := VRBuild.pbr("plaster", Color(0.8, 0.8, 0.8), Vector2(1, 1), 0.8)
	var oak := VRBuild.pbr("oakslat", Color(0.85, 0.8, 0.75), Vector2(1, 1), 1.2)
	var black := VRBuild.mat(Color(0.03, 0.03, 0.035), 0.5, 0.5)
	var walls := [[Vector3(0, 0, Z1), PI, HALF_W * 2.0, true], [Vector3(-HALF_W, 0, cz), PI / 2, DEPTH, false], [Vector3(HALF_W, 0, cz), -PI / 2, DEPTH, false]]
	for w in walls:
		var holder := Node3D.new()
		holder.position = w[0]
		holder.rotation.y = w[1]
		node.add_child(holder)
		var wm: StandardMaterial3D = (oak if w[3] else plaster).duplicate()
		var tile := 1.2 if w[3] else 2.4
		wm.uv1_scale = Vector3(float(w[2]) / tile, HEIGHT / tile, 1)
		VRBuild.quad(holder, Vector2(w[2], HEIGHT), Vector3(0, HEIGHT / 2.0, 0), wm)
		VRBuild.led_bar(holder, Vector3(w[2], 0.03, 0.03), Vector3(0, HEIGHT - 0.1, 0.03), Color(1.0, 0.86, 0.66), 1.6)
		VRBuild.box(holder, Vector3(w[2], 0.09, 0.025), Vector3(0, 0.045, 0.0125), black)
	# the hall's side of the arcade's back wall: oak slats facing into the hall, with the opening cut out of it
	var gl := GATE_X - GATE_W / 2.0
	var gr := GATE_X + GATE_W / 2.0
	for piece in [[-HALF_W, gl, 0.0, HEIGHT], [gl, gr, GATE_H, HEIGHT], [gr, HALF_W, 0.0, HEIGHT]]:
		var w: float = float(piece[1]) - float(piece[0])
		var h: float = float(piece[3]) - float(piece[2])
		var fm: StandardMaterial3D = oak.duplicate()
		fm.uv1_scale = Vector3(w / 1.2, h / 1.2, 1)
		VRBuild.quad(node, Vector2(w, h), Vector3((float(piece[0]) + float(piece[1])) / 2.0, float(piece[2]) + h / 2.0, Z0 + 0.012), fm)
	# the ceiling: pendant light bars over each zone, and spot tracks
	for z in [9.2, 12.4, 15.6, 18.8]:
		VRBuild.led_bar(node, Vector3(3.6, 0.05, 0.1), Vector3(0, HEIGHT - 0.55, z), Color(1.0, 0.9, 0.76), 2.4)
		VRBuild.box(node, Vector3(3.7, 0.025, 0.14), Vector3(0, HEIGHT - 0.51, z), black)
		for sx in [-1.7, 1.7]:
			VRBuild.box(node, Vector3(0.008, 0.5, 0.008), Vector3(sx, HEIGHT - 0.26, z), black)
	for p in [[Vector3(-1.6, 3.0, 9.8), Color(1.0, 0.93, 0.84), 1.0], [Vector3(2.2, 3.0, 12.0), Color(1.0, 0.93, 0.84), 0.9], [Vector3(-1.6, 3.0, 15.8), Color(1.0, 0.95, 0.88), 1.0], [Vector3(2.2, 3.0, 18.5), Color(1.0, 0.95, 0.88), 0.9]]:
		var l := OmniLight3D.new()
		l.position = p[0]
		l.light_color = p[1]
		l.light_energy = p[2]
		l.omni_range = 7.5
		node.add_child(l)
		lights.append(l)


func _gate_trim() -> void:
	# the opening: a slim black steel frame with a warm LED reveal
	var black := VRBuild.mat(Color(0.03, 0.03, 0.035), 0.45, 0.7)
	for sx in [-1.0, 1.0]:
		VRBuild.box(node, Vector3(0.07, GATE_H, 0.3), Vector3(GATE_X + sx * (GATE_W / 2.0 + 0.035), GATE_H / 2.0, Z0), black)
		VRBuild.led_bar(node, Vector3(0.015, GATE_H - 0.1, 0.012), Vector3(GATE_X + sx * (GATE_W / 2.0 - 0.01), GATE_H / 2.0, Z0 - 0.15), Color(1.0, 0.88, 0.7), 1.8)
	VRBuild.box(node, Vector3(GATE_W + 0.14, 0.07, 0.3), Vector3(GATE_X, GATE_H + 0.035, Z0), black)
	VRBuild.led_bar(node, Vector3(GATE_W - 0.04, 0.015, 0.012), Vector3(GATE_X, GATE_H - 0.02, Z0 - 0.15), Color(1.0, 0.88, 0.7), 1.8)


func _lobby_signs() -> void:
	VRBuild.label(node, "PICK UP: GRIP OR TRIGGER NEAR IT   •   THROW: LET GO", 0.06, Vector3(2.7, 1.7, Z0 + 0.04), Color(0.9, 0.9, 0.88), Vector3.ZERO, 0, font, true)


# ---- darts ---------------------------------------------------------------------------------------------
func _darts_scenery() -> void:
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
	VRBuild.label(node, "AXE THROWING", 0.22, Vector3(-1.75, 3.0, Z1 - 0.06), Color(1.0, 0.94, 0.84), Vector3(0, PI, 0), 0, font, true)


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
	VRBuild.label(node, "BOWLING", 0.22, Vector3(2.15, 3.0, Z1 - 0.52), Color(1.0, 0.94, 0.84), Vector3(0, PI, 0), 0, font, true)
	# the ball return between the two lanes: a low hooded box
	var mid_x: float = (LANE_X[0] + LANE_X[1]) / 2.0
	VRBuild.box(node, Vector3(0.28, 0.5, 0.7), Vector3(mid_x, 0.25, FOUL_Z - 0.55), VRBuild.mat(Color(0.12, 0.1, 0.16), 0.4, 0.5))
	VRBuild.box(node, Vector3(0.3, 0.02, 0.72), Vector3(mid_x, 0.51, FOUL_Z - 0.55), VRBuild.mat(Color(0.12, 0.1, 0.12), 0.3, 0.6))
