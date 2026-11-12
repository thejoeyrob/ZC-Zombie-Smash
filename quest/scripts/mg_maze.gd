class_name MGMaze
extends MiniGame
## MAZE MUNCH: guide the hungry little robot round the maze eating every pellet while four gremlins hunt you. Grab a power bolt and they turn scared
## and can be eaten. A new maze every level. (Our own robot, gremlins and mazes: only the old idea of a maze chase is borrowed.)

const CW := 18.0                       # cell size
const COLS := 19
const ROWS := 24
const OX := 9.0
const OY := 52.0
var walls: Array = []                   # [row][col] -> bit mask of open sides: 1 up, 2 right, 4 down, 8 left
var pellets: Array = []                 # [row][col] 0 none, 1 pellet, 2 bolt
var left := 0
var me := {"p": Vector2.ZERO, "d": Vector2i(0, 0), "want": Vector2i(0, 0), "mouth": 0.0}
var gremlins: Array = []                # {p, d, color, home: Vector2i, eaten, wait}
var scared_t := 0.0
var level := 1
var dead_t := 0.0
var start_cell := Vector2i(9, 18)
var _speed := 70.0


func _init() -> void:
	title = "MAZE MUNCH"
	blurb = "STICK STEERS THE ROBOT\nEAT ALL THE PELLETS"
	tint = Color(0.5, 0.85, 1.0)
	rng.randomize()
	_new_level()


func _cell_pos(c: Vector2i) -> Vector2:
	return Vector2(OX + (float(c.x) + 0.5) * CW, OY + (float(c.y) + 0.5) * CW)


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floorf((p.x - OX) / CW)), int(floorf((p.y - OY) / CW)))


func _new_level() -> void:
	_make_maze()
	scared_t = 0.0
	dead_t = 0.0
	_reset_positions()


