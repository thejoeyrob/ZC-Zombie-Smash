extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	for fps in [36, 60, 72, 90, 120]:
		var track := HandTrack.new()
		for k in range(fps):
			var time: float = float(k) / float(fps)
			track.push(time, Vector3(0, 0, time * 6.0), Basis.IDENTITY)
		check(absf(track.peak_velocity().z - 6.0) < 0.02, "Release speed is stable at %d Hz" % fps)
		track.push(1.0, Vector3(100, 0, 0), Basis.IDENTITY)
		check(track.peak_velocity() == Vector3.ZERO, "Teleport clears throw velocity")
	var ninth: Array = []
	for i in range(18):
		ninth.append(0)
	for entry in [[[5, 5, 5], "5/5", 15], [[0, 10, 10], "-/X", 20], [[10, 5, 5], "X5/", 20], [[10, 10, 10], "XXX", 30], [[10, 0, 10], "X-/", 20]]:
		var game: Array = ninth + entry[0]
		check(BowlingScore.frames(game)[9].text == entry[1], "Tenth frame notation: " + entry[1])
		check(BowlingScore.total(game) == entry[2] and BowlingScore.state(game).done, "Tenth frame total and completion")
	var darts := DartsGame.new()
	root.add_child(darts)
	darts.build(null)
	darts.choose("g_d0_go")
	check(darts.checkout(40, 0) == "", "No checkout after all darts are spent")
	var dart: Throwable = darts.darts[0]
	dart.data = {"scored": true, "bounced": true}
	darts._to_rack(dart)
	check(dart.data.is_empty(), "Returning a dart clears its previous score and bounce")
	darts.on_grab(dart, 0)
	check(darts.things().filter(func(t): return t.lane == 0).is_empty(), "A second dart cannot be picked up mid-throw")
	darts.cancel_hold(dart)
	check(darts.boards[0].left == 3 and dart.state == "rest", "Cancelled hold spends no dart")
	var s: Dictionary = darts.boards[0]
	s.scores[0] = 40
	s.turn_start = 40
	darts._record(0, {"label": "S20", "value": 20, "mult": 1, "number": 20})
	darts._record(0, {"label": "S20", "value": 20, "mult": 1, "number": 20})
	check(s.scores[0] == 40 and s.left == 0, "Non-double finish bust restores the whole visit")
	check(not darts.request_restart(s), "A live match needs confirmation to reset")
	check(darts.request_restart(s), "Second start press confirms")
	check(darts.result_text([5, 5]).begins_with("DRAW"), "Tied scores produce a draw")
	darts._next_turn(0)
	darts._record(0, {"label": "D20", "value": 40, "mult": 2, "number": 20})
	check(s.state == "over" and s.winner == 0, "Double finish wins")
	s.players = 2
	s.mode = 2
	darts._start(0)
	s.marks[0][0] = 3
	darts._record(0, {"label": "T20", "value": 60, "mult": 3, "number": 20})
	check(s.points[0] == 60, "Cricket scores against an open opponent")
	s.marks[1][0] = 3
	darts._record(0, {"label": "T20", "value": 60, "mult": 3, "number": 20})
	check(s.points[0] == 60, "Closed cricket numbers do not score")
	darts.free()
	var axes := AxeGame.new()
	root.add_child(axes)
	axes.build(null)
	axes.choose("g_a0_go")
	var axe: Throwable = axes.axes[0]
	axe.data = {"hit": true, "scored": true}
	axes._to_rack(axe)
	check(axe.data.is_empty(), "Reused axe clears collision state")
	axes.on_grab(axe, 0)
	axes.cancel_hold(axe)
	check(axes.lanes[0].thrown == 0, "Cancelled axe spends no throw")
	check(AxeGame.score_at(0.39, 0.31).value != 7, "Clutch hit area matches the painted dot")
	axe.basis = Basis(Vector3.UP, PI)
	axe.vel = Vector3(0, 0, 7)
	axe.state = "flying"
	var other := Vector3(ShackAnnex.AXE_X[1], ShackAnnex.AXE_Y, ShackAnnex.AXE_FACE_Z - 0.07)
	axes._arrive(axe, other - Vector3(0, 0, 0.1), other + Vector3(0, 0, 0.1), other.z)
	check(axes.lanes[0].scores[0] == 0 and axe.state != "stuck", "Another lane cannot award axe points")
	axes.free()
	var bowl := BowlingGame.new()
	root.add_child(bowl)
	bowl.build(null)
	bowl.choose("g_b0_go")
	var ball: Throwable = bowl.balls[0]
	bowl.on_grab(ball, 0)
	bowl.cancel_hold(ball)
	check(bowl.lanes[0].rolls[0].is_empty() and ball.state == "rest", "Cancelled bowling ball spends no roll")
	await physics_frame
	await physics_frame
	var space := bowl.get_world_3d().direct_space_state
	var gx := bowl.lane_x(0) + ShackAnnex.LANE_W / 2.0 + ShackAnnex.GUTTER_W / 2.0
	var ray := PhysicsRayQueryParameters3D.create(Vector3(gx, 1, 14), Vector3(gx, -1, 14), 1)
	var hit := space.intersect_ray(ray)
	check(not hit.is_empty() and hit.position.y < -0.05, "Gutter collision surface is below the lane")
	for lane in bowl.lanes:
		for pin in lane.pins:
			check(pin.body.freeze, "Ready pins stay stable until a release")
	bowl.free()
	print("SPORTS REGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
