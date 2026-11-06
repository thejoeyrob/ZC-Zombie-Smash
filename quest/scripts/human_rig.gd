class_name HumanRig
extends Node3D
## Imported Microsoft Rocketbox skinned human; no primitive mesh body is rendered.
## Prototype retargeting adapter: headset/controller calibration must pass headset QA before release.
var skeleton: Skeleton3D
var model: Node3D
var ready_rig := false
var self_view := false
var rest_eye := Vector3.ZERO
var eye_from_head := Vector3.ZERO       # the eye midpoint in the head bone's own frame (skeleton units)
var current_mode := "full"
var tracked := [true, true]
var head_bone := -1
var head_rest_basis := Basis.IDENTITY
var arms: Array = []              # per side: rest data for the two-bone arm solver (skeleton space)
var legs: Array = []
var foot_world_rest: Array = []   # per side: the foot's orientation in the world when the body is at yaw 0 and unscaled
var ankle_rest_y := 0.1
var hand_offsets: Array = []
var fingers: Array = []
var tracked_fingers: Array = [{}, {}]
var hand_poses: Array = []
var finger_curls: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

func bone(suffix: String) -> int:
	for i in range(skeleton.get_bone_count()):
		var clean := String(skeleton.get_bone_name(i)).replace("_", " ")
		if clean.ends_with(suffix):
			return i
	return -1

## The skeleton's transform in this node's own space (works before the node is in the scene tree).
func _sx() -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = skeleton
	while n != null and n != self:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


const FOLDERS := {"human_m01": "male", "human_f02": "female", "human_joeyrob": "m11", "human_discoman": "m03", "human_fatamy": "f09", "human_drmantis": "m09",
	"human_debo": "m04", "human_glowing": "m16", "human_jordan": "m06", "human_riley": "f04"}


func build(profile: String, for_self: bool) -> bool:
	self_view = for_self
	var folder := "res://avatars/" + str(FOLDERS.get(profile, "male")) + "/"
	# A release preflight requires complete licensed textures, not an untextured substitute.
	if not FileAccess.file_exists(folder + "READY.json") or not ResourceLoader.exists(folder + "model.fbx"):
		return false
	model = load(folder + "model.fbx").instantiate()
	add_child(model)
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		return false
	skeleton = rigs[0]
	for player in model.find_children("*", "AnimationPlayer", true, false):
		player.stop()
	head_bone = bone("Head")
	var left_eye := bone("LEye")
	var right_eye := bone("REye")
	if head_bone < 0 or left_eye < 0 or right_eye < 0:
		return false
	# Normalize the imported centimetre/metre convention from real joint positions.
	var eye := ((_sx() * skeleton.get_bone_global_rest(left_eye).origin) + (_sx() * skeleton.get_bone_global_rest(right_eye).origin)) * 0.5
	var head := (_sx() * skeleton.get_bone_global_rest(head_bone).origin)
	var face := eye - head
	face.y = 0
	if face.length() > 0.001:
		model.rotate_y(-atan2(-face.x, -face.z))
	eye = ((_sx() * skeleton.get_bone_global_rest(left_eye).origin) + (_sx() * skeleton.get_bone_global_rest(right_eye).origin)) * 0.5
	if eye.y < 0.1:
		return false
	model.scale *= 1.62 / eye.y
	rest_eye = (((_sx() * skeleton.get_bone_global_rest(left_eye).origin) + (_sx() * skeleton.get_bone_global_rest(right_eye).origin)) * 0.5)
	head_rest_basis = (_sx().basis * skeleton.get_bone_global_rest(head_bone).basis).orthonormalized()
	var rest_head := skeleton.get_bone_global_rest(head_bone)
	eye_from_head = rest_head.affine_inverse() * ((skeleton.get_bone_global_rest(left_eye).origin + skeleton.get_bone_global_rest(right_eye).origin) * 0.5)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var imported: Material = mesh.mesh.surface_get_material(surface)
			var label := String(imported.resource_name).to_lower() if imported != null else "body"
			var part := "head" if "head" in label else ("opacity" if "opacity" in label else "body")
			var material := StandardMaterial3D.new()
			material.albedo_texture = load(folder + part + "_color.png")
			material.roughness = 0.7 if part == "body" else 0.53
			if ResourceLoader.exists(folder + part + "_normal.png"):
				material.normal_enabled = true
				material.normal_texture = load(folder + part + "_normal.png")
				material.normal_scale = 0.65
			if part == "opacity":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold = 0.45
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.set_surface_override_material(surface, material)
	for original in model.find_children("*", "MeshInstance3D", true, false):
		_partition(original)
	set_body_mode("full")
	for side in range(2):
		var prefix := "L " if side == 0 else "R "
		var hand := bone(prefix + "Hand")
		var middle := bone(prefix + "Finger2")
		var index := bone(prefix + "Finger1")
		var little := bone(prefix + "Finger4")
		if mini(hand, mini(middle, mini(index, little))) < 0:
			return false
		var w := skeleton.get_bone_global_rest(hand).origin
		var forward := (skeleton.get_bone_global_rest(middle).origin - w).normalized()
		var up := skeleton.get_bone_global_rest(index).origin - skeleton.get_bone_global_rest(little).origin
		up = (up - forward * up.dot(forward)).normalized()
		var canonical := Basis(forward.cross(up), up, -forward).orthonormalized()
		hand_offsets.append(canonical.inverse() * skeleton.get_bone_global_rest(hand).basis.orthonormalized())
		arms.append(_limb(bone(prefix + "UpperArm"), bone(prefix + "Forearm"), bone(prefix + "Hand")))
		legs.append(_limb(bone(prefix + "Thigh"), bone(prefix + "Calf"), bone(prefix + "Foot")))
		foot_world_rest.append((_sx().basis.orthonormalized() * skeleton.get_bone_global_rest(bone(prefix + "Foot")).basis.orthonormalized()).orthonormalized())
		for f in range(5):
			for joint in range(3):
				var id := bone(prefix + "Finger%d" % f + (str(joint) if joint > 0 else ""))
				if id >= 0:
					var rest := skeleton.get_bone_rest(id)
					var axis := skeleton.get_bone_global_rest(id).basis.inverse() * canonical.y
					fingers.append({"bone": id, "rest": rest.basis.get_rotation_quaternion(), "axis": axis.normalized(), "side": side, "finger": f, "joint": joint})
	ankle_rest_y = ((_sx() * skeleton.get_bone_global_rest(bone("L Foot")).origin)).y
	for group in ["body", "left_arms", "right_arms", "left_hands", "right_hands", "head"]:
		if not body_parts.has(group) or body_parts[group].is_empty():
			push_error("Human mesh partition failed for " + group)
			return false
	ready_rig = true
	return true

