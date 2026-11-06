extends SceneTree
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var menu := VRMenu.new()
	var main_script = load("res://scripts/vr_main.gd")
	var defaults = main_script.new()
	menu.build(scene, ThemeDB.fallback_font, defaults.settings)
	defaults.free()
	menu.set_open(true)
	menu.point(Vector3(0, 0, 1), Vector3(0, 0, -1), true)
	assert(menu._pressed)
	menu.point(Vector3(0, 0, 1), Vector3.RIGHT, true)
	assert(not menu._pressed)
	menu.point(Vector3(0, 0, 1), Vector3(0, 0, -1), true)
	menu.set_open(false)
	assert(not menu._pressed)
	print("MENU RELEASE PASS")
	quit(0)
