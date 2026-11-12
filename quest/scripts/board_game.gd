class_name BoardGame
extends Node3D
## The lounge board game: Frustration (UK) / Trouble (US). Four players, four pegs each, a loop of 28 spaces round the board and a four-space
## home lane for each player. Roll a 6 to bring a peg out onto your start space (and roll again); land on another player's peg and it goes back
## home; you cannot land on your own peg; you need the exact number to finish. First to fill all four holes of their lane wins.
## Four seats, one per stool. A seat nobody sits on is played by the computer, so the game always runs. In a room the server runs the game
## (server/board.mjs, the same rules); on your own this script does. A peg's place: -1 home, 0..27 on the loop from its start, 28..31 in its lane.

signal event(name: String)

const LOOP := 28
const LANE_END := 31
const MARGIN := 72.0
const CELL := 110.0
const PIC := 1024.0
const BOARD_M := 0.76             # the picture is this many metres across on the table
const START := [24, 3, 10, 17]    # the loop space each seat's pegs start on
const LANES := [[[5, 6], [5, 5], [5, 4], [5, 3]], [[1, 5], [2, 5], [3, 5], [4, 5]], [[2, 1], [2, 2], [2, 3], [2, 4]], [[6, 2], [5, 2], [4, 2], [3, 2]]]
const HOMES := [[[1, 6], [2, 6], [3, 6], [4, 6]], [[1, 1], [1, 2], [1, 3], [1, 4]], [[3, 1], [4, 1], [5, 1], [6, 1]], [[6, 3], [6, 4], [6, 5], [6, 6]]]
const NAMES := ["DEBO", "DR MANTIS", "DISCO MAN", "FAT AMY"]          # the computer player in each seat
const COLOURS := [Color(0.34, 0.85, 0.27), Color(0.95, 0.2, 0.2), Color(1.0, 0.63, 0.14), Color(0.68, 0.45, 0.98)]   # match the stools: green, red, amber, purple
const PIECES := ["GREEN PEGS", "RED PEGS", "AMBER PEGS", "PURPLE PEGS"]
const TOP_Y := 0.0               # pegs stand on the board surface (this node sits on it)

var players: Array = []          # {name, pegs: [4], occupant, wins, human}
var peg_nodes: Array = []        # [seat][peg] -> Node3D
var last_occupant: Array = ["", "", "", ""]   # who sat in each seat most recently
var current := 0
var waiting_for_roll := false
var busy := false
var message := ""
var winner := -1
var rng := RandomNumberGenerator.new()
var authority := true
var local_id := "local"
var phase := "wait"              # wait (roll the die), move (pick a peg), pass (nothing can move), after (a move just made), win
var remaining := 1.6
var again := false
var round_number := 1
var die_value := 1
var tries := 3
var legal: Array = []
var auto_human := false           # the tour video plays the human seat by itself
var _die: Node3D
var _dome: MeshInstance3D
var _label: Label3D
var _font: Font
var _roll_t := 9.0
var _seen_die_key := ""
var _t := 0.0


func build(font: Font) -> void:
	_font = font
	rng.randomize()
	for i in range(NAMES.size()):
		players.append({"name": NAMES[i], "pegs": [-1, -1, -1, -1], "occupant": "", "wins": 0, "human": false})
		var row: Array = []
		for k in range(4):
			var peg := _make_peg(i)
			add_child(peg)
			row.append(peg)
		peg_nodes.append(row)
	_die = _make_die()
	_die.visible = false
	add_child(_die)
	_make_dome()
	_label = VRBuild.label(self, "", 0.045, Vector3(0, 0.34, 0), Color(1, 1, 1), Vector3.ZERO, 8, font)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 6
	_reset_game()


# ---- where things are ---------------------------------------------------------------------------------
static func _cell_of(n: int) -> Vector2i:
	n = n % LOOP
	if n < 8:
		return Vector2i(0, 7 - n)                 # up the left edge: (column, row)
	if n < 15:
		return Vector2i(n - 7, 0)                 # along the top
	if n < 22:
		return Vector2i(7, n - 14)                # down the right edge
	return Vector2i(7 - (n - 21), 7)              # back along the bottom


