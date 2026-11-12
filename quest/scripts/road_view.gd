class_name RoadView
extends Control
## The driving games' screen and rules: a road drawn the classic arcade way (segments projected from a camera, with curves and hills), with
## traffic, scenery and a heads-up display. Two games share it:
##   "racer"   ROAD RUSH: race against the clock through checkpoints, overtaking traffic, as fast as you dare.
##   "trucker" BIG RIG: a heavy truck delivers cargo to three cities against the clock, watching fuel and cargo damage.
## Everything is drawn here, in a 360 x 548 portrait picture.

signal sound(name: String)
signal haptic(strength: float, seconds: float)

const W := 360.0
const H := 548.0
const SEG_LEN := 200.0
const ROAD_W := 2000.0                  # half the road's width in world units
const CAM_H := 1050.0
const DRAW := 70
const CAM_DEPTH := 0.84                 # a 100 degree view
const HUD_H := 44.0
const PLAYER_Z := CAM_H * CAM_DEPTH         # how far ahead of the camera the player's vehicle is
const HORIZON := 548.0 * 0.40

var mode := "racer"
var state := "title"                    # title, play, over
var font: Font
var tint := Color(1.0, 0.4, 0.6)
var title_text := "ROAD RUSH"
var t := 0.0
var rng := RandomNumberGenerator.new()

# the track
var n_segs := 0
var seg_curve := PackedFloat32Array()
var seg_y := PackedFloat32Array()        # height at the start of each segment (the end is the next one's)
var seg_scenery: Array = []              # per segment: [] or [[offset, kind]]
var track_len := 0.0

# the player
var pos_z := 0.0
var player_x := 0.0
var speed := 0.0
var max_speed := 12000.0
var accel := 2400.0
var brake_f := 12000.0
var decel := 2400.0
var off_decel := 6000.0
var steer_rate := 2.0
var centrifugal := 0.3
var crash_t := 0.0
var bounce := 0.0
var sky_off := 0.0
var hills_off := 0.0

# the game
var time_left := 60.0
var score := 0
var distance := 0.0
var overtakes := 0
var fuel := 100.0
var cargo := 100.0
var money := 0
var route := 0
var route_start := 0.0
var route_len := 0.0
var banner := ""
var banner_t := 0.0
var next_checkpoint := 0.0
var over_reason := ""
var best := 0
var demo := true

# traffic and pickups
var cars: Array = []                     # {z, x, speed, color, kind, passed}
var cans: Array = []                     # {z, x, taken}
var _in := {"axis": 0.0, "gas": false, "brake": false}

# per-frame projection results
var _px := PackedFloat32Array()
var _py := PackedFloat32Array()
var _ps := PackedFloat32Array()
var _clip := PackedFloat32Array()
var _base := 0
var _base_pct := 0.0


func _init() -> void:
	size = Vector2(540, 822)
	clip_contents = true
	_px.resize(DRAW + 1)
	_py.resize(DRAW + 1)
	_ps.resize(DRAW + 1)
	_clip.resize(DRAW + 1)


func setup(m: String, f: Font) -> void:
	mode = m
	font = f
	rng.seed = 7
	if mode == "racer":
		title_text = "ROAD RUSH"
		tint = Color(1.0, 0.4, 0.6)
		max_speed = 12000.0
		accel = max_speed / 5.0
		brake_f = max_speed
		decel = max_speed / 5.0
		off_decel = max_speed / 2.0
		steer_rate = 2.0
		centrifugal = 0.3
	else:
		title_text = "BIG RIG"
		tint = Color(1.0, 0.75, 0.25)
		max_speed = 7600.0
		accel = max_speed / 9.0
		brake_f = max_speed * 0.8
		decel = max_speed / 6.0
		off_decel = max_speed / 2.2
		steer_rate = 1.45
		centrifugal = 0.42
	_build_track()
	_load_best()
	reset_game(true)


func _load_best() -> void:
	var fa := FileAccess.open("user://road_scores.json", FileAccess.READ)
	if fa != null:
		var d = JSON.parse_string(fa.get_as_text())
		if d is Dictionary:
			best = int(d.get(mode, 0))


func _save_best() -> void:
	var all := {}
	var fa := FileAccess.open("user://road_scores.json", FileAccess.READ)
	if fa != null:
		var d = JSON.parse_string(fa.get_as_text())
		if d is Dictionary:
			all = d
	all[mode] = best
	var fw := FileAccess.open("user://road_scores.json", FileAccess.WRITE)
	if fw != null:
		fw.store_string(JSON.stringify(all))


# ---- the road ---------------------------------------------------------------------------------------------
func _ease_in(a: float, b: float, p: float) -> float:
	return a + (b - a) * p * p


