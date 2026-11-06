class_name BoardGame
extends Node3D
## The lounge board game, "Zombie Smash: Race to the Lab". A loop of 28 squares round the table. Everyone races once round:
##   GRENADE jump forward 3   ZOMBIE run back 2   HEART roll again   BOSS miss your next turn
## Four seats, one per stool, each with its own piece. A seat nobody sits on is played by the computer, so the game always runs.
## Sit on a stool and you take over that seat's piece where it stands, mid-game; stand up and the computer carries on for you.
## Each seat remembers who last sat there, so someone who comes back gets the same piece if the seat is still free.
## Occupants are named by an id ("local" for this headset), ready for players joining over the network later.
## Square positions match the picture drawn by tools/make_zs_board.py.

signal event(name: String)

const SQUARES := 28
const MARGIN := 72.0
const CELL := 110.0
const PIC := 1024.0
const BOARD_M := 0.76             # the picture is this many metres across on the table
const KIND := {4: "grenade", 13: "grenade", 22: "grenade", 6: "zombie", 11: "zombie", 17: "zombie", 24: "zombie", 3: "heart", 9: "heart", 15: "heart", 20: "heart", 26: "heart",
	8: "boss", 14: "boss", 19: "boss", 25: "boss"}
const BOSS_NAME := {8: "JORDAN", 14: "DEBO", 19: "DR MANTIS", 25: "DISCO MAN"}
const NAMES := ["DEBO", "DR MANTIS", "DISCO MAN", "FAT AMY"]          # the computer player in each seat
const COLOURS := [Color(0.5, 0.95, 0.3), Color(1.0, 0.18, 0.18), Color(1.0, 0.62, 0.12), Color(0.7, 0.45, 1.0)]   # match the stools: green, red, amber, purple
const PIECES := ["GREEN HAND", "RED GRENADE", "AMBER BRAIN", "PURPLE SKULL"]
const TOP_Y := 0.0               # tokens stand on the board surface (this node sits on it)

var players: Array = []          # {name, pos, skip, token: Node3D, human, occupant}
var last_occupant: Array = ["", "", "", ""]   # who sat in each seat most recently
var current := 0
var waiting_for_roll := false
var busy := false
var message := ""
var winner := -1
var rng := RandomNumberGenerator.new()
var _die: Node3D
var _label: Label3D
var _font: Font
var _roll_now := false
var authority := true
var local_id := "local"
var phase := "wait"
var remaining := 1.6
var again := false
var round_number := 1
var die_value := 1
var deck: Array = []
var auto_human := false           # the tour video plays the human seat by itself


func build(font: Font) -> void:
	_font = font
	rng.randomize()
	for i in range(NAMES.size()):
		var tok := _make_token(i)
		add_child(tok)
		players.append({"name": NAMES[i], "pos": 0, "skip": false, "token": tok, "human": false, "occupant": "", "shield": 1, "wins": 0})
	_die = _make_die()
	_die.visible = false
	add_child(_die)
	_label = VRBuild.label(self, "", 0.045, Vector3(0, 0.34, 0), Color(1, 1, 1), Vector3.ZERO, 8, font)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 6
	_reset_game()



# ---- squares ----------------------------------------------------------------------------------------
static func _cell_of(i: int) -> Vector2i:
	var n := i % SQUARES
	if n < 8:
		return Vector2i(0, 7 - n)                 # up the left edge: (column, row)
	if n < 15:
		return Vector2i(n - 7, 0)                 # along the top
	if n < 22:
		return Vector2i(7, n - 14)                # down the right edge
	return Vector2i(7 - (n - 21), 7)              # back along the bottom


## Local position (on the board surface) of a square, with a small spread so tokens sharing a square do not overlap.
func square_pos(i: int, slot := 0) -> Vector3:
	var c := _cell_of(mini(i, SQUARES))
	var px := MARGIN + (float(c.x) + 0.5) * CELL
	var pz := MARGIN + (float(c.y) + 0.5) * CELL
	var k := BOARD_M / PIC
	var off := Vector2(float(slot % 3) - 1.0, float(slot / 3) - 0.5) * 0.018
	if i >= SQUARES:
		c = _cell_of(0)
		px = MARGIN + 0.5 * CELL
		pz = MARGIN + 7.5 * CELL
	return Vector3((px - PIC / 2.0) * k + off.x, TOP_Y, (pz - PIC / 2.0) * k + off.y)


# ---- seats ------------------------------------------------------------------------------------------
## Someone sits in a seat: they play that piece from wherever it is now. Returns false if someone else is already there.
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


## Someone stands up: the computer player takes the piece back and carries on. A roll they were waiting on is made for them.
func leave_seat(occupant: String) -> void:
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p.occupant == occupant:
			p.occupant = ""
			p.human = false
			p.name = NAMES[i]
			if waiting_for_roll and current == i:
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


# ---- the game ---------------------------------------------------------------------------------------
func hint() -> String:
	return "STEADY / DASH" if waiting_for_roll and current == seat_of(local_id) else ""


