class_name VRHand
extends Node3D
## A cartoon arcade-glove hand that follows a controller's grip pose. Fingers curl from the grip and trigger,
## so the player sees an open hand, a pointing finger or a fist. Local axes (grip pose): fingers point -Z,
## thumb up (+Y), palm faces +X on the left hand and -X on the right hand.

const FINGERS := [
	# name, y offset, length of the three bones, radius
	["index", 0.026, [0.040, 0.026, 0.022], 0.0092],
	["middle", 0.0085, [0.044, 0.029, 0.024], 0.0098],
	["ring", -0.009, [0.041, 0.027, 0.022], 0.0092],
	["pinky", -0.0255, [0.032, 0.021, 0.019], 0.0082],
]

var side := 0                      # 0 left, 1 right
var s := 1.0                       # +1 left (palm +X), -1 right (palm -X)
var joints := {}                   # finger name -> [Node3D, Node3D, Node3D]
var thumb: Array = []
var curl := {"index": 0.0, "grip": 0.0, "thumb": 0.0}
var nail_mat: StandardMaterial3D
var shown := {"index": 0.0, "grip": 0.0, "thumb": 0.0}


func build(hand_side: int, glove_color := Color(0.94, 0.94, 0.97), cuff_color := Color(0.8, 0.1, 0.15)) -> void:
	side = hand_side
	s = 1.0 if side == 0 else -1.0
	var skin_tex = load("res://assets/art/hand-skin.jpg")
	var glove := VRBuild.mat(Color(0.93, 0.74, 0.62), 0.55)
	if skin_tex != null:
		glove = VRBuild.tex_mat(skin_tex, 0.0, 0.55, false, Color(1.0, 0.8, 0.68))
		glove.uv1_scale = Vector3(1.2, 1.2, 1)
		glove.texture_repeat = true
	glove.rim_enabled = true
	glove.rim = 0.2
	glove.rim_tint = 0.4
	nail_mat = VRBuild.mat(Color(0.96, 0.82, 0.78), 0.2)
	var stitch := VRBuild.mat(Color(0.8, 0.6, 0.5), 0.7)
	var cuff := VRBuild.mat(cuff_color, 0.5)
	# palm and back of the hand, built from soft overlapping masses so it reads as a hand, not a block
	var core := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.022, 0.058, 0.07)
	core.mesh = pm
	core.material_override = glove
	core.position = Vector3(0, 0, -0.016)
	add_child(core)
	var dome := VRBuild.sphere(self, 0.034, Vector3(-s * 0.007, 0.0, -0.022), glove, 16)      # back of the hand
	dome.scale = Vector3(0.62, 0.95, 1.18)
	var pad := VRBuild.sphere(self, 0.032, Vector3(s * 0.007, 0.0, -0.02), glove, 16)         # palm pad
	pad.scale = Vector3(0.55, 0.95, 1.2)
	var mound := VRBuild.sphere(self, 0.024, Vector3(s * 0.006, 0.027, 0.002), glove, 14)     # thumb mound
	mound.scale = Vector3(0.8, 1.0, 1.15)
	VRBuild.sphere(self, 0.03, Vector3(-s * 0.002, -0.004, 0.018), glove, 14)                # heel of the hand
	for f in FINGERS:
		var kn := VRBuild.sphere(self, float(f[3]) * 1.12, Vector3(0, f[1], -0.054), glove, 10)   # knuckles
		kn.scale = Vector3(1.0, 1.0, 1.0)
	# the wrist: a short bare section that disappears into the sleeve of the arm
	VRBuild.cylinder(self, 0.029, 0.05, Vector3(0, -0.002, 0.075), glove, 0.03, Vector3(PI / 2, 0, 0), 20)
	for f in FINGERS:
		var kn := VRBuild.sphere(self, float(f[3]) * 1.12, Vector3(0, f[1], -0.054), glove, 10)   # knuckles
		kn.scale = Vector3(1.0, 1.0, 1.0)
	# wrist cuff: a ribbed band and a coloured stripe
	VRBuild.cylinder(self, 0.034, 0.05, Vector3(0, -0.004, 0.066), glove, 0.032, Vector3(PI / 2, 0, 0), 20)
	VRBuild.cylinder(self, 0.0365, 0.012, Vector3(0, -0.004, 0.052), cuff, -1.0, Vector3(PI / 2, 0, 0), 20)
	for k in range(3):
		VRBuild.cylinder(self, 0.0355, 0.004, Vector3(0, -0.004, 0.072 + k * 0.012), VRBuild.mat(Color(0.82, 0.82, 0.86), 0.7), -1.0, Vector3(PI / 2, 0, 0), 20)
	# a stitched line along the back of the hand and a velcro tab
	VRBuild.box(self, Vector3(0.002, 0.004, 0.07), Vector3(-s * 0.0235, 0, -0.012), stitch)
	VRBuild.box(self, Vector3(0.006, 0.03, 0.02), Vector3(-s * 0.036, 0.0, 0.03), VRBuild.mat(Color(0.2, 0.2, 0.24), 0.7))
	for f in FINGERS:
		var root := Node3D.new()
		root.position = Vector3(0, f[1], -0.056)
		add_child(root)
		joints[f[0]] = _chain(root, f[2], f[3], glove)
	_build_thumb(glove)


