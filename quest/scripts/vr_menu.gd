class_name VRMenu
extends Node3D
## The options board: a floating panel the player points at with a controller beam and clicks with the trigger.
## The board is ordinary Godot UI drawn into a SubViewport and shown on a quad; mouse events are fed in from the beam.

signal changed(key: String, value)
signal action(name: String)

const VIEW := Vector2i(1100, 900)
const SIZE := Vector2(1.1, 0.9)
const TOPPERS := {"grey": Color("#9aa3ad"), "red": Color("#e3262a"), "yellow": Color("#f5b800"), "blue": Color("#2f7bff"), "green": Color("#2fcf55")}

var open := false
var build_number := 0
var viewport: SubViewport
var quad: MeshInstance3D
var beam: MeshInstance3D
var dot: MeshInstance3D
var font: Font
var values := {}
var _widgets := {}
var _last_px := Vector2(-1, -1)
var _pressed := false
var _tex_mat: StandardMaterial3D


func build(root: Node3D, ui_font: Font, initial: Dictionary, build_no := 0) -> void:
	build_number = build_no
	font = ui_font
	values = initial.duplicate()
	root.add_child(self)
	viewport = SubViewport.new()
	viewport.size = VIEW
	viewport.transparent_bg = true
	viewport.gui_disable_input = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	_build_ui()
	quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = SIZE
	quad.mesh = qm
	_tex_mat = StandardMaterial3D.new()
	_tex_mat.albedo_texture = viewport.get_texture()
	_tex_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tex_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tex_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_tex_mat.no_depth_test = true          # always drawn over the machine, never hidden inside it
	_tex_mat.render_priority = 20
	_tex_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	quad.material_override = _tex_mat
	add_child(quad)
	beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.002
	cm.bottom_radius = 0.002
	cm.height = 1.0
	cm.radial_segments = 6
	beam.mesh = cm
	beam.material_override = VRBuild.mat(Color(0.6, 0.9, 1.0), 0.4, 0.0, 3.0)
	add_child(beam)
	dot = VRBuild.sphere(self, 0.008, Vector3.ZERO, VRBuild.mat(Color(1, 1, 1), 0.4, 0.0, 4.0), 8)
	set_open(false)


func set_open(on: bool) -> void:
	if not on:
		_release()
	open = on
	visible = on
	beam.visible = false
	dot.visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


## Puts the board in front of the player, turned to face them.
func present(head: Vector3, forward: Vector3) -> void:
	var f := Vector3(forward.x, 0.0, forward.z).normalized()
	scale = Vector3.ONE * 0.7      # close in, and drawn over everything
	global_position = Vector3(head.x, head.y - 0.12, head.z) + f * 0.48
	look_at(Vector3(head.x, head.y - 0.1, head.z), Vector3.UP)
	# look_at points -Z at the player; the quad faces +Z, so turn it round
	rotate_object_local(Vector3.UP, PI)


func set_value(key: String, v) -> void:
	values[key] = v
	_refresh(key)


# ---- the pointer -----------------------------------------------------------------------------------
## Feeds one hand's beam into the board. Returns true when the beam is over the board.
func point(origin: Vector3, dir: Vector3, trigger_down: bool, with_beam := true) -> bool:
	if not open:
		return false
	var n := global_transform.basis.z
	var denom := dir.dot(n)
	if absf(denom) < 0.0001:
		_release()
		dot.visible = false
		beam.visible = false
		return false
	var t := (global_position - origin).dot(n) / denom
	if t < 0.05 or t > 6.0:
		_release()
		dot.visible = false
		beam.visible = false
		return false
	var hit := origin + dir * t
	var l := to_local(hit)
	var over := absf(l.x) <= SIZE.x / 2.0 and absf(l.y) <= SIZE.y / 2.0
	if with_beam:
		_show_beam(origin, hit, over)
	else:
		beam.visible = false
		dot.visible = over
		dot.global_position = hit
	if not over:
		_release()
		return false
	var px := Vector2((l.x / SIZE.x + 0.5) * VIEW.x, (0.5 - l.y / SIZE.y) * VIEW.y)
	var mm := InputEventMouseMotion.new()
	mm.position = px
	mm.global_position = px
	mm.relative = px - _last_px if _last_px.x >= 0.0 else Vector2.ZERO
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT if _pressed else 0
	viewport.push_input(mm)
	_last_px = px
	if trigger_down and not _pressed:
		_pressed = true
		_click(px, true)
	elif not trigger_down and _pressed:
		_release()
	return true


