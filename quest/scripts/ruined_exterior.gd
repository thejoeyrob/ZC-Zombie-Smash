class_name RuinedExterior
extends RefCounted
## Depth-built, non-traversable street set. Texture atlases supply surface detail;
## silhouettes, vehicle bodies, window recesses and rubble are actual geometry.

static func surface(atlas: String, cell: int, tint := Color.WHITE, metal := 0.0) -> StandardMaterial3D:
	var m := VRBuild.tex_mat(load("res://assets/art/ruin-" + atlas + ".png"), 0.0, 0.86, false, tint)
	m.uv1_scale = Vector3(0.496, 0.496, 1)
	m.uv1_offset = Vector3((cell % 2) * 0.5 + 0.002, (cell / 2) * 0.5 + 0.002, 0)
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func panel(parent: Node, points: Array, material: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).abs()
	var uvs: Array[Vector2] = []
	for p: Vector3 in points:
		if normal.y >= normal.x and normal.y >= normal.z:
			uvs.append(Vector2(p.x,p.z))
		elif normal.x >= normal.z:
			uvs.append(Vector2(p.z,p.y))
		else:
			uvs.append(Vector2(p.x,p.y))
	var lo := uvs[0]
	var hi := uvs[0]
	for uv in uvs:
		lo = lo.min(uv)
		hi = hi.max(uv)
	var span := (hi-lo).max(Vector2(0.001,0.001))
	for i in range(1, points.size() - 1):
		for k in [0, i + 1, i]:
			st.set_uv((uvs[k]-lo)/span)
			st.add_vertex(points[k])
	st.generate_normals()
	# Static batching combines indexed primitive meshes; index this mesh too.
	st.index()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	parent.add_child(mi)
	return mi

static func rod(parent: Node, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var mi := VRBuild.cylinder(parent, radius, a.distance_to(b), (a + b) * 0.5, material, -1.0, Vector3.ZERO, 12)
	var direction := (b - a).normalized()
	var ref := Vector3.RIGHT if absf(direction.x) < 0.9 else Vector3.UP
	var x := direction.cross(ref).normalized()
	mi.basis = Basis(x, direction, x.cross(direction).normalized())

static func build(parent: Node3D) -> void:
	var set_root := Node3D.new()
	set_root.name = "RuinedStreetSet"
	parent.add_child(set_root)
	var asphalt := surface("materials", 0, Color(0.45, 0.49, 0.56))
	var concrete := surface("materials", 1, Color(0.6, 0.64, 0.68))
	var rust := surface("materials", 2, Color(0.38, 0.3, 0.25), 0.45)
	var brick := surface("facades", 2, Color(0.48, 0.49, 0.53))
	# Separate pavement modules avoid stretching detail across the entire scene.
	for x in range(-4, 5):
		for z in range(0, 8):
			VRBuild.quad(set_root, Vector2(4, 4), Vector3(x * 4, -0.14, -4.4 - z * 4), asphalt, Vector3(-PI / 2, 0, 0))
		VRBuild.quad(set_root, Vector2(4, 2.4), Vector3(x * 4, 0, -1.2), concrete, Vector3(-PI / 2, 0, 0))
		VRBuild.box(set_root, Vector3(3.96, 0.16, 0.22), Vector3(x * 4, -0.06, -2.4), concrete)
	# Opposite buildings: broken rooflines, thick masonry and recessed window bays.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1126
	for i in range(7):
		var x := -18.0 + i * 6.0
		var z := -21.0 - rng.randf_range(0, 4)
		var h := rng.randf_range(5.5, 10.0)
		var b := Node3D.new()
		b.position = Vector3(x, -0.14, z)
		set_root.add_child(b)
		VRBuild.box(b, Vector3(5.8, h - 1, 4.0), Vector3(0, (h - 1) / 2, -2), brick)
		panel(b, [Vector3(-2.9,h-1,0.01),Vector3(2.9,h-1,0.01),Vector3(2.9,h+0.2,0.01),Vector3(1.8,h-0.3,0.01),Vector3(1.4,h+0.6,0.01),Vector3(0.2,h-0.65,0.01),Vector3(-0.9,h+0.3,0.01),Vector3(-2.9,h+0.1,0.01)], brick)
		for row in range(int((h - 1.5) / 2.3)):
			for col in [-1, 1]:
				var y := 1.5 + row * 2.3
				var p := Vector3(col * 1.45, y, 0.035)
				VRBuild.quad(b, Vector2(1.9, 2.0), p, surface("facades", 0 if (i + row) % 2 == 0 else 3, Color(0.65, 0.7, 0.75)))
				VRBuild.box(b, Vector3(2.04, 0.12, 0.32), p + Vector3(0,-1.0,0.1), concrete)
				for side in [-1, 1]:
					VRBuild.box(b, Vector3(0.09, 2.1, 0.17), p + Vector3(side*0.98,0,0.05), concrete)
		for n in range(3):
			rod(b, Vector3(-2+n*1.4,h-0.8,0), Vector3(-1.8+n*1.4,h+0.6,0.1), 0.025, rust)
		VRBuild.merge_static(b)
	# Skewed, abandoned vehicles with profiled bodywork and broken glazing.
	for spec in [[Vector3(-3.2,0,-6.8),0.38,Color(0.38,0.43,0.42)], [Vector3(3.1,0,-10.6),-0.65,Color(0.32,0.18,0.13)], [Vector3(-6.9,0,-13),1.22,Color(0.21,0.25,0.33)], [Vector3(7,0,-16),-0.3,Color(0.28,0.28,0.25)]]:
		car(set_root, spec[0], spec[1], spec[2])
	# Jersey barricade, bent fence, irregular rubble: all carry real depth.
	for x in [-5.5, -3.7, 4.5]:
		var barrier := VRBuild.side_panel(set_root, PackedVector2Array([Vector2(-0.35,0),Vector2(0.35,0),Vector2(0.27,0.3),Vector2(0.12,0.85),Vector2(-0.12,0.85),Vector2(-0.27,0.3)]),0,1.65,concrete)
		barrier.position = Vector3(x,-0.14,-15)
		barrier.rotation.y = 0.18*x
	for i in range(65):
		var p := Vector3(rng.randf_range(-13,13),-0.11,rng.randf_range(-23,-3))
		var size := rng.randf_range(0.08,0.32)
		var rock := VRBuild.sphere(set_root,size,p,concrete,6)
		rock.scale = Vector3(1.6,0.5,0.8)
		rock.rotation = Vector3(rng.randf(),rng.randf()*PI,rng.randf())
	for i in range(6):
		var x := 9.5 + i * 0.5
		rod(set_root,Vector3(x,0,-9),Vector3(x-0.35,1.8,-9.3),0.018,rust)
	for y in [0.4,0.9,1.4]:
		rod(set_root,Vector3(9.4,y,-9.15),Vector3(12,y,-9.3),0.018,rust)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2,5,-8)
	fill.light_color = Color(0.34,0.44,0.7)
	fill.light_energy = 0.55
	fill.omni_range = 25
	fill.shadow_enabled = false
	set_root.add_child(fill)
	VRBuild.merge_static(set_root)

