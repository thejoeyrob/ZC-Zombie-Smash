class_name PrizeWall
extends Node3D
## The prize shelves: seven boxes, one per boss, in stage order. A box stays a mystery until that many bosses have
## been beaten, then it opens into a bobble head of the boss. Prizes can be picked up, turned over and are put back on release.

const REACH := 0.15

var prizes: Array = []           # [{root, head, index, home, unlocked, held, back}]
var holding := [-1, -1]
var offsets := [Transform3D.IDENTITY, Transform3D.IDENTITY]
var prev_grip := [false, false]
var unlocked_count := 0
var _t := 0.0
signal grabbed(index: int, unlocked: bool)
signal dropped(index: int)
signal opened(index: int)


func build(root: Node3D, pos: Vector3, yaw: float, font: Font) -> void:
	position = pos
	rotation.y = yaw
	root.add_child(self)
	var wood := VRBuild.mat(Color(0.26, 0.12, 0.36), 0.55)
	var dark := VRBuild.mat(Color(0.05, 0.03, 0.09), 0.8)
	var glow := VRBuild.mat(Color(1.0, 0.35, 0.75), 0.4, 0.0, 2.4)
	# the cabinet: back board, side posts, two shelves, neon trim and a sign
	VRBuild.box(self, Vector3(3.1, 1.6, 0.06), Vector3(0, 1.58, -0.05), dark)
	for sx in [-1.6, 1.6]:
		VRBuild.box(self, Vector3(0.1, 1.9, 0.4), Vector3(sx, 1.0, 0.1), wood)
	VRBuild.box(self, Vector3(3.3, 0.08, 0.42), Vector3(0, 2.4, 0.1), wood)
	for y in [1.15, 1.7]:
		VRBuild.box(self, Vector3(3.1, 0.05, 0.38), Vector3(0, y, 0.12), wood)
		VRBuild.box(self, Vector3(3.1, 0.015, 0.015), Vector3(0, y - 0.005, 0.315), glow)
	VRBuild.box(self, Vector3(3.1, 0.02, 0.02), Vector3(0, 2.36, 0.3), glow)
	VRBuild.label(self, "PRIZES", 0.3, Vector3(0, 2.62, 0.0), Color(1.0, 0.35, 0.75), Vector3.ZERO, 12, font)
	VRBuild.label(self, "BEAT A BOSS TO OPEN THE NEXT BOX", 0.075, Vector3(0, 2.46, 0.32), Color(1, 0.95, 0.8, 0.9), Vector3.ZERO, 3, font)
	var spots: Array = []
	for i in range(4):
		spots.append(Vector3(-1.05 + i * 0.7, 1.175, 0.2))
	for i in range(3):
		spots.append(Vector3(-0.7 + i * 0.7, 1.725, 0.2))
	var n := mini(ZSEngine.BOSSES.size(), spots.size())
	for i in range(n):
		var holder := Node3D.new()
		holder.position = spots[i]
		add_child(holder)
		prizes.append({"root": holder, "index": i, "unlocked": false, "held": false, "back": null, "head": null, "home": holder.transform})
	set_unlocked(0, true)


func set_unlocked(count: int, quiet := false) -> void:
	var before := unlocked_count
	unlocked_count = count
	for p in prizes:
		var open: bool = p.index < count
		if p.root.get_child_count() == 0 or p.unlocked != open:
			_fill(p, open)
			if open and not quiet and p.index >= before:
				opened.emit(p.index)


func _fill(p: Dictionary, open: bool) -> void:
	for c in p.root.get_children():
		c.queue_free()
	p.unlocked = open
	p.head = null
	var boss: Dictionary = ZSEngine.BOSSES[p.index]
	var gold := VRBuild.mat(Color(0.85, 0.65, 0.2), 0.25, 0.5, 0.2, Color(0.85, 0.65, 0.2))
	if not open:
		var box := Node3D.new()
		p.root.add_child(box)
		var wrap = load("res://assets/art/box-wrap.jpg")
		var face = load("res://assets/art/box-mystery.jpg")
		var top := VRBuild.tex_mat(wrap, 0.2, 0.4) if wrap != null else VRBuild.mat(Color(0.5, 0.1, 0.6), 0.4)
		var front := VRBuild.tex_mat(face, 0.35, 0.4) if face != null else VRBuild.mat(Color(0.5, 0.1, 0.6), 0.4)
		# six faces, so the picture sits whole on each side
		for rot in [0.0, PI / 2, PI, -PI / 2]:
			var holder := Node3D.new()
			holder.rotation.y = rot
			box.add_child(holder)
			VRBuild.quad(holder, Vector2(0.26, 0.26), Vector3(0, 0.15, 0.13), front)
		VRBuild.quad(box, Vector2(0.26, 0.26), Vector3(0, 0.28, 0), top, Vector3(-PI / 2, 0, 0))
		VRBuild.box(box, Vector3(0.25, 0.01, 0.25), Vector3(0, 0.02, 0), top)
		VRBuild.label(p.root, "STAGE %d" % (p.index + 1), 0.045, Vector3(0, 0.012, 0.13), Color(1, 0.9, 0.6, 0.9), Vector3(-0.6, 0, 0), 3)
	else:
		# a solid figure standing on its own feet; its head and shoulders wobble like a bobble head
		var mesh = load("res://assets/art/bobble-%s.obj" % boss.id)
		var atlas = load("res://assets/art/bobble-%s-atlas.jpg" % boss.id)
		if mesh != null and atlas != null:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = _bobble_material(atlas, _widths(str(boss.id)))
			var fig := Node3D.new()
			p.root.add_child(fig)
			fig.add_child(mi)
			p.head = fig
			p.mat = mi.material_override
		else:
			VRBuild.label(p.root, "?", 0.1, Vector3(0, 0.15, 0), Color.WHITE)
		VRBuild.label(p.root, str(boss.name), 0.05, Vector3(0, 0.012, 0.13), Color(1, 0.95, 0.8), Vector3(-0.6, 0, 0), 3)


