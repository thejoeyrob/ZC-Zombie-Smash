class_name MGPaddle
extends MiniGame
## PADDLE BALL: a ball, two paddles. Get it past the computer; first to seven points wins.

const PW := 72.0
const PH := 10.0
var px := 180.0
var ax := 180.0
var ball := Vector2(180, 290)
var vel := Vector2.ZERO
var speed := 250.0
var mine := 0
var theirs := 0
var serving := true
var msg := "PRESS A TO SERVE"
var _py := 520.0
var _ay := 70.0


func _init() -> void:
	title = "PADDLE BALL"
	blurb = "STICK MOVES PADDLE\nA SERVES   FIRST TO 7"
	tint = Color(0.5, 0.85, 1.0)
	rng.randomize()
	lives = 0


func update(dt: float, st: Vector2, _btn: Dictionary, edge: Dictionary) -> void:
	t += dt
	if over:
		return
	px = clampf(px + st.x * 380.0 * dt, PW / 2.0, W - PW / 2.0)
	if serving:
		ball = Vector2(px, _py - 16.0)
		if edge.get("a", false) or edge.get("b", false):
			serving = false
			speed = 250.0
			vel = Vector2(rng.randf_range(-0.5, 0.5), -1.0).normalized() * speed
			msg = ""
		ax = lerpf(ax, W / 2.0, minf(1.0, 2.0 * dt))
		return
	# the computer follows the ball, a little slowly
	var want := ball.x
	ax = move_toward(ax, want, (150.0 + 12.0 * float(mine)) * dt)
	ax = clampf(ax, PW / 2.0, W - PW / 2.0)
	ball += vel * dt
	if ball.x < 7.0 or ball.x > W - 7.0:
		vel.x = -vel.x
		ball.x = clampf(ball.x, 7.0, W - 7.0)
	if vel.y > 0.0 and ball.y > _py - PH / 2.0 - 7.0 and ball.y < _py + 8.0 and absf(ball.x - px) < PW / 2.0 + 7.0:
		var k := (ball.x - px) / (PW / 2.0)
		speed = minf(speed + 14.0, 520.0)
		vel = Vector2(k * 0.9, -1.0).normalized() * speed
		ball.y = _py - PH / 2.0 - 7.0
	elif vel.y < 0.0 and ball.y < _ay + PH / 2.0 + 7.0 and ball.y > _ay - 8.0 and absf(ball.x - ax) < PW / 2.0 + 7.0:
		var k2 := (ball.x - ax) / (PW / 2.0)
		vel = Vector2(k2 * 0.9, 1.0).normalized() * speed
		ball.y = _ay + PH / 2.0 + 7.0
	if ball.y < TOP:
		mine += 1
		score += 100
		_point(true)
	elif ball.y > H:
		theirs += 1
		_point(false)


func _point(me: bool) -> void:
	serving = true
	vel = Vector2.ZERO
	msg = "POINT TO YOU!" if me else "POINT TO THE COMPUTER"
	if mine >= 7 or theirs >= 7:
		over = true
		won = mine >= 7
		msg = "YOU WIN!" if won else "YOU LOSE"


func draw(ci: CanvasItem, font: Font) -> void:
	ci.draw_rect(Rect2(0, TOP, W, H - TOP), Color(0.0, 0.04, 0.09))
	for i in range(14):
		ci.draw_rect(Rect2(W / 2.0 - 2.0, TOP + 8.0 + float(i) * 38.0, 4.0, 18.0), Color(0.12, 0.28, 0.4))
	glow_rect(ci, Rect2(px - PW / 2.0, _py - PH / 2.0, PW, PH), Color(0.35, 0.85, 1.0))
	glow_rect(ci, Rect2(ax - PW / 2.0, _ay - PH / 2.0, PW, PH), Color(1.0, 0.55, 0.3))
	ci.draw_circle(ball, 7.0, Color(1, 1, 0.9))
	text(ci, font, "%d" % mine, Vector2(20, H / 2.0 + 60), 54, Color(0.2, 0.5, 0.7))
	text(ci, font, "%d" % theirs, Vector2(20, H / 2.0 - 20), 54, Color(0.6, 0.3, 0.2))
	if msg != "":
		text(ci, font, msg, Vector2(0, H / 2.0 + 10), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, W)
