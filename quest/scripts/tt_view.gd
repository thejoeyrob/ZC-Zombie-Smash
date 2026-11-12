class_name TTView
extends Control
## The picture of TRUCKIN' & DRIVIN': the owner's own painted road, lorry, cars, cones, tacos and sheep (art from the Trakway-Trail game), drawn the
## same way as the original: the road art scrolls in thin strips, every hazard and pickup sits in one of five lanes.

signal sound(name: String)
signal haptic(strength: float, seconds: float)
signal finished(result: Dictionary)

const W := 420.0
const H := 640.0
const PLAYER_Y := 416.0
const SPRITE_RECTS := [[59, 16, 203, 287], [394, 4, 151, 310], [678, 16, 203, 287], [990, 16, 203, 287], [71, 329, 175, 285], [382, 330, 175, 281], [662, 362, 235, 221], [960, 386, 268, 141], [42, 638, 244, 302], [335, 642, 273, 298], [652, 637, 263, 303], [981, 655, 228, 234], [70, 940, 172, 265], [316, 940, 310, 275], [693, 940, 247, 293], [940, 951, 295, 266]]
const HAZARD_RECTS := [[16, 84, 428, 306], [444, 13, 359, 425], [978, 12, 272, 419], [1423, 50, 254, 368], [59, 474, 336, 388], [495, 474, 339, 389], [901, 454, 414, 394], [1361, 455, 383, 417]]
const TERRAIN_RECTS := [[105, 1, 279, 511], [384, 1, 369, 511], [810, 3, 239, 509], [1152, 1, 271, 511], [106, 512, 278, 504], [384, 512, 357, 503], [787, 512, 365, 503], [1152, 512, 321, 501]]
const EXTRAS_RECTS := [[55, 46, 307, 310], [362, 50, 362, 299], [724, 20, 307, 342], [1119, 40, 296, 313], [24, 410, 338, 238], [362, 388, 362, 336], [724, 388, 347, 336], [1091, 464, 325, 260], [28, 741, 334, 252], [362, 724, 362, 295], [724, 724, 302, 326], [1098, 724, 321, 298]]
const SPR := {"truck": 0, "trailer": 1, "car": 4, "redcar": 5, "cone": 6, "barrier": 7, "taco": 8, "job": 9, "finish": 10, "coin": 11, "sheep": 12, "face": 13, "flatbed": 14, "oil": 15, "crumb": 11}
const HAZ := {"lowbridge": 0, "weakbridge": 1, "bus": 2, "noentry": 3, "narrow": 4, "house": 6, "grass": 7}
const LABELS := {"lowbridge": "LOW BRIDGE", "weakbridge": "WEAK BRIDGE", "bus": "BUS LANE", "noentry": "NO ENTRY", "house": "MIND THE HOUSE", "grass": "KEEP OFF", "narrow": "NARROW PASS"}
const TITLES := {"lowbridge": "LOW BRIDGE", "weakbridge": "WEAK BRIDGE", "bus": "BUS LANE", "noentry": "NO ENTRY", "narrow": "NARROW", "grass": "VERGE", "house": "HOUSES", "works": "ROADWORKS"}

var game: TTGame
var state := "title"          # title, play, over
var font: Font
var tex := {}
var t := 0.0
var over_t := 0.0
var fx: Array = []
var best := 0.0
var shake := 0.0
var _hint := ""
var _hint_t := 0.0
var _night_node: Control
var _lights: Control
var auto := false             # an autopilot drives (for the video tour and the attract screen)


func setup(f: Font) -> void:
	font = f
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	for n in ["sprites", "roads", "terrain", "extras", "restrictions", "cover"]:
		var path := "res://assets/art/tt-%s.%s" % [n, "jpg" if n in ["roads", "cover"] else "png"]
		tex[n] = load(path)
	_lights = Control.new()
	_lights.size = Vector2(W, H)
	_lights.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lights.material = mat
	_lights.draw.connect(_draw_lights)
	add_child(_lights)
	reset_title()


func reset_title() -> void:
	state = "title"
	game = TTGame.new()
	game.row = 1e9            # nothing spawns on the title screen
	queue_redraw()


func start_game() -> void:
	game = TTGame.new()
	state = "play"
	fx.clear()
	_hint = ""
	sound.emit("chime")


func steer(target_lane: int) -> void:
	if state == "play":
		game.set_lane(target_lane)


func horn() -> void:
	if state == "play":
		game.horn()


