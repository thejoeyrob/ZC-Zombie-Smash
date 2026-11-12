class_name BowlingGame
extends SportGame
## Ten-pin bowling on two lanes with real rigid-body physics: a 6 kg ball, ten 1.5 kg pins set 305 mm apart, gutters, and a pit. Pick the ball up,
## swing, and let go: it leaves at your hand's speed and direction, and a twist of your wrist as you let go puts a hook on it. Ten frames, strikes
## and spares scored properly, one to four players taking a frame each in turn at a lane.

const BALL_R := 0.109
const BALL_MASS := 6.0
const PIN_H := 0.38
const PIN_MASS := 1.5
const PIN_SPACING := 0.305
const ROW_SPACING := 0.264
const LANE_END := ShackAnnex.HEAD_PIN_Z + 0.75
const PIT_FLOOR := -0.45
const HOOK_GAIN := 0.06
const HOOK_MAX := 0.9
const BALL_COLOURS := [Color(0.1, 0.25, 0.85), Color(0.75, 0.1, 0.25)]

var lanes: Array = []
var balls: Array = []
var _pin_mesh: ArrayMesh
var _world: StaticBody3D


func build(f: Font) -> void:
	font = f
	_build_world()
	_pin_mesh = _make_pin_mesh()
	for i in range(ShackAnnex.LANE_X.size()):
		lanes.append(_fresh(i))
		_build_lane(i)


func _fresh(i: int) -> Dictionary:
	return {"lane": i, "players": 1, "state": "idle", "phase": "idle", "cur": 0, "rolls": [], "pins": [], "ball": null, "t": 0.0, "still": 0.0, "msg": "",
		"label": null, "board": null, "buttons": {}, "standing_before": 10, "thaw": [], "hook": 0.0, "fwd": Vector3(0, 0, 1)}


func lane_x(i: int) -> float:
	return float(ShackAnnex.LANE_X[i])


func _box(centre: Vector3, size: Vector3, friction := 0.5) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = centre
	_world.add_child(cs)


func _build_world() -> void:
	_world = StaticBody3D.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 0.35
	pm.bounce = 0.05
	_world.physics_material_override = pm
	add_child(_world)
	var z0 := ShackAnnex.Z0
	var z1 := ShackAnnex.Z1
	var foul := ShackAnnex.FOUL_Z
	var hw := ShackAnnex.HALF_W
	# the floor: everywhere at floor level, except under the lanes
	_box(Vector3(0, -0.5, (z0 + z1) / 2.0), Vector3(hw * 2.0, 1.0, z1 - z0))
	# the walls of the hall (so a ball cannot leave it)
	_box(Vector3(-hw - 0.5, 1.5, (z0 + z1) / 2.0), Vector3(1.0, 3.0, z1 - z0))
	_box(Vector3(hw + 0.5, 1.5, (z0 + z1) / 2.0), Vector3(1.0, 3.0, z1 - z0))
	_box(Vector3(0, 1.5, z1 + 0.5), Vector3(hw * 2.0, 3.0, 1.0))
	_box(Vector3(0, 1.5, z0 - 0.25), Vector3(hw * 2.0, 3.0, 0.5))
	# each lane: a slightly raised surface, two gutters sunk below it, rails, and a pit at the end
	for i in range(ShackAnnex.LANE_X.size()):
		var lx := lane_x(i)
		var len := LANE_END - foul
		_box(Vector3(lx, 0.003 - 0.5, foul + len / 2.0), Vector3(ShackAnnex.LANE_W, 1.0, len))
		for sx in [-1.0, 1.0]:
			# the gutter: a trough below the lane surface (the floor under it is cut away by raising the lane's neighbours)
			var gx: float = lx + sx * (ShackAnnex.LANE_W / 2.0 + ShackAnnex.GUTTER_W / 2.0)
			_box(Vector3(gx, -0.075 - 0.5, foul + len / 2.0), Vector3(ShackAnnex.GUTTER_W, 1.0, len))
			_box(Vector3(lx + sx * (ShackAnnex.LANE_W / 2.0 + ShackAnnex.GUTTER_W + 0.03), 0.1, foul + len / 2.0), Vector3(0.06, 0.4, len))
		# the pit behind the pin deck
		_box(Vector3(lx, PIT_FLOOR - 0.5, (LANE_END + z1 - 0.1) / 2.0), Vector3(ShackAnnex.LANE_W + 0.6, 1.0, z1 - 0.1 - LANE_END))
		_box(Vector3(lx, 0.5, z1 - 0.09), Vector3(ShackAnnex.LANE_W + 0.6, 2.0, 0.1))


