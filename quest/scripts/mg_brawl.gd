class_name MGBrawl
extends MiniGame
## STREET BRAWL: a one-on-one fighting game against the computer. Move, jump, duck, block, punch, kick and throw an energy blast. Three opponents, best of
## three rounds each, and the computer gets harder. (Our own fighters and moves, drawn from simple shapes.)

const FLOOR := 478.0
const GRAV := 1500.0
const ROUND_TIME := 60.0
var fighters: Array = []        # [player, cpu]
var round_no := 1
var wins := [0, 0]
var opp := 0
var time_left := ROUND_TIME
var banner := ""
var banner_t := 0.0
var phase := "fight"             # fight, ko, next
var blasts: Array = []
var phase_t := 0.0
const NAMES := ["BRICK", "SPARK", "TITAN"]


func _init() -> void:
	title = "STREET BRAWL"
	blurb = "STICK: MOVE / JUMP / DUCK\nA PUNCH   B KICK\nC ENERGY BLAST   D BLOCK"
	tint = Color(1.0, 0.55, 0.3)
	lives = 0
	rng.randomize()
	_new_match()


func _fighter(x: float, face: float, col: Color, hair: Color) -> Dictionary:
	return {"x": x, "y": FLOOR, "vy": 0.0, "face": face, "hp": 100.0, "state": "idle", "t": 0.0, "col": col, "hair": hair, "blocking": false, "hit": false, "cool": 0.0, "stun": 0.0, "duck": false, "blast_cool": 0.0, "walk": 0.0}


func _new_match() -> void:
	round_no = 1
	wins = [0, 0]
	_new_round()


func _new_round() -> void:
	var cols := [Color(0.9, 0.35, 0.25), Color(0.35, 0.6, 0.95), Color(0.55, 0.3, 0.7)]
	var hairs := [Color(0.2, 0.12, 0.08), Color(0.95, 0.85, 0.3), Color(0.12, 0.12, 0.14)]
	fighters = [_fighter(100.0, 1.0, Color(0.2, 0.75, 0.45), Color(0.15, 0.1, 0.08)), _fighter(260.0, -1.0, cols[opp % 3], hairs[opp % 3])]
	blasts = []
	time_left = ROUND_TIME
	phase = "fight"
	banner = "ROUND %d   %s" % [round_no, NAMES[opp % 3]]
	banner_t = 1.6
	phase_t = 0.0


func _attack_box(f: Dictionary) -> Rect2:
	var reach := 0.0
	var h := 26.0
	var y: float = f.y - 70.0
	match str(f.state):
		"punch":
			reach = 46.0
			y = f.y - 78.0 + (22.0 if f.duck else 0.0)
		"kick":
			reach = 58.0
			y = f.y - 52.0
		_:
			return Rect2()
	var x: float = f.x + (6.0 if f.face > 0 else -6.0 - reach)
	return Rect2(x, y, reach, h)


func _body_box(f: Dictionary) -> Rect2:
	var h := 62.0 if f.duck else 104.0
	return Rect2(f.x - 17.0, f.y - h, 34.0, h)


func _damage_of(state: String) -> float:
	return 7.0 if state == "punch" else (11.0 if state == "kick" else 14.0)


func _hurt(target: Dictionary, attacker: Dictionary, dmg: float, state: String) -> void:
	var behind: bool = (attacker.x - target.x) * target.face < 0.0
	if target.blocking and not behind and target.y >= FLOOR - 1.0:
		target.hp -= dmg * 0.18
		target.x += attacker.face * 5.0
		return
	target.hp -= dmg
	target.stun = 0.28
	target.state = "hurt"
	target.t = 0.0
	target.x += attacker.face * (14.0 if state == "kick" else 8.0)
	if attacker == fighters[0]:
		score += int(dmg * 10.0)


