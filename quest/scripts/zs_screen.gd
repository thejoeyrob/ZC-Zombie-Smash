class_name ZSScreen
extends Node2D
## Draws the game on the cabinet monitor: a 343 x 412 world (same as the phone game), ported from renderer.js.
## It lives inside a SubViewport whose texture is shown on the cabinet screen.

const ART := "res://assets/art/"
const FONT_PATH := "res://assets/fonts/font-barlow-condensed-900.woff2"

var g: ZSEngine = null
var mode := "title"          # title | play | paused | over
var best := 0
var final_score := 0
var final_wave := 0
var final_kills := 0
var clock := 0.0
var topper_color := Color("#f5b800")

var _tex := {}
var _bounds := {}
var _font: Font
var _boss_trail := {"id": -1, "hp": 1.0, "trail": 1.0}
var W: float
var H: float


func _ready() -> void:
	ZSEngine.setup()
	W = ZSEngine.W
	H = ZSEngine.H
	var f := FileAccess.open(ART + "art-bounds.json", FileAccess.READ)
	if f:
		_bounds = JSON.parse_string(f.get_as_text())
	_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font


var _base := Transform2D.IDENTITY


func set_xf(pos: Vector2, rot: float) -> void:
	_base = Transform2D(rot, pos)
	draw_set_transform_matrix(_base)


func tex(file: String) -> Texture2D:
	if not _tex.has(file):
		var t = load(ART + file)
		_tex[file] = t
	return _tex[file]


func preload_all() -> void:
	for m in ZSEngine.MAPS:
		tex(m.file)
	for k in ZSEngine.ENEMIES:
		tex(ZSEngine.ENEMIES[k].art)
	for b in ZSEngine.BOSSES:
		for s in b.sprites:
			tex(s)
	for f in ["player-transparent.webp", "player-fire.webp", "player-hit.webp", "player-victory.webp", "player-wounded.webp", "prop-barrel.webp",
			"bullet-pistol.webp", "bullet-smg.webp", "bullet-dmr.webp", "title-bg.webp"]:
		tex(f)
	for k in ["heart", "clock", "speed", "shield", "bomb", "smg", "dmr"]:
		tex("pickup-%s.webp" % k)
	for k in ["chain", "ember", "coffee", "missile", "burger", "donut", "handcuffs", "venom", "bodypart", "disco"]:
		tex("weapon-%s.webp" % k)
	for c in ZSEngine.GLOW:
		tex("weapon-glowstick-%s.webp" % c)


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


# ---- drawing helpers --------------------------------------------------------------------------
func fit(file: String, x: float, y: float, w: float, h: float, alpha := 1.0, flip := false, bright := false, rot := 0.0) -> void:
	var t := tex(file)
	if t == null:
		return
	var b: Array = _bounds.get(file, [0, 0, t.get_width(), t.get_height()])
	var scale := minf(w / float(b[2]), h / float(b[3]))
	var dw: float = b[2] * scale
	var dh: float = b[3] * scale
	var col := Color(1.7, 1.7, 1.7, alpha) if bright else Color(1, 1, 1, alpha)
	draw_set_transform_matrix(_base * Transform2D(rot, Vector2(-1.0 if flip else 1.0, 1.0), 0.0, Vector2(x + w / 2.0, y + h / 2.0)))
	draw_texture_rect_region(t, Rect2(-dw / 2.0, -dh / 2.0, dw, dh), Rect2(b[0], b[1], b[2], b[3]), col)
	draw_set_transform_matrix(_base)


func text(s: String, x: float, y: float, size := 11, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var width := W
	var px := x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		px = x - width / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		px = x - width
	draw_string(_font, Vector2(px + 0.8, y + 0.8), s, align, width, size, Color(0, 0, 0, 0.8))
	draw_string(_font, Vector2(px, y), s, align, width, size, color)


func circle_line(c: Vector2, r: float, col: Color, width := 1.0, start := 0.0, end := TAU) -> void:
	draw_arc(c, r, start, end, 40, col, width, true)


func ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func ellipse_line(c: Vector2, rx: float, ry: float, col: Color, width := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in range(25):
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, width, true)


func hc(s: String) -> Color:
	return Color.html(s)


# ---- the whole frame ----------------------------------------------------------------------------
func _draw() -> void:
	_base = Transform2D.IDENTITY
	if W == 0.0:
		return
	if mode == "title":
		draw_title()
		return
	if g == null:
		return
	draw_world()
	draw_hud()
	if g.scene != null:
		draw_scene_overlay()
	if mode == "paused":
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.62))
		text("PAUSED", W / 2.0, H / 2.0 - 6.0, 30, hc("#f5da98"))
		text("PRESS MENU TO RESUME", W / 2.0, H / 2.0 + 18.0, 12, Color.WHITE)
	if mode == "over":
		draw_over()


