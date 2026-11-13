extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var menu:=VRMenu.new();var defaults=load("res://scripts/vr_main.gd").new()
	menu.build(world,ThemeDB.fallback_font,defaults.settings);menu.show_page("sports");menu.set_open(true)
	await process_frame
	menu.controller(Vector2.ZERO,false)
	menu.controller(Vector2(0,1),false)
	var focused:=menu.viewport.gui_get_focus_owner()
	assert(focused is Button)
	var hits:=[0]
	focused.pressed.connect(func():hits[0]+=1)
	menu.controller(Vector2.ZERO,true);menu.controller(Vector2.ZERO,true)
	assert(hits[0]==1)
	menu.controller(Vector2.ZERO,false);menu.controller(Vector2.ZERO,true)
	assert(hits[0]==2)
	print("MENU CONTROLLER: focus and debounced A passed")
	defaults.free();world.queue_free();quit()