func _ease_out(a: float, b: float, p: float) -> float:
	return a + (b - a) * (1.0 - (1.0 - p) * (1.0 - p))


func _ease_io(a: float, b: float, p: float) -> float:
	return a + (b - a) * (-cos(p * PI) / 2.0 + 0.5)


func _add_seg(curve: float, y: float) -> void:
	seg_curve.append(curve)
	seg_y.append(y)
	seg_scenery.append([])


func _last_y() -> float:
	return seg_y[seg_y.size() - 1] if seg_y.size() > 0 else 0.0


func _add_road(enter: int, hold: int, leave: int, curve: float, hill: float) -> void:
	var start_y := _last_y()
	var end_y := start_y + hill * SEG_LEN
	var total := enter + hold + leave
	for n in range(enter):
		_add_seg(_ease_in(0.0, curve, float(n) / float(enter)), _ease_io(start_y, end_y, float(n) / float(total)))
	for n in range(hold):
		_add_seg(curve, _ease_io(start_y, end_y, float(enter + n) / float(total)))
	for n in range(leave):
		_add_seg(_ease_io(curve, 0.0, float(n) / float(leave)), _ease_io(start_y, end_y, float(enter + hold + n) / float(total)))


func _build_track() -> void:
	seg_curve = PackedFloat32Array()
	seg_y = PackedFloat32Array()
	seg_scenery = []
	_add_seg(0.0, 0.0)
	if mode == "racer":
		_add_road(20, 20, 20, 0.0, 0.0)
		_add_road(25, 30, 25, 3.0, 0.0)
		_add_road(15, 25, 15, 0.0, 30.0)
		_add_road(20, 20, 20, -4.0, 0.0)
		_add_road(15, 20, 15, 0.0, -25.0)
		_add_road(25, 35, 25, 5.0, 20.0)
		_add_road(15, 15, 15, -5.0, -20.0)
		_add_road(30, 20, 30, 2.5, 0.0)
		_add_road(15, 30, 15, -3.0, 40.0)
		_add_road(25, 25, 25, 0.0, -40.0)
		_add_road(20, 40, 20, 4.0, 0.0)
		_add_road(25, 25, 25, -6.0, 0.0)
	else:
		_add_road(30, 40, 30, 0.0, 0.0)
		_add_road(40, 60, 40, 2.0, 0.0)
		_add_road(30, 40, 30, 0.0, 22.0)
		_add_road(40, 50, 40, -2.2, 0.0)
		_add_road(30, 50, 30, 0.0, -22.0)
		_add_road(45, 60, 45, 3.0, 12.0)
		_add_road(35, 40, 35, -3.0, -12.0)
		_add_road(40, 80, 40, 0.0, 0.0)
	# the road must come back to where it started so the loop is seamless
	var end_y := _last_y()
	if absf(end_y) > 1.0:
		var fix := 60
		for n in range(fix):
			_add_seg(0.0, _ease_io(end_y, 0.0, float(n + 1) / float(fix)))
	n_segs = seg_curve.size()
	track_len = float(n_segs) * SEG_LEN
	# roadside scenery
	var local := RandomNumberGenerator.new()
	local.seed = 21
	for i in range(n_segs):
		if i % 6 == 0:
			var side := -1.0 if local.randf() < 0.5 else 1.0
			var kind := "palm" if mode == "racer" else "pine"
			if i % 48 == 0:
				kind = "sign"
			seg_scenery[i].append([side * local.randf_range(1.25, 2.6), kind])
		if i % 30 == 15:
			seg_scenery[i].append([-1.4 if (i / 30) % 2 == 0 else 1.4, "post"])
	_populate_traffic()


func _populate_traffic() -> void:
	cars = []
	var local := RandomNumberGenerator.new()
	local.seed = 33
	var count := 26 if mode == "racer" else 20
	for i in range(count):
		var z := local.randf_range(3000.0, track_len - 1000.0)
		var lane: float = [-0.55, -0.15, 0.25, 0.6][local.randi_range(0, 3)]
		var spd := max_speed * (local.randf_range(0.2, 0.5) if mode == "racer" else local.randf_range(0.3, 0.55))
		var kinds := ["sedan", "van", "sedan"] if mode == "racer" else ["sedan", "van", "truck"]
		cars.append({"z": z, "x": lane, "speed": spd, "color": Color.from_hsv(local.randf(), 0.7, 0.9), "kind": kinds[local.randi_range(0, kinds.size() - 1)], "passed": true})
	cans = []
	if mode == "trucker":
		var z := 8000.0
		while z < track_len:
			cans.append({"z": z, "x": [-0.55, 0.0, 0.55][local.randi_range(0, 2)], "taken": false})
			z += 26000.0


