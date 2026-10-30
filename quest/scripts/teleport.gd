class_name Teleporter
extends Node3D
## Floor markers the player can point at and jump to while unlocked from the machine.

const RADIUS := 0.34

# name, label, floor position, point to face, colour
const SPOTS := [
	["machine", "PLAY", Vector3(0, 0, 0), Vector3(0, 1.4, -0.9), Color(0.2, 1.0, 0.4)],
	["prizes", "PRIZES", Vector3(0.0, 0, 3.05), Vector3(0, 1.5, 4.2), Color(1.0, 0.35, 0.75)],
	["prizes_left", "PRIZES", Vector3(-1.1, 0, 3.05), Vector3(-1.1, 1.5, 4.2), Color(1.0, 0.35, 0.75)],
	["prizes_right", "PRIZES", Vector3(1.1, 0, 3.05), Vector3(1.1, 1.5, 4.2), Color(1.0, 0.35, 0.75)],
	["bank_1", "WATCH", Vector3(-2.58, 0, 0.12), Vector3(-2.58, 1.4, -0.4), Color(0.2, 0.9, 1.0)],
	["bank_2", "WATCH", Vector3(-1.72, 0, 0.12), Vector3(-1.72, 1.4, -0.4), Color(1.0, 0.3, 0.8)],
	["bank_3", "WATCH", Vector3(-0.86, 0, 0.12), Vector3(-0.86, 1.4, -0.4), Color(1.0, 0.85, 0.2)],
	["bank_5", "WATCH", Vector3(0.86, 0, 0.12), Vector3(0.86, 1.4, -0.4), Color(1.0, 0.55, 0.1)],
	["bank_6", "WATCH", Vector3(1.72, 0, 0.12), Vector3(1.72, 1.4, -0.4), Color(0.6, 0.4, 1.0)],
	["bank_7", "WATCH", Vector3(2.58, 0, 0.12), Vector3(2.58, 1.4, -0.4), Color(1.0, 0.3, 0.3)],
	["left_1", "WATCH", Vector3(-2.35, 0, 0.9), Vector3(-3.1, 1.3, 0.9), Color(1.0, 0.3, 0.9)],
	["left_2", "WATCH", Vector3(-2.35, 0, 1.9), Vector3(-3.1, 1.3, 1.9), Color(0.3, 0.9, 1.0)],
	["left_3", "WATCH", Vector3(-2.35, 0, 2.9), Vector3(-3.1, 1.3, 2.9), Color(1.0, 0.7, 0.2)],
	["right_1", "WATCH", Vector3(2.35, 0, 0.9), Vector3(3.1, 1.3, 0.9), Color(0.8, 0.4, 1.0)],
	["right_2", "WATCH", Vector3(2.35, 0, 1.9), Vector3(3.1, 1.3, 1.9), Color(0.4, 1.0, 0.5)],
	["right_3", "WATCH", Vector3(2.35, 0, 2.9), Vector3(3.1, 1.3, 2.9), Color(1.0, 0.4, 0.3)],
]

var markers: Array = []      # [{node, ring_mat, spot}]
var ray_mesh: MeshInstance3D
var reticle: MeshInstance3D
var hover := -1
var shown := false
var t := 0.0


func build(root: Node3D) -> void:
	root.add_child(self)
	for spot in SPOTS:
		var n := Node3D.new()
		n.position = spot[2] + Vector3(0, 0.012, 0)
		add_child(n)
		var col: Color = spot[4]
		var ring := VRBuild.mat(col, 0.4, 0.0, 2.2)
		ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.albedo_color.a = 0.85
		var torus := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = RADIUS - 0.035
		tm.outer_radius = RADIUS
		tm.ring_segments = 8
		tm.rings = 40
		torus.mesh = tm
		torus.scale = Vector3(1, 0.1, 1)
		torus.material_override = ring
		n.add_child(torus)
		var disc := VRBuild.cylinder(n, RADIUS - 0.04, 0.004, Vector3(0, 0.002, 0), _disc_mat(col), -1.0, Vector3.ZERO, 40)
		disc.name = "Disc"
		# a chevron marking which way you will face
		var dir: Vector3 = (spot[3] - spot[2])
		dir.y = 0.0
		var arrow := VRBuild.box(n, Vector3(0.1, 0.004, 0.16), Vector3(0, 0.006, 0), _disc_mat(col, 0.9))
		arrow.rotation.y = atan2(-dir.x, -dir.z)
		arrow.position = Vector3(-dir.normalized().x * -0.0, 0.006, 0)
		var tag := VRBuild.label(n, spot[1], 0.12, Vector3(0, 0.45, 0), Color(1, 1, 1, 0.95), Vector3.ZERO, 6)
		tag.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		tag.double_sided = true
		markers.append({"node": n, "ring": ring, "spot": spot, "disc": disc})
	# pointer beam and landing reticle
	ray_mesh = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.003
	cm.bottom_radius = 0.003
	cm.height = 1.0
	cm.radial_segments = 6
	ray_mesh.mesh = cm
	ray_mesh.material_override = VRBuild.mat(Color(0.5, 1.0, 0.7), 0.5, 0.0, 3.0)
	add_child(ray_mesh)
	ray_mesh.visible = false
	set_shown(false)


func _disc_mat(col: Color, alpha := 0.22) -> StandardMaterial3D:
	var m := VRBuild.mat(col, 0.5, 0.0, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = alpha
	return m


func set_shown(on: bool) -> void:
	shown = on
	visible = on
	if not on:
		ray_mesh.visible = false
		hover = -1


func _process(delta: float) -> void:
	t += delta
	if not shown:
		return
	for i in range(markers.size()):
		var m: Dictionary = markers[i]
		var on := i == hover
		var a := 0.95 if on else 0.55 + 0.2 * sin(t * 3.0 + i)
		m.ring.albedo_color.a = a
		m.ring.emission_energy_multiplier = 4.0 if on else 1.6
		m.node.scale = Vector3.ONE * (1.12 if on else 1.0)


## Points a ray (world) at the floor: lights up the marker under it. Returns the index of that marker or -1.
func aim(origin: Vector3, dir: Vector3, hide_spot := -1) -> int:
	hover = -1
	ray_mesh.visible = false
	if not shown or dir.y > -0.02:
		return -1
	var dist := -origin.y / dir.y
	if dist < 0.2 or dist > 14.0:
		return -1
	var hit := origin + dir * dist
	var best := 1.0e9
	for i in range(markers.size()):
		if i == hide_spot:
			continue
		var d := Vector2(hit.x - markers[i].spot[2].x, hit.z - markers[i].spot[2].z).length()
		if d < RADIUS + 0.12 and d < best:
			best = d
			hover = i
	ray_mesh.visible = true
	var end := hit
	if hover >= 0:
		end = markers[hover].spot[2] + Vector3(0, 0.02, 0)
	var length := origin.distance_to(end)
	var mid := (origin + end) / 2.0
	ray_mesh.global_position = mid
	ray_mesh.global_transform.basis = Basis.looking_at((end - origin).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI / 2)
	ray_mesh.scale = Vector3(1, length, 1)
	var m := ray_mesh.material_override as StandardMaterial3D
	m.albedo_color = Color(0.3, 1.0, 0.5) if hover >= 0 else Color(0.8, 0.8, 0.9)
	m.emission = m.albedo_color
	return hover
