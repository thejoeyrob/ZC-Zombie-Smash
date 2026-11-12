class_name TTGame
extends RefCounted
## TRUCKIN' & DRIVIN': the rules of the owner's five-lane lorry game (ported from the Trakway-Trail web game, minus the garage upgrades).
## Drive an articulated lorry down a five-lane road, take supermarket jobs by following the golden breadcrumbs to the finish flag, grab tacos, coins and
## turbo, drive through night shifts, dodge road restrictions, and beep the horn at the sheep when they bleat. Pure rules, no drawing.

const PICKUPS := ["job", "crumb", "finish", "taco", "coin", "night", "boost"]
const ROAD_TYPES := ["lowbridge", "weakbridge", "bus", "noentry", "narrow", "grass", "house", "works"]
const CRASHES := {"car": "Not a bumper car.", "lowbridge": "Height restriction. Not a suggestion.", "weakbridge": "Weight limit: less than you.",
	"oil": "Slick move, driver.", "house": "Planning permission denied.", "sheep": "Ewe had one job."}
const SCENARIOS := ["narrow", "split", "contraflow", "oneway", "works", "bus", "chicane"]

var rng := RandomNumberGenerator.new()
var items: Array = []
var events: Array = []
var distance := 0.0
var time := 0.0
var money := 500.0
var earned := 0.0
var fines := 0.0
var jobs := 0
var crumbs := 0
var horns := 0
var lane := 2
var x := 2.0
var trailer := 2.0
var rear := 2.0
var sway := 0.0
var angle := 0.0
var rapid := 0.0
var last_move := -10.0
var invulnerable := 0.0
var speed := 180.0
var last_scenario := ""
var cruise := 240.0
var row := 900.0
var next_job := 600.0
var next_sheep := 6500.0
var next_night := 5600.0
var next_boost := 2100.0
var night: Dictionary = {}
var nights := 0
var boost := 0.0
var job: Dictionary = {}
var sheep: Dictionary = {}
var finished := false
var end_reason := ""
var stage := 0
var slow := 0.0
var multiplier := 1
var next_id := 0
var combo := 0
var crash_kind := ""
var theme_seq: Array = [0, 1, 2, 3]


