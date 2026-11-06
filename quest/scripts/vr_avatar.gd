class_name VRAvatar
extends Node3D
## A player avatar: two skinned, textured humans (Microsoft Rocketbox, MIT) and a set of stylised outfits built from simple shapes. It is driven by the head and
## two hands. The stylised body is built like this:  Arms reach from the shoulders to the hands with two-bone inverse kinematics (shoulders lean toward a reaching hand); the torso
## follows the head with a lag and leans when you bow or crouch; the legs hang from the hips and the feet are planted on the floor, stepping
## when you walk or turn on the spot and folding when you sit. It sits at the world origin; every position it is given is a world position.
## Looks are data (SKINS): clothes, colours, hair or hat. In your own view the head is hidden (it sits on render layer 2, which your camera skips).

const SKINS := [
	{"id": "human_m01", "name": "ALEX — REALISTIC", "tone": "#d9a07a", "top": "#53603c", "trim": "#c9a24a", "bottom": "#2d3d5a", "shoes": "#3a2c22", "glove": "#26262a", "style": "jacket", "hat": "cap", "hat_col": "#b3262a", "hair": "#2a1c12", "gloves": false},
	{"id": "human_f02", "name": "MORGAN — REALISTIC", "tone": "#d9a07a", "top": "#53603c", "trim": "#c9a24a", "bottom": "#2d3d5a", "shoes": "#3a2c22", "glove": "#26262a", "style": "jacket", "hat": "cap", "hat_col": "#b3262a", "hair": "#2a1c12", "gloves": false},
	{"id": "survivor", "name": "SURVIVOR", "tone": "#d9a07a", "top": "#53603c", "trim": "#c9a24a", "bottom": "#2d3d5a", "shoes": "#3a2c22", "glove": "#26262a", "style": "jacket", "hat": "cap", "hat_col": "#b3262a", "hair": "#2a1c12", "gloves": true},
	{"id": "arcadekid", "name": "ARCADE KID", "tone": "#f0c09a", "top": "#ff3d9a", "trim": "#27e0ff", "bottom": "#1b1f3a", "shoes": "#f2f2f4", "glove": "#f0c09a", "style": "tee", "hat": "phones", "hat_col": "#27e0ff", "hair": "#ffcc33", "gloves": false},
	{"id": "raver", "name": "NEON RAVER", "tone": "#8a5a3c", "top": "#101018", "trim": "#27ffd0", "bottom": "#101018", "shoes": "#0c0c12", "glove": "#101018", "style": "suit", "hat": "visor", "hat_col": "#27ffd0", "hair": "#101018", "gloves": true, "glow": true},
	{"id": "hazmat", "name": "HAZMAT", "tone": "#d9a07a", "top": "#f2c31b", "trim": "#2a2a2a", "bottom": "#f2c31b", "shoes": "#222222", "glove": "#2f8f3a", "style": "suit", "hat": "bubble", "hat_col": "#9fd8ff", "hair": "#3a2a1a", "gloves": true},
	{"id": "hunter", "name": "ZOMBIE HUNTER", "tone": "#c58b6a", "top": "#2c3036", "trim": "#8d9199", "bottom": "#3b3f33", "shoes": "#17171a", "glove": "#151517", "style": "vest", "hat": "helmet", "hat_col": "#3c4a33", "hair": "#2a1c12", "gloves": true},
	{"id": "crew", "name": "FATTY'S CREW", "tone": "#e2b08a", "top": "#1fa24a", "trim": "#f2f2f2", "bottom": "#23242b", "shoes": "#f2f2f2", "glove": "#e2b08a", "style": "hoodie", "hat": "hood", "hat_col": "#1fa24a", "hair": "#4a2c18", "gloves": false},
	{"id": "disco", "name": "DISCO FEVER", "tone": "#7a4a30", "top": "#7a2bd6", "trim": "#ffd23f", "bottom": "#7a2bd6", "shoes": "#ffd23f", "glove": "#f2f2f2", "style": "suit", "hat": "afro", "hat_col": "#1a1210", "hair": "#1a1210", "gloves": true},
	{"id": "zombie", "name": "ZOMBIE", "tone": "#8fb56a", "top": "#5a4a52", "trim": "#3a2f35", "bottom": "#3a4252", "shoes": "#2a2420", "glove": "#8fb56a", "style": "tee", "hat": "none", "hat_col": "#5a4a52", "hair": "#3a3a2a", "gloves": false, "eyes": "#ff3a2a"},
	{"id": "robot", "name": "CHROME BOT", "tone": "#b9c0c8", "top": "#aeb6c0", "trim": "#27a8ff", "bottom": "#8d949e", "shoes": "#5f656e", "glove": "#aeb6c0", "style": "suit", "hat": "robot", "hat_col": "#aeb6c0", "hair": "#aeb6c0", "gloves": true, "metal": true, "eyes": "#27a8ff"},
]

