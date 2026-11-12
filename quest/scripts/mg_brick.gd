class_name MGBrick
extends MiniGame
## BRICK BREAK: bounce the ball off your paddle and knock out every brick. Three lives, and it speeds up every level.

const COLS := 9
const ROWS := 6
const BW := 36.0
const BH := 16.0
const PW := 66.0
var px := 180.0
var ball := Vector2(180, 500)
var vel := Vector2.ZERO
var bricks: Array = []
var launched := false
var level := 1
var speed := 280.0
var _py := 520.0


func _init() -> void:
	title = "BRICK BREAK"
	blurb = "STICK MOVES PADDLE\nA LAUNCHES THE BALL"
	tint = Color(1.0, 0.6, 0.25)
	rng.randomize()
	_fill()


func _fill() -> void:
	bricks = []
	for r in range(ROWS):
		var row: Array = []
		for c in range(COLS):
			row.append(true)
		bricks.append(row)


func _brick_rect(r: int, c: int) -> Rect2:
	return Rect2(18.0 + float(c) * (BW + 2.0), 86.0 + float(r) * (BH + 3.0), BW, BH)


func update(dt: float, st: Vector2, _btn: Dictionary, edge: Dictionary) -> void:
	t += dt
	if over:
		return
	px = clampf(px + st.x * 400.0 * dt, PW / 2.0, W - PW / 2.0)
	if not launched:
		ball = Vector2(px, _py - 14.0)
		if edge.get("a", false) or edge.get("b", false):
			launched = true
			vel = Vector2(rng.randf_range(-0.4, 0.4), -1.0).normalized() * speed
		return
	var steps := 3
	for _s in range(steps):
		ball += vel * dt / float(steps)
		if ball.x < 6.0 or ball.x > W - 6.0:
			vel.x = -vel.x
			ball.x = clampf(ball.x, 6.0, W - 6.0)
		if ball.y < TOP + 6.0:
			vel.y = absf(vel.y)
			ball.y = TOP + 6.0
		if vel.y > 0.0 and ball.y > _py - 12.0 and ball.y < _py + 4.0 and absf(ball.x - px) < PW / 2.0 + 6.0:
			var k := (ball.x - px) / (PW / 2.0)
			vel = Vector2(k * 0.95, -1.0).normalized() * speed
			ball.y = _py - 12.0
		for r in range(ROWS):
			for c in range(COLS):
				if bricks[r][c]:
					var rc := _brick_rect(r, c).grow(6.0)
					if rc.has_point(ball):
						bricks[r][c] = false
						score += (ROWS - r) * 10
						var inner := _brick_rect(r, c)
						if ball.x < inner.position.x - 1.0 or ball.x > inner.end.x + 1.0:
							vel.x = -vel.x
						else:
							vel.y = -vel.y
						speed = minf(speed + 2.5, 520.0)
						vel = vel.normalized() * speed
						_check_clear()
						break
	if ball.y > H + 10.0:
		lives -= 1
		launched = false
		if lives <= 0:
			over = true


func _check_clear() -> void:
	for r in bricks:
		for b in r:
			if b:
				return
	level += 1
	score += 200
	speed += 25.0
	launched = false
	_fill()


func draw(ci: CanvasItem, font: Font) -> void:
	ci.draw_rect(Rect2(0, TOP, W, H - TOP), Color(0.04, 0.03, 0.08))
	var cols := [Color(1.0, 0.3, 0.3), Color(1.0, 0.6, 0.2), Color(1.0, 0.9, 0.3), Color(0.4, 0.9, 0.4), Color(0.3, 0.7, 1.0), Color(0.7, 0.5, 1.0)]
	for r in range(ROWS):
		for c in range(COLS):
			if bricks[r][c]:
				glow_rect(ci, _brick_rect(r, c), cols[r])
	glow_rect(ci, Rect2(px - PW / 2.0, _py - 5.0, PW, 10.0), Color(0.85, 0.9, 1.0))
	ci.draw_circle(ball, 6.0, Color(1, 1, 0.8))
	text(ci, font, "LEVEL %d" % level, Vector2(0, H - 14), 16, Color(0.6, 0.6, 0.7), HORIZONTAL_ALIGNMENT_CENTER, W)
