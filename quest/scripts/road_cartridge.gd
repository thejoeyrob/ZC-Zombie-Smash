class_name RoadCartridge
extends Cartridge
## A driving game as a machine's cartridge: ROAD RUSH (race the clock) or BIG RIG (haul cargo). The picture is a SubViewport drawn by RoadView.
## Input: axis (the wheel, -1..1), fire (gas), alt (brake). It draws every frame while somebody plays and a few times a second as the attract screen.

var view: RoadView
var viewport: SubViewport
var mode := "racer"
var active := false
var _attract_t := 0.0


func _init(m := "racer") -> void:
	mode = m
	id = "road_rush" if m == "racer" else "big_rig"
	title = "ROAD RUSH" if m == "racer" else "BIG RIG"
	tint = Color("#ff5f99") if m == "racer" else Color("#ffbf40")


func build(host: Node) -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 822)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.transparent_bg = false
	host.add_child(viewport)
	view = RoadView.new()
	viewport.add_child(view)
	view.setup(mode, load("res://assets/fonts/DejaVuSansMono-Bold.ttf"))
	view.sound.connect(func(n): sound.emit(n, {}))
	view.haptic.connect(func(a, d): haptic.emit(a, d))


func screen_texture() -> Texture2D:
	return viewport.get_texture() if viewport != null else null


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	if on and view.state == "title":
		view.reset_game(true)


var _fire_prev := false


func set_input(input: Dictionary) -> void:
	var axis: float = float(input.get("axis", 0.0))
	var st: Vector2 = input.get("stick", Vector2.ZERO)
	var gas: bool = bool(input.get("fire", false)) or st.y < -0.45
	var brake: bool = bool(input.get("alt", false)) or st.y > 0.45
	var edge := gas and not _fire_prev
	_fire_prev = gas
	view.set_input(axis, gas, brake, edge)
	if view.state == "title" and not active:
		pass


func tick(delta: float) -> void:
	if view == null:
		return
	if active:
		view.tick(delta)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		_attract_t += delta
		view.tick(delta)
		if _attract_t > 0.2:
			_attract_t = 0.0
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		elif viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
