class_name VendingMachine
extends Node3D
## An old-school snack and soda machine. What is inside (and what it is called) comes from data/vending.json, so it is easy to rename.

func build(font: Font) -> void:
	var red := VRBuild.mat(Color(0.62, 0.08, 0.12), 0.35, 0.2)
	var dark := VRBuild.mat(Color(0.03, 0.03, 0.04), 0.6)
	var chrome := VRBuild.mat(Color(0.8, 0.82, 0.88), 0.2, 1.0)
	var white := VRBuild.mat(Color(0.95, 0.93, 0.88), 0.5)
	var lamp := VRBuild.mat(Color(1.0, 0.95, 0.8), 0.5, 0.0, 2.2)
	# shell
	# the shell is a frame round the window, so the goods can be seen through the glass
	VRBuild.box(self, Vector3(0.94, 1.86, 0.4), Vector3(0, 0.93, -0.2), red)
	VRBuild.box(self, Vector3(0.06, 1.24, 0.4), Vector3(-0.44, 0.99, 0.2), red)
	VRBuild.box(self, Vector3(0.26, 1.24, 0.4), Vector3(0.34, 0.99, 0.2), red)
	VRBuild.box(self, Vector3(0.94, 0.25, 0.4), Vector3(0, 1.735, 0.2), red)
	VRBuild.box(self, Vector3(0.94, 0.37, 0.4), Vector3(0, 0.185, 0.2), red)
	VRBuild.box(self, Vector3(0.98, 0.06, 0.84), Vector3(0, 1.87, 0), VRBuild.mat(Color(0.2, 0.03, 0.05), 0.4, 0.3))
	VRBuild.box(self, Vector3(0.98, 0.1, 0.84), Vector3(0, 0.03, 0), dark)
	# lit header sign
	VRBuild.box(self, Vector3(0.88, 0.2, 0.05), Vector3(0, 1.74, 0.42), lamp)
	VRBuild.label(self, "SNACKS & SODA", 0.11, Vector3(0, 1.74, 0.447), Color(0.7, 0.05, 0.1), Vector3.ZERO, 3, font)
	# window: dark interior, shelves, goods
	var w_x := -0.1
	var w_w := 0.62
	for fy in [0.99 + 0.63, 0.99 - 0.63]:
		VRBuild.box(self, Vector3(w_w + 0.06, 0.03, 0.03), Vector3(w_x, fy, 0.41), chrome)
	for fx in [w_x - w_w / 2.0 - 0.015, w_x + w_w / 2.0 + 0.015]:
		VRBuild.box(self, Vector3(0.03, 1.28, 0.03), Vector3(fx, 0.99, 0.41), chrome)
	VRBuild.box(self, Vector3(w_w, 1.24, 0.02), Vector3(w_x, 0.99, 0.17), VRBuild.mat(Color(0.2, 0.2, 0.26), 0.5, 0.0, 0.9, Color(1.0, 0.97, 0.9)))
	var pane := VRBuild.mat(Color(0.8, 0.9, 1.0, 0.07), 0.05)
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	VRBuild.quad(self, Vector2(w_w, 1.24), Vector3(w_x, 0.99, 0.425), pane)
	var items := _load_items()
	var rows := items.size()
	for r in range(rows):
		var y := 1.5 - r * 0.245
		VRBuild.box(self, Vector3(w_w, 0.012, 0.3), Vector3(w_x, y - 0.12, 0.27), chrome)
		var row: Array = items[r]
		for i in range(row.size()):
			var it: Dictionary = row[i]
			var x := w_x - w_w / 2.0 + 0.07 + i * (w_w - 0.14) / maxf(1.0, row.size() - 1.0)
			_item(it, Vector3(x, y - 0.115, 0.3))
			# price tag with the product's name
			VRBuild.box(self, Vector3(0.1, 0.03, 0.004), Vector3(x, y - 0.14, 0.436), white)
			var l := VRBuild.label(self, str(it.get("name", "")).substr(0, 14), 0.016, Vector3(x, y - 0.14, 0.4385), Color(0.1, 0.1, 0.12), Vector3.ZERO, 0, font)
			l.double_sided = false
	# right-hand panel: keypad, coin slot, card reader
	VRBuild.box(self, Vector3(0.2, 1.24, 0.02), Vector3(0.33, 0.99, 0.41), white)
	VRBuild.box(self, Vector3(0.14, 0.06, 0.02), Vector3(0.33, 1.5, 0.425), VRBuild.mat(Color(0.05, 0.1, 0.05), 0.4, 0.0, 1.6, Color(0.3, 1.0, 0.4)))
	VRBuild.label(self, "A1", 0.04, Vector3(0.33, 1.5, 0.437), Color(0.3, 1.0, 0.4), Vector3.ZERO, 0, font)
	for k in range(12):
		var kx := 0.28 + (k % 3) * 0.05
		var ky := 1.36 - (k / 3) * 0.06
		VRBuild.box(self, Vector3(0.04, 0.04, 0.012), Vector3(kx, ky, 0.428), VRBuild.mat(Color(0.2, 0.2, 0.24), 0.4, 0.4))
	VRBuild.box(self, Vector3(0.1, 0.1, 0.012), Vector3(0.33, 1.0, 0.428), dark)
	VRBuild.box(self, Vector3(0.012, 0.07, 0.014), Vector3(0.33, 1.0, 0.432), chrome)
	VRBuild.box(self, Vector3(0.1, 0.05, 0.012), Vector3(0.33, 0.86, 0.428), VRBuild.mat(Color(0.1, 0.2, 0.5), 0.4, 0.0, 1.0))
	# dispenser flap
	VRBuild.box(self, Vector3(0.62, 0.2, 0.02), Vector3(w_x, 0.2, 0.412), dark)
	VRBuild.box(self, Vector3(0.5, 0.14, 0.02), Vector3(w_x, 0.2, 0.425), VRBuild.mat(Color(0.02, 0.02, 0.03), 0.3, 0.2))
	# a warm glow around it
	var halo := VRBuild.mat(Color(1.0, 0.85, 0.6, 0.12), 0.5, 0.0, 1.0)
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	VRBuild.quad(self, Vector2(1.6, 1.6), Vector3(0, 0.01, 0.6), halo, Vector3(-PI / 2.0, 0, 0))


