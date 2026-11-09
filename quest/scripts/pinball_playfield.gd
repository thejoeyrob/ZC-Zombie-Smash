class_name PinballPlayfield
extends Node3D
## The zombie table built out of real parts that stand on the painted playfield: wooden rails with chrome caps, tapered flippers, brain pop
## bumpers, rubber slingshots, stand-up targets, glowing inserts, two ramps with side walls and neon edges, a stone door that swallows the ball
## and a hole it comes out of, and a one-way flap at the top of the plunger lane. Geometry and simulation use one coordinate mapping
## (point()); local +Z is above the playfield. Everything that never moves is built under one node and merged into a few meshes.
const U := 0.0014                  # metres per table unit
const BALL_Z := 0.0128

var table: PinTable
var ball_mesh: MeshInstance3D
var flippers: Array = []
var bumper_mats: Array = []
var bumper_rings: Array = []
var bumper_domes: Array = []
var target_mats: Array = []
var insert_mats: Array = []
var sling_mats: Array = []
var ramp_floor_mats: Array = []
var ramp_edge_mats: Array = []
var door_leaf: Node3D
var door_glow: StandardMaterial3D
var exit_ring: StandardMaterial3D
var gate_flap: Node3D
var _statics: Node3D
var _t := 0.0

static func point(v: Vector2, height := 0.0) -> Vector3:
	return Vector3((v.x - 200.0) * U, (400.0 - v.y) * U, height)


