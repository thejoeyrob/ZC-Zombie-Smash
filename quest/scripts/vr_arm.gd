class_name VRArm
extends Node3D
## A forearm and upper arm in a retro windbreaker sleeve, joined by a two-bone solve between the shoulder and the wrist,
## so the hand is never left floating.

const UPPER := 0.30
const FORE := 0.29

var s := 1.0
var upper: MeshInstance3D
var fore: MeshInstance3D
var elbow_ball: MeshInstance3D
var cuff: MeshInstance3D
var cuff2: MeshInstance3D
var shoulder_ball: MeshInstance3D
var _sleeve: StandardMaterial3D


static func sleeve_texture() -> ImageTexture:
	var w := 128
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var teal := Color(0.08, 0.62, 0.7)
	var navy := Color(0.12, 0.1, 0.35)
	var pink := Color(1.0, 0.32, 0.62)
	var yellow := Color(1.0, 0.82, 0.2)
	var white := Color(0.95, 0.95, 0.98)
	for x in range(w):
		var u := float(x) / w
		var c := teal
		# colour-blocked: a wide navy panel on one side and three stripes where it meets the teal
		if u > 0.5 and u < 0.85:
			c = navy
		if absf(u - 0.5) < 0.012 or absf(u - 0.85) < 0.012:
			c = white
		if absf(u - 0.54) < 0.014 or absf(u - 0.81) < 0.014:
			c = pink
		if absf(u - 0.575) < 0.012 or absf(u - 0.78) < 0.012:
			c = yellow
		for y in range(h):
			var fine := 1.0 + 0.04 * sin(float(y) * 1.7 + float(x) * 0.9)         # the faint ripple of nylon
			img.set_pixel(x, y, Color(c.r * fine, c.g * fine, c.b * fine, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func build(side: int) -> void:
	s = 1.0 if side == 0 else -1.0
	_sleeve = VRBuild.tex_mat(sleeve_texture(), 0.0, 0.32)
	_sleeve.metallic = 0.12
	_sleeve.rim_enabled = true
	_sleeve.rim = 0.25
	_sleeve.texture_repeat = true
	var band := VRBuild.mat(Color(1.0, 0.32, 0.62), 0.5)
	upper = _tube(0.052, 0.046, _sleeve)
	fore = _tube(0.046, 0.039, _sleeve)
	cuff = _tube(0.041, 0.041, band)
	cuff2 = _tube(0.041, 0.041, VRBuild.mat(Color(0.95, 0.95, 0.98), 0.5))
	elbow_ball = _ball(0.047, _sleeve)
	shoulder_ball = _ball(0.054, _sleeve)


func _tube(r_top: float, r_bottom: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.radial_segments = 18
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	add_child(mi)
	return mi


func _ball(r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	add_child(mi)
	return mi


func _place(mi: MeshInstance3D, a: Vector3, b: Vector3, trim_start := 0.0, trim_end := 0.0) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return
	var dir := d / len
	var pa := a + dir * trim_start
	var pb := b - dir * trim_end
	var ref := Vector3.RIGHT if absf(dir.dot(Vector3.RIGHT)) < 0.9 else Vector3.UP
	var x := dir.cross(ref).normalized()
	var z := x.cross(dir).normalized()
	(mi.mesh as CylinderMesh).height = maxf(0.001, pa.distance_to(pb))
	mi.global_transform = Transform3D(Basis(x, dir, z), (pa + pb) / 2.0)


## shoulder and wrist in world space; `heading` is the player's yaw (so the elbow bends outward and down for them).
func update(shoulder: Vector3, wrist: Vector3, heading: Basis) -> void:
	var d := wrist - shoulder
	var dist := clampf(d.length(), 0.08, UPPER + FORE - 0.002)
	var dir := d.normalized()
	var reach := shoulder + dir * dist
	var a := (UPPER * UPPER - FORE * FORE + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(UPPER * UPPER - a * a, 0.0))
	var pole := heading * Vector3(-s * 0.55, -1.0, 0.35)
	pole = (pole - dir * pole.dot(dir)).normalized()
	var elbow := shoulder + dir * a + pole * h
	_place(upper, shoulder, elbow)
	_place(fore, elbow, wrist - dir * 0.0, 0.0, 0.0)
	_place(cuff, wrist - (wrist - elbow).normalized() * 0.03, wrist + (wrist - elbow).normalized() * 0.0)
	_place(cuff2, wrist - (wrist - elbow).normalized() * 0.042, wrist - (wrist - elbow).normalized() * 0.032)
	elbow_ball.global_position = elbow
	shoulder_ball.global_position = shoulder
	# the fore-arm tube must end at the wrist and start at the elbow: it was placed that way above
