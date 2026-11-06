class_name Pinball
extends Node3D
## The zombie pinball machine, built to real proportions (about 0.6 m wide, 1.45 m long, playfield sloping 6.5 degrees to the player).
## Local +z is the player's side. The table itself is a live 2D game (PinTable) shown under the glass.

signal sound(name: String, world_pos: Vector3)

const TILT := 0.113
const PF_W := 0.56
const PF_H := 1.12
const SPOT_Y := 0.0

var table: PinTable
var viewport: SubViewport
var pf: Node3D
var plunger_knob: Node3D
var plunger_rest := Vector3.ZERO
var score_label: Label3D
var best_label: Label3D
var _charge := 0.0
var _held := false
var _launch_prev := false
var _flip_buttons := [null, null]
var _flip_down := [false, false]
var enabled := false
var reset_btn: Node3D
var _reset_prev := false
var _grab_z := 0.0
var _plunger_hand := -1
var _reset_hold := 0.0
var playfield: PinballPlayfield
var _latched := [-1, -1]       # which flipper button each hand is holding (-1 = none)


func build(font: Font, art_dir := "res://assets/art/") -> void:
	var body := VRBuild.mat(Color(0.07, 0.05, 0.1), 0.45, 0.35)
	var chrome := VRBuild.pbr("metal", Color(1, 1, 1), Vector2(1, 1), 0.8)    # brushed steel
	var dark := VRBuild.mat(Color(0.015, 0.015, 0.02), 0.6)
	var glow := VRBuild.mat(Color(1.0, 0.3, 0.7), 0.4, 0.0, 2.6)
	var side = load(art_dir + "side-pinball.png")
	var field = load(art_dir + "playfield-pinball.jpg")
	var head = load(art_dir + "marquee-pinball.jpg")
	# legs: tapered chrome tubes with a bolted bracket at the top, a screw leveller and a rubber foot, tied together with stretcher bars
	var black_rubber := VRBuild.mat(Color(0.02, 0.02, 0.025), 0.9)
	for sx in [-0.26, 0.26]:
		for sz in [-0.58, 0.74]:
			VRBuild.cylinder(self, 0.034, 0.58, Vector3(sx, 0.34, sz), chrome, 0.024, Vector3.ZERO, 24)
			VRBuild.box(self, Vector3(0.09, 0.02, 0.09), Vector3(sx, 0.615, sz), chrome)                  # the bracket under the cabinet
			for bx in [-0.03, 0.03]:
				for bz in [-0.03, 0.03]:
					VRBuild.cylinder(self, 0.006, 0.008, Vector3(sx + bx, 0.628, sz + bz), black_rubber, -1.0, Vector3.ZERO, 8)
			VRBuild.cylinder(self, 0.011, 0.05, Vector3(sx, 0.04, sz), chrome, -1.0, Vector3.ZERO, 12)    # the leveller
			VRBuild.cylinder(self, 0.034, 0.02, Vector3(sx, 0.01, sz), black_rubber, 0.032, Vector3.ZERO, 20)
	for sx in [-0.26, 0.26]:
		VRBuild.cylinder(self, 0.011, 1.32, Vector3(sx, 0.2, 0.08), chrome, -1.0, Vector3(PI / 2, 0, 0), 12)  # a bar between the legs on each side
	VRBuild.cylinder(self, 0.011, 0.52, Vector3(0, 0.2, -0.58), chrome, -1.0, Vector3(0, 0, PI / 2), 12)
	VRBuild.cylinder(self, 0.011, 0.52, Vector3(0, 0.2, 0.74), chrome, -1.0, Vector3(0, 0, PI / 2), 12)
	# a hollow cabinet: two side walls, a front and a back wall, a base, and the playfield sunk below the rails
	var cab_tex = load(art_dir + "pin-cab.jpg")
	var cab_col: StandardMaterial3D = VRBuild.tex_mat(cab_tex, 0.0, 0.3) if cab_tex != null else VRBuild.mat(Color(0.2, 0.08, 0.3), 0.4, 0.3)
	cab_col.metallic = 0.15
	cab_col.clearcoat_enabled = true
	cab_col.clearcoat = 0.8
	for sx in [-0.29, 0.29]:
		VRBuild.box(self, Vector3(0.025, 0.32, 1.46), Vector3(sx, 0.76, 0.07), cab_col)
	VRBuild.box(self, Vector3(0.6, 0.3, 0.03), Vector3(0, 0.75, 0.80), cab_col)              # front wall
	VRBuild.box(self, Vector3(0.6, 0.3, 0.03), Vector3(0, 0.75, -0.66), cab_col)             # back wall
	VRBuild.box(self, Vector3(0.58, 0.03, 1.46), Vector3(0, 0.62, 0.07), body)               # base
	for sx in [-0.31, 0.31]:
		VRBuild.box(self, Vector3(0.03, 0.04, 1.48), Vector3(sx, 0.925, 0.07), chrome)           # side rails
	VRBuild.box(self, Vector3(0.62, 0.04, 0.03), Vector3(0, 0.925, 0.81), chrome)
	VRBuild.box(self, Vector3(0.5, 0.012, 0.012), Vector3(0, 0.66, 0.82), glow)
	if side != null:
		for sx in [-1, 1]:
			var m := VRBuild.tex_mat(side, 0.25, 0.55)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.45
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			# the flipper-and-claw part of the artwork, run along the length of the cabinet
			m.uv1_scale = Vector3(1.0 * (-1 if sx > 0 else 1), 0.13, 1)
			m.uv1_offset = Vector3(1.0 if sx > 0 else 0.0, 0.8, 0)
			VRBuild.quad(self, Vector2(1.44, 0.3), Vector3(sx * 0.3035, 0.76, 0.07), m, Vector3(0, sx * PI / 2.0, 0))
	# the glass-covered playfield
	pf = Node3D.new()
	pf.position = Vector3(0, 0.79, 0.07)
	pf.rotation = Vector3(-PI / 2.0 + TILT, 0, 0)
	add_child(pf)
	viewport = SubViewport.new()
	viewport.size = Vector2i(512, 1024)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	table = PinTable.new()
	table.scale = Vector2(1.28, 1.28)
	table.font = font
	table.art = field
	viewport.add_child(table)
	table.event.connect(_on_table_event)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = viewport.get_texture()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	VRBuild.quad(pf, Vector2(PF_W, PF_H), Vector3.ZERO, fm)
	var glass := VRBuild.mat(Color(0.7, 0.9, 1.0, 0.07), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	VRBuild.quad(pf, Vector2(PF_W + 0.04, PF_H + 0.04), Vector3(0, 0, 0.055), glass)
	for sx in [-1, 1]:
		VRBuild.box(pf, Vector3(0.03, PF_H + 0.06, 0.08), Vector3(sx * (PF_W / 2.0 + 0.03), 0, 0.02), chrome)
	VRBuild.box(pf, Vector3(PF_W + 0.09, 0.03, 0.08), Vector3(0, PF_H / 2.0 + 0.03, 0.02), chrome)
	VRBuild.box(pf, Vector3(PF_W + 0.09, 0.05, 0.1), Vector3(0, -PF_H / 2.0 - 0.025, 0.03), chrome)     # lockdown bar
	# flipper buttons on both sides near the front
	for i in range(2):
		var sx := -1.0 if i == 0 else 1.0
		var btn := Node3D.new()
		btn.position = Vector3(sx * 0.312, 0.83, 0.68)       # near the player's end, where your hands rest on the sides
		add_child(btn)
		VRBuild.cylinder(btn, 0.044, 0.016, Vector3(sx * 0.0, 0, 0), chrome, 0.04, Vector3(0, 0, PI / 2), 28)
		VRBuild.cylinder(btn, 0.048, 0.006, Vector3(-sx * 0.008, 0, 0), black_rubber, -1.0, Vector3(0, 0, PI / 2), 28)
		var cap := VRBuild.cylinder(btn, 0.036, 0.034, Vector3(sx * 0.022, 0, 0), VRBuild.pbr("leather-red3", Color(1.15, 1.0, 0.9), Vector2(1, 1), 1.0), 0.034, Vector3(0, 0, PI / 2), 28)
		_flip_buttons[i] = cap
	# plunger: a chrome rod and a red knob that sticks out of the front on the right
	var lane_x := (366.0 - 200.0) / 400.0 * PF_W
	var front := pf.transform * Vector3(lane_x, -PF_H / 2.0 - 0.02, 0.0)
	plunger_rest = Vector3(front.x, front.y - 0.0, front.z + 0.2)
	plunger_knob = Node3D.new()
	plunger_knob.position = plunger_rest
	add_child(plunger_knob)
	VRBuild.cylinder(plunger_knob, 0.007, 0.2, Vector3(0, 0, -0.1), chrome, -1.0, Vector3(PI / 2, 0, 0), 12)
	VRBuild.sphere(plunger_knob, 0.027, Vector3(0, 0, 0.012), VRBuild.mat(Color(0.95, 0.12, 0.15), 0.2, 0.0, 0.6), 16)
	# a lit RESET button on the front starts a fresh game from any state
	reset_btn = Node3D.new()
	reset_btn.position = Vector3(-0.21, 0.69, 0.84)
	add_child(reset_btn)
	VRBuild.cylinder(reset_btn, 0.032, 0.012, Vector3.ZERO, chrome, -1.0, Vector3(PI / 2, 0, 0), 20)
	var amber := Color(1.0, 0.55, 0.1)
	VRBuild.cylinder(reset_btn, 0.025, 0.016, Vector3(0, 0, 0.01), VRBuild.mat(amber, 0.2, 0.0, 1.8, amber), 0.023, Vector3(PI / 2, 0, 0), 20)
	VRBuild.label(reset_btn, "RESET", 0.03, Vector3(0, -0.055, 0.004), Color(1, 0.85, 0.6), Vector3.ZERO, 4, font)
	# the backbox with the picture, the title and a live score display
	VRBuild.box(self, Vector3(0.64, 0.98, 0.2), Vector3(0, 1.42, -0.66), cab_col)
	var front_tex = load(art_dir + "pin-front.png")
	if front_tex != null:
		var fm2 := VRBuild.tex_mat(front_tex, 0.25, 0.4)
		fm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		VRBuild.quad(self, Vector2(0.5, 0.25), Vector3(0, 0.76, 0.8156), fm2)
	VRBuild.box(self, Vector3(0.68, 0.04, 0.24), Vector3(0, 1.93, -0.66), chrome)
	VRBuild.box(self, Vector3(0.68, 0.04, 0.24), Vector3(0, 0.93, -0.66), chrome)
	if field != null:
		var tm := VRBuild.tex_mat(field, 1.0, 0.5, true)
		tm.uv1_scale = Vector3(1, 0.62, 1)
		tm.uv1_offset = Vector3(0, 0.0, 0)
		VRBuild.quad(self, Vector2(0.6, 0.62), Vector3(0, 1.37, -0.558), tm)
	if head != null:
		VRBuild.quad(self, Vector2(0.6, 0.2), Vector3(0, 1.8, -0.558), VRBuild.tex_mat(head, 1.0, 0.5, true))
	VRBuild.box(self, Vector3(0.6, 0.14, 0.01), Vector3(0, 1.03, -0.56), VRBuild.mat(Color(0.02, 0.02, 0.04), 0.3))
	score_label = VRBuild.label(self, "0", 0.1, Vector3(0, 1.03, -0.552), Color(1.0, 0.5, 0.1), Vector3.ZERO, 2, font)
	best_label = VRBuild.label(self, "", 0.034, Vector3(0, 0.97, -0.552), Color(0.6, 0.9, 1.0), Vector3.ZERO, 0, font)
	VRBuild.box(self, Vector3(0.64, 0.02, 0.2), Vector3(0, 1.955, -0.66), glow)
	VRBuild.merge_static(self)
	VRBuild.merge_static(pf)
	playfield = PinballPlayfield.new()
	pf.add_child(playfield)
	playfield.build(table)


## Keeps a sphere (world position) out of the cabinet and backbox.
func constrain(world: Vector3, radius: float) -> Vector3:
	var p := to_local(world)
	if absf(p.x) > 0.9 or p.z < -1.1 or p.z > 1.2 or p.y > 2.2:
		return world
	for b in [[Vector3(0, 0.77, 0.07), Vector3(0.31, 0.16, 0.74)], [Vector3(0, 1.42, -0.66), Vector3(0.33, 0.5, 0.11)]]:
		var c: Vector3 = b[0]
		var half: Vector3 = b[1] + Vector3.ONE * radius
		var d := p - c
		if absf(d.x) < half.x and absf(d.y) < half.y and absf(d.z) < half.z:
			var pen := Vector3(half.x - absf(d.x), half.y - absf(d.y), half.z - absf(d.z))
			if pen.y <= pen.x and pen.y <= pen.z and d.y > 0.0:
				p.y = c.y + half.y
			elif pen.x <= pen.z:
				p.x = c.x + half.x * signf(d.x)
			else:
				p.z = c.z + half.z * signf(d.z)
	return to_global(p)


func set_enabled(on: bool) -> void:
	enabled = on
	table.enabled = on


func stand_world() -> Vector3:
	var p := to_global(Vector3(0, 0, 1.02))      # right up against the front rail
	return Vector3(p.x, 0.0, p.z)


func look_world() -> Vector3:
	return to_global(Vector3(0, 0.78, -0.2))     # the middle of the playfield, so you look down on it


func _on_table_event(n: String) -> void:
	var p := to_global(pf.position + Vector3(0, 0.1, 0))
	sound.emit(n, p)


## Hands holding the sides of the cabinet by the flipper buttons. A hand that grips near a button stays on it; pulling that hand's
## trigger presses the button (the flipper goes up) and letting go of the trigger lets it fall. Returns
## {"latch": [button per hand or -1], "spot": [world position per hand or null], "left": bool, "right": bool}.
func latch(hands: Array) -> Dictionary:
	var out := {"latch": [-1, -1], "spot": [null, null], "left": false, "right": false}
	for i in range(mini(2, hands.size())):
		var h: Dictionary = hands[i]
		var held: bool = h.active and (h.gripping or (_latched[i] >= 0 and float(h.grip_val) > 0.3))
		var hp: Vector3 = h.grip
		if _latched[i] >= 0:
			var cap0: Node3D = _flip_buttons[_latched[i]]
			if not held or hp.distance_to(cap0.global_position) > 0.3:
				_latched[i] = -1
		if _latched[i] < 0 and held:
			var best := -1
			var best_d := 0.16
			for b in range(2):
				var cap: Node3D = _flip_buttons[b]
				if cap == null or b == _latched[1 - i]:
					continue
				var d: float = minf(hp.distance_to(cap.global_position), (h.palm as Vector3).distance_to(cap.global_position))
				if d < best_d:
					best_d = d
					best = b
			_latched[i] = best
		if _latched[i] >= 0:
			var cap1: Node3D = _flip_buttons[_latched[i]]
			out.latch[i] = _latched[i]
			out.spot[i] = cap1.global_position
			if float(h.trig_val) > 0.5 or (h.trigger and float(h.trig_val) <= 0.0):
				if _latched[i] == 0:
					out.left = true
				else:
					out.right = true
	return out


func release_hands() -> void:
	_latched = [-1, -1]


## Hands: tips and palms are world positions; trig_* are the controller triggers (an assist), launch is a button press.
func interact(tips: Array, palms: Array, trig_left: bool, trig_right: bool, launch: bool, near: bool, hands: Array = []) -> void:
	if not near or table.network_remote:
		release_hands()
		_held = false
		_plunger_hand = -1
		_reset_hold = 0.0
		_reset_prev = false
		_launch_prev = launch
		if not table.network_remote:
			table.flippers(false, false)
			table.pull(0.0)
		return
	var flips := [trig_left, trig_right]
	for i in range(2):
		for tip in tips:
			if tip.distance_to(_flip_buttons[i].global_position) < 0.035:
				flips[i] = true
	table.flippers(flips[0], flips[1])
	for i in range(2):
		if flips[i] != _flip_down[i]:
			_flip_down[i] = flips[i]
			_flip_buttons[i].position.x += (0.012 if i == 0 else -0.012) * (1.0 if flips[i] else -1.0)
	var on_reset := false
	for tip in tips:
		on_reset = on_reset or tip.distance_to(reset_btn.global_position) < 0.035
	_reset_hold = _reset_hold + get_process_delta_time() if on_reset else 0.0
	if _reset_hold >= 0.9 and not _reset_prev:
		table.reset_game()
		_reset_prev = true
	if not on_reset:
		_reset_prev = false
	var knob := to_global(plunger_rest + Vector3(0, 0, _charge * 0.1))
	if _plunger_hand < 0:
		for i in range(hands.size()):
			if hands[i].active and hands[i].gripping and palms[i].distance_to(knob) < 0.11:
				_plunger_hand = i
				_grab_z = to_local(palms[i]).z
				_held = true
				_charge = 0.0
				break
	else:
		var i := _plunger_hand
		if i >= hands.size() or not hands[i].active:
			_plunger_hand = -1 # Tracking loss cancels; never launches.
			_held = false
			_charge = 0.0
			table.pull(0.0)
		elif not hands[i].gripping:
			if _charge > 0.1:
				table.launch()
			else:
				table.pull(0.0)
			_plunger_hand = -1
			_held = false
			_charge = 0.0
		elif palms[i].distance_to(knob) > 0.3:
			_plunger_hand = -1
			_held = false
			_charge = 0.0
			table.pull(0.0)
		else:
			_charge = clampf((to_local(palms[i]).z - _grab_z) / 0.1, 0, 1)
			table.pull(_charge)
	if launch and not _launch_prev:
		table.pull(0.8)
		table.launch()
	_launch_prev = launch
	plunger_knob.position = plunger_rest + Vector3(0, 0, _charge * 0.1)


func _process(_delta: float) -> void:
	if score_label != null:
		score_label.text = PinTable._commas(table.score) if enabled else "- - -"
		best_label.text = ("BEST %s  •  BALLS %d  •  x%d%s" % [PinTable._commas(table.best), table.balls_left, table.multiplier, "  SAVE" if table.ball_save > 0 else ""]) if enabled else "OUT OF ORDER"