func draw_title() -> void:
	var t := tex("title-bg.webp")
	if t != null:
		var k := maxf(W / t.get_width(), H / t.get_height())
		var w := t.get_width() * k
		var h := t.get_height() * k
		draw_texture_rect(t, Rect2((W - w) / 2.0, (H - h) / 2.0, w, h), false, Color(0.8, 0.8, 0.8))
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.35))
	var pulse := 0.5 + 0.5 * sin(clock * 2.0)
	text("ZOMBIE", W / 2.0, 92.0, 54, hc("#5dff52"))
	text("SMASH", W / 2.0, 142.0, 60, hc("#ff3b30"))
	text("HOLD THE LINE", W / 2.0, 168.0, 14, hc("#f2d9a0"))
	if best > 0:
		text("HIGH SCORE  " + ZSEngine.commas(best), W / 2.0, 30.0, 14, hc("#ffe467"))
	if int(clock * 2.0) % 2 == 0:
		text("PRESS FIRE", W / 2.0, 330.0, 26, hc("#fff3b0"))
	text("TO START GAME", W / 2.0, 350.0, 12, Color(1, 1, 1, 0.6 + 0.4 * pulse))
	text("GRAB THE STICK  ·  SMASH THE RED BUTTON", W / 2.0, 392.0, 10, Color(1, 1, 1, 0.7))


func draw_over() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.7))
	text("RUN COMPLETE", W / 2.0, 120.0, 26, hc("#f5da98"))
	text(ZSEngine.commas(final_score), W / 2.0, 180.0, 46, Color.WHITE)
	text("WAVE %d    KILLS %d" % [final_wave, final_kills], W / 2.0, 214.0, 14, hc("#cfe7c8"))
	if final_score >= best and final_score > 0:
		text("NEW HIGH SCORE!", W / 2.0, 244.0, 18, hc("#ffe467"))
	if int(clock * 2.0) % 2 == 0:
		text("PRESS FIRE", W / 2.0, 320.0, 22, hc("#fff3b0"))


