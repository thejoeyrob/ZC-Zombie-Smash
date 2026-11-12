class_name MGSerpent
extends MiniGame
## SERPENT: steer a growing snake round the board to eat the fruit. Hit a wall or yourself and it is over.

const CELL := 20
const COLS := 18
const ROWS := 24
var body: Array = []
var dir := Vector2i(1, 0)
var next_dir := Vector2i(1, 0)
var fruit := Vector2i(10, 8)
var step_t := 0.0
var grow := 0


func _init() -> void:
	title = "SERPENT"
	blurb = "STICK STEERS\nEAT THE FRUIT"
	tint = Color(0.4, 1.0, 0.45)
	rng.randomize()
	body = [Vector2i(5, 12), Vector2i(4, 12), Vector2i(3, 12)]
	_place_fruit()


func _place_fruit() -> void:
	for _i in range(200):
		var f := Vector2i(rng.randi_range(0, COLS - 1), rng.randi_range(0, ROWS - 1))
		if not body.has(f):
			fruit = f
			return


func update(dt: float, st: Vector2, _btn: Dictionary, _edge: Dictionary) -> void:
	t += dt
	if over:
		return
	if st.length() > 0.5:
		var want := Vector2i(1 if st.x > 0 else -1, 0) if absf(st.x) > absf(st.y) else Vector2i(0, 1 if st.y > 0 else -1)
		if want + dir != Vector2i.ZERO:
			next_dir = want
	step_t += dt
	var interval := maxf(0.06, 0.16 - 0.0025 * float(body.size()))
	while step_t >= interval and not over:
		step_t -= interval
		dir = next_dir
		var head: Vector2i = body[0] + dir
		if head.x < 0 or head.x >= COLS or head.y < 0 or head.y >= ROWS or body.has(head):
			over = true
			return
		body.push_front(head)
		if head == fruit:
			score += 10
			grow += 2
			_place_fruit()
		if grow > 0:
			grow -= 1
		else:
			body.pop_back()


func draw(ci: CanvasItem, font: Font) -> void:
	var o := Vector2(0, TOP)
	ci.draw_rect(Rect2(o, Vector2(COLS * CELL, ROWS * CELL)), Color(0.02, 0.07, 0.03))
	for x in range(COLS + 1):
		ci.draw_line(o + Vector2(x * CELL, 0), o + Vector2(x * CELL, ROWS * CELL), Color(0.05, 0.14, 0.07), 1.0)
	for y in range(ROWS + 1):
		ci.draw_line(o + Vector2(0, y * CELL), o + Vector2(COLS * CELL, y * CELL), Color(0.05, 0.14, 0.07), 1.0)
	var pulse := 0.8 + 0.2 * sin(t * 8.0)
	ci.draw_circle(o + Vector2(fruit.x * CELL + CELL / 2.0, fruit.y * CELL + CELL / 2.0), 7.0 * pulse, Color(1.0, 0.25, 0.3))
	ci.draw_circle(o + Vector2(fruit.x * CELL + CELL / 2.0 + 2, fruit.y * CELL + CELL / 2.0 - 3), 2.0, Color(1, 0.8, 0.8))
	for i in range(body.size()):
		var c: Vector2i = body[i]
		var k := 1.0 - 0.5 * float(i) / float(maxi(body.size(), 1))
		glow_rect(ci, Rect2(o + Vector2(c.x * CELL + 1, c.y * CELL + 1), Vector2(CELL - 2, CELL - 2)), Color(0.2 * k, 0.9 * k, 0.3 * k))
	var h: Vector2i = body[0]
	ci.draw_circle(o + Vector2(h.x * CELL + 6, h.y * CELL + 7), 2.0, Color.BLACK)
	ci.draw_circle(o + Vector2(h.x * CELL + 14, h.y * CELL + 7), 2.0, Color.BLACK)
