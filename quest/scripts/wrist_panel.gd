class_name WristPanel
extends Node3D
## Bare-hand controls. Turn your left palm up toward you and a small panel floats above it (MENU, turn left, turn right, RECENTRE, SKINS).
## Touch a button with a finger of your other hand. With controllers there is no panel: the controller buttons and sticks do all of this.

const BUTTONS := [["menu", "MENU", Color(0.2, 0.7, 1.0)], ["turn_l", "<  TURN", Color(0.5, 0.5, 0.9)], ["turn_r", "TURN  >", Color(0.5, 0.5, 0.9)], ["recentre", "RECENTRE", Color(0.3, 0.8, 0.5)]]
const STEP := 0.092

var shown := false
var _nodes := {}
var _glow := 0.0


func build(font: Font) -> void:
	visible = false
	var back := VRBuild.mat(Color(0.03, 0.03, 0.07, 0.85), 0.4)
	back.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	back.no_depth_test = true
	back.render_priority = 15
	VRBuild.box(self, Vector3(STEP * BUTTONS.size() + 0.02, 0.085, 0.006), Vector3(0, 0, -0.008), back)
	for i in range(BUTTONS.size()):
		var b: Array = BUTTONS[i]
		var node := Node3D.new()
		node.position = Vector3((float(i) - (BUTTONS.size() - 1) / 2.0) * STEP, 0, 0)
		add_child(node)
		var m := VRBuild.mat(b[2], 0.35, 0.0, 1.2, b[2])
		m.no_depth_test = true
		m.render_priority = 16
		VRBuild.box(node, Vector3(0.082, 0.062, 0.012), Vector3.ZERO, m)
		var l := VRBuild.label(node, b[1], 0.016, Vector3(0, 0, 0.0075), Color(0.02, 0.02, 0.05), Vector3.ZERO, 0, font)
		l.no_depth_test = true
		l.render_priority = 17
		_nodes[b[0]] = node


## hand_xf: the left hand; palm_up: how squarely the palm faces the ceiling (0..1); head: camera position.
func update(hand_pos: Vector3, palm_up: float, head: Vector3, active: bool, delta: float) -> void:
	var near := hand_pos.distance_to(head) < 0.75 and hand_pos.y < head.y - 0.05
	var want := active and palm_up > 0.72 and near
	shown = want
	_glow = move_toward(_glow, 1.0 if want else 0.0, delta * 6.0)
	visible = _glow > 0.02
	if not visible:
		return
	var p := hand_pos + Vector3(0, 0.1, 0)
	var to_head := head - p
	to_head.y = 0.0
	global_position = p
	if to_head.length() > 0.01:
		look_at(p + to_head, Vector3.UP)
		rotate_object_local(Vector3.UP, PI)
	rotate_object_local(Vector3.RIGHT, 0.5)        # tilted back a little so it reads from above
	scale = Vector3.ONE * _glow


## The button a fingertip is touching, or "".
func button_at(tip: Vector3) -> String:
	if not shown:
		return ""
	var l := to_local(tip)
	for k in _nodes:
		var n: Node3D = _nodes[k]
		if absf(l.x - n.position.x) < 0.04 and absf(l.y) < 0.034 and l.z > -0.035 and l.z < 0.03:
			return k
	return ""


func flash(name: String) -> void:
	var n: Node3D = _nodes.get(name)
	if n != null:
		var tw := create_tween()
		tw.tween_property(n, "scale", Vector3(0.9, 0.9, 0.5), 0.05)
		tw.tween_property(n, "scale", Vector3.ONE, 0.15)
