extends SceneTree
var menu: VRMenu
var tick := 0
var pages := ["play", "sports", "comfort", "display"]
var index := 0
var output := "/tmp/fattys-menu"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		output = args[0]
	root.size = Vector2i(1440, 1080)
	var world := Node3D.new()
	root.add_child(world)
	var main = load("res://scripts/vr_main.gd").new()
	menu = VRMenu.new()
	menu.build(world, load("res://assets/fonts/font-barlow-condensed-700.woff2"), main.settings)
	main.free()
	menu.set_open(true)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position.z = 1
	camera.current = true

func _process(_dt: float) -> bool:
	tick += 1
	if tick % 16 == 0:
		menu.viewport.get_texture().get_image().save_png(output + "_" + pages[index] + ".png")
		index += 1
		if index == pages.size():
			quit()
		else:
			menu.show_page(pages[index])
	return false