func _autopilot() -> void:
	var g := game
	var want: int = g.lane
	var danger := false
	for e in g.items:
		if bool(e.done) or TTGame.PICKUPS.has(str(e.type)):
			continue
		var d: float = float(e.z) - g.distance
		if d > -40.0 and d < 380.0 and absf(float(e.lane) - g.x) < 0.8:
			danger = true
	if danger:
		for cand in [g.lane - 1, g.lane + 1, g.lane - 2, g.lane + 2]:
			if cand < 0 or cand > 4:
				continue
			var ok := true
			for e in g.items:
				if bool(e.done) or TTGame.PICKUPS.has(str(e.type)):
					continue
				var d2: float = float(e.z) - g.distance
				if d2 > -80.0 and d2 < 380.0 and int(e.lane) == cand:
					ok = false
			if ok:
				want = cand
				break
	else:
		for e in g.items:
			if (e.type == "crumb" or e.type == "coin" or e.type == "job" or e.type == "finish") and not bool(e.done):
				var d3: float = float(e.z) - g.distance
				if d3 > 0.0 and d3 < 400.0:
					want = int(e.lane)
					break
	if want != g.lane and fmod(t, 0.12) < 0.017:
		g.set_lane(want)
	if not g.sheep.is_empty() and bool(g.sheep.baa) and not bool(g.sheep.cleared) and g.time - float(g.sheep.baa_at) > 0.2:
		g.horn()


func tick(dt: float) -> void:
	t += dt
	if auto:
		if state == "title" or (state == "over" and over_t > 2.0):
			start_game()
		elif state == "play":
			_autopilot()
	if state == "play":
		game.tick(dt)
		_handle_events()
		if game.finished:
			state = "over"
			over_t = 0.0
			best = maxf(best, game.earned)
			finished.emit({"score": int(game.earned), "jobs": game.jobs})
	elif state == "over":
		over_t += dt
	for f in fx:
		f.age += dt
		f.y += f.vy * dt
	fx = fx.filter(func(f): return f.age < f.life)
	_hint_t = maxf(0.0, _hint_t - dt)
	shake = maxf(0.0, shake - dt * 30.0)
	queue_redraw()
	_lights.queue_redraw()


func _handle_events() -> void:
	var px: float = game.lane_x(game.x, game.distance)
	for e in game.events:
		match str(e.type):
			"cash":
				sound.emit("pickup")
				fx.append({"x": px, "y": PLAYER_Y - 50.0, "vy": -45.0, "age": 0.0, "life": 1.0, "text": "+%d" % int(e.value) if float(e.value) < 100.0 else str(e.label)})
			"crumb":
				sound.emit("click")
			"loss":
				sound.emit("hurt")
				haptic.emit(0.6, 0.15)
				shake = 8.0
				fx.append({"x": px, "y": PLAYER_Y - 50.0, "vy": -35.0, "age": 0.0, "life": 1.3, "text": str(e.label), "bad": true})
			"crash":
				sound.emit("explosion")
				haptic.emit(1.0, 0.35)
				shake = 14.0
			"delivery":
				sound.emit("clear")
				fx.append({"x": px, "y": PLAYER_Y - 80.0, "vy": -35.0, "age": 0.0, "life": 1.6, "text": "DELIVERED +%d" % int(e.pay)})
			"job":
				sound.emit("chime")
				fx.append({"x": W / 2.0, "y": 120.0, "vy": -10.0, "age": 0.0, "life": 2.0, "text": str(e.label) + "!"})
			"boost":
				sound.emit("power")
				fx.append({"x": px, "y": PLAYER_Y - 60.0, "vy": -35.0, "age": 0.0, "life": 1.2, "text": "TURBO!"})
			"night":
				sound.emit("chime")
				fx.append({"x": W / 2.0, "y": 120.0, "vy": -10.0, "age": 0.0, "life": 2.0, "text": "NIGHT SHIFT: COINS x2"})
			"baa":
				sound.emit("warn")
			"sheep_warning":
				_hint = "SHEEP AHEAD!"
				_hint_t = 2.0
			"sheep_clear":
				sound.emit("clear")
			"horn":
				sound.emit("alarm")
				haptic.emit(0.3, 0.1)
			"hint":
				_hint = str(e.text)
				_hint_t = 1.6
			"missed_job":
				_hint = "Missed the flag!"
				_hint_t = 1.4
			"jackknife":
				sound.emit("hurt")
				shake = 10.0
	game.events.clear()


