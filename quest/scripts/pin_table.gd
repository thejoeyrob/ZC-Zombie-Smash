class_name PinTable
extends Node2D
## The zombie pinball table: a small 2D physics world drawn into a SubViewport that the machine shows under its glass.
## Table units: 400 wide, 800 tall, y runs down toward the player. Gravity pulls down the slope.

signal event(name: String)

const W := 400.0
const H := 800.0
const BALL_R := 9.0
const GRAVITY := 980.0
const SUBSTEPS := 8
const MAX_SPEED := 1500.0
const LANE_X := 366.0
const BUMPERS := [Vector2(150, 250), Vector2(235, 230), Vector2(190, 320)]
const BUMPER_R := 23.0
const TARGETS := [Vector2(95, 130), Vector2(150, 100), Vector2(205, 88), Vector2(262, 100)]
const TARGET_R := 11.0

var enabled := false              # the machine only works once the code has been keyed in at the snack machine
var art: Texture2D
var font: Font
var ball := Vector2(LANE_X, 700.0)
var vel := Vector2.ZERO
var in_play := false
var score := 0
var best := 0
var balls_left := 3
var game_over := true
var plunger := 0.0                # 0..1 how far the plunger is pulled back
var left_up := false
var right_up := false
var left_ang := 0.52
var right_ang := 0.52
var bump_flash := [0.0, 0.0, 0.0]
var target_lit := [false, false, false, false]
var sling_flash := [0.0, 0.0]
var sling_cool := [0.0, 0.0]
var message := ""
var message_t := 0.0
var clock := 0.0
var trail: Array = []
var segments: Array = []          # [a, b, restitution, kick]
var _launch_ready := true

const FLIP_LEN := 66.0
const LEFT_PIVOT := Vector2(132, 742)
const RIGHT_PIVOT := Vector2(262, 742)
const REST := 0.50                # radians below horizontal when down
const UP := -0.46                 # radians above horizontal when raised


func _ready() -> void:
	_build_segments()
	reset_game()


func _build_segments() -> void:
	segments.clear()
	# the outer arch: a half circle across the top joining the side walls
	var centre := Vector2(200, 200)
	var radius := 180.0
	var prev := Vector2(20, 200)
	for i in range(1, 25):
		var a := PI - PI * float(i) / 24.0
		var p := centre + Vector2(cos(a), -sin(a)) * radius
		segments.append([prev, p, 0.45, 0.0])
		prev = p
	# side walls, inlanes and outlanes
	segments.append([Vector2(20, 200), Vector2(20, 600), 0.45, 0.0])
	segments.append([Vector2(380, 200), Vector2(380, 790), 0.3, 0.0])
	segments.append([Vector2(20, 600), Vector2(52, 628), 0.4, 0.0])
	segments.append([Vector2(52, 628), Vector2(52, 668), 0.4, 0.0])
	segments.append([Vector2(52, 668), Vector2(LEFT_PIVOT.x - 4, LEFT_PIVOT.y - 4), 0.4, 0.0])
	segments.append([Vector2(352, 628), Vector2(320, 652), 0.4, 0.0])
	segments.append([Vector2(320, 652), Vector2(320, 668), 0.4, 0.0])
	segments.append([Vector2(320, 668), Vector2(RIGHT_PIVOT.x + 4, RIGHT_PIVOT.y - 4), 0.4, 0.0])
	# the plunger lane's inner wall, with a gap at the top so a launched ball can curl onto the table
	segments.append([Vector2(352, 640), Vector2(352, 270), 0.4, 0.0])
	segments.append([Vector2(352, 640), Vector2(352, 790), 0.3, 0.0])
	segments.append([Vector2(352, 790), Vector2(380, 790), 0.1, 0.0])
	# slingshots above the flippers
	segments.append([Vector2(70, 610), Vector2(110, 676), 0.2, 340.0])
	segments.append([Vector2(310, 610), Vector2(272, 676), 0.2, 340.0])
	# a deflector guiding the ball off the top of the lane
	segments.append([Vector2(300, 110), Vector2(338, 150), 0.3, 0.0])


func reset_game() -> void:
	score = 0
	balls_left = 3
	game_over = false
	_new_ball()
	flash("BALL 1")