func _build_lane(i: int) -> void:
	var lx := lane_x(i)
	var s: Dictionary = lanes[i]
	# the pedestal the ball waits on, beside the approach
	var iron := VRBuild.mat(Color(0.1, 0.1, 0.12), 0.4, 0.7)
	VRBuild.cylinder(self, 0.04, 0.8, Vector3(lx, 0.4, _ball_z()), iron, 0.04, Vector3.ZERO, 12)
	VRBuild.cylinder(self, 0.11, 0.05, Vector3(lx, 0.82, _ball_z()), VRBuild.mat(Color(0.3, 0.05, 0.1), 0.5), 0.09, Vector3.ZERO, 16)
	# the ball
	var b := RigidBody3D.new()
	b.mass = BALL_MASS
	b.continuous_cd = true
	b.can_sleep = true
	b.linear_damp = 0.0
	b.angular_damp = 0.15
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	pm.bounce = 0.08
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = BALL_R
	cs.shape = sh
	b.add_child(cs)
	var gloss := VRBuild.mat(BALL_COLOURS[i % 2], 0.12, 0.35, 0.1, BALL_COLOURS[i % 2].darkened(0.6))
	VRBuild.sphere(b, BALL_R, Vector3.ZERO, gloss, 24)
	var hole := VRBuild.mat(Color(0.02, 0.02, 0.03), 0.5)
	for h in [Vector3(-0.025, 0.09, 0.03), Vector3(0.025, 0.09, 0.03), Vector3(0.0, 0.085, -0.03)]:
		var hn: Vector3 = (h as Vector3).normalized()
		VRBuild.sphere(b, 0.011, hn * BALL_R * 0.99, hole, 8)
	add_child(b)
	var t := Throwable.new()
	t.kind = "ball"
	t.game = self
	t.lane = i
	t.node = b
	t.radius = 0.2
	balls.append(t)
	s.ball = t
	_ball_home(t)
	# ten pins, standing but frozen until the lane is started
	for k in range(10):
		var p := _make_pin(i, k)
		s.pins.append(p)
	_place_pins(i, true)
	# a score display on the masking unit above the pins, one above the lane at the foul line, and the control panel beside the approach
	var mon := VRBuild.label(self, "", 0.075, Vector3(lx, 2.55, ShackAnnex.HEAD_PIN_Z + 0.9), Color(0.7, 1.0, 0.8), Vector3(0, PI, 0), 3, font, true)
	mon.line_spacing = -6.0
	s.board = mon
	var near := VRBuild.label(self, "", 0.06, Vector3(lx, 2.55, ShackAnnex.FOUL_Z + 0.6), Color(0.7, 1.0, 0.8), Vector3.ZERO, 3, font, true)
	near.line_spacing = -6.0
	s.label = near
	var px := lx - 0.78
	VRBuild.box(self, Vector3(0.04, 0.22, 0.5), Vector3(px, 1.15, ShackAnnex.FOUL_Z - 1.0), VRBuild.mat(Color(0.1, 0.08, 0.1), 0.5))
	var names := ["players", "go"]
	for k in range(2):
		var zz := ShackAnnex.FOUL_Z - 1.0 + (0.12 if k == 0 else -0.12)
		var bl := VRBuild.label(self, "", 0.04, Vector3(px + 0.025, 1.15, zz), Color(1.0, 0.85, 0.4), Vector3(0, PI / 2, 0), 2, font, true)
		s.buttons[names[k]] = {"label": bl, "z": zz, "x": px}
	_refresh_buttons(i)


func _ball_z() -> float:
	return ShackAnnex.FOUL_Z - 1.3


func _ball_home(t: Throwable) -> void:
	var b := t.node as RigidBody3D
	b.freeze = true
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	b.global_transform = Transform3D(Basis.IDENTITY, Vector3(lane_x(t.lane), 0.85 + BALL_R, _ball_z()))
	t.state = "rest"
	t.held_hand = -1