func draw_world() -> void:
	var map: Dictionary = ZSEngine.MAPS[ZSEngine.map_index(g.wave)]
	draw_backdrop(map)
	var opens: Array = g.openings
	if ZSEngine.map_index(g.wave) == 4 and map.has("tileGrid"):
		draw_disco_floor(map, opens)
	arena_atmosphere(map)
	var style: String = map.get("entryStyle", "")
	if style != "tile" and style != "portal" and style != "edge":
		for e in map.entries:
			var x: float = e[0]
			var y: float = e[1]
			ellipse(Vector2(x, y + 12.0), 18.0, 7.0, hc("#102b2be0"))
			ellipse_line(Vector2(x, y + 12.0), 18.0, 7.0, hc(map.accent), 1.5)
			for n in range(-10, 11, 5):
				draw_line(Vector2(x + n, y + 8.0), Vector2(x + n, y + 16.0), hc("#bac7bd88"), 1.0)
	if style == "portal":
		for e in map.entries:
			var active := false
			for o in opens:
				if absf(o.x - e[0]) < 1.0 and absf(o.y - e[1]) < 1.0:
					active = true
			ellipse(Vector2(e[0], e[1] + 12.0), 27.0, 10.0, hc("#112a10e0") if active else hc("#173d1940"))
			ellipse_line(Vector2(e[0], e[1] + 12.0), 27.0, 10.0, hc(map.accent), 2.2 if active else 1.0)
	if g.arena != null:
		var idx := 0
		for target in g.arena.targets:
			var col := hc(map.accent) if target.lit else hc("#182b30b8")
			draw_circle(Vector2(target.x, target.y), 12.0, col)
			circle_line(Vector2(target.x, target.y), 12.0, hc(map.accent), 1.4)
			text(str(idx + 1), target.x, target.y + 4.0, 12, hc("#102027") if target.lit else Color.WHITE)
			if g.arena.cool > 0.0:
				circle_line(Vector2(target.x, target.y), 16.0, hc(map.accent), 1.4, -PI / 2.0, -PI / 2.0 + TAU * g.arena.cool / 12.0)
			idx += 1
	var off := Vector2.ZERO
	if g.shake > 0.0:
		off = Vector2(sin(g.t * 93.0) * g.shake, cos(g.t * 111.0) * g.shake * 0.55)
		set_xf(off, 0.0)
	draw_rect(Rect2(0, 0, W, 55), Color(0.02, 0.035, 0.03, 0.55))
	for x in range(0, int(W), 9):
		draw_line(Vector2(x, H - 38.0), Vector2(x + 4.0, H - 38.0), hc("#89baa52b"), 1.0)
	for item in g.pickups:
		if item.life < 3.0 and int(floor(item.age * (14.0 if item.life < 1.2 else 8.0))) % 2 == 1:
			continue
		var x: float = item.x
		var y: float = item.y + sin(item.age * 5.0) * 2.0
		draw_circle(Vector2(x, y), 16.0, hc("#6bbfe52a"))
		var rc := hc("#ffd24a") if item.type == "goldheart" else (hc("#ff6d7a") if item.type == "heart" else hc("#84d7f4"))
		circle_line(Vector2(x, y), 16.0, rc, 2.0 if item.type == "goldheart" else 1.0)
		if item.type == "goldheart":
			gold_heart(x, y, 1.0 + sin(item.age * 6.0) * 0.06)
			continue
		var art: String = "pickup-" + item.type + ".webp"
		if item.type == "shotgun":
			art = "pickup-smg.webp"
		elif item.type == "burst":
			art = "pickup-dmr.webp"
		elif item.type == "grenade":
			art = "pickup-bomb.webp"
		fit(art, x - 12.0, y - 12.0, 24.0, 24.0)
	for b in g.barrels:
		barrel(b)
	var order: Array = g.enemies.duplicate()
	if g.boss != null:
		order.append(g.boss)
	order.sort_custom(func(a, b): return a.y < b.y)
	for z in order:
		enemy(z)
	for b in g.bullets:
		if b.sp != "":
			special_bullet(b)
			continue
		set_xf(Vector2(b.x, b.y) + off, atan2(b.vy, b.vx) + PI / 6.0)
		fit(gun_art(b.gun), -11.0, -7.5, 22.0, 15.0)
		set_xf(off, 0.0)
	special_effects()
	for s in g.shots:
		shot(s)
	var p: Dictionary = g.player
	if not g.over:
		ellipse(Vector2(p.x, p.y + 30.0), 28.0, 7.0, Color(0, 0, 0, 0.45))
		if p.special != null:
			var sp := g.special_def(p.special.id)
			if not sp.is_empty() and (p.special.left > 2.0 or int(g.t * 8.0) % 2 == 1):
				var c := hc(sp.color)
				c.a = 0.6 + 0.3 * sin(g.t * 9.0)
				ellipse_line(Vector2(p.x, p.y - 6.0), 41.0, 49.0, c, 2.5)
		if p.shield > 0.0 or g.invincible:
			ellipse_line(Vector2(p.x, p.y - 6.0), 38.0, 46.0, hc("#8bdffc"), 2.0)
		var bob := sin(g.t * 18.0) * 1.2 if absf(g.input_axis) > 0.1 else 0.0
		var art := "player-transparent.webp"
		if p.hit > 0.0 and p.hit < 1.2:
			art = "player-hit.webp"
		elif p.fireFx > 0.0:
			art = "player-fire.webp"
		var a := 0.58 if (p.hit > 0.0 and int(g.t * 12.0) % 2 == 1) else 1.0
		fit(art, p.x - 35.0, p.y - 55.0 + bob, 70.0, 91.0, a)
		if p.fireFx > 0.0:
			var k := minf(1.0, p.fireFx / 0.065)
			var fp := Vector2(p.x, p.y - 52.0)
			draw_circle(fp, 17.0 * (0.6 + 0.4 * k), Color(1.0, 0.82, 0.35, 0.45 * k))
			draw_circle(fp, 7.0, Color(1.0, 0.97, 0.8, 0.8 * k))
			for ang in [-0.5, 0.0, 0.5]:
				var dir := Vector2(sin(ang), -cos(ang))
				draw_line(fp, fp + dir * (24.0 - absf(ang) * 14.0), Color(1.0, 0.91, 0.63, 0.9 * k), 3.0)
	for gr in g.grenades:
		fit("pickup-bomb.webp", gr.x - 10.0, gr.y - 10.0, 20.0, 20.0)
	var sparks := 0
	for f in g.effects:
		var a2 := clampf(f.life / f.total, 0.0, 1.0)
		if f.kind == "ring" or f.kind == "barrelBlast":
			var q: float = 1.0 - f.life / f.total
			var col := hc(f.color)
			col.a = a2
			circle_line(Vector2(f.x, f.y), maxf(0.5, f.r * q), col, (8.0 if f.kind == "barrelBlast" else 5.0) * (1.0 - q))
			var fill := hc("#ff7a2038") if f.kind == "barrelBlast" else hc(f.color)
			fill.a = (0.22 if f.kind == "barrelBlast" else 0.2) * a2
			draw_circle(Vector2(f.x, f.y), maxf(0.5, f.r * q), fill)
		else:
			sparks += 1
			var col2 := hc(f.color)
			col2.a = a2
			draw_rect(Rect2(f.x, f.y, f.r * 1.7, f.r * 1.7), col2)
	for pop in g.pops:
		text(pop.text, pop.x, pop.y - (1.0 - pop.life) * 22.0, 13, hc("#ffe467") if g.multiplier > 1 else Color.WHITE)
	set_xf(Vector2.ZERO, 0.0)
	if g.boss != null:
		var b = g.boss
		var def := g.boss_def(b.bossId)
		draw_rect(Rect2(10, 5, W - 20, 26), hc("#070c0dda"))
		text("%s  /  %d OF %d" % [b.name, b.stage, b.stages], W / 2.0, 16.0, 10, hc(def.accent))
		draw_rect(Rect2(17, 22, W - 34, 4), hc("#333333"))
		var hp := maxf(0.0, b.hp / b.maxHp)
		if _boss_trail.id != b.id or hp > _boss_trail.hp:
			_boss_trail = {"id": b.id, "hp": hp, "trail": hp}
		if hp < _boss_trail.hp:
			_boss_trail.hp = hp
		_boss_trail.trail = hp + (_boss_trail.trail - hp) * exp(-0.12)
		draw_rect(Rect2(17, 22, (W - 34) * _boss_trail.trail, 4), hc("#fff0bd"))
		draw_rect(Rect2(17, 22, (W - 34) * hp, 4), hc(def.accent))
	if g.active and not g.over and g.scene == null and (p.lives <= 1 or g.breaches >= 8):
		var warn := hc("#ff6666") if p.lives <= 1 else hc("#ffbf68")
		warn.a = 0.38 + sin(g.t * 3.0) * 0.12
		draw_rect(Rect2(1, 1, W - 2, H - 2), warn, false, 2.0)
	if g.banner_left > 0.0 and g.scene == null and g.banner != "":
		draw_rect(Rect2(26, 47, W - 52, 28), hc("#08100dcc"))
		text(g.banner, W / 2.0, 66.0, 16, hc("#f5da98"))