# ---- starting and input -----------------------------------------------------------------------------------
func reset_game(attract := false) -> void:
	pos_z = 0.0
	player_x = 0.0
	speed = 0.0
	crash_t = 0.0
	score = 0
	distance = 0.0
	overtakes = 0
	fuel = 100.0
	cargo = 100.0
	money = 0
	route = 0
	banner = ""
	banner_t = 0.0
	over_reason = ""
	demo = attract
	state = "title" if attract else "play"
	for c in cars:
		c.passed = true
	for c in cans:
		c.taken = false
	if mode == "racer":
		time_left = 60.0
		next_checkpoint = 42000.0
	else:
		route = 0
		_start_route()


func _start_route() -> void:
	route_start = distance
	route_len = [42000.0, 70000.0, 105000.0][mini(route, 2)]
	time_left = route_len / 4200.0 + 22.0
	banner = "DELIVERY %d OF 3" % (route + 1)
	banner_t = 2.5


func set_input(axis: float, gas: bool, brake: bool, fire_edge: bool) -> void:
	_in = {"axis": axis, "gas": gas, "brake": brake}
	if fire_edge:
		if state == "title":
			reset_game(false)
		elif state == "over" and t > 1.0:
			reset_game(false)


# ---- the simulation ---------------------------------------------------------------------------------------
func _seg_index(z: float) -> int:
	return int(floorf(fposmod(z, track_len) / SEG_LEN)) % n_segs


func tick(dt: float) -> void:
	t += dt
	dt = minf(dt, 0.05)
	banner_t = maxf(0.0, banner_t - dt)
	crash_t = maxf(0.0, crash_t - dt)
	var axis: float = float(_in.axis)
	var gas: bool = bool(_in.gas)
	var brake: bool = bool(_in.brake)
	var player_seg := _seg_index(pos_z + PLAYER_Z)
	var curve: float = seg_curve[player_seg]
	if state == "title" or demo:
		# the attract mode drives itself: keeps to the road and eases off in the bends
		axis = clampf(-player_x * 1.2 + curve * 0.12, -1.0, 1.0)
		gas = true
		brake = false
		if speed > max_speed * (0.55 if absf(curve) > 2.0 else 0.8):
			gas = false
	if state == "over":
		gas = false
		brake = true
	var speed_pct := speed / max_speed
	var dx := dt * steer_rate * speed_pct
	# the world moves
	pos_z += speed * dt
	if state == "play":
		distance += speed * dt
	player_x += axis * dx * (1.0 if speed > 100.0 else 0.0)
	player_x -= dx * speed_pct * curve * centrifugal
	if gas and not (state == "play" and mode == "trucker" and fuel <= 0.0):
		speed += accel * dt * (1.0 - 0.35 * crash_t)
	elif brake:
		speed -= brake_f * dt
	else:
		speed -= decel * dt
	if absf(player_x) > 1.0 and speed > max_speed / 4.0:
		speed -= off_decel * dt
		bounce = sin(t * 50.0) * 2.0
		if state == "play" and int(t * 6.0) != int((t - dt) * 6.0):
			haptic.emit(0.25, 0.04)
	else:
		bounce = sin(t * 14.0 * speed_pct) * speed_pct * 1.2
	player_x = clampf(player_x, -2.2, 2.2)
	speed = clampf(speed, 0.0, max_speed)
	sky_off = fposmod(sky_off + curve * speed_pct * dt * 0.06, 1.0)
	hills_off = fposmod(hills_off + curve * speed_pct * dt * 0.12, 1.0)
	# traffic
	var pz := pos_z + PLAYER_Z
	for c in cars:
		c.z = fposmod(c.z + c.speed * dt, track_len)
		var rel := _rel(c.z, pz)
		# cars keep their lane; a faster one catching a slower one eases off
		if state != "over":
			if absf(rel) < 220.0 and absf(player_x - c.x) < (0.33 if c.kind != "truck" else 0.42) and speed > c.speed * 0.9 and crash_t <= 0.0:
				speed = c.speed * 0.4
				crash_t = 1.2
				player_x += (-0.15 if player_x < c.x else 0.15)
				sound.emit("hit")
				haptic.emit(1.0, 0.25)
				if state == "play":
					if mode == "trucker":
						cargo = maxf(0.0, cargo - 14.0)
					else:
						time_left = maxf(0.0, time_left - 2.0)
		# overtaking: a car that was ahead of you is now behind you
		var is_ahead := rel > 0.0
		if bool(c.passed) and not is_ahead and absf(rel) < 2000.0 and state == "play" and speed > c.speed:
			overtakes += 1
			sound.emit("click")
		c.passed = is_ahead                          # (passed: it was ahead of the player at the last look)
	# pickups (fuel cans) and the rules
	if state == "play":
		for c in cans:
			if not c.taken and absf(_rel(c.z, pz)) < 260.0 and absf(player_x - c.x) < 0.3:
				c.taken = true
				fuel = minf(100.0, fuel + 30.0)
				banner = "FUEL +30"
				banner_t = 1.5
				sound.emit("pickup")
		time_left -= dt
		if mode == "racer":
			score = int(distance / 100.0) + overtakes * 100
			if distance >= next_checkpoint:
				time_left += 24.0
				next_checkpoint += 42000.0
				banner = "CHECKPOINT +24s"
				banner_t = 2.0
				sound.emit("chime")
			if time_left <= 0.0:
				_game_over("TIME UP")
		else:
			fuel = maxf(0.0, fuel - dt * (0.15 + 0.9 * speed_pct))
			if distance - route_start >= route_len:
				var pay := 400 + int(cargo * 8.0) + int(maxf(0.0, time_left) * 15.0)
				money += pay
				score = money
				banner = "DELIVERED!  $%d" % pay
				banner_t = 3.0
				sound.emit("clear")
				route += 1
				if route >= 3:
					_game_over("ALL DELIVERED")
				else:
					_start_route()
					banner = "DELIVERED!  $%d" % pay
			elif time_left <= 0.0:
				_game_over("TOO LATE")
			elif fuel <= 0.0 and speed < 200.0:
				_game_over("OUT OF FUEL")
			elif cargo <= 0.0:
				_game_over("CARGO DESTROYED")
	queue_redraw()


