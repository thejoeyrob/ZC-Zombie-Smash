class_name BowlingGame
extends SportGame
## Ten-pin bowling on two lanes with real rigid-body physics: a 6 kg ball, ten 1.5 kg pins set 305 mm apart, gutters, and a pit. Pick the ball up,
## swing, and let go: it leaves at your hand's speed and direction, and a twist of your wrist as you let go puts a hook on it. Ten frames, strikes
## and spares scored properly, one to four players taking a frame each in turn at a lane.

const BALL_R := 0.109
const BALL_MASS := 6.0
const PIN_H := 0.38
const PIN_MASS := 1.5
const PIN_SPACING := 0.305
const ROW_SPACING := 0.264
const LANE_END := ShackAnnex.HEAD_PIN_Z + 0.95
const PIT_FLOOR := -0.45
const HOOK_GAIN := 0.06
const HOOK_MAX := 0.9
const BALL_COLOURS := [Color(0.1, 0.25, 0.85), Color(0.75, 0.1, 0.25)]

var lanes: Array = []
var balls: Array = []
var _pin_mesh: ArrayMesh
var _world: StaticBody3D


func build(f: Font) -> void:
	font = f
	_build_world()
	_pin_mesh = _make_pin_mesh()
	for i in range(ShackAnnex.LANE_X.size()):
		lanes.append(_fresh(i))
		_build_lane(i)


func _fresh(i: int) -> Dictionary:
	return {"lane": i, "players": 1, "state": "idle", "phase": "idle", "cur": 0, "rolls": [], "pins": [], "ball": null, "t": 0.0, "still": 0.0, "msg": "",
		"label": null, "board": null, "buttons": {}, "standing_before": 10, "thaw": [], "hook": 0.0, "fwd": Vector3(0, 0, 1), "gutter": false}


func lane_x(i: int) -> float:
	return float(ShackAnnex.LANE_X[i])


func _box(centre: Vector3, size: Vector3, friction := 0.5) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = centre
	_world.add_child(cs)


func _build_world() -> void:
	_world = StaticBody3D.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 0.35
	pm.bounce = 0.05
	_world.physics_material_override = pm
	add_child(_world)
	var z0 := ShackAnnex.Z0
	var z1 := ShackAnnex.Z1
	var foul := ShackAnnex.FOUL_Z
	var hw := ShackAnnex.HALF_W
	# Cut out the complete lane / gutter / pit footprints. A full hall slab
	# here used to cover every recessed gutter and the pin pit.
	_box(Vector3(0, -0.5, (z0 + foul) / 2.0), Vector3(hw * 2.0, 1.0, foul - z0))
	var left := -hw
	for centre in ShackAnnex.LANE_X:
		var edge_left: float = centre - ShackAnnex.LANE_W / 2.0 - ShackAnnex.GUTTER_W
		if edge_left > left:
			_box(Vector3((left + edge_left) / 2.0, -0.5, (foul + z1) / 2.0), Vector3(edge_left - left, 1.0, z1 - foul))
		left = centre + ShackAnnex.LANE_W / 2.0 + ShackAnnex.GUTTER_W
	if left < hw:
		_box(Vector3((left + hw) / 2.0, -0.5, (foul + z1) / 2.0), Vector3(hw - left, 1.0, z1 - foul))
	# the walls of the hall (so a ball cannot leave it)
	_box(Vector3(-hw - 0.5, 1.5, (z0 + z1) / 2.0), Vector3(1.0, 3.0, z1 - z0))
	_box(Vector3(hw + 0.5, 1.5, (z0 + z1) / 2.0), Vector3(1.0, 3.0, z1 - z0))
	_box(Vector3(0, 1.5, z1 + 0.5), Vector3(hw * 2.0, 3.0, 1.0))
	_box(Vector3(0, 1.5, z0 - 0.25), Vector3(hw * 2.0, 3.0, 0.5))
	# each lane: a slightly raised surface, two gutters sunk below it, rails, and a pit at the end
	for i in range(ShackAnnex.LANE_X.size()):
		var lx := lane_x(i)
		var len := LANE_END - foul
		_box(Vector3(lx, 0.003 - 0.5, foul + len / 2.0), Vector3(ShackAnnex.LANE_W, 1.0, len))
		for sx in [-1.0, 1.0]:
			# the gutter: a trough below the lane surface (the floor under it is cut away by raising the lane's neighbours)
			var gx: float = lx + sx * (ShackAnnex.LANE_W / 2.0 + ShackAnnex.GUTTER_W / 2.0)
			_box(Vector3(gx, -0.075 - 0.5, foul + len / 2.0), Vector3(ShackAnnex.GUTTER_W, 1.0, len))
			_box(Vector3(lx + sx * (ShackAnnex.LANE_W / 2.0 + ShackAnnex.GUTTER_W + 0.03), 0.1, foul + len / 2.0), Vector3(0.06, 0.4, len))
		# the pit behind the pin deck
		_box(Vector3(lx, PIT_FLOOR - 0.5, (LANE_END + z1 - 0.1) / 2.0), Vector3(ShackAnnex.LANE_W + 0.6, 1.0, z1 - 0.1 - LANE_END))
		_box(Vector3(lx, 0.5, z1 - 0.09), Vector3(ShackAnnex.LANE_W + 0.6, 2.0, 0.1))


