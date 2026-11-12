extends SceneTree
## You can walk from the arcade through the gate into the sports hall, but not through the rest of the back wall.
func _initialize() -> void:
	ZSEngine.setup()
	var world := Node3D.new()
	root.add_child(world)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var room := ArcadeRoom.new()
	room.build(world, ImageTexture.create_from_image(img), ImageTexture.create_from_image(img), ThemeDB.fallback_font, VRProgress.new())
	var fails := 0
	var gx := ShackAnnex.GATE_X
	var cases := [
		[Vector3(gx, 0, 6.5), Vector3(gx, 0, 6.5), "open floor inside the arcade"],
		[Vector3(gx, 0, ArcadeRoom.BACK_Z), Vector3(gx, 0, ArcadeRoom.BACK_Z), "standing in the gateway"],
		[Vector3(gx, 0, 9.0), Vector3(gx, 0, 9.0), "inside the hall"],
		[Vector3(0.0, 0, ArcadeRoom.BACK_Z - 0.2), Vector3(0.0, 0, ArcadeRoom.BACK_Z - 0.4), "pushed back off the wall away from the gate"],
		[Vector3(gx + 1.2, 0, ArcadeRoom.BACK_Z + 0.1), Vector3(gx + 1.2, 0, ArcadeRoom.BACK_Z + 0.35), "the hall side of the wall beside the gate"],
	]
	for c in cases:
		var out: Vector3 = room.collide(c[0])
		if out.distance_to(c[1]) > 0.02:
			print("FAIL: ", c[2], " -> ", out, " wanted ", c[1])
			fails += 1
	# a walk through: step along z at the gate and you arrive in the hall
	var p := Vector3(gx, 0, 5.0)
	for i in range(120):
		p = room.collide(p + Vector3(0, 0, 0.05))
	if p.z < ArcadeRoom.BACK_Z + 1.0:
		print("FAIL: could not walk through the gate (z=", p.z, ")")
		fails += 1
	print("GATE TEST ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails > 0 else 0)
