class_name VRBuild
extends RefCounted
## Small helpers that build 3D shapes and materials in code (the whole room and cabinet are made this way).


static func mat(color: Color, rough := 0.7, metal := 0.0, emit := 0.0, emit_color := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = emit_color if emit_color.a > 0.0 else color
		m.emission_energy_multiplier = emit
	return m


static func unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func tex_mat(t: Texture2D, emit := 0.0, rough := 0.8, unshaded_mode := false, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.albedo_color = tint
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if unshaded_mode:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emit > 0.0:
		m.emission_enabled = true
		m.emission_texture = t
		m.emission_energy_multiplier = emit
	return m


static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, material: Material, top_radius := -1.0, rot := Vector3.ZERO, segments := 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func sphere(parent: Node, radius: float, pos: Vector3, material: Material, segments := 20) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segments
	sm.rings = segments / 2
	mi.mesh = sm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


## A picture frame that keeps its corners and stretches only its sides: the middle (the window) is left open.
## win_uv is the window's rectangle in picture fractions (x0, y0, x1, y1); outer and inner are sizes in metres, both centred on the origin.
static func frame9(parent: Node, tex: Texture2D, win_uv: Rect2, outer: Vector2, inner: Vector2, pos: Vector3, material: Material = null) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs := [-outer.x / 2.0, -inner.x / 2.0, inner.x / 2.0, outer.x / 2.0]
	var ys := [outer.y / 2.0, inner.y / 2.0, -inner.y / 2.0, -outer.y / 2.0]
	var us := [0.0, win_uv.position.x, win_uv.end.x, 1.0]
	var vs := [0.0, win_uv.position.y, win_uv.end.y, 1.0]
	for j in range(3):
		for i in range(3):
			if i == 1 and j == 1:
				continue
			var a := Vector3(xs[i], ys[j], 0)
			var b := Vector3(xs[i + 1], ys[j], 0)
			var c := Vector3(xs[i + 1], ys[j + 1], 0)
			var d := Vector3(xs[i], ys[j + 1], 0)
			var ua := Vector2(us[i], vs[j])
			var ub := Vector2(us[i + 1], vs[j])
			var uc := Vector2(us[i + 1], vs[j + 1])
			var ud := Vector2(us[i], vs[j + 1])
			for t in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
				st.set_normal(Vector3(0, 0, 1))
				st.set_uv(t[1])
				st.add_vertex(t[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material if material != null else tex_mat(tex, 0.25, 0.5)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func quad(parent: Node, size: Vector2, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func label(parent: Node, text: String, size: float, pos: Vector3, color: Color, rot := Vector3.ZERO, outline := 0, font: Font = null, emit := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = size / 64.0
	l.font_size = 64
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.double_sided = false
	l.shaded = false
	l.position = pos
	l.rotation = rot
	if font != null:
		l.font = font
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	parent.add_child(l)
	return l


## Extrudes a 2D polygon (given as (z, y) pairs) across x from -half..half; used for the cabinet sides.
static func side_panel(parent: Node, profile: PackedVector2Array, x: float, thickness: float, material: Material) -> MeshInstance3D:
	var idx := Geometry2D.triangulate_polygon(profile)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := x - thickness / 2.0
	var x1 := x + thickness / 2.0
	for face in [x0, x1]:
		for i in range(0, idx.size(), 3):
			var tri := [idx[i], idx[i + 1], idx[i + 2]]
			if face == x0:
				tri = [idx[i], idx[i + 2], idx[i + 1]]
			for k in tri:
				var p: Vector2 = profile[k]
				st.set_normal(Vector3(-1 if face == x0 else 1, 0, 0))
				st.set_uv(Vector2(p.x, p.y))
				st.add_vertex(Vector3(face, p.y, p.x))
	# the rim between the two faces
	for i in range(profile.size()):
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[(i + 1) % profile.size()]
		var n := Vector3(0, (b.x - a.x), -(b.y - a.y)).normalized()
		var va := Vector3(x0, a.y, a.x)
		var vb := Vector3(x0, b.y, b.x)
		var vc := Vector3(x1, b.y, b.x)
		var vd := Vector3(x1, a.y, a.x)
		for v in [va, vb, vc, va, vc, vd]:
			st.set_normal(n)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	parent.add_child(mi)
	return mi


## Bakes a node's plain mesh children into as few meshes as possible (one per distinct look), which keeps the draw-call count low
## on the headset. Children that must stay separate (moving parts, live screens) are marked with set_meta("dynamic", true).
static func merge_static(parent: Node) -> void:
	var groups := {}
	var doomed: Array = []
	for c in parent.get_children():
		if not (c is MeshInstance3D):
			continue
		var mi := c as MeshInstance3D
		if mi.mesh == null or mi.has_meta("dynamic") or mi.name == "ScreenQuad" or mi.mesh.get_surface_count() != 1:
			continue
		var m := mi.material_override as StandardMaterial3D
		if m == null:
			continue
		var sig := str([m.albedo_color, m.albedo_texture.get_instance_id() if m.albedo_texture != null else 0, m.roughness, m.metallic, m.emission_enabled, m.emission, m.emission_energy_multiplier,
			m.transparency, m.cull_mode, m.shading_mode, m.uv1_scale, m.uv1_offset, m.rim_enabled, m.blend_mode, m.alpha_scissor_threshold, m.texture_repeat])
		if not groups.has(sig):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[sig] = {"mat": m, "st": st}
		(groups[sig].st as SurfaceTool).append_from(mi.mesh, 0, mi.transform)
		doomed.append(mi)
	for d in doomed:
		parent.remove_child(d)
		d.queue_free()
	for sig in groups:
		var merged := MeshInstance3D.new()
		merged.mesh = (groups[sig].st as SurfaceTool).commit()
		merged.material_override = groups[sig].mat
		parent.add_child(merged)


## A flat shape (points as (z, y) in metres) turned into a slab, picture-mapped on its outer face. `uvs` are the picture coordinates of each point.
static func picture_slab(parent: Node, pts: PackedVector2Array, uvs: PackedVector2Array, x_centre: float, thickness: float, outward: float, picture: Material, plain: Material, flip_u := false) -> void:
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return
	var x_out := x_centre + outward * thickness / 2.0
	var x_in := x_centre - outward * thickness / 2.0
	var outer := SurfaceTool.new()
	outer.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rest := SurfaceTool.new()
	rest.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, idx.size(), 3):
		var tri := [idx[i], idx[i + 1], idx[i + 2]]
		var a: Vector2 = pts[tri[0]]
		var b: Vector2 = pts[tri[1]]
		var c: Vector2 = pts[tri[2]]
		# make the face point the way `outward` says
		var cr := (Vector3(x_out, b.y, b.x) - Vector3(x_out, a.y, a.x)).cross(Vector3(x_out, c.y, c.x) - Vector3(x_out, a.y, a.x))
		if cr.x * outward < 0.0:
			tri = [idx[i], idx[i + 2], idx[i + 1]]
		for k in tri:
			var p: Vector2 = pts[k]
			var uv: Vector2 = uvs[k]
			outer.set_normal(Vector3(outward, 0, 0))
			outer.set_uv(Vector2(1.0 - uv.x if flip_u else uv.x, uv.y))
			outer.add_vertex(Vector3(x_out, p.y, p.x))
		for k in [tri[0], tri[2], tri[1]]:
			var p2: Vector2 = pts[k]
			rest.set_normal(Vector3(-outward, 0, 0))
			rest.add_vertex(Vector3(x_in, p2.y, p2.x))
	for i in range(pts.size()):
		var a2: Vector2 = pts[i]
		var b2: Vector2 = pts[(i + 1) % pts.size()]
		for v in [Vector3(x_in, a2.y, a2.x), Vector3(x_out, a2.y, a2.x), Vector3(x_out, b2.y, b2.x), Vector3(x_in, a2.y, a2.x), Vector3(x_out, b2.y, b2.x), Vector3(x_in, b2.y, b2.x)]:
			rest.add_vertex(v)
	var m1 := MeshInstance3D.new()
	m1.mesh = outer.commit()
	m1.material_override = picture
	parent.add_child(m1)
	var m2 := MeshInstance3D.new()
	m2.mesh = rest.commit()
	m2.material_override = plain
	parent.add_child(m2)


## A seamless-ish arcade carpet: dark ground with neon confetti.
static func carpet_texture(seed_in := 4) -> ImageTexture:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.055, 0.045, 0.13))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_in
	var cols := [Color(0.05, 0.75, 0.8), Color(0.9, 0.2, 0.65), Color(0.95, 0.75, 0.15), Color(0.35, 0.3, 0.95), Color(0.2, 0.85, 0.4)]
	for i in range(70):
		var c: Color = cols[rng.randi() % cols.size()]
		c = c.darkened(0.25)
		var x := rng.randi_range(0, s - 1)
		var y := rng.randi_range(0, s - 1)
		var kind := rng.randi() % 3
		var r := rng.randi_range(3, 8)
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var inside := false
				if kind == 0:
					inside = dx * dx + dy * dy <= r * r
				elif kind == 1:
					inside = absi(dx) + absi(dy) <= r
				else:
					inside = absi(dy) <= 1 and absi(dx) <= r * 2
				if inside:
					img.set_pixel(posmod(x + dx, s), posmod(y + dy, s), c)
	var t := ImageTexture.create_from_image(img)
	return t


static func grid_texture(c1: Color, c2: Color, cells := 8) -> ImageTexture:
	var s := cells * 8
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for x in range(s):
		for y in range(s):
			img.set_pixel(x, y, c1 if ((x / 8) + (y / 8)) % 2 == 0 else c2)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A flat, speckled, slightly embossed paint finish for a control panel (no pictures): fine grain plus a soft diamond-plate pattern.
static func panel_texture(base: Color, seed_in := 3) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_in
	for y in range(n):
		for x in range(n):
			var g := (rng.randf() - 0.5) * 0.07                  # fine grain
			# a diamond pattern repeating every 16 px, very low contrast
			var u := float(x % 16) / 16.0
			var v := float(y % 16) / 16.0
			var d := absf(u - 0.5) + absf(v - 0.5)
			var emboss := 0.035 * (1.0 - smoothstep(0.18, 0.34, d)) - 0.012
			var c := base
			var k := 1.0 + g + emboss
			img.set_pixel(x, y, Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1), 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Scanline overlay for the monitor glass (transparent, darkens every other line a little).
static func scanline_texture() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for y in range(4):
		for x in range(4):
			img.set_pixel(x, y, Color(0, 0, 0, 0.0 if y % 2 == 0 else 0.08))
	return ImageTexture.create_from_image(img)

## A real neon tube: a round glass tube with a hot white core, a soft glow around it, and dark mounting clips along its length.
## It runs along local X from the given centre. Rotate the parent (or pass rot) to point it anywhere.
static func neon_tube(parent: Node, length: float, pos: Vector3, color: Color, rot := Vector3.ZERO, standoff := 0.03) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation = rot
	parent.add_child(root)
	var axis := Vector3(0, 0, PI / 2)          # cylinders stand up by default; lay them along X
	var glass := CylinderMesh.new()
	glass.top_radius = 0.014
	glass.bottom_radius = 0.014
	glass.height = length
	glass.radial_segments = 12
	glass.rings = 1
	var gm := StandardMaterial3D.new()
	gm.albedo_color = color
	gm.emission_enabled = true
	gm.emission = color
	gm.emission_energy_multiplier = 2.4
	gm.roughness = 0.15
	var gi := MeshInstance3D.new()
	gi.mesh = glass
	gi.material_override = gm
	gi.rotation = axis
	root.add_child(gi)
	var core := CylinderMesh.new()               # the hot white line down the middle of the glass
	core.top_radius = 0.0055
	core.bottom_radius = 0.0055
	core.height = length
	core.radial_segments = 8
	core.rings = 1
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(1, 1, 1)
	cm.emission_enabled = true
	cm.emission = color.lerp(Color(1, 1, 1), 0.75)
	cm.emission_energy_multiplier = 3.5
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ci := MeshInstance3D.new()
	ci.mesh = core
	ci.material_override = cm
	ci.rotation = axis
	root.add_child(ci)
	var halo := CylinderMesh.new()               # soft glow around the tube (additive, no hard edge)
	halo.top_radius = 0.055
	halo.bottom_radius = 0.055
	halo.height = length
	halo.radial_segments = 10
	halo.rings = 1
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_color = Color(color.r * 0.16, color.g * 0.16, color.b * 0.16, 1.0)
	hm.cull_mode = BaseMaterial3D.CULL_FRONT
	var hi := MeshInstance3D.new()
	hi.mesh = halo
	hi.material_override = hm
	hi.rotation = axis
	hi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(hi)
	var clip_m := mat(Color(0.03, 0.03, 0.035), 0.4, 0.6)    # dark metal clips holding the tube off the wall
	var n := int(maxf(2.0, ceilf(length / 1.2)))
	for i in range(n + 1):
		var x := -length / 2.0 + length * float(i) / float(n)
		box(root, Vector3(0.025, 0.012, 0.012), Vector3(x, 0, 0.0), clip_m)
		box(root, Vector3(0.016, 0.016, standoff), Vector3(x, 0, -standoff / 2.0), clip_m)
	return root

## A realistic surface from a photographed material set: colour, normal (bumps) and roughness pictures called pbr-<name>-c/n/r in the art folder
## (plus -m for metal where the material has one). tint multiplies the colour; uv is how many times it repeats across a unit quad.
static func pbr(name: String, tint := Color.WHITE, uv := Vector2.ONE, normal_scale := 1.0, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var c = load("res://assets/art/pbr-%s-c.jpg" % name)
	var n = load("res://assets/art/pbr-%s-n.png" % name)
	var r = load("res://assets/art/pbr-%s-r.jpg" % name)
	var mt = load("res://assets/art/pbr-%s-m.jpg" % name) if ResourceLoader.exists("res://assets/art/pbr-%s-m.jpg" % name) else null
	if c != null:
		m.albedo_texture = c
	m.albedo_color = tint
	if n != null:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = normal_scale
	if r != null:
		m.roughness_texture = r
		m.roughness = 1.0
	else:
		m.roughness = 0.7
	if mt != null:
		m.metallic_texture = mt
		m.metallic = 1.0
	else:
		m.metallic = metallic
	m.uv1_scale = Vector3(uv.x, uv.y, 1)
	m.texture_repeat = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

