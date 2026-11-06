class_name PinballPlayfield
extends Node3D
## Geometry and simulation use one coordinate mapping; local +Z is above the playfield.
var table: PinTable
var ball_mesh: MeshInstance3D
var flippers: Array = []
var bumper_mats: Array = []
var target_mats: Array = []
static func point(v: Vector2, height := 0.0) -> Vector3:
	return Vector3((v.x - 200.0) * 0.0014, (400.0 - v.y) * 0.0014, height)

func rod(a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var m := VRBuild.cylinder(self, radius, a.distance_to(b), (a + b) * 0.5, material, -1.0, Vector3.ZERO, 10)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length_squared() < 0.001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	m.basis = Basis(x, y, x.cross(y)).orthonormalized()
	return m

func build(source: PinTable) -> void:
	table = source
	table.physical_view = true
	if table.segments.is_empty():
		table._build_segments()
	var steel := VRBuild.mat(Color(0.65, 0.68, 0.72), 0.18, 0.92)
	for seg in table.segments:
		rod(point(seg[0], 0.009), point(seg[1], 0.009), 0.0028, steel)
	for bp in PinTable.BUMPERS:
		VRBuild.cylinder(self, PinTable.BUMPER_R * 0.0014, 0.014, point(bp, 0.009), steel, -1.0, Vector3(PI / 2, 0, 0), 24)
		var cap := VRBuild.mat(Color(0.65, 0.12, 0.3), 0.3, 0.0, 0.4)
		bumper_mats.append(cap)
		VRBuild.cylinder(self, 0.024, 0.007, point(bp, 0.02), cap, -1.0, Vector3(PI / 2, 0, 0), 24)
	for tp in PinTable.TARGETS:
		var mat := VRBuild.mat(Color(0.15, 0.45, 0.3), 0.35, 0.0, 0.3)
		target_mats.append(mat)
		VRBuild.box(self, Vector3(0.012, 0.022, 0.016), point(tp, 0.01), mat)
	for ramp in PinTable.RAMPS:
		var path: Array = ramp.path
		for i in range(path.size() - 1):
			for offset in [-0.01, 0.01]:
				var a := point(path[i], 0.012 + sin(float(i) / (path.size() - 1) * PI) * 0.02)
				var b := point(path[i + 1], 0.012 + sin(float(i + 1) / (path.size() - 1) * PI) * 0.02)
				rod(a + Vector3(offset, 0, 0), b + Vector3(offset, 0, 0), 0.002, steel)
	for pivot in [PinTable.LEFT_PIVOT, PinTable.RIGHT_PIVOT]:
		var f := Node3D.new()
		add_child(f)
		f.position = point(pivot, 0.009)
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.009
		mesh.height = PinTable.FLIP_LEN * 0.0014 + 0.018
		mesh.radial_segments = 16
		mesh.rings = 4
		var vis := MeshInstance3D.new()
		vis.mesh = mesh
		vis.material_override = VRBuild.mat(Color(0.9, 0.88, 0.83), 0.28)
		vis.rotation.z = PI / 2
		vis.position.x = PinTable.FLIP_LEN * 0.0014 / 2
		f.add_child(vis)
		flippers.append(f)
	ball_mesh = VRBuild.sphere(self, PinTable.BALL_R * 0.0014, point(table.ball, 0.013), steel, 24)

func _process(delta: float) -> void:
	if table == null:
		return
	var target := point(table.ball, 0.013)
	# Ramp height follows its segmented distance, matching the ramp rail interpolation.
	if table.on_ramp >= 0:
		var path: Array = PinTable.RAMPS[table.on_ramp].path
		var left := table.ramp_d
		for i in range(path.size() - 1):
			var length: float = (path[i] as Vector2).distance_to(path[i + 1])
			if left <= length:
				var a := 0.012 + sin(float(i) / (path.size() - 1) * PI) * 0.02
				var b := 0.012 + sin(float(i + 1) / (path.size() - 1) * PI) * 0.02
				target.z += lerpf(a, b, left / maxf(length, 0.001))
				break
			left -= length
	ball_mesh.position = ball_mesh.position.lerp(target, 1.0 - exp(-delta * 22.0)) if table.network_remote else target
	ball_mesh.visible = not table.game_over
	flippers[0].rotation.z = -table.left_ang
	flippers[1].rotation.z = PI + table.right_ang
	for i in range(3):
		bumper_mats[i].emission_energy_multiplier = 0.4 + table.bump_flash[i] * 1.5
	for i in range(8):
		target_mats[i].emission_energy_multiplier = 1.5 if table.target_lit[i] else 0.15