func _click(px: Vector2, down: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.position = px
	mb.global_position = px
	mb.pressed = down
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	viewport.push_input(mb)


func _release() -> void:
	if _pressed:
		_pressed = false
		_click(_last_px, false)


func _show_beam(a: Vector3, b: Vector3, over: bool) -> void:
	beam.visible = true
	dot.visible = over
	dot.global_position = b
	beam.global_position = (a + b) / 2.0
	beam.global_transform.basis = Basis.looking_at((b - a).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI / 2)
	beam.scale = Vector3(1, a.distance_to(b), 1)


# ---- the board itself -------------------------------------------------------------------------------------
func _style(c: Color, border := Color(0, 0, 0, 0), radius := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(3 if border.a > 0.0 else 0)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _button(text: String, color := Color("#262a44"), size := 34) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 62)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.7))
	b.add_theme_stylebox_override("normal", _style(color, Color(1, 1, 1, 0.12)))
	b.add_theme_stylebox_override("hover", _style(color.lightened(0.25), Color(1, 0.95, 0.5, 0.9)))
	b.add_theme_stylebox_override("pressed", _style(color.darkened(0.2), Color(1, 1, 1, 0.9)))
	b.focus_mode = Control.FOCUS_NONE
	return b


func _label(text: String, size := 32, color := Color(0.85, 0.9, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


const PAGES := [["play", "PLAY", Color("#1f8f4a")], ["avatar", "AVATAR", Color("#7a3fd0")], ["hands", "HANDS", Color("#2a7fb8")], ["comfort", "COMFORT", Color("#b8782a")], ["display", "DISPLAY", Color("#2a9aa8")], ["sound", "SOUND", Color("#a82a6a")]]
var LABELS := {
	"handmode": {"auto": "AUTO", "controllers": "CONTROLLERS", "hands": "BARE HANDS"},
	"body": {"full": "FULL BODY", "arms": "ARMS ONLY", "hands": "HANDS ONLY"},
}

var _pages := {}
var _tabs := {}
var _page_name := "play"


func _page(name: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.visible = false
	_pages[name] = v
	return v


func _heading(parent: Control, text: String) -> void:
	var l := _label(text, 30, Color(0.4, 1.0, 0.7))
	parent.add_child(l)


func _hint(parent: Control, text: String) -> void:
	var l := _label(text, 26, Color(0.7, 0.75, 0.9))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(0, 70)
	parent.add_child(l)


func show_page(name: String) -> void:
	_page_name = name
	for k in _pages:
		_pages[k].visible = k == name
	for k in _tabs:
		var b: Button = _tabs[k]
		var on: bool = k == name
		var col: Color = PAGES[_page_index(k)][2]
		b.add_theme_stylebox_override("normal", _style(col if on else Color("#1b1e34"), Color(1, 1, 1, 0.9) if on else Color(1, 1, 1, 0.1)))


func _page_index(name: String) -> int:
	for i in range(PAGES.size()):
		if PAGES[i][0] == name:
			return i
	return 0


func _build_ui() -> void:
	var back := PanelContainer.new()
	back.size = Vector2(VIEW)
	back.add_theme_stylebox_override("panel", _style(Color(0.035, 0.05, 0.065, 0.98), Color(0.32, 0.52, 0.58, 0.9), 18))
	viewport.add_child(back)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	back.add_child(root)
	var title := _label("FATTY'S GAME SHACK" + ("      build %d" % build_number if build_number > 0 else ""), 50, Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	# the tabs down the left
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.custom_minimum_size = Vector2(230, 0)
	body.add_child(tabs)
	for pg in PAGES:
		var tb := _button(pg[1], Color("#1b1e34"), 36)
		tb.custom_minimum_size = Vector2(230, 72)
		var id: String = pg[0]
		tb.pressed.connect(func(): show_page(id))
		tabs.add_child(tb)
		_tabs[id] = tb
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(holder)
	for pg in PAGES:
		var pv := _page(pg[0])
		holder.add_child(pv)
		pv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# PLAY
	var play: VBoxContainer = _pages.play
	_heading(play, "GO TO")
	var go := GridContainer.new()
	go.columns = 2
	go.add_theme_constant_override("h_separation", 12)
	go.add_theme_constant_override("v_separation", 12)
	play.add_child(go)
	for g in [["PINBALL LEFT", "pinball", "#356c78"], ["PINBALL RIGHT", "pinball2", "#356c78"], ["AVATAR LOCKER", "skins", "#7a3fd0"], ["JUKEBOX", "jukebox", "#b8782a"], ["SNACKS", "vending", "#a8302a"], ["BOARD GAME", "lounge", "#2a9a4a"], ["HALL OF FAME", "hall", "#a88a1a"], ["THE DOOR", "exit", "#2a5fa8"]]:
		var gb := _button(g[0], Color(g[2]), 30)
		gb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var gid: String = g[1]
		gb.pressed.connect(func(): action.emit("goto:" + gid))
		go.add_child(gb)
	_heading(play, "BOSS BATTLE")
	var names: Array = []
	for b in ZSEngine.BOSSES:
		names.append(str(b.name))
	_stepper(play, "battle", "Boss", names, "")
	var fight := _button("FIGHT THIS BOSS (PRACTICE)", Color("#7a2a8f"), 32)
	fight.pressed.connect(func(): action.emit("fight"))
	play.add_child(fight)
	var story := _button("REPLAY THE STORY (comic intro)", Color("#2a5fa8"), 30)
	story.pressed.connect(func(): action.emit("story"))
	play.add_child(story)
	# AVATAR
	var av: VBoxContainer = _pages.avatar
	_heading(av, "YOUR LOOK")
	var skin_ids: Array = []
	var skin_labels := {}
	for sk in VRAvatar.SKINS:
		skin_ids.append(sk.id)
		skin_labels[sk.id] = sk.name
	LABELS["skin"] = skin_labels
	_stepper(av, "skin", "Outfit", skin_ids, "")
	_stepper(av, "body", "Show", ["full", "arms", "hands"], "")
	_hint(av, "Try outfits on at the Avatar Locker, the machine in the back right corner. It shows your character turning on a stand.")
	var lock := _button("GO TO THE AVATAR LOCKER", Color("#7a3fd0"), 32)
	lock.pressed.connect(func(): action.emit("goto:skins"))
	av.add_child(lock)
	# HANDS
	var hd: VBoxContainer = _pages.hands
	_heading(hd, "CONTROLS")
	_stepper(hd, "handmode", "Input", ["auto", "controllers", "hands"], "")
	_hint(hd, "AUTO uses controllers when you hold them and your bare hands when you put them down. With bare hands: point and pinch to choose, touch buttons with a finger, turn your left palm up for the wrist panel.")
	_stepper(hd, "pointer", "Pointer hand", ["right", "left"], "")
	_stepper(hd, "assist", "Controller assist (marks scores *)", ["off", "on"], "")
	_slider(hd, "haptics", "Vibration", 0.0, 1.0, 0.1)
	_heading(hd, "IF HANDS LOOK TWISTED")
	_stepper(hd, "handroll", "Hand roll", [-90, -60, -30, 0, 30, 60, 90, 180], "°")
	_stepper(hd, "handtilt", "Hand tilt", [-90, -60, -45, -30, 0, 30, 45, 60, 90], "°")
	# COMFORT
	var cf: VBoxContainer = _pages.comfort
	_heading(cf, "HEIGHT AND DISTANCE")
	_slider(cf, "lift", "Player height", -0.5, 0.8, 0.02)
	_slider(cf, "reach", "Distance to machine", -0.25, 0.4, 0.02)
	_heading(cf, "MOVING")
	_stepper(cf, "turn", "Turning", ["smooth", "snap"], "")
	_stepper(cf, "turnspeed", "Smooth turn speed", [60, 90, 120, 150], "°/s")
	_stepper(cf, "snap", "Snap turn size", [15, 30, 45, 60, 90], "°")
	_stepper(cf, "walk", "Walk speed", [1.0, 1.5, 2.0, 2.5], " m/s")
	# DISPLAY
	var dp: VBoxContainer = _pages.display
	_heading(dp, "PICTURE")
	_slider(dp, "sharp", "Sharpness", 0.9, 1.6, 0.1)
	_hint(dp, "Higher is clearer far away but works the headset harder. Lower it if the picture stutters.")
	_stepper(dp, "glow", "Soft glow on neon", ["on", "off"], "")
	_stepper(dp, "hud", "Screen shake", ["on", "off"], "")
	_heading(dp, "JOYSTICK TOP")
	var sw := HBoxContainer.new()
	sw.add_theme_constant_override("separation", 10)
	dp.add_child(sw)
	for k in TOPPERS:
		var b := _button("", TOPPERS[k])
		b.custom_minimum_size = Vector2(88, 80)
		b.pressed.connect(func():
			set_value("topper", k)
			changed.emit("topper", k))
		sw.add_child(b)
		_widgets["topper_" + k] = b
	# SOUND
	var sd: VBoxContainer = _pages.sound
	_heading(sd, "VOLUME")
	_slider(sd, "music", "Music", 0.0, 1.0, 0.05)
	_slider(sd, "effects", "Effects", 0.0, 1.0, 0.05)
	# the buttons that are always there
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	root.add_child(row)
	for a in [["RESUME", "resume", Color("#1f8f4a")], ["RECENTRE", "recentre", Color("#2a5fa8")], ["END GAME", "end", Color("#a8302a")], ["EXIT ARCADE", "quit", Color("#5a1a1a")]]:
		var bt := _button(a[0], a[2], 36)
		bt.custom_minimum_size = Vector2(0, 76)
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.pressed.connect(func(): action.emit(a[1]))
		row.add_child(bt)
	for k in values:
		_refresh(k)
	show_page("play")


func _slider(parent: Control, key: String, text: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var l := _label(text, 30)
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 52)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.18, 0.2, 0.34)
	track.set_corner_radius_all(8)
	track.content_margin_top = 10
	track.content_margin_bottom = 10
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.85, 1.0)
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 10
	fill.content_margin_bottom = 10
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob()
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v: float):
		if not is_equal_approx(float(values.get(key, -1.0)), v):
			values[key] = v
			changed.emit(key, v))
	row.add_child(s)
	_widgets[key] = s