## Rest data for one limb (upper, middle and end bone), in skeleton space, for the two-bone solver.
func _limb(upper: int, mid: int, end: int) -> Dictionary:
	var u := skeleton.get_bone_global_rest(upper)
	var m := skeleton.get_bone_global_rest(mid)
	var e := skeleton.get_bone_global_rest(end)
	return {"upper": upper, "mid": mid, "end": end, "S0": u.origin, "E0": m.origin, "W0": e.origin,
		"Bu": u.basis.orthonormalized(), "Bm": m.basis.orthonormalized(), "l1": (m.origin - u.origin).length(), "l2": (e.origin - m.origin).length()}


## Turns direction a onto direction b (the shortest way round).
static func _arc(a: Vector3, b: Vector3) -> Basis:
	var d := clampf(a.dot(b), -1.0, 1.0)
	if d > 0.99999:
		return Basis.IDENTITY
	var axis := a.cross(b)
	if axis.length() < 0.00001:
		axis = a.cross(Vector3.UP) if absf(a.dot(Vector3.UP)) < 0.9 else a.cross(Vector3.RIGHT)
	return Basis(axis.normalized(), acos(d))


## Puts a limb so that its end bone is at `target` (skeleton space; it stretches up to `stretch` times to reach), bending toward `pole`
## (a direction), and gives the end bone the orientation `end_basis` (skeleton space).
func _solve_limb(l: Dictionary, target: Vector3, pole: Vector3, end_basis: Basis, stretch := 1.15) -> void:
	var s0: Vector3 = l.S0
	var l1: float = l.l1
	var l2: float = l.l2
	var to_t := target - s0
	var dist := to_t.length()
	if dist < 0.0001:
		return
	var k := 1.0
	if dist > (l1 + l2) * 0.999:
		k = minf(dist / ((l1 + l2) * 0.999), stretch)
	var a := l1 * k
	var b := l2 * k
	dist = minf(dist, a + b - 0.0005)
	var dir := to_t / to_t.length()
	var cosv := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var along := a * cosv
	var h := sqrt(maxf(a * a - along * along, 0.0))
	var side := pole - dir * pole.dot(dir)
	side = side.normalized() if side.length() > 0.0001 else Vector3.UP
	var elbow := s0 + dir * along + side * h
	var wrist := s0 + dir * dist
	var d0: Vector3 = ((l.E0 as Vector3) - s0).normalized()
	var r1 := _arc(d0, (elbow - s0).normalized())
	skeleton.set_bone_global_pose_override(l.upper, Transform3D((r1 * (l.Bu as Basis)).scaled(Vector3.ONE * k), s0), 1.0, true)
	var f0: Vector3 = ((l.W0 as Vector3) - (l.E0 as Vector3)).normalized()
	var r2 := _arc(r1 * f0, (wrist - elbow).normalized())
	skeleton.set_bone_global_pose_override(l.mid, Transform3D((r2 * r1 * (l.Bm as Basis)).scaled(Vector3.ONE * k), elbow), 1.0, true)
	skeleton.set_bone_global_pose_override(l.end, Transform3D(end_basis, wrist), 1.0, true)