func cell_pos(c: int, r: int) -> Vector3:
	var k := BOARD_M / PIC
	return Vector3((MARGIN + (float(c) + 0.5) * CELL - PIC / 2.0) * k, TOP_Y, (MARGIN + (float(r) + 0.5) * CELL - PIC / 2.0) * k)


## Local position (on the board surface) of a peg: in its home area, on the loop, or in its lane.
func peg_pos(seat: int, peg: int, place: int) -> Vector3:
	if place < 0:
		var h: Array = HOMES[seat][peg]
		return cell_pos(h[0], h[1])
	if place >= LOOP:
		var l: Array = LANES[seat][place - LOOP]
		return cell_pos(l[0], l[1])
	var c := _cell_of(int(START[seat]) + place)
	return cell_pos(c.x, c.y)


func square_pos(i: int, _slot := 0) -> Vector3:
	var c := _cell_of(i)
	return cell_pos(c.x, c.y)


# ---- seats ------------------------------------------------------------------------------------------
## Someone sits in a seat: they play those pegs from wherever they are now. Returns false if someone else is already there.
func take_seat(seat: int, occupant: String, display_name := "YOU") -> bool:
	if seat < 0 or seat >= players.size():
		return false
	var p: Dictionary = players[seat]
	if p.occupant != "" and p.occupant != occupant:
		return false
	leave_seat(occupant)                     # one seat per person
	p.occupant = occupant
	p.human = true
	if current == seat and phase == "wait":
		remaining = 25.0
	p.name = display_name
	last_occupant[seat] = occupant
	_say("%s TAKES THE %s" % [display_name, PIECES[seat]])
	return true


## Someone stands up: the computer takes the pegs back and carries on.
func leave_seat(occupant: String) -> void:
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p.occupant == occupant:
			p.occupant = ""
			p.human = false
			p.name = NAMES[i]
			if current == i and phase in ["wait", "move"]:
				remaining = minf(remaining, 1.6)


## The seat this person should get: the one they had before if it is free, otherwise the given one.
func seat_for(occupant: String, wanted: int) -> int:
	var prev := last_occupant.find(occupant)
	if prev >= 0 and prev != wanted and players[prev].occupant == "" and players[wanted].occupant != "":
		return prev
	return wanted


func seat_of(occupant: String) -> int:
	for i in range(players.size()):
		if players[i].occupant == occupant:
			return i
	return -1


# ---- what the player can do ---------------------------------------------------------------------------
func my_turn() -> bool:
	return current == seat_of(local_id)


func hint() -> String:
	if not my_turn():
		return ""
	if phase == "wait":
		return "ROLL"
	if phase == "move" and legal.size() > 1:
		return "PICK A PEG"
	return ""


## The pegs you may pick right now (when there is a choice).
func choosing() -> bool:
	return phase == "move" and my_turn() and legal.size() > 1


func roll_human(_dash := false) -> void:
	if authority and phase == "wait" and players[current].occupant == local_id:
		_do_roll()


func move_human(peg: int) -> void:
	if authority and phase == "move" and players[current].occupant == local_id and legal.has(peg):
		_do_move(peg)


func peg_world(seat: int, peg: int) -> Vector3:
	return global_transform * peg_nodes[seat][peg].position


# ---- the rules (the same as server/board.mjs) -----------------------------------------------------------
func _reset_game() -> void:
	winner = -1
	current = 0
	again = false
	tries = 3
	legal = []
	for i in range(players.size()):
		players[i].pegs = [-1, -1, -1, -1]
	phase = "wait"
	remaining = 1.6
	_say("FRUSTRATION!  SIT ON A STOOL TO PLAY")
	_place_all(true)


func _on_board(p: Dictionary) -> bool:
	for r in p.pegs:
		if int(r) >= 0:
			return true
	return false


