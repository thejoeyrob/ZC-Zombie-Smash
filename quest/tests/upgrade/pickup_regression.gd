extends SceneTree
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
	sports.choose("g_d0_go")
	sports.choose("g_a0_go")
	sports.choose("g_b0_go")
	var off := {"active": false, "gripping": false, "trigger": false}
	for item in [sports.darts.darts[0], sports.axes.axes[0], sports.bowling.balls[0]]:
		var h := {"active": true, "gripping": true, "trigger": false, "palm": Vector3(0, 1, 12), "vis_xf": Transform3D(Basis.IDENTITY, Vector3(0, 1, 12))}
		sports.update([h, off], 0.014, Vector3(0, 0, 10), true)
		h.palm = item.world_pos()
		h.vis_xf.origin = h.palm
		sports.update([h, off], 0.014, Vector3(0, 0, 10), true)
		check(sports.held[0] == item, "Pre-squeezed hand acquires " + item.kind)
		sports.update([h, off], 0.014, Vector3(0, 0, 10), false)
		check(sports.held[0] == null and item.state == "rest", "Menu cancellation returns " + item.kind)
	world.free()
	print("PICKUP: 6 checks; %d failures" % failed)
	quit(failed)
