class_name FlatView
extends Node
## Browser and desktop mode (no headset): walk with W A S D, drag the mouse to look, click a glowing thing to choose it.
## At a machine: A / D or the arrow keys move, SPACE fires, G throws a grenade, ESC steps back. It feeds the same game as the headset does.

var main: Node
var cam: Camera3D
var origin: Node3D
var yaw := 0.0
var pitch := -0.05
var axis := 0.0
var fire := false
var alt := false
var pause := false
var _drag := false
var _moved := 0.0
var _press_pos := Vector2.ZERO
var _click := false
var _hud: Label
var _pause_prev := false


func setup(m: Node, c: Camera3D, o: Node3D, font: Font) -> void:
	main = m
	cam = c
	origin = o
	var f := -cam.global_transform.basis.z
	yaw = atan2(-f.x, -f.z)
	pitch = asin(clampf(f.y, -1.0, 1.0))
	cam.fov = 75.0
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 20)
	_hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hud.add_theme_constant_override("outline_size", 6)
	if font != null:
		_hud.add_theme_font_override("font", font)
	_hud.position = Vector2(18, 14)
	layer.add_child(_hud)
	_apply()


func place(pos: Vector3, look: Vector3) -> void:
	var p := Vector3(pos.x, 1.6, pos.z)
	origin.position = Vector3.ZERO
	cam.position = p
	var d := look - p
	yaw = atan2(-d.x, -d.z)
	pitch = asin(clampf(d.normalized().y, -1.0, 1.0))
	_apply()


func _apply() -> void:
	cam.rotation = Vector3(pitch, yaw, 0.0)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_drag = true
			_moved = 0.0
			_press_pos = e.position
			if main.locked:
				fire = true
		else:
			_drag = false
			fire = false
			if _moved < 6.0 and not main.locked:
				_click = true
	elif e is InputEventMouseMotion and _drag and not main.locked:
		_moved += e.relative.length()
		yaw -= e.relative.x * 0.004
		pitch = clampf(pitch - e.relative.y * 0.004, -1.3, 1.3)
		_apply()


func _process(delta: float) -> void:
	var locked: bool = main.locked
	var kx := Input.get_axis("ui_left", "ui_right")
	var kz := Input.get_axis("ui_down", "ui_up")
	if Input.is_key_pressed(KEY_A):
		kx -= 1.0
	if Input.is_key_pressed(KEY_D):
		kx += 1.0
	if Input.is_key_pressed(KEY_W):
		kz += 1.0
	if Input.is_key_pressed(KEY_S):
		kz -= 1.0
	kx = clampf(kx, -1.0, 1.0)
	kz = clampf(kz, -1.0, 1.0)
	axis = kx if locked else 0.0
	fire = fire or (locked and Input.is_key_pressed(KEY_SPACE))
	if locked and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_key_pressed(KEY_SPACE):
		fire = false
	alt = locked and Input.is_key_pressed(KEY_G)
	pause = locked and (Input.is_key_pressed(KEY_P))
	if not locked:
		if (kx != 0.0 or kz != 0.0) and not main.menu.open:
			var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
			var right := Vector3(cos(yaw), 0, -sin(yaw))
			var step := (fwd * kz + right * kx) * float(main.settings.walk) * 1.4 * delta
			var np: Vector3 = main.room.collide(Vector3(cam.position.x, 0, cam.position.z) + step)
			cam.position = Vector3(np.x, 1.6, np.z)
		# what the mouse points at
		var mp := get_viewport().get_mouse_position()
		var o := cam.project_ray_origin(mp)
		var d := cam.project_ray_normal(mp)
		var hover: int = main.selector.aim(o, d) if not _drag else main.selector.aim(Vector3.ZERO, Vector3.UP)
		if _click:
			_click = false
			if hover >= 0:
				main._choose(str(main.selector.targets[hover].id))
			elif main.selector.floor_ok:
				var p: Vector3 = main.selector.floor_pos
				cam.position = Vector3(p.x, 1.6, p.z)
		_hud.text = "WASD walk   DRAG look   CLICK a glowing thing to choose it or the floor to move"
	else:
		_click = false
		_hud.text = "A / D move    SPACE or CLICK fire    G grenade    ESC leave the machine"
		if Input.is_key_pressed(KEY_ESCAPE) and not _pause_prev:
			main._set_locked(false)
	_pause_prev = Input.is_key_pressed(KEY_ESCAPE)
