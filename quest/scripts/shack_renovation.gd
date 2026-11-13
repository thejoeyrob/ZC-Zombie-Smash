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
	var characters := [["boss-jordan-stage1.webp","JORDAN","OWN THE NIGHT"],["boss-debo-stage1.webp","DEBO","PLAY FOR GLORY"],["boss-drmantis-stage1.webp","DR MANTIS","ONE MORE ROUND"],["boss-caffeinatedsloth-stage1.webp","SLOTH","STAY IN THE GAME"]]
	# Gallery above cabinets, not behind controls or at eye level over them.
	for i in range(4):
		var side := -1 if i<2 else 1
		poster(root,Vector3(side*3.92,2.65,2.1+(i%2)*2.25),-side*PI/2,Vector2(1.05,0.70),characters[i],font)
	# Larger, separated portraits in previously empty sports corridor bays.
	for i in range(2):
		poster(root,Vector3(-3.91,1.95,13.8+i*1.65),PI/2,Vector2(1.05,1.48),characters[i+2],font)
		poster(root,Vector3(3.91,1.95,13.8+i*1.65),-PI/2,Vector2(1.05,1.48),characters[i],font)
	# Inlaid wayfinding instead of floating instructions.
	for entry in [["ARCADE  /  LOUNGE",Vector3(0,0.022,1.1)],["SPORTS CLUB",Vector3(0,0.022,8.0)]]:
		var plaque := Node3D.new();root.add_child(plaque);plaque.position=entry[1];plaque.rotation.x=-PI/2
		VRBuild.box(plaque,Vector3(1.6,0.28,0.012),Vector3.ZERO,metal)
		VRBuild.label(plaque,entry[0],0.10,Vector3(0,0,0.008),Color(0.06,0.05,0.03),Vector3.ZERO,0,font)

static func poster(parent: Node3D, at: Vector3, yaw: float, size: Vector2, character: Array, font: Font) -> void:
	var n:=Node3D.new();parent.add_child(n);n.position=at;n.rotation.y=yaw
	VRBuild.box(n,Vector3(size.x+0.06,size.y+0.06,0.04),Vector3.ZERO,VRBuild.pbr("metal",Color(0.7,0.52,0.28),Vector2.ONE,0.25,0.65))
	VRBuild.quad(n,size,Vector3(0,0,0.024),VRBuild.pbr("leather-black",Color(0.35,0.40,0.44),Vector2.ONE,0.25))
	var texture:=load("res://assets/art/"+str(character[0])) as Texture2D
	var art:=VRBuild.tex_mat(texture,0,0.9,true)
	art.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	VRBuild.quad(n,Vector2(size.y*0.72,size.y*0.72),Vector3(-size.x*0.1,size.y*0.05,0.028),art)
	VRBuild.label(n,str(character[1]),size.y*0.10,Vector3(0,-size.y*0.32,0.031),Color(0.94,0.75,0.39),Vector3.ZERO,0,font)
	VRBuild.label(n,str(character[2]),size.y*0.038,Vector3(0,-size.y*0.43,0.031),Color(0.8,0.8,0.76),Vector3.ZERO,0,font)
