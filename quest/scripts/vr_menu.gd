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


const PAGES := [["play", "PLAY", Color("#1f8f4a")], ["friends", "FRIENDS", Color("#268a88")], ["avatar", "CHARACTER", Color("#7a3fd0")], ["comfort", "CONTROLS", Color("#b8782a")], ["display", "PICTURE + SOUND", Color("#2a9aa8")]]
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
	back.add_theme_stylebox_override("panel", _style(Color(0.025, 0.040, 0.057, 0.98), Color(0.26, 0.64, 0.58, 0.85), 18))
	viewport.add_child(back)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	back.add_child(root)
	var title := _label("FATTY'S GAME SHACK" + ("	 %d" % build_number if build_number > 0 else ""), 45, Color("#f5c968"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	tabs.custom_minimum_size = Vector2(255, 0)
	body.add_child(tabs)
	for pg in PAGES:
		var tb := _button(pg[1], Color("#1b2531"), 30)
		tb.custom_minimum_size = Vector2(255, 94)
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
	# PLAY: primary action first; practice options are secondary.
	var play: VBoxContainer = _pages.play
	_heading(play, "READY TO PLAY?")
	var resume := _button("CONTINUE PLAYING", Color("#267e59"), 36)
	resume.pressed.connect(func(): action.emit("resume"))
	play.add_child(resume)
	var names: Array = []
	for boss in ZSEngine.BOSSES:
		names.append(str(boss.name))
	_stepper(play, "battle", "Practice boss", names, "")
	var fight := _button("PRACTICE THIS BOSS", Color("#663586"), 30)
	fight.pressed.connect(func(): action.emit("fight"))
	play.add_child(fight)
	var story := _button("REPLAY STORY", Color("#275c80"), 30)
	story.pressed.connect(func(): action.emit("story"))
	play.add_child(story)
	var end := _button("END CURRENT GAME", Color("#813939"), 28)
	end.pressed.connect(func(): action.emit("end"))
	play.add_child(end)
	# FRIENDS panel populated by LobbyPanel in vr_main.gd after menu.build().
	var friends: VBoxContainer = _pages.friends
	_heading(friends, "PLAY TOGETHER")
	# CHARACTER: only the five existing bespoke game-character GLB rigs.
	var av: VBoxContainer = _pages.avatar
	_heading(av, "CHOOSE A GAME CHARACTER")
	var ids: Array = []
	var names_by_id := {}
	for skin in VRAvatar.SKINS:
		ids.append(skin.id)
		names_by_id[skin.id] = skin.name
	LABELS["skin"] = names_by_id
	_stepper(av, "skin", "Character", ids, "")
	_stepper(av, "body", "Visible body", ["full", "arms", "hands"], "")
	_hint(av, "You can also change characters at the locker by the entrance.")
	# CONTROLS: the normal player sees basic comfort and hand controls.
	var cf: VBoxContainer = _pages.comfort
	_heading(cf, "HEADSET AND HANDS")
	_slider(cf, "lift", "Player height", -0.5, 0.8, 0.02)
	_slider(cf, "reach", "Machine distance", -0.25, 0.4, 0.02)
	_stepper(cf, "handmode", "Hands", ["auto", "controllers", "hands"], "")
	_stepper(cf, "pointer", "Menu pointer", ["right", "left"], "")
	_stepper(cf, "turn", "Turning", ["smooth", "snap"], "")
	_stepper(cf, "snap", "Snap angle", [30, 45, 60], "°")
	var advanced := VBoxContainer.new()
	advanced.visible = false
	cf.add_child(advanced)
	_stepper(advanced, "handroll", "Hand roll", [-90, -60, -30, 0, 30, 60, 90, 180], "°")
	_stepper(advanced, "handtilt", "Hand tilt", [-90, -60, -45, -30, 0, 30, 45, 60, 90], "°")
	_slider(advanced, "haptics", "Vibration", 0.0, 1.0, 0.1)
	var advanced_button := _button("ADVANCED HAND ALIGNMENT", Color("#303848"), 26)
	advanced_button.pressed.connect(func():
		advanced.visible = not advanced.visible
		advanced_button.text = "HIDE ADVANCED CONTROLS" if advanced.visible else "ADVANCED HAND ALIGNMENT")
	cf.add_child(advanced_button)
	# VIDEO: preserve eye resolution; never offer silent adaptive blur.
	var dp: VBoxContainer = _pages.display
	_heading(dp, "PICTURE")
	_slider(dp, "sharp", "Image sharpness", 1.0, 1.6, 0.1)
	_slider(dp, "screenlight", "Arcade screens", 0.5, 1.15, 0.05)
	_stepper(dp, "glow", "Neon bloom", ["on", "off"], "")
	_stepper(dp, "fps", "Show FPS", ["off", "on"], "")
	_heading(dp, "SOUND")
	_slider(dp, "music", "Music", 0.0, 1.0, 0.05)
	_slider(dp, "effects", "Effects", 0.0, 1.0, 0.05)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	root.add_child(footer)
	for entry in [["RESUME", "resume", Color("#267e59")], ["RECENTRE", "recentre", Color("#325e8b")], ["EXIT ARCADE", "quit", Color("#73393b")]]:
		var b := _button(entry[0], entry[2], 32)
		b.custom_minimum_size = Vector2(0, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): action.emit(entry[1]))
		footer.add_child(b)
	for key in values:
		_refresh(key)
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
