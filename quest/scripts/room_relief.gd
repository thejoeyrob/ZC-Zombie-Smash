class_name VRSurfaceRelief
extends RefCounted
## Physical brick relief on the existing arcade walls: the texture remains the
## supplied PBR brick material, but the front faces and edges are true geometry.
## One static mesh per wall, no physics, no runtime animation, no new textures.
## Designed for a conservative Quest triangle/draw-call budget.

static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_uv(ud)
	st.add_vertex(d)


static func brick_wall(parent: Node3D, width: float, height: float, source: StandardMaterial3D) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Brick dimensions and mortar recess in metres; discrete face geometry gives
	# readable highlights under changing eye position without parallax shaders.
	var brick_w := 0.60
	var brick_h := 0.225
	var gap := 0.013
	var count_row := ceili(height / brick_h)
	var count_col := ceili(width / brick_w) + 2
	var half := width * 0.5
	for row in range(count_row):
		var y_lo := row * brick_h + gap * 0.5
		var y_hi := minf((row + 1) * brick_h - gap * 0.5, height - gap * 0.5)
		if y_hi - y_lo < 0.035:
			continue
		var offset := brick_w * 0.5 if row % 2 == 1 else 0.0
		for col in range(-1, count_col):
			var x_lo := maxf(-half + gap * 0.5, -half + col * brick_w + offset + gap * 0.5)
			var x_hi := minf(half - gap * 0.5, -half + (col + 1) * brick_w + offset - gap * 0.5)
			if x_hi - x_lo < 0.05:
				continue
			var depth := 0.012 + 0.003 * float((row * 7 + col * 11) % 3)
			var back := 0.001
			var a := Vector3(x_lo, y_lo, depth)
			var b := Vector3(x_hi, y_lo, depth)
			var c := Vector3(x_hi, y_hi, depth)
			var d := Vector3(x_lo, y_hi, depth)
			# UV mapping matches the existing wall's 2.4 m texture repeat.
			var ua := Vector2((x_lo + half) / 2.4, (height - y_lo) / 2.4)
			var ub := Vector2((x_hi + half) / 2.4, (height - y_lo) / 2.4)
			var uc := Vector2((x_hi + half) / 2.4, (height - y_hi) / 2.4)
			var ud := Vector2((x_lo + half) / 2.4, (height - y_hi) / 2.4)
			_face(st, a, b, c, d, ua, ub, uc, ud)
			# Small raised upper and right edges catch highlights at grazing angles.
			var d_back := Vector3(x_lo, y_hi, back)
			var c_back := Vector3(x_hi, y_hi, back)
			_face(st, d, c, c_back, d_back, ud, uc, uc, ud)
			var b_back := Vector3(x_hi, y_lo, back)
			_face(st, b, b_back, c_back, c, ub, ub, uc, uc)
	st.generate_normals()
	st.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.name = "PhysicalBrickRelief"
	instance.mesh = st.commit()
	var mat := source.duplicate() as StandardMaterial3D
	mat.uv1_scale = Vector3.ONE # Vertex UV already uses the wall's physical repeat
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func tile_floor(parent: Node3D, width: float, depth: float, centre_z: float, source: StandardMaterial3D) -> MeshInstance3D:
	# Subtle raised tiles sit on the original floor. The original floor remains the
	# recessed grout underneath, so no original geometry or PBR texture is removed.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tile := 0.4
	var joint := 0.006
	var half_w := width * 0.5
	var half_d := depth * 0.5
	for row in range(ceili(depth / tile)):
		for col in range(ceili(width / tile)):
			var x0 := -half_w + col * tile + joint * 0.5
			var x1 := minf(-half_w + (col + 1) * tile - joint * 0.5, half_w)
			var z0 := centre_z - half_d + row * tile + joint * 0.5
			var z1 := minf(centre_z - half_d + (row + 1) * tile - joint * 0.5, centre_z + half_d)
			if x1 - x0 < 0.03 or z1 - z0 < 0.03:
				continue
			var y := 0.007 + float((row + col) % 3) * 0.0006
			var a := Vector3(x0, y, z0)
			var b := Vector3(x0, y, z1)
			var c := Vector3(x1, y, z1)
			var d := Vector3(x1, y, z0)
			var ua := Vector2((x0 + half_w) / 1.6, (z0 - centre_z + half_d) / 1.6)
			var ub := Vector2((x0 + half_w) / 1.6, (z1 - centre_z + half_d) / 1.6)
			var uc := Vector2((x1 + half_w) / 1.6, (z1 - centre_z + half_d) / 1.6)
			var ud := Vector2((x1 + half_w) / 1.6, (z0 - centre_z + half_d) / 1.6)
			_face(st, a, b, c, d, ua, ub, uc, ud)
			var edge := 0.0005
			_face(st, d, c, Vector3(x1, edge, z1), Vector3(x1, edge, z0), ud, uc, uc, ud)
			_face(st, b, a, Vector3(x0, edge, z0), Vector3(x0, edge, z1), ub, ua, ua, ub)
	st.generate_normals()
	st.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.name = "PhysicalTileRelief"
	instance.mesh = st.commit()
	var mat := source.duplicate() as StandardMaterial3D
	mat.uv1_scale = Vector3.ONE
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