# ---- drawing ----------------------------------------------------------------------------------------
func _spr(sheet: String, rects: Array, id: int, x: float, y: float, w: float, h: float, ang := 0.0, alpha := 1.0) -> void:
	var r: Array = rects[id]
	draw_set_transform(Vector2(x, y), ang, Vector2.ONE)
	draw_texture_rect_region(tex[sheet], Rect2(-w / 2.0, -h / 2.0, w, h), Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])), Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _label(text: String, x: float, y: float, col := Color(1.0, 0.96, 0.8), size := 10) -> void:
	var pos := Vector2(x - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0, y)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.09, 0.2, 0.2))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _road() -> void:
	var img: Texture2D = tex.roads
	var tile: float = float(img.get_width()) / 2.0
	var strip := 6.0
	var y := 0.0
	while y < H:
		var z: float = game.distance + PLAYER_Y - y
		var phase: float = fposmod(z, 5400.0)
		var raw: float = fposmod(z, tile * 2.0)
		var sy: float = clampf(tile * 2.0 - raw if raw >= tile else raw - strip, 0.0, tile - strip)
		var theme: int = game.road_theme(z)
		_road_strip(img, tile, theme, y, raw < tile, sy, strip, game.road_width(z), 1.0)
		if phase < 360.0 and z >= 5400.0:
			_road_strip(img, tile, game.road_theme(z - 5400.0), y, raw < tile, sy, strip, game.road_width(z - 5400.0), 1.0 - phase / 360.0)
		y += strip


func _road_strip(img: Texture2D, tile: float, idx: int, y: float, flip: bool, sy: float, strip: float, width: float, a: float) -> void:
	var src := Rect2(float(idx % 2) * tile, float(idx / 2) * tile + sy, tile, strip)
	var dx: float = (W - width) / 2.0
	var dst := Rect2(dx, y + strip, width, -strip) if flip else Rect2(dx, y, width, strip)
	draw_texture_rect_region(img, dst, src, Color(1, 1, 1, a))


func _terrain() -> void:
	var img: Texture2D = tex.terrain
	for e in game.items:
		if not e.get("road", false):
			continue
		var idx: int = TTGame.ROAD_TYPES.find(str(e.type))
		var rect: Array = TERRAIN_RECTS[idx]
		var length: float = float(e.get("length", 190.0))
		var off := 0.0
		while off < length:
			var z: float = float(e.z) + off
			var y: float = PLAYER_Y - (z - game.distance)
			var h: float = minf(6.0, length - off)
			if y > -8.0 and y < H + 8.0:
				var lane_w: float = game.road_width(z) * 0.56 / 5.0
				var sy: float = float(rect[1]) + float(rect[3]) * (1.0 - (off + h) / length)
				var sh: float = maxf(1.0, float(rect[3]) * h / length)
				draw_texture_rect_region(img, Rect2(game.lane_x(float(e.lane), z) - lane_w / 2.0, y - h, lane_w, h + 0.7), Rect2(float(rect[0]), sy, float(rect[2]), sh))
			off += 6.0
		var warn: float = float(e.z) - float(e.get("warning", 390.0))
		var wy: float = PLAYER_Y - (warn - game.distance)
		if wy > 28.0 and wy < H - 25.0:
			var wx: float = game.lane_x(float(e.lane), warn)
			var hid: int = {"lowbridge": 0, "weakbridge": 1, "bus": 2, "noentry": 3, "narrow": 4, "grass": 7, "house": 6, "works": 4}[str(e.type)]
			_spr("restrictions", HAZARD_RECTS, hid, wx, wy, 39.0, 39.0)
			_label(str(TITLES.get(str(e.type), "")), wx, wy + 29.0, Color(1.0, 0.95, 0.76), 7)
			_label("AHEAD", wx, wy + 39.0, Color(1.0, 0.95, 0.76), 7)


