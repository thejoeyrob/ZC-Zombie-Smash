extends SceneTree
## Taking a dart, an axe or a ball from a station nobody has started starts a match there, so nothing has to be started first.
var failed := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var sports := ThrowGames.new()
	sports.build(world, null)
	var off := {"active": false, "gripping": false, "trigger": false}
	var items: Array = [sports.darts.darts[0], sports.axes.axes[0], sports.bowling.balls[0]]
	check(sports.darts.boards[0].state == "idle" and sports.axes.lanes[0].state == "idle" and sports.bowling.lanes[0].state == "idle", "stations start idle")
	for item in items:
		var h := {"active": true, "gripping": false, "trigger": true, "palm": item.world_pos(), "vis_xf": Transform3D(Basis.IDENTITY, item.world_pos())}
		sports.update([h, off], 0.014, Vector3(0, 0, 10), true)
		check(sports.held[0] == item, "taking the " + item.kind + " from an unstarted station works")
		sports.update([{"active": true, "gripping": false, "trigger": false, "palm": item.world_pos(), "vis_xf": Transform3D(Basis.IDENTITY, item.world_pos())}, off], 0.014, Vector3(0, 0, 10), true)
		sports._cancel(0)
	check(sports.darts.boards[0].state == "play" and sports.axes.lanes[0].state == "play" and sports.bowling.lanes[0].state == "play", "all three matches started by taking an item")
	world.free()
	print("AUTOSTART: %d failures" % failed)
	quit(failed)
