class_name PinTable
extends Node2D
## The zombie pinball table: a small 2D physics world drawn into a SubViewport that the machine shows under its glass.
## Table units: 400 wide, 800 tall, y runs down toward the player. Gravity pulls down the slope.

signal event(name: String)

const W := 400.0
const H := 800.0
const BALL_R := 9.0
const GRAVITY := 980.0
const SUBSTEPS := 2
const MAX_SPEED := 1500.0
const LANE_X := 366.0
const BUMPERS := [Vector2(195, 169), Vector2(160, 212), Vector2(238, 212)]       # the three brain bumpers in the artwork
const BUMPER_R := 21.0
# two banks of four lit targets, one down each side, where the artwork has its yellow and green light bars
const TARGETS := [Vector2(84, 402), Vector2(84, 424), Vector2(84, 446), Vector2(84, 468), Vector2(300, 402), Vector2(300, 424), Vector2(300, 446), Vector2(300, 468)]
const TARGET_R := 8.0
# lit inserts the ball rolls over: the orange lights down the middle lane and at the top, and the green arrows
const INSERTS := [Vector2(203, 79), Vector2(203, 98), Vector2(203, 275), Vector2(203, 293), Vector2(203, 311), Vector2(203, 334), Vector2(122, 252), Vector2(282, 252), Vector2(148, 370), Vector2(252, 370), Vector2(180, 575), Vector2(222, 575)]
const INSERT_COL := [Color(1, 0.7, 0.15), Color(1, 0.7, 0.15), Color(1, 0.6, 0.1), Color(1, 0.6, 0.1), Color(1, 0.6, 0.1), Color(1, 0.6, 0.1), Color(0.5, 1, 0.2), Color(0.5, 1, 0.2), Color(1, 0.3, 0.8), Color(0.2, 0.9, 1.0), Color(0.5, 1, 0.2), Color(0.5, 1, 0.2)]
# the two ramps drawn in the artwork: the ball can run up them, travel along (above everything else) and drop back onto the table
const RAMPS := [
	{"entry": Vector2(104, 364), "r": 20.0, "dir": Vector2(-0.35, -0.94), "path": [Vector2(104, 364), Vector2(86, 322), Vector2(48, 282), Vector2(30, 222), Vector2(58, 162), Vector2(112, 124), Vector2(140, 76), Vector2(150, 70)], "exit_vel": Vector2(40, 120), "col": Color(1, 0.2, 0.7), "name": "PINK RAMP"},
	{"entry": Vector2(250, 62), "r": 20.0, "dir": Vector2(1, 0.2), "path": [Vector2(250, 62), Vector2(300, 60), Vector2(346, 96), Vector2(366, 160), Vector2(358, 232), Vector2(336, 290), Vector2(326, 300)], "exit_vel": Vector2(-110, 150), "col": Color(1, 0.6, 0.1), "name": "ORANGE RAMP"},
]

var physical_view := false
var network_remote := false
var _accumulator := 0.0
var multiplier := 1
var combo := 0
var combo_time := 0.0
var ball_save := 0.0
var save_used := false
var skill_time := 0.0
var tilt_heat := 0.0
var tilted := false
var nudge_cool := 0.0
var bonus_balls := false
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
var target_lit := [false, false, false, false, false, false, false, false]
var insert_t: Array = []           # seconds each lit insert still glows
var on_ramp := -1
var ramp_d := 0.0                  # distance travelled along the ramp
var ramp_hits := 0
var sling_flash := [0.0, 0.0]
var sling_cool := [0.0, 0.0]
var message := ""
var message_t := 0.0
var clock := 0.0
var trail: Array = []
var segments: Array = []          # [a, b, restitution, kick]
var _launch_ready := true
var _slow_t := 0.0                # how long the ball has barely moved

const FLIP_LEN := 76.0
const LEFT_PIVOT := Vector2(122, 700)       # apart far enough that the ball drains between resting flippers (a gap of two balls), while raised flippers close the gap
const RIGHT_PIVOT := Vector2(278, 700)
const REST := 0.62                # radians below horizontal when down
const UP := -0.35                 # radians above horizontal when raised


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
	segments.append([Vector2(14, 200), Vector2(14, 596), 0.45, 0.0])
	segments.append([Vector2(380, 200), Vector2(380, 790), 0.3, 0.0])
	segments.append([Vector2(14, 596), Vector2(46, 622), 0.4, 0.0])
	segments.append([Vector2(46, 622), Vector2(46, 654), 0.4, 0.0])
	segments.append([Vector2(46, 654), Vector2(LEFT_PIVOT.x - 4, LEFT_PIVOT.y - 4), 0.4, 0.0])
	segments.append([Vector2(352, 596), Vector2(320, 622), 0.4, 0.0])
	segments.append([Vector2(320, 622), Vector2(320, 654), 0.4, 0.0])
	segments.append([Vector2(320, 654), Vector2(RIGHT_PIVOT.x + 4, RIGHT_PIVOT.y - 4), 0.4, 0.0])
	# the plunger lane's inner wall, with a gap at the top so a launched ball can curl onto the table
	segments.append([Vector2(352, 640), Vector2(352, 270), 0.4, 0.0])
	segments.append([Vector2(352, 640), Vector2(352, 790), 0.3, 0.0])
	segments.append([Vector2(352, 790), Vector2(380, 790), 0.1, 0.0])
	# slingshots above the flippers
	segments.append([Vector2(72, 584), Vector2(106, 650), 0.2, 340.0])
	segments.append([Vector2(328, 584), Vector2(294, 650), 0.2, 340.0])
	# a deflector guiding the ball off the top of the lane
	segments.append([Vector2(300, 110), Vector2(338, 150), 0.3, 0.0])


