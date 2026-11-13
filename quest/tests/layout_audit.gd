extends SceneTree
## Builds the room and checks the physical layout: nothing pokes through a wall or the skirting, machines and tables do not overlap,
## and every play spot can actually be stood on. Prints each problem; ends with LAYOUT AUDIT OK or LAYOUT AUDIT FAILED.

const SKIRT := 0.07           # skirting and its top moulding stand this far out from the wall


func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or not mi.visible or mi.get_viewport() is SubViewport:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Footprint: the four bottom corners of a node's own-space box, turned into the room.
func _footprint(n: Node3D) -> PackedVector2Array:
	var inv := n.global_transform.affine_inverse()
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or not mi.visible or mi.get_viewport() is SubViewport:
			continue
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		lo = lo.min(b.position)
		hi = hi.max(b.end)
	var pts := PackedVector2Array()
	for p in [Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z), Vector3(hi.x, 0, hi.z), Vector3(lo.x, 0, hi.z)]:
		var w: Vector3 = n.global_transform * p
		pts.append(Vector2(w.x, w.z))
	return pts


func _initialize() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	ZSEngine.setup()
	var room := ArcadeRoom.new()
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	room.build(root, ImageTexture.create_from_image(img), ImageTexture.create_from_image(img), ThemeDB.fallback_font, VRProgress.new())
	await process_frame
	var bad := 0
	var things := []
	for i in range(room.machines.size()):
		things.append(["machine %d (%s)" % [i, room.machines[i].bezel_id], room.machines[i]])
	things.append(["pinball 1", room.pinball])
	things.append(["pinball 2", room.pinball2])
	things.append(["jukebox", room.jukebox])
	things.append(["vending", room.vending])
	things.append(["skins", room.skins])
	var hw := ArcadeRoom.HALF_W - SKIRT
	var back := ArcadeRoom.BACK_Z - SKIRT
	var front := ArcadeRoom.FRONT_Z + 0.06 + SKIRT + 0.02    # the door wall is 0.12 thick, its skirting stands out in front
	var feet := {}
	for t in things:
		var fp := _footprint(t[1])
		if fp.size() == 0 or is_inf(fp[0].x) or is_nan(fp[0].x):
			continue                                          # (a machine that is no longer built has nothing to measure)
		feet[t[0]] = fp
		for p in fp:
			if absf(p.x) > hw + 0.001 or p.y > back + 0.001 or p.y < front - 0.001:
				print("WALL  %s corner %s is in the wall or skirting (limit x=±%.2f, z=%.2f..%.2f)" % [t[0], p, hw, front, back])
				bad += 1
				break
	var names := feet.keys()
	for a in range(names.size()):
		for b in range(a + 1, names.size()):
			if Geometry2D.intersect_polygons(feet[names[a]], feet[names[b]]).size() > 0:
				print("OVERLAP  %s and %s" % [names[a], names[b]])
				bad += 1
	# every place you can be sent to must be free floor
	for s in room.spots:
		var p: Vector3 = s[2]
		var q: Vector3 = room.collide(p)
		if q.distance_to(Vector3(p.x, 0, p.z)) > 0.06:
			print("SPOT  %s at %s is pushed to %s by a blocker" % [s[0], p, q])
			bad += 1
	for t in things:
		var bx := _bounds(t[1])
		if bx.size == Vector3.ZERO:
			continue
		print("  %-22s x %.2f..%.2f  z %.2f..%.2f  top %.2f" % [t[0], bx.position.x, bx.end.x, bx.position.z, bx.end.z, bx.end.y])
	print("LAYOUT AUDIT OK" if bad == 0 else "LAYOUT AUDIT FAILED (%d)" % bad)
	quit()
