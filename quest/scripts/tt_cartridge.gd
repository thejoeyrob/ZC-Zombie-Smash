class_name TTCartridge
extends Cartridge
## TRUCKIN' & DRIVIN' as a machine's cartridge. Input: axis (the wheel, picks the lane), fire (horn / start).

var view: TTView
var viewport: SubViewport
var active := false
var _attract_t := 0.0
var _fire_prev := false
var _step_t := 0.0


func _init() -> void:
	id = "truckin"
	title = "TRUCKIN' & DRIVIN'"
	tint = Color("#45e0c8")


func build(host: Node) -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 822)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.transparent_bg = false
	host.add_child(viewport)
	view = TTView.new()
	var k: float = 540.0 / TTView.W
	view.scale = Vector2(k, k)
	viewport.add_child(view)
	view.setup(load("res://assets/fonts/DejaVuSansMono-Bold.ttf"))
	view.sound.connect(func(n): sound.emit(n, {}))
	view.haptic.connect(func(a, d): haptic.emit(a, d))
	view.finished.connect(func(r): finished.emit(r))


func screen_texture() -> Texture2D:
	return viewport.get_texture() if viewport != null else null


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	if on and view.state == "over":
		view.reset_title()


func set_input(input: Dictionary) -> void:
	var axis: float = float(input.get("axis", 0.0))
	var st: Vector2 = input.get("stick", Vector2.ZERO)
	axis = clampf(axis + st.x, -1.0, 1.0)
	var fire: bool = bool(input.get("fire", false))
	var edge := fire and not _fire_prev
	_fire_prev = fire
	if view.state == "title":
		if edge:
			view.start_game()
		return
	if view.state == "over":
		if edge and view.over_t > 1.5:
			view.start_game()
		return
	if edge:
		view.horn()
	_target = clampi(roundi(2.0 + axis * 2.6), 0, 4)


var _target := 2


func tick(delta: float) -> void:
	if view == null:
		return
	if view.state == "play" and active:
		_step_t -= delta
		if _step_t <= 0.0 and _target != view.game.lane:
			view.steer(_target)
			_step_t = 0.11
	if active:
		view.tick(delta)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		_attract_t += delta
		view.t += delta
		if _attract_t > 0.25:
			_attract_t = 0.0
			view.queue_redraw()
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		elif viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func control_names() -> Dictionary:
	return {"stick": "STEER", "fire": "HORN", "alt": ""}