func _rel(z: float, from_z: float) -> float:
	var d := fposmod(z - from_z + track_len / 2.0, track_len) - track_len / 2.0
	return d


func _game_over(why: String) -> void:
	state = "over"
	over_reason = why
	t = 0.0
	if mode == "trucker":
		score = money + int(cargo)
	if score > best:
		best = score
		_save_best()


# ---- drawing ---------------------------------------------------------------------------------------------------
func _draw() -> void:
	if font == null or n_segs == 0:
		return
	var sc := minf(size.x / W, size.y / H)
	draw_set_transform(Vector2((size.x - W * sc) / 2.0, (size.y - H * sc) / 2.0), 0.0, Vector2(sc, sc))
	_draw_world()
	_draw_hud()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _palette() -> Dictionary:
	if mode == "racer":
		return {"sky_top": Color(0.16, 0.05, 0.38), "sky_bot": Color(1.0, 0.5, 0.3), "far": Color(0.2, 0.08, 0.35), "grass_a": Color(0.1, 0.5, 0.3), "grass_b": Color(0.08, 0.42, 0.26),
			"road_a": Color(0.36, 0.34, 0.45), "road_b": Color(0.32, 0.3, 0.41), "rumble_a": Color(0.9, 0.15, 0.3), "rumble_b": Color(0.95, 0.95, 0.95), "lane": Color(1.0, 0.95, 0.5), "fog": Color(1.0, 0.55, 0.4)}
	return {"sky_top": Color(0.02, 0.04, 0.22), "sky_bot": Color(0.25, 0.35, 0.62), "far": Color(0.07, 0.12, 0.24), "grass_a": Color(0.08, 0.2, 0.12), "grass_b": Color(0.07, 0.17, 0.1),
		"road_a": Color(0.2, 0.21, 0.24), "road_b": Color(0.17, 0.18, 0.21), "rumble_a": Color(0.9, 0.75, 0.15), "rumble_b": Color(0.9, 0.9, 0.9), "lane": Color(0.92, 0.92, 0.88), "fog": Color(0.2, 0.3, 0.55)}


