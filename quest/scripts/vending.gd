class_name VendingMachine
extends Node3D
## A tall old-school snack and soda machine. What is inside (and what it is called) comes from data/vending.json.
## The keypad works: key a code and press # (see "codes" in that file). * clears the display.

signal code_entered(action: String)
signal key_pressed(key: String, ok: bool)

const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
const KEY_X := 0.35
const KEY_Y0 := 1.34
const KEY_DX := 0.062
const KEY_DY := 0.072
const FRONT_Z := 0.43

var entry := ""
var display: Label3D
var codes := {}
var _key_nodes := {}
var _msg_t := 0.0
var _font: Font


func build(font: Font) -> void:
	_font = font
	var red := VRBuild.mat(Color(0.58, 0.07, 0.11), 0.3, 0.25)
	var red_dark := VRBuild.mat(Color(0.36, 0.04, 0.07), 0.35, 0.25)
	var dark := VRBuild.mat(Color(0.03, 0.03, 0.04), 0.6)
	var chrome := VRBuild.mat(Color(0.82, 0.84, 0.9), 0.18, 0.55, 0.16, Color(0.82, 0.84, 0.9))
	var cream := VRBuild.mat(Color(0.96, 0.93, 0.85), 0.45)
	var lamp := VRBuild.mat(Color(1.0, 0.96, 0.82), 0.5, 0.0, 2.4)
	# the cabinet: a red shell with the window, control column and dispenser cut out of the front
	VRBuild.box(self, Vector3(1.0, 2.04, 0.4), Vector3(0, 1.02, -0.2), red)
	VRBuild.box(self, Vector3(0.07, 1.1, 0.45), Vector3(-0.465, 1.12, 0.2), red)                       # left of the window
	VRBuild.box(self, Vector3(0.3, 1.1, 0.45), Vector3(0.35, 1.12, 0.2), red_dark)                     # control column
	VRBuild.box(self, Vector3(1.0, 0.33, 0.45), Vector3(0, 1.855, 0.2), red)                          # header block
	VRBuild.box(self, Vector3(1.0, 0.56, 0.45), Vector3(0, 0.28, 0.2), red)                           # lower body
	VRBuild.box(self, Vector3(1.04, 0.06, 0.5), Vector3(0, 2.05, 0.1), VRBuild.mat(Color(0.22, 0.03, 0.05), 0.35, 0.3))
	VRBuild.box(self, Vector3(1.04, 0.1, 0.5), Vector3(0, 0.05, 0.1), dark)
	# side panels: a white stripe and a lit logo plate
	for sx in [-0.505, 0.505]:
		VRBuild.box(self, Vector3(0.006, 1.5, 0.08), Vector3(sx, 0.95, 0.12), cream)
	# header sign: an illuminated cream panel with the machine's name
	VRBuild.box(self, Vector3(0.9, 0.26, 0.04), Vector3(0, 1.855, FRONT_Z + 0.012), lamp)
	VRBuild.box(self, Vector3(0.94, 0.03, 0.05), Vector3(0, 1.99, FRONT_Z + 0.01), chrome)
	VRBuild.box(self, Vector3(0.94, 0.03, 0.05), Vector3(0, 1.72, FRONT_Z + 0.01), chrome)
	VRBuild.label(self, str(_data().get("title", "SNACKS & SODA")), 0.13, Vector3(0, 1.86, FRONT_Z + 0.036), Color(0.7, 0.04, 0.1), Vector3.ZERO, 3, font)
	# the window: chrome frame, dark interior with warm LED strips, glass in front
	var w_x := -0.12
	var w_w := 0.66
	var w_top := 1.66
	var w_bot := 0.6
	var w_mid := (w_top + w_bot) / 2.0
	var w_h := w_top - w_bot
	for fy in [w_top + 0.015, w_bot - 0.015]:
		VRBuild.box(self, Vector3(w_w + 0.07, 0.035, 0.04), Vector3(w_x, fy, FRONT_Z), chrome)
	for fx in [w_x - w_w / 2.0 - 0.015, w_x + w_w / 2.0 + 0.015]:
		VRBuild.box(self, Vector3(0.035, w_h + 0.07, 0.04), Vector3(fx, w_mid, FRONT_Z), chrome)
	VRBuild.box(self, Vector3(w_w, w_h, 0.02), Vector3(w_x, w_mid, 0.0), VRBuild.mat(Color(0.2, 0.2, 0.26), 0.5, 0.0, 0.9, Color(1.0, 0.97, 0.9)))
	var pane := StandardMaterial3D.new()
	pane.albedo_texture = _sheen()
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pane.cull_mode = BaseMaterial3D.CULL_DISABLED
	VRBuild.quad(self, Vector2(w_w, w_h), Vector3(w_x, w_mid, FRONT_Z + 0.022), pane)
	var rows := _items()
	for r in range(rows.size()):
		var y: float = w_top - 0.06 - r * (w_h - 0.06) / maxf(1.0, float(rows.size()))
		VRBuild.box(self, Vector3(w_w, 0.014, 0.38), Vector3(w_x, y - 0.115, 0.2), chrome)               # shelf
		VRBuild.box(self, Vector3(w_w, 0.01, 0.012), Vector3(w_x, y - 0.1, 0.385), lamp)                  # LED strip along the shelf lip
		var row: Array = rows[r]
		for i in range(row.size()):
			var it: Dictionary = row[i]
			var x := w_x - w_w / 2.0 + 0.075 + i * (w_w - 0.15) / maxf(1.0, row.size() - 1.0)
			_item(it, Vector3(x, y - 0.108, 0.3))
			VRBuild.box(self, Vector3(0.118, 0.034, 0.006), Vector3(x, y - 0.133, 0.396), cream)           # price strip
			var l := VRBuild.label(self, str(it.get("name", "")).substr(0, 15), 0.017, Vector3(x, y - 0.131, 0.4), Color(0.1, 0.1, 0.12), Vector3.ZERO, 0, font)
			l.double_sided = false
	# the control column: a lit display, the keypad, coin and card slots
	VRBuild.box(self, Vector3(0.26, 1.04, 0.02), Vector3(0.35, 1.12, FRONT_Z - 0.005), VRBuild.mat(Color(0.85, 0.86, 0.9), 0.35, 0.5, 0.2, Color(0.85, 0.86, 0.9)))
	VRBuild.box(self, Vector3(0.2, 0.09, 0.016), Vector3(0.35, 1.52, FRONT_Z + 0.008), VRBuild.mat(Color(0.02, 0.06, 0.02), 0.4, 0.0, 0.5, Color(0.2, 0.8, 0.3)))
	display = VRBuild.label(self, "- - - -", 0.07, Vector3(0.35, 1.52, FRONT_Z + 0.019), Color(0.45, 1.0, 0.55), Vector3.ZERO, 0, font)
	VRBuild.label(self, "ENTER CODE", 0.02, Vector3(0.35, 1.455, FRONT_Z + 0.014), Color(0.15, 0.15, 0.2), Vector3.ZERO, 0, font)
	for k in range(KEYS.size()):
		var kx := KEY_X + ((k % 3) - 1) * KEY_DX
		var ky := KEY_Y0 - (k / 3) * KEY_DY
		var key_node := Node3D.new()
		key_node.position = Vector3(kx, ky, FRONT_Z + 0.006)
		add_child(key_node)
		VRBuild.box(key_node, Vector3(0.05, 0.05, 0.016), Vector3.ZERO, VRBuild.mat(Color(0.12, 0.12, 0.16), 0.3, 0.4))
		VRBuild.box(key_node, Vector3(0.043, 0.043, 0.01), Vector3(0, 0, 0.007), VRBuild.mat(Color(0.88, 0.86, 0.8) if KEYS[k] != "#" else Color(0.3, 0.8, 0.4), 0.3))
		VRBuild.label(key_node, KEYS[k], 0.03, Vector3(0, 0, 0.0125), Color(0.1, 0.1, 0.12), Vector3.ZERO, 0, font)
		_key_nodes[KEYS[k]] = key_node
	VRBuild.box(self, Vector3(0.1, 0.07, 0.014), Vector3(0.35, 1.0, FRONT_Z + 0.006), dark)               # coin slot
	VRBuild.box(self, Vector3(0.01, 0.05, 0.016), Vector3(0.35, 1.0, FRONT_Z + 0.012), chrome)
	VRBuild.box(self, Vector3(0.1, 0.045, 0.014), Vector3(0.35, 0.9, FRONT_Z + 0.006), VRBuild.mat(Color(0.1, 0.2, 0.55), 0.35, 0.0, 1.0))
	VRBuild.label(self, "CARD", 0.02, Vector3(0.35, 0.9, FRONT_Z + 0.016), Color(1, 1, 1), Vector3.ZERO, 0, font)
	VRBuild.box(self, Vector3(0.08, 0.08, 0.014), Vector3(0.35, 0.74, FRONT_Z + 0.006), dark)               # coin return
	VRBuild.box(self, Vector3(0.05, 0.03, 0.016), Vector3(0.35, 0.74, FRONT_Z + 0.012), chrome)
	# dispenser flap under the window
	VRBuild.box(self, Vector3(0.64, 0.2, 0.03), Vector3(w_x, 0.28, FRONT_Z), dark)
	var flap := VRBuild.box(self, Vector3(0.58, 0.15, 0.02), Vector3(w_x, 0.28, FRONT_Z + 0.02), VRBuild.mat(Color(0.015, 0.015, 0.02), 0.25, 0.3), Vector3(-0.08, 0, 0))
	VRBuild.label(self, "PUSH", 0.04, Vector3(w_x, 0.28, FRONT_Z + 0.032), Color(0.8, 0.8, 0.85, 0.7), Vector3.ZERO, 0, font)
	# a warm pool of light on the floor
	var halo := VRBuild.mat(Color(1.0, 0.85, 0.6, 0.13), 0.5, 0.0, 1.0)
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	VRBuild.quad(self, Vector2(1.8, 1.8), Vector3(0, 0.012, 0.7), halo, Vector3(-PI / 2.0, 0, 0))
	var l2 := OmniLight3D.new()
	l2.position = Vector3(0, 1.2, 0.9)
	l2.light_color = Color(1.0, 0.92, 0.8)
	l2.light_energy = 0.8
	l2.omni_range = 2.4
	add_child(l2)
	VRBuild.merge_static(self)


