class_name SportsFinish
extends RefCounted
## Low-cost finish geometry. All stationary pieces are merged by the annex.
static func panel(parent: Node3D, at: Vector3, yaw: float, size: Vector2) -> void:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = at
	n.rotation.y = yaw
	VRBuild.box(n, Vector3(size.x + 0.035, size.y + 0.035, 0.025), Vector3(0, 0, -0.035), VRBuild.mat(Color(0.2, 0.25, 0.28), 0.4, 0.7))
	VRBuild.box(n, Vector3(size.x, size.y, 0.012), Vector3(0, 0, -0.017), VRBuild.mat(Color(0.012, 0.025, 0.03), 0.8))
	VRBuild.box(n, Vector3(size.x, 0.008, 0.008), Vector3(0, size.y / 2.0, -0.01), VRBuild.mat(Color(0.25, 0.8, 0.7), 0.5))
	VRBuild.merge_static(n)

static func floor_piece(parent: Node3D, x0: float, x1: float, z0: float, z1: float, base: StandardMaterial3D) -> void:
	if x1 <= x0:
		return
	var m: StandardMaterial3D = base.duplicate()
	m.uv1_scale = Vector3((x1 - x0) / 1.6, (z1 - z0) / 1.6, 1)
	VRBuild.quad(parent, Vector2(x1 - x0, z1 - z0), Vector3((x0 + x1) / 2, 0, (z0 + z1) / 2), m, Vector3(-PI / 2, 0, 0))

static func board(parent: Node3D, at: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [0.0, DartsGame.R_DBULL, DartsGame.R_BULL, DartsGame.R_TRE_IN, DartsGame.R_TRE_OUT, DartsGame.R_DBL_IN, DartsGame.R_DBL_OUT]
	for ring in range(radii.size() - 1):
		for k in range(160):
			var sector := k / 8
			var red := Color(0.6, 0.055, 0.04)
			var green := Color(0.035, 0.28, 0.15)
			var col: Color = (Color(0.035, 0.03, 0.025) if sector % 2 == 0 else Color(0.78, 0.7, 0.51))
			if ring in [0, 1, 3, 5]:
				col = red if (ring == 0 or (ring > 1 and sector % 2 == 0)) else green
			var a := TAU * float(k) / 160.0 - PI / 20.0
			var b := TAU * float(k + 1) / 160.0 - PI / 20.0
			var pts: Array[Vector3] = []
			for v in [[radii[ring], a], [radii[ring + 1], a], [radii[ring + 1], b], [radii[ring], b]]:
				pts.append(Vector3(sin(v[1]) * v[0], cos(v[1]) * v[0], 0))
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3(0, 0, 1))
				st.set_color(col)
				st.add_vertex(pts[idx])
	var m := VRBuild.mat(Color.WHITE, 0.92)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = m
	parent.add_child(mesh)
	mesh.position = at
	mesh.rotation.y = PI / 2
