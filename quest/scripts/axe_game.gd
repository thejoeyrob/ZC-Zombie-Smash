class_name AxeGame
extends SportGame
## Axe throwing, as in the leagues: three lanes, targets 3.66 m (12 feet) away, rings worth 1 to 5 from the outside in, a blue bullseye (5) and two
## blue clutch dots in the top corners worth 7. The axe turns head over handle after you let go: it sticks only if the blade is facing the board
## when it arrives, so the number of turns it makes (set by how hard and how far you throw, and by how you flick your wrist) is the whole skill.
## Modes: CLASSIC (best total over three turns of three axes) and BULLSEYE BLITZ (hit the bull or a clutch in a row to build a combo).

const MODES := ["CLASSIC", "BULLSEYE BLITZ"]
const RINGS := [0.076, 0.152, 0.229, 0.305, 0.381]      # outer edge of the 5, 4, 3, 2 and 1 rings (metres from the target's centre)
const CENTRE_DROP := 0.06                               # the painted centre sits this far below the board's middle
const CLUTCH_X := 0.33
const CLUTCH_Y := 0.31
const CLUTCH_R := 0.045
const GRAVITY := 9.8
const ROUNDS := 3
const PER_TURN := 3
const BLADE_EDGE := Vector3(0, 0.255, -0.12)             # the middle of the cutting edge, from the grip point

var lanes: Array = []
var axes: Array = []


# ---- scoring and the stick rule (static, so they can be tested) -----------------------------------------------
## dx: metres to the right of the target's painted centre as the thrower sees it, dy: metres above it. Returns {value, label, bull}.
static func score_at(dx: float, dy: float) -> Dictionary:
	for sgn in [-1.0, 1.0]:
		var cx: float = float(sgn) * CLUTCH_X
		if sqrt((dx - cx) * (dx - cx) + (dy - CLUTCH_Y) * (dy - CLUTCH_Y)) <= CLUTCH_R + 0.02:
			return {"value": 7, "label": "CLUTCH 7", "bull": true}
	var r := sqrt(dx * dx + dy * dy)
	for i in range(RINGS.size()):
		if r <= float(RINGS[i]):
			var pts: int = [5, 4, 3, 2, 1][i]
			return {"value": pts, "label": "BULLSEYE 5" if i == 0 else "%d" % pts, "bull": i == 0}
	return {"value": 0, "label": "MISS", "bull": false}


## Does an axe arriving with this attitude bite? blade_dir: where the cutting edge faces; handle: along the handle (head end); v_dir: its direction of travel.
static func can_stick(blade_dir: Vector3, handle: Vector3, v_dir: Vector3, speed: float) -> bool:
	return speed > 3.0 and blade_dir.dot(v_dir) > 0.79 and absf(handle.x) < 0.5 and absf(handle.y) > 0.6


# ---- building ---------------------------------------------------------------------------------------------------
func build(f: Font) -> void:
	font = f
	for i in range(ShackAnnex.AXE_X.size()):
		lanes.append(_fresh())
		_build_lane(i)
		for k in range(PER_TURN):
			var t := Throwable.new()
			t.kind = "axe"
			t.game = self
			t.lane = i
			t.slot = k
			t.radius = 0.17
			t.node = _make_axe()
			add_child(t.node)
			axes.append(t)
			_to_rack(t)


func _fresh() -> Dictionary:
	return {"mode": 0, "players": 1, "state": "idle", "cur": 0, "round": 0, "thrown": 0, "scores": [], "combo": 0, "timer": 0.0, "label": null, "buttons": {}, "msg": "", "last": ""}


func _rack_z() -> float:
	return ShackAnnex.AXE_LINE_Z - 1.25


func _lane_x(i: int) -> float:
	return float(ShackAnnex.AXE_X[i])