func _build_lane(i: int) -> void:
	var lx := lane_x(i)
	var s: Dictionary = lanes[i]
	# the pedestal the ball waits on, beside the approach
	var iron := VRBuild.mat(Color(0.1, 0.1, 0.12), 0.4, 0.7)
	VRBuild.cylinder(self, 0.04, 0.8, Vector3(lx, 0.4, _ball_z()), iron, 0.04, Vector3.ZERO, 12)
	VRBuild.cylinder(self, 0.11, 0.05, Vector3(lx, 0.82, _ball_z()), VRBuild.mat(Color(0.3, 0.05, 0.1), 0.5), 0.09, Vector3.ZERO, 16)
	# the ball
	var b := RigidBody3D.new()
	b.collision_layer = 1 << (i + 1)
	b.collision_mask = 1 | b.collision_layer
	b.mass = BALL_MASS
	b.continuous_cd = true
	b.can_sleep = true
	b.linear_damp = 0.0
	b.angular_damp = 0.15
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	pm.bounce = 0.08
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = BALL_R
	cs.shape = sh
	b.add_child(cs)
	var gloss := StandardMaterial3D.new()
	gloss.roughness=0.2;gloss.metallic=0.12
	gloss.clearcoat_enabled=true;gloss.clearcoat=0.7;gloss.clearcoat_roughness=0.12
	var noise:=FastNoiseLite.new();noise.seed=53+i*19;noise.frequency=0.018
	noise.fractal_octaves=3
	var resin:=NoiseTexture2D.new();resin.width=256;resin.height=256;resin.seamless=true;resin.noise=noise
	var ramp:=Gradient.new();ramp.colors=PackedColorArray([BALL_COLOURS[i%2].darkened(0.72),BALL_COLOURS[i%2].lightened(0.3)])
	resin.color_ramp=ramp;gloss.albedo_texture=resin
	gloss.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var shape:=MeshInstance3D.new();shape.mesh=load("res://assets/renovation/bowling_ball.res")
	for surface in range(shape.mesh.get_surface_count()):
		if shape.mesh.surface_get_material(surface).resource_name=="shell":
			shape.set_surface_override_material(surface,gloss)
	b.add_child(shape)
	add_child(b)
	var t := Throwable.new()
	t.kind = "ball"
	t.game = self
	t.lane = i
	t.node = b
	t.radius = 0.2
	balls.append(t)
	s.ball = t
	_ball_home(t)
	# ten pins, standing but frozen until the lane is started
	for k in range(10):
		var p := _make_pin(i, k)
		s.pins.append(p)
	_place_pins(i, true)
	# a score display on the masking unit above the pins, one above the lane at the foul line, and the control panel beside the approach
	var mon := VRBuild.label(self, "", 0.085, Vector3(lx, 2.55, ShackAnnex.HEAD_PIN_Z + 0.83), Color(0.7, 1.0, 0.8), Vector3(0, PI, 0), 3, font, true)
	mon.line_spacing = -6.0
	s.board = mon
	mon.visible = false
	var reaction := BowlingReaction.new()
	reaction.build(self, Vector3(lx,2.50,ShackAnnex.HEAD_PIN_Z+0.80), font, i)
	s["reaction"] = reaction
	var near := VRBuild.label(self, "", 0.08, Vector3(lx, 2.55, ShackAnnex.FOUL_Z - 0.12), Color(0.7, 1.0, 0.8), Vector3(0, PI, 0), 3, font, true)
	near.line_spacing = -6.0
	s.label = near
	SportsFinish.panel(self, mon.position, PI, Vector2(1.45, 0.68))
	SportsFinish.panel(self, near.position, PI, Vector2(1.45, 0.68))
	var px := lx - 0.78
	var names := ["players", "go"]
	for k in range(2):
		var zz := ShackAnnex.FOUL_Z - 1.0 + (0.12 if k == 0 else -0.12)
		var bl := VRBuild.label(self, "", 0.04, Vector3(px + 0.025, 1.15, zz), Color(1.0, 0.85, 0.4), Vector3(0, PI / 2, 0), 2, font, true)
		bl.visible = false
		s.buttons[names[k]] = {"label": bl, "z": zz, "x": px}
	_refresh_buttons(i)