static func abs_space(seat: int, rel: int) -> int:
	return (int(START[seat]) + rel) % LOOP


func legal_moves() -> Array:
	var out: Array = []
	var p: Dictionary = players[current]
	for k in range(4):
		var r: int = p.pegs[k]
		var t := 0
		if r < 0:
			if die_value != 6:
				continue
		else:
			t = r + die_value
			if t > LANE_END:
				continue
		var blocked := false
		for j in range(4):
			if j != k and int(p.pegs[j]) == t:
				blocked = true
		if not blocked:
			out.append(k)
	return out


func _say(t: String) -> void:
	message = t
	if _label != null:
		_label.text = t


func _do_roll() -> void:
	var p: Dictionary = players[current]
	die_value = rng.randi_range(1, 6)
	legal = legal_moves()
	event.emit("roll")
	if legal.is_empty():
		phase = "pass"
		remaining = 1.4
		_say("%s ROLLS %d — NO MOVE" % [p.name, die_value])
		return
	phase = "move"
	remaining = 25.0 if (p.human and legal.size() > 1 and not auto_human) else 1.0
	_say("%s ROLLS %d%s" % [p.name, die_value, " — CHOOSE A PEG" if legal.size() > 1 else ""])


func ai_pick() -> int:
	var p: Dictionary = players[current]
	var best: int = legal[0]
	var best_score := -1
	for k in legal:
		var r: int = p.pegs[k]
		var t := 0 if r < 0 else r + die_value
		var s := t
		if r < 0:
			s += 40
		if t >= LOOP:
			s += 35
		if t <= 27:
			var a := abs_space(current, t)
			for i in range(players.size()):
				if i != current:
					for q in players[i].pegs:
						if int(q) >= 0 and int(q) <= 27 and abs_space(i, int(q)) == a:
							s += 60
		if r >= 0 and r < LOOP and t >= LOOP:
			s += 10
		if s > best_score:
			best_score = s
			best = k
	return best


func _do_move(k: int) -> void:
	var p: Dictionary = players[current]
	var r: int = p.pegs[k]
	var t := 0 if r < 0 else r + die_value
	p.pegs[k] = t
	var detail := "PEG OUT" if r < 0 else ""
	event.emit("enter" if r < 0 else "hop")
	if t <= 27:
		var a := abs_space(current, t)
		for i in range(players.size()):
			if i == current:
				continue
			for j in range(4):
				var q: int = players[i].pegs[j]
				if q >= 0 and q <= 27 and abs_space(i, q) == a:
					players[i].pegs[j] = -1
					detail = "SENDS %s HOME" % players[i].name
					event.emit("capture")
	elif detail == "":
		detail = "IN THE HOME LANE"
		event.emit("finish")
	_say(("%s: %d  %s" % [p.name, die_value, detail]).strip_edges())
	var all_home := true
	for q in p.pegs:
		if int(q) < LOOP:
			all_home = false
	if all_home:
		winner = current
		p.wins += 1
		phase = "win"
		remaining = 8.0
		_say("%s WINS!" % p.name)
		event.emit("win")
		return
	again = die_value == 6
	phase = "after"
	remaining = 0.9


func _next_turn() -> void:
	var was_again := again
	tries = 3
	if not was_again:
		current = (current + 1) % players.size()
	again = false
	legal = []
	phase = "wait"
	remaining = 25.0 if (players[current].human and not auto_human) else 1.4
	_say("%s%s" % [players[current].name, " — SIX! ROLL AGAIN" if was_again else " — ROLL THE DIE"])


func _tick_rules(delta: float) -> void:
	remaining -= delta
	if remaining > 0.0:
		return
	match phase:
		"win":
			round_number += 1
			for q in players:
				q.pegs = [-1, -1, -1, -1]
			winner = -1
			current = (round_number - 1) % players.size()
			again = false
			legal = []
			phase = "wait"
			tries = 3
			remaining = 25.0 if (players[current].human and not auto_human) else 1.4
			_say("NEW GAME — %s ROLLS" % players[current].name)
		"after":
			_next_turn()
		"pass":
			var p: Dictionary = players[current]
			if not _on_board(p) and tries > 1:
				tries -= 1
				legal = []
				phase = "wait"
				remaining = 25.0 if (p.human and not auto_human) else 1.0
				_say("%s — TRY AGAIN (%d LEFT)" % [p.name, tries])
			else:
				_next_turn()
		"move":
			_do_move(ai_pick() if not legal.is_empty() else 0)
		_:
			_do_roll()


