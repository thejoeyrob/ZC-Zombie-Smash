class_name VRMenu
extends Node3D
## The options board: a floating panel the player points at with a controller beam and clicks with the trigger.
## The board is ordinary Godot UI drawn into a SubViewport and shown on a quad; mouse events are fed in from the beam.

signal changed(key: String, value)
signal action(name: String)

const VIEW := Vector2i(1440, 1080)
const SIZE := Vector2(1.12, 0.84)
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
var _armed := false
var _scrolls := {}
var _value_labels := {}
var _confirm_layer: Control
var _confirm_title: Label
var _pending_action := ""
var _tex_mat: StandardMaterial3D


func build(root: Node3D, ui_font: Font, initial: Dictionary, build_no := 0) -> void:
	build_number = build_no
	font = ui_font
	values = initial.duplicate()
	for key in {"sports_players": 1, "bowling_lane": 1, "darts_lane": 1, "axe_lane": 1, "darts_mode": "501", "axe_mode": "CLASSIC"}:
		if not values.has(key):
			values[key] = {"sports_players": 1, "bowling_lane": 1, "darts_lane": 1, "axe_lane": 1, "darts_mode": "501", "axe_mode": "CLASSIC"}[key]
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
	cm.top_radius = 0.0025
	cm.bottom_radius = 0.0025
	beam.material_override = _on_top(Color(0.55, 0.92, 1.0, 0.95))
	add_child(beam)
	# the dot where the beam meets the board: a bright core with a soft ring, drawn over the board so you can always see where you are pointing
	dot = VRBuild.sphere(self, 0.010, Vector3.ZERO, _on_top(Color(1, 1, 1, 1.0)), 10)
	var ring := VRBuild.sphere(dot, 0.020, Vector3.ZERO, _on_top(Color(0.4, 0.9, 1.0, 0.35)), 10)
	ring.name = "Ring"
	set_open(false)


## A bright flat colour that is never hidden by the board (the board itself is drawn over everything, so the pointer is drawn after it).
func _on_top(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 40
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func set_open(on: bool) -> void:
	if not on:
		_cancel_pointer()
	_armed = false
	if _confirm_layer != null:
		_confirm_layer.visible = false
	_accept_ready=false
	_nav_ready=true
	open = on
	visible = on
	beam.visible = false
	dot.visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


## Puts the board in front of the player, turned to face them.
func present(head: Vector3, forward: Vector3) -> void:
	var f := Vector3(forward.x, 0.0, forward.z).normalized()
	if f.length_squared() < 0.01:
		f = Vector3.FORWARD
	scale = Vector3.ONE
	global_position = Vector3(head.x, head.y - 0.10, head.z) + f * 0.82
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
	if not trigger_down:
		_armed = true
	var n := global_transform.basis.z
	var denom := dir.dot(n)
	if absf(denom) < 0.0001:
		_cancel_pointer()
		dot.visible = false
		beam.visible = false
		return false
	var t := (global_position - origin).dot(n) / denom
	if t < 0.05 or t > 6.0:
		_cancel_pointer()
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
		_cancel_pointer()
		return false
	var px := Vector2((l.x / SIZE.x + 0.5) * VIEW.x, (0.5 - l.y / SIZE.y) * VIEW.y)
	var mm := InputEventMouseMotion.new()
	mm.position = px
	mm.global_position = px
	mm.relative = px - _last_px if _last_px.x >= 0.0 else Vector2.ZERO
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT if _pressed else 0
	viewport.push_input(mm)
	_last_px = px
	if trigger_down and not _pressed and _armed:
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


## Leaving the panel cancels a press: do not send a release over the old button.
func _cancel_pointer() -> void:
	if _pressed:
		var move := InputEventMouseMotion.new()
		move.position = Vector2(-100, -100)
		move.global_position = move.position
		viewport.push_input(move)
		_pressed = false
		_click(move.position, false)
	_last_px = Vector2(-1, -1)
	_armed = false


func scroll_page(pixels: float) -> void:
	if not open or (_confirm_layer != null and _confirm_layer.visible):
		return
	var sc: ScrollContainer = _scrolls.get(_page_name)
	if sc != null:
		sc.scroll_vertical += int(pixels)


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


func _button(text: String, color := Color("#23333d"), size := 34) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 68)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color("#ffffff"))
	b.add_theme_stylebox_override("normal", _style(color, Color(1, 1, 1, 0.12)))
	b.add_theme_stylebox_override("hover", _style(color.lightened(0.15), Color("#69d6bb")))
	b.add_theme_stylebox_override("pressed", _style(color.darkened(0.2), Color("#69d6bb")))
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


