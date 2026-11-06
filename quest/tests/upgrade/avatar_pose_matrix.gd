extends SceneTree
var failures := 0
var max_wrist_error := 0.0
var max_eye_error := 0.0
var cases := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	# Build below a translated, rotated parent to catch world/local normalization mistakes.
	scene.position = Vector3(3, 0.5, -2)
	scene.rotation.y = 0.7
	for id in ["human_m01", "human_f02"]:
		var avatar := VRAvatar.new()
		scene.add_child(avatar)
		avatar.build(true)
		avatar.apply_skin(id)
		check(avatar.human != null, "Missing rig: " + id)
		if avatar.human == null:
			continue
		var rig := avatar.human
		check(absf(rig.rest_eye.y - 1.62) < 0.001, "Avatar size depends on parent position")
		for scale_value in [0.8, 1.0, 1.3]:
			avatar.scale_k = scale_value
			for mode in ["hands", "arms", "full"]:
				avatar.set_body_mode(mode)
				for sample in range(12):
					avatar._inited = false
					var yaw := float(sample) * TAU / 12
					var b := Basis(Vector3.UP, yaw)
					var head := Transform3D(b * Basis(Vector3.RIGHT, sin(sample) * 0.45), Vector3(1, 1.62 * scale_value, -1))
					var left := Transform3D(b, head.origin + b * Vector3(-0.26, -0.4, -0.3) * scale_value)
					var right := Transform3D(b, head.origin + b * Vector3(0.26, -0.4, -0.3) * scale_value)
					avatar.hand_poses = [left, right]
					avatar.finger_curls.fill(0.0 if sample % 2 == 0 else 0.85)
					avatar.update(head, [left.origin, right.origin], [true, true], 1.0 / 90, false)
					for side in range(2):
						var wrist := rig.bone(("L " if side == 0 else "R ") + "Hand")
						var actual := rig.skeleton.to_global(rig.skeleton.get_bone_global_pose(wrist).origin)
						var wanted: Vector3 = left.origin if side == 0 else right.origin
						var error := actual.distance_to(wanted)
						max_wrist_error = maxf(max_wrist_error, error)
						check(actual.is_finite() and error < 0.025, "Wrist alignment exceeded 25mm: " + id)
						check(rig.fingertip(side).is_finite(), "Nonfinite fingertip")
					var eye := (rig.skeleton.to_global(rig.skeleton.get_bone_global_pose(rig.bone("LEye")).origin) + rig.skeleton.to_global(rig.skeleton.get_bone_global_pose(rig.bone("REye")).origin)) * 0.5
					max_eye_error = maxf(max_eye_error, eye.distance_to(head.origin))
					check(eye.distance_to(head.origin) < 0.005, "Eyes drift from headset while turning")
					cases += 1
					await process_frame
		avatar.update(Transform3D(Basis.IDENTITY, Vector3(0, 1.62, 0)), [Vector3.ZERO, Vector3.ZERO], [false, true], 1.0 / 90)
		for mesh in rig.body_parts.left_hands:
			check(not mesh.visible, "Lost left tracking still displays a hand")
		for mesh in rig.body_parts.right_hands:
			check(mesh.visible, "Tracking loss hides the other hand")
		avatar.free()
	print("POSE MATRIX: %d cases; max wrist %.3f mm; max eye %.3f mm" % [cases, max_wrist_error * 1000, max_eye_error * 1000])
	print("AVATAR POSE PASS" if failures == 0 else "AVATAR POSE FAILED")
	quit(1 if failures else 0)
