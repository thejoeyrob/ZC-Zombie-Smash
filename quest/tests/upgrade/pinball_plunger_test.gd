extends SceneTree
## The plunger: pulling the knob all the way back (or further) must let go of the hand AND strike the ball at full power.
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failed += 1
func _initialize() -> void:
	_run.call_deferred()

func _hands(on: bool) -> Array:
	return [{"active": on, "gripping": on, "grip": Vector3.ZERO, "palm": Vector3.ZERO, "trig_val": 0.0, "grip_val": 1.0 if on else 0.0, "trigger": false}, {"active": false, "gripping": false, "grip": Vector3.ZERO, "palm": Vector3.ZERO, "trig_val": 0.0, "grip_val": 0.0, "trigger": false}]

func _fresh() -> Pinball:
	var p := Pinball.new()
	root.add_child(p)
	p.build(ThemeDB.fallback_font)
	p.set_enabled(true)
	p.table.game_over = true
	return p

func _run() -> void:
	for far in [0.12, 0.25, 0.6]:      # to the end, past the end, way past the end (where it used to let go without hitting)
		var p := _fresh()
		var knob := p.to_global(p.plunger_rest)
		var hands := _hands(true)
		p.interact([], [knob, knob], false, false, false, true, hands)
		check(p._plunger_hand == 0, "Hand should have taken hold of the plunger")
		var back := p.to_global(p.plunger_rest + Vector3(0, 0, far))
		p.interact([], [back, back], false, false, false, true, hands)
		check(p.table.in_play, "Pulling %.2f m back should strike the ball" % far)
		check(p._plunger_hand == -1, "The plunger should let go of the hand after firing (pulled %.2f m)" % far)
		check(p.table.vel.y <= -1650.0, "Full pull should be full power (got %.0f)" % p.table.vel.y)
		p.queue_free()
	# a gentle pull and release still fires, softer
	var q := _fresh()
	var kn := q.to_global(q.plunger_rest)
	var hs := _hands(true)
	q.interact([], [kn, kn], false, false, false, true, hs)
	var half := q.to_global(q.plunger_rest + Vector3(0, 0, 0.05))
	q.interact([], [half, half], false, false, false, true, hs)
	check(not q.table.in_play and q._plunger_hand == 0, "Half a pull is still holding")
	hs = _hands(true)
	hs[0].gripping = false                 # opened the hand: let go
	hs[0].grip_val = 0.0
	q.interact([], [half, half], false, false, false, true, hs)
	check(q.table.in_play and q.table.vel.y > -1650.0 and q.table.vel.y < -1200.0, "Releasing half way fires a softer shot (got %.0f)" % q.table.vel.y)
	print("PINBALL PLUNGER PASS" if failed == 0 else "PINBALL PLUNGER FAILED")
	quit(failed)
