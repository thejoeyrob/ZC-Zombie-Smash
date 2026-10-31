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


func build(font: Font, art_dir := "res://assets/art/") -> void:
	var body := VRBuild.mat(Color(0.07, 0.05, 0.1), 0.45, 0.35)
	var chrome := VRBuild.mat(Color(0.82, 0.84, 0.9), 0.18, 0.55, 0.16, Color(0.82, 0.84, 0.9))
	var dark := VRBuild.mat(Color(0.015, 0.015, 0.02), 0.6)
	var glow := VRBuild.mat(Color(1.0, 0.3, 0.7), 0.4, 0.0, 2.6)
	var side = load(art_dir + "side-pinball.png")
	var field = load(art_dir + "playfield-pinball.jpg")
	var head = load(art_dir + "marquee-pinball.jpg")
	# legs, cabinet body, side strips
	for sx in [-0.26, 0.26]:
		for sz in [-0.58, 0.74]:
			VRBuild.box(self, Vector3(0.06, 0.64, 0.06), Vector3(sx, 0.32, sz), chrome)
			VRBuild.box(self, Vector3(0.075, 0.03, 0.075), Vector3(sx, 0.015, sz), dark)
	# a hollow cabinet: two side walls, a front and a back wall, a base, and the playfield sunk below the rails
	var cab_col := VRBuild.mat(Color(0.2, 0.08, 0.3), 0.4, 0.3)
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
		btn.position = Vector3(sx * 0.31, 0.79, 0.55)
		add_child(btn)
		VRBuild.cylinder(btn, 0.034, 0.014, Vector3(sx * 0.0, 0, 0), chrome, -1.0, Vector3(0, 0, PI / 2), 24)
		var cap := VRBuild.cylinder(btn, 0.028, 0.03, Vector3(sx * 0.02, 0, 0), VRBuild.mat(Color(1.0, 0.45, 0.1), 0.2, 0.0, 0.5), 0.026, Vector3(0, 0, PI / 2), 24)
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
	# the backbox with the picture, the title and a live score display
	VRBuild.box(self, Vector3(0.64, 0.98, 0.2), Vector3(0, 1.42, -0.66), body)
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
	# a glow under the machine
	var halo := VRBuild.mat(Color(1.0, 0.3, 0.7, 0.16), 0.5, 0.0, 1.2)
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	VRBuild.quad(self, Vector2(1.5, 2.2), Vector3(0, 0.01, 0.07), halo, Vector3(-PI / 2.0, 0, 0))
	VRBuild.merge_static(self)
	VRBuild.merge_static(pf)


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
	var p := to_global(Vector3(0, 0, 1.3))
	return Vector3(p.x, 0.0, p.z)


func look_world() -> Vector3:
	return to_global(Vector3(0, 0.9, 0.0))


func _on_table_event(n: String) -> void:
	var p := to_global(pf.position + Vector3(0, 0.1, 0))
	sound.emit(n, p)


## Hands: tips and palms are world positions; trig_* are the controller triggers (an assist), launch is a button press.
func interact(tips: Array, palms: Array, trig_left: bool, trig_right: bool, launch: bool, near: bool) -> void:
	var left := false
	var right := false
	for p in tips:
		for i in range(2):
			var cap: Node3D = _flip_buttons[i]
			if cap != null and cap.global_position.distance_to(p) < 0.055:
				if i == 0:
					left = true
				else:
					right = true
	if near:
		left = left or trig_left
		right = right or trig_right
	table.flippers(left, right)
	for i in range(2):
		var down: bool = left if i == 0 else right
		var cap2: Node3D = _flip_buttons[i]
		if cap2 != null and down != _flip_down[i]:
			_flip_down[i] = down
			var push := 0.012 if i == 0 else -0.012
			cap2.position.x += push if down else -push
	# plunger: touch the red knob to pull it back; let go to launch
	var touching := false
	var knob := plunger_knob.global_position
	for p2 in tips + palms:
		if p2.distance_to(knob) < 0.07:
			touching = true
	if touching and not _held:
		_held = true
		_charge = 0.0
	if _held:
		if touching:
			_charge = minf(1.0, _charge + get_process_delta_time() * 1.1)
			table.pull(_charge)
		else:
			_held = false
			table.launch()
			_charge = 0.0
	if launch and not _launch_prev and near:
		table.pull(0.8)
		table.launch()
	_launch_prev = launch
	var pulled := _charge if _held else table.plunger
	plunger_knob.position = plunger_rest + Vector3(0, 0, pulled * 0.07)


func _process(_delta: float) -> void:
	if score_label != null:
		score_label.text = PinTable._commas(table.score) if enabled else "- - -"
		best_label.text = ("BEST " + PinTable._commas(table.best)) if enabled else "OUT OF ORDER"