func rod(a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var m := VRBuild.cylinder(_statics, radius, a.distance_to(b), (a + b) * 0.5, material, -1.0, Vector3.ZERO, 10)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length_squared() < 0.001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	m.basis = Basis(x, y, x.cross(y)).orthonormalized()
	return m


## A flat piece lying on the playfield, drawn from a table-space outline: top face and side walls, as two surfaces (top, sides).
func _prism(parent: Node3D, outline: PackedVector2Array, z0: float, z1: float, top_mat: Material, side_mat: Material) -> MeshInstance3D:
	for m in [top_mat, side_mat]:
		(m as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED      # either winding shows
	var st_top := SurfaceTool.new()
	st_top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := Geometry2D.triangulate_polygon(outline)
	for i in tri:
		st_top.set_normal(Vector3.BACK)
		st_top.add_vertex(Vector3(outline[i].x, outline[i].y, z1))
	var mesh := ArrayMesh.new()
	st_top.commit(mesh)
	var st_side := SurfaceTool.new()
	st_side.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	for i in range(n):
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var nrm := Vector3((b.y - a.y), -(b.x - a.x), 0.0).normalized()
		var va0 := Vector3(a.x, a.y, z0)
		var va1 := Vector3(a.x, a.y, z1)
		var vb0 := Vector3(b.x, b.y, z0)
		var vb1 := Vector3(b.x, b.y, z1)
		for v in [va0, vb0, vb1, va0, vb1, va1]:
			st_side.set_normal(nrm)
			st_side.add_vertex(v)
	st_side.commit(mesh)
	mesh.surface_set_material(0, top_mat)
	mesh.surface_set_material(1, side_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	return mi


## A tapered flipper outline (rounded at both ends) in metres, pivot at the origin, pointing along +x.
func _flipper_outline(length: float, r1: float, r2: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var th := asin(clampf((r1 - r2) / length, -0.9, 0.9))
	var steps := 10
	for i in range(steps + 1):                                        # around the pivot, the back of the flipper
		var a := lerpf(PI / 2.0 + th, 3.0 * PI / 2.0 - th, float(i) / steps)
		out.append(Vector2(cos(a), sin(a)) * r1)
	for i in range(steps + 1):                                        # around the tip
		var a := lerpf(-PI / 2.0 + th, PI / 2.0 - th, float(i) / steps)
		out.append(Vector2(length, 0.0) + Vector2(cos(a), sin(a)) * r2)
	# the outline above runs pivot-top -> pivot-bottom -> tip-bottom -> tip-top, which is counter-clockwise for the triangulator
	return out


## A dome (half an egg) lying on the playfield with its picture laid on flat from above, so a photo of the brain fits it exactly.
func _dome(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	var segs := 28
	for r in range(rings):
		for sg in range(segs):
			var quad: Array = []
			for corner in [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]]:
				var phi: float = (float(r + corner[0]) / rings) * PI / 2.0
				var th: float = (float(sg + corner[1]) / segs) * TAU
				var nx := sin(phi) * cos(th)
				var ny := sin(phi) * sin(th)
				var nz := cos(phi)
				var pos := Vector3(nx * radius, ny * radius, nz * height)
				st.set_normal(Vector3(nx / radius, ny / radius, nz / height).normalized())
				st.set_uv(Vector2(pos.x / (2.0 * radius) + 0.5, 0.5 - pos.y / (2.0 * radius)))
				st.add_vertex(pos)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(mi)
	return mi


## A ramp: a floor you can see through, two side walls and a glowing edge, following the ball's own path and rising in the middle.
func _ramp_mesh(ri: int, floor_mat: Material, wall_mat: Material, edge_mat: Material) -> MeshInstance3D:
	var pts := PinTable.ramp_points(ri)
	var total := PinTable.ramp_length(ri)
	var hw := 0.0185
	var wall_h := 0.011
	var st_f := SurfaceTool.new()
	var st_w := SurfaceTool.new()
	var st_e := SurfaceTool.new()
	for st in [st_f, st_w, st_e]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var run := 0.0
	var rows: Array = []
	for i in range(pts.size()):
		if i > 0:
			run += (pts[i] as Vector2).distance_to(pts[i - 1])
		var a: Vector2 = pts[maxi(i - 1, 0)]
		var b: Vector2 = pts[mini(i + 1, pts.size() - 1)]
		var tdir := (b - a).normalized()
		var c := point(pts[i], ramp_floor_z(ri, run, total))
		# table-space direction (tx, ty) maps to local (tx, -ty); the side vector is perpendicular to that
		var ldir := Vector3(tdir.x, -tdir.y, 0.0)
		var sv := Vector3(-ldir.y, ldir.x, 0.0)
		rows.append({"c": c, "s": sv})
	for i in range(rows.size() - 1):
		var r0: Dictionary = rows[i]
		var r1: Dictionary = rows[i + 1]
		var l0: Vector3 = r0.c + r0.s * hw
		var rr0: Vector3 = r0.c - r0.s * hw
		var l1: Vector3 = r1.c + r1.s * hw
		var rr1: Vector3 = r1.c - r1.s * hw
		for v in [l0, rr0, rr1, l0, rr1, l1]:
			st_f.set_normal(Vector3.BACK)
			st_f.add_vertex(v)
		var up := Vector3(0, 0, wall_h)
		# left wall: inner face (normal toward the middle) and top; right wall likewise
		for sgn in [1.0, -1.0]:
			var a0: Vector3 = (r0.c as Vector3) + (r0.s as Vector3) * hw * sgn
			var a1: Vector3 = (r1.c as Vector3) + (r1.s as Vector3) * hw * sgn
			var nrm: Vector3 = -(r0.s as Vector3) * sgn
			for v in [a0, a1, a1 + up, a0, a1 + up, a0 + up]:
				st_w.set_normal(nrm)
				st_w.add_vertex(v)
			for v in [a0 + up, a1 + up, a1 + up + (r1.s as Vector3) * 0.004 * sgn, a0 + up, a1 + up + (r1.s as Vector3) * 0.004 * sgn, a0 + up + (r0.s as Vector3) * 0.004 * sgn]:
				st_e.set_normal(Vector3.BACK)
				st_e.add_vertex(v)
	var mesh := ArrayMesh.new()
	st_f.commit(mesh)
	st_w.commit(mesh)
	st_e.commit(mesh)
	mesh.surface_set_material(0, floor_mat)
	mesh.surface_set_material(1, wall_mat)
	mesh.surface_set_material(2, edge_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	# legs: thin chrome posts under the high part so the ramp reads as a raised ramp
	var steel := VRBuild.mat(Color(0.7, 0.72, 0.78), 0.2, 0.9)
	for i in range(8, rows.size() - 6, 7):
		var c: Vector3 = rows[i].c
		if c.z > 0.016:
			VRBuild.cylinder(_statics, 0.0016, c.z, Vector3(c.x, c.y, c.z * 0.5), steel, -1.0, Vector3(PI / 2, 0, 0), 6)
	return mi


static func ramp_floor_z(ri: int, run: float, total: float) -> float:
	return 0.012 + sin(clampf(run / maxf(total, 0.001), 0.0, 1.0) * PI) * 0.024


func build(source: PinTable) -> void:
	table = source
	table.physical_view = true
	if table.segments.is_empty():
		table._build_segments()
	_statics = Node3D.new()
	add_child(_statics)
	var steel := VRBuild.mat(Color(0.7, 0.72, 0.78), 0.18, 0.92)
	var wood := VRBuild.mat(Color(0.1, 0.07, 0.06), 0.6, 0.1)
	var rubber := VRBuild.mat(Color(0.5, 0.04, 0.07), 0.8)
	var black := VRBuild.mat(Color(0.03, 0.03, 0.04), 0.7)
	var stone := VRBuild.mat(Color(0.22, 0.2, 0.19), 0.9)
	# rails: a dark wall with a chrome cap
	for seg in table.segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var kick: float = seg[3]
		if kick > 0.0:
			continue                                    # the slingshot edges are built below
		var pa := point(a)
		var pb := point(b)
		var len := pa.distance_to(pb)
		if len < 0.001:
			continue
		var mid := (pa + pb) * 0.5
		var ang := atan2(pb.y - pa.y, pb.x - pa.x)
		VRBuild.box(_statics, Vector3(len + 0.002, 0.006, 0.026), Vector3(mid.x, mid.y, 0.013), wood, Vector3(0, 0, ang))
		rod(point(a, 0.0275), point(b, 0.0275), 0.0026, steel)
	# the flipper-bat posts and the lane's bottom plate
	VRBuild.box(_statics, Vector3(0.03, 0.006, 0.01), point(Vector2(PinTable.LANE_X, 786.0), 0.005), black)
	# the plunger lane's one-way flap
	gate_flap = Node3D.new()
	add_child(gate_flap)
	gate_flap.position = point(Vector2(380.0, PinTable.GATE_Y), 0.014)
	VRBuild.box(gate_flap, Vector3(0.036, 0.0035, 0.012), Vector3(-0.018, 0, 0), steel)
	VRBuild.cylinder(gate_flap, 0.0035, 0.014, Vector3.ZERO, steel, -1.0, Vector3(PI / 2, 0, 0), 10)
	var brain_tex = load("res://assets/art/bumper-brain.png") if ResourceLoader.exists("res://assets/art/bumper-brain.png") else null
	# pop bumpers: a dark skirt, a chrome ring, a glowing ring and a brain dome that lights when hit
	for bp in PinTable.BUMPERS:
		var c := point(bp)
		VRBuild.cylinder(_statics, PinTable.BUMPER_R * U * 1.45, 0.004, Vector3(c.x, c.y, 0.002), black, -1.0, Vector3(PI / 2, 0, 0), 28)
		VRBuild.cylinder(_statics, PinTable.BUMPER_R * U * 1.02, 0.02, Vector3(c.x, c.y, 0.01), steel, PinTable.BUMPER_R * U * 0.96, Vector3(PI / 2, 0, 0), 28)
		var ring := VRBuild.mat(Color(0.9, 0.2, 0.55), 0.25, 0.0, 0.5)
		bumper_rings.append(ring)
		VRBuild.cylinder(self, PinTable.BUMPER_R * U * 1.06, 0.004, point(bp, 0.0085), ring, -1.0, Vector3(PI / 2, 0, 0), 28)
		var cap := VRBuild.mat(Color(0.7, 0.14, 0.32), 0.3, 0.0, 0.4, Color(0.8, 0.12, 0.3))
		if brain_tex != null:                         # the brain from the artwork on top of the dome
			cap.albedo_texture = brain_tex
			cap.albedo_color = Color.WHITE
			cap.emission_texture = brain_tex
			cap.emission = Color.WHITE
			cap.roughness = 0.35
		bumper_mats.append(cap)
		var dome := _dome(PinTable.BUMPER_R * U * 0.9, PinTable.BUMPER_R * U * 0.62, cap)
		dome.position = point(bp, 0.012)
		bumper_domes.append(dome)
	# slingshots: a triangular body with a rubber band on the kicking edge and a plate that flashes
	for side in [-1, 1]:
		var a := Vector2(200.0 + side * 128.0, 584.0)
		var b := Vector2(200.0 + side * 94.0, 650.0)
		var c2 := Vector2(200.0 + side * 128.0, 650.0)
		var plate := VRBuild.mat(Color(0.95, 0.5, 0.1), 0.4, 0.0, 0.5, Color(1.0, 0.45, 0.05))
		sling_mats.append(plate)
		var tri := PackedVector2Array([Vector2(point(a).x, point(a).y), Vector2(point(b).x, point(b).y), Vector2(point(c2).x, point(c2).y)])
		_prism(self, tri, 0.0, 0.019, plate, black)
		rod(point(a, 0.017), point(b, 0.017), 0.0042, rubber)
		VRBuild.sphere(_statics, 0.0048, point(a, 0.017), steel, 10)
		VRBuild.sphere(_statics, 0.0048, point(b, 0.017), steel, 10)
	# targets: stand-up targets with a chrome foot
	for tp in PinTable.TARGETS:
		var mat := VRBuild.mat(Color(0.1, 0.5, 0.65), 0.35, 0.0, 0.3, Color(0.1, 0.8, 1.0))
		target_mats.append(mat)
		VRBuild.box(self, Vector3(0.011, 0.02, 0.017), point(tp, 0.0105), mat)
		VRBuild.box(_statics, Vector3(0.016, 0.026, 0.003), point(tp, 0.0015), steel)
	# lit inserts the ball rolls over
	for i in range(PinTable.INSERTS.size()):
		var col: Color = PinTable.INSERT_COL[i]
		var im := VRBuild.mat(col * 0.35, 0.3, 0.0, 0.2, col)
		insert_mats.append(im)
		VRBuild.cylinder(self, 0.0072, 0.0014, point(PinTable.INSERTS[i], 0.0008), im, -1.0, Vector3(PI / 2, 0, 0), 14)
	# the two ramps
	var ramp_cols := [Color(1.0, 0.18, 0.62), Color(1.0, 0.55, 0.08)]
	for ri in range(PinTable.RAMPS.size()):
		var col: Color = ramp_cols[ri]
		var floor_mat := VRBuild.mat(Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.62), 0.15, 0.0, 0.3, col)
		floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		floor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ramp_floor_mats.append(floor_mat)
		var wall := VRBuild.mat(Color(0.75, 0.78, 0.85), 0.2, 0.9)
		wall.cull_mode = BaseMaterial3D.CULL_DISABLED
		var edge := VRBuild.mat(col, 0.3, 0.0, 1.6, col)
		edge.cull_mode = BaseMaterial3D.CULL_DISABLED
		ramp_edge_mats.append(edge)
		_ramp_mesh(ri, floor_mat, wall, edge)
	# the stone door in the left wall: two pillars, a lintel and a door leaf that swings open
	var dp := point(PinTable.DOOR_POS)
	VRBuild.box(_statics, Vector3(0.012, 0.014, 0.034), Vector3(dp.x - 0.002, dp.y + 0.026, 0.017), stone)
	VRBuild.box(_statics, Vector3(0.012, 0.014, 0.034), Vector3(dp.x - 0.002, dp.y - 0.026, 0.017), stone)
	VRBuild.box(_statics, Vector3(0.016, 0.066, 0.01), Vector3(dp.x - 0.002, dp.y, 0.037), stone)
	door_glow = VRBuild.mat(Color(0.05, 0.3, 0.12), 0.4, 0.0, 0.0, Color(0.2, 1.0, 0.4))
	VRBuild.box(_statics, Vector3(0.006, 0.04, 0.026), Vector3(dp.x - 0.008, dp.y, 0.014), door_glow)
	door_leaf = Node3D.new()
	add_child(door_leaf)
	door_leaf.position = Vector3(dp.x + 0.004, dp.y + 0.019, 0.0)
	var leaf_mat := VRBuild.mat(Color(0.28, 0.16, 0.08), 0.6, 0.1)
	VRBuild.box(door_leaf, Vector3(0.004, 0.038, 0.027), Vector3(0, -0.019, 0.0135), leaf_mat)
	VRBuild.box(door_leaf, Vector3(0.006, 0.038, 0.004), Vector3(0, -0.019, 0.016), steel)
	# the hole it comes out of: a dark mouth in a chrome collar with a glowing ring
	var ep := point(PinTable.EXIT_POS)
	VRBuild.cylinder(_statics, 0.0235, 0.004, Vector3(ep.x, ep.y, 0.002), black, -1.0, Vector3(PI / 2, 0, 0), 24)
	VRBuild.cylinder(_statics, 0.0215, 0.012, Vector3(ep.x, ep.y, 0.006), steel, 0.0185, Vector3(PI / 2, 0, 0), 24)
	exit_ring = VRBuild.mat(Color(0.1, 0.5, 0.35), 0.3, 0.0, 0.4, Color(0.3, 1.0, 0.7))
	VRBuild.cylinder(self, 0.0178, 0.0035, Vector3(ep.x, ep.y, 0.0112), exit_ring, -1.0, Vector3(PI / 2, 0, 0), 24)
	VRBuild.cylinder(_statics, 0.0138, 0.004, Vector3(ep.x, ep.y, 0.0125), black, -1.0, Vector3(PI / 2, 0, 0), 24)
	# flippers: a tapered body with a rubber side, a pivot cap, and a yellow stripe
	for pivot in [PinTable.LEFT_PIVOT, PinTable.RIGHT_PIVOT]:
		var f := Node3D.new()
		add_child(f)
		f.position = point(pivot, 0.003)
		var top := VRBuild.mat(Color(0.95, 0.62, 0.12), 0.3, 0.0, 0.25, Color(1.0, 0.55, 0.05))
		var edge_rubber := VRBuild.mat(Color(0.55, 0.05, 0.08), 0.75)
		_prism(f, _flipper_outline(PinTable.FLIP_LEN * U, 0.0125, 0.007), 0.0, 0.0125, top, edge_rubber)
		VRBuild.cylinder(f, 0.0055, 0.003, Vector3(0, 0, 0.0135), steel, -1.0, Vector3(PI / 2, 0, 0), 12)
		flippers.append(f)
	# the ball: polished steel
	var ball_mat := VRBuild.mat(Color(0.86, 0.89, 0.96), 0.16, 0.85, 0.5, Color(0.28, 0.32, 0.4))
	ball_mesh = VRBuild.sphere(self, PinTable.BALL_R * U, point(table.ball, BALL_Z), ball_mat, 24)
	VRBuild.merge_static(_statics)


func _process(delta: float) -> void:
	if table == null:
		return
	_t += delta
	var target := point(table.ball, BALL_Z)
	# on a ramp the ball rides along the ramp's floor
	if table.on_ramp >= 0:
		var total := PinTable.ramp_length(table.on_ramp)
		target.z = ramp_floor_z(table.on_ramp, table.ramp_d, total) + BALL_Z
	if table.network_remote:
		ball_mesh.position = ball_mesh.position.lerp(target, 1.0 - exp(-delta * 22.0))
	else:
		ball_mesh.position = target
	ball_mesh.visible = not table.game_over and not table.in_portal
	flippers[0].rotation.z = -table.left_ang
	flippers[1].rotation.z = PI + table.right_ang
	for i in range(3):
		var f: float = table.bump_flash[i]
		bumper_mats[i].emission_energy_multiplier = 0.4 + f * 2.2
		bumper_rings[i].emission_energy_multiplier = 0.5 + f * 3.0
		bumper_domes[i].scale = Vector3(1.0 + f * 0.08, 1.0 + f * 0.08, 1.0 + f * 0.15)
	for i in range(8):
		target_mats[i].emission_energy_multiplier = 1.8 if table.target_lit[i] else 0.2
		target_mats[i].emission = Color(1.0, 0.8, 0.15) if table.target_lit[i] else Color(0.1, 0.8, 1.0)
		target_mats[i].albedo_color = Color(0.9, 0.7, 0.1) if table.target_lit[i] else Color(0.1, 0.5, 0.65)
	for i in range(insert_mats.size()):
		var on: float = clampf(table.insert_t[i] if i < table.insert_t.size() else 0.0, 0.0, 1.0)
		insert_mats[i].emission_energy_multiplier = 0.25 + 0.15 * sin(_t * 3.0 + float(i)) + on * 2.2
	for i in range(2):
		sling_mats[i].emission_energy_multiplier = 0.5 + table.sling_flash[i] * 2.5
	for i in range(ramp_edge_mats.size()):
		ramp_edge_mats[i].emission_energy_multiplier = 1.6 + (2.2 if table.on_ramp == i else 0.0) + 0.3 * sin(_t * 4.0 + float(i))
	door_leaf.rotation.z = -deg_to_rad(105.0) * table.door_open
	door_glow.emission_energy_multiplier = 0.2 + table.door_open * 2.2
	exit_ring.emission_energy_multiplier = 0.5 + table.exit_flash * 3.5 + (1.2 if table.in_portal else 0.0) * (0.6 + 0.4 * sin(_t * 12.0))
	gate_flap.rotation.z = deg_to_rad(-18.0) - table.gate_flash * 0.5
