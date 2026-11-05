class_name SkinMachine
extends Node3D
## The avatar locker: an arcade cabinet whose screen shows your character turning on a spotlit stand. Press the arrow buttons (with a finger, a
## pinch-poke, or flick the left stick) to try each outfit on; SELECT puts it on. The choice is kept and your own body, arms and gloves change.
## Local axes: the front faces +Z, the floor is y = 0.

signal chosen(skin_id: String)
signal sound(kind: String)

const W := 0.74
const H := 2.0
const D := 0.6
const LEDGE_Y := 1.0
const LEDGE_Z := 0.46
const SCREEN := Vector2(0.54, 0.70)
const VIEW := Vector2i(540, 700)

var index := 0
var equipped := ""
var viewport: SubViewport
var preview: VRAvatar
var buttons := {}                 # name -> button node
var _font: Font
var _name: Label
var _count: Label
var _state: Label
var _t := 0.0
var _awake := false


func build(font: Font, equipped_id: String) -> void:
	_font = font
	equipped = equipped_id
	index = VRAvatar.skin_index(equipped_id)
	var body := VRBuild.mat(Color(0.05, 0.04, 0.09), 0.5, 0.2)
	var trim_c := VRBuild.mat(Color(0.15, 0.85, 1.0), 0.4, 0.0, 2.6)
	var pink := VRBuild.mat(Color(1.0, 0.25, 0.7), 0.4, 0.0, 2.2)
	VRBuild.box(self, Vector3(W, H - 0.22, D), Vector3(0, (H - 0.22) / 2.0, 0), body)
	VRBuild.box(self, Vector3(W + 0.04, 0.22, D + 0.04), Vector3(0, H - 0.11, 0), VRBuild.mat(Color(0.08, 0.05, 0.14), 0.45, 0.25))    # the header
	for sx in [-1.0, 1.0]:
		VRBuild.box(self, Vector3(0.02, H - 0.22, 0.02), Vector3(sx * (W / 2.0 + 0.002), (H - 0.22) / 2.0, D / 2.0), trim_c)           # neon edges down the front
		VRBuild.box(self, Vector3(0.02, 0.22, 0.02), Vector3(sx * (W / 2.0 + 0.02), H - 0.11, D / 2.0 + 0.02), pink)
	VRBuild.box(self, Vector3(W, 0.02, 0.02), Vector3(0, H + 0.002, D / 2.0 + 0.02), pink)
	var head_l := VRBuild.label(self, "AVATAR LOCKER", 0.095, Vector3(0, H - 0.085, D / 2.0 + 0.0215), Color(1.0, 0.95, 0.5), Vector3.ZERO, 8, _font, true)
	head_l.shaded = false
	VRBuild.label(self, "CHOOSE YOUR LOOK", 0.04, Vector3(0, H - 0.17, D / 2.0 + 0.0215), Color(0.3, 0.95, 1.0), Vector3.ZERO, 4, _font, true)
	# the screen: a live 3D view of the character
	_build_viewport()
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = viewport.get_texture()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	VRBuild.box(self, Vector3(SCREEN.x + 0.06, SCREEN.y + 0.06, 0.02), Vector3(0, 1.41, D / 2.0 + 0.0), VRBuild.mat(Color(0.01, 0.01, 0.02), 0.2))       # glass surround
	VRBuild.quad(self, SCREEN, Vector3(0, 1.41, D / 2.0 + 0.0115), sm)
	# the control ledge with its three big buttons
	VRBuild.box(self, Vector3(W + 0.04, 0.07, LEDGE_Z - D / 2.0 + 0.1), Vector3(0, LEDGE_Y - 0.035, D / 2.0 + (LEDGE_Z - D / 2.0 - 0.1) / 2.0 + 0.05), VRBuild.mat(Color(0.1, 0.08, 0.16), 0.4, 0.3))
	var defs := [["prev", -0.2, Color(0.15, 0.7, 1.0), "<"], ["select", 0.0, Color(0.2, 0.95, 0.4), "OK"], ["next", 0.2, Color(0.15, 0.7, 1.0), ">"]]
	for d in defs:
		var node := Node3D.new()
		node.position = Vector3(d[1], LEDGE_Y + 0.0, D / 2.0 + 0.19)
		add_child(node)
		var radius := 0.058 if d[0] == "select" else 0.048
		VRBuild.cylinder(node, radius + 0.012, 0.012, Vector3(0, -0.006, 0), VRBuild.mat(Color(0.03, 0.03, 0.04), 0.4, 0.5), -1.0, Vector3.ZERO, 24)
		var cap := VRBuild.cylinder(node, radius, 0.03, Vector3(0, 0.015, 0), VRBuild.mat(d[2], 0.3, 0.0, 1.4, d[2]), -1.0, Vector3.ZERO, 24)
		cap.name = "cap"
		VRBuild.label(node, str(d[3]), 0.05, Vector3(0, 0.0311, 0), Color(0.02, 0.02, 0.03), Vector3(-PI / 2, 0, 0), 0, _font)
		buttons[d[0]] = node
	VRBuild.box(self, Vector3(0.3, 0.012, 0.004), Vector3(0, 0.62, D / 2.0 + 0.002), VRBuild.mat(Color(0.02, 0.02, 0.03), 0.4))       # a coin slot
	VRBuild.label(self, "FREE PLAY", 0.035, Vector3(0, 0.66, D / 2.0 + 0.004), Color(1.0, 0.8, 0.3), Vector3.ZERO, 3, _font)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 1.5, 0.9)
	glow.light_color = Color(0.7, 0.5, 1.0)
	glow.light_energy = 0.7
	glow.omni_range = 2.2
	add_child(glow)
	_show(0)