const PAGES := [["play", "THE SHACK", Color("#236b60")], ["sports", "SPORTS", Color("#236b60")], ["friends", "FRIENDS", Color("#236b60")], ["avatar", "CHARACTER", Color("#236b60")], ["comfort", "COMFORT", Color("#236b60")], ["display", "SOUND", Color("#236b60")]]
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
	var l := _label(text, 30, Color("#8fe1ca"))
	parent.add_child(l)


func _hint(parent: Control, text: String) -> void:
	var l := _label(text, 26, Color("#a8bcc6"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(0, 70)
	parent.add_child(l)


func show_page(name: String) -> void:
	if not _pages.has(name):
		return
	_page_name = name
	for k in _pages:
		_scrolls[k].visible = k == name
	for k in _tabs:
		var b: Button = _tabs[k]
		var on: bool = k == name
		var col: Color = PAGES[_page_index(k)][2]
		b.add_theme_stylebox_override("normal", _style(col if on else Color("#1b2b34"), Color(1, 1, 1, 0.9) if on else Color(1, 1, 1, 0.1)))


func _page_index(name: String) -> int:
	for i in range(PAGES.size()):
		if PAGES[i][0] == name:
			return i
	return 0


func _action_button(parent: Control, text: String, id: String, primary := false, confirmation := "") -> Button:
	var button := _button(text, Color("#276e60") if primary else Color("#23333d"), 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func():
		if confirmation != "":
			ask(id, confirmation)
		else:
			action.emit(id))
	parent.add_child(button)
	return button


func ask(id: String, question: String) -> void:
	_pending_action = id
	_confirm_title.text = question
	_confirm_layer.show()


func _build_ui() -> void:
	var back := PanelContainer.new()
	back.size = Vector2(VIEW)
	back.add_theme_stylebox_override("panel", _style(Color("#101b22"), Color("#42606a"), 24))
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 28
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "Button", _style(Color("#2d564f") if state == "hover" else Color("#23333d"), Color("#63877e") if state == "focus" else Color(1, 1, 1, 0.1), 10))
	theme.set_color("font_color", "Button", Color("#e7f1f4"))
	theme.set_color("font_color", "Label", Color("#d0e1e8"))
	back.theme = theme
	viewport.add_child(back)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	back.add_child(root)
	var title_row := HBoxContainer.new()
	root.add_child(title_row)
	var title := _label("FATTY'S GAME SHACK", 48, Color("#f3d39b"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var subtitle := _label("YOUR NIGHT. YOUR GAME.", 25, Color("#8fb3b8"))
	title_row.add_child(subtitle)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	tabs.custom_minimum_size = Vector2(264, 0)
	body.add_child(tabs)
	for pg in PAGES:
		var tb := _button(pg[1], Color("#1b2b34"), 30)
		tb.custom_minimum_size = Vector2(264, 80)
		var id: String = pg[0]
		tb.pressed.connect(func(): show_page(id))
		tabs.add_child(tb)
		_tabs[id] = tb
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var scroll_row := HBoxContainer.new()
	tabs.add_child(scroll_row)
	for entry in [["UP", -420], ["DOWN", 420]]:
		var sb := _button(entry[0], Color("#23333d"), 25)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.pressed.connect(func(): scroll_page(float(entry[1])))
		scroll_row.add_child(sb)
	_hint(tabs, "Point + trigger
Thumbstick to scroll")
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(holder)
	for pg in PAGES:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		sc.follow_focus = true
		sc.get_v_scroll_bar().custom_minimum_size.x = 32
		holder.add_child(sc)
		sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var pv := _page(pg[0])
		pv.visible = true
		pv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var padding := MarginContainer.new()
		padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		padding.add_theme_constant_override("margin_right", 42)
		sc.add_child(padding)
		padding.add_child(pv)
		_scrolls[pg[0]] = sc
	var play: VBoxContainer = _pages.play
	_heading(play, "MAKE YOURSELF AT HOME")
	_hint(play, "Pick a game, meet your friends or explore the arcade. Open this menu any time with the menu button.")
	_action_button(play, "RESUME PLAYING", "resume", true)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	play.add_child(grid)
	for entry in [["STRIKERS BOWLING", "visit_bowling"], ["DARTS", "visit_darts"], ["ODIN'S AXE TOSS", "visit_axes"], ["EXPLORE THE ARCADE", "visit_arcade"], ["PINBALL", "visit_pinball"], ["LOUNGE", "visit_lounge"]]:
		var tile := _action_button(grid, entry[0], entry[1])
		tile.custom_minimum_size.y = 98
	var setup := _button("SPORTS SETUP & HOW TO PLAY", Color("#304e56"), 28)
	setup.pressed.connect(func(): show_page("sports"))
	play.add_child(setup)
	_heading(play, "ZOMBIE SMASH")
	var names: Array = []
	for boss in ZSEngine.BOSSES:
		names.append(str(boss.name))
	_stepper(play, "battle", "Practice boss", names, "")
	_action_button(play, "PRACTICE THIS BOSS", "fight")
	_action_button(play, "REPLAY STORY", "story")
	_action_button(play, "END CURRENT ARCADE GAME", "end", false, "End your current arcade game?
Your unfinished run will be lost.")
	var sp: VBoxContainer = _pages.sports
	_heading(sp, "SPORTS NIGHT")
	_hint(sp, "Play solo or take turns on this headset. Choose your station and rules below, then start a new match. Visit a sport from The Shack to continue an existing match.")
	_stepper(sp, "sports_players", "Local players", [1, 2, 3, 4], "")
	_heading(sp, "01  STRIKERS BOWLING")
	_hint(sp, "Grip the ball, swing underarm and release. Wrist rotation adds hook. Ten frames with proper strike, spare and final-frame bonuses.")
	_stepper(sp, "bowling_lane", "Lane", [1, 2], "")
	_action_button(sp, "START BOWLING", "sport_bowling", true, "Start a new bowling match?
This replaces the selected lane's scores.")
	_heading(sp, "02  DARTS")
	_hint(sp, "Take one dart at a time. Grip near the barrel, aim and release with a natural follow-through. 501 and 301 finish on a double; Cricket closes 15–20 and bull.")
	_stepper(sp, "darts_lane", "Board", [1, 2], "")
	_stepper(sp, "darts_mode", "Rules", ["501", "301", "CRICKET"], "")
	_action_button(sp, "START DARTS", "sport_darts", true, "Start a new darts match?
This replaces the selected board's scores.")
	_heading(sp, "03  ODIN'S AXE TOSS")
	_hint(sp, "Grip the handle, stand at the line and release towards your target. Blade angle matters. Classic scores nine throws; Blitz rewards consecutive bullseyes.")
	_stepper(sp, "axe_lane", "Lane", [1, 2, 3], "")
	_stepper(sp, "axe_mode", "Rules", ["CLASSIC", "BULLSEYE BLITZ"], "")
	_action_button(sp, "START AXE THROWING", "sport_axes", true, "Start a new axe match?
This replaces the selected lane's scores.")
	_heading(_pages.friends, "BRING YOUR FRIENDS")
	var av: VBoxContainer = _pages.avatar
	_heading(av, "MAKE IT YOURS")
	var ids: Array = []
	var names_by_id := {}
	for skin in VRAvatar.SKINS:
		ids.append(skin.id)
		names_by_id[skin.id] = skin.name
	LABELS["skin"] = names_by_id
	_stepper(av, "skin", "Character", ids, "")
	_stepper(av, "body", "Visible body", ["full", "arms", "hands"], "")
	_hint(av, "Your appearance updates immediately. The locker by the entrance gives you another place to change.")
	var cf: VBoxContainer = _pages.comfort
	_heading(cf, "FIND YOUR COMFORT")
	_stepper(cf, "turn", "Turning", ["smooth", "snap"], "")
	_stepper(cf, "pointer", "Pointer hand", ["right", "left"], "")
	_slider(cf, "haptics", "Vibration", 0.0, 1.0, 0.1)
	_slider(cf, "lift", "Player height", -0.5, 0.8, 0.02)
	var dp: VBoxContainer = _pages.display
	_heading(dp, "SOUND")
	_stepper(dp, "scares", "Door jump scares", ["on", "off"], "")
	_slider(dp, "music", "Music", 0.0, 1.0, 0.05)
	_slider(dp, "effects", "Effects", 0.0, 1.0, 0.05)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	root.add_child(footer)
	_action_button(footer, "RESUME", "resume", true)
	_action_button(footer, "RECENTRE", "recentre")
	_action_button(footer, "EXIT GAME", "quit", false, "Leave Fatty's Game Shack?")
	_build_confirmation()
	for key in values:
		_refresh(key)
	show_page("play")


func _build_confirmation() -> void:
	_confirm_layer = Control.new()
	_confirm_layer.size = Vector2(VIEW)
	viewport.add_child(_confirm_layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(290, 340)
	panel.size = Vector2(860, 350)
	panel.add_theme_stylebox_override("panel", _style(Color("#16272e"), Color("#65bcaa"), 20))
	_confirm_layer.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 30)
	panel.add_child(stack)
	_confirm_title = _label("", 34)
	_confirm_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_confirm_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	stack.add_child(row)
	var cancel := _button("KEEP PLAYING")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): _confirm_layer.hide())
	row.add_child(cancel)
	var confirm := _button("CONFIRM", Color("#276e60"))
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(func():
		_confirm_layer.hide()
		action.emit(_pending_action))
	row.add_child(confirm)
	_confirm_layer.hide()


func _slider(parent: Control, key: String, text: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var l := _label(text, 30)
	l.custom_minimum_size = Vector2(300, 0)
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
			_refresh(key)
			changed.emit(key, v))
	row.add_child(s)
	var readout := _label("", 27, Color("#8fe1ca"))
	readout.custom_minimum_size.x = 100
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	_value_labels[key] = readout
	_widgets[key] = s


func _knob() -> ImageTexture:
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	for x in range(40):
		for y in range(40):
			var d := Vector2(x - 19.5, y - 19.5).length()
			if d < 19.0:
				img.set_pixel(x, y, Color("#a3e3d1") if d < 14.0 else Color(0.1, 0.1, 0.2))
	return ImageTexture.create_from_image(img)


func _stepper(parent: Control, key: String, text: String, options: Array, suffix: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := _label(text, 30)
	l.custom_minimum_size = Vector2(280, 0)
	row.add_child(l)
	var minus := _button("<", Color("#262a44"), 34)
	minus.custom_minimum_size = Vector2(64, 62)
	row.add_child(minus)
	var val := _label("", 30, Color("#a3e3d1"))
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
		if _value_labels.has(key):
			_value_labels[key].text = _value_text(key, float(values[key]))
	elif w is Dictionary:
		var v = values[key]
		if LABELS.has(key) and LABELS[key].has(v):
			w.label.text = str(LABELS[key][v])
		else:
			w.label.text = ("%s%s" % [str(v), w.suffix]) if v is String or w.suffix != "" else str(v)


func _value_text(key: String, value: float) -> String:
	if key in ["music", "effects", "haptics", "screenlight"]:
		return "%d%%" % roundi(value * 100.0)
	if key in ["lift", "reach"]:
		return "%+d cm" % roundi(value * 100.0)
	if key == "turnspeed":
		return "%d°/s" % roundi(value)
	if key == "walk":
		return "%.1f m/s" % value
	return "%.1fx" % value

# Controller navigation after selecting a physical sports screen.
# Left stick selects, A activates, right stick continues to scroll.
var _nav_ready := true
var _accept_ready := false
func controller(stick: Vector2, accept: bool) -> void:
	if not open: return
	if not accept: _accept_ready=true
	var options: Array[Button]=[]
	var scope: Node = _confirm_layer if _confirm_layer!=null and _confirm_layer.visible else _pages[_page_name]
	for node in scope.find_children("*","Button",true,false):
		var button:=node as Button
		if button.is_visible_in_tree() and not button.disabled: options.append(button)
	if options.is_empty(): return
	var focused:=viewport.gui_get_focus_owner()
	var index:=options.find(focused)
	if absf(stick.y)<0.3: _nav_ready=true
	if absf(stick.y)>0.65 and _nav_ready:
		_nav_ready=false
		index=0 if index<0 else posmod(index+(1 if stick.y>0 else -1),options.size())
		options[index].focus_mode=Control.FOCUS_ALL
		options[index].grab_focus()
		for scroll in _scrolls.values():
			if scroll is ScrollContainer and scroll.is_ancestor_of(options[index]): scroll.ensure_control_visible(options[index])
	if accept and _accept_ready:
		_accept_ready=false
		if index>=0: options[index].pressed.emit()
