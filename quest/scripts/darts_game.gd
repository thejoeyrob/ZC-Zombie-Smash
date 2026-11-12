class_name DartsGame
extends SportGame
## Darts on two regulation boards (radius 225 mm, treble and double rings 8 mm wide, bull 12.7 mm, throw line 2.37 m away, centre 1.73 m high).
## Real flight: the dart leaves your hand at your hand's speed and direction, falls under gravity and sticks if it lands point first. No aim help.
## 501 or 301 (double out) or Cricket (15-20 and the bull), one to four players taking turns of three darts at one board.

const ORDER := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
const MODES := ["501", "301", "CRICKET"]
const CRICKET := [20, 19, 18, 17, 16, 15, 25]
const R_DBULL := 0.00635
const R_BULL := 0.0159
const R_TRE_IN := 0.099
const R_TRE_OUT := 0.107
const R_DBL_IN := 0.162
const R_DBL_OUT := 0.170
const R_BOARD := 0.225
const R_SURROUND := 0.31
const GRAVITY := 9.8
const THROW_BOOST := 1.35

var boards: Array = []           # per board: the game's state (see _fresh)
var darts: Array = []            # Throwables
var _col_board := Color(0.06, 0.1, 0.08)
var _check_cache := {}


# ---- the board's scoring (static, so it can be tested) -----------------------------------------------------
## sx: metres to the right of the centre as the thrower sees it, sy: metres above it. Returns {number, mult, value, label}.
static func score_at(sx: float, sy: float) -> Dictionary:
	var r := sqrt(sx * sx + sy * sy)
	if r <= R_DBULL:
		return {"number": 25, "mult": 2, "value": 50, "label": "DBL BULL"}
	if r <= R_BULL:
		return {"number": 25, "mult": 1, "value": 25, "label": "BULL"}
	if r > R_DBL_OUT:
		return {"number": 0, "mult": 0, "value": 0, "label": "MISS"}
	var ang := rad_to_deg(atan2(sx, sy))
	if ang < 0.0:
		ang += 360.0
	var n: int = ORDER[int(floor((ang + 9.0) / 18.0)) % 20]
	var mult := 1
	var tag := "S"
	if r >= R_DBL_IN:
		mult = 2
		tag = "D"
	elif r >= R_TRE_IN and r <= R_TRE_OUT:
		mult = 3
		tag = "T"
	return {"number": n, "mult": mult, "value": n * mult, "label": "%s%d" % [tag, n]}


## The fewest darts that finish `score` with a double on the last one (up to `darts_left` darts). "" when there is no way.
func checkout(score: int, darts_left: int) -> String:
	if darts_left <= 0 or score < 2 or score > 170:
		return ""
	var key := "%d:%d" % [score, darts_left]
	if _check_cache.has(key):
		return _check_cache[key]
	var segs: Array = []
	for n in range(20, 0, -1):
		segs.append(["T%d" % n, n * 3, false])
	segs.append(["50", 50, true])
	for n in range(20, 0, -1):
		segs.append(["D%d" % n, n * 2, true])
	segs.append(["25", 25, false])
	for n in range(20, 0, -1):
		segs.append(["S%d" % n, n, false])
	var doubles: Array = []
	for s in segs:
		if s[2]:
			doubles.append(s)
	var out := ""
	for d in doubles:
		if d[1] == score:
			out = d[0]
			break
	if out == "" and darts_left >= 2:
		for a in segs:
			for d in doubles:
				if int(a[1]) + int(d[1]) == score:
					out = "%s %s" % [a[0], d[0]]
					break
			if out != "":
				break
	if out == "" and darts_left >= 3:
		for a in segs:
			for b in segs:
				for d in doubles:
					if int(a[1]) + int(b[1]) + int(d[1]) == score:
						out = "%s %s %s" % [a[0], b[0], d[0]]
						break
				if out != "":
					break
			if out != "":
				break
	_check_cache[key] = out
	return out


# ---- building ---------------------------------------------------------------------------------------------
func build(f: Font) -> void:
	font = f
	for b in range(ShackAnnex.DART_Z.size()):
		boards.append(_fresh())
		_build_board_extras(b)
		for k in range(3):
			var t := Throwable.new()
			t.kind = "dart"
			t.game = self
			t.lane = b
			t.slot = k
			t.radius = 0.11
			t.node = _make_dart(b)
			add_child(t.node)
			darts.append(t)
			_to_rack(t)


