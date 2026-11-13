class_name MGFKBC
extends MiniGame
## Native FKBC arcade adaptation using the owner's FKBC Battle Game character poses and arena.
const FLOOR := 478.0
const GRAV := 1500.0
const ROUND_TIME := 99.0
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
const NAMES := ["JACK", "JOHN", "JUSTIN", "PAUL"]
const OPPONENTS := ["jack","john","justin","paul"]
var assets := {}
var textures := {}
var arena: Texture2D
var hit_pause := 0.0
var impact := 0.0
var hit_sound := ""


func _init() -> void:
	title = "FKBC FIGHT NIGHT"
	blurb = "STICK: MOVE / JUMP / DUCK\nA / TRIGGER: PUNCH   B: KICK\nX: SPECIAL   Y: GUARD"
	tint = Color(1.0, 0.55, 0.3)
	lives = 0
	assets=JSON.parse_string(FileAccess.get_file_as_string("res://fkbc/fighters.json"))
	arena=load("res://fkbc/arena.jpg")
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
	banner = "ROUND %d   %s" % [round_no, NAMES[opp % 4]]
	banner_t = 1.6
	phase_t = 0.0


func _attack_box(f: Dictionary) -> Rect2:
	var reach := 0.0
	var h := 26.0
	var y: float = f.y - 70.0
	match str(f.state):
		"punch":
			reach = 46.0
			y = f.y - 100.0 + (22.0 if f.duck else 0.0)
		"kick":
			reach = 58.0
			y = f.y - 73.0
		_:
			return Rect2()
	var x: float = f.x + (6.0 if f.face > 0 else -6.0 - reach)
	return Rect2(x, y, reach, h)


func _body_box(f: Dictionary) -> Rect2:
	var h := 78.0 if f.duck else 130.0
	return Rect2(f.x - 17.0, f.y - h, 34.0, h)


func _damage_of(state: String) -> float:
	return 7.0 if state == "punch" else (11.0 if state == "kick" else 14.0)


func _hurt(target: Dictionary, attacker: Dictionary, dmg: float, state: String) -> void:
	var behind: bool = (attacker.x - target.x) * target.face < 0.0
	if target.blocking and not behind and target.y >= FLOOR - 1.0:
		hit_sound="block"
		target.hp -= dmg * 0.18
		target.x += attacker.face * 5.0
		return
	hit_pause=0.045;impact=0.12;hit_sound="kick" if state=="kick" else "punch"
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
	impact=maxf(0,impact-dt)
	if hit_pause>0:
		hit_pause=maxf(0,hit_pause-dt)
		return
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
					if opp >= 4:
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
			blasts.append({"x": f.x + f.face * 30.0, "y": f.y - 95.0, "dir": f.face, "owner": f})
	_controls_player(p, st, btn, edge, dt)
	_controls_cpu(c, p, dt)
	if p.stun <= 0.0 and p.state in ["idle", "walk"] and absf(c.x - p.x) > 4.0:
		p.face = signf(c.x - p.x)
	if absf(p.x-c.x)<42 and absf(p.y-c.y)<70:
		var side: float = 1.0 if p.x<=c.x else -1.0
		var mid: float = (p.x+c.x)*0.5
		p.x=clampf(mid-side*21,24,W-24);c.x=clampf(mid+side*21,24,W-24)
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


func _sprite(id: String, pose: String, face: float) -> Texture2D:
	var right := face>0
	if id=="joe": right=not right # Source Joe artwork uses reversed native facing.
	var fn: String = assets[id][pose]["R" if right else "L"]
	if not textures.has(fn): textures[fn]=load("res://fkbc/"+fn)
	return textures[fn]

func _draw_fighter(ci: CanvasItem, f: Dictionary, id: String) -> void:
	var pose: String="stance"
	if f.hp<=0: pose="defeated"
	elif phase!="fight" and f.hp>fighters[1 if f==fighters[0] else 0].hp: pose="winnerRaised"
	elif f.stun>0: pose="hitHigh"
	elif f.blocking: pose="standingBlock"
	elif f.state=="punch": pose="crouchPunch" if f.duck else "standingPunch"
	elif f.state=="kick": pose="jumpKick" if f.y<FLOOR-8 else "crouchKick" if f.duck else "standingKickBody"
	elif f.state=="cast": pose="fireball"
	elif f.duck: pose="crouch"
	elif f.y<FLOOR-8: pose="jump"
	# Pose recovery uses stance, as in the source's semantic frame sequences.
	if f.state in ["punch","kick"] and f.t<0.075: pose="stance"
	var tex:=_sprite(id,pose,f.face)
	var scale_by: float=148.0/float(assets[id].stance.h)
	var sz:=Vector2(tex.get_width(),tex.get_height())*scale_by
	var bob: float=absf(sin(f.walk))*1.5 if f.state=="walk" else 0.0
	ci.draw_texture_rect(tex,Rect2(Vector2(f.x-sz.x/2,f.y-sz.y-bob),sz),false)

func draw(ci: CanvasItem, font: Font) -> void:
	ci.draw_texture_rect_region(arena,Rect2(0,TOP,W,H-TOP),Rect2(385,0,510,720))
	ci.draw_rect(Rect2(0,TOP,W,H-TOP),Color(0,0,0,0.12))
	for k in range(2):
		var f: Dictionary=fighters[k]
		ci.draw_line(Vector2(f.x-20,FLOOR+2),Vector2(f.x+20,FLOOR+2),Color(0,0,0,0.4),6,true)
		_draw_fighter(ci,f,"joe" if k==0 else OPPONENTS[opp%4])
	for b in blasts:
		ci.draw_circle(Vector2(b.x,b.y),12,Color(0.9,0.16,0.05,0.4))
		ci.draw_circle(Vector2(b.x,b.y),6,Color(1,0.75,0.2))
	ci.draw_rect(Rect2(0,40,W,65),Color(0.025,0.025,0.03,0.94))
	for k in range(2):
		var x:=12.0 if k==0 else 204.0
		ci.draw_rect(Rect2(x,50,144,12),Color(0.28,0.05,0.06))
		ci.draw_rect(Rect2(x,50,144*maxf(0,fighters[k].hp)/100,12),Color(0.9,0.64,0.26))
		text(ci,font,"JOE" if k==0 else NAMES[opp%4],Vector2(x,83),16,Color.WHITE)
		text(ci,font,"●".repeat(wins[k]),Vector2(x,100),12,Color(1,0.65,0.2))
	text(ci,font,"%02d"%maxi(0,ceili(time_left)),Vector2(0,70),22,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,W)
	text(ci,font,"FIGHT %d / 4    •    ROUND %d"%[opp+1,round_no],Vector2(0,528),17,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,W)
	if banner_t>0:
		ci.draw_rect(Rect2(0,182,W,50),Color(0,0,0,0.8))
		text(ci,font,banner,Vector2(0,216),24,Color(1,0.79,0.35),HORIZONTAL_ALIGNMENT_CENTER,W)