func pose(head: Transform3D, wrists: Array, feet: Array, active: Array, yaw: float, body_scale: float) -> void:
	if not ready_rig:
		return
	var root_basis := Basis(Vector3.UP, yaw)
	global_transform = Transform3D(root_basis.scaled(Vector3.ONE * body_scale), head.origin - root_basis * rest_eye * body_scale)
	skeleton.clear_bones_global_pose_override()
	var sk_xf := skeleton.global_transform
	var to_skel := sk_xf.affine_inverse()
	var rot_to_skel := sk_xf.basis.orthonormalized().inverse()
	var head_pose := skeleton.get_bone_global_pose(head_bone)
	head_pose.basis = rot_to_skel * head.basis * head_rest_basis
	head_pose.origin = to_skel * head.origin - head_pose.basis * eye_from_head      # the eyes stay exactly at the headset pose while the head turns and pitches
	tracked = active
	set_body_mode(current_mode)
	skeleton.set_bone_global_pose_override(head_bone, head_pose, 1.0, true)
	for side in range(2):
		var sgn := -1.0 if side == 0 else 1.0
		# arm: the hand goes where the real hand is, turned the way the real hand is turned
		var hand_basis := root_basis * Basis(Vector3.RIGHT, -1.2)
		if hand_poses.size() == 2:
			hand_basis = (hand_poses[side] as Transform3D).basis.orthonormalized()
		var arm_pole: Vector3 = rot_to_skel * (root_basis * Vector3(sgn * 0.6, -0.85, 0.45))
		_solve_limb(arms[side], to_skel * (wrists[side] as Vector3), arm_pole, rot_to_skel * hand_basis * (hand_offsets[side] as Basis), 1.18)
		# leg: the foot stays planted where the body's stepping logic put it
		var ankle: Vector3 = (feet[side] as Vector3) + Vector3(0, ankle_rest_y * body_scale, 0)
		var leg_pole: Vector3 = rot_to_skel * (root_basis * Vector3(sgn * 0.12, 0.1, -1.0))
		_solve_limb(legs[side], to_skel * ankle, leg_pole, rot_to_skel * root_basis * (foot_world_rest[side] as Basis), 1.06)
	for finger in fingers:
		var curl_index: int = finger.side * 3 + (2 if finger.finger == 0 else (0 if finger.finger == 1 else 1))
		var curl: float = clampf(finger_curls[curl_index], 0, 1)
		var angle := curl * (0.65 if finger.finger == 0 else 1.25)
		var name: String = ["thumb", "index", "middle", "ring", "pinky"][finger.finger]
		if tracked_fingers.size() == 2 and tracked_fingers[finger.side].has(name):
			var values: Array = tracked_fingers[finger.side][name]
			angle = clampf(float(values[mini(finger.joint, values.size() - 1)]), 0, 1.65)
		angle *= -1.0 if finger.side == 0 else 1.0
		skeleton.set_bone_pose_rotation(finger.bone, finger.rest * Quaternion(finger.axis, angle))