func _build_lane(i: int) -> void:
	var x := _lane_x(i)
	var wood := VRBuild.mat(Color(0.2, 0.13, 0.08), 0.6)
	VRBuild.box(self, Vector3(0.8, 0.9, 0.4), Vector3(x, 0.45, _rack_z()), wood)
	VRBuild.box(self, Vector3(0.84, 0.04, 0.44), Vector3(x, 0.92, _rack_z()), VRBuild.mat(Color(0.3, 0.2, 0.12), 0.6))
	# the board above the targets: scores
	var lbl := VRBuild.label(self, "", 0.06, Vector3(x, 2.5, ShackAnnex.AXE_FACE_Z - 0.09), Color(1.0, 0.95, 0.8), Vector3(0, PI, 0), 3, font, true)
	lbl.line_spacing = -6.0
	lanes[i].label = lbl
	# a panel with three buttons beside the rack, facing the thrower
	VRBuild.box(self, Vector3(0.82, 0.2, 0.04), Vector3(x, 1.3, _rack_z() + 0.24), VRBuild.mat(Color(0.1, 0.08, 0.1), 0.5))
	var names := ["mode", "players", "go"]
	for k in range(3):
		var bx := x - (float(k) - 1.0) * 0.27
		var bl := VRBuild.label(self, "", 0.036, Vector3(bx, 1.3, _rack_z() + 0.22), Color(1.0, 0.85, 0.4), Vector3(0, PI, 0), 2, font, true)
		lanes[i].buttons[names[k]] = {"label": bl, "x": bx}
	_refresh_buttons(i)


func _make_axe() -> Node3D:
	var n := Node3D.new()
	var wood := VRBuild.mat(Color(0.5, 0.33, 0.18), 0.6)
	var steel := VRBuild.mat(Color(0.62, 0.64, 0.7), 0.3, 0.85)
	var edge := VRBuild.mat(Color(0.9, 0.92, 0.95), 0.2, 0.95)
	VRBuild.cylinder(n, 0.017, 0.40, Vector3(0, 0.1, 0), wood, 0.014, Vector3.ZERO, 10)                  # the handle, from just below the grip to the head
	VRBuild.box(n, Vector3(0.04, 0.09, 0.05), Vector3(0, 0.26, 0.0), steel)                                  # the poll and eye of the head
	VRBuild.box(n, Vector3(0.018, 0.11, 0.1), Vector3(0, 0.255, -0.065), steel)                              # the blade
	VRBuild.box(n, Vector3(0.006, 0.13, 0.012), Vector3(0, 0.255, -0.118), edge)                             # the cutting edge
	return n


func _rest_xf(t: Throwable) -> Transform3D:
	var x := _lane_x(t.lane) + (float(t.slot) - 1.0) * 0.23
	# lying on the rack with the head toward the targets and the blade up
	return Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(x, 0.96, _rack_z() - 0.1))


func _to_rack(t: Throwable) -> void:
	t.state = "rest"
	t.held_hand = -1
	t.node.visible = true
	t.node.global_transform = _rest_xf(t)


func things() -> Array:
	var out: Array = []
	for t in axes:
		if t.can_grab() and lanes[t.lane].state == "play" and lanes[t.lane].thrown < PER_TURN:
			out.append(t)
	return out


func hold_xf(_t: Throwable, hand_xf: Transform3D) -> Transform3D:
	return hand_xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.0, -0.03))


func on_grab(t: Throwable, _hand: int) -> void:
	t.state = "held"
	sound.emit("pickup", t.world_pos(), 0.5)


func on_release(t: Throwable, hand_xf: Transform3D, vel: Vector3, angv: Vector3, hand: int) -> void:
	t.pos = t.node.global_position
	t.basis = hand_xf.basis.orthonormalized()
	t.vel = vel * 1.25
	var sp := t.vel.length()
	if sp > 16.0:
		t.vel = t.vel.normalized() * 16.0
		sp = 16.0
	var d := t.vel.normalized() if sp > 0.2 else Vector3(0, 0, 1)
	var side := Vector3.UP.cross(d)
	if side.length() < 0.2:
		side = Vector3.RIGHT
	side = side.normalized()
	t.data["side"] = side
	# the turn the axe was given by your wrist; with a gentle or straight push it still tumbles about once per 3.7 m, like a natural throw
	var w := angv.dot(side)
	if absf(w) < 3.0:
		w = TAU * maxf(sp, 3.0) / 3.66
	t.spin = clampf(w, 2.0, 26.0)
	t.state = "flying"
	t.t = 0.0
	t.data["scored"] = false
	lanes[t.lane].thrown += 1
	buzz.emit(hand, 0.3, 0.05)
	sound.emit("throw", t.pos, 0.6)