func _make_maze() -> void:
	# a random maze on every second cell (a depth-first walk), then some walls knocked out so there are loops to run round, and mirrored left to right
	var hw := (COLS + 1) / 2
	walls = []
	for r in range(ROWS):
		var row: Array = []
		for c in range(COLS):
			row.append(0)
		walls.append(row)
	var seen := {}
	var stack: Array = [Vector2i(0, 0)]
	seen[Vector2i(0, 0)] = true
	var half: Array = []
	for r in range(ROWS):
		var row2: Array = []
		for c in range(hw):
			row2.append(0)
		half.append(row2)
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var bits := [1, 2, 4, 8]
	var gw := (hw + 1) / 2
	var gh := (ROWS + 1) / 2
	var links := {}
	while not stack.is_empty():
		var cur: Vector2i = stack[stack.size() - 1]
		var opts: Array = []
		for k in range(4):
			var n: Vector2i = cur + dirs[k]
			if n.x >= 0 and n.x < gw and n.y >= 0 and n.y < gh and not seen.has(n):
				opts.append(k)
		if opts.is_empty():
			stack.pop_back()
			continue
		var k2: int = opts[rng.randi_range(0, opts.size() - 1)]
		var nxt: Vector2i = cur + dirs[k2]
		seen[nxt] = true
		links["%d,%d,%d,%d" % [cur.x, cur.y, nxt.x, nxt.y]] = [cur, nxt]
		stack.append(nxt)
	# open the half-board cells: maze nodes sit on even cell coordinates, links open the cell between them
	for node in seen.keys():
		var cx: int = node.x * 2
		var cy: int = node.y * 2
		if cx < hw and cy < ROWS:
			half[cy][cx] = 1
	for key in links.keys():
		var a: Vector2i = links[key][0]
		var b: Vector2i = links[key][1]
		var mx: int = a.x + b.x
		var my: int = a.y + b.y
		if mx < hw and my < ROWS:
			half[my][mx] = 1
	# extra openings for loops
	for _i in range(18):
		var rx := rng.randi_range(1, hw - 2)
		var ry := rng.randi_range(1, ROWS - 2)
		half[ry][rx] = 1
	# the middle column and the bottom row are corridors so the two halves join
	for r in range(ROWS):
		half[r][hw - 1] = 1 if (r % 2 == 0 or rng.randf() < 0.5) else half[r][hw - 1]
	# mirror
	var open: Array = []
	for r in range(ROWS):
		var row3: Array = []
		for c in range(COLS):
			var mc := c if c < hw else (COLS - 1 - c)
			row3.append(half[r][mc])
		open.append(row3)
	# make sure no cell is a dead pocket of one: every open cell needs two open neighbours
	for _pass in range(3):
		for r in range(ROWS):
			for c in range(COLS):
				if open[r][c] == 1:
					var nb: Array = []
					for k in range(4):
						var rr: int = r + dirs[k].y
						var cc: int = c + dirs[k].x
						if rr >= 0 and rr < ROWS and cc >= 0 and cc < COLS and open[rr][cc] == 1:
							nb.append(k)
					if nb.size() < 2:
						for k in range(4):
							var rr2: int = r + dirs[k].y
							var cc2: int = c + dirs[k].x
							if rr2 >= 0 and rr2 < ROWS and cc2 >= 0 and cc2 < COLS and open[rr2][cc2] == 0 and (nb.size() < 2) and rr2 > 0 and rr2 < ROWS - 1 and cc2 > 0 and cc2 < COLS - 1:
								open[rr2][cc2] = 1
								nb.append(k)
	# the walls bitmask from the open cells
	walls = []
	for r in range(ROWS):
		var row4: Array = []
		for c in range(COLS):
			var m := 0
			if open[r][c] == 1:
				for k in range(4):
					var rr3: int = r + dirs[k].y
					var cc3: int = c + dirs[k].x
					if rr3 >= 0 and rr3 < ROWS and cc3 >= 0 and cc3 < COLS and open[rr3][cc3] == 1:
						m |= bits[k]
				if m == 0:
					m = 0
			row4.append(m if open[r][c] == 1 else -1)        # -1: solid
		walls.append(row4)
	# pellets everywhere there is corridor, power bolts in the corners
	pellets = []
	left = 0
	for r in range(ROWS):
		var pr: Array = []
		for c in range(COLS):
			var v := 1 if int(walls[r][c]) >= 0 else 0
			pr.append(v)
			left += v
		pellets.append(pr)
	# the start cell and the gremlin pen are the nearest open cells to where they should be
	start_cell = _nearest_open(Vector2i(COLS / 2, ROWS - 4))
	for corner in [Vector2i(1, 1), Vector2i(COLS - 2, 1), Vector2i(1, ROWS - 2), Vector2i(COLS - 2, ROWS - 2)]:
		var cc4 := _nearest_open(corner)
		if pellets[cc4.y][cc4.x] == 1:
			pellets[cc4.y][cc4.x] = 2
	pellets[start_cell.y][start_cell.x] = 0
	_wall_off_unreachable()
	left = 0
	for r in range(ROWS):
		for c in range(COLS):
			left += 1 if pellets[r][c] > 0 else 0


func _wall_off_unreachable() -> void:
	var seen := {start_cell: true}
	var todo: Array = [start_cell]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var n: Vector2i = c + d
			if _open_dir(c, d) and not seen.has(n):
				seen[n] = true
				todo.append(n)
	for r in range(ROWS):
		for c in range(COLS):
			if int(walls[r][c]) >= 0 and not seen.has(Vector2i(c, r)):
				walls[r][c] = -1
				pellets[r][c] = 0


func _nearest_open(c: Vector2i) -> Vector2i:
	var best := c
	var best_d := 9999
	for r in range(ROWS):
		for cc in range(COLS):
			if int(walls[r][cc]) >= 0:
				var d := absi(r - c.y) + absi(cc - c.x)
				if d < best_d:
					best_d = d
					best = Vector2i(cc, r)
	return best


func _reset_positions() -> void:
	me.p = _cell_pos(start_cell)
	me.d = Vector2i(0, 0)
	me.want = Vector2i(0, 0)
	gremlins = []
	var cols := [Color(1.0, 0.3, 0.35), Color(1.0, 0.65, 0.3), Color(0.9, 0.4, 1.0), Color(0.4, 1.0, 0.7)]
	var corners := [Vector2i(1, 1), Vector2i(COLS - 2, 1), Vector2i(1, ROWS / 2), Vector2i(COLS - 2, ROWS / 2)]
	for i in range(4):
		var home := _nearest_open(corners[i])
		gremlins.append({"p": _cell_pos(home), "d": Vector2i(1, 0), "color": cols[i], "home": home, "eaten": false, "wait": 1.2 * float(i)})