var body_parts := {}
func set_body_mode(mode: String) -> void:
	current_mode = mode
	for group in body_parts:
		var side := 0 if group.begins_with("left_") else 1
		var is_hand: bool = group.ends_with("hands")
		var is_arm: bool = group.ends_with("arms")
		var shown: bool = is_hand or (is_arm and mode != "hands") or (group == "body" and mode == "full") or (group == "head" and not self_view)
		if self_view and (is_hand or is_arm) and not tracked[side]:
			shown = false                                  # a hand that is not tracked is not drawn (the other side stays)
		for mesh in body_parts[group]:
			mesh.visible = shown

func _partition(source: MeshInstance3D) -> void:
	if source.skin == null:
		return
	var parts := {"body": ArrayMesh.new(), "left_arms": ArrayMesh.new(), "right_arms": ArrayMesh.new(), "left_hands": ArrayMesh.new(), "right_hands": ArrayMesh.new(), "head": ArrayMesh.new()}
	for surface in range(source.mesh.get_surface_count()):
		var arrays: Array = source.mesh.surface_get_arrays(surface)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if bones.is_empty() or weights.is_empty():
			continue
		var per_vertex := int(bones.size() / vertices.size())
		var groups: Array = []
		for v in range(vertices.size()):
			var biggest := -1.0
			var bind := 0
			for k in range(per_vertex):
				if weights[v * per_vertex + k] > biggest:
					biggest = weights[v * per_vertex + k]
					bind = bones[v * per_vertex + k]
			var id := source.skin.get_bind_bone(bind)
			if id < 0:
				id = skeleton.find_bone(source.skin.get_bind_name(bind))
			var group := "body"
			var cursor := id
			while cursor >= 0:
				var name := String(skeleton.get_bone_name(cursor)).replace("_", " ")
				if name.ends_with("Head") or name.ends_with("Neck"):
					group = "head"
					break
				if name.ends_with(" Hand"):
					group = ("left_" if " L " in name else "right_") + "hands"
					break
				if name.ends_with(" UpperArm") or name.ends_with(" Forearm") or name.ends_with(" Clavicle"):
					group = ("left_" if " L " in name else "right_") + "arms"
					break
				cursor = skeleton.get_bone_parent(cursor)
			groups.append(group)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices = PackedInt32Array(range(vertices.size()))
		var chosen := {"body": PackedInt32Array(), "left_arms": PackedInt32Array(), "right_arms": PackedInt32Array(), "left_hands": PackedInt32Array(), "right_hands": PackedInt32Array(), "head": PackedInt32Array()}
		for i in range(0, indices.size(), 3):
			var g: String = groups[indices[i]]
			if groups[indices[i + 1]] == groups[indices[i + 2]]:
				g = groups[indices[i + 1]]
			chosen[g].append_array(PackedInt32Array([indices[i], indices[i + 1], indices[i + 2]]))
		for group in parts:
			if chosen[group].is_empty():
				continue
			var split := arrays.duplicate()
			split[Mesh.ARRAY_INDEX] = chosen[group]
			parts[group].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, split)
			parts[group].surface_set_material(parts[group].get_surface_count() - 1, source.get_active_material(surface))
	for group in parts:
		if parts[group].get_surface_count() == 0:
			continue
		var mesh := MeshInstance3D.new()
		source.get_parent().add_child(mesh)
		mesh.transform = source.transform
		mesh.mesh = parts[group]
		mesh.skin = source.skin
		mesh.skeleton = mesh.get_path_to(skeleton)
		if not body_parts.has(group):
			body_parts[group] = []
		body_parts[group].append(mesh)
	source.visible = false

func fingertip(side: int) -> Vector3:
	var prefix := "L " if side == 0 else "R "
	var middle := bone(prefix + "Finger11")
	var tip := bone(prefix + "Finger12")
	var a := skeleton.to_global(skeleton.get_bone_global_pose(middle).origin)
	var b := skeleton.to_global(skeleton.get_bone_global_pose(tip).origin)
	return b + (b - a).normalized() * 0.019 * global_basis.get_scale().x

func palm(side: int) -> Vector3:
	var prefix := "L " if side == 0 else "R "
	var a := skeleton.to_global(skeleton.get_bone_global_pose(bone(prefix + "Hand")).origin)
	var b := skeleton.to_global(skeleton.get_bone_global_pose(bone(prefix + "Finger2")).origin)
	return a.lerp(b, 0.55)