func _draw_world() -> void:
	var pal := _palette()
	# the sky and distant hills
	var sky_h := HORIZON + 4.0
	for i in range(8):
		var k := float(i) / 7.0
		draw_rect(Rect2(0, float(i) * sky_h / 8.0, W, sky_h / 8.0 + 1.0), (pal.sky_top as Color).lerp(pal.sky_bot as Color, k))
	if mode == "racer":
		draw_circle(Vector2(W * 0.5 - sky_off * 120.0 + 60.0, HORIZON - 40.0), 46.0, Color(1.0, 0.85, 0.45))
	else:
		for k in range(40):
			var sx := fposmod(float(k) * 97.0 - sky_off * 300.0, W)
			draw_circle(Vector2(sx, 20.0 + fposmod(float(k) * 53.0, 190.0)), 1.1, Color(1, 1, 1, 0.8))
	var hill_pts := PackedVector2Array()
	hill_pts.append(Vector2(0, HORIZON + 4.0))
	for i in range(0, 25):
		var hx := float(i) / 24.0 * W
		var u := float(i) / 24.0 + hills_off
		hill_pts.append(Vector2(hx, HORIZON - 14.0 - 12.0 * sin(u * TAU * 2.0) - 7.0 * sin(u * TAU * 5.0 + 1.0)))
	hill_pts.append(Vector2(W, HORIZON + 4.0))
	draw_colored_polygon(hill_pts, pal.far)
	# the road, near to far (a segment is projected from a camera CAM_H above the road, looking down it)
	var base := _seg_index(pos_z)
	_base = base
	var base_pct := fposmod(pos_z, SEG_LEN) / SEG_LEN
	_base_pct = base_pct
	var p_seg := _seg_index(pos_z + PLAYER_Z)
	var p_pct := fposmod(pos_z + PLAYER_Z, SEG_LEN) / SEG_LEN
	var player_y := lerpf(seg_y[p_seg], seg_y[(p_seg + 1) % n_segs], p_pct)
	var cam_y := player_y + CAM_H
	var x := 0.0
	var dx := -(seg_curve[base] * base_pct)
	var maxy := H
	var cy := HORIZON
	var fog_col: Color = pal.fog
	draw_rect(Rect2(0.0, cy - 2.0, W, H - cy + 2.0), (pal.grass_a as Color).lerp(fog_col, 0.9))
	for n in range(DRAW):
		var si := (base + n) % n_segs
		var z0 := float(n) * SEG_LEN - base_pct * SEG_LEN            # how far ahead of the camera this segment starts
		var z1 := z0 + SEG_LEN
		var cam_x1 := x - player_x * ROAD_W
		var cam_x2 := x + dx - player_x * ROAD_W
		var visible := z0 > CAM_DEPTH
		var s1 := CAM_DEPTH / maxf(z0, 0.01)
		var s2 := CAM_DEPTH / z1
		var sx1 := W / 2.0 + s1 * cam_x1 * W / 2.0
		var sx2 := W / 2.0 + s2 * cam_x2 * W / 2.0
		var sy1 := cy - s1 * (seg_y[si] - cam_y) * H / 2.0
		var sy2 := cy - s2 * (seg_y[(si + 1) % n_segs] - cam_y) * H / 2.0
		var sw1 := s1 * ROAD_W * W / 2.0
		var sw2 := s2 * ROAD_W * W / 2.0
		_px[n] = sx1
		_py[n] = sy1
		_ps[n] = s1
		_clip[n] = maxy
		x += dx
		dx += seg_curve[si]
		if not visible or sy2 >= sy1 or sy2 >= maxy:
			continue
		var fog := clampf(pow(float(n) / float(DRAW), 2.2), 0.0, 1.0)
		var band := (int(floorf(float(base + n) / 3.0)) % 2) == 0
		var grass: Color = (pal.grass_a if band else pal.grass_b).lerp(fog_col, fog)
		draw_rect(Rect2(0.0, sy2, W, sy1 - sy2 + 1.0), grass)
		var rumble: Color = (pal.rumble_a if band else pal.rumble_b).lerp(fog_col, fog)
		var road: Color = (pal.road_a if band else pal.road_b).lerp(fog_col, fog)
		var rw1 := sw1 * 0.12
		var rw2 := sw2 * 0.12
		draw_colored_polygon(PackedVector2Array([Vector2(sx1 - sw1 - rw1, sy1), Vector2(sx1 - sw1, sy1), Vector2(sx2 - sw2, sy2), Vector2(sx2 - sw2 - rw2, sy2)]), rumble)
		draw_colored_polygon(PackedVector2Array([Vector2(sx1 + sw1, sy1), Vector2(sx1 + sw1 + rw1, sy1), Vector2(sx2 + sw2 + rw2, sy2), Vector2(sx2 + sw2, sy2)]), rumble)
		draw_colored_polygon(PackedVector2Array([Vector2(sx1 - sw1, sy1), Vector2(sx1 + sw1, sy1), Vector2(sx2 + sw2, sy2), Vector2(sx2 - sw2, sy2)]), road)
		if band:
			var lw1 := sw1 * 0.03
			var lw2 := sw2 * 0.03
			var lc: Color = (pal.lane as Color).lerp(fog_col, fog)
			draw_colored_polygon(PackedVector2Array([Vector2(sx1 - lw1, sy1), Vector2(sx1 + lw1, sy1), Vector2(sx2 + lw2, sy2), Vector2(sx2 - lw2, sy2)]), lc)
		maxy = sy2
	_draw_sprites()
	_draw_player()