func _new_ball() -> void:
	ball = Vector2(LANE_X, 700.0)
	vel = Vector2.ZERO
	in_play = false
	_launch_ready = true
	plunger = 0.0
	trail.clear()


func flash(t: String) -> void:
	message = t
	message_t = 2.0


## Plunger pulled back by `amount` (0..1). Call launch() on release.
func pull(amount: float) -> void:
	if not enabled or in_play:
		return
	plunger = clampf(amount, 0.0, 1.0)


func launch() -> void:
	if not enabled:
		return
	if game_over:
		reset_game()
		return
	if in_play or not _launch_ready:
		plunger = 0.0
		return
	var power := maxf(plunger, 0.55)
	vel = Vector2(0, -(1050.0 + 650.0 * power))
	in_play = true
	_launch_ready = false
	plunger = 0.0
	event.emit("launch")


func flippers(left: bool, right: bool) -> void:
	if not enabled:
		left = false
		right = false
	if left and not left_up:
		event.emit("flip")
	if right and not right_up:
		event.emit("flip")
	left_up = left
	right_up = right


func _process(delta: float) -> void:
	clock += delta
	message_t = maxf(0.0, message_t - delta)
	for i in range(3):
		bump_flash[i] = maxf(0.0, bump_flash[i] - delta * 4.0)
	for i in range(2):
		sling_flash[i] = maxf(0.0, sling_flash[i] - delta * 5.0)
		sling_cool[i] = maxf(0.0, sling_cool[i] - delta)
	if enabled:
		var dt := minf(delta, 0.033) / SUBSTEPS
		for s in range(SUBSTEPS):
			_step(dt)
	queue_redraw()


func _step(dt: float) -> void:
	# flippers swing up fast and fall slower
	var l_target := UP if left_up else REST
	var r_target := UP if right_up else REST
	var l_prev := left_ang
	var r_prev := right_ang
	left_ang = move_toward(left_ang, l_target, (24.0 if left_up else 12.0) * dt)
	right_ang = move_toward(right_ang, r_target, (24.0 if right_up else 12.0) * dt)
	var l_omega := (left_ang - l_prev) / dt
	var r_omega := (right_ang - r_prev) / dt
	if not in_play:
		return
	vel.y += GRAVITY * dt
	if vel.length() > MAX_SPEED:
		vel = vel.normalized() * MAX_SPEED
	ball += vel * dt
	for seg in segments:
		_hit_segment(seg[0], seg[1], seg[2], seg[3])
	# the two flippers (their near end is the pivot; angles measured down from horizontal toward the middle)
	var l_tip := LEFT_PIVOT + Vector2(cos(left_ang), sin(left_ang)) * FLIP_LEN
	var r_tip := RIGHT_PIVOT + Vector2(-cos(right_ang), sin(right_ang)) * FLIP_LEN
	_hit_flipper(LEFT_PIVOT, l_tip, l_omega, 1.0)
	_hit_flipper(RIGHT_PIVOT, r_tip, r_omega, -1.0)
	for i in range(BUMPERS.size()):
		var d: Vector2 = ball - BUMPERS[i]
		var minr: float = BUMPER_R + BALL_R
		if d.length() < minr:
			var n := d.normalized() if d.length() > 0.001 else Vector2.UP
			ball = BUMPERS[i] + n * minr
			var vn := vel.dot(n)
			vel -= n * vn
			vel += n * maxf(520.0, -vn * 1.1)
			bump_flash[i] = 1.0
			_score(100, "bump")
	for i in range(TARGETS.size()):
		var d2: Vector2 = ball - TARGETS[i]
		var minr2: float = TARGET_R + BALL_R
		if d2.length() < minr2:
			var n2 := d2.normalized() if d2.length() > 0.001 else Vector2.UP
			ball = TARGETS[i] + n2 * minr2
			vel = vel.bounce(n2) * 0.7
			if not target_lit[i]:
				target_lit[i] = true
				_score(500, "target")
				if not target_lit.has(false):
					_score(5000, "clear")
					flash("TARGETS CLEARED  +5000")
					target_lit = [false, false, false, false]
			else:
				_score(50, "target")
	# a ball that rolls back down the lane and settles can be launched again
	if ball.x > 352.0 and ball.y > 690.0 and vel.length() < 40.0:
		in_play = false
		_launch_ready = true
		vel = Vector2.ZERO
		ball = Vector2(LANE_X, 700.0)
	# lost down the middle, or out the bottom
	if ball.y > H + 40.0:
		_drain()
	trail.append(ball)
	if trail.size() > 7:
		trail.pop_front()