func _make_pin(i: int, k: int) -> Dictionary:
	var b := RigidBody3D.new()
	b.mass = PIN_MASS
	b.can_sleep = true
	b.linear_damp = 0.12
	b.angular_damp = 0.25
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	pm.bounce = 0.25
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.048
	cap.height = PIN_H
	cs.shape = cap
	cs.position = Vector3(0, PIN_H / 2.0, 0)
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = _pin_mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.25
	mi.material_override = m
	b.add_child(mi)
	add_child(b)
	return {"body": b, "k": k, "alive": true, "home": _pin_home(i, k)}


func _pin_home(i: int, k: int) -> Vector3:
	# rows of 1, 2, 3 and 4 pins, the head pin nearest the bowler
	var row := 0
	var idx := k
	while idx > row:
		idx -= row + 1
		row += 1
	var x := lane_x(i) + (float(idx) - float(row) / 2.0) * PIN_SPACING
	return Vector3(x, 0.006, ShackAnnex.HEAD_PIN_Z + float(row) * ROW_SPACING)


func _place_pins(i: int, all: bool) -> void:
	var s: Dictionary = lanes[i]
	for p in s.pins:
		if all or p.alive:
			if all:
				p.alive = true
				(p.body as Node3D).visible = true
				_pin_set(p, p.home)


func _pin_set(p: Dictionary, at: Vector3) -> void:
	var b := p.body as RigidBody3D
	b.freeze = true
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	b.global_transform = Transform3D(Basis.IDENTITY, at)
	p["thaw"] = 3


func _hide_pin(p: Dictionary) -> void:
	p.alive = false
	var b := p.body as RigidBody3D
	b.freeze = true
	b.global_transform = Transform3D(Basis.IDENTITY, Vector3(lane_x(0), -6.0, 5.0))
	(b as Node3D).visible = false