const L_UPPER := 0.29
const L_FORE := 0.26
const L_THIGH := 0.44
const L_SHIN := 0.42
const ANKLE := 0.075
const SPINE := 0.5
const HEAD_LAYER := 2

var tracked_fingers: Array = [{}, {}]
var human: HumanRig
var hand_poses: Array = []
var finger_curls: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var self_view := false             # your own avatar: the head is hidden from your camera
var scale_k := 1.0                 # body size relative to a 1.75 m person
var skin_id := ""
var show_body := "full"            # full / arms / hands
var body_yaw := 0.0
var wrists := [Vector3.ZERO, Vector3.ZERO]
var feet := [Vector3.ZERO, Vector3.ZERO]
var _foot_from := [Vector3.ZERO, Vector3.ZERO]
var _foot_to := [Vector3.ZERO, Vector3.ZERO]
var _foot_t := [1.0, 1.0]
var _last_pelvis := Vector3.ZERO
var _vel := Vector3.ZERO
var _inited := false
var _t := 0.0

var _mats := {}
var _head: Node3D
var _hat_root: Node3D
var _chest: Node3D
var _detail: Node3D
var _hips: Node3D
var _neck: MeshInstance3D
var _spine: Array = []
var _arm_segs: Array = []          # per side: [upper, fore, elbow ball, shoulder ball]
var _leg_segs: Array = []          # per side: [thigh, shin, knee ball, foot node]
var _mitts: Array = []             # simple hands for avatars that are not you (your own hands are the finger-tracked VRHand)
var _body_nodes: Array = []        # everything that is hidden in "arms" and "hands" views
var _skin := {}


static func skin_index(id: String) -> int:
	for i in range(SKINS.size()):
		if SKINS[i].id == id:
			return i
	return 0


func build(for_self: bool) -> void:
	self_view = for_self
	_head = Node3D.new()
	add_child(_head)
	_hat_root = Node3D.new()
	_head.add_child(_hat_root)
	_chest = Node3D.new()
	add_child(_chest)
	_detail = Node3D.new()
	_chest.add_child(_detail)
	_hips = Node3D.new()
	add_child(_hips)
	_neck = _seg(0.058, 0.05)
	_spine = [_seg(0.135, 0.17), _seg(0.17, 0.2)]
	for side in range(2):
		_arm_segs.append([_seg(0.05, 0.041), _seg(0.041, 0.029), _ball(0.045), _ball(0.062)])
		_leg_segs.append([_seg(0.098, 0.07), _seg(0.068, 0.05), _ball(0.07), Node3D.new()])
		add_child(_leg_segs[side][3])
		var mitt := Node3D.new()
		add_child(mitt)
		_mitts.append(mitt)
	apply_skin(SKINS[0].id)