func roll_human(dash := false) -> void:
	if authority and phase == "wait" and players[current].occupant == local_id:
		_resolve(dash)


func _reset_game() -> void:
	winner = -1
	current = 0
	for i in range(players.size()):
		players[i].pos = 0
		players[i].skip = false
		players[i].shield = 1
		players[i].token.position = square_pos(0, i)
	_say("RACE TO THE LAB!  SIT ON A STOOL TO PLAY")
	_place_all()


func _place_all() -> void:
	for i in range(players.size()):
		var tok: Node3D = players[i].token
		tok.position = square_pos(int(players[i].pos), i)


func _say(t: String) -> void:
	message = t
	if _label != null:
		_label.text = t


func _process(delta: float) -> void:
	for i in range(players.size()):
		var token: Node3D = players[i].token
		token.position = token.position.lerp(square_pos(players[i].pos, i), 1.0 - exp(-delta * 8.0))
	waiting_for_roll = phase == "wait"
	busy = phase != "wait"
	_die.visible = phase == "result"
	if _die.visible:
		_die.position = Vector3(0, 0.04, 0)
		if remaining > 1.4:
			_die.rotation = Vector3(2.2 - remaining, 2.2 - remaining, 2.2 - remaining) * 12.0
			_die.position.y = 0.04 + absf(sin((2.2 - remaining) * 10.0)) * 0.05
		else:
			_die.basis = _face_up(die_value)
	if _label != null and phase == "wait":
		_label.text = "%s  •  %ds\nSHIELDS %d  •  WINS %d" % [message, ceili(remaining), players[current].shield, players[current].wins]
	if not authority:
		return
	remaining -= delta
	if remaining > 0.0:
		return
	if phase == "win":
		round_number += 1
		_reset_game()
		current = (round_number - 1) % players.size()
		_begin_turn()
	elif phase == "result":
		if not again:
			current = (current + 1) % players.size()
		_begin_turn()
	else:
		_resolve(false)


func _begin_turn() -> void:
	phase = "wait"
	remaining = 25.0 if players[current].human and not auto_human else 1.6
	_say("%s — STEADY or DASH" % players[current].name)


func _resolve(dash: bool) -> void:
	var p: Dictionary = players[current]
	phase = "result"
	remaining = 2.2
	again = false
	if p.skip:
		p.skip = false
		_say("%s MISSES A TURN" % p.name)
		return
	die_value = rng.randi_range(1, 6)
	var steps := die_value + (2 if dash else 0)
	var detail := ""
	if dash and die_value == 1:
		if p.shield > 0:
			p.shield -= 1
			detail = "SHIELD SAVED DASH"
		else:
			steps = -2
			detail = "DASH FAILED — BACK 2"
	p.pos = clampi(p.pos + steps, 0, 28)
	if p.pos < 28 and steps > 0:
		match KIND.get(p.pos, ""):
			"grenade":
				p.pos = mini(28, p.pos + 3)
				detail = "GRENADE +3"
			"heart":
				p.shield = mini(2, p.shield + 1)
				again = true
				detail = "HEART: SHIELD + ROLL AGAIN"
			"boss", "zombie":
				if p.shield > 0:
					p.shield -= 1
					detail = "SHIELD BLOCKED ATTACK"
				elif KIND.get(p.pos) == "boss":
					p.skip = true
					detail = "BOSS: MISS NEXT TURN"
				else:
					p.pos = maxi(0, p.pos - 2)
					detail = "ZOMBIE: BACK 2"
			_:
				if p.pos in [2, 10, 16, 23]:
					if deck.is_empty():
						deck = [0, 1, 2, 3, 4, 5]
						for i in range(5, 0, -1):
							var j := rng.randi_range(0, i)
							var saved: int = deck[i]
							deck[i] = deck[j]
							deck[j] = saved
					var card: int = deck.pop_back()
					if card in [0, 3]:
						p.shield = mini(2, p.shield + 1)
					else:
						p.pos = clampi(p.pos + [0, 2, -1, 0, 1, 3][card], 0, 28)
					detail = ["SUPPLY: SHIELD", "SHORTCUT +2", "AMBUSH -1", "MEDKIT: SHIELD", "RESCUE +1", "POWER SURGE +3"][card]
	_say("%s: %s %d  %s" % [p.name, "DASH" if dash else "STEADY", die_value, detail])
	event.emit("roll")
	if p.pos >= 28:
		winner = current
		p.wins += 1
		phase = "win"
		remaining = 7.0
		_say("%s WINS!" % p.name)
		event.emit("win")