func _load_items() -> Array:
	var f := FileAccess.open("res://data/vending.json", FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary and d.has("rows"):
			return d.rows
	return []


func _item(it: Dictionary, pos: Vector3) -> void:
	var col := Color.html(str(it.get("color", "#cccccc")))
	var m := VRBuild.mat(col, 0.45, 0.1, 0.12)
	match str(it.get("kind", "candy")):
		"chips":
			VRBuild.box(self, Vector3(0.085, 0.13, 0.03), pos + Vector3(0, 0.05, 0), m, Vector3(-0.2, 0, 0))
			VRBuild.box(self, Vector3(0.07, 0.04, 0.032), pos + Vector3(0, 0.07, 0.002), VRBuild.mat(Color(1, 1, 1), 0.5), Vector3(-0.2, 0, 0))
		"can":
			VRBuild.cylinder(self, 0.03, 0.12, pos + Vector3(0, 0.06, 0), m)
			VRBuild.cylinder(self, 0.031, 0.015, pos + Vector3(0, 0.12, 0), VRBuild.mat(Color(0.8, 0.82, 0.88), 0.2, 1.0))
		_:
			VRBuild.box(self, Vector3(0.09, 0.03, 0.05), pos + Vector3(0, 0.02, 0), m)
			VRBuild.box(self, Vector3(0.09, 0.03, 0.05), pos + Vector3(0, 0.05, 0), VRBuild.mat(col.lightened(0.15), 0.45), Vector3(0, 0.15, 0))