func _hit_segment(a: Vector2, b: Vector2, rest: float, kick: float) -> void:
	var ab := b - a
	var t := clampf((ball - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	var closest := a + ab * t
	var d := ball - closest
	var dist := d.length()
	if dist >= BALL_R:
		return
	var n := d / dist if dist > 0.0001 else Vector2(-ab.y, ab.x).normalized()
	ball = closest + n * BALL_R
	var vn := vel.dot(n)
	if vn < 0.0:
		vel -= n * vn * (1.0 + rest)
		var si := 0 if a.x < 200.0 else 1
		if kick > 0.0 and absf(vn) > 140.0 and sling_cool[si] <= 0.0:
			vel += n * kick
			sling_flash[si] = 1.0
			sling_cool[si] = 0.25
			_score(10, "sling")
		elif absf(vn) > 250.0:
			event.emit("wall")


func _hit_flipper(pivot: Vector2, tip: Vector2, omega: float, side: float) -> void:
	var ab := tip - pivot
	var t := clampf((ball - pivot).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var closest := pivot + ab * t
	var radius := lerpf(9.0, 5.0, t)       # the flipper tapers toward its tip
	var d := ball - closest
	var dist := d.length()
	if dist >= BALL_R + radius:
		return
	var n := d / dist if dist > 0.0001 else Vector2.UP
	ball = closest + n * (BALL_R + radius)
	# speed of the flipper's surface at the contact point
	var r := closest - pivot
	var surf := Vector2(-r.y, r.x) * omega * side
	var rel := vel - surf
	var vn := rel.dot(n)
	if vn < 0.0:
		rel -= n * vn * (1.0 + 0.35)
		vel = rel + surf
	if absf(omega) > 8.0:
		event.emit("flipper_hit")


func _score(points: int, kind: String) -> void:
	score += points
	if score > best:
		best = score
	event.emit(kind)


func _drain() -> void:
	in_play = false
	balls_left -= 1
	event.emit("drain")
	if balls_left <= 0:
		game_over = true
		flash("GAME OVER  " + _commas(score))
		event.emit("over")
	else:
		_new_ball()
		flash("BALL %d" % (4 - balls_left))


static func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


# ---- drawing -----------------------------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.01, 0.06))
	if art != null:
		draw_texture_rect(art, Rect2(0, 0, W, H), false, Color(0.55, 0.5, 0.6))
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0.08, 0.38))
	# plunger lane and rails
	draw_rect(Rect2(352, 270, 28, 530), Color(0.0, 0.0, 0.0, 0.5))
	for seg in segments:
		var kick: float = seg[3]
		var col := Color(0.85, 0.9, 1.0, 0.95) if kick == 0.0 else Color(1.0, 0.35, 0.6, 0.9)
		if kick > 0.0:
			var idx := 0 if seg[0].x < 200.0 else 1
			col = col.lerp(Color.WHITE, sling_flash[idx])
		draw_line(seg[0], seg[1], col, 4.0, true)
	# drop targets
	for i in range(TARGETS.size()):
		var lit: bool = target_lit[i]
		var tc := Color(1.0, 0.85, 0.2) if lit else Color(0.2, 0.9, 1.0)
		draw_circle(TARGETS[i], TARGET_R + 3.0, Color(tc.r, tc.g, tc.b, 0.25))
		draw_circle(TARGETS[i], TARGET_R, tc)
		draw_circle(TARGETS[i], TARGET_R - 4.0, Color(1, 1, 1, 0.6 if lit else 0.25))
	# pop bumpers
	for i in range(BUMPERS.size()):
		var f: float = bump_flash[i]
		var glow := Color(1.0, 0.3, 0.7).lerp(Color(1, 1, 0.6), f)
		draw_circle(BUMPERS[i], BUMPER_R + 8.0 + f * 6.0, Color(glow.r, glow.g, glow.b, 0.22 + f * 0.3))
		draw_circle(BUMPERS[i], BUMPER_R, Color(0.15, 0.05, 0.2))
		draw_arc(BUMPERS[i], BUMPER_R - 2.0, 0, TAU, 32, glow, 5.0, true)
		draw_circle(BUMPERS[i], BUMPER_R - 9.0, glow.lerp(Color.WHITE, 0.35 + f * 0.5))
	# flippers
	_draw_flipper(LEFT_PIVOT, left_ang, 1.0, left_up)
	_draw_flipper(RIGHT_PIVOT, right_ang, -1.0, right_up)
	# plunger
	var py := 770.0 + plunger * 22.0
	draw_rect(Rect2(LANE_X - 8, py, 16, 30), Color(0.8, 0.82, 0.88))
	draw_rect(Rect2(LANE_X - 11, py - 4, 22, 6), Color(0.95, 0.15, 0.2))
	# ball: a metal sphere with a soft trail
	for i in range(trail.size()):
		draw_circle(trail[i], BALL_R * (0.35 + 0.5 * float(i) / trail.size()), Color(0.8, 0.9, 1.0, 0.07 * float(i)))
	if in_play or _launch_ready:
		draw_circle(ball, BALL_R, Color(0.72, 0.75, 0.82))
		draw_circle(ball + Vector2(-2.5, -3.0), BALL_R * 0.45, Color(1, 1, 1, 0.95))
		draw_arc(ball, BALL_R - 1.0, 0.2, 2.6, 12, Color(0.3, 0.35, 0.5), 2.0)
	# readouts
	_text("SCORE", Vector2(32, 38), 16, Color(0.6, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	_text(_commas(score), Vector2(32, 66), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_text("BALLS", Vector2(250, 38), 16, Color(0.6, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	for i in range(3):
		draw_circle(Vector2(268 + i * 22, 56), 7.0, Color(0.8, 0.85, 0.95) if i < balls_left else Color(0.2, 0.2, 0.3))
	if not enabled:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.72))
		var blink := 0.6 + 0.4 * sin(clock * 5.0)
		_text("OUT OF ORDER", Vector2(0, 360), 44, Color(1.0, 0.25, 0.2, blink), HORIZONTAL_ALIGNMENT_CENTER, W)
		_text("TRY THE SNACK MACHINE", Vector2(0, 410), 22, Color(1.0, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER, W)
		_text("KEY IN THE CODE", Vector2(0, 440), 22, Color(1.0, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER, W)
		return
	if message_t > 0.0:
		_text(message, Vector2(0, 450), 30, Color(1.0, 0.9, 0.3, minf(1.0, message_t)), HORIZONTAL_ALIGNMENT_CENTER, W)
	if game_over:
		_text("PRESS LAUNCH", Vector2(0, 520), 34, Color(0.4, 1.0, 0.6, 0.6 + 0.4 * sin(clock * 5.0)), HORIZONTAL_ALIGNMENT_CENTER, W)
		_text("BEST " + _commas(best), Vector2(0, 560), 22, Color(0.9, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, W)
	elif not in_play:
		_text("PULL THE PLUNGER", Vector2(0, 520), 24, Color(0.4, 1.0, 0.6, 0.6 + 0.4 * sin(clock * 5.0)), HORIZONTAL_ALIGNMENT_CENTER, W)


func _draw_flipper(pivot: Vector2, ang: float, side: float, up: bool) -> void:
	var dir := Vector2(cos(ang) * side, sin(ang))
	var tip := pivot + dir * FLIP_LEN
	var nrm := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([pivot + nrm * 9.0, tip + nrm * 5.0, tip - nrm * 5.0, pivot - nrm * 9.0])
	var body := Color(1.0, 0.8, 0.15) if up else Color(0.95, 0.55, 0.1)
	draw_colored_polygon(pts, Color(0.1, 0.05, 0.1))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), body, 3.0, true)
	draw_circle(pivot, 9.0, Color(0.75, 0.78, 0.85))
	draw_circle(pivot, 4.0, Color(0.3, 0.3, 0.4))
	draw_circle(tip, 5.0, body)


func _text(s: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := 0.0) -> void:
	if font == null:
		return
	var w := width if width > 0.0 else 300.0
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		x = pos.x - w
	draw_string(font, Vector2(x + 1.5, pos.y + 1.5), s, align, w, size, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(x, pos.y), s, align, w, size, col)