# ---- showing it ---------------------------------------------------------------------------------------
func _place_all(snap := false) -> void:
	for i in range(players.size()):
		for k in range(4):
			var n: Node3D = peg_nodes[i][k]
			var want := peg_pos(i, k, int(players[i].pegs[k]))
			n.position = want if snap else n.position.lerp(want, 0.2)


func _process(delta: float) -> void:
	_t += delta
	waiting_for_roll = phase == "wait"
	busy = phase != "wait"
	var pick := choosing()
	for i in range(players.size()):
		for k in range(4):
			var n: Node3D = peg_nodes[i][k]
			var want := peg_pos(i, k, int(players[i].pegs[k]))
			var d := Vector3(want.x - n.position.x, 0.0, want.z - n.position.z)      # sideways distance still to go (a peg hops while it travels)
			n.position = n.position.lerp(want, 1.0 - exp(-delta * 9.0))
			var hop := clampf(d.length() * 4.0, 0.0, 0.05)
			var bounce := 0.0
			if pick and i == current and legal.has(k):
				bounce = (0.5 + 0.5 * sin(_t * 8.0 + float(k))) * 0.016
			elif i == current and phase == "move" and legal.has(k):
				bounce = 0.006
			n.position.y = TOP_Y + hop + bounce
			n.scale = Vector3.ONE * (1.25 if (pick and i == current and legal.has(k)) else 1.0)
	# the die in the dome: a tumble when a new number is rolled, then it rests showing the number
	var key := "%d:%d:%d:%s" % [round_number, current, die_value, phase]
	if phase in ["move", "pass"] and key != _seen_die_key:
		_seen_die_key = key
		_roll_t = 0.0
	if phase in ["wait", "win"]:
		_seen_die_key = ""
	_roll_t += delta
	var show_die := phase in ["move", "pass", "after"]
	_die.visible = show_die
	if show_die:
		if _roll_t < 0.8:
			var u := _roll_t / 0.8
			_die.rotation = Vector3(11.0, 8.0, 6.0) * u * (1.0 - u * 0.2) + Vector3(0.6, 0.2, 0.9)
			_die.position = Vector3(0.0, 0.045 + absf(sin(u * PI * 3.0)) * 0.05 * (1.0 - u), 0.0)
		else:
			_die.basis = _face_up(die_value)
			_die.position = Vector3(0.0, 0.03, 0.0)
	_dome.scale = Vector3(1.0, 0.55 - (0.12 if (phase == "move" and _roll_t < 0.15) else 0.0), 1.0)
	if _label != null:
		if phase == "wait":
			_label.text = "%s  •  %ds\nWINS %d" % [message, ceili(maxf(remaining, 0.0)), players[current].wins]
		elif phase == "move" and choosing():
			_label.text = "%s  •  %ds" % [message, ceili(maxf(remaining, 0.0))]
	if not authority:
		return
	_tick_rules(delta)