func _controls_player(f: Dictionary, st: Vector2, btn: Dictionary, edge: Dictionary, dt: float) -> void:
	f.blocking = btn.get("d", false) and f.y >= FLOOR - 1.0
	f.duck = st.y > 0.6 and f.y >= FLOOR - 1.0
	if f.state in ["idle", "walk"] and f.stun <= 0.0 and not f.blocking:
		var dir := 0.0
		if absf(st.x) > 0.3 and not f.duck:
			dir = signf(st.x)
		f.x += dir * 130.0 * dt
		f.walk += absf(dir) * dt * 9.0
		f.state = "walk" if dir != 0.0 else "idle"
		if st.y < -0.6 and f.y >= FLOOR - 1.0:
			f.vy = -560.0
		if edge.get("a", false):
			f.state = "punch"
			f.t = 0.0
			f.hit = false
		elif edge.get("b", false):
			f.state = "kick"
			f.t = 0.0
			f.hit = false
		elif edge.get("c", false) and f.blast_cool <= 0.0:
			f.state = "cast"
			f.t = 0.0
			f.blast_cool = 1.1


func _controls_cpu(f: Dictionary, o: Dictionary, dt: float) -> void:
	var skill := 0.35 + 0.22 * float(opp) + 0.04 * float(round_no)
	var dist: float = o.x - f.x
	f.face = signf(dist) if absf(dist) > 4.0 else f.face
	f.blocking = false
	f.duck = false
	if f.stun > 0.0 or f.state not in ["idle", "walk"]:
		return
	var adist := absf(dist)
	f.cool -= dt
	# block sometimes when the player is attacking close by
	if o.state in ["punch", "kick"] and adist < 90.0 and rng.randf() < skill * 0.9 * dt * 6.0:
		f.blocking = true
		return
	if adist > 70.0:
		f.x += signf(dist) * (80.0 + 30.0 * skill) * dt
		f.state = "walk"
		f.walk += dt * 8.0
		if adist > 150.0 and f.blast_cool <= 0.0 and rng.randf() < dt * 0.7 * skill:
			f.state = "cast"
			f.t = 0.0
			f.blast_cool = 2.0 - skill
	else:
		f.state = "idle"
		if f.cool <= 0.0:
			var r := rng.randf()
			if r < 0.45:
				f.state = "punch"
			elif r < 0.8:
				f.state = "kick"
			else:
				f.x -= signf(dist) * 30.0
			f.t = 0.0
			f.hit = false
			f.cool = rng.randf_range(0.5, 1.2) / (0.7 + skill)
	if f.y >= FLOOR - 1.0 and o.state == "cast" and rng.randf() < dt * 3.0 * skill:
		f.vy = -520.0


func update(dt: float, st: Vector2, btn: Dictionary, edge: Dictionary) -> void:
	t += dt
	banner_t = maxf(0.0, banner_t - dt)
	if over:
		return
	var p: Dictionary = fighters[0]
	var c: Dictionary = fighters[1]
	if phase != "fight":
		phase_t += dt
		if phase_t > 2.2:
			if phase == "next":
				if wins[0] >= 2:
					opp += 1
					if opp >= 3:
						over = true
						won = true
						return
					round_no = 1
					wins = [0, 0]
					score += 500
					_new_round()
				elif wins[1] >= 2:
					over = true
					return
				else:
					round_no += 1
					_new_round()
			phase_t = 0.0
		return
	time_left -= dt
	for f in fighters:
		f.t += dt
		f.stun = maxf(0.0, f.stun - dt)
		f.blast_cool = maxf(0.0, f.blast_cool - dt)
		f.vy += GRAV * dt
		f.y += f.vy * dt
		if f.y >= FLOOR:
			f.y = FLOOR
			f.vy = 0.0
		f.x = clampf(f.x, 24.0, W - 24.0)
		# attacks finish
		var dur := 0.34 if f.state == "punch" else (0.46 if f.state == "kick" else (0.45 if f.state == "cast" else (0.28 if f.state == "hurt" else 0.0)))
		if dur > 0.0 and f.t >= dur:
			f.state = "idle"
		if f.state == "cast" and not f.hit and f.t > 0.18:
			f.hit = true
			blasts.append({"x": f.x + f.face * 30.0, "y": f.y - 66.0, "dir": f.face, "owner": f})
	_controls_player(p, st, btn, edge, dt)
	_controls_cpu(c, p, dt)
	if p.stun <= 0.0 and p.state in ["idle", "walk"] and absf(c.x - p.x) > 4.0:
		p.face = signf(c.x - p.x)
	# hits
	for k in range(2):
		var a: Dictionary = fighters[k]
		var d: Dictionary = fighters[1 - k]
		if a.state in ["punch", "kick"] and not a.hit and a.t > 0.1 and a.t < 0.26:
			if _attack_box(a).intersects(_body_box(d)):
				a.hit = true
				_hurt(d, a, _damage_of(str(a.state)), str(a.state))
	var keep: Array = []
	for b in blasts:
		b.x += b.dir * 300.0 * dt
		var target: Dictionary = fighters[1] if b.owner == fighters[0] else fighters[0]
		if _body_box(target).has_point(Vector2(b.x, b.y)) and not (target.duck and false):
			_hurt(target, b.owner, _damage_of("cast"), "cast")
			continue
		if b.x > -20.0 and b.x < W + 20.0:
			keep.append(b)
	blasts = keep
	# the round ends
	if p.hp <= 0.0 or c.hp <= 0.0 or time_left <= 0.0:
		var pw: bool = p.hp > c.hp
		if p.hp <= 0.0 and c.hp <= 0.0:
			pw = false
		wins[0 if pw else 1] += 1
		phase = "next"
		phase_t = 0.0
		banner = "K.O.!" if (p.hp <= 0.0 or c.hp <= 0.0) else "TIME!"
		banner_t = 2.0
		if pw:
			score += 100 + int(time_left)


