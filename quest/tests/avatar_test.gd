extends SceneTree
## The avatar must never produce NaNs, its hands must reach the controllers, its feet must stay near its body, and every skin must build.
func _initialize() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var av := VRAvatar.new()
	root.add_child(av)
	av.build(true)
	var bad := 0
	for sk in VRAvatar.SKINS:
		av.apply_skin(sk.id)
		if av.skin_id != sk.id:
			print("SKIN not applied: ", sk.id)
			bad += 1
		for mode in ["full", "arms", "hands"]:
			av.set_body_mode(mode)
	av.set_body_mode("full")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pos := Vector3(0, 1.62, 0)
	var yaw := 0.0
	var worst_reach := 0.0
	var worst_foot := 0.0
	for f in range(900):
		var dt := 1.0 / 72.0
		# walk, turn, bow, crouch and wave about
		var t := f * dt
		yaw += sin(t * 0.4) * 0.03
		var speed := 1.2 if int(t / 3.0) % 2 == 0 else 0.0
		pos += Basis(Vector3.UP, yaw) * Vector3(0, 0, -speed * dt)
		pos.y = 1.62 - (0.5 if int(t / 5.0) % 3 == 2 else 0.0) * smoothstep(0.0, 1.0, fmod(t, 5.0))
		var pitch := sin(t * 0.5) * 0.5
		var head := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch), pos)
		var lw: Vector3 = pos + Basis(Vector3.UP, yaw) * Vector3(-0.3, -0.5 + sin(t * 2.0) * 0.3, -0.35 + sin(t * 1.3) * 0.2)
		var rw: Vector3 = pos + Basis(Vector3.UP, yaw) * Vector3(0.3, -0.4 + cos(t * 1.7) * 0.4, -0.4 + cos(t * 1.1) * 0.3)
		av.update(head, [lw, rw], [true, true], dt, int(t / 7.0) % 4 == 3)
		if is_nan(av.body_yaw) or is_nan(av.feet[0].x) or is_nan(av.wrists[0].x):
			print("NaN at frame ", f)
			bad += 1
			break
		for s in range(2):
			var want: Vector3 = lw if s == 0 else rw
			var shoulder_dist: float = (want - (av.wrists[s] as Vector3)).length()
			if f > 5:
				worst_reach = maxf(worst_reach, shoulder_dist)
			var foot_d: float = Vector2(av.feet[s].x - pos.x, av.feet[s].z - pos.z).length()
			worst_foot = maxf(worst_foot, foot_d)
	print("worst wrist error %.3f m, worst foot distance from the head %.2f m" % [worst_reach, worst_foot])
	if worst_reach > 0.12:
		print("hands drift from the controllers")
		bad += 1
	if worst_foot > 1.0:
		print("feet left behind")
		bad += 1
	print("AVATAR TEST OK" if bad == 0 else "AVATAR TEST FAILED (%d)" % bad)
	quit()
