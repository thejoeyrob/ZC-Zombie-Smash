class_name MGAliens
extends MiniGame
## ALIEN WAVE: a squad of invaders steps across and down the screen. Shoot them from your cannon before they land.

const COLS := 8
const ROWS := 4
var cx := 180.0
var aliens: Array = []       # {x, y, kind, alive}
var dir := 1.0
var step_t := 0.0
var shot := Vector2(-1, -1)
var bombs: Array = []
var shields: Array = []      # destructible blocks {r: Rect2, hp}
var ufo := Vector2(-40, 62)
var ufo_t := 12.0
var wave := 1
var hit_t := 0.0
var _y := 520.0


func _init() -> void:
	title = "ALIEN WAVE"
	blurb = "STICK MOVES CANNON\nA FIRES"
	tint = Color(0.9, 0.5, 1.0)
	rng.randomize()
	_spawn()
	for k in range(4):
		for gx in range(8):
			for gy in range(3):
				shields.append({"r": Rect2(24.0 + float(k) * 86.0 + float(gx) * 7.0, 436.0 + float(gy) * 7.0, 7, 7), "hp": 1})


func _spawn() -> void:
	aliens = []
	for r in range(ROWS):
		for c in range(COLS):
			aliens.append({"x": 40.0 + float(c) * 36.0, "y": 100.0 + float(r) * 30.0 + float(wave - 1) * 6.0, "kind": r % 3, "alive": true})
	dir = 1.0
	bombs = []


func update(dt: float, st: Vector2, _btn: Dictionary, edge: Dictionary) -> void:
	t += dt
	if over:
		return
	hit_t = maxf(0.0, hit_t - dt)
	cx = clampf(cx + st.x * 230.0 * dt, 18.0, W - 18.0)
	if (edge.get("a", false) or edge.get("b", false)) and shot.y < 0.0:
		shot = Vector2(cx, _y - 14.0)
	if shot.y >= 0.0:
		shot.y -= 520.0 * dt
		if shot.y < TOP:
			shot = Vector2(-1, -1)
	var alive := 0
	for a in aliens:
		if a.alive:
			alive += 1
	if alive == 0:
		wave += 1
		score += 300
		_spawn()
		return
	var interval := maxf(0.05, 0.55 - 0.016 * float(COLS * ROWS - alive) - 0.03 * float(wave - 1))
	step_t += dt
	if step_t >= interval:
		step_t = 0.0
		var edge_hit := false
		for a in aliens:
			if a.alive and ((dir > 0.0 and a.x > W - 30.0) or (dir < 0.0 and a.x < 30.0)):
				edge_hit = true
		for a in aliens:
			if a.alive:
				if edge_hit:
					a.y += 16.0
				else:
					a.x += dir * 10.0
		if edge_hit:
			dir = -dir
	if rng.randf() < dt * (0.8 + 0.3 * float(wave)) and alive > 0:
		var pick: Dictionary = aliens[rng.randi_range(0, aliens.size() - 1)]
		if pick.alive:
			bombs.append(Vector2(pick.x, pick.y + 10.0))
	for i in range(bombs.size()):
		bombs[i] = (bombs[i] as Vector2) + Vector2(0, 190.0 * dt)
	for a in aliens:
		if a.alive and shot.y >= 0.0 and absf(shot.x - a.x) < 14.0 and absf(shot.y - a.y) < 10.0:
			a.alive = false
			shot = Vector2(-1, -1)
			score += [30, 20, 10][a.kind]
		if a.alive and a.y > _y - 24.0:
			over = true
	ufo_t -= dt
	if ufo_t <= 0.0:
		ufo.x += 90.0 * dt
		if shot.y >= 0.0 and absf(shot.x - ufo.x) < 18.0 and absf(shot.y - ufo.y) < 10.0:
			score += [50, 100, 150, 300][rng.randi_range(0, 3)]
			shot = Vector2(-1, -1)
			ufo = Vector2(-40, 62)
			ufo_t = 15.0
		elif ufo.x > W + 40.0:
			ufo = Vector2(-40, 62)
			ufo_t = 15.0
	for s in shields:
		if s.hp > 0:
			if shot.y >= 0.0 and (s.r as Rect2).grow(1).has_point(shot):
				s.hp = 0
				shot = Vector2(-1, -1)
			for i in range(bombs.size()):
				if (s.r as Rect2).grow(1).has_point(bombs[i]):
					s.hp = 0
					bombs[i] = Vector2(0, 9999)
	bombs = bombs.filter(func(b): return (b as Vector2).y < _y + 20.0)
	for b in bombs:
		if absf((b as Vector2).x - cx) < 16.0 and absf((b as Vector2).y - _y) < 10.0 and hit_t <= 0.0:
			lives -= 1
			hit_t = 1.2
			bombs = []
			if lives <= 0:
				over = true
			break


