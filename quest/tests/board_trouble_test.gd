extends SceneTree
## Frustration / Trouble rules in the game (the same as server/board.mjs): a 6 brings a peg out, captures, blocking, exact finish, win.

func _init() -> void:
	var b := BoardGame.new()
	root.add_child(b)
	b.build(null)
	b.take_seat(0, "local")
	var fails := 0
	# a roll with no 6 and no peg out cannot move
	b.phase = "wait"
	b.die_value = 1
	b.legal = b.legal_moves()
	fails += _expect(b.legal.is_empty(), "no peg can leave home without a 6")
	b.die_value = 6
	b.legal = b.legal_moves()
	fails += _expect(b.legal == [0, 1, 2, 3], "a 6 lets any peg out")
	# bring a peg out, then roll again
	b.current = 0
	b.phase = "move"
	b._do_move(2)
	fails += _expect(b.players[0].pegs[2] == 0 and b.again and b.phase == "after", "peg out onto the start space, and a 6 rolls again")
	b._next_turn()
	fails += _expect(b.current == 0 and b.phase == "wait", "the same player rolls again after a 6")
	# capture: seat 1's start is loop space 3; seat 0's rel 7 is space (24+7)%28 = 3
	b.players[1].pegs = [0, -1, -1, -1]
	b.players[0].pegs = [-1, -1, 3, -1]
	b.die_value = 4
	b.legal = b.legal_moves()
	fails += _expect(b.legal == [2], "one peg can move")
	b.phase = "move"
	b._do_move(2)
	fails += _expect(b.players[0].pegs[2] == 7 and b.players[1].pegs[0] == -1, "landing on a peg sends it home")
	# own pegs block
	b.current = 0
	b.again = false
	b.players[0].pegs = [5, 8, -1, -1]
	b.die_value = 3
	fails += _expect(b.legal_moves() == [1], "a peg cannot land on your own peg")
	b.players[0].pegs = [30, -1, -1, -1]
	b.die_value = 2
	fails += _expect(b.legal_moves().is_empty(), "exact roll to finish")
	b.die_value = 1
	fails += _expect(b.legal_moves() == [0], "one step to the last hole")
	# win
	b.players[0].pegs = [31, 30, 29, 27]
	b.die_value = 1
	b.legal = b.legal_moves()
	b.phase = "move"
	b._do_move(3)
	fails += _expect(b.winner == 0 and b.phase == "win" and b.players[0].wins == 1, "all four home wins")
	# snapshots from the server are accepted and bad ones refused
	var snap := {"players": [], "phase": "move", "current": 1, "winner": -1, "remaining": 5.0, "die": 4, "legal": [0, 2], "message": "X", "round": 3}
	for i in range(4):
		snap.players.append({"name": "P%d" % i, "occupant": "", "pegs": [-1, 0, 28, 31], "wins": 0})
	b.apply_snapshot(snap)
	fails += _expect(b.current == 1 and b.legal == [0, 2] and b.players[2].pegs[3] == 31 and not b.authority, "server snapshot is shown")
	snap.players[0].pegs = [-1, 0, 28, 99]
	b.current = 3
	b.apply_snapshot(snap)
	fails += _expect(b.current == 3, "a bad snapshot is ignored")
	# (the computer no longer plays: only people move the pegs; see tests/upgrade/board_human_only.gd)
	print("BOARD TROUBLE PASS" if fails == 0 else "BOARD TROUBLE FAIL %d" % fails)
	quit(1 if fails > 0 else 0)


func _expect(ok: bool, what: String) -> int:
	if not ok:
		print("FAIL: ", what)
	return 0 if ok else 1