# ---- controls ------------------------------------------------------------------------------------------------------
func selector_targets() -> Array:
	var out: Array = []
	for i in range(lanes.size()):
		for nm in lanes[i].buttons:
			var bx: float = lanes[i].buttons[nm].x
			out.append({"id": "g_a%d_%s" % [i, nm], "label": "", "xf": Transform3D.IDENTITY, "box": AABB(Vector3(bx - 0.13, 1.2, _rack_z() + 0.1), Vector3(0.26, 0.2, 0.3)), "colour": Color(1.0, 0.7, 0.3), "always": false})
	return out


func choose(id: String) -> bool:
	if not id.begins_with("g_a"):
		return false
	var i := int(id.substr(3, 1))
	var what := id.substr(5)
	if i < 0 or i >= lanes.size():
		return false
	var s: Dictionary = lanes[i]
	if what == "mode" and s.state != "play":
		s.mode = (s.mode + 1) % MODES.size()
	elif what == "players" and s.state != "play":
		s.players = s.players % 4 + 1
	elif what == "go":
		_start(i)
	sound.emit("click", Vector3(_lane_x(i), 1.3, _rack_z()), 0.5)
	_refresh_buttons(i)
	return true


func _refresh_buttons(i: int) -> void:
	var s: Dictionary = lanes[i]
	s.buttons.mode.label.text = "MODE\n%s" % ("CLASSIC" if s.mode == 0 else "BLITZ")
	s.buttons.players.label.text = "PLAYERS\n%d" % s.players
	s.buttons.go.label.text = "RESTART" if s.state == "play" else "START"


func _start(i: int) -> void:
	var s: Dictionary = lanes[i]
	s.state = "play"
	s.cur = 0
	s.round = 0
	s.thrown = 0
	s.combo = 0
	s.timer = 0.0
	s.last = ""
	s.scores = []
	for _p in range(s.players):
		s.scores.append(0)
	s.msg = "PLAYER 1"
	for t in axes:
		if t.lane == i:
			_to_rack(t)
	_refresh_buttons(i)


func _score_throw(t: Throwable, hit: Dictionary) -> void:
	var s: Dictionary = lanes[t.lane]
	var pts: int = hit.value
	if s.mode == 1:
		if hit.bull:
			s.combo += 1
			pts = (10 if hit.value == 5 else 14) * mini(s.combo, 5)
		else:
			s.combo = 0
			pts = hit.value
	s.scores[s.cur] += pts
	s.last = "%s  +%d" % [hit.label, pts]
	sound.emit("target" if hit.value > 0 else "click", t.pos, 0.8)


func tick(delta: float) -> void:
	for i in range(lanes.size()):
		var s: Dictionary = lanes[i]
		if s.state == "play" and s.thrown >= PER_TURN:
			var busy := false
			for t in axes:
				if t.lane == i and t.state == "flying":
					busy = true
			if not busy:
				s.timer += delta
				if s.timer > 2.6:
					_next_turn(i)
		_text(i)
	for t in axes:
		if t.state == "flying":
			_fly(t, delta)


func _next_turn(i: int) -> void:
	var s: Dictionary = lanes[i]
	s.timer = 0.0
	s.thrown = 0
	s.combo = 0
	s.cur += 1
	if s.cur >= s.players:
		s.cur = 0
		s.round += 1
	if s.round >= ROUNDS:
		s.state = "over"
		var best := 0
		for p in range(s.players):
			if s.scores[p] > s.scores[best]:
				best = p
		s.msg = "PLAYER %d WINS  %d" % [best + 1, s.scores[best]] if s.players > 1 else "FINAL SCORE  %d" % s.scores[0]
		sound.emit("chime", Vector3(_lane_x(i), 2.0, ShackAnnex.AXE_LINE_Z), 1.0)
		_refresh_buttons(i)
	else:
		s.msg = "PLAYER %d" % (s.cur + 1)
	for t in axes:
		if t.lane == i:
			_to_rack(t)
			if s.state == "over":
				t.node.visible = false


