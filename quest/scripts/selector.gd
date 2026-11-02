class_name Selector
extends Node3D
## Pointing at things in the room. What you can use lights up: a soft pulsing glow round it, the thing itself dims a touch,
## and one pulsing word floats over it. Pull the trigger to choose it. Pointing at open floor shows where you would land.
## Nothing is drawn in the room until you point at it.

var targets: Array = []        # {id, label, xf: Transform3D, box: AABB, colour: Color, spot: Array}
var hover := -1
var shown := true
var forced := -1               # development: show the glow without a pointer
var floor_pos := Vector3.ZERO
var floor_ok := false
var accessible := Callable()   # func(point: Vector3) -> bool, true where a person may stand

var _glow: MeshInstance3D
var _glow_mat: ShaderMaterial
var _edges: Array = []
var _edge_mat: StandardMaterial3D
var _floor_glow: MeshInstance3D
var _floor_mat: StandardMaterial3D
var _dim: MeshInstance3D
var _word: Label3D
var _beam: MeshInstance3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _t := 0.0

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec4 colour : source_color = vec4(1.0, 0.3, 0.8, 1.0);
uniform float pulse = 1.0;
void fragment() {
	float f = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.6);
	ALBEDO = colour.rgb * (0.35 + f * 1.4) * pulse;
	ALPHA = clamp((0.16 + f) * pulse, 0.0, 1.0);
}
"""


func build(root: Node3D, list: Array, font: Font) -> void:
	targets = list
	root.add_child(self)
	var sh := Shader.new()
	sh.code = SHADER
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = sh
	_glow = MeshInstance3D.new()
	_glow.mesh = BoxMesh.new()
	_glow.material_override = _glow_mat
	_glow.visible = false
	add_child(_glow)
	# bright glowing edges round the whole thing
	_edge_mat = StandardMaterial3D.new()
	_edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_edge_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_edge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_edge_mat.no_depth_test = true
	for k in range(12):
		var e := MeshInstance3D.new()
		e.mesh = BoxMesh.new()
		e.material_override = _edge_mat
		e.visible = false
		add_child(e)
		_edges.append(e)
	# a soft pool of the same colour on the floor under it
	var gt := GradientTexture2D.new()
	var gg := Gradient.new()
	gg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	gg.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gt.gradient = gg
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_floor_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_floor_mat.albedo_texture = gt
	_floor_glow = MeshInstance3D.new()
	_floor_glow.mesh = QuadMesh.new()
	_floor_glow.material_override = _floor_mat
	_floor_glow.visible = false
	add_child(_floor_glow)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0, 0, 0, 0.3)
	dm.render_priority = -1
	_dim = MeshInstance3D.new()
	_dim.mesh = BoxMesh.new()
	_dim.material_override = dm
	_dim.visible = false
	add_child(_dim)
	_word = VRBuild.label(self, "PLAY", 0.14, Vector3.ZERO, Color(1, 1, 1), Vector3.ZERO, 8, font)
	_word.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_word.double_sided = true
	_word.no_depth_test = true
	_word.render_priority = 5
	_word.visible = false
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


func set_shown(on: bool) -> void:
	shown = on
	if not on:
		_clear()


func _clear() -> void:
	hover = -1
	floor_ok = false
	_glow.visible = false
	_dim.visible = false
	_word.visible = false
	_beam.visible = false
	_ring.visible = false
	for e in _edges:
		e.visible = false
	_floor_glow.visible = false


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
	_glow.visible = false
	_dim.visible = false
	_word.visible = false
	for e in _edges:
		e.visible = false
	_floor_glow.visible = false
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


func _show_target(t: Dictionary) -> void:
	var box: AABB = t.box
	var xf: Transform3D = t.xf
	var c: Color = t.colour
	var centre := xf * box.get_center()
	for pair in [[_glow, 0.07], [_dim, 0.005]]:
		var mi: MeshInstance3D = pair[0]
		(mi.mesh as BoxMesh).size = box.size + Vector3.ONE * float(pair[1])
		mi.global_transform = Transform3D(xf.basis, centre)
		mi.visible = true
	_glow_mat.set_shader_parameter("colour", c)
	_edge_mat.albedo_color = Color(c.r, c.g, c.b, 1.0)
	_floor_mat.albedo_color = Color(c.r, c.g, c.b, 0.9)
	(_floor_glow.mesh as QuadMesh).size = Vector2(maxf(box.size.x, box.size.z) + 1.4, maxf(box.size.x, box.size.z) + 1.4)
	_floor_glow.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3((xf * box.get_center()).x, 0.02, (xf * box.get_center()).z))
	_floor_glow.visible = true
	var sz := box.size + Vector3.ONE * 0.05
	var th := 0.02
	var corners: Array = []
	for ax in [-1.0, 1.0]:
		for ay in [-1.0, 1.0]:
			for az in [-1.0, 1.0]:
				corners.append(Vector3(ax, ay, az))
	var idx := 0
	for axis in range(3):               # four bars along each axis
		for a in [-1.0, 1.0]:
			for b2 in [-1.0, 1.0]:
				var e: MeshInstance3D = _edges[idx]
				idx += 1
				var size := Vector3(th, th, th)
				var local := box.get_center()
				size[axis] = sz[axis]
				var o1 := (axis + 1) % 3
				var o2 := (axis + 2) % 3
				local[o1] += a * sz[o1] / 2.0
				local[o2] += b2 * sz[o2] / 2.0
				(e.mesh as BoxMesh).size = size
				e.global_transform = Transform3D(xf.basis, xf * local)
				e.visible = true
	_word.text = str(t.label)
	_word.modulate = Color(1, 1, 1)
	_word.global_position = xf * (box.get_center() + Vector3(0, box.size.y / 2.0, 0)) + Vector3(0, 0.3, 0)
	_word.visible = true


func _process(delta: float) -> void:
	_t += delta
	var p := 0.75 + 0.25 * sin(_t * 4.0)
	_glow_mat.set_shader_parameter("pulse", p)
	_edge_mat.albedo_color.a = 0.55 + 0.45 * sin(_t * 4.0)
	_floor_mat.albedo_color.a = 0.45 + 0.3 * sin(_t * 4.0)
	_word.modulate.a = 0.6 + 0.4 * sin(_t * 4.0)
	_word.scale = Vector3.ONE * (1.0 + 0.06 * sin(_t * 4.0))
	_ring_mat.albedo_color.a = 0.6 + 0.35 * sin(_t * 5.0)