func _build_viewport() -> void:
	viewport = SubViewport.new()
	viewport.size = VIEW
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.03, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.75)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 36
	viewport.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.75, 4.4), Vector3(0, 0.62, 0), Vector3.UP)
	cam.current = true
	var key := OmniLight3D.new()
	key.position = Vector3(1.2, 2.2, 2.2)
	key.light_energy = 2.2
	key.omni_range = 9.0
	viewport.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.6, 1.6, -1.8)
	rim.light_color = Color(1.0, 0.3, 0.8)
	rim.light_energy = 2.5
	rim.omni_range = 9.0
	viewport.add_child(rim)
	var stand := VRBuild.cylinder(viewport, 0.62, 0.06, Vector3(0, -0.03, 0), VRBuild.mat(Color(0.12, 0.1, 0.2), 0.3, 0.6), -1.0, Vector3.ZERO, 40)
	VRBuild.cylinder(viewport, 0.64, 0.01, Vector3(0, 0.003, 0), VRBuild.mat(Color(0.2, 0.9, 1.0), 0.3, 0.0, 3.0), -1.0, Vector3.ZERO, 40)
	stand.name = "stand"
	preview = VRAvatar.new()
	viewport.add_child(preview)
	preview.build(false)
	preview.apply_skin(VRAvatar.SKINS[index].id)
	# the words on the screen
	var ui := Control.new()
	ui.size = Vector2(VIEW)
	viewport.add_child(ui)
	_name = _text("", 62, Color(1, 1, 1))
	_name.position = Vector2(0, VIEW.y - 190)
	_name.size = Vector2(VIEW.x, 80)
	ui.add_child(_name)
	_count = _text("", 36, Color(0.5, 0.95, 1.0))
	_count.position = Vector2(0, VIEW.y - 112)
	_count.size = Vector2(VIEW.x, 50)
	ui.add_child(_count)
	_state = _text("", 40, Color(0.4, 1.0, 0.5))
	_state.position = Vector2(0, VIEW.y - 66)
	_state.size = Vector2(VIEW.x, 56)
	ui.add_child(_state)


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	return l


func _show(dir: int) -> void:
	index = posmod(index, VRAvatar.SKINS.size())
	var s: Dictionary = VRAvatar.SKINS[index]
	if preview != null and preview.skin_id != s.id:
		preview.apply_skin(s.id)
	if _name != null:
		_name.text = s.name
		_count.text = "<   %d / %d   >" % [index + 1, VRAvatar.SKINS.size()]
		var on: bool = s.id == equipped
		_state.text = "WEARING THIS" if on else "PRESS OK TO WEAR"
		_state.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if on else Color(1.0, 0.85, 0.3))
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _awake else SubViewport.UPDATE_ONCE


func set_equipped(id: String) -> void:
	equipped = id
	_show(0)


## Called every frame: the figure turns and waves, and the screen only redraws while someone is near.
func animate(delta: float, near: bool) -> void:
	_awake = near
	if viewport == null:
		return
	if near:
		_t += delta
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		preview.pose_idle(Vector3.ZERO, PI + sin(_t * 0.7) * 0.9, delta)
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


## Which button a fingertip (world position) is pressing, or "".
func button_at(world: Vector3) -> String:
	var p := to_local(world)
	for k in buttons:
		var n: Node3D = buttons[k]
		if absf(p.x - n.position.x) < 0.06 and absf(p.z - n.position.z) < 0.06 and p.y > LEDGE_Y - 0.02 and p.y < LEDGE_Y + 0.07:
			return k
	return ""


func press(name: String) -> void:
	var n: Node3D = buttons.get(name)
	if n == null:
		return
	var tw := create_tween()
	tw.tween_property(n, "position:y", LEDGE_Y - 0.012, 0.04)
	tw.tween_property(n, "position:y", LEDGE_Y, 0.14)
	match name:
		"prev":
			index -= 1
			sound.emit("click")
			_show(-1)
		"next":
			index += 1
			sound.emit("click")
			_show(1)
		"select":
			var id: String = VRAvatar.SKINS[index].id
			equipped = id
			sound.emit("chime")
			_show(0)
			chosen.emit(id)