func _make_pin_mesh() -> ArrayMesh:
	# a lathe of the pin's outline: (radius, height) pairs, red neck stripes
	var prof := [[0.0, 0.0], [0.030, 0.0], [0.040, 0.02], [0.0475, 0.08], [0.0465, 0.12], [0.038, 0.17], [0.028, 0.215], [0.0255, 0.25], [0.029, 0.285], [0.0375, 0.32], [0.041, 0.345], [0.0375, 0.37], [0.02, 0.38], [0.0, 0.38]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 14
	for i in range(prof.size() - 1):
		var a: Array = prof[i]
		var b: Array = prof[i + 1]
		var red: bool = (float(a[1]) > 0.19 and float(a[1]) < 0.24) or (float(a[1]) > 0.255 and float(a[1]) < 0.27)
		var col := Color(0.8, 0.08, 0.1) if red else Color(0.96, 0.95, 0.9)
		for k in range(seg):
			var a0 := TAU * float(k) / float(seg)
			var a1 := TAU * float(k + 1) / float(seg)
			var p00 := Vector3(sin(a0) * float(a[0]), float(a[1]), cos(a0) * float(a[0]))
			var p01 := Vector3(sin(a1) * float(a[0]), float(a[1]), cos(a1) * float(a[0]))
			var p10 := Vector3(sin(a0) * float(b[0]), float(b[1]), cos(a0) * float(b[0]))
			var p11 := Vector3(sin(a1) * float(b[0]), float(b[1]), cos(a1) * float(b[0]))
			for tri in [[p00, p10, p11], [p00, p11, p01]]:
				var n: Vector3 = ((tri[1] - tri[0]) as Vector3).cross((tri[2] - tri[0]) as Vector3).normalized()
				for v in tri:
					st.set_color(col)
					st.set_normal(n)
					st.add_vertex(v)
	return st.commit()


# ---- picking up and throwing ----------------------------------------------------------------------------------
func things() -> Array:
	var out: Array = []
	for t in balls:
		if t.can_grab() and lanes[t.lane].state == "play" and lanes[t.lane].phase == "ready":
			out.append(t)
	return out


func hold_xf(_t: Throwable, hand_xf: Transform3D) -> Transform3D:
	return hand_xf * Transform3D(Basis.IDENTITY, Vector3(0, -0.02, -0.07))


func on_grab(t: Throwable, _hand: int) -> void:
	t.state = "held"
	var b := t.node as RigidBody3D
	b.freeze = true
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	sound.emit("pickup", t.world_pos(), 0.5)


func on_release(t: Throwable, _hand_xf: Transform3D, vel: Vector3, angv: Vector3, hand: int) -> void:
	var b := t.node as RigidBody3D
	var s: Dictionary = lanes[t.lane]
	var v := vel
	if v.length() > 11.0:
		v = v.normalized() * 11.0
	b.freeze = false
	b.linear_velocity = v
	var fwd := Vector3(v.x, 0, v.z)
	fwd = fwd.normalized() if fwd.length() > 0.5 else Vector3(0, 0, 1)
	var roll_spin := clampf(angv.dot(fwd), -14.0, 14.0)            # a twist of the wrist about the direction of the throw
	var side := Vector3.UP.cross(fwd)
	b.angular_velocity = Vector3.UP.cross(Vector3(v.x, 0, v.z)) / BALL_R + fwd * roll_spin
	s.hook = -roll_spin * HOOK_GAIN
	s.fwd = fwd
	t.state = "flying"
	t.t = 0.0
	s.phase = "rolling"
	s.t = 0.0
	s.still = 0.0
	s.standing_before = _standing(s)
	buzz.emit(hand, 0.4, 0.08)
	sound.emit("throw", t.node.global_position, 0.7)


# ---- controls -------------------------------------------------------------------------------------------------
func selector_targets() -> Array:
	var out: Array = []
	for i in range(lanes.size()):
		for nm in lanes[i].buttons:
			var bd: Dictionary = lanes[i].buttons[nm]
			out.append({"id": "g_b%d_%s" % [i, nm], "label": "", "xf": Transform3D.IDENTITY, "box": AABB(Vector3(float(bd.x) - 0.05, 1.04, float(bd.z) - 0.11), Vector3(0.12, 0.22, 0.22)), "colour": Color(1.0, 0.85, 0.3), "always": false})
	return out


func choose(id: String) -> bool:
	if not id.begins_with("g_b"):
		return false
	var i := int(id.substr(3, 1))
	var what := id.substr(5)
	if i < 0 or i >= lanes.size():
		return false
	var s: Dictionary = lanes[i]
	if what == "players" and s.state != "play":
		s.players = s.players % 4 + 1
	elif what == "go":
		_start(i)
	sound.emit("click", Vector3(lane_x(i), 1.1, ShackAnnex.FOUL_Z - 1.0), 0.5)
	_refresh_buttons(i)
	return true


func _refresh_buttons(i: int) -> void:
	var s: Dictionary = lanes[i]
	s.buttons.players.label.text = "PLAYERS\n%d" % s.players
	s.buttons.go.label.text = "RESTART" if s.state == "play" else "NEW GAME"


func _start(i: int) -> void:
	var s: Dictionary = lanes[i]
	s.state = "play"
	s.phase = "ready"
	s.cur = 0
	s.rolls = []
	for _p in range(s.players):
		s.rolls.append([])
	s.msg = "PLAYER 1 - GRAB THE BALL"
	_place_pins(i, true)
	_ball_home(s.ball)
	_refresh_buttons(i)


# ---- the game -----------------------------------------------------------------------------------------------------
func _standing(s: Dictionary) -> int:
	var n := 0
	for p in s.pins:
		if p.alive and _pin_up(p):
			n += 1
	return n


func _pin_up(p: Dictionary) -> bool:
	var b := p.body as RigidBody3D
	var up := b.global_transform.basis.y.y
	var d := Vector2(b.global_position.x - p.home.x, b.global_position.z - p.home.z).length()
	return up > 0.93 and b.global_position.y > -0.08 and d < 0.35


func tick(delta: float) -> void:
	for i in range(lanes.size()):
		var s: Dictionary = lanes[i]
		for p in s.pins:
			if int(p.get("thaw", 0)) > 0:
				p["thaw"] = int(p.thaw) - 1
				if int(p.thaw) == 0 and p.alive:
					(p.body as RigidBody3D).freeze = false
		var t: Throwable = s.ball
		if t.state == "held":
			continue
		if s.phase == "rolling" or s.phase == "settle":
			_follow(i, delta)
		_text(i)


func _follow(i: int, delta: float) -> void:
	var s: Dictionary = lanes[i]
	var b := s.ball.node as RigidBody3D
	s.t += delta
	var z := b.global_position.z
	# the hook: the lane's friction pulls a spinning ball sideways, mostly in the last half of the lane
	if s.phase == "rolling" and absf(s.hook) > 0.01 and z > ShackAnnex.FOUL_Z + 4.5 and z < ShackAnnex.HEAD_PIN_Z - 0.5 and b.global_position.y < 0.2:
		var side := Vector3.UP.cross(s.fwd).normalized()
		b.apply_central_force(side * clampf(s.hook, -HOOK_MAX, HOOK_MAX) * BALL_MASS)
	if s.phase == "rolling":
		var speed := b.linear_velocity.length()
		var done: bool = z > ShackAnnex.HEAD_PIN_Z + 1.2 or b.global_position.y < -0.15 or float(s.t) > 9.0
		if speed < 0.3:
			s.still += delta
		else:
			s.still = 0.0
		if done or s.still > 1.0:
			s.phase = "settle"
			s.t = 0.0
			s.still = 0.0
		return
	# settling: wait until everything has stopped moving
	var moving := false
	for p in s.pins:
		if p.alive:
			var pb := p.body as RigidBody3D
			if not pb.sleeping and (pb.linear_velocity.length() > 0.12 or pb.angular_velocity.length() > 0.5):
				moving = true
	if moving:
		s.still = 0.0
	else:
		s.still += delta
	if s.still > 0.9 or s.t > 7.0:
		_finish_ball(i)


func _finish_ball(i: int) -> void:
	var s: Dictionary = lanes[i]
	var after := _standing(s)
	var before: int = s.standing_before
	var knocked: int = before - after
	# pins that are down leave the lane
	for p in s.pins:
		if p.alive and not _pin_up(p):
			_hide_pin(p)
	(s.rolls[s.cur] as Array).append(knocked)
	var msg := "%d PIN%s" % [knocked, "" if knocked == 1 else "S"]
	if knocked == 10 and before == 10:
		msg = "STRIKE!"
	elif before < 10 and knocked == before and knocked > 0:
		msg = "SPARE!"
	elif knocked == 0:
		msg = "GUTTER BALL" if absf((s.ball.node as Node3D).global_position.x - lane_x(i)) > ShackAnnex.LANE_W / 2.0 else "MISSED"
	s.msg = "P%d: %s" % [s.cur + 1, msg]
	sound.emit("clear" if knocked == 10 else "hit", Vector3(lane_x(i), 0.6, ShackAnnex.HEAD_PIN_Z), 0.9)
	_next_ball(i)


func _next_ball(i: int) -> void:
	var s: Dictionary = lanes[i]
	var rolls: Array = s.rolls[s.cur]
	var st_after := BowlingScore.state(rolls)
	var st_before := BowlingScore.state(rolls.slice(0, rolls.size() - 1))
	var turn_over: bool = bool(st_after.done) or int(st_after.frame) != int(st_before.frame)
	if int(st_after.standing) == 10:
		_place_pins(i, true)                          # a strike, a spare, or the end of the frame: a fresh rack
	if turn_over:
		var all_done := true
		for q in range(s.players):
			if not BowlingScore.state(s.rolls[q]).done:
				all_done = false
		if all_done:
			s.state = "over"
			s.phase = "idle"
			var best := 0
			for q in range(s.players):
				if BowlingScore.total(s.rolls[q]) > BowlingScore.total(s.rolls[best]):
					best = q
			s.msg = ("PLAYER %d WINS  %d" % [best + 1, BowlingScore.total(s.rolls[best])]) if s.players > 1 else "FINAL SCORE  %d" % BowlingScore.total(s.rolls[0])
			sound.emit("chime", Vector3(lane_x(i), 2.0, ShackAnnex.FOUL_Z), 1.0)
			_ball_home(s.ball)
			_refresh_buttons(i)
			return
		var guard := 0
		s.cur = (s.cur + 1) % s.players
		while BowlingScore.state(s.rolls[s.cur]).done and guard < 5:
			s.cur = (s.cur + 1) % s.players
			guard += 1
		_place_pins(i, int(BowlingScore.state(s.rolls[s.cur]).standing) == 10)
	s.phase = "ready"
	_ball_home(s.ball)


func _text(i: int) -> void:
	var s: Dictionary = lanes[i]
	var txt := ""
	if s.state == "idle":
		txt = "LANE %d\nPOINT AT NEW GAME" % (i + 1)
	else:
		for p in range(s.players):
			var fr := BowlingScore.frames(s.rolls[p])
			var line := "%sP%d " % ["▶" if (p == s.cur and s.state == "play") else " ", p + 1]
			var cum := ""
			for f in fr:
				line += "%-3s " % f.text
				cum += "%-3s " % (str(f.total) if int(f.total) >= 0 else ".")
			txt += line + "\n" + "    " + cum + "\n"
		txt += s.msg
	(s.label as Label3D).text = txt
	(s.board as Label3D).text = txt