func apply_snapshot(data: Dictionary) -> void:
	var ps: Array = data.get("players", [])
	if ps.size() != players.size() or not str(data.get("phase", "")) in ["wait", "move", "pass", "after", "win"]:
		return
	for q in ps:
		if not q is Dictionary or not q.get("pegs", null) is Array or q.pegs.size() != 4:
			return
		for r in q.pegs:
			if not (r is float or r is int) or r < -1 or r > LANE_END:
				return
	authority = false
	current = clampi(int(data.get("current", 0)), 0, players.size() - 1)
	winner = clampi(int(data.get("winner", -1)), -1, players.size() - 1)
	phase = str(data.phase)
	remaining = clampf(float(data.get("remaining", 0)), 0, 25)
	die_value = clampi(int(data.get("die", 1)), 1, 6)
	round_number = int(data.get("round", round_number))
	legal = []
	for k in data.get("legal", []):
		if k is float or k is int:
			legal.append(clampi(int(k), 0, 3))
	for i in range(players.size()):
		players[i].name = str(ps[i].get("name", players[i].name)).left(20)
		players[i].occupant = str(ps[i].get("occupant", ""))
		players[i].wins = int(ps[i].get("wins", 0))
		for k in range(4):
			players[i].pegs[k] = int(ps[i].pegs[k])
		players[i].human = players[i].occupant != ""
	_say(str(data.get("message", "")).left(120))


# ---- the Pop-O-Matic dome and the die ----------------------------------------------------------------
func _make_dome() -> void:
	var ring := VRBuild.cylinder(self, 0.085, 0.012, Vector3(0, 0.006, 0), VRBuild.mat(Color(0.1, 0.08, 0.07), 0.3, 0.7), 0.09, Vector3.ZERO, 40)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.8, 0.92, 1.0, 0.16)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic = 0.1
	_dome = VRBuild.sphere(self, 0.08, Vector3(0, 0.012, 0), glass, 24)
	_dome.scale = Vector3(1.0, 0.55, 1.0)


## The orientation that shows value n on top. Opposite faces add to 7: +y 1, -y 6, +z 2, -z 5, +x 3, -x 4.
static func _face_up(n: int) -> Basis:
	match n:
		1: return Basis.IDENTITY
		6: return Basis(Vector3.RIGHT, PI)
		2: return Basis(Vector3.RIGHT, -PI / 2.0)
		5: return Basis(Vector3.RIGHT, PI / 2.0)
		3: return Basis(Vector3.BACK, PI / 2.0)
		_: return Basis(Vector3.BACK, -PI / 2.0)


func _make_die() -> Node3D:
	var die := Node3D.new()
	var body := VRBuild.mat(Color(0.96, 0.95, 0.9), 0.25, 0.0)
	var pip := VRBuild.mat(Color(0.05, 0.05, 0.06), 0.3, 0.0)
	var h := 0.026
	VRBuild.box(die, Vector3(h * 2.0, h * 2.0, h * 2.0), Vector3.ZERO, body)
	var layouts := {1: [Vector2(0, 0)], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
		4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)], 5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
		6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]}
	var faces := {1: Vector3.UP, 6: Vector3.DOWN, 2: Vector3.BACK, 5: Vector3.FORWARD, 3: Vector3.RIGHT, 4: Vector3.LEFT}
	for v in faces:
		var nrm: Vector3 = faces[v]
		var up := Vector3.UP if absf(nrm.y) < 0.5 else Vector3.BACK
		var rt := nrm.cross(up).normalized()
		var upv := rt.cross(nrm).normalized()
		for q in layouts[v]:
			var sph := VRBuild.sphere(die, 0.0048, nrm * (h + 0.0005) + rt * q.x * 0.014 + upv * q.y * 0.014, pip, 10)
			sph.scale = Vector3(1, 1, 0.5) if false else Vector3.ONE
	return die


# ---- the pegs: a round foot, a stem and a rounded head, in the seat's colour ------------------------
func _make_peg(i: int) -> Node3D:
	var t := Node3D.new()
	var col: Color = COLOURS[i]
	var glossy := VRBuild.mat(col, 0.16, 0.12, 0.3, col.darkened(0.55))
	VRBuild.cylinder(t, 0.017, 0.007, Vector3(0, 0.0035, 0), glossy, 0.019, Vector3.ZERO, 20)
	VRBuild.cylinder(t, 0.008, 0.026, Vector3(0, 0.02, 0), glossy, 0.01, Vector3.ZERO, 14)
	VRBuild.sphere(t, 0.0125, Vector3(0, 0.04, 0), glossy, 14)
	return t