func _chain(parent: Node3D, lengths: Array, radius: float, mat: Material) -> Array:
	var out: Array = []
	var node := parent
	for i in range(3):
		var j := Node3D.new()
		node.add_child(j)
		var r: float = radius * (1.0 - i * 0.07)
		var len: float = lengths[i]
		var seg := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = r
		cm.height = len + r * 1.4
		cm.radial_segments = 10
		cm.rings = 3
		seg.mesh = cm
		seg.material_override = mat
		seg.rotation = Vector3(PI / 2, 0, 0)
		seg.position = Vector3(0, 0, -len / 2.0)
		j.add_child(seg)
		out.append(j)
		if i > 0:
			var jb := MeshInstance3D.new()      # a small knuckle where this bone starts
			var sm := SphereMesh.new()
			sm.radius = r * 1.05
			sm.height = r * 2.1
			sm.radial_segments = 8
			sm.rings = 4
			jb.mesh = sm
			jb.material_override = mat
			j.add_child(jb)
		var next := Node3D.new()
		next.position = Vector3(0, 0, -len)
		j.add_child(next)
		if i == 2 and nail_mat != null:
			var nl := MeshInstance3D.new()          # a fingernail
			var nm := SphereMesh.new()
			nm.radius = r * 0.7
			nm.height = r * 1.4
			nm.radial_segments = 8
			nm.rings = 4
			nl.mesh = nm
			nl.material_override = nail_mat
			nl.scale = Vector3(1.0, 0.35, 1.5)
			nl.position = Vector3(0, r * 0.62, -len * 0.45)
			j.add_child(nl)
		node = next
	return out


func _build_thumb(mat: Material) -> void:
	var root := Node3D.new()
	root.position = Vector3(s * 0.006, 0.033, -0.012)
	root.rotation = Vector3(0, s * 0.35, 0)
	add_child(root)
	thumb = _chain(root, [0.032, 0.026, 0.0], 0.0108, mat)
	# the third bone of the thumb is only a tip; hide it by making it tiny
	thumb[2].scale = Vector3.ONE * 0.01


## open = 0, closed = 1
func set_pose(index_curl: float, grip_curl: float, thumb_curl: float) -> void:
	curl.index = clampf(index_curl, 0.0, 1.0)
	curl.grip = clampf(grip_curl, 0.0, 1.0)
	curl.thumb = clampf(thumb_curl, 0.0, 1.0)


func _process(delta: float) -> void:
	var k := 1.0 - exp(-delta * 22.0)
	for key in shown:
		shown[key] = lerpf(shown[key], curl[key], k)
	_apply()


func _flex(j: Node3D, angle: float) -> void:
	# curling rotates the finger toward the palm: about -Y on the left hand, +Y on the right hand
	j.basis = Basis(Vector3(0, -s, 0), angle)


func _apply() -> void:
	for f in FINGERS:
		var name: String = f[0]
		var c: float = shown.index if name == "index" else shown.grip
		var rest := 0.18 if name == "index" else 0.24 + float(FINGERS.find(f)) * 0.04
		var a: float = rest + c * (1.0 - rest) * 1.0
		var js: Array = joints[name]
		_flex(js[0], a * 1.30)
		_flex(js[1], a * 1.55)
		_flex(js[2], a * 1.05)
	var t: float = shown.thumb
	_flex(thumb[0], 0.15 + t * 0.55)
	_flex(thumb[1], 0.1 + t * 0.9)
