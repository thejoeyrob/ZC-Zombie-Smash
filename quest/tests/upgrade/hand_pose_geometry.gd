extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	for id in ["human_m01", "human_f02"]:
		var avatar := VRAvatar.new()
		stage.add_child(avatar)
		avatar.build(true)
		avatar.apply_skin(id)
		var head := Transform3D(Basis.IDENTITY, Vector3(0, 1.62, 0))
		var wrists := [Vector3(-0.26, 1.2, -0.3), Vector3(0.26, 1.2, -0.3)]
		avatar.hand_poses = [Transform3D(Basis.IDENTITY, wrists[0]), Transform3D(Basis.IDENTITY, wrists[1])]
		var open: Array = []
		for curl in [0.0, 0.9]:
			avatar.finger_curls.fill(curl)
			avatar.update(head, wrists, [true, true], 1.0 / 90)
			for side in range(2):
				var dist := avatar.human.fingertip(side).distance_to(wrists[side])
				if curl == 0.0:
					open.append(dist)
				else:
					print("%s side %d: open %.1fmm / grip %.1fmm" % [id, side, open[side]*1000, dist*1000])
					if dist >= float(open[side]) - 0.02:
						push_error("Index finger did not close toward the palm")
						failures += 1
			await process_frame
		avatar.free()
	print("HAND GEOMETRY PASS" if failures == 0 else "HAND GEOMETRY FAILED")
	quit(1 if failures else 0)
