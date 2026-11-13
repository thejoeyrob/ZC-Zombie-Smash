extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in range(4):await process_frame
	var found:=-1
	for i in range(main.machines.size()):
		if main.machines[i].fkbc_session!=null: found=i
	assert(found>=0)
	main._select_machine(found);main._set_locked(true)
	assert(main.cab.fkbc_session!=null)
	main.cab.fkbc_session.set_input(Vector2.ZERO,{"a":true})
	for i in range(5):await process_frame
	assert(main.cab.fkbc_session.view.state=="play")
	assert(main.emu.hold)
	main._set_locked(false)
	var before: float=main.cab.fkbc_session.view.game.time_left
	for i in range(5):await process_frame
	assert(main.cab.fkbc_session.view.game.time_left==before)
	print("INTEGRATION: FKBC cabinet entry, independent emulator, leave suspension passed")
	main.queue_free();await process_frame;await process_frame;quit()
