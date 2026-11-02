extends SceneTree
## Checks the pointing maths: a ray at a thing lights it, a ray at the floor offers a landing spot, a ray into the air does neither.
func _initialize() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var s := Selector.new()
	s.accessible = func(_p): return true
	var xf := Transform3D(Basis(Vector3.UP, 1.0), Vector3(3, 0, 2))      # a box turned in the room
	s.build(root, [{"id": "a", "label": "PLAY", "xf": xf, "box": AABB(Vector3(-0.4, 0, -0.4), Vector3(0.8, 2, 0.8)), "colour": Color.RED}], ThemeDB.fallback_font)
	var o := Vector3(0, 1.4, 0)
	var at := (xf * Vector3(0, 1.0, 0) - o).normalized()
	assert(s.aim(o, at) == 0)
	assert(s.aim(o, Vector3(0, -0.5, -1).normalized()) == -1 and s.floor_ok)
	assert(s.aim(o, Vector3(0, 0.3, -1).normalized()) == -1 and not s.floor_ok)
	assert(s.aim(o, Vector3(-1, 0.0, 0).normalized()) == -1)
	print("SELECTOR TEST OK")
	quit()
