class_name ShackRenovation
extends RefCounted
## Deliberate architectural zones. Existing photograph-based PBR materials and
## character artwork; no new realtime lights or reflection cameras.
static var _oak: StandardMaterial3D


## The one oak used for the lower walls and the ceiling beams everywhere, so the wood is the same colour and grain size on every surface: it is mapped in space
## (triplanar, a repeat about every 1.25 m) instead of being stretched over each box separately.
static func oak() -> StandardMaterial3D:
	if _oak == null:
		_oak = VRBuild.pbr("oakslat", Color(0.66, 0.5, 0.35), Vector2.ONE, 0.4)
		_oak.uv1_triplanar = true
		_oak.uv1_scale = Vector3(0.8, 0.8, 0.8)
		_oak.texture_repeat = true
	return _oak


## The same oak with the picture laid out by the beam's own length (grain along the beam, a repeat about every 1.25 m), for the ceiling beams.
static var _beam_oak: StandardMaterial3D


static func beam_oak() -> StandardMaterial3D:
	if _beam_oak == null:
		_beam_oak = VRBuild.pbr("oakslat", Color(0.62, 0.49, 0.37), Vector2.ONE, 0.4)
		_beam_oak.texture_repeat = true
	return _beam_oak


## A beam running along x: `size` is (length, height, depth). Its picture runs the length of the beam on all four long faces, so every beam shows the same grain.
static func beam(parent: Node3D, size: Vector3, pos: Vector3) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x / 2.0
	var hy := size.y / 2.0
	var hz := size.z / 2.0
	var k := 1.0 / 1.25
	# each face: four corners, the normal, and which two sizes the picture follows (u across, v along the beam)
	var faces := [
		[Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz), Vector3.UP, "z"],
		[Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz), Vector3.DOWN, "z"],
		[Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz), Vector3.BACK, "y"],
		[Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz), Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3.FORWARD, "y"],
		[Vector3(-hx, hy, -hz), Vector3(-hx, hy, hz), Vector3(-hx, -hy, hz), Vector3(-hx, -hy, -hz), Vector3.LEFT, "end"],
		[Vector3(hx, hy, hz), Vector3(hx, hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), Vector3.RIGHT, "end"],
	]
	for f in faces:
		var corners: Array = [f[0], f[1], f[2], f[3]]
		var uvs: Array = []
		for p in corners:
			var v: Vector3 = p
			match str(f[5]):
				"z":
					uvs.append(Vector2((v.z + hz) * k, (v.x + hx) * k))
				"y":
					uvs.append(Vector2((v.y + hy) * k, (v.x + hx) * k))
				_:
					uvs.append(Vector2((v.z + hz) * k, (v.y + hy) * k))
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(f[4])
			st.set_uv(uvs[idx])
			st.add_vertex(corners[idx])
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = beam_oak()
	mi.position = pos
	parent.add_child(mi)
	return mi


## Oak panelling from the floor to 94 cm with a slim brass cap, on a wall piece `width` wide whose centre is at `centre` (x) in the holder's space; the holder's +z
## points into the room. Used for every wall of the arcade and the hall.
static func wainscot(parent: Node3D, width: float, centre: float) -> void:
	var metal := VRBuild.pbr("metal", Color(0.65, 0.48, 0.25), Vector2(2, 1), 0.25, 0.7)
	VRBuild.box(parent, Vector3(width, 0.94, 0.045), Vector3(centre, 0.47, 0.032), oak())
	VRBuild.box(parent, Vector3(width, 0.03, 0.062), Vector3(centre, 0.955, 0.04), metal)


static func build(root: Node3D, font: Font) -> void:
	var oak := oak()
	var metal := VRBuild.pbr("metal", Color(0.65,0.48,0.25),Vector2(2,1),0.25,0.7)
	# Textured coffer beams give the ceiling scale and depth without extra lights.
	for z in [0.8,2.8,4.8,6.8,9.0,12.0,15.0,18.0,20.6]:
		beam(root,Vector3(7.9,0.12,0.16),Vector3(0,3.22,z))
		VRBuild.box(root,Vector3(7.6,0.012,0.035),Vector3(0,3.153,z),metal)
	gallery(root)
	# Inlaid wayfinding instead of floating instructions.
	for entry in [["ARCADE  /  LOUNGE",Vector3(0,0.022,1.1)],["SPORTS CLUB",Vector3(0,0.022,8.0)]]:
		var plaque := Node3D.new();root.add_child(plaque);plaque.position=entry[1];plaque.rotation.x=-PI/2
		VRBuild.box(plaque,Vector3(1.6,0.28,0.012),Vector3.ZERO,metal)
		VRBuild.label(plaque,entry[0],0.10,Vector3(0,0,0.008),Color(0.06,0.05,0.03),Vector3.ZERO,0,font)