## Roadside things, traffic and pickups, far to near, each hidden if a hill is in front of it.
func _draw_sprites() -> void:
	var list: Array = []
	for n in range(DRAW - 1, 0, -1):
		var si := (_base + n) % n_segs
		for sc in seg_scenery[si]:
			list.append([n, "scenery", sc[0], sc[1], 0])
	for c in cars:
		var rel_c := _rel(c.z, pos_z)
		var n := int(floorf((rel_c + _base_pct * SEG_LEN) / SEG_LEN))
		if n > 0 and n < DRAW - 1 and rel_c > 0.0:
			list.append([n, "car", c.x, c.kind, c.color])
	for c in cans:
		if not c.taken:
			var rel_k := _rel(c.z, pos_z)
			var n := int(floorf((rel_k + _base_pct * SEG_LEN) / SEG_LEN))
			if n > 0 and n < DRAW - 1 and rel_k > 0.0:
				list.append([n, "can", c.x, "can", Color(0.3, 0.9, 0.4)])
	list.sort_custom(func(a, b): return a[0] > b[0])
	for e in list:
		var n: int = e[0]
		var s: float = _ps[n]
		var px: float = _px[n] + s * float(e[2]) * ROAD_W * W / 2.0
		var py: float = _py[n]
		if py > _clip[n] + 2.0:
			continue
		var unit := s * ROAD_W * W / 2.0         # pixels for half the road's width at this distance
		var fog := clampf(pow(float(n) / float(DRAW), 2.2), 0.0, 0.85)
		match str(e[1]):
			"scenery":
				_scenery(str(e[3]), Vector2(px, py), unit, fog)
			"car":
				_car(Vector2(px, py), unit * (0.36 if str(e[3]) != "truck" else 0.5), e[4] as Color, str(e[3]), fog)
			"can":
				var u := unit * 0.12
				draw_rect(Rect2(px - u, py - u * 1.7, u * 2.0, u * 1.7), (e[4] as Color).lerp(Color(0.1, 0.2, 0.3), fog))
				draw_rect(Rect2(px - u * 0.5, py - u * 2.1, u, u * 0.5), Color(0.9, 0.9, 0.9))


func _scenery(kind: String, p: Vector2, unit: float, fog: float) -> void:
	var g := Color(0.1, 0.6, 0.3) if mode == "racer" else Color(0.05, 0.3, 0.18)
	g = g.lerp(Color(0.2, 0.3, 0.5), fog)
	var trunk := Color(0.35, 0.22, 0.12).lerp(Color(0.2, 0.3, 0.5), fog)
	match kind:
		"palm":
			var h := unit * 0.9
			draw_rect(Rect2(p.x - unit * 0.025, p.y - h, unit * 0.05, h), trunk)
			for k in range(5):
				var a := -PI * 0.5 + (float(k) - 2.0) * 0.55
				draw_line(Vector2(p.x, p.y - h), Vector2(p.x, p.y - h) + Vector2.from_angle(a) * unit * 0.3, g, maxf(1.0, unit * 0.04))
		"pine":
			var h2 := unit * 0.95
			draw_rect(Rect2(p.x - unit * 0.02, p.y - h2 * 0.2, unit * 0.04, h2 * 0.2), trunk)
			for k in range(3):
				var w := unit * (0.22 - float(k) * 0.05)
				var yb := p.y - h2 * (0.15 + float(k) * 0.28)
				draw_colored_polygon(PackedVector2Array([Vector2(p.x - w, yb), Vector2(p.x + w, yb), Vector2(p.x, yb - h2 * 0.36)]), g)
		"sign":
			var h3 := unit * 0.6
			draw_rect(Rect2(p.x - unit * 0.015, p.y - h3, unit * 0.03, h3), Color(0.5, 0.5, 0.55).lerp(Color(0.2, 0.3, 0.5), fog))
			draw_rect(Rect2(p.x - unit * 0.2, p.y - h3 - unit * 0.2, unit * 0.4, unit * 0.2), Color(0.1, 0.4, 0.8).lerp(Color(0.2, 0.3, 0.5), fog))
		"post":
			draw_rect(Rect2(p.x - unit * 0.01, p.y - unit * 0.3, unit * 0.02, unit * 0.3), Color(0.9, 0.9, 0.9).lerp(Color(0.2, 0.3, 0.5), fog))
			draw_rect(Rect2(p.x - unit * 0.015, p.y - unit * 0.22, unit * 0.03, unit * 0.04), Color(0.9, 0.2, 0.2).lerp(Color(0.2, 0.3, 0.5), fog))


