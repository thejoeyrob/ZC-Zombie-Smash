class_name RemoteGuest
extends Node3D
var avatar: VRAvatar
var hands: Array = []
var label: Label3D
var target: Dictionary = {}
var poses: Array = [Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY]
var age := 99.0

func build(display_name: String, skin: String, font: Font) -> void:
	avatar = VRAvatar.new()
	add_child(avatar)
	avatar.build(false)
	avatar.apply_skin(skin)
	for mitt in avatar._mitts:
		mitt.visible = false
	for side in range(2):
		var h := VRHand.new()
		add_child(h)
		h.build(side, avatar.hand_look())
		h.set_gauntlet(false)
		hands.append(h)
	label = VRBuild.label(self, display_name.left(20), 0.045, Vector3.ZERO, Color(0.8, 0.95, 1), Vector3.ZERO, 2, font)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	visible = false

func receive_pose(data: Dictionary) -> void:
	for key in ["head", "left", "right"]:
		if not data.get(key) is Array or data[key].size() != 7:
			return
		for n in data[key]:
			if not (n is float or n is int) or not is_finite(float(n)) or absf(float(n)) > 20:
				return
	if not data.get("curls") is Array or data.curls.size() != 6 or not data.get("active") is Array or data.active.size() != 2:
		return
	target = data
	var head := unpack(data.head)
	if age > 4 or poses[0].origin.distance_to(head.origin) > 1.0:
		poses = [head, unpack(data.left), unpack(data.right)]
		avatar._inited = false
	age = 0

static func unpack(a: Array) -> Transform3D:
	var q := Quaternion(a[3], a[4], a[5], a[6])
	if q.length_squared() < 0.001:
		q = Quaternion.IDENTITY
	return Transform3D(Basis(q.normalized()), Vector3(a[0], a[1], a[2]))

func _process(delta: float) -> void:
	age += delta
	visible = age < 4.0
	if not visible or target.is_empty():
		return
	var amount := 1.0 - exp(-delta * 18.0)
	for i in range(3):
		poses[i] = poses[i].interpolate_with(unpack(target[["head", "left", "right"][i]]), amount)
	var wrists: Array = []
	for i in range(2):
		hands[i].transform = poses[i + 1]
		hands[i].visible = target.active[i]
		hands[i].set_pose(target.curls[i * 3], target.curls[i * 3 + 1], target.curls[i * 3 + 2])
		wrists.append(poses[i + 1] * Vector3(0, -0.004, 0.075))
	avatar.scale_k = clampf(float(target.get("scale", 1.0)), 0.8, 1.3)
	avatar.hand_poses = [poses[1], poses[2]]
	avatar.finger_curls = target.curls
	avatar.update(poses[0], wrists, target.active, delta, bool(target.get("seated", false)))
	if avatar.human != null:
		for hand in hands:
			hand.visible = false
	label.position = poses[0].origin + Vector3(0, 0.27, 0)