func _ball_z() -> float:
	return ShackAnnex.FOUL_Z - 1.3


func _ball_home(t: Throwable) -> void:
	var b := t.node as RigidBody3D
	b.freeze = true
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	b.global_transform = Transform3D(Basis.IDENTITY, Vector3(lane_x(t.lane), 0.85 + BALL_R, _ball_z()))
	t.state = "rest"
	t.held_hand = -1


func _make_pin(i: int, k: int) -> Dictionary:
	var b := RigidBody3D.new()
	b.collision_layer = 1 << (i + 1)
	b.collision_mask = 1 | b.collision_layer
	b.continuous_cd = true
	b.mass = PIN_MASS
	b.can_sleep = true
	b.linear_damp = 0.08
	b.angular_damp = 0.18
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	pm.bounce = 0.35
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	# A real flat base and tapered body; capsules balance on a hemisphere.
	var hull := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for level in [[0.030, 0.0], [0.0475, 0.08], [0.038, 0.17], [0.0255, 0.25], [0.041, 0.345], [0.02, 0.38]]:
		for segment in range(12):
			var angle := TAU * segment / 12.0
			points.append(Vector3(sin(angle) * float(level[0]), level[1], cos(angle) * float(level[0])))
	hull.points = points
	cs.shape = hull
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = _pin_mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.25
	mi.material_override = m
	b.add_child(mi)
	add_child(b)
	return {"body": b, "k": k, "alive": true, "home": _pin_home(i, k)}


func _pin_home(i: int, k: int) -> Vector3:
	# rows of 1, 2, 3 and 4 pins, the head pin nearest the bowler
	var row := 0
	var idx := k
	while idx > row:
		idx -= row + 1
		row += 1
	var x := lane_x(i) + (float(idx) - float(row) / 2.0) * PIN_SPACING
	return Vector3(x, 0.006, ShackAnnex.HEAD_PIN_Z + float(row) * ROW_SPACING)


func _place_pins(i: int, all: bool) -> void:
	var s: Dictionary = lanes[i]
	for p in s.pins:
		if all or p.alive:
			if all:
				p.alive = true
				(p.body as Node3D).visible = true
				_pin_set(p, p.home)


func _pin_set(p: Dictionary, at: Vector3) -> void:
	var b := p.body as RigidBody3D
	b.freeze = true
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	b.global_transform = Transform3D(Basis.IDENTITY, at)
	p["thaw"] = 0
	p["tipped"] = false


func _hide_pin(p: Dictionary) -> void:
	p.alive = false
	var b := p.body as RigidBody3D
	b.freeze = true
	b.global_transform = Transform3D(Basis.IDENTITY, Vector3(lane_x(0), -6.0, 5.0))
	(b as Node3D).visible = false