func _car(p: Vector2, w: float, col: Color, kind: String, fog: float) -> void:
	var f := func(c: Color) -> Color: return c.lerp(Color(0.2, 0.3, 0.5), fog)
	var h := w * (0.5 if kind == "sedan" else (0.8 if kind == "van" else 1.0))
	draw_rect(Rect2(p.x - w / 2.0, p.y - h, w, h * 0.78), f.call(col))
	if kind == "sedan":
		draw_rect(Rect2(p.x - w * 0.32, p.y - h * 1.0 - w * 0.12, w * 0.64, w * 0.18), f.call(col.darkened(0.2)))
		draw_rect(Rect2(p.x - w * 0.28, p.y - h * 0.98 - w * 0.1, w * 0.56, w * 0.13), f.call(Color(0.15, 0.2, 0.3)))
	elif kind == "truck":
		draw_rect(Rect2(p.x - w / 2.0, p.y - h * 1.2, w, h * 1.2), f.call(Color(0.85, 0.85, 0.88)))
	draw_rect(Rect2(p.x - w * 0.46, p.y - h * 0.55, w * 0.18, h * 0.14), f.call(Color(1.0, 0.2, 0.15)))
	draw_rect(Rect2(p.x + w * 0.28, p.y - h * 0.55, w * 0.18, h * 0.14), f.call(Color(1.0, 0.2, 0.15)))
	draw_rect(Rect2(p.x - w * 0.5, p.y - h * 0.18, w * 0.16, h * 0.18), f.call(Color(0.05, 0.05, 0.06)))
	draw_rect(Rect2(p.x + w * 0.34, p.y - h * 0.18, w * 0.16, h * 0.18), f.call(Color(0.05, 0.05, 0.06)))


func _draw_player() -> void:
	var steer: float = float(_in.axis)
	var cx := W / 2.0 + steer * 6.0
	var by := H - 70.0 + bounce
	var shake := (sin(t * 70.0) * 4.0) if crash_t > 0.0 else 0.0
	cx += shake
	if mode == "racer":
		var body := Color(0.9, 0.1, 0.25)
		draw_rect(Rect2(cx - 60, by - 20, 120, 44), body)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 44, by - 20), Vector2(cx - 30, by - 44), Vector2(cx + 30, by - 44), Vector2(cx + 44, by - 20)]), body.darkened(0.15))
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 36, by - 22), Vector2(cx - 26, by - 40), Vector2(cx + 26, by - 40), Vector2(cx + 36, by - 22)]), Color(0.12, 0.17, 0.3))
		draw_rect(Rect2(cx - 66, by + 8, 28, 20), Color(0.05, 0.05, 0.06))
		draw_rect(Rect2(cx + 38, by + 8, 28, 20), Color(0.05, 0.05, 0.06))
		draw_rect(Rect2(cx - 54, by - 10, 30, 10), Color(1.0, 0.25, 0.2))
		draw_rect(Rect2(cx + 24, by - 10, 30, 10), Color(1.0, 0.25, 0.2))
		draw_rect(Rect2(cx - 52, by - 52, 104, 7), body.darkened(0.35))
	else:
		var tr := Color(0.85, 0.88, 0.95)
		draw_rect(Rect2(cx - 62, by - 100, 124, 112), tr)
		draw_rect(Rect2(cx - 62, by - 100, 124, 10), Color(0.7, 0.72, 0.8))
		draw_rect(Rect2(cx - 4, by - 100, 8, 112), Color(0.6, 0.62, 0.7))
		draw_rect(Rect2(cx - 66, by + 12, 132, 22), Color(0.12, 0.12, 0.14))
		draw_rect(Rect2(cx - 58, by - 4, 22, 12), Color(1.0, 0.25, 0.2))
		draw_rect(Rect2(cx + 36, by - 4, 22, 12), Color(1.0, 0.25, 0.2))
		draw_rect(Rect2(cx - 70, by + 12, 22, 26), Color(0.05, 0.05, 0.06))
		draw_rect(Rect2(cx + 48, by + 12, 22, 26), Color(0.05, 0.05, 0.06))
	if speed > max_speed * 0.5 and state == "play":
		for k in range(4):
			var sx := cx + (float(k) - 1.5) * 34.0
			draw_circle(Vector2(sx, by + 36.0 + fposmod(t * 300.0 + float(k) * 11.0, 22.0)), 1.6, Color(0.9, 0.9, 0.9, 0.25))


