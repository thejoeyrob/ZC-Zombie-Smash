extends SceneTree
## Two pinball machines must play independently: working one must not move the other.
func _initialize() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var a := Pinball.new()
	var b := Pinball.new()
	a.position = Vector3(-2.35, 0, 0)
	b.position = Vector3(2.35, 0, 0)
	root.add_child(a)
	root.add_child(b)
	a.build(ThemeDB.fallback_font)
	b.build(ThemeDB.fallback_font)
	a.set_enabled(true)
	b.set_enabled(true)
	await process_frame
	var tip_a: Vector3 = (a._flip_buttons[0] as Node3D).global_position
	a.interact([tip_a], [tip_a], false, false, false, true)
	b.interact([], [], false, false, false, false)
	var ok := a.table.left_up and not b.table.left_up
	print("A left flipper up: ", a.table.left_up, "   B left flipper up: ", b.table.left_up)
	# launch A only
	a.table.reset_game()
	a.table.pull(0.9)
	a.table.launch()
	for i in range(20):
		await process_frame
	ok = ok and a.table.in_play and not b.table.in_play
	print("A ball in play: ", a.table.in_play, "   B ball in play: ", b.table.in_play)
	print("INDEPENDENT TEST OK" if ok else "INDEPENDENT TEST FAILED")
	quit()