func _sheen() -> GradientTexture2D:
	# a faint diagonal highlight, like light on real glass
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(0.8, 0.9, 1.0, 0.06), Color(1, 1, 1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.3, 0.42, 0.62, 0.72, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(1.0, 1.0)
	return t


func _data() -> Dictionary:
	var f := FileAccess.open("res://data/vending.json", FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			codes = d.get("codes", {})
			return d
	return {}


func _items() -> Array:
	return _data().get("rows", [])


func _item(it: Dictionary, pos: Vector3) -> void:
	var col := Color.html(str(it.get("color", "#cccccc")))
	var m := VRBuild.mat(col, 0.45, 0.1, 0.12)
	var spring := VRBuild.mat(Color(0.15, 0.15, 0.18), 0.5, 0.5, 0.2, Color(0.15, 0.15, 0.18))
	VRBuild.cylinder(self, 0.004, 0.2, pos + Vector3(0, 0.0, -0.06), spring, -1.0, Vector3(PI / 2, 0, 0), 6)        # the coil behind it
	match str(it.get("kind", "candy")):
		"chips":
			VRBuild.box(self, Vector3(0.095, 0.15, 0.03), pos + Vector3(0, 0.075, 0), m, Vector3(-0.18, 0, 0))
			VRBuild.box(self, Vector3(0.08, 0.05, 0.032), pos + Vector3(0, 0.1, 0.002), VRBuild.mat(Color(1, 1, 1), 0.5), Vector3(-0.18, 0, 0))
			VRBuild.box(self, Vector3(0.095, 0.012, 0.03), pos + Vector3(0, 0.152, -0.01), m.duplicate(), Vector3(-0.18, 0, 0))
		"can":
			VRBuild.cylinder(self, 0.032, 0.13, pos + Vector3(0, 0.065, 0), m)
			VRBuild.cylinder(self, 0.033, 0.014, pos + Vector3(0, 0.134, 0), VRBuild.mat(Color(0.8, 0.82, 0.88), 0.2, 0.55, 0.16, Color(0.8, 0.82, 0.88)))
			VRBuild.cylinder(self, 0.0325, 0.01, pos + Vector3(0, 0.005, 0), VRBuild.mat(Color(0.7, 0.72, 0.78), 0.2, 0.55, 0.16, Color(0.7, 0.72, 0.78)))
		_:
			VRBuild.box(self, Vector3(0.1, 0.034, 0.055), pos + Vector3(0, 0.022, 0), m)
			VRBuild.box(self, Vector3(0.1, 0.034, 0.055), pos + Vector3(0, 0.058, 0), VRBuild.mat(col.lightened(0.15), 0.45), Vector3(0, 0.15, 0))
			VRBuild.box(self, Vector3(0.1, 0.034, 0.055), pos + Vector3(0, 0.094, 0), m, Vector3(0, -0.1, 0))


# ---- the keypad ----------------------------------------------------------------------------------------
func key_at(world: Vector3) -> String:
	var p := to_local(world)
	if p.z < FRONT_Z - 0.04 or p.z > FRONT_Z + 0.09:
		return ""
	for k in KEYS:
		var n: Node3D = _key_nodes[k]
		if absf(p.x - n.position.x) < 0.028 and absf(p.y - n.position.y) < 0.028:
			return k
	return ""


## A key was pushed. Returns "" normally, or the action of a code that was accepted.
func press(key: String) -> String:
	var n: Node3D = _key_nodes.get(key)
	if n != null:
		var tw := create_tween()
		tw.tween_property(n, "position:z", FRONT_Z - 0.002, 0.04)
		tw.tween_property(n, "position:z", FRONT_Z + 0.006, 0.1)
	_msg_t = 0.0
	if key == "*":
		entry = ""
		_show()
		key_pressed.emit(key, true)
		return ""
	if key == "#":
		_data()
		var action := ""
		if codes.has(entry):
			action = str(codes[entry])
		var ok := action != ""
		_flash("OK" if ok else "ERR", ok)
		entry = ""
		key_pressed.emit(key, ok)
		if ok:
			code_entered.emit(action)
		return action
	if entry.length() < 6:
		entry += key
	_show()
	key_pressed.emit(key, true)
	return ""


func _show() -> void:
	display.text = entry if entry != "" else "- - - -"
	display.modulate = Color(0.45, 1.0, 0.55)


func _flash(text: String, ok: bool) -> void:
	display.text = text
	display.modulate = Color(0.45, 1.0, 0.55) if ok else Color(1.0, 0.3, 0.25)
	_msg_t = 1.4


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_show()
