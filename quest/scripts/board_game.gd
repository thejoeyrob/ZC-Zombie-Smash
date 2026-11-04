class_name BoardGame
extends Node3D
## The lounge board game, "Zombie Smash: Race to the Lab". A loop of 28 squares round the table. Everyone races once round:
##   GRENADE jump forward 3   ZOMBIE run back 2   HEART roll again   BOSS miss your next turn
## You are the green zombie hand; three friends from the game (played by the computer) race you. Point at the table and pull the trigger to roll.
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
const NAMES := ["YOU", "DEBO", "DR MANTIS", "DISCO MAN"]
const COLOURS := [Color(0.35, 0.95, 0.25), Color(0.95, 0.3, 0.2), Color(0.45, 0.75, 0.2), Color(0.95, 0.35, 0.85)]
const TOP_Y := 0.0               # tokens stand on the board surface (this node sits on it)

var players: Array = []          # {name, pos, skip, token: Node3D, human}
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
var auto_human := false           # the tour video plays the human seat by itself


func build(font: Font) -> void:
	_font = font
	rng.randomize()
	for i in range(NAMES.size()):
		var tok := _make_token(i)
		add_child(tok)
		players.append({"name": NAMES[i], "pos": 0, "skip": false, "token": tok, "human": i == 0})
	_die = _make_die()
	_die.visible = false
	add_child(_die)
	_label = VRBuild.label(self, "", 0.045, Vector3(0, 0.34, 0), Color(1, 1, 1), Vector3.ZERO, 8, font)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 6
	_reset_game()
	_run()


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
	var off := Vector2(float(slot % 2) - 0.5, float(slot / 2) - 0.5) * 0.034
	if i >= SQUARES:
		c = _cell_of(0)
		px = MARGIN + 0.5 * CELL
		pz = MARGIN + 7.5 * CELL
	return Vector3((px - PIC / 2.0) * k + off.x, TOP_Y, (pz - PIC / 2.0) * k + off.y)


# ---- the game ---------------------------------------------------------------------------------------
func hint() -> String:
	if winner >= 0:
		return ""
	return "ROLL" if waiting_for_roll else ""


func roll_human() -> void:
	if waiting_for_roll and not busy:
		_roll_now = true


func _reset_game() -> void:
	winner = -1
	current = 0
	for i in range(players.size()):
		players[i].pos = 0
		players[i].skip = false
		players[i].token.position = square_pos(0, i)
	_say("RACE TO THE LAB!  YOU ARE THE GREEN HAND")
	_place_all()


func _place_all() -> void:
	for i in range(players.size()):
		var tok: Node3D = players[i].token
		tok.position = square_pos(int(players[i].pos), i)


func _say(t: String) -> void:
	message = t
	if _label != null:
		_label.text = t


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	while is_inside_tree():
		if winner >= 0:
			await get_tree().create_timer(6.0).timeout
			_reset_game()
			continue
		var p: Dictionary = players[current]
		if p.skip:
			p.skip = false
			_say("%s MISSES A TURN" % p.name)
			event.emit("boss")
			await get_tree().create_timer(1.4).timeout
			current = (current + 1) % players.size()
			continue
		var again := true
		while again and winner < 0:
			again = false
			if p.human:
				_say("YOUR TURN  -  POINT AT THE TABLE AND ROLL")
				waiting_for_roll = true
				_roll_now = false
				if auto_human:
					await get_tree().create_timer(1.3).timeout
					_roll_now = true
				while not _roll_now and is_inside_tree():
					await get_tree().process_frame
				waiting_for_roll = false
			else:
				_say("%s ROLLS..." % p.name)
				await get_tree().create_timer(1.1).timeout
			busy = true
			var n := rng.randi_range(1, 6)
			await _roll_die(n)
			_say("%s ROLLED %d" % [p.name, n])
			await get_tree().create_timer(0.5).timeout
			await _move(p, n)
			var heart: bool = await _land(p)
			busy = false
			if heart and winner < 0:
				again = true
				await get_tree().create_timer(0.6).timeout
		current = (current + 1) % players.size()
		await get_tree().create_timer(0.6).timeout


func _move(p: Dictionary, n: int) -> void:
	for s in range(n):
		p.pos = mini(int(p.pos) + 1, SQUARES)
		await _hop(p)
		if int(p.pos) >= SQUARES:
			break


func _hop(p: Dictionary) -> void:
	var tok: Node3D = p.token
	var idx := players.find(p)
	var a := tok.position
	var b := square_pos(int(p.pos), idx)
	var tw := create_tween()
	tw.tween_method(func(t: float): tok.position = a.lerp(b, t) + Vector3(0, sin(t * PI) * 0.045, 0), 0.0, 1.0, 0.24)
	event.emit("hop")
	await tw.finished


## What the square the player landed on does. Returns true when they get another roll.
func _land(p: Dictionary) -> bool:
	if int(p.pos) >= SQUARES:
		winner = players.find(p)
		_say("%s WINS!  BACK TO THE LAB FIRST" % p.name)
		event.emit("win")
		return false
	var kind: String = KIND.get(int(p.pos), "")
	match kind:
		"grenade":
			_say("%s: GRENADE!  JUMP FORWARD 3" % p.name)
			event.emit("grenade")
			await get_tree().create_timer(0.7).timeout
			await _move(p, 3)
			if int(p.pos) >= SQUARES:
				winner = players.find(p)
				_say("%s WINS!" % p.name)
				event.emit("win")
		"zombie":
			_say("%s: ZOMBIE ATTACK!  BACK 2" % p.name)
			event.emit("zombie")
			await get_tree().create_timer(0.7).timeout
			for s in range(2):
				p.pos = maxi(int(p.pos) - 1, 0)
				await _hop(p)
		"boss":
			_say("%s: %s BLOCKS THE WAY  -  MISS A TURN" % [p.name, BOSS_NAME.get(int(p.pos), "BOSS")])
			event.emit("boss")
			p.skip = true
			await get_tree().create_timer(0.9).timeout
		"heart":
			_say("%s: HEART!  ROLL AGAIN" % p.name)
			event.emit("heart")
			await get_tree().create_timer(0.6).timeout
			return true
	return false


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
	return t
