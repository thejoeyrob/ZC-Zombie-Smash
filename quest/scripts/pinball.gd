class_name Pinball
extends Node3D
## The zombie pinball machine that stands opposite the door. Local +z is the player's side.

func build(art_dir := "res://assets/art/") -> void:
	var body := VRBuild.mat(Color(0.05, 0.04, 0.08), 0.5, 0.3)
	var chrome := VRBuild.mat(Color(0.8, 0.82, 0.88), 0.2, 1.0)
	var dark := VRBuild.mat(Color(0.015, 0.015, 0.02), 0.6)
	var glow := VRBuild.mat(Color(1.0, 0.3, 0.7), 0.4, 0.0, 2.6)
	var side = load(art_dir + "side-pinball.png")
	var field = load(art_dir + "playfield-pinball.jpg")
	var head = load(art_dir + "marquee-pinball.jpg")
	# cabinet: base block with the side art on both sides, chrome legs and trim
	VRBuild.box(self, Vector3(0.62, 0.62, 1.34), Vector3(0, 0.52, 0.05), body)
	for sx in [-0.28, 0.28]:
		for sz in [-0.55, 0.65]:
			VRBuild.cylinder(self, 0.028, 0.22, Vector3(sx, 0.11, sz), chrome)
	VRBuild.box(self, Vector3(0.6, 0.02, 1.3), Vector3(0, 0.215, 0.05), dark)
	VRBuild.box(self, Vector3(0.5, 0.012, 0.012), Vector3(0, 0.23, 0.72), glow)
	if side != null:
		for sx in [-1, 1]:
			var m := VRBuild.tex_mat(side, 0.2, 0.55)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.45
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			# the lower, flipper end of the picture on the long side of the cabinet
			m.uv1_scale = Vector3(1.0 * (-1 if sx > 0 else 1), 0.42, 1)
			m.uv1_offset = Vector3(1.0 if sx > 0 else 0.0, 0.58, 0)
			VRBuild.quad(self, Vector2(1.34, 0.62), Vector3(sx * 0.3125, 0.52, 0.05), m, Vector3(0, sx * PI / 2.0, 0))
			var m2 := VRBuild.tex_mat(side, 0.2, 0.55)
			m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m2.cull_mode = BaseMaterial3D.CULL_DISABLED
			m2.uv1_scale = Vector3(0.36 * (-1 if sx > 0 else 1), 0.52, 1)
			m2.uv1_offset = Vector3(0.36 if sx > 0 else 0.0, 0.02, 0)
			VRBuild.quad(self, Vector2(0.24, 1.0), Vector3(sx * 0.3225, 1.45, -0.5), m2, Vector3(0, sx * PI / 2.0, 0))
	# playfield under glass, tilted toward the player
	var tilt := 0.11
	var pf := Node3D.new()
	pf.position = Vector3(0, 0.86, 0.05)
	pf.rotation = Vector3(-PI / 2.0 + tilt, 0, 0)
	add_child(pf)
	if field != null:
		var fm := VRBuild.tex_mat(field, 0.55, 0.45, false)
		VRBuild.quad(pf, Vector2(0.56, 1.12), Vector3.ZERO, fm)
	else:
		VRBuild.quad(pf, Vector2(0.56, 1.12), Vector3.ZERO, VRBuild.mat(Color(0.1, 0.05, 0.2)))
	var glass := VRBuild.mat(Color(0.7, 0.9, 1.0, 0.08), 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	VRBuild.quad(pf, Vector2(0.56, 1.12), Vector3(0, 0, 0.05), glass)
	for sx in [-0.29, 0.29]:
		VRBuild.box(pf, Vector3(0.025, 1.14, 0.07), Vector3(sx, 0, 0.03), chrome)
	VRBuild.box(pf, Vector3(0.6, 0.03, 0.07), Vector3(0, 0.575, 0.03), chrome)
	# lockdown bar, flipper buttons, plunger
	VRBuild.box(self, Vector3(0.6, 0.05, 0.04), Vector3(0, 0.84, 0.735), chrome)
	for sx in [-0.32, 0.32]:
		VRBuild.cylinder(self, 0.018, 0.02, Vector3(sx, 0.6, 0.56), VRBuild.mat(Color(0.9, 0.1, 0.12), 0.3, 0.0, 0.4), -1.0, Vector3(0, 0, PI / 2.0))
	VRBuild.cylinder(self, 0.01, 0.16, Vector3(0.22, 0.6, 0.78), chrome, -1.0, Vector3(PI / 2.0, 0, 0))
	VRBuild.sphere(self, 0.024, Vector3(0.22, 0.6, 0.87), VRBuild.mat(Color(0.9, 0.1, 0.12), 0.3), 12)
	# backbox with the picture on its face and the title across the top
	VRBuild.box(self, Vector3(0.64, 0.96, 0.22), Vector3(0, 1.43, -0.5), body)
	if field != null:
		var tm := VRBuild.tex_mat(field, 0.9, 0.5, true)
		tm.uv1_scale = Vector3(1, 0.5, 1)
		VRBuild.quad(self, Vector2(0.6, 0.72), Vector3(0, 1.34, -0.386), tm)
	if head != null:
		VRBuild.quad(self, Vector2(0.63, 0.21), Vector3(0, 1.8, -0.386), VRBuild.tex_mat(head, 1.0, 0.5, true))
	VRBuild.box(self, Vector3(0.64, 0.02, 0.22), Vector3(0, 1.915, -0.5), glow)
	VRBuild.box(self, Vector3(0.64, 0.02, 0.012), Vector3(0, 0.96, -0.39), glow)
	# a soft glow on the floor so it reads in the dark
	var halo := VRBuild.mat(Color(1.0, 0.3, 0.7, 0.18), 0.5, 0.0, 1.2)
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	VRBuild.quad(self, Vector2(1.4, 2.0), Vector3(0, 0.01, 0.05), halo, Vector3(-PI / 2.0, 0, 0))