func _fresh() -> Dictionary:
	return {"mode": 0, "players": 1, "state": "idle", "cur": 0, "left": 3, "scores": [], "turn_start": 0, "marks": [], "points": [], "hits": [],
		"msg": "POINT AT START", "timer": 0.0, "last": "", "label": null, "buttons": {}, "winner": -1, "turn_total": 0}


func _board_z(b: int) -> float:
	return float(ShackAnnex.DART_Z[b])


func _rack_pos(b: int, k: int) -> Vector3:
	return Vector3(ShackAnnex.OCHE_X + 0.55, 1.03, _board_z(b) + 0.72 + (float(k) - 1.0) * 0.05)


func _build_board_extras(b: int) -> void:
	var z := _board_z(b)
	# the stand the darts wait on
	var iron := VRBuild.mat(Color(0.1, 0.1, 0.12), 0.4, 0.7)
	VRBuild.cylinder(self, 0.03, 0.98, Vector3(ShackAnnex.OCHE_X + 0.55, 0.49, z + 0.72), iron, 0.03, Vector3.ZERO, 12)
	VRBuild.cylinder(self, 0.16, 0.02, Vector3(ShackAnnex.OCHE_X + 0.55, 0.01, z + 0.72), iron, 0.16, Vector3.ZERO, 20)
	VRBuild.box(self, Vector3(0.22, 0.02, 0.26), Vector3(ShackAnnex.OCHE_X + 0.55, 1.0, z + 0.72), VRBuild.mat(Color(0.35, 0.05, 0.08), 0.6))
	# the chalkboard above the board and three buttons below it
	var bx := -ShackAnnex.HALF_W + 0.07
	VRBuild.box(self, Vector3(0.03, 0.62, 0.95), Vector3(bx, 2.5, z), VRBuild.mat(Color(0.34, 0.24, 0.14), 0.6))
	VRBuild.box(self, Vector3(0.035, 0.56, 0.89), Vector3(bx + 0.003, 2.5, z), VRBuild.mat(_col_board, 0.9))
	var lbl := VRBuild.label(self, "", 0.052, Vector3(bx + 0.025, 2.5, z), Color(0.93, 0.95, 0.88), Vector3(0, PI / 2, 0), 0, font, true)
	lbl.line_spacing = -4.0
	boards[b].label = lbl
	var names := ["mode", "players", "go"]
	for i in range(3):
		var zz := z + 0.34 - 0.34 * float(i)       # the thrower faces -x: their right is -z, so MODE is on their left
		VRBuild.box(self, Vector3(0.03, 0.12, 0.3), Vector3(bx + 0.015, 2.0, zz), VRBuild.mat(Color(0.2, 0.16, 0.1), 0.5))
		var bl := VRBuild.label(self, "", 0.04, Vector3(bx + 0.035, 2.0, zz), Color(1.0, 0.9, 0.5), Vector3(0, PI / 2, 0), 2, font, true)
		boards[b].buttons[names[i]] = {"label": bl, "z": zz}
	_refresh_buttons(b)


func _make_dart(b: int) -> Node3D:
	var n := Node3D.new()
	var steel := VRBuild.mat(Color(0.75, 0.76, 0.8), 0.3, 0.9)
	var col: Color = [Color(0.95, 0.2, 0.2), Color(0.2, 0.55, 1.0)][b % 2]
	var flight := VRBuild.mat(col, 0.5)
	flight.cull_mode = BaseMaterial3D.CULL_DISABLED
	var barrel := VRBuild.cylinder(n, 0.0033, 0.05, Vector3(0, 0, -0.03), steel, 0.0033, Vector3(PI / 2, 0, 0), 8)
	VRBuild.cylinder(n, 0.0004, 0.028, Vector3(0, 0, -0.068), steel, 0.0022, Vector3(PI / 2, 0, 0), 8)      # the point (top radius is the tip)
	VRBuild.cylinder(n, 0.0016, 0.045, Vector3(0, 0, 0.018), VRBuild.mat(Color(0.1, 0.1, 0.12), 0.5), 0.0016, Vector3(PI / 2, 0, 0), 6)
	for a in [0.0, PI / 2.0]:
		VRBuild.quad(n, Vector2(0.03, 0.04), Vector3(0, 0, 0.055), flight, Vector3(0, 0, a))
	barrel.name = "Barrel"
	return n


func _to_rack(t: Throwable) -> void:
	t.data.clear()
	t.vel = Vector3.ZERO
	t.t = 0.0
	t.state = "rest"
	t.held_hand = -1
	t.node.visible = true
	t.node.global_transform = Transform3D(Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP), _rack_pos(t.lane, t.slot))