func draw(ci: CanvasItem, font: Font) -> void:
	ci.draw_rect(Rect2(0, TOP, W, H - TOP), Color(0.02, 0.0, 0.06))
	var cols := [Color(1.0, 0.5, 0.9), Color(0.5, 1.0, 0.8), Color(1.0, 0.85, 0.35)]
	var wob := int(t * 3.0) % 2
	for a in aliens:
		if not a.alive:
			continue
		var c: Color = cols[a.kind]
		var p := Vector2(a.x, a.y)
		match int(a.kind):
			0:                                     # a round bug with antennae
				ci.draw_circle(p, 9.0, c)
				ci.draw_line(p + Vector2(-5, -8), p + Vector2(-9, -14 - wob * 2), c, 2.0)
				ci.draw_line(p + Vector2(5, -8), p + Vector2(9, -14 - wob * 2), c, 2.0)
			1:                                     # a wide flat saucer with legs
				ci.draw_rect(Rect2(p + Vector2(-13, -5), Vector2(26, 9)), c)
				ci.draw_rect(Rect2(p + Vector2(-7, -9), Vector2(14, 5)), c)
				ci.draw_line(p + Vector2(-9, 4), p + Vector2(-12 - wob * 3, 11), c, 2.0)
				ci.draw_line(p + Vector2(9, 4), p + Vector2(12 + wob * 3, 11), c, 2.0)
			_:                                     # a tall helmet
				ci.draw_rect(Rect2(p + Vector2(-8, -9), Vector2(16, 14)), c)
				ci.draw_rect(Rect2(p + Vector2(-11, 3), Vector2(6, 6 + wob * 3)), c)
				ci.draw_rect(Rect2(p + Vector2(5, 3), Vector2(6, 6 + (1 - wob) * 3)), c)
		ci.draw_rect(Rect2(p + Vector2(-5, -3), Vector2(3, 3)), Color.BLACK)
		ci.draw_rect(Rect2(p + Vector2(2, -3), Vector2(3, 3)), Color.BLACK)
	for s in shields:
		if s.hp > 0:
			ci.draw_rect(s.r, Color(0.3, 0.9, 0.4))
	if hit_t <= 0.0 or int(t * 14.0) % 2 == 0:
		ci.draw_rect(Rect2(cx - 15.0, _y - 4.0, 30.0, 10.0), Color(0.5, 0.9, 1.0))
		ci.draw_rect(Rect2(cx - 3.0, _y - 12.0, 6.0, 9.0), Color(0.5, 0.9, 1.0))
	if shot.y >= 0.0:
		ci.draw_rect(Rect2(shot.x - 1.5, shot.y - 8.0, 3.0, 12.0), Color(1, 1, 0.7))
	for b in bombs:
		ci.draw_rect(Rect2((b as Vector2).x - 2.0, (b as Vector2).y - 6.0, 4.0, 11.0), Color(1.0, 0.4, 0.3))
	if ufo_t <= 0.0:
		ci.draw_rect(Rect2(ufo.x - 16.0, ufo.y - 5.0, 32.0, 9.0), Color(1.0, 0.3, 0.4))
		ci.draw_rect(Rect2(ufo.x - 8.0, ufo.y - 10.0, 16.0, 6.0), Color(1.0, 0.5, 0.55))
