class_name SportGame
extends Node3D
## Base for the three sports. A game owns its things to throw, shows its own score display and answers the pointer buttons next to it.

signal sound(name: String, at: Vector3, volume: float)
signal buzz(hand: int, amp: float, dur: float)

var font: Font
var active := false              # only runs while somebody is in the hall


func things() -> Array:
	return []


## Things that are lying ready at a station that has no match running (not started yet, or finished). Taking one starts a new match there, so nobody has to find
## and press START first.
func idle_things() -> Array:
	return []


## Starts a match at the station this thing belongs to (called when it is taken from an idle station).
func wake(_t: Throwable) -> void:
	pass


func hold_xf(_t: Throwable, hand_xf: Transform3D) -> Transform3D:
	return hand_xf


func on_grab(_t: Throwable, _hand: int) -> void:
	pass


func on_release(_t: Throwable, _hand_xf: Transform3D, _vel: Vector3, _angv: Vector3, _hand: int) -> void:
	pass


## Buttons you can point at: {id, label, xf, box, colour}.
func selector_targets() -> Array:
	return []


func choose(_id: String) -> bool:
	return false


func tick(_delta: float) -> void:
	pass


func cancel_hold(t: Throwable) -> void:
	t.state = "rest"
	t.held_hand = -1
	t.vel = Vector3.ZERO
	t.data.clear()


## One live object per station keeps throws and turns unambiguous.
func lane_busy(items: Array, lane: int) -> bool:
	for item in items:
		if item.lane == lane and item.state in ["held", "flying"]:
			return true
	return false


## Physical START buttons require a second deliberate press during a live match.
func request_restart(state: Dictionary) -> bool:
	if state.state == "play" and float(state.get("restart_left", 0.0)) <= 0.0:
		state["restart_left"] = 3.0
		return false
	state["restart_left"] = 0.0
	return true


func tick_restart(state: Dictionary, delta: float) -> bool:
	var remaining: float = state.get("restart_left", 0.0)
	if remaining <= 0.0:
		return false
	state["restart_left"] = maxf(0.0, remaining - delta)
	return state.restart_left == 0.0


func result_text(scores: Array) -> String:
	var best: int = scores.max()
	if scores.size() == 1:
		return "FINAL SCORE  %d" % best
	var winners: Array[String] = []
	for p in range(scores.size()):
		if scores[p] == best:
			winners.append("P%d" % (p + 1))
	return ("DRAW  " if winners.size() > 1 else "WINNER  ") + " + ".join(winners) + "  %d" % best