func _stick_figure(ci: CanvasItem, f: Dictionary) -> void:
	var x: float = f.x
	var y: float = f.y
	var face: float = f.face
	var col: Color = f.col
	var flash: bool = f.stun > 0.0 and int(t * 30.0) % 2 == 0
	if flash:
		col = Color.WHITE
	var duck: bool = f.duck
	var hip := Vector2(x, y - (30.0 if duck else 46.0))
	var chest := hip + Vector2(0, -(26.0 if not duck else 18.0))
	var head := chest + Vector2(face * 2.0, -17.0)
	var walk_sw := sin(f.walk) * 12.0 if f.state == "walk" else 0.0
	var leg_len := 46.0 if not duck else 30.0
	# legs
	var foot1 := Vector2(x - 10.0 - walk_sw, y)
	var foot2 := Vector2(x + 10.0 + walk_sw, y)
	if f.state == "kick":
		var k := sin(clampf(f.t / 0.46, 0.0, 1.0) * PI)
		foot2 = hip + Vector2(face * (22.0 + 40.0 * k), 6.0 - 20.0 * k)
	if f.y < FLOOR - 2.0:
		foot1 = hip + Vector2(-8, 30)
		foot2 = hip + Vector2(10, 22)
	ci.draw_line(hip, foot1, col.darkened(0.3), 8.0)
	ci.draw_line(hip, foot2, col.darkened(0.3), 8.0)
	ci.draw_rect(Rect2(Vector2(foot1.x - 6, foot1.y - 3), Vector2(14, 6)), Color(0.1, 0.1, 0.12))
	ci.draw_rect(Rect2(Vector2(foot2.x - 6, foot2.y - 3), Vector2(14, 6)), Color(0.1, 0.1, 0.12))
	# body
	ci.draw_line(hip, chest, col, 16.0)
	# arms
	var sh := chest + Vector2(0, 2)
	var hand1 := sh + Vector2(face * 14.0, 18.0)
	var hand2 := sh + Vector2(face * 22.0, 6.0)
	if f.blocking:
		hand1 = sh + Vector2(face * 16.0, -8.0)
		hand2 = sh + Vector2(face * 18.0, 2.0)
	if f.state == "punch":
		var k2 := sin(clampf(f.t / 0.34, 0.0, 1.0) * PI)
		hand2 = sh + Vector2(face * (22.0 + 36.0 * k2), 4.0)
	if f.state == "cast":
		var k3 := clampf(f.t / 0.3, 0.0, 1.0)
		hand1 = sh + Vector2(face * (18.0 + 14.0 * k3), 2.0)
		hand2 = sh + Vector2(face * (22.0 + 18.0 * k3), 4.0)
	ci.draw_line(sh, hand1, col.lightened(0.15), 6.0)
	ci.draw_line(sh, hand2, col.lightened(0.15), 6.0)
	ci.draw_circle(hand1, 5.0, Color(0.95, 0.78, 0.62))
	ci.draw_circle(hand2, 5.0, Color(0.95, 0.78, 0.62))
	# head
	ci.draw_circle(head, 12.0, Color(0.95, 0.78, 0.62))
	ci.draw_rect(Rect2(Vector2(head.x - 12.0, head.y - 13.0), Vector2(24.0, 8.0)), f.hair)
	ci.draw_circle(head + Vector2(face * 5.0, -1.0), 1.8, Color.BLACK)
	ci.draw_line(head + Vector2(face * 3.0, -5.0), head + Vector2(face * 9.0, -4.0), Color.BLACK, 1.5)