func _fly(t: Throwable, delta: float) -> void:
	var steps := maxi(1, ceili(delta / 0.004))
	var h := delta / float(steps)
	var side: Vector3 = t.data.get("side", Vector3.RIGHT)
	var plane := ShackAnnex.AXE_FACE_Z - 0.07
	for _i in range(steps):
		var prev_edge := t.pos + t.basis * BLADE_EDGE
		t.vel.y -= GRAVITY * h
		t.pos += t.vel * h
		t.basis = (Basis(side, t.spin * h) * t.basis).orthonormalized()
		t.t += h
		var edge := t.pos + t.basis * BLADE_EDGE
		if prev_edge.z < plane and edge.z >= plane and not t.data.get("hit", false):
			t.data["hit"] = true
			_arrive(t, prev_edge, edge, plane)
			if t.state != "flying":
				return
		if t.pos.y < 0.05:
			t.state = "down"
			t.node.global_transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0 * 3.0) * Basis(Vector3.UP, atan2(t.vel.x, t.vel.z)), Vector3(t.pos.x, 0.03, t.pos.z))
			if not t.data.get("scored", false):
				t.data["scored"] = true
				lanes[t.lane].last = "NO STICK"
				sound.emit("hit", t.pos, 0.5)
			return
		if t.pos.x < -ShackAnnex.HALF_W + 0.1 or t.pos.x > ShackAnnex.HALF_W - 0.1 or t.pos.z < ShackAnnex.Z0 + 0.15 or t.pos.y > ShackAnnex.HEIGHT - 0.1:
			t.vel.x *= -0.3
			t.vel.z = absf(t.vel.z) * 0.2 if t.pos.z < 10 else t.vel.z * 0.3
			t.pos.x = clampf(t.pos.x, -ShackAnnex.HALF_W + 0.11, ShackAnnex.HALF_W - 0.11)
			t.pos.y = minf(t.pos.y, ShackAnnex.HEIGHT - 0.11)
		if t.t > 5.0:
			t.state = "down"
			return
	t.node.global_transform = Transform3D(t.basis, t.pos)


func _arrive(t: Throwable, prev_edge: Vector3, edge: Vector3, plane: float) -> void:
	var u := (plane - prev_edge.z) / maxf(edge.z - prev_edge.z, 0.00001)
	var hit := prev_edge.lerp(edge, u)
	var blade_dir: Vector3 = t.basis * Vector3(0, 0, -1)
	var handle: Vector3 = t.basis * Vector3(0, 1, 0)
	var speed := t.vel.length()
	# which target did it reach?
	var lane := -1
	for k in range(lanes.size()):
		if absf(hit.x - _lane_x(k)) < 0.6 and absf(hit.y - ShackAnnex.AXE_Y) < 0.6:
			lane = k
	if lane >= 0 and can_stick(blade_dir, handle, t.vel.normalized(), speed):
		var dx := -(hit.x - _lane_x(lane))          # the thrower faces +z: their right is -x
		var dy := hit.y - (ShackAnnex.AXE_Y - CENTRE_DROP)
		t.state = "stuck"
		t.vel = Vector3.ZERO
		var b := Basis.looking_at(Vector3(0, 0, 1), Vector3.UP)
		t.node.global_transform = Transform3D(b, hit - b * BLADE_EDGE + Vector3(0, 0, 0.035))
		t.data["scored"] = true
		_score_throw(t, score_at(dx, dy))
		buzz.emit(0, 0.7, 0.08)
		buzz.emit(1, 0.7, 0.08)
		return
	# it hits flat, handle first, or the wall beside the targets: it falls
	t.vel = Vector3(t.vel.x * 0.2, t.vel.y * 0.2, -absf(t.vel.z) * 0.22)
	t.spin = -t.spin * 0.4
	t.data["scored"] = true
	lanes[t.lane].last = "NO STICK"
	if lanes[t.lane].mode == 1:
		lanes[t.lane].combo = 0
	sound.emit("ricochet", hit, 0.7)
	buzz.emit(0, 0.25, 0.04)
	buzz.emit(1, 0.25, 0.04)


func _text(i: int) -> void:
	var s: Dictionary = lanes[i]
	var lbl := s.label as Label3D
	if lbl == null:
		return
	if s.state == "idle":
		lbl.text = "LANE %d  •  %s\nGRAB AN AXE, STAND AT THE LINE\nPOINT AT START" % [i + 1, MODES[s.mode]]
		return
	var t := "%s  •  ROUND %d/%d\n" % [MODES[s.mode], mini(s.round + 1, ROUNDS), ROUNDS]
	for p in range(s.players):
		t += "%s P%d  %d\n" % ["▶" if (p == s.cur and s.state == "play") else " ", p + 1, s.scores[p]]
	if s.mode == 1 and s.combo > 1 and s.state == "play":
		t += "COMBO x%d\n" % s.combo
	t += s.last if s.last != "" and s.state == "play" else s.msg
	lbl.text = t