# ---- looks ----------------------------------------------------------------------------------------------
func _mat(c: Color, rough := 0.7, metal := 0.0, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.rim_enabled = true               # a soft edge light so the dark clothes still read in the dark arcade
	m.rim = 0.25
	m.rim_tint = 0.5
	return m


func apply_skin(id: String) -> void:
	var i := skin_index(id)
	_skin = SKINS[i]
	skin_id = _skin.id
	var metal: bool = _skin.get("metal", false)
	var glow: bool = _skin.get("glow", false)
	_mats = {
		"tone": _mat(Color(_skin.tone), 0.55 if not metal else 0.25, 0.9 if metal else 0.0),
		"top": _mat(Color(_skin.top), 0.75 if not metal else 0.3, 0.85 if metal else 0.0),
		"trim": _mat(Color(_skin.trim), 0.5, 0.0, 2.2 if (glow or metal) else 0.0),
		"bottom": _mat(Color(_skin.bottom), 0.8 if not metal else 0.35, 0.8 if metal else 0.0),
		"shoes": _mat(Color(_skin.shoes), 0.6, 0.6 if metal else 0.0),
		"hair": _mat(Color(_skin.hair), 0.9),
		"hat": _mat(Color(_skin.hat_col), 0.6, 0.5 if metal else 0.0),
		"white": _mat(Color(0.96, 0.96, 0.96), 0.4),
		"dark": _mat(Color(0.03, 0.03, 0.04), 0.35),
		"eye": _mat(Color(_skin.get("eyes", "#101014")), 0.3, 0.0, 3.0 if _skin.has("eyes") else 0.0),
		"glass": _mat(Color(_skin.hat_col), 0.05, 0.0, 0.0, 0.28),
		"visor": _mat(Color(_skin.hat_col), 0.2, 0.0, 3.0),
		"glove": _mat(Color(_skin.glove), 0.8),
	}
	var long_sleeves: bool = _skin.style != "tee"
	for side in range(2):
		var a: Array = _arm_segs[side]
		a[0].material_override = _mats.top
		a[1].material_override = _mats.top if long_sleeves else _mats.tone
		a[2].material_override = a[1].material_override
		a[3].material_override = _mats.top
		var l: Array = _leg_segs[side]
		l[0].material_override = _mats.bottom
		l[1].material_override = _mats.bottom
		l[2].material_override = _mats.bottom
	_neck.material_override = _mats.tone
	_spine[0].material_override = _mats.bottom if _skin.style != "suit" else _mats.top
	_spine[1].material_override = _mats.top
	_build_head()
	_build_torso()
	_build_feet()
	for side in range(2):
		var mitt: Node3D = _mitts[side]
		_clear(mitt)
		var hm: Material = _mats.glove if _skin.gloves else _mats.tone
		_sph(mitt, 0.04, hm, Vector3(0, 0, -0.05), Vector3(0.95, 0.5, 1.25))
		_sph(mitt, 0.017, hm, Vector3(0.03 * (1.0 if side == 0 else -1.0), 0.005, -0.045), Vector3(1.0, 0.9, 1.5))
		_cyl(mitt, 0.04, 0.04, 0.018, _mats.trim, Vector3(0, 0, 0.015), Vector3(PI / 2, 0, 0))
		mitt.visible = not self_view
	_apply_layers()
	if human != null:
		remove_child(human)
		human.queue_free()
		human = null
	if id.begins_with("human_"):
		var candidate := HumanRig.new()
		add_child(candidate)
		if candidate.build(id, self_view):
			human = candidate
		else:
			remove_child(candidate)
			candidate.queue_free()
			push_warning("Realistic avatar assets incomplete: run quest/tools/fetch-human-assets.py before building")
	if human == null:
		set_body_mode(show_body)                    # a stylised outfit: show its shapes again (a human skin had hidden them)
		for side in range(2):
			(_mitts[side] as Node3D).visible = not self_view
	_refresh_human_visibility()


func hand_look() -> Dictionary:
	return {"glove": Color(_skin.glove), "gloves": _skin.gloves, "cuff": Color(_skin.trim), "tone": Color(_skin.tone)}


func _clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()
		n.remove_child(c)


func _mesh(parent: Node, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.scale = scl
	m.rotation = rot
	parent.add_child(m)
	return m


func _sph(parent: Node, r: float, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 7
	return _mesh(parent, s, mat, pos, scl)


func _box(parent: Node, size: Vector3, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, b, mat, pos, Vector3.ONE, rot)


func _cyl(parent: Node, r0: float, r1: float, h: float, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = r0
	c.top_radius = r1
	c.height = h
	c.radial_segments = 16
	c.rings = 1
	return _mesh(parent, c, mat, pos, Vector3.ONE, rot)


func _seg(r0: float, r1: float) -> MeshInstance3D:
	var m := _cyl(self, r0, r1, 1.0, null)
	_body_nodes.append(m)
	return m


func _ball(r: float) -> MeshInstance3D:
	var m := _sph(self, r, null)
	_body_nodes.append(m)
	return m


func _build_head() -> void:
	_clear(_head)
	_hat_root = Node3D.new()
	_head.add_child(_hat_root)
	var t: Material = _mats.tone
	_sph(_head, 0.095, t, Vector3.ZERO, Vector3(1.0, 1.12, 1.06))                      # skull
	for sx in [-1.0, 1.0]:
		_sph(_head, 0.022, t, Vector3(sx * 0.093, -0.005, 0.0), Vector3(0.5, 1.0, 0.8))      # ears
		_sph(_head, 0.019, _mats.white, Vector3(sx * 0.035, 0.022, -0.082), Vector3(1.0, 1.1, 0.55))   # eyes
		_sph(_head, 0.0105, _mats.eye, Vector3(sx * 0.035, 0.022, -0.0925), Vector3(1, 1, 0.5))
		_box(_head, Vector3(0.04, 0.007, 0.01), _mats.hair, Vector3(sx * 0.036, 0.05, -0.086), Vector3(0, 0, sx * -0.12))   # brows
	_sph(_head, 0.016, t, Vector3(0, -0.012, -0.098), Vector3(1, 0.9, 1))               # nose
	_box(_head, Vector3(0.042, 0.007, 0.01), _mats.dark, Vector3(0, -0.05, -0.086))     # mouth
	_box(_head, Vector3(0.01, 0.01, 0.01), _mats.dark, Vector3(-0.024, -0.047, -0.086), Vector3(0, 0, 0.6))
	_box(_head, Vector3(0.01, 0.01, 0.01), _mats.dark, Vector3(0.024, -0.047, -0.086), Vector3(0, 0, -0.6))
	var hat: String = _skin.hat
	var hair_ok := hat in ["none", "cap", "phones", "visor", "hood"]
	if hair_ok and _skin.id != "zombie":
		_sph(_hat_root, 0.1, _mats.hair, Vector3(0, 0.022, 0.018), Vector3(1.0, 0.92, 1.0))
	if _skin.id == "zombie":
		_sph(_hat_root, 0.1, _mats.hair, Vector3(0, 0.05, 0.03), Vector3(0.9, 0.5, 0.9))        # a few thin tufts
	match hat:
		"cap":
			_sph(_hat_root, 0.1, _mats.hat, Vector3(0, 0.04, 0.005), Vector3(1.0, 0.75, 1.05))
			_cyl(_hat_root, 0.1, 0.1, 0.008, _mats.hat, Vector3(0, 0.035, -0.09), Vector3(0.1, 0, 0)).scale = Vector3(1.0, 1.0, 0.55)
		"phones":
			_cyl(_hat_root, 0.032, 0.032, 0.03, _mats.hat, Vector3(-0.1, 0, 0), Vector3(0, 0, PI / 2))
			_cyl(_hat_root, 0.032, 0.032, 0.03, _mats.hat, Vector3(0.1, 0, 0), Vector3(0, 0, PI / 2))
			var band := TorusMesh.new()
			band.inner_radius = 0.1
			band.outer_radius = 0.108
			_mesh(_hat_root, band, _mats.hat, Vector3(0, 0.0, 0.0), Vector3(1.0, 1.0, 1.0), Vector3(0, 0, 0)).rotation = Vector3(PI / 2, 0, PI / 2)
		"visor":
			_box(_hat_root, Vector3(0.2, 0.05, 0.02), _mats.visor, Vector3(0, 0.022, -0.09))
			_box(_hat_root, Vector3(0.002, 0.002, 0.002), _mats.dark)
		"hood":
			_sph(_hat_root, 0.118, _mats.hat, Vector3(0, 0.01, 0.03), Vector3(1.0, 1.0, 1.0))
			_sph(_hat_root, 0.075, _mats.tone, Vector3(0, -0.005, -0.045), Vector3(1.05, 1.18, 0.7))
		"helmet":
			_sph(_hat_root, 0.108, _mats.hat, Vector3(0, 0.03, 0.012), Vector3(1.0, 0.92, 1.05))
			_box(_hat_root, Vector3(0.13, 0.02, 0.03), _mats.dark, Vector3(0, 0.085, -0.1))
			_box(_hat_root, Vector3(0.03, 0.02, 0.13), _mats.trim, Vector3(0, 0.133, 0.0))
		"bubble":
			_sph(_hat_root, 0.135, _mats.glass, Vector3(0, 0.0, 0.0), Vector3(1.0, 1.05, 1.0))
			_cyl(_hat_root, 0.12, 0.12, 0.04, _mats.trim, Vector3(0, -0.13, 0.02))
		"afro":
			_sph(_hat_root, 0.15, _mats.hat, Vector3(0, 0.055, 0.035), Vector3(1.0, 0.95, 1.0))
		"robot":
			_sph(_hat_root, 0.102, _mats.hat, Vector3(0, 0.005, 0.01), Vector3(1.0, 1.1, 1.06))
			_cyl(_hat_root, 0.006, 0.006, 0.1, _mats.hat, Vector3(0.05, 0.19, 0.0))
			_sph(_hat_root, 0.014, _mats.trim, Vector3(0.05, 0.245, 0.0))
			_box(_hat_root, Vector3(0.15, 0.04, 0.02), _mats.eye, Vector3(0, 0.022, -0.1))


func _build_torso() -> void:
	_clear(_detail)
	var body: Material = _mats.top
	_sph(_detail, 0.16, body, Vector3(0, 0.0, 0.0), Vector3(1.22, 1.0, 0.82))         # chest and shoulders
	_sph(_detail, 0.15, _mats.top, Vector3(0, -0.12, 0.0), Vector3(1.05, 0.9, 0.72))
	var st: String = _skin.style
	match st:
		"jacket":
			_box(_detail, Vector3(0.012, 0.3, 0.012), _mats.trim, Vector3(0, -0.03, -0.1))        # zip
			for sx in [-1.0, 1.0]:
				_box(_detail, Vector3(0.07, 0.07, 0.02), _mats.dark, Vector3(sx * 0.1, -0.15, -0.092), Vector3(0, sx * 0.2, 0))   # pockets
			_cyl(_detail, 0.075, 0.07, 0.05, _mats.top, Vector3(0, 0.15, 0.0))                    # collar
		"hoodie":
			_cyl(_detail, 0.08, 0.075, 0.06, _mats.top, Vector3(0, 0.15, 0.0))
			_box(_detail, Vector3(0.17, 0.07, 0.02), _mats.dark, Vector3(0, -0.14, -0.094))       # pouch
			_box(_detail, Vector3(0.006, 0.05, 0.006), _mats.white, Vector3(-0.03, 0.08, -0.105))  # drawstrings
			_box(_detail, Vector3(0.006, 0.05, 0.006), _mats.white, Vector3(0.03, 0.08, -0.105))
		"vest":
			_box(_detail, Vector3(0.27, 0.3, 0.17), _mats.hat, Vector3(0, -0.02, 0.0))             # plate carrier
			for px in [-0.08, 0.0, 0.08]:
				_box(_detail, Vector3(0.07, 0.09, 0.04), _mats.trim, Vector3(px, -0.1, -0.1))      # pouches
			_box(_detail, Vector3(0.11, 0.07, 0.03), _mats.dark, Vector3(0, 0.07, -0.098))
		"suit":
			_cyl(_detail, 0.07, 0.06, 0.05, _mats.trim, Vector3(0, 0.15, 0.0))
			_box(_detail, Vector3(0.02, 0.32, 0.01), _mats.trim, Vector3(0, -0.03, -0.1))
			for sx in [-1.0, 1.0]:
				_box(_detail, Vector3(0.01, 0.3, 0.006), _mats.trim, Vector3(sx * 0.14, -0.04, -0.07))
		"tee":
			_box(_detail, Vector3(0.1, 0.1, 0.01), _mats.trim, Vector3(0, -0.02, -0.103))         # a print on the front
	_box(_detail, Vector3(0.22, 0.04, 0.15), _mats.dark, Vector3(0, -0.25, 0.0))                  # belt


func _build_feet() -> void:
	for side in range(2):
		var f: Node3D = _leg_segs[side][3]
		_clear(f)
		_body_nodes.erase(f)
		_box(f, Vector3(0.095, 0.06, 0.17), _mats.shoes, Vector3(0, 0.0, -0.045))
		_sph(f, 0.049, _mats.shoes, Vector3(0, -0.002, -0.115), Vector3(1, 0.62, 1.0))
		_box(f, Vector3(0.1, 0.014, 0.19), _mats.white if _skin.id in ["arcadekid", "crew"] else _mats.dark, Vector3(0, -0.033, -0.05))
		_body_nodes.append(f)


func _apply_layers() -> void:
	# head parts live on layer 2 so that your own camera does not draw them (the world and the other avatars draw them on layer 1)
	var layer := 1 << (HEAD_LAYER - 1) if self_view else 1
	for n in [_head, _neck]:
		for c in (n.find_children("*", "VisualInstance3D", true, false) + ([n] if n is VisualInstance3D else [])):
			(c as VisualInstance3D).layers = layer
	set_body_mode(show_body)


func set_body_mode(mode: String) -> void:
	show_body = mode
	for n in _body_nodes:
		(n as Node3D).visible = mode == "full" or (mode == "arms" and (n in _arm_segs[0] or n in _arm_segs[1]))
	_chest.visible = mode == "full"
	_head.visible = mode == "full" or not self_view
	_neck.visible = mode == "full"
	_refresh_human_visibility()


# ---- movement ---------------------------------------------------------------------------------------------
func _place(m: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := maxf(d.length(), 0.001)
	var y := d / l
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	m.transform = Transform3D(Basis(x * scale_k, y * l, z * scale_k), (a + b) * 0.5)


func _place_ball(m: Node3D, p: Vector3) -> void:
	m.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_k), p)


## Two-bone reach: the middle joint (elbow or knee) for a limb from root to target, bending toward the pole direction.
static func _bend(root: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var d := target - root
	var dist := d.length()
	var reach := l1 + l2
	var s := 1.0
	if dist > reach * 0.999:
		s = minf(dist / (reach * 0.999), 1.35)      # the limb stretches a little so the hand never comes loose from the arm
	var a := l1 * s
	var b := l2 * s
	dist = minf(dist, a + b - 0.001)
	var dir := d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var cosv := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var along := a * cosv
	var h := sqrt(maxf(a * a - along * along, 0.0))
	var side := pole - dir * pole.dot(dir)
	side = side.normalized() if side.length() > 0.0001 else Vector3.UP
	return [root + dir * along + side * h, target]


## head: the headset's world transform; wrist_pos: where each wrist is (or null); active: whether that hand is tracked.
func update(head: Transform3D, wrist_pos: Array, active: Array, delta: float, seated := false) -> void:
	_t += delta
	var k := scale_k
	var hb := head.basis
	# --- the body's heading: it follows the head with a lag, never more than 50 degrees behind ---
	var fwd := -hb.z
	if fwd.y < -0.8:
		fwd = hb.y                                              # looking straight down: use the top of the head instead
	fwd.y = 0.0
	var head_yaw := body_yaw if fwd.length() < 0.05 else atan2(-fwd.x, -fwd.z)
	if not _inited:
		body_yaw = head_yaw
	var diff := wrapf(head_yaw - body_yaw, -PI, PI)
	var speed := _vel.length()
	var follow := 1.0 - exp(-delta * (7.0 if speed > 0.25 else 2.5))
	if absf(diff) > deg_to_rad(28.0) or speed > 0.25:
		body_yaw += diff * follow
	diff = wrapf(head_yaw - body_yaw, -PI, PI)
	diff = wrapf(head_yaw - body_yaw, -PI, PI)
	if absf(diff) > deg_to_rad(50.0):
		body_yaw += diff - signf(diff) * deg_to_rad(50.0)
	var bb := Basis(Vector3.UP, body_yaw)
	# --- the head and neck ---
	var eye := head.origin
	_head.transform = Transform3D(hb.scaled(Vector3.ONE * k * 1.1), eye + hb * Vector3(0, -0.02, 0.085) * k)
	var neck_base := eye + Basis(Vector3.UP, body_yaw) * Vector3(0, -0.2, 0.1) * k
	var neck_top := _head.position + hb * Vector3(0, -0.09, 0.0) * k
	_place(_neck, neck_base + Vector3(0, 0.03, 0) * k, neck_top)
	# --- the spine: leans forward when you look down or crouch ---
	var pitch_down := clampf(asin(clampf(-(-hb.z).y, -1.0, 1.0)), 0.0, 1.2) if (-hb.z).y < 0.0 else 0.0
	var lean := clampf(pitch_down * 0.3, 0.0, 0.6)
	var spine_len := SPINE * k
	var min_pelvis := 0.34 * k if not seated else 0.5 * k
	if neck_base.y - min_pelvis < spine_len:
		lean = maxf(lean, acos(clampf((neck_base.y - min_pelvis) / spine_len, 0.0, 1.0)))
	var up_s := Vector3.UP * cos(lean) + (-bb.z) * sin(lean)
	var pelvis := neck_base - up_s * spine_len
	if seated:
		pelvis.y = maxf(pelvis.y, 0.0)
	var chest_c := neck_base - up_s * 0.2 * k
	var waist_c := neck_base - up_s * 0.36 * k
	var cb := Basis(Vector3.UP, lerp_angle(body_yaw, head_yaw, 0.4))
	var chest_basis := Basis(cb.x, up_s, cb.x.cross(up_s)).orthonormalized().scaled(Vector3.ONE * k)
	_chest.transform = Transform3D(chest_basis, chest_c)
	_place(_spine[0], pelvis, waist_c)
	_place(_spine[1], waist_c, chest_c + up_s * 0.02 * k)
	# --- legs ---
	var flat := Vector3(pelvis.x, 0.0, pelvis.z)
	if not _inited:
		_last_pelvis = flat
		for s in range(2):
			feet[s] = flat + bb * Vector3((-0.1 if s == 0 else 0.1) * k, 0, 0)
			_foot_from[s] = feet[s]
			_foot_to[s] = feet[s]
		_inited = true
	var vnow := (flat - _last_pelvis) / maxf(delta, 0.0001)
	_vel = _vel.lerp(vnow, 1.0 - exp(-delta * 8.0))
	_last_pelvis = flat
	for s in range(2):
		var sgn := -1.0 if s == 0 else 1.0
		var home := flat + bb * Vector3(sgn * 0.1 * k, 0, 0)
		if seated:
			home = flat + bb * Vector3(sgn * 0.12 * k, 0, -0.38 * k)
		var other := 1 - s
		var lead := _vel * 0.22
		lead.y = 0.0
		if _foot_t[s] >= 1.0:
			var away: float = (feet[s] - (home + lead)).length()
			if away > 0.26 * k and _foot_t[other] >= 1.0 or away > 0.5 * k:
				_foot_from[s] = feet[s]
				_foot_to[s] = home + lead * 1.3
				_foot_t[s] = 0.0
		if _foot_t[s] < 1.0:
			var dur := clampf(0.42 - _vel.length() * 0.1, 0.22, 0.45)
			_foot_t[s] = minf(_foot_t[s] + delta / dur, 1.0)
			var e := smoothstep(0.0, 1.0, _foot_t[s])
			feet[s] = (_foot_from[s] as Vector3).lerp(_foot_to[s], e)
			feet[s].y = sin(_foot_t[s] * PI) * 0.09 * k
		else:
			feet[s].y = 0.0
		var hip: Vector3 = pelvis + bb * Vector3(sgn * 0.09 * k, -0.04 * k, 0)
		var ankle: Vector3 = (feet[s] as Vector3) + Vector3(0, ANKLE * k, 0)
		var foot_yaw := body_yaw
		var pole: Vector3 = bb * Vector3(sgn * 0.15, 0.25, -1.0)
		var kn: Array = _bend(hip, ankle, L_THIGH * k, L_SHIN * k, pole)
		var legs: Array = _leg_segs[s]
		_place(legs[0], hip, kn[0])
		_place(legs[1], kn[0], kn[1])
		_place_ball(legs[2], kn[0])
		var fn: Node3D = legs[3]
		fn.transform = Transform3D(Basis(Vector3.UP, foot_yaw).scaled(Vector3.ONE * k), kn[1] + Vector3(0, -0.02 * k, 0))
	# --- arms ---
	for s in range(2):
		var sgn := -1.0 if s == 0 else 1.0
		var sh: Vector3 = chest_c + chest_basis * Vector3(sgn * 0.185, 0.14, 0.0)
		var want: Vector3
		if active[s] and wrist_pos[s] != null:
			want = wrist_pos[s]
		else:
			want = sh + bb * Vector3(sgn * 0.1, -(L_UPPER + L_FORE) * k * 0.97, -0.05 * k)      # arms hang when the hand is not tracked
		wrists[s] = want if self_view or not _inited else (wrists[s] as Vector3).lerp(want, 1.0 - exp(-delta * 20.0))
		var to_hand: Vector3 = (wrists[s] as Vector3) - sh
		sh += to_hand.normalized() * clampf(to_hand.length() - 0.3 * k, 0.0, 0.25 * k) * 0.22          # the shoulder shrugs toward a reaching hand
		var pole: Vector3 = bb * Vector3(sgn * 0.6, -0.85, 0.45)
		var el: Array = _bend(sh, wrists[s], L_UPPER * k, L_FORE * k, pole)
		var arm: Array = _arm_segs[s]
		_place(arm[0], sh, el[0])
		_place(arm[1], el[0], wrists[s])
		_place_ball(arm[2], el[0])
		_place_ball(arm[3], sh)
		var dirf: Vector3 = ((wrists[s] as Vector3) - (el[0] as Vector3)).normalized()
		var zax: Vector3 = -dirf
		var xax: Vector3 = Vector3.UP.cross(zax).normalized() if absf(dirf.y) < 0.95 else Vector3.RIGHT
		var yax: Vector3 = zax.cross(xax)
		(_mitts[s] as Node3D).transform = Transform3D(Basis(xax, yax, zax).scaled(Vector3.ONE * k), wrists[s])

	if human != null:
		human.tracked_fingers = tracked_fingers
		human.hand_poses = hand_poses
		human.finger_curls = finger_curls
		human.pose(head, wrists, feet, active, body_yaw, scale_k)


## A relaxed standing pose, for the preview on the skin machine and the tests.
func pose_idle(root: Vector3, yaw: float, delta: float) -> void:
	var eye_h := 1.62 * scale_k
	var b := Basis(Vector3.UP, yaw)
	var sway := sin(_t * 1.1) * 0.012
	var head := Transform3D(b * Basis(Vector3.RIGHT, 0.04 + sin(_t * 0.7) * 0.02), root + Vector3(sway, eye_h, 0))
	var wave := maxf(sin(_t * 0.5), 0.0)
	var rw: Vector3 = root + b * Vector3(0.27 + wave * 0.1, 0.95 * scale_k + wave * 0.5, -0.12 - wave * 0.15)
	var lw: Vector3 = root + b * Vector3(-0.27, 0.92 * scale_k, -0.08)
	update(head, [lw, rw], [true, true], delta, false)


func _refresh_human_visibility() -> void:
	if human == null:
		return
	for child in get_children():
		if child is Node3D and child != human:
			child.visible = false
	human.set_body_mode(show_body)