func _make_pin_mesh() -> ArrayMesh:
	# a lathe of the pin's outline: (radius, height) pairs, red neck stripes
	var prof := [[0.0, 0.0], [0.030, 0.0], [0.040, 0.02], [0.0475, 0.08], [0.0465, 0.12], [0.038, 0.17], [0.028, 0.215], [0.0255, 0.25], [0.029, 0.285], [0.0375, 0.32], [0.041, 0.345], [0.0375, 0.37], [0.02, 0.38], [0.0, 0.38]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 24
	for i in range(prof.size() - 1):
		var a: Array = prof[i]
		var b: Array = prof[i + 1]
		var red: bool = (float(a[1]) > 0.19 and float(a[1]) < 0.24) or (float(a[1]) > 0.255 and float(a[1]) < 0.27)
		var col := Color(0.8, 0.08, 0.1) if red else Color(0.96, 0.95, 0.9)
		for k in range(seg):
			var a0 := TAU * float(k) / float(seg)
			var a1 := TAU * float(k + 1) / float(seg)
			var p00 := Vector3(sin(a0) * float(a[0]), float(a[1]), cos(a0) * float(a[0]))
			var p01 := Vector3(sin(a1) * float(a[0]), float(a[1]), cos(a1) * float(a[0]))
			var p10 := Vector3(sin(a0) * float(b[0]), float(b[1]), cos(a0) * float(b[0]))
			var p11 := Vector3(sin(a1) * float(b[0]), float(b[1]), cos(a1) * float(b[0]))
			for tri in [[p00, p10, p11], [p00, p11, p01]]:
				var n: Vector3 = ((tri[1] - tri[0]) as Vector3).cross((tri[2] - tri[0]) as Vector3).normalized()
				for v in tri:
					st.set_color(col)
					var radial := Vector3(v.x, 0, v.z).normalized()
					var dy: float = float(b[1]) - float(a[1])
					var dr: float = float(b[0]) - float(a[0])
					var smooth_normal := Vector3(radial.x * dy, -dr, radial.z * dy).normalized()
					st.set_normal(smooth_normal if smooth_normal.length_squared() > 0.1 else -n)
					st.add_vertex(v)
	return st.commit()


# ---- picking up and throwing ----------------------------------------------------------------------------------
func things() -> Array:
	var out: Array = []
	for t in balls:
		if t.can_grab() and lanes[t.lane].state == "play" and lanes[t.lane].phase == "ready":
			out.append(t)
	return out


func idle_things() -> Array:
	var out: Array = []
	for t in balls:
		if t.can_grab() and lanes[t.lane].state != "play":
			out.append(t)
	return out


func wake(t: Throwable) -> void:
	_start(t.lane)


func hold_xf(_t: Throwable, hand_xf: Transform3D) -> Transform3D:
	return hand_xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.095, -0.04))


func on_grab(t: Throwable, _hand: int) -> void:
	t.state = "held"
	var b := t.node as RigidBody3D
	b.freeze = true
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	sound.emit("pickup", t.world_pos(), 0.5)


func cancel_hold(t: Throwable) -> void:
	_ball_home(t)


func on_release(t: Throwable, _hand_xf: Transform3D, vel: Vector3, angv: Vector3, hand: int) -> void:
	if lanes[t.lane].state != "play" or lanes[t.lane].phase != "ready":
		_ball_home(t)
		return
	for pin in lanes[t.lane].pins:
		if pin.alive:
			(pin.body as RigidBody3D).freeze = false
	var b := t.node as RigidBody3D
	var s: Dictionary = lanes[t.lane]
	var v := SportAssist.bowling(vel, b.global_position, lane_x(t.lane), ShackAnnex.HEAD_PIN_Z) if social_handling else vel
	if v.length() > 11.0:
		v = v.normalized() * 11.0
	b.freeze = false
	b.linear_velocity = v
	var fwd := Vector3(v.x, 0, v.z)
	fwd = fwd.normalized() if fwd.length() > 0.5 else Vector3(0, 0, 1)
	var roll_spin := clampf(angv.dot(fwd), -14.0, 14.0)            # a twist of the wrist about the direction of the throw
	var side := Vector3.UP.cross(fwd)
	b.angular_velocity = Vector3.UP.cross(Vector3(v.x, 0, v.z)) / BALL_R + fwd * roll_spin
	s.hook = -roll_spin * HOOK_GAIN
	s.fwd = fwd
	t.state = "flying"
	t.t = 0.0
	s.phase = "rolling"
	s.t = 0.0
	s.still = 0.0
	s.standing_before = int(BowlingScore.state(s.rolls[s.cur]).standing)
	s.gutter = false
	s["carry_used"] = false
	buzz.emit(hand, 0.4, 0.08)
	sound.emit("throw", t.node.global_position, 0.7)


# ---- controls -------------------------------------------------------------------------------------------------
func selector_targets() -> Array:
	var out: Array = []
	for i in range(lanes.size()):
		var panel := lanes[i].label as Label3D
		out.append({"id": "setup_b%d" % i, "label": "", "xf": panel.global_transform, "box": AABB(Vector3(-0.72,-0.34,-0.05),Vector3(1.44,0.68,0.1)), "colour": Color(0.85,0.67,0.36), "always": false})
	return out


