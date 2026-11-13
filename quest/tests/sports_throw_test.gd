extends SceneTree
## Throws a dart and an axe the way a hand would and checks they fly, arrive and score sensibly.
## godot --headless --fixed-fps 60 --path quest -s tests/sports_throw_test.gd
var fails := 0
var darts: DartsGame
var axes: AxeGame
var step := 0
var stage := 0
var dart_results: Array = []
var axe_results: Array = []
var dart_throws := [Vector3(-5.9, 1.6, 0.0), Vector3(-5.9, 1.6, 0.45), Vector3(-5.9, 0.4, 0.0), Vector3(-1.5, 0.0, 0.0)]
var axe_throws := [[Vector3(0, 1.2, 7.0), 0.0], [Vector3(0, 1.2, 3.2), 0.0], [Vector3(0, 1.2, 7.0), 12.0]]       # [velocity, wrist turn rad/s]
var idx := 0


func _init() -> void:
	darts = DartsGame.new()
	root.add_child(darts)
	darts.build(null)
	axes = AxeGame.new()
	root.add_child(axes)
	axes.build(null)
	darts.social_handling = false       # these throws are tuned for the strict (Simulation) feel; Social has its own tests (tests/upgrade/social_handling.gd)
	axes.social_handling = false
	darts.choose("g_d0_go")
	axes.choose("g_a1_go")


func _t(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL: ", what)
		fails += 1


func _throw_dart(v: Vector3) -> void:
	var t: Throwable = darts.darts[idx]
	t.node.global_position = Vector3(ShackAnnex.OCHE_X + 0.2, 1.55, float(ShackAnnex.DART_Z[0]))
	t.pos = t.node.global_position       # (the hand loop keeps pos up to date while a thing is held)
	t.state = "held"
	darts.on_release(t, Transform3D.IDENTITY, v, Vector3.ZERO, 0)


func _throw_axe(v: Vector3, w: float) -> void:
	var t: Throwable = axes.axes[3 + idx]
	var x := float(ShackAnnex.AXE_X[1])
	t.node.global_position = Vector3(x, 1.5, ShackAnnex.AXE_LINE_Z)
	t.pos = t.node.global_position
	t.state = "held"
	axes.on_release(t, Transform3D(Basis(Vector3.UP, PI), Vector3(x, 1.5, ShackAnnex.AXE_LINE_Z)), v, Vector3(w, 0, 0), 0)


func _process(delta: float) -> bool:
	step += 1
	darts.tick(delta)
	axes.tick(delta)
	if stage == 0 and step == 5:
		_throw_dart(dart_throws[0])
		stage = 1
		step = 0
	elif stage == 1 and step > 90:
		var d: Throwable = darts.darts[idx]
		print("dart ", idx, ": state=", d.state, " last=", darts.boards[0].last)
		dart_results.append([d.state, darts.boards[0].last])
		idx += 1
		step = 0
		if idx < dart_throws.size() and idx < 3:
			_throw_dart(dart_throws[idx])
		else:
			_t(dart_results[0][0] == "stuck", "a good throw sticks in the board (%s)" % dart_results[0][0])
			_t(dart_results[0][1] != "MISS" and dart_results[0][1] != "BOUNCE", "and scores (%s)" % dart_results[0][1])
			_t(dart_results[2][0] != "stuck", "a throw into the floor does not stick (%s)" % dart_results[2][0])
			idx = 0
			stage = 2
			_throw_axe(axe_throws[0][0], axe_throws[0][1])
	elif stage == 2 and step > 150:
		var a: Throwable = axes.axes[3 + idx]
		print("axe ", idx, ": state=", a.state, " last=", axes.lanes[1].last)
		axe_results.append([a.state, axes.lanes[1].last])
		idx += 1
		step = 0
		if idx < axe_throws.size():
			_throw_axe(axe_throws[idx][0], axe_throws[idx][1])
		else:
			_t(axe_results[0][0] == "stuck", "an axe thrown at a natural speed from 12 feet sticks (%s)" % axe_results[0][0])
			_t(axe_results[1][0] != "stuck", "a feeble lob does not stick (%s)" % axe_results[1][0])
			print("THROW TESTS ", "PASS" if fails == 0 else "FAIL %d" % fails)
			quit(1 if fails > 0 else 0)
			return true
	return false