func _items() -> void:
	for e in game.items:
		if bool(e.done) or e.get("road", false):
			continue
		var y: float = PLAYER_Y - (float(e.z) - game.distance)
		var x: float = game.lane_x(float(e.lane), float(e.z))
		if y < -100.0 or y > H + 100.0:
			continue
		var typ: String = str(e.type)
		var collectible: bool = TTGame.PICKUPS.has(typ)
		var bob: float = sin(t * 5.0 + float(e.id)) * 5.0 if collectible else 0.0
		var w := 49.0
		match typ:
			"crumb": w = 23.0
			"coin": w = 31.0
			"car": w = 46.0
			"finish": w = 58.0
			"job": w = 54.0
		var h: float = 68.0 if typ == "car" else w
		if collectible:
			if typ == "night":
				_spr("extras", EXTRAS_RECTS, 0, x, y + bob, w, h)
			elif typ == "boost":
				_spr("extras", EXTRAS_RECTS, 1, x, y + bob, w, h)
			else:
				_spr("sprites", SPRITE_RECTS, int(SPR[typ]), x, y + bob, w, h)
			if typ == "job":
				_label("DOUBLE x2" if bool(e.get("double", false)) else "JOB", x, y - 39.0, Color(0.9, 0.73, 1.0) if bool(e.get("double", false)) else Color(0.65, 1.0, 0.89), 9)
			elif typ == "night":
				_label("NIGHT x2", x, y - 38.0, Color(0.74, 0.88, 1.0), 10)
			elif typ == "boost":
				_label("TURBO", x, y - 38.0, Color(1.0, 0.9, 0.6), 10)
			elif typ == "finish":
				_label("CASH OUT", x, y - 40.0, Color(0.65, 1.0, 0.89), 9)
		elif HAZ.has(typ):
			var ww: float = 64.0 if typ.contains("bridge") else 55.0
			_spr("restrictions", HAZARD_RECTS, int(HAZ[typ]), x, y, ww, ww)
			if LABELS.has(typ):
				_label(str(LABELS[typ]), x, y - 34.0, Color(1.0, 0.95, 0.82), 7)
		else:
			_spr("sprites", SPRITE_RECTS, int(SPR.get(typ, 6)), x, y, w, h, PI if bool(e.get("oncoming", false)) else 0.0)


func _sheep() -> void:
	if game.sheep.is_empty():
		return
	var s: Dictionary = game.sheep
	var y: float = PLAYER_Y - (float(s.z) - game.distance)
	for i in range(5):
		var x: float = game.lane_x(float(i), float(s.z))
		var rot: float = sin(t * 5.0 + float(i)) * 0.12
		var sy: float = y + sin(float(i) * 3.0) * 17.0
		if bool(s.cleared):
			var mv: float = maxf(0.0, game.time - float(s.baa_at) - 0.3) * 120.0
			x += (-1.0 if i < 2 else 1.0) * mv
			rot = -1.5 if i < 2 else 1.5
			sy += sin(t * 20.0 + float(i)) * 5.0
		_spr("sprites", SPRITE_RECTS, 12, x, sy, 50.0, 52.0, rot)


func _rig() -> void:
	var g := game
	var px: float = g.lane_x(g.x, g.distance)
	var cab_angle: float = clampf((float(g.lane) - g.x) * 0.16, -0.2, 0.2)
	var pose: Dictionary = g.rig_pose(px, PLAYER_Y, cab_angle, g.angle, clampf((g.trailer - g.rear) * 0.55, -0.8, 0.8))
	var alpha: float = 0.55 if (g.invulnerable > 0.0 and int(t * 13.0) % 2 == 0) else 1.0
	_spr("sprites", SPRITE_RECTS, 0, px, PLAYER_Y, 61.0, 81.0, cab_angle, alpha)
	if not g.job.is_empty() and bool(g.job.double):
		var rp: Vector2 = pose.rear
		_spr("sprites", SPRITE_RECTS, 14, rp.x, rp.y, 56.0, 108.0, float(pose.rear_angle), alpha)
	var tp: Vector2 = pose.trailer
	_spr("sprites", SPRITE_RECTS, 1, tp.x, tp.y, 59.0, 116.0, float(pose.trailer_angle), alpha)


func _draw_lights() -> void:
	if state != "play" or game.night.is_empty():
		return
	var px: float = game.lane_x(game.x, game.distance)
	for dir in [-1.0, 1.0]:
		var pts := PackedVector2Array([Vector2(px + dir * 15.0, PLAYER_Y - 40.0), Vector2(px + dir * 15.0 - 70.0, PLAYER_Y - 340.0), Vector2(px + dir * 15.0 + 70.0, PLAYER_Y - 340.0)])
		_lights.draw_colored_polygon(pts, Color(0.55, 0.5, 0.3, 0.45))