func things() -> Array:
	var out: Array = []
	for t in darts:
		if t.can_grab() and boards[t.lane].state == "play" and boards[t.lane].left > 0 and not lane_busy(darts, t.lane):
			out.append(t)
	return out


func hold_xf(_t: Throwable, hand_xf: Transform3D) -> Transform3D:
	return hand_xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.0, -0.045))


func on_grab(t: Throwable, _hand: int) -> void:
	t.state = "held"
	sound.emit("pickup", t.world_pos(), 0.4)


func cancel_hold(t: Throwable) -> void:
	_to_rack(t)


func on_release(t: Throwable, _hand_xf: Transform3D, vel: Vector3, _angv: Vector3, hand: int) -> void:
	if boards[t.lane].state != "play" or boards[t.lane].left <= 0:
		_to_rack(t)
		return
	t.data.clear()
	t.data["hand"] = hand
	t.pos = t.node.global_position
	t.vel = vel * THROW_BOOST
	if t.vel.length() > 14.0:
		t.vel = t.vel.normalized() * 14.0
	t.state = "flying"
	t.t = 0.0
	t.data["bounced"] = false
	buzz.emit(hand, 0.2, 0.03)
	sound.emit("throw", t.pos, 0.3)


# ---- controls ------------------------------------------------------------------------------------------------
func selector_targets() -> Array:
	var out: Array = []
	var bx := -ShackAnnex.HALF_W + 0.07
	for b in range(boards.size()):
		for nm in boards[b].buttons:
			var zz: float = boards[b].buttons[nm].z
			out.append({"id": "g_d%d_%s" % [b, nm], "label": "", "xf": Transform3D.IDENTITY, "box": AABB(Vector3(bx, 1.92, zz - 0.15), Vector3(0.3, 0.16, 0.3)), "colour": Color(1.0, 0.85, 0.3), "always": false})
	return out


func choose(id: String) -> bool:
	if not id.begins_with("g_d"):
		return false
	var b := int(id.substr(3, 1))
	var what := id.substr(5)
	if b < 0 or b >= boards.size():
		return false
	var s: Dictionary = boards[b]
	if what == "mode" and s.state != "play":
		s.mode = (s.mode + 1) % MODES.size()
	elif what == "players" and s.state != "play":
		s.players = s.players % 4 + 1
	elif what == "go" and request_restart(s):
		_start(b)
	sound.emit("click", Vector3(-ShackAnnex.HALF_W + 0.5, 2.0, _board_z(b)), 0.5)
	_refresh_buttons(b)
	return true


func _refresh_buttons(b: int) -> void:
	var s: Dictionary = boards[b]
	s.buttons.mode.label.text = "MODE\n%s" % MODES[s.mode]
	s.buttons.players.label.text = "PLAYERS\n%d" % s.players
	s.buttons.go.label.text = "CONFIRM" if float(s.get("restart_left", 0.0)) > 0.0 else "RESTART" if s.state == "play" else "START"


func _start(b: int) -> void:
	var s: Dictionary = boards[b]
	s["restart_left"] = 0.0
	var np: int = s.players
	s.state = "play"
	s.cur = 0
	s.left = 3
	s.winner = -1
	s.hits = []
	s.last = ""
	s.turn_total = 0
	s.timer = 0.0
	s.scores = []
	s.marks = []
	s.points = []
	for i in range(np):
		s.scores.append(501 if s.mode == 0 else 301)
		s.marks.append([0, 0, 0, 0, 0, 0, 0])
		s.points.append(0)
	s.turn_start = s.scores[0]
	s.msg = "PLAYER 1 - THROW!"
	for t in darts:
		if t.lane == b:
			_to_rack(t)
	_refresh_buttons(b)