static func car(parent: Node3D, pos: Vector3, yaw: float, color: Color) -> void:
	var c := Node3D.new()
	c.position = pos
	c.rotation = Vector3(0.025,yaw,-0.035)
	parent.add_child(c)
	var paint := surface("materials",2,color,0.45)
	paint.roughness = 0.78
	var rubber := VRBuild.mat(Color(0.018,0.02,0.022),0.95)
	var glass := VRBuild.mat(Color(0.025,0.04,0.045),0.26,0.45)
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var metal := surface("materials",3,Color(0.3,0.31,0.33),0.7)
	# Each longitudinal ring has bevelled shoulders and a narrower sill.
	var rings := [[-2.25,0.70,0.62],[-2.05,0.86,0.83],[-1.4,0.88,0.9],[0.8,0.87,0.86],[1.9,0.8,0.72],[2.2,0.65,0.57]]
	var rows: Array = []
	for r in rings:
		var z: float = r[0]
		var w: float = r[1]
		var y: float = r[2]
		rows.append([Vector3(-w*0.85,0.24,z),Vector3(-w,0.38,z),Vector3(-w,y-0.08,z),Vector3(-w*0.86,y,z),Vector3(w*0.86,y,z),Vector3(w,y-0.08,z),Vector3(w,0.38,z),Vector3(w*0.85,0.24,z)])
	for i in range(rows.size()-1):
		for j in range(8):
			panel(c,[rows[i][j],rows[i+1][j],rows[i+1][(j+1)%8],rows[i][(j+1)%8]],paint)
	panel(c,rows[0],paint)
	var end: Array = rows[-1].duplicate()
	end.reverse()
	panel(c,end,paint)
	# Sloping windshield and roof: not a box perched on another box.
	var a := Vector3(-0.74,0.88,0.85)
	var b := Vector3(0.74,0.88,0.85)
	var d := Vector3(-0.61,1.44,0.18)
	var e := Vector3(0.61,1.44,0.18)
	panel(c,[a,b,e,d],glass)
	panel(c,[d,e,Vector3(0.61,1.4,-0.95),Vector3(-0.61,1.4,-0.95)],paint)
	panel(c,[Vector3(-0.61,1.4,-0.95),Vector3(0.61,1.4,-0.95),Vector3(0.75,0.87,-1.65),Vector3(-0.75,0.87,-1.65)],glass)
	for side in [-1,1]:
		panel(c,[Vector3(side*0.75,0.88,-1.65),Vector3(side*0.61,1.4,-0.95),Vector3(side*0.61,1.44,0.18),Vector3(side*0.74,0.88,0.85)],glass)
		for z in [-1.43,1.35]:
			VRBuild.cylinder(c,0.32,0.2,Vector3(side*0.83,0.25,z),rubber,-1,Vector3(0,0,PI/2),20)
			VRBuild.cylinder(c,0.19,0.205,Vector3(side*0.84,0.25,z),metal,-1,Vector3(0,0,PI/2),16)
			VRBuild.cylinder(c,0.08,0.213,Vector3(side*0.85,0.25,z),rubber,-1,Vector3(0,0,PI/2),12)
		rod(c,Vector3(side*0.74,0.88,0.85),Vector3(side*0.61,1.44,0.18),0.035,paint)
		rod(c,Vector3(side*0.75,0.87,-1.65),Vector3(side*0.61,1.4,-0.95),0.035,paint)
		rod(c,Vector3(side*0.82,0.85,-0.55),Vector3(side*0.61,1.42,-0.55),0.04,paint)
		rod(c,Vector3(side*0.88,0.68,-0.7),Vector3(side*0.88,0.68,-0.45),0.018,metal)
	# Detached bumper and grille fins; unlit lamps sell the abandoned scene.
	VRBuild.box(c,Vector3(1.55,0.12,0.12),Vector3(0.12,0.27,2.28),metal,Vector3(0,0.08,0.06))
	for x in [-0.5,-0.38,0.38,0.5]:
		VRBuild.cylinder(c,0.09,0.03,Vector3(x,0.56,2.15),metal,-1,Vector3(PI/2,0,0),16)
	for x in range(-4,5):
		VRBuild.box(c,Vector3(0.025,0.12,0.03),Vector3(x*0.045,0.48,2.19),rubber)
	VRBuild.merge_static(c)
