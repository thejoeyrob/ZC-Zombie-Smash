class_name ModelMachine
extends Node3D
## A display arcade machine built from the red cabinet model (arcade-model.fbx): the same classic upright shape for every variation,
## with the artwork, trim colour and button colours swapped. These stand in the room for atmosphere; the playable machines are Cabinet.
## Local +z is the front (where the player stands); the deck's front lip is at z = +0.30, like Cabinet.

const MODEL := "res://assets/art/arcade-model.fbx"
const SX := 0.00310       # the model is in centimetres: 0.01 turns it into metres, then it is slimmed to a 0.66 m wide cabinet
const SY := 0.00382       # and 1.85 m tall
const SZ := 0.00382
const RAW_Y_MIN := -101.14
const RAW_Z_LIP := 191.0

var screen_mat: StandardMaterial3D


## o: {side: Texture2D, marquee: Texture2D, screen: Texture2D, trim: Color, btn_a/btn_b/btn_c: Color, mirror_right: bool, panel: Color}
func build(o: Dictionary) -> void:
	var ps = load(MODEL)
	if ps == null:
		return
	var inst: Node3D = ps.instantiate()
	var found := inst.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		return
	var src: ArrayMesh = (found[0] as MeshInstance3D).mesh
	var mesh := ArrayMesh.new()
	for s in range(src.get_surface_count()):
		var arr := src.surface_get_arrays(s)
		if s == 0:
			arr[Mesh.ARRAY_TEX_UV] = _side_uv(arr, bool(o.get("mirror_right", true)))
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(s, _material(s, o))
	inst.free()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3(SX, SY, SZ)
	mi.position = Vector3(0, -RAW_Y_MIN * SY, 0.30 - RAW_Z_LIP * SZ)
	add_child(mi)
	var light := OmniLight3D.new()           # a little of the screen's glow on the floor and the player
	light.position = Vector3(0, 1.1, 0.5)
	light.light_color = o.get("trim", Color(1, 1, 1))
	light.light_energy = 0.35
	light.omni_range = 1.4
	add_child(light)


static func _side_uv(arr: Array, mirror_right: bool) -> PackedVector2Array:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var lo := v[0]
	var hi := v[0]
	for p in v:
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	var uv := PackedVector2Array()
	for p in v:
		var u := (p.z - lo.z) / maxf(hi.z - lo.z, 0.001)
		if p.x > 0.0 and mirror_right:
			u = 1.0 - u
		uv.append(Vector2(u, 1.0 - (p.y - lo.y) / maxf(hi.y - lo.y, 0.001)))
	return uv


func _material(s: int, o: Dictionary) -> Material:
	var trim: Color = o.get("trim", Color(0.6, 0.1, 0.1))
	match s:
		0:
			var t = o.get("side")
			var m: StandardMaterial3D
			if t != null:
				m = VRBuild.tex_mat(t, 0.1, 0.55)
			else:
				m = VRBuild.mat(trim.darkened(0.4), 0.5, 0.1)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			return m
		1:
			return VRBuild.mat(Color(0.05, 0.05, 0.06), 0.35, 0.8)
		2:
			var c: Color = o.get("btn_a", Color(0.9, 0.12, 0.1))
			return VRBuild.mat(c, 0.15, 0.1, 0.5, c)
		3:
			var c2: Color = o.get("btn_b", Color(0.1, 0.4, 0.95))
			return VRBuild.mat(c2, 0.15, 0.1, 0.5, c2)
		4:
			var c3: Color = o.get("btn_c", Color(1.0, 0.8, 0.05))
			return VRBuild.mat(c3, 0.15, 0.1, 0.5, c3)
		5:
			return VRBuild.pbr("metal", Color(1, 1, 1), Vector2(1, 1), 0.8)
		6:
			var sm := StandardMaterial3D.new()
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var st = o.get("screen")
			if st != null:
				sm.albedo_texture = st
			sm.albedo_color = Color(1.3, 1.3, 1.3) if st != null else Color(0.02, 0.02, 0.04)
			sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			screen_mat = sm
			return sm
		7:
			return VRBuild.mat(Color(0.015, 0.015, 0.02), 0.25, 0.1)
		8:
			var mt = o.get("marquee")
			if mt != null:
				var mm := VRBuild.tex_mat(mt, 1.0, 0.5, true)
				mm.cull_mode = BaseMaterial3D.CULL_DISABLED
				return mm
			return VRBuild.mat(trim, 0.4, 0.0, 1.2, trim)
		9:
			return VRBuild.pbr("plate-blue", Color(0.22, 0.22, 0.28), Vector2(1, 2), 0.9)
		10:
			return VRBuild.pbr("plate-blue", Color(0.34, 0.34, 0.42), Vector2(1, 1), 0.9)
		11:
			return VRBuild.pbr("leather-black", Color(1.4, 1.4, 1.4), Vector2(1.6, 1.0), 1.0)
		12:
			return VRBuild.mat(trim, 0.3, 0.3, 0.5, trim)
	return VRBuild.pbr("metal", Color(0.8, 0.8, 0.8), Vector2(1, 1), 0.8)
