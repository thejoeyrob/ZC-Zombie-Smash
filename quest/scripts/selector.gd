class_name Selector
extends Node3D
## Pointing at things in the room. No boxes or glows: machines, the pinball table and the bean bags carry a small pulsing word
## (PLAY, SIT) over them all the time, and the one you point at gets brighter and bigger. The exit door shows EXIT when pointed at.
## Pull the trigger to choose it. Pointing at open floor shows a ring where you would land.

var targets: Array = []        # {id, label, xf: Transform3D, box: AABB, colour: Color, spot: Array}
var hover := -1
var shown := true
var forced := -1               # development: show the glow without a pointer
var floor_pos := Vector3.ZERO
var floor_ok := false
var accessible := Callable()   # func(point: Vector3) -> bool, true where a person may stand

var _word: Label3D
var _hints: Dictionary = {}     # target index -> its always-on pulsing word
var _beam: MeshInstance3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _t := 0.0

func build(root: Node3D, list: Array, font: Font) -> void:
	targets = list
	root.add_child(self)
	_word = VRBuild.label(self, "PLAY", 0.14, Vector3.ZERO, Color(1, 1, 1), Vector3.ZERO, 8, font)
	_word.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_word.double_sided = true
	_word.no_depth_test = true
	_word.render_priority = 5
	_word.visible = false
	for i in range(targets.size()):
		if bool(targets[i].get("always", false)):
			var h := VRBuild.label(self, str(targets[i].label), 0.1, Vector3.ZERO, Color(1, 1, 1), Vector3.ZERO, 8, font)
			h.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			h.double_sided = true
			h.render_priority = 4
			h.visible = false
			h.global_position = _word_pos(targets[i])
			_hints[i] = h
	# the beam from the hand and the ring that shows where a move would land
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0035
	cm.bottom_radius = 0.0035
	cm.height = 1.0
	cm.radial_segments = 6
	_beam.mesh = cm
	_beam.material_override = VRBuild.mat(Color(0.8, 0.9, 1.0), 0.5, 0.0, 2.5)
	_beam.visible = false
	add_child(_beam)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.2
	tm.outer_radius = 0.24
	tm.rings = 40
	tm.ring_segments = 8
	_ring.mesh = tm
	_ring.scale = Vector3(1, 0.08, 1)
	_ring_mat = VRBuild.mat(Color(0.3, 0.95, 1.0), 0.4, 0.0, 3.0)
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = _ring_mat
	_ring.visible = false
	add_child(_ring)


func relabel(id: String, text: String) -> void:
	for i in range(targets.size()):
		if str(targets[i].id) == id:
			targets[i].label = text
			if _hints.has(i):
				(_hints[i] as Label3D).text = text


func set_shown(on: bool) -> void:
	shown = on
	if not on:
		_clear()


func _clear() -> void:
	hover = -1
	floor_ok = false
	_word.visible = false
	_beam.visible = false
	_ring.visible = false
	for h in _hints.values():
		h.visible = false


## Index of the target a ray (world) hits, or -1. Also reports whether it hits one particular target.
func ray_hits(origin: Vector3, dir: Vector3, i: int) -> bool:
	return _hit_dist(origin, dir, targets[i]) >= 0.0


func _hit_dist(origin: Vector3, dir: Vector3, t: Dictionary) -> float:
	var inv: Transform3D = (t.xf as Transform3D).affine_inverse()
	var lo: Vector3 = inv * origin
	var ld: Vector3 = (inv.basis * dir).normalized()
	var hit = (t.box as AABB).intersects_ray(lo, ld)
	if hit == null:
		return -1.0
	return lo.distance_to(hit)


## Points a ray at the room. Lights up what it hits and returns its index; over open floor it shows the landing ring instead.
func aim(origin: Vector3, dir: Vector3) -> int:
	if not shown:
		_clear()
		return -1
	var best := -1
	var best_d := 12.0
	if forced >= 0:
		best = forced
	else:
		for i in range(targets.size()):
			var d := _hit_dist(origin, dir, targets[i])
			if d >= 0.0 and d < best_d:
				best_d = d
				best = i
	hover = best
	floor_ok = false
	_ring.visible = false
	if hover >= 0:
		_show_target(targets[hover])
		_beam.visible = forced < 0
		if forced < 0:
			_set_beam(origin, origin + dir.normalized() * best_d, targets[hover].colour)
		return hover
	_word.visible = false
	if dir.y > -0.03:
		_beam.visible = false
		return -1
	var dist := -origin.y / dir.y
	if dist < 0.3 or dist > 9.0:
		_beam.visible = false
		return -1
	var p := origin + dir * dist
	p.y = 0.0
	floor_pos = p
	floor_ok = accessible.is_valid() and bool(accessible.call(p))
	_set_beam(origin, Vector3(p.x, 0.0, p.z), Color(0.35, 0.95, 1.0) if floor_ok else Color(0.7, 0.7, 0.8))
	_beam.visible = true
	_ring.visible = floor_ok
	_ring.global_position = p + Vector3(0, 0.02, 0)
	return -1


func _set_beam(a: Vector3, b: Vector3, col: Color) -> void:
	var length := a.distance_to(b)
	if length < 0.05:
		_beam.visible = false
		return
	_beam.global_position = (a + b) / 2.0
	_beam.global_transform.basis = Basis.looking_at((b - a).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI / 2)
	_beam.scale = Vector3(1, length, 1)
	var m := _beam.material_override as StandardMaterial3D
	m.albedo_color = col
	m.emission = col


func _word_pos(t: Dictionary) -> Vector3:
	var box: AABB = t.box
	var xf: Transform3D = t.xf
	return xf * (box.get_center() + Vector3(0, box.size.y / 2.0, 0)) + Vector3(0, 0.25, 0)


func _show_target(t: Dictionary) -> void:
	if hover >= 0 and _hints.has(hover):
		_word.visible = false           # the always-on word is already there; it just gets brighter
		return
	_word.text = str(t.label)
	_word.global_position = _word_pos(t)
	_word.visible = true


func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 3.2)
	_word.modulate.a = 0.6 + 0.4 * sin(_t * 4.0)
	_word.scale = Vector3.ONE * (1.0 + 0.06 * sin(_t * 4.0))
	for i in _hints:
		var h: Label3D = _hints[i]
		h.visible = shown and h.text != ""
		var on: bool = (i == hover)
		h.modulate = Color(1, 1, 1, 1.0) if on else Color(1, 1, 1, 0.35 + 0.4 * pulse)
		h.scale = Vector3.ONE * (1.35 if on else 1.0 + 0.05 * pulse)
	_ring_mat.albedo_color.a = 0.6 + 0.35 * sin(_t * 5.0)