func _init(seed_value := 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value


static func clampf2(v: float, a: float, b: float) -> float:
	return maxf(a, minf(b, v))


# ---- the road ---------------------------------------------------------------------------------------
func road_theme(z: float) -> int:
	var sector: int = int(floorf(maxf(0.0, z) / 5400.0))
	while theme_seq.size() <= sector:
		var n: int = theme_seq.size()
		var h: int = ((n ^ 0x9e3779b9) * 0x85ebca6b) & 0xffffffff
		h = (h ^ (h >> 16)) & 0xffffffff
		theme_seq.append((int(theme_seq[n - 1]) + 1 + h % 3) % 4)
	return int(theme_seq[sector])


func road_width(z: float) -> float:
	return 610.0 if road_theme(z) == 1 else 630.0


func lane_x(lane_pos: float, z: float) -> float:
	return 210.0 + (lane_pos - 2.0) * road_width(z) * 0.56 / 5.0


func _back(p: Vector2, d: float, a: float) -> Vector2:
	return Vector2(p.x - sin(a) * d, p.y + cos(a) * d)


## Where the cab, trailer (and second trailer) are, relative to the cab at (x, 0).
func rig_pose(px: float, py: float, cab_angle: float, trailer_angle: float, rear_angle: float) -> Dictionary:
	var hitch := _back(Vector2(px, py), 34.0, cab_angle)
	var tr := _back(hitch, 38.0, trailer_angle)
	var rear_hitch := _back(hitch, 101.0, trailer_angle)
	var rr := _back(rear_hitch, 45.0, rear_angle)
	return {"hitch": hitch, "trailer": tr, "trailer_angle": trailer_angle, "rear": rr, "rear_angle": rear_angle}


func hazard_kinds(z: float) -> Array:
	var all := [["car", "cone", "bus", "noentry", "lowbridge"], ["grass", "weakbridge", "oil", "lowbridge", "narrow"],
		["house", "car", "noentry", "narrow"], ["barrier", "cone", "oil", "works"]]
	return all[road_theme(z)]


func ramp() -> float:
	return clampf2(distance / 63000.0, 0.0, 1.0)


# ---- helpers ----------------------------------------------------------------------------------------
func emit(type: String, data := {}) -> void:
	var e := {"type": type}
	e.merge(data)
	events.append(e)


func _len(e: Dictionary, dflt: float) -> float:
	var l: float = float(e.get("length", 0.0))
	return l if l > 0.0 else dflt


func add(type: String, z: float, ln: int, props := {}) -> Dictionary:
	next_id += 1
	var is_road: bool = ROAD_TYPES.has(type)
	var e := {"id": next_id, "type": type, "z": z, "lane": ln, "done": false}
	if is_road:
		e["road"] = true
		e["length"] = 310.0 if (type == "bus" or type == "noentry" or type == "works") else 190.0
		e["warning"] = 390.0
	e.merge(props, true)
	items.append(e)
	return e


func move(direction: int) -> void:
	if finished:
		return
	var nxt: int = clampi(lane + direction, 0, 4)
	if nxt == lane:
		return
	rapid = clampf2(rapid + (0.3 if time - last_move < 0.2 else 0.07), 0.0, 1.5)
	last_move = time
	lane = nxt
	emit("steer")


func set_lane(target: int) -> void:
	# the wheel picks a lane directly; step toward it one at a time so the swing of the trailer looks right
	var t: int = clampi(target, 0, 4)
	if t != lane and not finished:
		move(1 if t > lane else -1)


func horn() -> void:
	if finished:
		return
	emit("horn")
	if sheep.is_empty() or bool(sheep.cleared):
		return
	var delta: float = time - float(sheep.baa_at)
	if bool(sheep.baa) and delta >= 0.0 and delta <= 0.75:
		sheep.cleared = true
		horns += 1
		award(75.0, "WOOL DONE!")
		emit("sheep_clear")
	else:
		emit("hint", {"text": "Too late! Brake for the flock." if bool(sheep.baa) else "Wait for the BAA..."})


func award(value: float, label: String) -> void:
	money += value
	earned += value
	emit("cash", {"value": value, "label": label})


func fine(value: float, label: String) -> void:
	if invulnerable > 0.0:
		return
	money -= value
	fines += value
	combo = 0
	invulnerable = 1.3
	slow = 0.8
	emit("loss", {"value": value, "label": label})
	if money <= 0.0:
		end("The float has floated away.")


func job_value(value: float) -> float:
	return roundf(value * float(multiplier))


func jobPath(start_lane: int, count := 10) -> Array:
	var p: Array = []
	var ln := start_lane
	for i in range(count):
		if i % 2 == 1:
			ln = clampi(ln + (1 if rng.randf() > 0.5 else -1), 0, 4)
		p.append(ln)
	return p


func start_job(item: Dictionary) -> void:
	if not job.is_empty() or not night.is_empty():
		return
	var dbl: bool = bool(item.get("double", false))
	multiplier = 2 if dbl else 1
	job = {"label": "THE DOUBLE TROUBLE" if dbl else "SUPERMARKET SWEEP", "pay": job_value(150.0), "count": 0, "total": 10, "double": dbl, "end": float(item.z) + 1780.0}
	var keep: Array = []
	for e in items:
		if e == item or float(e.z) + float(e.get("length", 0.0)) < float(item.z) - 240.0 or float(e.z) > float(job.end) + 650.0:
			keep.append(e)
	items = keep
	var p: Array = jobPath(int(item.lane))
	for i in range(p.size()):
		var ln: int = int(p[i])
		add("crumb", float(item.z) + 160.0 * float(i + 1), ln)
		if i % 2 == 1:
			add("cone" if rng.randf() > 0.5 else "car", float(item.z) + 160.0 * float(i + 1), (ln + 2 + int(floorf(rng.randf() * 2.0))) % 5)
	add("finish", float(job.end), int(p[p.size() - 1]))
	row = maxf(row, float(job.end) + 650.0)
	next_job = float(job.end) + 1000.0
	emit("job", {"label": job.label, "double": dbl})


func start_night(item: Dictionary) -> void:
	if not job.is_empty() or not sheep.is_empty() or not night.is_empty():
		return
	var end_z: float = float(item.z) + 4200.0
	night = {"start": item.z, "end": end_z}
	nights += 1
	var keep: Array = []
	for e in items:
		if e == item or float(e.z) + float(e.get("length", 0.0)) < float(item.z) - 235.0 or float(e.z) > end_z + 600.0:
			keep.append(e)
	items = keep
	var ln: int = int(item.lane)
	for i in range(1, 41):
		if i % 4 == 0:
			ln = clampi(ln + (1 if rng.randf() > 0.5 else -1), 0, 4)
		var z: float = float(item.z) + float(i) * 100.0
		add("coin", z, ln, {"night_coin": true})
		if i % 5 == 0:
			var k: Array = hazard_kinds(z)
			add(str(k[int(floorf(rng.randf() * float(k.size())))]), z, (ln + 2) % 5)
	row = maxf(row, end_z + 650.0)
	next_job = maxf(next_job, end_z + 760.0)
	next_sheep = maxf(next_sheep, end_z + 1100.0)
	next_night = end_z + 4300.0
	emit("night")


func collect(e: Dictionary) -> void:
	if bool(e.done):
		return
	e.done = true
	match str(e.type):
		"job":
			start_job(e)
		"night":
			start_night(e)
		"boost":
			boost = 7.0
			emit("boost")
		"crumb":
			if not job.is_empty():
				job.count = int(job.count) + 1
				crumbs += 1
				combo += 1
				var v: float = job_value(25.0)
				job.pay = float(job.pay) + v
				emit("crumb", {"value": v})
		"finish":
			if not job.is_empty():
				var pay: float = float(job.pay)
				var dbl: bool = bool(job.double)
				jobs += 1
				award(pay, "DELIVERY BANKED")
				emit("delivery", {"pay": pay, "perfect": int(job.count) == 10, "double": dbl})
				job = {}
				multiplier = 1
		"taco":
			award(100.0, "TACO BREAK. PAID.")
			slow = 2.4
			emit("taco")
		"coin":
			award(roundf(15.0 * (2.0 if not night.is_empty() else 1.0)), "DOUBLE BUBBLE" if not night.is_empty() else "ROAD BONUS")
		"car", "lowbridge", "weakbridge", "oil", "house":
			crash(str(e.type))
		"cone", "barrier", "works":
			fine(70.0, "Cones are not a slalom.")
		"narrow":
			fine(80.0, "Mirrors are wider than optimism.")
		"bus":
			fine(90.0, "You are not a bus.")
		"noentry":
			fine(120.0, "Sat-nav says... absolutely not.")
		"grass":
			fine(65.0, "Lawn care: 65.")


func crash(kind: String) -> void:
	if finished:
		return
	crash_kind = kind
	emit("crash", {"kind": kind})
	end(str(CRASHES.get(kind, "Crunch.")))


func end(reason: String) -> void:
	if finished:
		return
	finished = true
	end_reason = reason
	emit("end", {"reason": reason})


# ---- lanes are never double-booked -----------------------------------------------------------------
func lane_busy(ln: int, z0: float, z1: float, pad := 110.0) -> bool:
	for e in items:
		if not bool(e.done) and int(e.lane) == ln and float(e.z) - pad < z1 and float(e.z) + _len(e, 40.0) + pad > z0:
			return true
	return false


func open_lanes(z0: float, z1: float, pad := 60.0) -> Array:
	var r: Array = []
	for l in range(5):
		if not lane_busy(l, z0, z1, pad):
			r.append(l)
	return r


func shuffled() -> Array:
	var a: Array = [0, 1, 2, 3, 4]
	for i in range(4, 0, -1):
		var j: int = int(floorf(rng.randf() * float(i + 1)))
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a


func make_row(z: float, gap_sec: float) -> float:
	var r: float = ramp()
	var kinds: Array = hazard_kinds(z)
	var reach: int = maxi(2, int(floorf(gap_sec / 0.34)))
	var roll: float = rng.randf()
	var want: int = 1 if distance < 2500.0 else (1 if roll < 0.40 - 0.18 * r else (2 if roll < 0.86 - 0.12 * r else 3))
	var picked: Array = []
	for ln in shuffled():
		if picked.size() >= want:
			break
		var edge: bool = ln == 0 or ln == 4
		var pool: Array = []
		for k in kinds:
			if edge or not (k == "house" or k == "grass" or k == "bus"):
				pool.append(k)
		if pool.is_empty():
			continue
		var kind: String = str(pool[int(floorf(rng.randf() * float(pool.size())))])
		var length: float = 40.0
		if ROAD_TYPES.has(kind):
			length = 310.0 if (kind == "bus" or kind == "noentry" or kind == "works") else 190.0
		if not lane_busy(int(ln), z, z + length):
			picked.append({"lane": int(ln), "kind": kind, "len": length})
	var span := 40.0
	for p in picked:
		span = maxf(span, float(p.len))
	var prev: Array = open_lanes(z - cruise * gap_sec * 1.1, z - 60.0)
	while not picked.is_empty():
		var fr: Array = _free(picked, z, span)
		var reachable := false
		for f in fr:
			for pv in prev:
				if absi(int(f) - int(pv)) <= reach:
					reachable = true
		if fr.size() >= 2 and reachable:
			break
		picked.pop_back()
	for p in picked:
		add(str(p.kind), z + rng.randf() * 50.0, int(p.lane))
	var open: Array = _free(picked, z, span)
	if not open.is_empty() and rng.randf() < 0.6:
		var ln2: int = int(open[int(floorf(rng.randf() * float(open.size())))])
		for k in range(4):
			var cz: float = z + 120.0 + float(k) * 95.0
			if not lane_busy(ln2, cz, cz, 45.0):
				add("taco" if (k == 0 and rng.randf() < 0.12) else "coin", cz, ln2)
			var nxt: Array = []
			for l in [ln2 - 1, ln2 + 1]:
				if open.has(l):
					nxt.append(l)
			if not nxt.is_empty() and rng.randf() < 0.7:
				ln2 = int(nxt[int(floorf(rng.randf() * float(nxt.size())))])
	return span


func _free(picked: Array, z: float, span: float) -> Array:
	var r: Array = []
	for l in range(5):
		var taken := false
		for p in picked:
			if int(p.lane) == l:
				taken = true
		if not taken and not lane_busy(l, z, z + span, 60.0):
			r.append(l)
	return r


func choose_scenario(z: float, diff: float) -> Dictionary:
	var allowed: Array = []
	for n in SCENARIOS:
		if (diff >= 0.18 or n != "chicane") and n != last_scenario:
			allowed.append(n)
	var name: String = str(allowed[int(floorf(rng.randf() * float(allowed.size())))])
	var side: int = 0 if rng.randf() < 0.5 else 4
	var from_edge: Array = [0, 1] if side == 0 else [4, 3]
	var width: int = 1 if rng.randf() < 0.6 else 2
	var p: Array = []
	var pick3: int = 1 + int(floorf(rng.randf() * 3.0))
	match name:
		"narrow":
			_sec(p, "grass", 0, z, 340.0)
			_sec(p, "grass", 4, z, 340.0)
		"split":
			_sec(p, "works", 2, z, 340.0)
			_sec(p, "noentry", 1 if rng.randf() < 0.5 else 3, z, 340.0)
		"contraflow":
			_sec(p, "noentry", side, z, 340.0)
			p.append({"type": "car", "lane": side, "z": z + 175.0, "oncoming": true})
			if width == 2:
				_sec(p, "noentry", int(from_edge[1]), z, 340.0)
		"oneway":
			for ln in from_edge:
				_sec(p, "noentry", int(ln), z, 340.0)
		"works":
			_sec(p, "works", pick3, z, 340.0)
			_sec(p, "narrow", side, z + 95.0, 175.0)
		"bus":
			_sec(p, "bus", side, z, 340.0)
			if width == 2:
				_sec(p, "noentry", int(from_edge[1]), z + 115.0, 190.0)
		"chicane":
			_sec(p, "works", pick3, z, 170.0)
			var nxt: int = 3 if pick3 == 1 else (1 if pick3 == 3 else (0 if rng.randf() < 0.5 else 4))
			_sec(p, "narrow", nxt, z + 210.0, 170.0)
	return {"name": name, "items": p}


func _sec(p: Array, type: String, ln: int, at: float, length: float) -> void:
	p.append({"type": type, "lane": ln, "z": at, "length": length, "warning": 620.0})


func spawn_encounter(z: float) -> bool:
	var e: Dictionary = choose_scenario(z, ramp())
	for i in e.items:
		var z0: float = distance if bool(i.get("oncoming", false)) else float(i.z)
		if lane_busy(int(i.lane), z0, float(i.z) + _len(i, 40.0), 90.0):
			return false
	last_scenario = str(e.name)
	for i in e.items:
		var props: Dictionary = i.duplicate()
		props.erase("type")
		props.erase("z")
		props.erase("lane")
		add(str(i.type), float(i.z), int(i.lane), props)
	return true


func _pending(types: Array) -> bool:
	for e in items:
		if types.has(str(e.type)) and not bool(e.done):
			return true
	return false


func spawn() -> void:
	var busy: bool = not job.is_empty() or not sheep.is_empty() or not night.is_empty()
	var pending: bool = _pending(["job", "night"])
	if not busy and not pending:
		if distance > next_night - 1100.0:
			add("night", distance + 700.0, 2)
			next_night = distance + 6500.0
		elif distance > next_job - 1100.0:
			add("job", maxf(next_job, distance + 700.0), 2, {"double": jobs > 0 and rng.randf() > 0.5})
			next_job += 3300.0
	if not busy and distance > next_boost - 700.0:
		add("boost", distance + 550.0, int(floorf(rng.randf() * 5.0)))
		next_boost = distance + 4200.0
	while row < distance + 1300.0:
		var r: float = ramp()
		var gap_sec: float = maxf(0.85, 1.4 - 0.45 * r)
		var near_job := false
		for e in items:
			if (e.type == "job" or e.type == "night") and not bool(e.done) and absf(float(e.z) - row) < 580.0:
				near_job = true
		if not job.is_empty() or not night.is_empty() or near_job:
			row += cruise * (gap_sec + rng.randf() * 0.55)
			continue
		if rng.randf() < 0.2 + 0.15 * r and spawn_encounter(row):
			row += 340.0 + cruise * (0.9 + rng.randf() * 0.5)
			continue
		row += make_row(row, gap_sec) + cruise * (gap_sec + rng.randf() * 0.55)
	var night_pending := false
	for e in items:
		if e.type == "night" and not bool(e.done):
			night_pending = true
	if distance > next_sheep - 850.0 and not busy and not night_pending:
		sheep = {"z": distance + 850.0, "baa": false, "baa_at": INF, "cleared": false}
		emit("sheep_warning")
		for e in items:
			if e.type == "job" and not bool(e.done) and float(e.z) > distance:
				e.z = float(sheep.z) + 900.0
		var keep: Array = []
		for e in items:
			if e.type == "job" or float(e.z) + float(e.get("length", 0.0)) < float(sheep.z) - 450.0 or float(e.z) > float(sheep.z) + 400.0:
				keep.append(e)
		items = keep
		next_sheep = distance + 5200.0


func tick(dt_in: float) -> void:
	if finished:
		return
	var dt: float = clampf2(dt_in, 0.0, 0.05)
	time += dt
	invulnerable = maxf(0.0, invulnerable - dt)
	slow = maxf(0.0, slow - dt)
	boost = maxf(0.0, boost - dt)
	var base: float = 240.0 + minf(70.0, time * 0.7) + 70.0 * ramp()
	cruise = base
	speed = base * (0.65 if slow > 0.0 else (1.3 if boost > 0.0 else 1.0))
	distance += speed * dt
	stage = road_theme(distance)
	var dbl: bool = not job.is_empty() and bool(job.double)
	rapid = maxf(0.0, rapid - dt * (0.19 if dbl else 0.43))
	x += (float(lane) - x) * (1.0 - exp(-dt * 11.0))
	trailer += (x - trailer) * (1.0 - exp(-dt * (2.2 if dbl else 4.0)))
	rear += (trailer - rear) * (1.0 - exp(-dt * 1.7))
	angle = clampf2((x - trailer) * 0.62, -0.85, 0.85)
	sway = clampf2(absf(x - trailer) * 0.3 + rapid * (0.72 if dbl else 0.32), 0.0, 1.0)
	if sway > 0.98 and dbl:
		fine(260.0, "JACKKNIFE! Double trouble.")
		emit("jackknife")
		var keep: Array = []
		for e in items:
			if e.type != "crumb" and e.type != "finish":
				keep.append(e)
		items = keep
		job = {}
		multiplier = 1
		rapid = 0.0
	if not night.is_empty() and distance > float(night.end):
		night = {}
		emit("dawn")
	spawn()
	if not sheep.is_empty():
		var ahead: float = float(sheep.z) - distance
		if ahead < maxf(375.0, speed * 1.5) and not bool(sheep.baa):
			sheep.baa = true
			sheep.baa_at = time
			emit("baa")
		if ahead < 65.0 and not bool(sheep.cleared):
			crash_kind = "sheep"
			emit("sheep_fail")
			end(str(CRASHES.sheep))
		if ahead < -200.0 and bool(sheep.cleared):
			sheep = {}
	for e in items:
		if not bool(e.done) and bool(e.get("oncoming", false)):
			e.z = float(e.z) - speed * dt * 0.55
	var pose: Dictionary = rig_pose(lane_x(x, distance), 0.0, clampf2((float(lane) - x) * 0.16, -0.2, 0.2), angle, clampf2((trailer - rear) * 0.55, -0.8, 0.8))
	var tp: Vector2 = pose.trailer
	var rp: Vector2 = pose.rear
	var dbl_now: bool = not job.is_empty() and bool(job.double)
	for e in items:
		if bool(e.done):
			continue
		var delta: float = float(e.z) - distance
		var length: float = float(e.get("length", 0.0))
		var hazard: bool = not PICKUPS.has(str(e.type))
		var cab_hit: bool = delta < 22.0 and delta + length > -24.0 and absf(float(e.lane) - x) < 0.52
		var trail_hit: bool = hazard and delta < -tp.y + 55.0 and delta + length > -tp.y - 55.0 and absf(lane_x(float(e.lane), float(e.z)) - tp.x) < 30.0
		var rear_hit: bool = hazard and dbl_now and delta < -rp.y + 55.0 and delta + length > -rp.y - 55.0 and absf(lane_x(float(e.lane), float(e.z)) - rp.x) < 30.0
		if cab_hit or trail_hit or rear_hit:
			collect(e)
		elif delta + length < (-240.0 if hazard else -28.0):
			e.done = true
			if e.type == "finish" and not job.is_empty():
				emit("missed_job")
				job = {}
				multiplier = 1
			elif e.type == "crumb":
				combo = 0
		if finished:
			break
	var live: Array = []
	for e in items:
		if float(e.z) + float(e.get("length", 0.0)) > distance - 325.0:
			live.append(e)
	items = live
