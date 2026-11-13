class_name ShackRenovation
extends RefCounted
## Deliberate architectural zones. Existing photograph-based PBR materials and
## character artwork; no new realtime lights or reflection cameras.
static func build(root: Node3D, font: Font) -> void:
	var oak := VRBuild.pbr("oakslat", Color(0.65,0.48,0.32), Vector2(2,1),0.45)
	var metal := VRBuild.pbr("metal", Color(0.65,0.48,0.25),Vector2(2,1),0.25,0.7)
	# Textured coffer beams give the ceiling scale and depth without extra lights.
	for z in [0.8,2.8,4.8,6.8,9.0,12.0,15.0,18.0,20.6]:
		VRBuild.box(root,Vector3(7.9,0.12,0.16),Vector3(0,3.22,z),oak)
		VRBuild.box(root,Vector3(7.6,0.012,0.035),Vector3(0,3.153,z),metal)
	# Comfortable wall panelling under the character gallery in the hall.
	for side in [-1,1]:
		var n := Node3D.new()
		root.add_child(n)
		n.position=Vector3(side*3.96,0,14.35)
		n.rotation.y=-side*PI/2
		VRBuild.box(n,Vector3(5.5,0.9,0.04),Vector3(0,0.45,0),oak)
		VRBuild.box(n,Vector3(5.5,0.035,0.065),Vector3(0,0.92,0.025),metal)
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