func apply_snapshot(data: Dictionary) -> void:
	var ps: Array = data.get("players", [])
	if ps.size() != players.size() or not data.get("phase", "") in ["wait", "result", "win"]:
		return
	for q in ps:
		if not q is Dictionary or not q.get("pos", -1) is float and not q.get("pos", -1) is int:
			return
		if q.pos < 0 or q.pos > 28:
			return
	authority = false
	current = clampi(int(data.get("current", 0)), 0, players.size() - 1)
	winner = clampi(int(data.get("winner", -1)), -1, players.size() - 1)
	phase = data.phase
	remaining = clampf(float(data.get("remaining", 0)), 0, 25)
	die_value = clampi(int(data.get("die", 1)), 1, 6)
	for i in range(players.size()):
		for key in ["name", "occupant", "pos", "skip", "shield", "wins"]:
			players[i][key] = ps[i].get(key, players[i][key])
		players[i].human = players[i].occupant != ""
	_say(str(data.get("message", "")).left(120))


# ---- the die ----------------------------------------------------------------------------------------
func _roll_die(n: int) -> void:
	_die.visible = true
	var start := Vector3(0.0, 0.5, 0.0)
	_die.position = start
	event.emit("roll")
	var spin := Vector3(rng.randf_range(4.0, 9.0), rng.randf_range(3.0, 8.0), rng.randf_range(3.0, 8.0))
	var final := _face_up(n)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var arc := sin(t * PI) * 0.16
		_die.position = Vector3(0.0, 0.07 + 0.43 * (1.0 - ease(t, 0.35)) + arc * 0.2, 0.0)
		if t < 0.82:
			_die.rotation = spin * t
		else:
			_die.basis = Basis.from_euler(spin * 0.82).slerp(final, (t - 0.82) / 0.18), 0.0, 1.0, 1.1)
	await tw.finished
	_die.position = Vector3(0.0, 0.03, 0.0)
	_die.basis = final
	await get_tree().create_timer(0.5).timeout
	_die.visible = false


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


# ---- the pieces: little collector's tokens, each in a player colour ----------------------------------
func _make_token(i: int) -> Node3D:
	var t := Node3D.new()
	var col: Color = COLOURS[i]
	var base := VRBuild.mat(col.darkened(0.55), 0.25, 0.6)
	var glossy := VRBuild.mat(col, 0.18, 0.15, 0.25, col)
	VRBuild.cylinder(t, 0.022, 0.006, Vector3(0, 0.003, 0), base, 0.024, Vector3.ZERO, 24)          # a round base, like a board game piece
	match i:
		0:    # the zombie hand: palm, four fingers and a thumb reaching up
			var palm := VRBuild.sphere(t, 0.015, Vector3(0, 0.02, 0), glossy, 16)
			palm.scale = Vector3(1.0, 0.8, 0.75)
			for f in range(4):
				var fx := (float(f) - 1.5) * 0.0105
				VRBuild.cylinder(t, 0.0042, 0.026, Vector3(fx, 0.043, 0), glossy, 0.0035, Vector3(0, 0, (float(f) - 1.5) * -0.12), 10)
				VRBuild.sphere(t, 0.0042, Vector3(fx + (float(f) - 1.5) * -0.0031, 0.057, 0), glossy, 8)
			VRBuild.cylinder(t, 0.0045, 0.02, Vector3(0.019, 0.03, 0), glossy, 0.0038, Vector3(0, 0, -0.9), 10)
		1:    # a grenade
			var body := VRBuild.sphere(t, 0.017, Vector3(0, 0.026, 0), glossy, 16)
			body.scale = Vector3(1.0, 1.1, 1.0)
			VRBuild.cylinder(t, 0.007, 0.01, Vector3(0, 0.048, 0), base, -1.0, Vector3.ZERO, 12)
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.0045
			tm.outer_radius = 0.0075
			ring.mesh = tm
			ring.material_override = VRBuild.mat(Color(0.85, 0.85, 0.9), 0.2, 0.9)
			ring.position = Vector3(0.008, 0.058, 0)
			ring.rotation = Vector3(PI / 2, 0, 0)
			t.add_child(ring)
		2:    # a brain: two lumpy halves
			for sx in [-1.0, 1.0]:
				var half := VRBuild.sphere(t, 0.0135, Vector3(sx * 0.0085, 0.028, 0), glossy, 14)
				half.scale = Vector3(0.95, 0.9, 1.15)
			VRBuild.sphere(t, 0.008, Vector3(0, 0.017, 0.006), glossy, 10)
		3:    # a skull
			var skull := VRBuild.sphere(t, 0.0165, Vector3(0, 0.036, 0), glossy, 16)
			skull.scale = Vector3(1.0, 1.05, 1.0)
			var jaw := VRBuild.cylinder(t, 0.0105, 0.012, Vector3(0, 0.017, 0.003), glossy, 0.0085, Vector3.ZERO, 12)
			var dark := VRBuild.mat(Color(0.02, 0.02, 0.03), 0.4)
			for sx in [-1.0, 1.0]:
				VRBuild.sphere(t, 0.0045, Vector3(sx * 0.0068, 0.038, 0.0135), dark, 8)
		4, 5:
			VRBuild.cylinder(t, 0.012, 0.05, Vector3(0, 0.034, 0), glossy, 0.009, Vector3.ZERO, 16)
			VRBuild.sphere(t, 0.015, Vector3(0, 0.063, 0), glossy, 14)
	return t