func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, W, HUD_H), Color(0, 0, 0, 0.6))
	var kmh := int(speed / max_speed * (300.0 if mode == "racer" else 110.0))
	draw_string(font, Vector2(8, 28), "%d" % kmh, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, tint)
	draw_string(font, Vector2(8 + 66, 28), "KM/H", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.85))
	var tcol := Color(1, 1, 1) if time_left > 10.0 else Color(1.0, 0.3, 0.3)
	draw_string(font, Vector2(0, 20), "TIME", HORIZONTAL_ALIGNMENT_CENTER, W, 12, Color(0.8, 0.8, 0.85))
	draw_string(font, Vector2(0, 40), "%d" % maxi(0, ceili(time_left)), HORIZONTAL_ALIGNMENT_CENTER, W, 22, tcol)
	if mode == "racer":
		draw_string(font, Vector2(0, 20), "SCORE", HORIZONTAL_ALIGNMENT_RIGHT, W - 8, 12, Color(0.8, 0.8, 0.85))
		draw_string(font, Vector2(0, 40), "%d" % score, HORIZONTAL_ALIGNMENT_RIGHT, W - 8, 22, tint)
	else:
		draw_string(font, Vector2(0, 20), "EARNED", HORIZONTAL_ALIGNMENT_RIGHT, W - 8, 12, Color(0.8, 0.8, 0.85))
		draw_string(font, Vector2(0, 40), "$%d" % money, HORIZONTAL_ALIGNMENT_RIGHT, W - 8, 22, tint)
		# fuel and cargo bars along the bottom, and how far to go
		draw_rect(Rect2(10, H - 24, 100, 10), Color(0.15, 0.15, 0.18))
		draw_rect(Rect2(10, H - 24, fuel, 10), Color(0.95, 0.75, 0.2) if fuel > 20.0 else Color(1.0, 0.25, 0.2))
		draw_string(font, Vector2(10, H - 28), "FUEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.9))
		draw_rect(Rect2(125, H - 24, 100, 10), Color(0.15, 0.15, 0.18))
		draw_rect(Rect2(125, H - 24, cargo, 10), Color(0.4, 0.85, 0.5) if cargo > 30.0 else Color(1.0, 0.25, 0.2))
		draw_string(font, Vector2(125, H - 28), "CARGO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.9))
		var togo := maxf(0.0, route_len - (distance - route_start)) / 1000.0
		draw_string(font, Vector2(0, H - 14), "%.1f KM TO GO" % (togo * 0.5), HORIZONTAL_ALIGNMENT_RIGHT, W - 10, 14, Color(0.85, 0.9, 1.0))
	if banner_t > 0.0 and state == "play":
		draw_string(font, Vector2(0, 120), banner, HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color(1, 1, 0.6, clampf(banner_t, 0.0, 1.0)))
	if state == "title":
		draw_rect(Rect2(20, 90, W - 40, 170), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(20, 90, W - 40, 170), tint, false, 2.0)
		draw_string(font, Vector2(0, 140), title_text, HORIZONTAL_ALIGNMENT_CENTER, W, 38, tint)
		var how := "STEER: WHEEL   GAS: RED BUTTON\nBRAKE: BLUE BUTTON" if mode == "racer" else "STEER: WHEEL   GAS: RED BUTTON\nBRAKE: BLUE   GRAB FUEL CANS"
		var y := 172.0
		for line in how.split("\n"):
			draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_CENTER, W, 14, Color(0.9, 0.95, 0.9))
			y += 20.0
		draw_string(font, Vector2(0, 238), "PRESS GAS TO START", HORIZONTAL_ALIGNMENT_CENTER, W, 17, Color(1, 0.9, 0.4, 0.6 + 0.4 * sin(t * 5.0)))
		draw_string(font, Vector2(0, 256), "BEST %d" % best, HORIZONTAL_ALIGNMENT_CENTER, W, 13, Color(0.7, 0.8, 0.75))
	elif state == "over":
		draw_rect(Rect2(20, 110, W - 40, 190), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(20, 110, W - 40, 190), tint, false, 2.0)
		draw_string(font, Vector2(0, 156), over_reason, HORIZONTAL_ALIGNMENT_CENTER, W, 28, tint)
		draw_string(font, Vector2(0, 200), "SCORE %d" % score, HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color.WHITE)
		draw_string(font, Vector2(0, 232), "BEST %d" % best, HORIZONTAL_ALIGNMENT_CENTER, W, 16, Color(0.75, 0.8, 0.8))
		if t > 1.0:
			draw_string(font, Vector2(0, 275), "PRESS GAS TO PLAY AGAIN", HORIZONTAL_ALIGNMENT_CENTER, W, 15, Color(1, 0.9, 0.4, 0.6 + 0.4 * sin(t * 5.0)))