func draw(ci: CanvasItem, font: Font) -> void:
	# the stage: a street at dusk
	ci.draw_rect(Rect2(0, TOP, W, FLOOR - TOP), Color(0.12, 0.1, 0.22))
	for i in range(6):
		ci.draw_rect(Rect2(float(i) * 62.0 + 4.0, 250.0 + float((i * 37) % 70), 52.0, 230.0), Color(0.07, 0.06, 0.15))
		for wy in range(6):
			if (i + wy) % 3 != 0:
				ci.draw_rect(Rect2(float(i) * 62.0 + 12.0, 262.0 + float((i * 37) % 70) + float(wy) * 28.0, 10.0, 14.0), Color(0.95, 0.8, 0.4, 0.7))
	ci.draw_rect(Rect2(0, FLOOR, W, H - FLOOR), Color(0.22, 0.2, 0.26))
	ci.draw_rect(Rect2(0, FLOOR, W, 5), Color(0.35, 0.33, 0.4))
	for f in fighters:
		ci.draw_circle(Vector2(f.x, FLOOR + 3.0), 18.0 - (FLOOR - f.y) * 0.05, Color(0, 0, 0, 0.35))
		_stick_figure(ci, f)
	for b in blasts:
		ci.draw_circle(Vector2(b.x, b.y), 12.0 + sin(t * 30.0) * 2.0, Color(0.4, 0.8, 1.0, 0.5))
		ci.draw_circle(Vector2(b.x, b.y), 7.0, Color(0.9, 1.0, 1.0))
	# health bars, names, time and round wins
	var p: Dictionary = fighters[0]
	var c: Dictionary = fighters[1]
	ci.draw_rect(Rect2(10, 46, 146, 14), Color(0.2, 0.06, 0.06))
	ci.draw_rect(Rect2(10, 46, 146.0 * clampf(p.hp / 100.0, 0.0, 1.0), 14), Color(0.35, 0.95, 0.45))
	ci.draw_rect(Rect2(204, 46, 146, 14), Color(0.2, 0.06, 0.06))
	var cw := 146.0 * clampf(c.hp / 100.0, 0.0, 1.0)
	ci.draw_rect(Rect2(350.0 - cw, 46, cw, 14), Color(1.0, 0.5, 0.3))
	ci.draw_string(font, Vector2(10, 78), "YOU  %s" % ("●".repeat(wins[0])), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 1.0, 0.85))
	ci.draw_string(font, Vector2(0, 78), "%s  %s" % [NAMES[opp % 3], "●".repeat(wins[1])], HORIZONTAL_ALIGNMENT_RIGHT, 350.0, 13, Color(1.0, 0.85, 0.7))
	ci.draw_string(font, Vector2(0, 62), "%02d" % maxi(0, ceili(time_left)), HORIZONTAL_ALIGNMENT_CENTER, W, 18, Color.WHITE)
	if banner_t > 0.0:
		ci.draw_string(font, Vector2(0, 220), banner, HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color(1.0, 0.9, 0.5, clampf(banner_t, 0.0, 1.0)))