static var _shader: Shader


## The figure is textured by blending its front, side and back pictures by the direction each bit of surface faces.
func _bobble_material(atlas: Texture2D, widths: Vector3) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 widths;        // widths in pixels of the front, side and back pictures
uniform float picture_h = 480.0;
uniform float figure_h = 0.357;
uniform float amp = 0.0;
uniform float swing = 0.0;
varying vec3 mpos;
varying vec3 mnrm;
void vertex() {
	mpos = VERTEX;
	mnrm = NORMAL;
	float h = clamp((VERTEX.y - 0.12) / 0.24, 0.0, 1.0);
	VERTEX.x += swing * h * h * amp;
	VERTEX.z += swing * 0.6 * h * h * amp;
}
void fragment() {
	float aw = widths.x + widths.y + widths.z;
	float k = picture_h / figure_h;
	float v = 1.0 - clamp(mpos.y / figure_h, 0.0, 1.0);
	vec2 uf = vec2((widths.x * 0.5 + mpos.x * k) / aw, v);
	vec2 ub = vec2((widths.x + widths.y + widths.z * 0.5 - mpos.x * k) / aw, v);
	float sz = mpos.z * k;
	vec2 us = vec2((widths.x + widths.y * 0.5 + (mnrm.x < 0.0 ? sz : -sz)) / aw, v);
	uf.x = clamp(uf.x, 0.001, widths.x / aw - 0.001);
	ub.x = clamp(ub.x, (widths.x + widths.y) / aw + 0.001, 0.999);
	us.x = clamp(us.x, widths.x / aw + 0.001, (widths.x + widths.y) / aw - 0.001);
	vec3 n = normalize(mnrm);
	float wf = pow(max(n.z, 0.0), 3.0);
	float wb = pow(max(-n.z, 0.0), 3.0);
	float ws = pow(abs(n.x), 3.0);
	float sum = wf + wb + ws + 0.0001;
	vec3 col = (texture(atlas, uf).rgb * wf + texture(atlas, ub).rgb * wb + texture(atlas, us).rgb * ws) / sum;
	ALBEDO = col;
	ROUGHNESS = 0.6;
	EMISSION = col * 0.12;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("atlas", atlas)
	m.set_shader_parameter("widths", widths)
	return m


func _widths(id: String) -> Vector3:
	var f := FileAccess.open("res://assets/art/bobble-%s-atlas.json" % id, FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			var w: Array = d.widths
			return Vector3(float(w[0]), float(w[1]), float(w[2]))
	return Vector3(265, 260, 240)


func animate(delta: float) -> void:
	_t += delta
	for p in prizes:
		if p.head != null and p.get("mat") != null:
			var held: bool = p.held
			var amp := 0.035 if held else 0.012
			p.mat.set_shader_parameter("amp", amp)
			p.mat.set_shader_parameter("swing", sin(_t * (6.0 if held else 2.3) + p.index) )


## hs: per hand {grab: bool, xf: Transform3D (the hand as drawn), point: Vector3 (palm position)}
func update(hs: Array) -> void:
	for i in range(2):
		var h: Dictionary = hs[i]
		if holding[i] == -1:
			if h.grab and not prev_grip[i]:
				var best := -1
				var best_d := REACH
				for p in prizes:
					if p.held:
						continue
					var d: float = (p.root.global_position + Vector3(0, 0.14, 0)).distance_to(h.point)
					if d < best_d:
						best_d = d
						best = p.index
				if best >= 0:
					var p: Dictionary = prizes[best]
					p.held = true
					holding[i] = best
					offsets[i] = h.xf.affine_inverse() * p.root.global_transform
					grabbed.emit(best, p.unlocked)
		else:
			var p: Dictionary = prizes[holding[i]]
			if h.grab:
				p.root.global_transform = h.xf * offsets[i]
			else:
				holding[i] = -1
				var home: Transform3D = p.home
				var tw := create_tween()
				tw.tween_property(p.root, "transform", home, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_callback(func(): p.held = false)
				dropped.emit(p.index)
		prev_grip[i] = h.grab
