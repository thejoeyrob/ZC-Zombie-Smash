extends SceneTree
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var menu := VRMenu.new()
	var defaults = load("res://scripts/vr_main.gd").new()
	menu.build(world, ThemeDB.fallback_font, defaults.settings)
	defaults.free()
	menu.set_open(true)
	menu.point(Vector3(0, 0, 1), Vector3.FORWARD, true)
	check(not menu._pressed, "Opening with a held trigger must not click")
	menu.point(Vector3(0, 0, 1), Vector3.FORWARD, false)
	menu.point(Vector3(0, 0, 1), Vector3.FORWARD, true)
	check(menu._pressed, "Fresh trigger press is accepted")
	menu.point(Vector3(0, 0, 1), Vector3.RIGHT, true)
	check(not menu._pressed, "Leaving panel cancels pointer capture")
	menu.point(Vector3(0, 0, 1), Vector3.FORWARD, true)
	check(not menu._pressed, "Held trigger cannot activate a second button on re-entry")
	menu.show_page("sports")
	for _i in range(5):
		await process_frame
	check(menu._scrolls.sports.visible and not menu._scrolls.play.visible, "Only selected page is visible")
	var sc: ScrollContainer = menu._scrolls.sports
	check(sc.size.y < menu.VIEW.y, "Sport page stays inside the fixed menu")
	check(menu._pages.sports.size.y > sc.size.y, "Long sports page has scrollable content")
	menu.scroll_page(10000)
	await process_frame
	check(sc.scroll_vertical > 0, "Lower sports controls remain reachable")
	menu.set_value("lift", 0.12)
	check(menu._value_labels.lift.text == "+12 cm", "Height has a readable unit")
	menu.present(Vector3(0, 1.6, 0), Vector3.UP)
	check(menu.global_transform.basis.is_finite(), "Looking vertically still presents a valid menu")
	menu.ask("quit", "Exit?")
	check(menu._confirm_layer.visible, "Destructive actions show confirmation")
	menu.set_open(false)
	check(not menu._pressed and not menu._confirm_layer.visible, "Close clears pointer and confirmation")
	print("MENU SPORTS: %d failures" % failures)
	world.free()
	quit(1 if failures else 0)