func _draw() -> void:
	if font == null or game == null:
		return
	if state == "title":
		_draw_title()
		return
	if shake > 0.0:
		draw_set_transform(Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.5, 0.0, Vector2.ONE)
	_road()
	_terrain()
	_items()
	_sheep()
	_rig()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not game.night.is_empty():
		draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.05, 0.14, 0.62))
	for f in fx:
		var a: float = clampf(1.0 - float(f.age) / float(f.life), 0.0, 1.0)
		_label(str(f.text), float(f.x), float(f.y), Color(1.0, 0.45, 0.4, a) if f.get("bad", false) else Color(1.0, 0.94, 0.68, a), 14)
	_hud()
	if state == "over":
		_draw_over()


func _hud() -> void:
	draw_rect(Rect2(0, 0, W, 34), Color(0.05, 0.12, 0.14, 0.8))
	draw_string(font, Vector2(10, 23), "£%d" % int(game.money), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.9, 0.4))
	draw_string(font, Vector2(0, 23), "%.1f mi" % (game.distance / 9000.0), HORIZONTAL_ALIGNMENT_CENTER, W, 14, Color(0.8, 0.95, 0.95))
	draw_string(font, Vector2(0, 23), "BEST £%d" % int(best), HORIZONTAL_ALIGNMENT_RIGHT, W - 8.0, 13, Color(0.7, 0.85, 0.85))
	if not game.job.is_empty():
		draw_rect(Rect2(0, 34, W, 22), Color(0.1, 0.3, 0.28, 0.8))
		draw_string(font, Vector2(10, 50), "%s  %d/10   £%d" % [game.job.label, int(game.job.count), int(game.job.pay)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 1.0, 0.9))
	elif not game.night.is_empty():
		draw_rect(Rect2(0, 34, W, 22), Color(0.1, 0.12, 0.35, 0.8))
		draw_string(font, Vector2(10, 50), "NIGHT SHIFT  coins x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.85, 1.0))
	if not game.sheep.is_empty() and not bool(game.sheep.cleared):
		var b: bool = bool(game.sheep.baa)
		_label("BAA!  BEEP NOW!" if b else "SHEEP AHEAD...", W / 2.0, 100.0, Color(1.0, 0.95, 0.5) if int(t * 8.0) % 2 == 0 else Color.WHITE, 22 if b else 16)
	if _hint_t > 0.0 and game.sheep.is_empty():
		_label(_hint, W / 2.0, 100.0, Color(1.0, 0.9, 0.6), 16)
	if game.boost > 0.0:
		draw_string(font, Vector2(0, H - 8), "TURBO", HORIZONTAL_ALIGNMENT_CENTER, W, 14, Color(1.0, 0.85, 0.4))


func _draw_title() -> void:
	var cover: Texture2D = tex.cover
	var scale: float = H / float(cover.get_height())
	var cw: float = float(cover.get_width()) * scale
	draw_texture_rect(cover, Rect2((W - cw) / 2.0, 0, cw, H), false)
	draw_rect(Rect2(0, H - 130, W, 130), Color(0.04, 0.12, 0.14, 0.55))
	_label("TRUCKIN' & DRIVIN'", W / 2.0, H - 92.0, Color(1.0, 0.92, 0.55), 26)
	if int(t * 2.0) % 2 == 0:
		_label("PRESS FIRE TO START", W / 2.0, H - 50.0, Color(0.7, 1.0, 0.92), 18)
	_label("WHEEL = LANE   FIRE = HORN", W / 2.0, H - 22.0, Color(1.0, 0.96, 0.8), 12)


func _draw_over() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.08, 0.1, 0.72))
	var cy := 190.0
	_label("SHIFT OVER", W / 2.0, cy, Color(1.0, 0.6, 0.45), 34)
	_label(game.end_reason, W / 2.0, cy + 40.0, Color(1.0, 0.95, 0.8), 15)
	_label("EARNED  £%d" % int(game.earned), W / 2.0, cy + 100.0, Color(1.0, 0.9, 0.4), 24)
	_label("%d deliveries   %.1f miles" % [game.jobs, game.distance / 9000.0], W / 2.0, cy + 135.0, Color(0.75, 0.95, 0.95), 14)
	_label("fines £%d   sheep saved %d" % [int(game.fines), game.horns], W / 2.0, cy + 160.0, Color(0.75, 0.95, 0.95), 14)
	if over_t > 1.5 and int(t * 2.0) % 2 == 0:
		_label("PRESS FIRE TO DRIVE AGAIN", W / 2.0, cy + 230.0, Color(0.7, 1.0, 0.92), 16)