# ---- the game ---------------------------------------------------------------------------------------------------
func _record(b: int, hit: Dictionary) -> void:
	var s: Dictionary = boards[b]
	if s.state != "play" or s.left <= 0:
		return
	s.left -= 1
	s.hits.append(hit.label)
	s.last = hit.label
	var p: int = s.cur
	var done := false
	if s.mode < 2:
		var sc: int = s.scores[p] - int(hit.value)
		var ok_double: bool = int(hit.mult) == 2
		if sc < 0 or sc == 1 or (sc == 0 and not ok_double):
			s.scores[p] = s.turn_start               # bust: the turn's score is thrown away
			s.msg = "BUST!  BACK TO %d" % s.turn_start
			s.left = 0
			s.turn_total = 0
			s.last = s.msg
			sound.emit("hurt", Vector3(-ShackAnnex.HALF_W + 0.5, 1.7, _board_z(b)), 0.6)
		elif sc == 0:
			s.scores[p] = 0
			s.winner = p
			done = true
		else:
			s.scores[p] = sc
	else:
		var idx: int = CRICKET.find(int(hit.number))
		if idx >= 0:
			var marks: Array = s.marks[p]
			var add: int = hit.mult if hit.number != 25 else (2 if hit.mult == 2 else 1)
			for _m in range(add):
				if marks[idx] < 3:
					marks[idx] += 1
				else:
					var open := false
					for q in range(s.marks.size()):
						if q != p and s.marks[q][idx] < 3:
							open = true
					if open:
						s.points[p] += CRICKET[idx]
			if _cricket_won(s, p):
				s.winner = p
				done = true
	if s.mode < 2 and s.left > 0:
		s.turn_total = s.turn_start - int(s.scores[p])
	if done:
		s.state = "over"
		s.msg = "PLAYER %d WINS!" % (p + 1)
		s.timer = 0.0
		_refresh_buttons(b)
		sound.emit("chime", Vector3(-ShackAnnex.HALF_W + 0.8, 1.8, _board_z(b)), 1.0)
		for t in darts:
			if t.lane == b and t.state == "rest":
				t.node.visible = false
	elif s.left == 0:
		s.timer = 2.4


func _cricket_won(s: Dictionary, p: int) -> bool:
	for m in s.marks[p]:
		if m < 3:
			return false
	for q in range(s.points.size()):
		if q != p and s.points[q] > s.points[p]:
			return false
	return true


func _next_turn(b: int) -> void:
	var s: Dictionary = boards[b]
	s.cur = (s.cur + 1) % s.players
	s.left = 3
	s.hits = []
	s.last = ""
	s.turn_total = 0
	if s.mode < 2:
		s.turn_start = s.scores[s.cur]
	s.msg = "PLAYER %d - THROW!" % (s.cur + 1)
	for t in darts:
		if t.lane == b:
			_to_rack(t)


func tick(delta: float) -> void:
	for b in range(boards.size()):
		var s: Dictionary = boards[b]
		if tick_restart(s, delta):
			_refresh_buttons(b)
		if s.state == "play" and s.left == 0 and s.timer > 0.0:
			# wait for the last dart to land, then clear the board for the next player
			var busy := false
			for t in darts:
				if t.lane == b and t.state == "flying":
					busy = true
			if not busy:
				s.timer -= delta
				if s.timer <= 0.0:
					_next_turn(b)
		_text(b)
	for t in darts:
		if t.state == "held":
			continue
		if t.state == "flying":
			_fly(t, delta)


func _fly(t: Throwable, delta: float) -> void:
	var steps := maxi(1, ceili(delta / 0.004))
	var h := delta / float(steps)
	var face := ShackAnnex.DART_FACE_X
	for _i in range(steps):
		var prev_tip := t.pos + _fwd(t) * 0.075
		t.vel.y -= GRAVITY * h
		t.vel *= 1.0 - 0.08 * h
		t.pos += t.vel * h
		t.t += h
		var tip := t.pos + _fwd(t) * 0.075
		if prev_tip.x > face and tip.x <= face and not t.data.get("bounced", false):
			var u := (prev_tip.x - face) / maxf(prev_tip.x - tip.x, 0.00001)
			var hit := prev_tip.lerp(tip, u)
			_hit_board(t, hit)
			if t.state != "flying":
				return
		if t.pos.y < 0.03:
			t.state = "down"
			t.pos.y = 0.03
			_settle(t)
			if t.data.get("scored", false) == false:
				_record(t.lane, {"label": "MISS", "value": 0, "mult": 0, "number": 0})
				t.data["scored"] = true
			sound.emit("click", t.pos, 0.3)
			return
		if t.pos.x < -ShackAnnex.HALF_W + 0.06 or t.pos.x > ShackAnnex.HALF_W - 0.1 or t.pos.z < ShackAnnex.Z0 + 0.1 or t.pos.z > ShackAnnex.Z1 - 0.1 or t.pos.y > ShackAnnex.HEIGHT - 0.05:
			t.vel = Vector3(absf(t.vel.x) * 0.2 if t.pos.x < 0 else -absf(t.vel.x) * 0.2, minf(t.vel.y, 0.0), t.vel.z * 0.2)
			t.pos = Vector3(clampf(t.pos.x, -ShackAnnex.HALF_W + 0.07, ShackAnnex.HALF_W - 0.12), minf(t.pos.y, ShackAnnex.HEIGHT - 0.06), clampf(t.pos.z, ShackAnnex.Z0 + 0.12, ShackAnnex.Z1 - 0.12))
		if t.t > 4.0:
			t.state = "down"
			if not t.data.get("scored", false):
				_record(t.lane, {"label": "MISS", "value": 0, "mult": 0, "number": 0})
				t.data["scored"] = true
			_settle(t)
			return
	_pose(t)