func reset_game() -> void:
	multiplier = 1
	combo = 0
	combo_time = 0.0
	target_lit.fill(false)
	insert_t.resize(INSERTS.size())
	insert_t.fill(0.0)
	score = 0
	balls_left = 5 if bonus_balls else 3
	game_over = false
	_new_ball()
	flash("BALL 1")


func _new_ball() -> void:
	tilted = false
	tilt_heat = 0.0
	nudge_cool = 0.0
	ball_save = 0.0
	save_used = false
	left_up = false
	right_up = false
	_slow_t = 0.0
	on_ramp = -1
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
	var power := maxf(plunger, 0.15)
	vel = Vector2(0, -(1050.0 + 650.0 * power))
	in_play = true
	ball_save = 8.0 if not save_used else 0.0
	skill_time = 4.0
	_launch_ready = false
	plunger = 0.0
	event.emit("launch")


func flippers(left: bool, right: bool) -> void:
	if not enabled or tilted:
		left = false
		right = false
	if left and not left_up:
		event.emit("flip")
	if right and not right_up:
		event.emit("flip")
	left_up = left
	right_up = right


func _process(delta: float) -> void:
	if network_remote:
		queue_redraw()
		return
	_accumulator = minf(_accumulator + delta, 0.1)
	while _accumulator >= 1.0 / 120.0:
		_simulate(1.0 / 120.0)
		_accumulator -= 1.0 / 120.0
	queue_redraw()


func _simulate(delta: float) -> void:
	ball_save = maxf(0, ball_save - delta)
	skill_time = maxf(0, skill_time - delta)
	combo_time = maxf(0, combo_time - delta)
	nudge_cool = maxf(0, nudge_cool - delta)
	tilt_heat = maxf(0, tilt_heat - delta * 0.14)
	clock += delta
	message_t = maxf(0.0, message_t - delta)
	for i in range(3):
		bump_flash[i] = maxf(0.0, bump_flash[i] - delta * 4.0)
	if insert_t.size() != INSERTS.size():
		insert_t.resize(INSERTS.size())
		insert_t.fill(0.0)
	for i in range(insert_t.size()):
		insert_t[i] = maxf(0.0, insert_t[i] - delta)
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
	if on_ramp >= 0:
		_ride_ramp(dt)
		return
	vel.y += GRAVITY * dt
	if vel.length() > MAX_SPEED:
		vel = vel.normalized() * MAX_SPEED
	ball += vel * dt
	for ri in range(RAMPS.size()):
		var rp: Dictionary = RAMPS[ri]
		if ball.distance_to(rp.entry) < float(rp.r) and vel.length() > 380.0 and vel.normalized().dot(rp.dir.normalized()) > 0.35:
			on_ramp = ri
			ramp_d = 0.0
			ramp_hits += 1
			event.emit("ramp")
			combo = mini(combo + 1, 5) if combo_time > 0.0 else 1
			combo_time = 8.0
			_score(1000 * combo, "ramp")
			flash(str(rp.name) + "  COMBO x%d" % combo)
			return
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
			if skill_time > 0.0:
				_score(1500, "target")
				flash("SKILL SHOT +1500")
				skill_time = 0.0
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
				var bank := 0 if i < 4 else 4
				var done := true
				for k in range(bank, bank + 4):
					if not target_lit[k]:
						done = false
				if done:
					_score(2500, "clear")
					multiplier = mini(multiplier + 1, 5)
					flash("BANK COMPLETE  x%d" % multiplier)
					for k in range(bank, bank + 4):
						target_lit[k] = false
			else:
				_score(50, "target")
	# lit inserts: roll over them and they glow; the four down the middle lane give a bonus when all are lit
	for i in range(INSERTS.size()):
		if ball.distance_to(INSERTS[i]) < 11.0 and insert_t[i] < 2.4:
			insert_t[i] = 3.0
			_score(50, "insert")
			if i >= 2 and i <= 5 and insert_t[2] > 0.0 and insert_t[3] > 0.0 and insert_t[4] > 0.0 and insert_t[5] > 0.0:
				_score(2000, "clear")
				flash("MIDDLE LANE  +2000")
				for k in range(2, 6):
					insert_t[k] = 0.0
	# a ball that rolls back down the lane and settles can be launched again
	if ball.x > 352.0 and ball.y > 690.0 and vel.length() < 40.0:
		in_play = false
		_launch_ready = true
		vel = Vector2.ZERO
		ball = Vector2(LANE_X, 700.0)
	# a ball that has stopped dead on the table (it can wedge between a post and a wall) gets a nudge
	if vel.length() < 25.0 and not (ball.x > 352.0 and ball.y > 690.0):
		_slow_t += dt
		if _slow_t > 3.0:
			_slow_t = 0.0
			vel = Vector2(randf_range(-160.0, 160.0), -520.0)
			flash("NUDGE")
	else:
		_slow_t = 0.0
	# lost down the middle, or out the bottom
	if ball.y > H + 40.0:
		_drain()
	trail.append(ball)
	if trail.size() > 7:
		trail.pop_front()