## The best artwork we have, standing proud of the walls of both rooms with a glow behind each in the picture's own colour.
## [file, wall, position along the wall (z for the side walls, x for the back wall of the arcade), centre height, picture height, glow]
const WALL_L := -3.96
const WALL_R := 3.96
const GALLERY := [
	# the arcade, above the machines
	["battle-jordan.jpg", "L", 1.3, 2.55, 0.95, Color(1.0, 0.5, 0.12)],
	["battle-discoman.jpg", "L", 3.2, 2.55, 0.95, Color(1.0, 0.2, 0.8)],
	["battle-drmantis.jpg", "L", 4.6, 2.55, 0.95, Color(0.25, 1.0, 0.45)],
	["battle-debo.jpg", "R", 1.3, 2.55, 0.95, Color(1.0, 0.7, 0.15)],
	["battle-fatamy.jpg", "R", 3.2, 2.55, 0.95, Color(1.0, 0.45, 0.25)],
	["battle-glowinghumanity.jpg", "R", 5.1, 2.55, 0.95, Color(0.6, 1.0, 0.2)],
	["battle-caffeinatedsloth.jpg", "R", 6.7, 2.55, 0.95, Color(1.0, 0.6, 0.15)],
	["poster-neon.jpg", "B", -3.2, 2.2, 1.35, Color(0.6, 0.3, 1.0)],
	["poster-disco.jpg", "B", 3.2, 2.2, 1.35, Color(1.0, 0.25, 0.85)],
	# the sports hall
	["poster-mantis.jpg", "L", 13.8, 1.95, 1.45, Color(0.3, 1.0, 0.4)],
	["poster-fire.jpg", "L", 15.6, 1.95, 1.45, Color(1.0, 0.5, 0.1)],
	["poster-comic-glowing.jpg", "L", 17.4, 1.95, 1.45, Color(0.5, 1.0, 0.25)],
	["poster-comic-fatamy.jpg", "L", 19.2, 1.95, 1.45, Color(1.0, 0.3, 0.35)],
	["panel-wedding.jpg", "R", 11.9, 1.95, 1.5, Color(1.0, 0.35, 0.65)],       # on the bowling wall, by the foul line, in line with the STRIKERS neon
	["panel-city.jpg", "R", 18.0, 1.95, 1.3, Color(1.0, 0.3, 0.7)],
]


static func gallery(root: Node3D) -> void:
	for g in GALLERY:
		var wall: String = g[1]
		var at := Vector3(WALL_L if wall == "L" else WALL_R if wall == "R" else float(g[2]), float(g[3]), float(g[2]) if wall != "B" else 7.3 - 0.04)
		var yaw := PI / 2.0 if wall == "L" else -PI / 2.0 if wall == "R" else PI
		stand_poster(root, str(g[0]), at, yaw, float(g[4]), g[5])


## A picture standing off the wall on four steel standoffs in a slim steel frame, lit from within a little, with a soft glow on the wall behind it.
## yaw turns its face into the room (0 faces +z).
static func stand_poster(parent: Node3D, file: String, at: Vector3, yaw: float, height: float, glow: Color) -> void:
	var tex := load("res://assets/art/" + file) as Texture2D
	if tex == null:
		return
	var n := Node3D.new()
	parent.add_child(n)
	n.position = at
	n.rotation.y = yaw
	var w: float = height * float(tex.get_width()) / float(tex.get_height())
	var steel := VRBuild.pbr("metal", Color(0.9, 0.9, 0.95), Vector2(2, 1), 0.9)
	var off := 0.07
	# the glow on the wall behind it (additive, no hard edge)
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	gr.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	halo.albedo_texture = gt
	halo.albedo_color = Color(glow.r, glow.g, glow.b, 0.75)
	VRBuild.quad(n, Vector2(w * 2.1, height * 1.75), Vector3(0, 0, 0.012), halo)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			VRBuild.cylinder(n, 0.012, off, Vector3(sx * (w / 2.0 - 0.04), sy * (height / 2.0 - 0.04), off / 2.0), steel, -1.0, Vector3(PI / 2, 0, 0), 10)
	VRBuild.box(n, Vector3(w + 0.05, height + 0.05, 0.03), Vector3(0, 0, off + 0.015), VRBuild.mat(Color(0.03, 0.02, 0.05), 0.6))
	for e in [[Vector3(w + 0.06, 0.03, 0.05), Vector3(0, height / 2.0 + 0.012, off + 0.025)], [Vector3(w + 0.06, 0.03, 0.05), Vector3(0, -height / 2.0 - 0.012, off + 0.025)],
			[Vector3(0.03, height + 0.06, 0.05), Vector3(-w / 2.0 - 0.012, 0, off + 0.025)], [Vector3(0.03, height + 0.06, 0.05), Vector3(w / 2.0 + 0.012, 0, off + 0.025)]]:
		VRBuild.box(n, e[0], e[1], steel)
	var face := VRBuild.tex_mat(tex, 0.0, 0.5)
	face.emission_enabled = true
	face.emission_texture = tex
	face.emission_energy_multiplier = 0.45
	VRBuild.quad(n, Vector2(w, height), Vector3(0, 0, off + 0.032), face)
