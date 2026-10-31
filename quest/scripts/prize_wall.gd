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
	var wood := VRBuild.mat(Color(0.30, 0.16, 0.08), 0.55)
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
	var gold := VRBuild.mat(Color(0.85, 0.65, 0.2), 0.25, 0.9)
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
		# bobble head: a brass plinth, a spring and the boss on a springy neck
		VRBuild.cylinder(p.root, 0.11, 0.025, Vector3(0, 0.0125, 0), gold, 0.1)
		VRBuild.cylinder(p.root, 0.014, 0.1, Vector3(0, 0.075, 0), VRBuild.mat(Color(0.8, 0.8, 0.85), 0.2, 0.9))
		var head := Node3D.new()
		head.position = Vector3(0, 0.125, 0)
		p.root.add_child(head)
		p.head = head
		var tex: Texture2D = load("res://assets/art/" + boss.sprites[0])
		var mat := VRBuild.tex_mat(tex, 0.25, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.4
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		VRBuild.quad(head, Vector2(0.4, 0.4), Vector3(0, 0.2, 0), mat)
		VRBuild.label(p.root, str(boss.name), 0.05, Vector3(0, 0.012, 0.13), Color(1, 0.95, 0.8), Vector3(-0.6, 0, 0), 3)


func animate(delta: float) -> void:
	_t += delta
	for p in prizes:
		if p.head != null:
			var amp: float = 0.35 if p.held else 0.07
			p.head.rotation = Vector3(sin(_t * 2.1 + p.index) * amp * 0.5, 0.0, sin(_t * 2.7 + p.index * 1.3) * amp)


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