func gun_art(gun: String) -> String:
	match gun:
		"smg", "burst":
			return "bullet-smg.webp"
		"dmr":
			return "bullet-dmr.webp"
	return "bullet-pistol.webp"


func draw_hud() -> void:
	if g.boss != null:
		return
	var p: Dictionary = g.player
	draw_rect(Rect2(0, H - 30, W, 30), Color(0.02, 0.04, 0.035, 0.78))
	text("WAVE %d" % g.wave, 10.0, H - 11.0, 13, hc("#f5da98"), HORIZONTAL_ALIGNMENT_LEFT)
	text(ZSEngine.commas(g.score), W / 2.0, H - 11.0, 15, Color.WHITE)
	for i in range(p.lives):
		var hx := W - 14.0 - i * 15.0
		draw_heart(Vector2(hx, H - 15.0), 5.5, hc("#ff4a5a") if i < 5 else hc("#ffd24a"))
	var gun_name: String = ZSEngine.GUNS[p.gun].name
	var ammo := "" if not is_finite(p.ammo) else " " + str(int(p.ammo))
	if p.special != null:
		gun_name = g.special_def(p.special.id).name + " %d" % int(ceil(p.special.left))
		ammo = ""
	text(gun_name + ammo, 10.0, H - 36.0, 10, hc("#cfe7c8"), HORIZONTAL_ALIGNMENT_LEFT)
	text("GRENADES %d" % p.grenades, W - 10.0, H - 36.0, 10, hc("#8fd0ff"), HORIZONTAL_ALIGNMENT_RIGHT)
	if g.multiplier > 1:
		text("x%d" % g.multiplier, W - 10.0, 100.0, 22, hc("#ffe467"), HORIZONTAL_ALIGNMENT_RIGHT)


