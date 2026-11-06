extends SceneTree
var failed := 0
func _initialize() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	await process_frame
	for id in ["human_m01", "human_f02"]:
		var avatar := VRAvatar.new()
		scene.add_child(avatar)
		avatar.build(true)
		avatar.apply_skin(id)
		if avatar.human == null:
			push_error("Imported human unavailable: " + id)
			failed += 1
			continue
		for mode in ["hands", "arms", "full"]:
			avatar.set_body_mode(mode)
			for i in range(180):
				var head := Transform3D(Basis.IDENTITY, Vector3(0, 1.62, 0))
				var left := Transform3D(Basis.IDENTITY, Vector3(-0.25, 1.1, -0.3))
				var right := Transform3D(Basis.IDENTITY, Vector3(0.25, 1.1, -0.3))
				avatar.hand_poses = [left, right]
				avatar.update(head, [left.origin, right.origin], [true, true], 1.0 / 90, false)
				for side in range(2):
					var rig: HumanRig = avatar.human
					var bone := rig.bone(("L " if side == 0 else "R ") + "Hand")
					var actual := rig.skeleton.to_global(rig.skeleton.get_bone_global_pose(bone).origin)
					var wanted: Vector3 = left.origin if side == 0 else right.origin
					if not actual.is_finite() or actual.distance_to(wanted) > 0.06:
						push_error("Wrist retarget error in " + id)
						failed += 1
						break
		avatar.queue_free()
	print("HUMAN RIG PASS" if failed == 0 else "HUMAN RIG FAILED — do not release")
	quit(mini(failed, 1))
