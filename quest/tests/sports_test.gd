extends SceneTree
## Rules and physics of the sports hall: bowling scoring, dartboard and axe-target scoring, the axe's stick rule, and real throws down a bowling lane.
## godot --headless --fixed-fps 60 --path quest -s tests/sports_test.gd
var fails := 0
var bowl: BowlingGame
var phase := 0
var frames := 0
var results: Array = []
var shots := [[0.0, 7.0, 0.0], [0.0, 7.0, 6.0], [0.65, 7.0, 0.0], [0.0, 9.0, 0.0], [-0.09, 7.0, 0.0]]       # [x offset from the lane's middle, speed, wrist roll]
var shot := 0


func _init() -> void:
	# ---- bowling scoring ----
	_t(BowlingScore.total([10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10]) == 300, "a perfect game is 300")
	_t(BowlingScore.total([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) == 0, "all gutters is 0")
	var spares: Array = []
	for _i in range(21):
		spares.append(5)
	_t(BowlingScore.total(spares) == 150, "five and a spare every frame is 150")
	_t(BowlingScore.total([9, 0, 9, 0, 9, 0, 9, 0, 9, 0, 9, 0, 9, 0, 9, 0, 9, 0, 9, 0]) == 90, "nine and a miss ten times is 90")
	_t(BowlingScore.total([10, 7, 3, 9, 0, 10, 0, 8, 8, 2, 0, 6, 10, 10, 10, 8, 1]) == 167, "a mixed game: 167")
	var f := BowlingScore.frames([10, 7, 3, 9, 0])
	_t(f[0].text == "X" and f[1].text == "7/" and f[2].text == "9-", "frame marks X, 7/ and 9-")
	_t(int(f[0].total) == 20 and int(f[1].total) == 39 and int(f[2].total) == 48, "running totals 20, 39, 48")
	var st := BowlingScore.state([10])
	_t(st.frame == 2 and st.ball == 1 and st.standing == 10, "a strike moves to the next frame with a full rack")
	st = BowlingScore.state([7])
	_t(st.frame == 1 and st.ball == 2 and st.standing == 3, "after a 7 three pins stand")
	st = BowlingScore.state([7, 3])
	_t(st.frame == 2 and st.ball == 1 and st.standing == 10, "a spare moves on")
	var tenth: Array = []
	for _i in range(9):
		tenth.append(10)
	_t(BowlingScore.state(tenth).frame == 10, "tenth frame reached after nine strikes")
	_t(not BowlingScore.state(tenth + [10, 10]).done and BowlingScore.state(tenth + [10, 10]).ball == 3, "a third ball after two strikes in the tenth")
	_t(BowlingScore.state(tenth + [10, 10, 10]).done, "game over after the third ball")
	_t(BowlingScore.state(tenth + [3, 4]).done, "no bonus ball with an open tenth")
	_t(BowlingScore.state(tenth + [6, 4]).standing == 10 and not BowlingScore.state(tenth + [6, 4]).done, "a spare in the tenth gives a fresh rack and one more ball")
	# ---- darts ----
	_t(DartsGame.score_at(0.0, 0.0).value == 50, "dead centre is the double bull, 50")
	_t(DartsGame.score_at(0.0, 0.012).value == 25, "outer bull is 25")
	_t(DartsGame.score_at(0.0, 0.103).label == "T20", "the top treble is T20")
	_t(DartsGame.score_at(0.0, 0.166).label == "D20", "the top double is D20")
	_t(DartsGame.score_at(0.0, 0.13).label == "S20", "between the rings is a single")
	_t(DartsGame.score_at(0.2, 0.0).value == 0, "outside the double ring scores nothing")
	_t(DartsGame.score_at(0.103, 0.0).label == "T6", "straight right is 6 (treble)")
	_t(DartsGame.score_at(-0.166, 0.0).label == "D11", "straight left is 11 (double)")
	_t(DartsGame.score_at(0.0, -0.13).label == "S3", "straight down is 3")
	var dg := DartsGame.new()
	_t(dg.checkout(170, 3) == "T20 T20 50", "170 checks out T20 T20 50: %s" % dg.checkout(170, 3))
	_t(dg.checkout(40, 1) == "D20", "40 is D20")
	_t(dg.checkout(32, 3) != "" and dg.checkout(169, 3) == "", "32 can be finished, 169 cannot")
	dg.free()
	# ---- axes ----
	_t(AxeGame.score_at(0.0, 0.0).value == 5, "the bullseye is 5")
	_t(AxeGame.score_at(0.0, 0.2).value == 3, "a ring: 3")
	_t(AxeGame.score_at(0.33, 0.31).value == 7, "a clutch dot is 7")
	_t(AxeGame.score_at(0.0, 0.39).value == 0, "outside the 1 ring is a miss")
	_t(AxeGame.can_stick(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(0, 0, 1), 6.0), "blade first and upright sticks")
	_t(not AxeGame.can_stick(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(0, 0, 1), 6.0), "blade facing away does not stick")
	_t(not AxeGame.can_stick(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(0, 0, 1), 6.0), "handle first does not stick")
	_t(not AxeGame.can_stick(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(0, 0, 1), 1.5), "a feeble throw does not stick")
	# ---- bowling physics: real throws down lane 1 ----
	bowl = BowlingGame.new()
	root.add_child(bowl)
	bowl.build(null)
	bowl._start(0)


func _t(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL: ", what)
		fails += 1


func _throw(k: int) -> void:
	var sh: Array = shots[k]
	var s: Dictionary = bowl.lanes[0]
	var t: Throwable = s.ball
	var b := t.node as RigidBody3D
	b.freeze = false
	b.global_transform = Transform3D(Basis.IDENTITY, Vector3(bowl.lane_x(0) + float(sh[0]), 0.13, ShackAnnex.FOUL_Z - 0.2))
	t.state = "held"
	bowl.on_release(t, Transform3D.IDENTITY, Vector3(0, 0, float(sh[1])), Vector3(0, 0, float(sh[2])), 0)


func _process(delta: float) -> bool:
	if bowl == null:
		return false
	frames += 1
	bowl.tick(delta)
	var s: Dictionary = bowl.lanes[0]
	if phase == 0 and frames > 20:
		_throw(shot)
		phase = 1
	elif phase == 1 and s.phase == "ready":
		var rolls: Array = s.rolls[0]
		results.append(rolls[rolls.size() - 1])
		print("throw ", shot, " -> ", rolls[rolls.size() - 1], " pins   (", s.msg, ")")
		shot += 1
		if shot >= shots.size():
			_t(results[0] >= 5, "a centre hit transfers energy through the rack (splits are possible with flat-base pins) (%d)" % results[0])
			_t(results[2] == 0, "a ball 0.65 m off line goes in the gutter: %d" % results[2])
			_t(results[4] >= 6, "a pocket shot produces pin action")
			print("BOWLING / DARTS / AXE TESTS ", "PASS" if fails == 0 else "FAIL %d" % fails)
			quit(1 if fails > 0 else 0)
			return true
		# each shot starts from a fresh rack
		bowl._start(0)
		phase = 0
		frames = 0
	elif phase == 1 and frames > 2400:
		_t(false, "the ball never finished (%s)" % s.phase)
		quit(1)
		return true
	return false