func _knob() -> ImageTexture:
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	for x in range(40):
		for y in range(40):
			var d := Vector2(x - 19.5, y - 19.5).length()
			if d < 19.0:
				img.set_pixel(x, y, Color(1, 0.95, 0.6) if d < 14.0 else Color(0.1, 0.1, 0.2))
	return ImageTexture.create_from_image(img)


func _stepper(parent: Control, key: String, text: String, options: Array, suffix: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := _label(text, 30)
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	var minus := _button("<", Color("#262a44"), 34)
	minus.custom_minimum_size = Vector2(64, 62)
	row.add_child(minus)
	var val := _label("", 30, Color(1, 0.95, 0.6))
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(val)
	var plus := _button(">", Color("#262a44"), 34)
	plus.custom_minimum_size = Vector2(64, 62)
	row.add_child(plus)
	var step := func(dir: int):
		var i := options.find(values.get(key, options[0]))
		i = posmod(i + dir, options.size())
		set_value(key, options[i])
		changed.emit(key, options[i])
	minus.pressed.connect(func(): step.call(-1))
	plus.pressed.connect(func(): step.call(1))
	_widgets[key] = {"label": val, "suffix": suffix}


func _refresh(key: String) -> void:
	if key == "topper":
		for k in TOPPERS:
			var b: Button = _widgets.get("topper_" + k)
			if b != null:
				b.text = "✓" if values.get("topper", "yellow") == k else ""
		return
	var w = _widgets.get(key)
	if w == null:
		return
	if w is HSlider:
		w.set_value_no_signal(float(values[key]))
	elif w is Dictionary:
		var v = values[key]
		if LABELS.has(key) and LABELS[key].has(v):
			w.label.text = str(LABELS[key][v])
		else:
			w.label.text = ("%s%s" % [str(v), w.suffix]) if v is String or w.suffix != "" else str(v)