## While on a ramp the ball runs along its path above the table: nothing else can touch it. At the end it drops back onto the playfield.
func _ride_ramp(dt: float) -> void:
	var rp: Dictionary = RAMPS[on_ramp]
	var pts: Array = rp.path
	ramp_d += 420.0 * dt
	var d := ramp_d
	for i in range(pts.size() - 1):
		var seg_len: float = pts[i].distance_to(pts[i + 1])
		if d <= seg_len:
			ball = pts[i].lerp(pts[i + 1], d / maxf(seg_len, 0.001))
			trail.append(ball)
			if trail.size() > 7:
				trail.pop_front()
			return
		d -= seg_len
	ball = pts[pts.size() - 1]
	vel = rp.exit_vel
	on_ramp = -1


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
	if tilted:
		return
	score += points * multiplier
	if score > best:
		best = score
	event.emit(kind)


func _drain() -> void:
	if ball_save > 0.0 and not save_used and not tilted:
		_new_ball()
		save_used = true
		pull(0.7)
		launch()
		ball_save = 0.0
		flash("BALL SAVED")
		return
	in_play = false
	balls_left -= 1
	event.emit("drain")
	if balls_left <= 0:
		game_over = true
		flash("GAME OVER  " + _commas(score))
		event.emit("over")
	else:
		_new_ball()
		flash("BALL %d" % ((6 if bonus_balls else 4) - balls_left))


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
		draw_texture_rect(art, Rect2(0, 0, W, H), false, Color.WHITE)      # vibrant: the artwork at full brightness
	_draw_inserts()
	if physical_view:
		return
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


func _draw_inserts() -> void:
	for i in range(INSERTS.size()):
		var on: float = clampf(insert_t[i] if i < insert_t.size() else 0.0, 0.0, 1.0)
		var c: Color = INSERT_COL[i]
		var idle := 0.12 + 0.1 * sin(clock * 3.0 + float(i))
		draw_circle(INSERTS[i], 11.0 + on * 4.0, Color(c.r, c.g, c.b, idle + on * 0.55))
		draw_circle(INSERTS[i], 5.0, Color(1, 1, 1, idle * 0.8 + on * 0.9))
	if on_ramp >= 0:
		var pts: Array = RAMPS[on_ramp].path
		var rc: Color = RAMPS[on_ramp].col
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], Color(rc.r, rc.g, rc.b, 0.55), 10.0, true)


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


func nudge(direction := 1.0) -> void:
	if not in_play or network_remote or nudge_cool > 0.0 or tilted:
		return
	nudge_cool = 0.65
	tilt_heat += 1.0
	if tilt_heat >= 2.8:
		tilted = true
		ball_save = 0.0
		flippers(false, false)
		flash("TILT — scoring disabled for this ball")
	else:
		vel += Vector2(clampf(direction, -1, 1) * 100.0, -160.0)
		flash("CAREFUL" if tilt_heat > 1.8 else "NUDGE")


func snapshot() -> Dictionary:
	return {"ball": [ball.x, ball.y], "angles": [left_ang, right_ang], "score": score,
		"balls": balls_left, "play": in_play, "over": game_over, "ramp": on_ramp, "ramp_d": ramp_d,
		"multiplier": multiplier, "save": ball_save, "bumps": bump_flash.duplicate(), "targets": target_lit.duplicate()}


func apply_snapshot(d: Dictionary) -> void:
	if not d.get("ball") is Array or d.ball.size() != 2 or not d.get("angles") is Array or d.angles.size() != 2:
		return
	for value in d.ball + d.angles:
		if not (value is float or value is int) or not is_finite(float(value)):
			return
	ball = Vector2(clampf(d.ball[0], -100, 1500), clampf(d.ball[1], -100, 1500))
	left_ang = clampf(d.angles[0], -4, 4)
	right_ang = clampf(d.angles[1], -4, 4)
	score = clampi(int(d.get("score", 0)), 0, 1000000000)
	balls_left = clampi(int(d.get("balls", 0)), 0, 5)
	in_play = bool(d.get("play", false))
	game_over = bool(d.get("over", false))
	on_ramp = clampi(int(d.get("ramp", -1)), -1, 1)
	ramp_d = clampf(float(d.get("ramp_d", 0)), 0, 2000)
	multiplier = clampi(int(d.get("multiplier", 1)), 1, 5)
	ball_save = clampf(float(d.get("save", 0)), 0, 8)
	if d.get("bumps") is Array and d.bumps.size() == 3:
		bump_flash = d.bumps.duplicate()
	if d.get("targets") is Array and d.targets.size() == 8:
		target_lit = d.targets.duplicate()
