class_name ThrowGames
extends Node3D
## The sports hall behind the arcade: builds it, lets your hands pick things up and throw them, and runs darts, axe throwing and bowling.
## Pick something up by closing your fingers (grip or trigger) with your hand on it; let go to throw: it leaves with your hand's speed, direction and turn.

signal sound(name: String, at: Vector3, volume: float)
signal buzz(hand: int, amp: float, dur: float)

var annex: ShackAnnex
var darts: DartsGame
var axes: AxeGame
var bowling: BowlingGame
var games: Array = []
var tracks: Array = [HandTrack.new(), HandTrack.new()]
var held: Array = [null, null]
var frames: Array = [Transform3D.IDENTITY, Transform3D.IDENTITY]       # where each held thing is carried: the hand's point, facing where you point, sideways level
var grip_prev: Array = [false, false]
var primary := ["gripping", "gripping"]
var active := false
var _clock := 0.0


func build(parent: Node3D, font: Font) -> void:
	annex = ShackAnnex.new()
	annex.build(parent, font)
	parent.add_child(self)
	darts = DartsGame.new()
	axes = AxeGame.new()
	bowling = BowlingGame.new()
	for g in [darts, axes, bowling]:
		add_child(g)
		g.build(font)
		g.sound.connect(func(n, at, v): sound.emit(n, at, v))
		g.buzz.connect(func(h, a, d): buzz.emit(h, a, d))
		games.append(g)
	set_active(false)


func set_active(on: bool) -> void:
	active = on
	annex.set_active(true)               # the hall is part of the same space now: it is always there to see (the camera only draws what it looks at)
	for g in games:
		g.active = on
		g.visible = true
		g.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if not on:
		for i in range(2):
			_cancel(i)


## The way a held thing faces: forward is where you point (the controller's aim, or the line of a bare hand from wrist to knuckles), sideways is level.
static func hold_frame(h: Dictionary) -> Basis:
	var raw: Transform3D = h.get("xf", h.get("vis_xf", Transform3D.IDENTITY))
	var f: Vector3 = -raw.basis.z
	if not bool(h.get("bare", false)) and h.has("aim_dir"):
		var a: Vector3 = h.aim_dir
		if a.is_finite() and a.length_squared() > 0.5:
			f = a
	if not f.is_finite() or f.length_squared() < 0.001:
		f = Vector3(0, 0, 1)
	f = f.normalized()
	# never straight up or down, so the sideways direction stays defined
	var flat := Vector2(f.x, f.z)
	if absf(f.y) > 0.94:
		if flat.length() < 0.01:
			var rf: Vector3 = -raw.basis.z
			flat = Vector2(rf.x, rf.z) if Vector2(rf.x, rf.z).length() > 0.01 else Vector2(0, 1)
		flat = flat.normalized() * 0.34
		f = Vector3(flat.x, 0.94 * signf(f.y), flat.y).normalized()
	return Basis.looking_at(f, Vector3.UP)


## `hs` are the two hands as vr_main reads them; `at` is where the player is standing.
func update(hs: Array, delta: float, at: Vector3, can_play: bool) -> void:
	var want: bool = (at.z > ShackAnnex.Z0 - 1.6 and absf(at.x - ShackAnnex.GATE_X) < 3.2) or at.z > ShackAnnex.Z0 + 0.2
	if want != active:
		set_active(want)
	if not active:
		return
	_clock += delta
	for g in games:
		g.tick(delta)
	for i in range(2):
		var h: Dictionary = hs[i]
		var here: bool = bool(h.active) and can_play and h.has("palm")       # (the flat desktop view has no hand points)
		if here:
			var raw: Transform3D = h.get("xf", h.vis_xf)
			tracks[i].push(_clock, raw.origin, raw.basis)
		else:
			tracks[i].clear()
		if not here:
			_cancel(i)
			grip_prev[i] = bool(h.gripping) or bool(h.trigger)
			continue
		# A restart may have returned an item to its rack while it was held.
		if held[i] != null and (held[i].state != "held" or held[i].held_hand != i):
			held[i] = null
			tracks[i].clear()
		var grip: bool = bool(h.gripping) or bool(h.trigger)
		if grip and held[i] == null:
			_try_grab(i, h)
		if held[i] != null:
			if bool(h.get(primary[i], false)):
				var t: Throwable = held[i]
				# What you hold follows where you point and the height of your hand, not the tilt and roll the visible hand is drawn with
				# (that tilt is for looks and would turn a dart to the sky and push a ball off to one side).
				frames[i] = Transform3D(hold_frame(h), (h.vis_xf as Transform3D).origin)
				var xf: Transform3D = (t.game as SportGame).hold_xf(t, frames[i])
				t.node.global_transform = xf
				t.pos = xf.origin
			else:
				_release(i, h)
		grip_prev[i] = grip


## Picks up the nearest thing within reach of the hand. The hand has several points (the palm, the fingertip, the spot the stick ball is held, the controller
## itself); the nearest of them counts, and the reach is never less than 20 cm, so a dart on its rack or a ball in its return is easy to take.
func _try_grab(i: int, h: Dictionary) -> void:
	var points: Array = [h.palm]
	for k in ["tip", "grip"]:
		if h.has(k) and (h[k] as Vector3).length() < 90.0:
			points.append(h[k])
	if h.has("vis_xf"):
		points.append((h.vis_xf as Transform3D).origin)
	var best: Throwable = null
	var best_d := 1.0e9
	var from_idle := false
	for g in games:
		for pass_idle in [false, true]:
			var list: Array = (g as SportGame).idle_things() if pass_idle else (g as SportGame).things()
			for t in list:
				if not t.can_grab():
					continue
				var reach: float = maxf((t as Throwable).radius, 0.2)
				var d := 1.0e9
				for p in points:
					d = minf(d, (p as Vector3).distance_to((t as Throwable).world_pos()))
				if d < reach and d < best_d:
					best = t
					best_d = d
					from_idle = pass_idle
	if best != null and from_idle:
		(best.game as SportGame).wake(best)          # nobody had started a match here: taking the thing starts one
		if not (best.game as SportGame).things().has(best):
			return
	if best != null:
		primary[i] = "gripping" if bool(h.gripping) else "trigger"
		held[i] = best
		best.held_hand = i
		tracks[i].clear()
		(best.game as SportGame).on_grab(best, i)
		buzz.emit(i, 0.25, 0.04)


func _release(i: int, h: Dictionary) -> void:
	var t: Throwable = held[i]
	held[i] = null
	if t == null:
		return
	t.held_hand = -1
	var v := (tracks[i] as HandTrack).peak_velocity()
	var w := (tracks[i] as HandTrack).angular_velocity()
	(t.game as SportGame).on_release(t, frames[i], v, w, i)


## Cancelling tracking, opening menus or travelling never spends a throw.
func _cancel(i: int) -> void:
	var t = held[i]
	held[i] = null
	tracks[i].clear()
	if t == null:
		return
	if t.state == "held":
		(t.game as SportGame).cancel_hold(t)
	t.held_hand = -1


func cancel_holds() -> void:
	for i in range(2):
		_cancel(i)
		grip_prev[i] = false


func _drop(i: int) -> void:
	_cancel(i)


func selector_targets() -> Array:
	var out: Array = []
	for g in games:
		out.append_array((g as SportGame).selector_targets())
	return out


func choose(id: String) -> bool:
	for g in games:
		if (g as SportGame).choose(id):
			return true
	return false