func _open_dir(c: Vector2i, d: Vector2i) -> bool:
	if c.x < 0 or c.x >= COLS or c.y < 0 or c.y >= ROWS:
		return false
	var m: int = walls[c.y][c.x]
	if m < 0:
		return false
	if d == Vector2i(0, -1):
		return m & 1 != 0
	if d == Vector2i(1, 0):
		return m & 2 != 0
	if d == Vector2i(0, 1):
		return m & 4 != 0
	return m & 8 != 0


func _step_actor(p: Vector2, d: Vector2i, dt: float, want: Vector2i, speed: float) -> Array:
	var c := _cell_of(p)
	var centre := _cell_pos(c)
	var dist := speed * dt
	var dir := d
	# at (or just past) a cell's centre the actor may turn; between centres it can only reverse
	var to_centre := centre - p
	var at_centre := to_centre.length() < dist + 0.01
	if want != Vector2i.ZERO and want != dir:
		if dir == Vector2i.ZERO or at_centre or want == -dir:
			if want == -dir or _open_dir(c, want):
				if want != -dir:
					p = centre
				dir = want
	elif dir == Vector2i.ZERO and want != Vector2i.ZERO:
		dir = want
	if dir == Vector2i.ZERO:
		return [p, dir]
	if at_centre and not _open_dir(c, dir):
		return [centre, Vector2i.ZERO]
	var move := Vector2(dir) * dist
	# stay on the corridor's centre line
	if dir.x != 0:
		p.y = move_toward(p.y, centre.y, dist)
	else:
		p.x = move_toward(p.x, centre.x, dist)
	p += move
	return [p, dir]


func update(dt: float, st: Vector2, _btn: Dictionary, _edge: Dictionary) -> void:
	t += dt
	if over:
		return
	if dead_t > 0.0:
		dead_t -= dt
		if dead_t <= 0.0:
			_reset_positions()
		return
	if st.length() > 0.45:
		me.want = Vector2i(1 if st.x > 0 else -1, 0) if absf(st.x) > absf(st.y) else Vector2i(0, 1 if st.y > 0 else -1)
	var r := _step_actor(me.p, me.d, dt, me.want, _speed + 4.0 * float(level))
	me.p = r[0]
	me.d = r[1]
	me.mouth = fposmod(me.mouth + dt * 9.0, 1.0)
	var c := _cell_of(me.p)
	if c.x >= 0 and c.x < COLS and c.y >= 0 and c.y < ROWS:
		var v: int = pellets[c.y][c.x]
		if v > 0 and (me.p - _cell_pos(c)).length() < CW * 0.4:
			pellets[c.y][c.x] = 0
			left -= 1
			score += 10 if v == 1 else 50
			if v == 2:
				scared_t = 7.0
				for g in gremlins:
					g.eaten = false
	scared_t = maxf(0.0, scared_t - dt)
	if left <= 0:
		level += 1
		score += 500
		_new_level()
		return
	for g in gremlins:
		if g.wait > 0.0:
			g.wait -= dt
			continue
		var gc := _cell_of(g.p)
		var gcentre := _cell_pos(gc)
		var spd := (_speed - 10.0 + 3.0 * float(level)) * (0.6 if scared_t > 0.0 else 1.0) * (1.8 if g.eaten else 1.0)
		if (g.p - gcentre).length() < spd * dt + 0.01:
			# at a junction: pick the way that gets nearest the target, never turning straight back unless boxed in
			var target: Vector2 = me.p
			if g.eaten:
				target = _cell_pos(g.home)
			elif scared_t > 0.0:
				target = Vector2(rng.randf_range(0, 360), rng.randf_range(0, 540))
			elif int(t * 0.2) % 3 == 2:
				target = _cell_pos(g.home)                     # now and then they scatter to their corners
			var best := Vector2i.ZERO
			var best_d := 1.0e9
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				if d == -g.d:
					continue
				if _open_dir(gc, d):
					var dd := (gcentre + Vector2(d) * CW - target).length()
					if dd < best_d:
						best_d = dd
						best = d
			if best == Vector2i.ZERO:
				best = -g.d if _open_dir(gc, -g.d) else Vector2i.ZERO
			g.p = gcentre
			g.d = best
		g.p += Vector2(g.d) * spd * dt
		if g.eaten and (g.p - _cell_pos(g.home)).length() < 4.0:
			g.eaten = false
		if not g.eaten and (g.p - me.p).length() < 11.0:
			if scared_t > 0.0:
				g.eaten = true
				score += 200
			else:
				lives -= 1
				dead_t = 1.3
				if lives <= 0:
					over = true
				return


