class_name Throwable
extends RefCounted
## Something you can pick up in the sports hall and throw: a dart, an axe or a bowling ball.

var kind := ""                   # dart, axe or ball
var node: Node3D
var game                         # the game it belongs to (a SportGame)
var lane := 0                    # which board / lane it belongs to
var slot := 0
var state := "rest"              # rest (on its rack), held, flying, stuck (in the board), down (lying where it fell), away (out of play)
var held_hand := -1
var radius := 0.14               # how close the palm must be to pick it up
var vel := Vector3.ZERO
var spin := 0.0                  # rad/s about the travel's side axis (axes)
var basis := Basis.IDENTITY
var pos := Vector3.ZERO
var t := 0.0                     # time in this state
var rest_xf := Transform3D.IDENTITY
var data := {}


func can_grab() -> bool:
	return state == "rest" and node != null and node.visible


func world_pos() -> Vector3:
	return node.global_position if node != null else pos