func choose(id: String) -> bool:
	if not id.begins_with("g_b"):
		return false
	var i := int(id.substr(3, 1))
	var what := id.substr(5)
	if i < 0 or i >= lanes.size():
		return false
	var s: Dictionary = lanes[i]
	if what == "players" and s.state != "play":
		s.players = s.players % 4 + 1
	elif what == "go" and request_restart(s):
		_start(i)
	sound.emit("click", Vector3(lane_x(i), 1.1, ShackAnnex.FOUL_Z - 1.0), 0.5)
	_refresh_buttons(i)
	return true


func _refresh_buttons(i: int) -> void:
	var s: Dictionary = lanes[i]
	s.buttons.players.label.text = "PLAYERS\n%d" % s.players
	s.buttons.go.label.text = "CONFIRM" if float(s.get("restart_left", 0.0)) > 0.0 else "RESTART" if s.state == "play" else "NEW GAME"


func _start(i: int) -> void:
	var s: Dictionary = lanes[i]
	s["restart_left"] = 0.0
	s.state = "play"
	s.phase = "ready"
	s.cur = 0
	s.rolls = []
	for _p in range(s.players):
		s.rolls.append([])
	s.msg = "PLAYER 1 - GRAB THE BALL"
	_place_pins(i, true)
	_ball_home(s.ball)
	_refresh_buttons(i)


# ---- the game -----------------------------------------------------------------------------------------------------
func _standing(s: Dictionary) -> int:
	var n := 0
	for p in s.pins:
		if p.alive and _pin_up(p):
			n += 1
	return n


func _pin_up(p: Dictionary) -> bool:
	if p.get("tipped", false):
		return false
	var b := p.body as RigidBody3D
	var up := b.global_transform.basis.y.y
	var d := Vector2(b.global_position.x - p.home.x, b.global_position.z - p.home.z).length()
	return up > 0.93 and b.global_position.y > -0.08 and d < 0.35


func tick(delta: float) -> void:
	for i in range(lanes.size()):
		var s: Dictionary = lanes[i]
		if tick_restart(s, delta):
			_refresh_buttons(i)
		var t: Throwable = s.ball
		if t.state == "held":
			continue
		if s.phase == "rolling" or s.phase == "settle":
			_follow(i, delta)
		_text(i)


func _follow(i: int, delta: float) -> void:
	var s: Dictionary = lanes[i]
	var b := s.ball.node as RigidBody3D
	s.t += delta
	for pin in s.pins:
		if pin.alive and (pin.body as RigidBody3D).global_transform.basis.y.y < 0.70:
			pin["tipped"] = true
	var z := b.global_position.z
	if z >= ShackAnnex.FOUL_Z and z < ShackAnnex.HEAD_PIN_Z - 0.2 and absf(b.global_position.x - lane_x(i)) > ShackAnnex.LANE_W / 2.0 + BALL_R * 0.35:
		s.gutter = true
	# Social pin-carry assistance is gated by a genuine low pocket entry.
	# It adds contact energy; the normal physics/scoring still decide pinfall.
	if social_handling and not s.gutter and not s.get("carry_used", false) and z > ShackAnnex.HEAD_PIN_Z - 0.13 and z < ShackAnnex.HEAD_PIN_Z + 0.15:
		var offset := absf(b.global_position.x - lane_x(i))
		if offset > 0.025 and offset < 0.14 and b.global_position.y < 0.24 and b.linear_velocity.z > 3.0:
			s.carry_used = true
			for pin in s.pins:
				if pin.alive:
					var body: RigidBody3D = pin.body
					var side: float = signf(body.global_position.x - b.global_position.x)
					body.apply_impulse(Vector3(side * 0.22, 0, 1.3) * PIN_MASS, Vector3(0, 0.15, 0))
	# the hook: the lane's friction pulls a spinning ball sideways, mostly in the last half of the lane
	if s.phase == "rolling" and not s.gutter and absf(s.hook) > 0.01 and z > ShackAnnex.FOUL_Z + 4.5 and z < ShackAnnex.HEAD_PIN_Z - 0.5 and b.global_position.y < 0.2:
		var side := Vector3.UP.cross(s.fwd).normalized()
		b.apply_central_impulse(side * clampf(s.hook, -HOOK_MAX, HOOK_MAX) * BALL_MASS * delta)
	if s.phase == "rolling":
		var speed := b.linear_velocity.length()
		var done: bool = z > ShackAnnex.HEAD_PIN_Z + 1.2 or b.global_position.y < -0.15 or float(s.t) > 9.0
		if speed < 0.3:
			s.still += delta
		else:
			s.still = 0.0
		if done or s.still > 1.0:
			s.phase = "settle"
			s.t = 0.0
			s.still = 0.0
		return
	# settling: wait until everything has stopped moving
	var moving := false
	for p in s.pins:
		if p.alive:
			var pb := p.body as RigidBody3D
			if not pb.sleeping and (pb.linear_velocity.length() > 0.12 or pb.angular_velocity.length() > 0.5):
				moving = true
	if moving:
		s.still = 0.0
	else:
		s.still += delta
	if s.still > 0.9 or s.t > 7.0:
		_finish_ball(i)