func draw(ci: CanvasItem, font: Font) -> void:
	ci.draw_rect(Rect2(0, TOP, W, H - TOP), Color(0.02, 0.02, 0.07))
	var wall_col := Color(0.2, 0.35, 0.95)
	for r in range(ROWS):
		for c in range(COLS):
			var m: int = walls[r][c]
			var p := Vector2(OX + float(c) * CW, OY + float(r) * CW)
			if m < 0:
				ci.draw_rect(Rect2(p + Vector2(3, 3), Vector2(CW - 6, CW - 6)), Color(0.07, 0.12, 0.45, 0.9))
				ci.draw_rect(Rect2(p + Vector2(2, 2), Vector2(CW - 4, CW - 4)), wall_col, false, 1.4)
			else:
				var v: int = pellets[r][c]
				var cc := p + Vector2(CW / 2.0, CW / 2.0)
				if v == 1:
					ci.draw_circle(cc, 2.0, Color(1.0, 0.9, 0.7))
				elif v == 2:
					ci.draw_circle(cc, 5.0 + sin(t * 8.0), Color(1.0, 0.95, 0.4))
	# the robot: a rounded square face with a little mouth that chomps, and two eyes
	var mp: Vector2 = me.p
	if dead_t > 0.0:
		var k := 1.0 - dead_t / 1.3
		ci.draw_circle(mp, 8.0 * (1.0 - k), Color(0.5, 0.9, 1.0))
	else:
		ci.draw_rect(Rect2(mp - Vector2(8, 8), Vector2(16, 16)), Color(0.5, 0.9, 1.0))
		ci.draw_rect(Rect2(mp - Vector2(8, 8), Vector2(16, 16)), Color.WHITE, false, 1.0)
		var dirv := Vector2(me.d) if me.d != Vector2i.ZERO else Vector2(1, 0)
		var mouth := 3.0 + 4.0 * absf(sin(me.mouth * PI))
		var perp := Vector2(-dirv.y, dirv.x)
		ci.draw_colored_polygon(PackedVector2Array([mp, mp + dirv * 9.0 + perp * mouth, mp + dirv * 9.0 - perp * mouth]), Color(0.02, 0.02, 0.07))
		ci.draw_circle(mp - dirv * 2.0 + perp * 4.0, 1.8, Color.BLACK)
		ci.draw_circle(mp - dirv * 2.0 - perp * 4.0, 1.8, Color.BLACK)
	# the gremlins: spiky blobs; pale and wobbling when scared, just eyes when eaten
	for g in gremlins:
		var gp: Vector2 = g.p
		var col: Color = g.color
		if g.eaten:
			ci.draw_circle(gp + Vector2(-3, -1), 2.5, Color.WHITE)
			ci.draw_circle(gp + Vector2(3, -1), 2.5, Color.WHITE)
			continue
		if scared_t > 0.0:
			col = Color(0.3, 0.4, 1.0) if (scared_t > 2.0 or int(t * 8.0) % 2 == 0) else Color(1, 1, 1)
		ci.draw_circle(gp + Vector2(0, -1), 8.0, col)
		ci.draw_rect(Rect2(gp + Vector2(-8, -1), Vector2(16, 8)), col)
		for k in range(4):
			var sx := -7.0 + float(k) * 4.7
			ci.draw_colored_polygon(PackedVector2Array([gp + Vector2(sx, 7), gp + Vector2(sx + 2.3, 11 + sin(t * 10.0 + float(k)) * 1.5), gp + Vector2(sx + 4.7, 7)]), col)
		ci.draw_circle(gp + Vector2(-3, -2), 2.5, Color.WHITE)
		ci.draw_circle(gp + Vector2(3, -2), 2.5, Color.WHITE)
		ci.draw_circle(gp + Vector2(-3, -2) + Vector2(g.d) * 1.2, 1.2, Color.BLACK)
		ci.draw_circle(gp + Vector2(3, -2) + Vector2(g.d) * 1.2, 1.2, Color.BLACK)