func draw_heart(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(21):
		var a := TAU * i / 20.0
		var x := 16.0 * pow(sin(a), 3.0)
		var y := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		pts.append(c + Vector2(x, y) * (r / 16.0))
	draw_colored_polygon(pts, col)


func gold_heart(x: float, y: float, k: float) -> void:
	draw_heart(Vector2(x, y), 9.0 * k, hc("#ffc93c"))
	draw_heart(Vector2(x - 1.0, y - 1.0), 5.0 * k, hc("#fff3a6"))


func barrel(b: Dictionary) -> void:
	if b.dead:
		return
	var thrown: bool = b.get("thrown", false)
	var w: float = float(ZSEngine.BARREL.throwWidth) if thrown else float(ZSEngine.BARREL.width)
	var h: float = float(ZSEngine.BARREL.throwHeight) if thrown else float(ZSEngine.BARREL.height)
	if thrown:
		# A fixed landing mark makes the throw readable; it never follows Joey.
		ellipse_line(Vector2(b.tx, b.ty), ZSEngine.BARREL.throwBlast, 12.0, hc("#ffb36ba8"), 1.4)
		draw_line(Vector2(b.tx - 5.0, b.ty - 5.0), Vector2(b.tx + 5.0, b.ty + 5.0), hc("#ffb36ba8"), 1.4)
		draw_line(Vector2(b.tx + 5.0, b.ty - 5.0), Vector2(b.tx - 5.0, b.ty + 5.0), hc("#ffb36ba8"), 1.4)
		set_xf(Vector2(b.x, b.y), b.rot)
		fit("prop-barrel.webp", -w / 2.0, -h / 2.0, w, h)
		set_xf(Vector2.ZERO, 0.0)
	else:
		ellipse(Vector2(b.x, b.y + h * 0.4), w * 0.42, 5.0, hc("#0007"))
		fit("prop-barrel.webp", b.x - w / 2.0, b.y - h / 2.0, w, h)


func enemy(z: Dictionary) -> void:
	if z.dead:
		return
	var def: Dictionary = g.boss_def(z.bossId) if z.get("boss", false) else {}
	var h: float
	var w: float
	if z.get("boss", false):
		h = 139.0 if (z.bossId == "drmantis" and z.stage == 3) else 113.0
		w = 130.0
	else:
		h = float(z.height)
		w = h * 0.82
	var alpha := 1.0
	if not z.get("boss", false) and z.get("emerge", 0.0) > 0.0:
		alpha = 1.0 - z.get("emerge", 0.0) / 0.45
	ellipse(Vector2(z.x, z.y + h * 0.34), w * 0.29, 5.0, hc("#0006"))
	if z.get("charge", 0) == 1:
		circle_line(Vector2(z.x, z.y), w * 0.5, hc("#fa994d"), 1.5)
	if z.get("boss", false) and z.wind != 0:
		text("ATTACK!", z.x, z.y - h * 0.62 - 5.0, 9, hc("#ffb04c"))
	var wobble := sin(z.age * (16.0 if z.get("type", "") == "runner" else 8.0)) * 1.4
	var art: String
	if not def.is_empty():
		art = def.sprites[z.stage - 1]
	elif z.type == "helmet" and z.hp < 2.2:
		art = "zombie-normal.webp"
	else:
		art = z.art
	var jx := sin(z.age * 70.0) * 2.6 if z.get("shake", 0) != 0 else 0.0
	if z.get("mode", "") == "shake":
		var p: Dictionary = g.player
		draw_dashed_line(Vector2(z.x, z.y), Vector2(p.x, p.y), hc("#ff5a4acc"), 2.0, 6.0)
	var lean := 0.0
	var hover := 0.0
	if z.get("boss", false):
		lean = clampf(float(z.vx) / 1100.0, -0.13, 0.13)
		if not str(z.get("mode", "")).begins_with("c"):
			hover = sin(z.age * 2.4) * 2.4
	fit(art, z.x - w / 2.0 + jx, z.y - h * 0.55 + wobble + hover, w, h, alpha, false, z.get("flash", 0.0) > 0.0, lean)
	if z.get("type", "") == "bulwark" and fmod(z.age, 3.5) < 2.0:
		circle_line(Vector2(z.x, z.y + 2.0), 23.0, hc("#82dffeaa"), 2.0, 0.1, PI - 0.1)
	if not z.get("boss", false) and z.maxHp > 2.0 and z.hp < z.maxHp:
		draw_rect(Rect2(z.x - 20.0, z.y - h * 0.58 - 3.0, 40.0, 3.0), hc("#080808"))
		draw_rect(Rect2(z.x - 20.0, z.y - h * 0.58 - 3.0, 40.0 * z.hp / z.maxHp, 3.0), hc("#ddb969"))


func shot(s: Dictionary) -> void:
	if s.kind == "record":
		draw_circle(Vector2(s.x, s.y), 12.0, hc("#15131c"))
		circle_line(Vector2(s.x, s.y), 12.0, hc("#cab5e4"), 1.2)
		circle_line(Vector2(s.x, s.y), 7.0, hc("#62586e"), 1.0)
		circle_line(Vector2(s.x, s.y), 9.0, hc("#62586e"), 1.0)
		var a: float = s.age * 7.0
		draw_circle(Vector2(s.x, s.y), 4.5, hc("#ff6bc8"))
		draw_line(Vector2(s.x, s.y), Vector2(s.x + cos(a) * 10.0, s.y + sin(a) * 10.0), hc("#ffffff55"), 1.0)
		return
	if s.kind == "chain":
		if s.age < s.wind:
			draw_dashed_line(Vector2(s.ox, s.oy), Vector2(s.ox + s.dx * s.reach, s.oy + s.dy * s.reach), hc("#ffd26877"), 1.5, 5.0)
			return
		var length := ZSEngine.hypot(s.x - s.ox, s.y - s.oy)
		var d := 0.0
		while d < length:
			var q := d / length
			var cx: float = s.ox + (s.x - s.ox) * q
			var cy: float = s.oy + (s.y - s.oy) * q
			draw_circle(Vector2(cx, cy), 3.5, hc("#fff0ac") if int(d) % 20 != 0 else hc("#a97520"))
			d += 10.0
		fit("weapon-chain.webp", s.x - 22.0, s.y - 22.0, 44.0, 44.0)
		return
	var rot: float
	if s.kind == "missile":
		rot = atan2(s.vy, s.vx) + PI / 4.0
	else:
		var spin := 1.7
		match s.kind:
			"disco": spin = 3.0
			"handcuffs": spin = 5.0
			"glowstick": spin = 5.0
			"tea": spin = 4.0
			"bodypart": spin = 3.5
		rot = s.age * spin
	var k := 1.6 if s.kind == "glowstick" else 1.0
	var f: String = "weapon-" + s.kind + ".webp"
	if s.kind == "glowstick":
		f = "weapon-glowstick-" + (s.color if s.color != "" else "green") + ".webp"
	set_xf(Vector2(s.x, s.y), rot)
	fit(f, -s.r * 1.4 * k, -s.r * 1.4 * k, s.r * 2.8 * k, s.r * 2.8 * k)
	set_xf(Vector2.ZERO, 0.0)


func special_bullet(b: Dictionary) -> void:
	var pos := Vector2(b.x, b.y)
	var ang := atan2(b.vy, b.vx)
	match b.sp:
		"hose":
			set_xf(pos, ang)
			ellipse(Vector2(-3, 0), 17.0, 7.0, Color(0.16, 0.66, 1.0, 0.45))
			ellipse(Vector2.ZERO, 11.0, 4.0, hc("#d6f3ff"))
		"rainbow":
			draw_circle(pos, 5.5, Color.from_hsv(fmod(g.t * 1.17 + b.id * 0.13, 1.0), 0.75, 1.0))
			draw_circle(pos + Vector2(-1, -1), 2.0, Color.WHITE)
		"bass":
			var k := 1.0 + sin(g.t * 26.0 + b.id) * 0.18
			circle_line(pos, 11.0 * k, hc("#ffb23d"), 3.0)
			circle_line(pos, 6.5 * k, hc("#fff2c4"), 1.6)
			draw_circle(pos, 3.0, hc("#fff6d6"))
		"beans":
			set_xf(pos, ang)
			ellipse(Vector2.ZERO, 4.4, 2.8, hc("#7a4a1f"))
			draw_line(Vector2(-3.4, 0), Vector2(3.4, 0), hc("#d9a566"), 0.9)
		"remover":
			draw_circle(pos, 7.0, Color(1.0, 0.77, 0.89, 0.9))
			draw_circle(pos + Vector2(-7, 5), 4.0, Color(1.0, 0.77, 0.89, 0.9))
			draw_circle(pos + Vector2(6, 6), 3.0, Color(1.0, 0.77, 0.89, 0.9))
			draw_circle(pos + Vector2(-2, -2.5), 2.2, Color.WHITE)
		"purge":
			draw_circle(pos, 10.0, Color(0.49, 1.0, 0.16, 0.4))
			draw_circle(pos, 5.0, hc("#d4ff9a"))
	set_xf(Vector2.ZERO, 0.0)


func special_effects() -> void:
	for b in g.beams:
		var k: float = b.life / b.total
		var w: float = b.width * (0.55 + 0.45 * k)
		var hue := fmod(g.t * 2.5, 1.0)
		draw_rect(Rect2(b.x - w, 0.0, w * 2.0, b.y), Color.from_hsv(hue, 0.6, 1.0, 0.55 * k + 0.25))
		draw_rect(Rect2(b.x - w * 0.28, 0.0, w * 0.56, b.y), Color(1, 1, 1, 0.9))
	for a in g.arcs:
		var pts := PackedVector2Array([Vector2(a.x1, a.y1)])
		var n := 5
		for i in range(1, n):
			var t := float(i) / n
			pts.append(Vector2(a.x1 + (a.x2 - a.x1) * t + sin(g.t * 90.0 + i * 3.1) * 6.0, a.y1 + (a.y2 - a.y1) * t + cos(g.t * 77.0 + i * 2.3) * 6.0))
		pts.append(Vector2(a.x2, a.y2))
		draw_polyline(pts, Color(0.72, 1.0, 0.35, minf(1.0, a.life / a.total + 0.2)), 2.4, true)


func draw_backdrop(map: Dictionary) -> void:
	var t := tex(map.file)
	if t == null:
		draw_rect(Rect2(0, 0, W, H), hc("#141b19"))
		return
	var k := maxf(W / t.get_width(), H / t.get_height())
	var w := t.get_width() * k
	var h := t.get_height() * k
	draw_texture_rect(t, Rect2((W - w) / 2.0, (H - h) / 2.0, w, h), false)


func draw_disco_floor(map: Dictionary, opens: Array) -> void:
	var grid: Dictionary = map.tileGrid
	var cols: int = int(grid.cols)
	var rows: int = int(grid.rows)
	var pts: Array = grid.pts
	var t := g.t
	var phase := int(floor(t / 3.0)) % 3
	var schemes := [[320.0, 185.0], [42.0, 280.0], [130.0, 215.0]]
	for row in range(rows):
		for col in range(cols):
			var a: Array = pts[row * (cols + 1) + col]
			var b: Array = pts[row * (cols + 1) + col + 1]
			var d: Array = pts[(row + 1) * (cols + 1) + col + 1]
			var e: Array = pts[(row + 1) * (cols + 1) + col]
			var cx: float = (a[0] + b[0] + d[0] + e[0]) / 4.0
			var cy: float = (a[1] + b[1] + d[1] + e[1]) / 4.0
			var dark := 0.0
			for o in opens:
				if absf(o.x - cx) < 2.0 and absf(o.y - (cy - 12.0)) < 2.0:
					dark = maxf(dark, 1.0 if o.age < 1.5 else maxf(0.0, 1.0 - (o.age - 1.5) / 0.5))
			var hue: float = schemes[phase][(row + col + int(floor(t / 1.5))) % 2]
			var pulse := 0.5 + 0.5 * sin(t * 2.4 + row * 0.9 + col * 1.7)
			var chase := maxf(0.0, 1.0 - absf(fmod(t * 1.1, rows + 2.0) - row - 1.0) * 0.9) * 0.14
			var ins := 1.2
			var poly := PackedVector2Array([
				Vector2(a[0] + ins, a[1] + ins), Vector2(b[0] - ins, b[1] + ins), Vector2(d[0] - ins, d[1] - ins), Vector2(e[0] + ins, e[1] - ins)])
			draw_colored_polygon(poly, Color.from_hsv(hue / 360.0, 0.9, 0.58 + pulse * 0.2, 0.25 + pulse * 0.13 + chase))
			if dark > 0.0:
				draw_colored_polygon(poly, Color(0.012, 0.0, 0.03, 0.95 * dark))


func arena_atmosphere(map: Dictionary) -> void:
	var index := ZSEngine.map_index(g.wave)
	var t := g.t
	if index == 0 or index == 2:
		for i in range(10):
			var side := (W - 25.0) if i % 2 == 1 else 25.0
			var y := 65.0 + fmod(fmod(i * 37.0 - t * (14.0 if index == 0 else 5.0), 260.0) + 260.0, 260.0)
			draw_rect(Rect2(side + sin(i + t * 0.6) * 6.0, y, 2.0 if index == 0 else 1.5, 2.0), hc("#ffc27866") if index == 0 else hc("#ffe8ae44"))
	elif index != 3 and index != 4:
		var c := hc(map.accent)
		c.a = 0.2 + 0.14 * (0.5 + 0.5 * sin(t * 1.1))
		for x in [22.0, W - 22.0]:
			for i in range(4):
				draw_circle(Vector2(x, 90.0 + i * 70.0), 4.0, c)


func draw_scene_overlay() -> void:
	var s = g.scene
	var def: Dictionary = g.boss_def(s.bossId) if s.get("bossId") != null else {}
	var kind: String = s.kind
	draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.02, 0.02, 0.82))
	var accent := hc(def.accent) if not def.is_empty() else hc("#f5da98")
	var line := ""
	var head := ""
	var art := ""
	match kind:
		"arrival":
			head = "WARNING" if s.phase == 0 else def.name
			line = def.tease if s.phase == 0 else (def.announce if s.phase == 1 else def.react)
			art = def.sprites[0]
		"mutation":
			head = def.name
			line = def.stageLines[maxi(0, int(s.stage) - 2)]
			art = def.sprites[int(s.stage) - 1]
		"down":
			head = "BOSS DOWN"
			line = def.finalLine if s.time < 1.7 else def.victory
			art = def.sprites[int(s.stage) - 1]
		"loss":
			head = "JOEY IS DOWN" if def.is_empty() else def.name
			line = "The camp was overrun." if def.is_empty() else def.playerLoss
			art = "player-wounded.webp" if def.is_empty() else def.sprites[0]
	if art != "":
		var pulse := 1.0 + 0.03 * sin(g.t * 5.0)
		fit(art, W / 2.0 - 120.0 * pulse, 88.0, 240.0 * pulse, 200.0 * pulse, 1.0)
	text(head, W / 2.0, 66.0, 26, accent)
	# wrap the line over two rows
	var words := line.split(" ")
	var rows := ["", ""]
	var r := 0
	for w in words:
		if r == 0 and (rows[0] + " " + w).length() > 30:
			r = 1
		rows[r] = (rows[r] + " " + w).strip_edges()
	text(rows[0], W / 2.0, 322.0, 15, Color.WHITE)
	text(rows[1], W / 2.0, 342.0, 15, Color.WHITE)