func _finish_ball(i: int) -> void:
	var s: Dictionary = lanes[i]
	var after := _standing(s)
	var before: int = s.standing_before
	var knocked: int = clampi(before - after, 0, before)
	if s.gutter:
		knocked = 0
		_place_pins(i, false) # gutter rebounds cannot score or remove pins
	# pins that are down leave the lane
	for p in s.pins:
		if p.alive and not _pin_up(p):
			_hide_pin(p)
		elif p.alive:
			(p.body as RigidBody3D).freeze = true
	(s.rolls[s.cur] as Array).append(knocked)
	var msg := "%d PIN%s" % [knocked, "" if knocked == 1 else "S"]
	if knocked == 10 and before == 10:
		msg = "STRIKE!"
	elif before < 10 and knocked == before and knocked > 0:
		msg = "SPARE!"
	elif knocked == 0:
		msg = "GUTTER BALL" if s.gutter else "MISSED"
	s.msg = "P%d: %s" % [s.cur + 1, msg]
	if s.has("reaction"):
		(s.reaction as BowlingReaction).react(msg, knocked, s.cur)
	sound.emit("clear" if knocked == 10 else "hit", Vector3(lane_x(i), 0.6, ShackAnnex.HEAD_PIN_Z), 0.9)
	_next_ball(i)


func _next_ball(i: int) -> void:
	var s: Dictionary = lanes[i]
	var rolls: Array = s.rolls[s.cur]
	var st_after := BowlingScore.state(rolls)
	var st_before := BowlingScore.state(rolls.slice(0, rolls.size() - 1))
	var turn_over: bool = bool(st_after.done) or int(st_after.frame) != int(st_before.frame)
	if int(st_after.standing) == 10:
		_place_pins(i, true)                          # a strike, a spare, or the end of the frame: a fresh rack
	if turn_over:
		var all_done := true
		for q in range(s.players):
			if not BowlingScore.state(s.rolls[q]).done:
				all_done = false
		if all_done:
			s.state = "over"
			s.phase = "idle"
			var best := 0
			for q in range(s.players):
				if BowlingScore.total(s.rolls[q]) > BowlingScore.total(s.rolls[best]):
					best = q
			s.msg = result_text(s.rolls.map(func(rs): return BowlingScore.total(rs)))
			sound.emit("chime", Vector3(lane_x(i), 2.0, ShackAnnex.FOUL_Z), 1.0)
			_ball_home(s.ball)
			_refresh_buttons(i)
			return
		var guard := 0
		s.cur = (s.cur + 1) % s.players
		while BowlingScore.state(s.rolls[s.cur]).done and guard < 5:
			s.cur = (s.cur + 1) % s.players
			guard += 1
		_place_pins(i, int(BowlingScore.state(s.rolls[s.cur]).standing) == 10)
	s.phase = "ready"
	_ball_home(s.ball)


func _text(i: int) -> void:
	var s: Dictionary = lanes[i]
	var txt := ""
	if s.state == "idle":
		txt = "LANE %d\nPICK UP A BALL\nSELECT SCREEN FOR SETUP" % (i + 1)
	else:
		for p in range(s.players):
			var fr := BowlingScore.frames(s.rolls[p])
			var line := "%sP%d " % ["▶" if (p == s.cur and s.state == "play") else " ", p + 1]
			var cum := ""
			for f in fr:
				line += "%-3s " % f.text
				cum += "%-3s " % (str(f.total) if int(f.total) >= 0 else ".")
			txt += line + "\n" + "    " + cum + "\n"
		if s.state == "play":
			var st := BowlingScore.state(s.rolls[s.cur])
			txt += "FRAME %d / 10  |  BALL %d\n" % [st.frame, st.ball]
		txt += s.msg
	(s.label as Label3D).text = txt
	(s.board as Label3D).text = txt
