class_name MGRocks
extends MiniGame
## ROCK BLASTER: a little ship in a field of drifting rocks. Turn, thrust and shoot; big rocks split into smaller ones.

var pos := Vector2(180, 300)
var vel := Vector2.ZERO
var ang := -PI / 2.0
var rocks: Array = []        # {p, v, r, shape: PackedVector2Array, a, spin}
var shots: Array = []        # {p, v, life}
var wave := 0
var safe := 2.0
var dead_t := 0.0
var sparks: Array = []


func _init() -> void:
	title = "ROCK BLASTER"
	blurb = "STICK TURNS   A THRUST\nB OR X FIRES"
	tint = Color(0.7, 0.85, 1.0)
	rng.randomize()
	_wave()


func _wave() -> void:
	wave += 1
	for _i in range(wave + 2):
		var p := Vector2.ZERO
		for _k in range(20):
			p = Vector2(rng.randf_range(0, W), rng.randf_range(TOP, H))
			if p.distance_to(pos) > 130.0:
				break
		_rock(p, 3)


func _rock(p: Vector2, size: int) -> void:
	var r: float = [0.0, 11.0, 20.0, 34.0][size]
	var pts := PackedVector2Array()
	var n := rng.randi_range(9, 12)
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * r * rng.randf_range(0.72, 1.1))
	rocks.append({"p": p, "v": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(25.0, 60.0 + 12.0 * wave), "r": r, "size": size, "shape": pts, "a": 0.0, "spin": rng.randf_range(-1.0, 1.0)})


func _wrap(p: Vector2) -> Vector2:
	return Vector2(fposmod(p.x, W), TOP + fposmod(p.y - TOP, H - TOP))


func update(dt: float, st: Vector2, btn: Dictionary, edge: Dictionary) -> void:
	t += dt
	if over:
		return
	for s in sparks:
		s.life -= dt
	sparks = sparks.filter(func(s): return s.life > 0.0)
	if dead_t > 0.0:
		dead_t -= dt
		if dead_t <= 0.0:
			pos = Vector2(W / 2.0, (H + TOP) / 2.0)
			vel = Vector2.ZERO
			safe = 2.5
	else:
		ang += st.x * 3.6 * dt
		if btn.get("a", false) or st.y < -0.6:
			vel += Vector2.from_angle(ang) * 190.0 * dt
		vel *= 1.0 - 0.35 * dt
		pos = _wrap(pos + vel * dt)
		safe = maxf(0.0, safe - dt)
		if (edge.get("b", false) or edge.get("c", false)) and shots.size() < 5:
			shots.append({"p": pos + Vector2.from_angle(ang) * 12.0, "v": vel + Vector2.from_angle(ang) * 340.0, "life": 1.1})
	for s in shots:
		s.p = _wrap(s.p + s.v * dt)
		s.life -= dt
	shots = shots.filter(func(s): return s.life > 0.0)
	var split: Array = []
	for rk in rocks:
		rk.p = _wrap(rk.p + rk.v * dt)
		rk.a += rk.spin * dt
	for s in shots:
		for rk in rocks:
			if s.life > 0.0 and (s.p as Vector2).distance_to(rk.p) < float(rk.r) + 2.0:
				s.life = 0.0
				rk["dead"] = true
				score += [0, 100, 50, 20][int(rk.size)]
				if int(rk.size) > 1:
					split.append([rk.p, int(rk.size) - 1])
				for _i in range(6):
					sparks.append({"p": rk.p, "v": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30, 90), "life": 0.5})
	rocks = rocks.filter(func(r): return not r.get("dead", false))
	for sp in split:
		_rock(sp[0], sp[1])
		_rock(sp[0], sp[1])
	if dead_t <= 0.0 and safe <= 0.0:
		for rk in rocks:
			if pos.distance_to(rk.p) < float(rk.r) + 7.0:
				lives -= 1
				dead_t = 1.5
				for _i in range(14):
					sparks.append({"p": pos, "v": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30, 120), "life": 0.8})
				if lives <= 0:
					over = true
				break
	if rocks.is_empty():
		_wave()


func draw(ci: CanvasItem, font: Font) -> void:
	ci.draw_rect(Rect2(0, TOP, W, H - TOP), Color(0.0, 0.0, 0.03))
	var line := Color(0.8, 0.9, 1.0)
	for rk in rocks:
		var pts := PackedVector2Array()
		for p in rk.shape:
			pts.append(rk.p + (p as Vector2).rotated(rk.a))
		pts.append(pts[0])
		ci.draw_polyline(pts, line, 1.6)
	if dead_t <= 0.0 and (safe <= 0.0 or int(t * 12.0) % 2 == 0):
		var f := Vector2.from_angle(ang)
		var r := f.rotated(PI / 2.0)
		ci.draw_polyline(PackedVector2Array([pos + f * 12.0, pos - f * 8.0 + r * 8.0, pos - f * 4.0, pos - f * 8.0 - r * 8.0, pos + f * 12.0]), Color(0.5, 1.0, 0.7), 1.8)
	for s in shots:
		ci.draw_circle(s.p, 2.0, Color(1.0, 1.0, 0.6))
	for s in sparks:
		ci.draw_circle(s.p + s.v * (0.5 - s.life) * 1.0, 1.5, Color(1.0, 0.7, 0.4, clampf(s.life * 2.0, 0.0, 1.0)))