func _fwd(t: Throwable) -> Vector3:
	if t.vel.length() > 0.5:
		return t.vel.normalized()
	return Vector3(-1, -0.2, 0).normalized()


func _pose(t: Throwable) -> void:
	t.node.global_transform = Transform3D(Basis.looking_at(_fwd(t), Vector3.UP), t.pos)


func _hit_board(t: Throwable, hit: Vector3) -> void:
	var b := t.lane
	var bz := _board_z(b)
	if absf(hit.z - bz) > R_SURROUND + 0.05 or absf(hit.y - ShackAnnex.DART_Y) > R_SURROUND + 0.05:
		return                                  # missed the board and its cabinet: carries on to the wall
	var sx := -(hit.z - bz)                     # the thrower faces -x, so their right is -z
	var sy := hit.y - ShackAnnex.DART_Y
	var r := sqrt(sx * sx + sy * sy)
	var f := _fwd(t)
	var nose_in := -f.x                         # 1 = straight at the board
	var speed := t.vel.length()
	t.data["bounced"] = true
	if r <= R_BOARD and nose_in > 0.4 and speed > 1.6:
		# a clean landing: the dart stays where its point went in
		var sc := score_at(sx, sy)
		var dir := Vector3(-1, 0, 0).lerp(f, 0.35).normalized()
		t.vel = Vector3.ZERO
		t.state = "stuck"
		t.pos = hit + dir * 0.012 - dir * 0.075
		t.data["dir"] = dir
		t.node.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), t.pos)
		t.data["scored"] = true
		_record(b, sc)
		sound.emit("target", hit, 0.9)
		buzz.emit(int(t.data.get("hand", 0)), 0.1, 0.02)
		return
	# it bounces off (wire, surround, a flat landing or a weak throw) and falls
	t.vel = Vector3(absf(t.vel.x) * 0.2 + 0.4, minf(t.vel.y, 0.0) * 0.3, t.vel.z * 0.3)
	t.data["scored"] = true
	_record(b, {"label": "BOUNCE", "value": 0, "mult": 0, "number": 0})
	sound.emit("ricochet", hit, 0.6)


func _settle(t: Throwable) -> void:
	t.node.global_transform = Transform3D(Basis.looking_at(Vector3(-1, -0.0, 0.3).normalized(), Vector3.UP), t.pos)


# ---- the chalkboard ------------------------------------------------------------------------------------------
func _text(b: int) -> void:
	var s: Dictionary = boards[b]
	var lbl := s.label as Label3D
	if lbl == null:
		return
	if s.state == "idle":
		lbl.text = "DARTS\n%s  •  %d PLAYER%s\nPOINT AT START" % [MODES[s.mode], s.players, "" if s.players == 1 else "S"]
		return
	var t := ""
	if s.mode < 2:
		t = "%s  DOUBLE OUT\n" % MODES[s.mode]
		for i in range(s.players):
			t += "%s P%d  %d\n" % ["▶" if (i == s.cur and s.state == "play") else " ", i + 1, s.scores[i]]
		if s.state == "play":
			var co := checkout(int(s.scores[s.cur]), maxi(int(s.left), 1)) if s.left > 0 else ""
			t += ("OUT: " + co) if co != "" else ("LAST %s" % s.last if s.last != "" else s.msg)
		else:
			t += s.msg
	else:
		t = "CRICKET  "
		for i in range(s.players):
			t += "%sP%d:%d " % ["▶" if (i == s.cur and s.state == "play") else "", i + 1, s.points[i]]
		t += "\n"
		for k in range(CRICKET.size()):
			var line := "%s " % ("BULL" if CRICKET[k] == 25 else str(CRICKET[k]))
			for i in range(s.players):
				line += "%s " % ["·", "/", "X", "◉"][mini(int(s.marks[i][k]), 3)]
			t += line + ("  " if k % 2 == 0 else "\n")
		t += s.msg
	if s.state == "play":
		t += "\n%d DART%s LEFT  |  %s" % [s.left, "" if s.left == 1 else "S", "  ".join(s.hits)]
	if lbl.text != t:
		lbl.text = t
