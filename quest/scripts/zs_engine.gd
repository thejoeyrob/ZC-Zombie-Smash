class_name ZSEngine
extends RefCounted
## Zombie Smash simulation, ported line by line from engine.js (fixed-step, fixed-world, seeded random numbers).
## It is checked against the JavaScript engine tick for tick (quest/tools/golden.mjs and quest/tests/trace.gd),
## so any change here must keep those traces identical.

const DATA_PATH := "res://data/zs_data.json"
const PICKUP_LIFE := 15.0
const GLOW := ["green", "pink", "blue", "orange", "yellow", "violet"]
const JOEY_TOP := -40.0
const JOEY_BOTTOM := 20.0
const JOEY_R := 15.0

static var data: Dictionary = {}
static var W: float = 343.0
static var H: float = 412.0
static var BOSSES: Array = []
static var MAPS: Array = []
static var ENEMIES: Dictionary = {}
static var BARREL: Dictionary = {}
static var SPECIALS: Array = []
static var GUNS: Dictionary = {}
static var BOSS_MOVE: Dictionary = {}
static var _ready_static := false

# ---- game state ---------------------------------------------------------------------------------
var on_event: Callable = Callable()
var seed_value: int = 1
var t := 0.0
var wave := 1
var score := 0
var kills := 0
var breaches := 0
var combo := 0
var multiplier := 1
var combo_left := 0.0
var spawned := 0
var resolved := 0
var target := 10
var spawn_in := 0.6
var enemies: Array = []
var openings: Array = []
var tile_bag: Array = []
var tile_bag_map := -1
var last_tile_entry := -1
var bullets: Array = []
var shots: Array = []
var pickups: Array = []
var grenades: Array = []
var barrels: Array = []
var effects: Array = []
var beams: Array = []
var arcs: Array = []
var pops: Array = []
var boss = null
var scene = null
var arena = null
var next_in := 0.0
var active := false
var over := false
var practice := false
var max_lives := 5
var invincible := false
var infinite_ammo := false
var next_id := 1
var bosses_down: Array = []
var banner := "HOLD THE LINE"
var banner_left := 2.4
var hit_stop := 0.0
var shake := 0.0
var danger_source = null
var player: Dictionary = {}
var input_axis := 0.0
var input_fire := false


# ---- static data -------------------------------------------------------------------------------
static func setup() -> void:
	if _ready_static:
		return
	_ready_static = true
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	W = float(data["W"])
	H = float(data["H"])
	BOSSES = data["BOSSES"]
	MAPS = data["MAPS"]
	ENEMIES = {
		"normal": {"hp": 2, "speed": 28, "r": 13, "points": 120, "art": "zombie-normal.webp", "height": 42},
		"runner": {"hp": 2, "speed": 49, "r": 12, "points": 180, "art": "zombie-runner.webp", "height": 42},
		"helmet": {"hp": 4, "speed": 25, "r": 14, "points": 240, "art": "zombie-helmet.webp", "height": 46},
		"toxic": {"hp": 4, "speed": 24, "r": 15, "points": 320, "art": "zombie-toxic.webp", "height": 48},
		"armored": {"hp": 6, "speed": 24, "r": 17, "points": 420, "art": "zombie-armored.webp", "height": 52},
		"berserker": {"hp": 5, "speed": 36, "r": 16, "points": 500, "art": "zombie-berserker.webp", "height": 50},
		"brute": {"hp": 9, "speed": 19, "r": 21, "points": 700, "art": "zombie-brute.webp", "height": 65},
		"titan": {"hp": 15, "speed": 17, "r": 24, "points": 1050, "art": "zombie-titan.webp", "height": 75},
		"fuse": {"hp": 3, "speed": 33, "r": 14, "points": 380, "art": "zombie-fuse.webp", "height": 52},
		"bulwark": {"hp": 9, "speed": 20, "r": 19, "points": 650, "art": "zombie-bulwark.webp", "height": 61},
		"mantismini": {"hp": 1, "speed": 36, "r": 11, "points": 150, "art": "boss-drmantis-stage3.webp", "height": 44},
	}
	# 7.6.2: zombies are 45% larger (hitbox +30%) and 20% slower.
	for k in ENEMIES:
		var s: Dictionary = ENEMIES[k]
		s["height"] = js_round(float(s["height"]) * 1.45)
		s["r"] = js_round(float(s["r"]) * 1.3)
		s["speed"] = float(String.num(float(s["speed"]) * 0.8, 1))
		s["hp"] = float(s["hp"])
	BARREL = {
		"width": 40, "height": 54, "hitRadius": 17.0, "throwWidth": 38, "throwHeight": 50, "throwHitRadius": 16.0,
		"throwBlast": js_round(W * 0.17), "flight": 1.08, "chainWind": 0.34, "chainExtend": 0.22,
	}
	SPECIALS = [
		{"id": "hose", "name": "WATER PULSE", "color": "#6fd0ff", "sound": "smg", "time": 10.0, "delay": 0.075, "damage": 0.95, "speed": 540.0, "pierce": 3, "life": 0.6, "knock": 7.0, "size": 6},
		{"id": "rainbow", "name": "RAINBOW SPRAY", "color": "#ff6ad5", "sound": "burst", "time": 10.0, "delay": 0.12, "damage": 0.8, "speed": 560.0, "pierce": 1, "life": 0.9, "fan": [-0.26, -0.13, 0.0, 0.13, 0.26], "size": 5},
		{"id": "bass", "name": "BASS CANNON", "color": "#ffb23d", "sound": "shotgun", "time": 10.0, "delay": 0.5, "damage": 2.4, "speed": 430.0, "pierce": 1, "life": 1.4, "blast": 52.0, "size": 9},
		{"id": "beans", "name": "ESPRESSO BLASTER", "color": "#c98a4b", "sound": "smg", "time": 10.0, "delay": 0.04, "damage": 0.55, "speed": 740.0, "pierce": 1, "life": 0.9, "jitter": 0.09, "size": 3},
		{"id": "laser", "name": "LASER PULSE", "color": "#ff2fd2", "sound": "dmr", "time": 10.0, "delay": 0.17, "damage": 1.7, "hitscan": true, "width": 13.0},
		{"id": "remover", "name": "MAKEUP REMOVER", "color": "#ff9fcb", "sound": "smg", "time": 10.0, "delay": 0.13, "damage": 1.0, "speed": 500.0, "pierce": 2, "life": 0.8, "slow": true, "strip": true, "size": 6},
		{"id": "purge", "name": "PURGE ARC", "color": "#9dff4a", "sound": "burst", "time": 10.0, "delay": 0.24, "damage": 1.5, "speed": 600.0, "pierce": 1, "life": 0.9, "chain": 3, "size": 5},
	]
	GUNS = {
		"pistol": {"name": "PISTOL", "delay": 0.22, "damage": 1.5, "speed": 600.0, "ammo": INF, "pierce": 1},
		"smg": {"name": "SMG", "delay": 0.09, "damage": 1.15, "speed": 660.0, "ammo": 100.0, "pierce": 1},
		"shotgun": {"name": "SCATTER", "delay": 0.54, "damage": 1.7, "speed": 550.0, "ammo": 24.0, "pierce": 1},
		"dmr": {"name": "DMR-82", "delay": 0.42, "damage": 9.0, "speed": 800.0, "ammo": 24.0, "pierce": 3},
		"burst": {"name": "PULSE", "delay": 0.26, "damage": 1.6, "speed": 670.0, "ammo": 60.0, "pierce": 1},
	}
	BOSS_MOVE = {
		"jordan": {"kind": "wander", "v": 92.0, "x": [48.0, W - 48.0], "y": [98.0, 142.0], "dwell": [0.7, 1.3], "sway": [0.0, 5.0, 0.0, 6.0], "lunge": 0.2},
		"glowinghumanity": {"kind": "orbit", "ax": 98.0, "ay": 22.0, "fx": 0.85, "fy": 1.7, "cy": 125.0, "sway": [0.0, 3.0, 0.0, 4.0]},
		"debo": {"kind": "wander", "v": 46.0, "x": [60.0, W - 60.0], "y": [100.0, 135.0], "dwell": [1.3, 2.2], "sway": [0.0, 3.5, 0.0, 3.2], "lunge": 0.5, "follow": 0.45},
		"caffeinatedsloth": {"kind": "stopgo", "crawl": 18.0, "burst": 210.0, "x": [50.0, W - 50.0], "y": [98.0, 150.0], "sway": [2.4, 1.2, 34.0, 28.0]},
		"discoman": {"kind": "wander", "v": 62.0, "x": [56.0, W - 56.0], "y": [100.0, 140.0], "dwell": [0.8, 1.2], "sway": [15.0, 9.0, 3.4, 6.8], "lunge": 0.15},
		"fatamy": {"kind": "wander", "v": 48.0, "x": [66.0, W - 66.0], "y": [104.0, 150.0], "dwell": [1.4, 2.3], "sway": [4.0, 5.0, 2.2, 4.4], "lunge": 0.3},
		"drmantis": {"kind": "zigzag", "v": 168.0, "x": [50.0, W - 50.0], "y": [98.0, 150.0], "dwell": [0.55, 1.0], "sway": [0.0, 4.0, 0.0, 7.0], "lunge": 0.25},
	}


## JavaScript Math.round for the values used here (always positive).
static func js_round(v: float) -> int:
	return int(floor(v + 0.5))


## V8's Math.hypot (scaled, Kahan summed) so distances match the JavaScript engine exactly.
static func hypot(a: float, b: float) -> float:
	var ax := absf(a)
	var bx := absf(b)
	var m := maxf(ax, bx)
	if m == 0.0:
		return 0.0
	var sum := 0.0
	var comp := 0.0
	for v in [ax, bx]:
		var n: float = v / m
		var summand: float = n * n - comp
		var prelim: float = sum + summand
		comp = (prelim - sum) - summand
		sum = prelim
	return sqrt(sum) * m


static func cl(v: float, a: float, b: float) -> float:
	return maxf(a, minf(b, v))


static func segment_distance(px: float, py: float, x1: float, y1: float, x2: float, y2: float) -> float:
	var dx := x2 - x1
	var dy := y2 - y1
	var den := dx * dx + dy * dy
	if den == 0.0:
		den = 1.0
	var q := cl(((px - x1) * dx + (py - y1) * dy) / den, 0.0, 1.0)
	return hypot(px - x1 - q * dx, py - y1 - q * dy)


static func map_index(w: int) -> int:
	return int(minf(6.0, maxf(0.0, floor((float(w) - 1.0) / 2.0))))


## Stable sort with a JavaScript style comparator (negative = a first).
static func js_sort(arr: Array, cmp: Callable) -> void:
	for i in range(1, arr.size()):
		var item = arr[i]
		var j := i - 1
		while j >= 0 and float(cmp.call(arr[j], item)) > 0.0:
			arr[j + 1] = arr[j]
			j -= 1
		arr[j + 1] = item


func _init(seed_in: int = 1, handler: Callable = Callable()) -> void:
	setup()
	on_event = handler
	seed_value = seed_in & 0xFFFFFFFF
	reset()


func rand() -> float:
	seed_value = (1664525 * seed_value + 1013904223) & 0xFFFFFFFF
	return float(seed_value) / 4294967296.0


func emit(type: String, d: Dictionary = {}) -> void:
	if on_event.is_valid():
		on_event.call(type, d)


func joey_distance(x: float, y: float) -> float:
	var p := player
	return hypot(x - p.x, y - cl(y, p.y + JOEY_TOP, p.y + JOEY_BOTTOM))


func joey_hit(x1: float, y1: float, x2: float, y2: float, r: float) -> bool:
	var steps := maxi(1, int(ceil(hypot(x2 - x1, y2 - y1) / 5.0)))
	for i in range(steps + 1):
		if joey_distance(x1 + ((x2 - x1) * i) / steps, y1 + ((y2 - y1) * i) / steps) < JOEY_R + r:
			return true
	return false


func reset() -> void:
	t = 0.0
	wave = 1
	score = 0
	kills = 0
	breaches = 0
	combo = 0
	multiplier = 1
	combo_left = 0.0
	spawned = 0
	resolved = 0
	target = 10
	spawn_in = 0.6
	enemies = []
	openings = []
	tile_bag = []
	tile_bag_map = -1
	last_tile_entry = -1
	bullets = []
	shots = []
	pickups = []
	grenades = []
	barrels = []
	effects = []
	beams = []
	arcs = []
	pops = []
	boss = null
	scene = null
	arena = null
	next_in = 0.0
	active = false
	over = false
	practice = false
	max_lives = 5
	invincible = false
	infinite_ammo = false
	next_id = 1
	bosses_down = []
	banner = "HOLD THE LINE"
	banner_left = 2.4
	hit_stop = 0.0
	shake = 0.0
	danger_source = null
	player = {
		"x": W / 2.0, "y": H - 52.0, "lives": 5, "gun": "pistol", "ammo": INF, "grenades": 3, "cool": 0.0, "inv": 1.2,
		"shield": 0.0, "rapid": 0.0, "fireFx": 0.0, "hit": 0.0, "speedUp": 0.0, "vx": 0.0, "special": null,
		"inventory": {"smg": 0.0, "shotgun": 0.0, "dmr": 0.0, "burst": 0.0},
	}
	input_axis = 0.0
	input_fire = false


func start() -> void:
	active = true
	if barrels.is_empty():
		spawn_barrels()
	emit("music", {"track": "main"})
	emit("wave", {"wave": 1})


func set_input(axis: float, fire_on: bool) -> void:
	input_axis = cl(axis, -1.0, 1.0)
	input_fire = fire_on


func reset_input() -> void:
	input_axis = 0.0
	input_fire = false


func prepare_wave(n: int) -> void:
	if map_index(wave) != map_index(n):
		arena = null
		openings = []
		tile_bag = []
		tile_bag_map = -1
	wave = n
	target = int(minf(34.0, 8.0 + n * 2.0))
	spawned = 0
	resolved = 0
	spawn_in = 0.55
	next_in = 0.0
	boss = null
	banner = "INFINITE SURVIVAL" if n > 14 else "WAVE %d" % n
	banner_left = 1.8
	player.inv = maxf(player.inv, 1.1)
	spawn_barrels()
	emit("wave", {"wave": n})
	emit("music", {"track": "main"})


func spawn_barrels() -> void:
	barrels = []
	var count := 1 + int(floor(rand() * minf(5.0, 2.0 + floor(wave / 3.0))))
	for i in range(count):
		var x := 0.0
		var y := 0.0
		for tries in range(40):
			x = 38.0 + rand() * (W - 76.0)
			y = 105.0 + rand() * (H - 210.0)
			var ok := true
			for b in barrels:
				if not (hypot(b.x - x, b.y - y) > 57.0):
					ok = false
					break
			if ok:
				break
		var clash := false
		for b in barrels:
			if hypot(b.x - x, b.y - y) <= 57.0:
				clash = true
				break
		if clash:
			continue
		barrels.append({"id": next_id, "x": x, "y": y, "hp": 2.0, "dead": false})
		next_id += 1


func explode_barrel(barrel: Dictionary) -> void:
	if barrel.is_empty() or barrel.dead:
		return
	barrel.dead = true
	var r: float = float(BARREL.throwBlast) if barrel.get("small", false) else W * 0.2
	effects.append({"kind": "barrelBlast", "x": barrel.x, "y": barrel.y, "r": r, "life": 0.58, "total": 0.58, "color": "#ff9d35"})
	shake = maxf(shake, 2.6)
	emit("explosion")
	var targets: Array = enemies.duplicate()
	if boss != null:
		targets.append(boss)
	for z in targets:
		if not z.dead and hypot(z.x - barrel.x, z.y - barrel.y) < r + z.r:
			damage(z, 9.0 if z.get("boss", false) else 12.0, "barrel")
	if barrel.get("thrown", false) and boss != null and joey_distance(barrel.x, barrel.y) < r + 8.0:
		hurt(boss_def(boss.bossId).playerLoss)
	for other in barrels:
		if not other.dead and other.id != barrel.id and hypot(other.x - barrel.x, other.y - barrel.y) < r * 0.9:
			explode_barrel(other)


func boss_def(id: String) -> Dictionary:
	for b in BOSSES:
		if b.id == id:
			return b
	return {}


func enemy_pace() -> float:
	return (
		(1.0 + minf(1.1, (wave - 1) * 0.06))
		* minf(1.0, 0.9 + (wave - 1) * 0.04)
		* (1.0 + minf(0.6, maxf(0.0, wave - 12) * 0.025))
	)


func spawn_interval() -> float:
	return maxf(0.31, 0.82 - wave * 0.029)


func enemy_health(type: String) -> float:
	if type in ["normal", "runner", "mantismini"]:
		return 1.0
	return minf(1.32, 1.0 + maxf(0.0, wave - 4) * 0.022)


func choose_type() -> String:
	var w := wave
	var r := rand()
	if w < 3:
		return "normal" if r < 0.76 else "runner"
	if w < 5:
		return "normal" if r < 0.45 else ("runner" if r < 0.65 else ("helmet" if r < 0.85 else "fuse"))
	if w < 8:
		return "normal" if r < 0.25 else ("runner" if r < 0.4 else ("helmet" if r < 0.57 else ("toxic" if r < 0.73 else ("fuse" if r < 0.88 else "bulwark"))))
	var pool := ["normal", "runner", "helmet", "toxic", "armored", "berserker", "brute", "fuse", "bulwark"]
	if w > 10:
		pool.append("titan")
	return pool[int(floor(r * pool.size()))]


func spawn(type = null, x = null, y: float = -28.0, minion: bool = false) -> Dictionary:
	if type == null:
		type = choose_type()
	var spec: Dictionary = ENEMIES[type]
	var z := {
		"id": next_id, "type": type, "hp": spec.hp, "speed": spec.speed, "r": spec.r, "points": spec.points, "art": spec.art,
		"height": spec.height, "maxHp": spec.hp, "x": 0.0, "y": y, "age": 0.0, "attack": 0.0, "flash": 0.0, "dead": false,
		"minion": minion, "charge": 0, "baseX": 0.0, "route": null, "emerge": 0.0, "entryStyle": "", "paceFactor": 1.0,
		"slowT": 0.0, "vx": 0.0, "resolved": false,
	}
	next_id += 1
	# JS evaluates `x ?? 36 + rand() * (W - 72)` before `attack: 2 + rand() * 2`; keep that order.
	z.x = float(x) if x != null else 36.0 + rand() * (W - 72.0)
	z.attack = 2.0 + rand() * 2.0
	var spawn_map: Dictionary = MAPS[map_index(wave)]
	if not minion and y < 0.0 and spawn_map.get("entryStyle", "") == "edge":
		# The Harvest Chamber has no hatches: the horde walks in from the edges of the map.
		var entry: Array = spawn_map.entries[spawned % spawn_map.entries.size()]
		var lane := fmod(spawned * 0.61803398875 + rand() * 0.16, 1.0)
		z.x = float(entry[0])
		z.y = float(entry[1])
		z.entryStyle = "edge"
		var to_x: float = float(spawn_map.corridor[0]) + lane * (float(spawn_map.corridor[1]) - float(spawn_map.corridor[0]))
		var to_y: float = maxf(z.y, float(spawn_map.fanY) - 20.0) + rand() * 22.0
		z.route = {"edge": true, "fromX": z.x, "fromY": z.y, "toX": to_x, "toY": to_y}
	elif not minion and y < 0.0:
		var map: Dictionary = spawn_map
		var entry2: Array
		if map.get("entryStyle", "") == "tile":
			var map_id := map_index(wave)
			if tile_bag_map != map_id or tile_bag.is_empty():
				tile_bag_map = map_id
				tile_bag = []
				for i in range(map.entries.size()):
					var ex: float = float(map.entries[i][0])
					if ex >= float(map.corridor[0]) and ex <= float(map.corridor[1]):
						tile_bag.append(i)
				for i in range(tile_bag.size() - 1, 0, -1):
					var j := int(floor(rand() * (i + 1)))
					var tmp = tile_bag[i]
					tile_bag[i] = tile_bag[j]
					tile_bag[j] = tmp
				# A shuffled bag gives variety without repeated use of one square.
				if tile_bag.size() > 1 and tile_bag[tile_bag.size() - 1] == last_tile_entry:
					var tmp2 = tile_bag[0]
					tile_bag[0] = tile_bag[tile_bag.size() - 1]
					tile_bag[tile_bag.size() - 1] = tmp2
			last_tile_entry = tile_bag.pop_back()
			entry2 = map.entries[last_tile_entry]
		else:
			entry2 = map.entries[spawned % map.entries.size()]
		openings.append({"x": float(entry2[0]), "y": float(entry2[1]), "age": 0.0})
		var lane2 := fmod(spawned * 0.61803398875 + rand() * 0.16, 1.0)
		z.x = float(entry2[0]) + (0.0 if map.get("entryStyle", "") == "tile" else (rand() - 0.5) * 8.0)
		z.entryStyle = map.get("entryStyle", "grate")
		z.y = float(entry2[1])
		var to_x2: float = float(map.corridor[0]) + lane2 * (float(map.corridor[1]) - float(map.corridor[0]))
		var to_y2: float = float(map.fanY) + rand() * 22.0
		z.route = {"edge": false, "fromX": z.x, "fromY": z.y, "toX": to_x2, "toY": to_y2}
		z.emerge = 0.45
	z.baseX = z.x
	z.speed = float(z.speed) * enemy_pace()
	if z.route != null:
		z.paceFactor = (H - 52.0 - z.route.fromY) / (H - 52.0 + 28.0)
		z.speed = float(z.speed) * z.paceFactor
	z.maxHp = float(spec.hp) * enemy_health(type)
	z.hp = z.maxHp
	if not minion and not (z.route != null and z.route.edge):
		var m: float = ceil(float(z.height) * 0.41) + 2.0
		z.x = cl(z.x, m, W - m)
		z.baseX = z.x
	enemies.append(z)
	if not minion:
		spawned += 1
	return z


# ---- the main step ------------------------------------------------------------------------------
func step(dt_in: float) -> void:
	if not openings.is_empty():
		var kept: Array = []
		for o in openings:
			o.age += dt_in
			if o.age < 2.0:
				kept.append(o)
		openings = kept
	if not active or over:
		return
	var dt := minf(dt_in, 0.05)
	t += dt
	shake = maxf(0.0, shake - dt * 16.0)
	banner_left = maxf(0.0, banner_left - dt)
	effects = _tick_list(effects, dt)
	beams = _tick_list(beams, dt)
	arcs = _tick_list(arcs, dt)
	pops = _tick_list(pops, dt)
	for f in effects:
		f.x += float(f.get("vx", 0.0)) * dt
		f.y += float(f.get("vy", 0.0)) * dt
	if scene != null:
		scene.time += dt
		if scene.time >= scene.duration:
			advance_scene()
		return
	if player.special != null:
		player.special.left -= dt
		if player.special.left <= 0.0:
			player.special = null
			banner = "WEAPON SPENT"
			banner_left = 1.0
	var p := player
	p.inv = maxf(0.0, p.inv - dt)
	p.hit = maxf(0.0, p.hit - dt)
	p.cool = maxf(0.0, p.cool - dt)
	p.shield = maxf(0.0, p.shield - dt)
	p.rapid = maxf(0.0, p.rapid - dt)
	p.fireFx = maxf(0.0, p.fireFx - dt)
	p.speedUp = maxf(0.0, p.speedUp - dt)
	var tgt: float = input_axis * 212.0 * (1.55 if p.speedUp > 0.0 else 1.0)
	p.vx = tgt
	p.x = cl(p.x + p.vx * dt, 28.0, W - 28.0)
	p.y = H - 52.0
	if hit_stop > 0.0:
		hit_stop -= dt
		return
	if next_in > 0.0:
		next_in -= dt
		if next_in <= 0.0:
			prepare_wave(wave + 1)
		update_pickups(dt)
		return
	if combo_left > 0.0:
		combo_left -= dt
		if combo_left <= 0.0:
			reset_combo()
	if input_fire:
		fire()
	if boss == null and spawned < target:
		spawn_in -= dt
		if spawn_in <= 0.0 and enemies.size() < 13:
			var z := spawn()
			if spawned % 5 == 0 and z.route == null:
				z.x = cl(p.x, z.r + 6.0, W - z.r - 6.0)
				z.baseX = z.x
			spawn_in = spawn_interval() + (rand() - 0.5) * 0.14
			if wave >= 5 and spawned % 7 == 0 and spawned < target and enemies.size() < 12:
				var flank: float
				if absf(W - 2.0 * z.x) < 65.0:
					flank = (W - 52.0) if z.x < W / 2.0 else 52.0
				else:
					flank = W - z.x
				spawn("helmet" if wave >= 9 else "normal", flank, -52.0)
				spawn_in += 0.22
	if boss != null:
		update_boss(dt)
	for z in enemies:
		if z.dead:
			continue
		z.age += dt
		z.flash = maxf(0.0, z.flash - dt)
		z.attack -= dt
		var speed: float = z.speed
		if z.type == "runner" and z.age > 2.0:
			var phase := fmod(z.age - 2.0, 3.2)
			if phase < 0.45:
				speed = 2.0
				z.charge = 1
			elif phase < 1.0:
				speed *= 2.6
				z.charge = 2
			else:
				z.charge = 0
		var map: Dictionary = MAPS[map_index(wave)]
		speed *= 0.55 if (arena != null and arena.slow > 0.0) else 1.0
		z.emerge = maxf(0.0, z.emerge - dt)
		if z.emerge > 0.0 and (z.entryStyle == "tile" or z.entryStyle == "portal"):
			continue
		if z.slowT > 0.0:
			z.slowT -= dt
			speed *= 0.5
		if z.route != null and z.route.edge:
			var dx: float = z.route.toX - z.x
			var dy: float = z.route.toY - z.y
			var d := hypot(dx, dy)
			var stride := speed * dt
			if d <= stride + 0.5:
				z.x = z.route.toX
				z.y = z.route.toY
				z.baseX = z.x
				z.route = null
			else:
				z.x += (dx / d) * stride
				z.y += (dy / d) * stride
		elif z.route != null:
			z.y += speed * dt
			var q := cl((z.y - z.route.fromY) / (z.route.toY - z.route.fromY), 0.0, 1.0)
			# Smooth diagonal fan-out: deterministic per run, never a column of enemies.
			var ease := q * q * (3.0 - 2.0 * q)
			z.x = z.route.fromX + (z.route.toX - z.route.fromX) * ease
			if q >= 1.0:
				z.baseX = z.x
				z.route = null
		else:
			if z.type == "berserker":
				z.x = z.baseX + sin(z.age * 2.7) * 28.0
			if z.type in ["brute", "titan", "armored"]:
				z.x += cl(p.x - z.x, -1.0, 1.0) * 11.0 * dt
			z.y += speed * dt
			if z.vx != 0.0:
				z.x += z.vx * dt
				z.vx *= maxf(0.0, 1.0 - dt * 0.7)
				if absf(z.vx) < 2.0:
					z.vx = 0.0
		if not z.minion and not (z.route != null and z.route.edge):
			var m: float = ceil(float(z.height) * 0.41) + 2.0
			z.x = cl(z.x, maxf(m, float(map.corridor[0]) + maxf(0.0, m - 27.0)), minf(W - m, float(map.corridor[1]) - maxf(0.0, m - 27.0)))
		if z.type == "toxic" and z.attack <= 0.0 and z.y > 25.0 and z.y < p.y - 70.0:
			aimed_shot(z.x, z.y, "venom", 108.0 + minf(24.0, wave * 1.5), 8.0)
			z.attack = maxf(2.9, 4.1 - wave * 0.055)
		if z.type == "fuse" and z.y > p.y - 16.0:
			z.dead = true
			resolve(z)
			explode(z.x, z.y, 60.0, 3.0, false)
			if hypot(z.x - p.x, z.y - p.y) < 72.0:
				hurt("The Fuse detonated too close.")
		if joey_distance(z.x, z.y) < z.r + 12.0:
			hurt("The horde reached Joey Rob.")
			z.y += 18.0
		if z.y > H + 20.0:
			z.dead = true
			resolve(z)
			if not z.minion:
				breaches += 1
				reset_combo()
				emit("breach")
				banner = "BASE BREACH"
				banner_left = 0.9
				if breaches >= 10:
					end("The camp was overrun.")
	for br in barrels:
		if br.get("thrown", false) and not br.dead:
			br.age += dt
			br.x += br.vx * dt
			br.y += br.vy * dt
			br.rot += dt * 5.0
			if br.age >= br.T:
				explode_barrel(br)
	update_arena(dt)
	update_bullets(dt)
	update_shots(dt)
	update_pickups(dt)
	update_grenades(dt)
	enemies = enemies.filter(func(z): return not z.dead)
	barrels = barrels.filter(func(b): return not b.dead)
	if scene == null and boss == null and spawned >= target and resolved >= target and enemies.is_empty() and not over:
		var def: Dictionary = {}
		for b in BOSSES:
			if int(b.wave) == wave and not (b.id in bosses_down):
				def = b
				break
		if not def.is_empty():
			queue_boss(def.id)
		else:
			next_in = 1.55
			banner = "WAVE CLEAR"
			banner_left = 1.55
			emit("clear")


## Decrements `life` and keeps the entries that are still alive (JS: filter((f) => (f.life -= dt) > 0)).
func _tick_list(list: Array, dt: float) -> Array:
	var out: Array = []
	for f in list:
		f.life -= dt
		if f.life > 0.0:
			out.append(f)
	return out


func fire() -> bool:
	var p := player
	if not active or over or scene != null or p.cool > 0.0 or next_in > 0.0:
		return false
	if p.special != null:
		return fire_special()
	if p.ammo <= 0.0 and not infinite_ammo:
		equip("pistol")
	var gun: Dictionary = GUNS[p.gun]
	var angles: Array = [0.0]
	if p.gun == "shotgun":
		angles = [-0.17, -0.085, 0.0, 0.085, 0.17]
	elif p.gun == "burst":
		angles = [-0.055, 0.0, 0.055]
	for a in angles:
		bullets.append({
			"id": next_id, "x": p.x, "y": p.y - 27.0, "prevX": p.x, "prevY": p.y - 27.0,
			"vx": sin(a) * gun.speed, "vy": -cos(a) * gun.speed, "damage": gun.damage, "gun": p.gun,
			"pierce": int(gun.pierce), "hit": [], "life": 1.5, "sp": "",
		})
		next_id += 1
	p.cool = float(gun.delay) * (0.65 if p.rapid > 0.0 else 1.0)
	if is_finite(p.ammo) and not infinite_ammo:
		p.ammo -= 1.0
	p.fireFx = 0.065
	emit("shot", {"gun": p.gun})
	return true


func update_arena(dt: float) -> void:
	var index := map_index(wave)
	if arena == null or arena.index != index:
		arena = {"index": index, "cool": 0.0, "slow": 0.0, "pulse": 0.0, "targets": [
			{"x": 82.0, "y": 190.0, "lit": false}, {"x": W / 2.0, "y": 230.0, "lit": false}, {"x": W - 82.0, "y": 190.0, "lit": false}]}
	var a = arena
	var cooling: bool = a.cool > 0.0
	a.cool = maxf(0.0, a.cool - dt)
	a.slow = maxf(0.0, a.slow - dt)
	a.pulse = maxf(0.0, a.pulse - dt)
	if cooling and a.cool == 0.0:
		for tg in a.targets:
			tg.lit = false


func hit_arena_target(tg: Dictionary) -> void:
	var a = arena
	if a == null or a.cool != 0.0 or tg.lit or scene != null or over:
		return
	tg.lit = true
	var n := 0
	for x in a.targets:
		if x.lit:
			n += 1
	emit("target", {"n": n})
	for x in a.targets:
		if not x.lit:
			return
	a.cool = 12.0
	a.pulse = 1.2
	grant_special(a.index)


func grant_special(index: int) -> void:
	var sp: Dictionary = SPECIALS[index] if index < SPECIALS.size() else SPECIALS[0]
	player.special = {"id": sp.id, "left": sp.time}
	player.cool = 0.0
	banner = sp.name + "!"
	banner_left = 2.2
	shake = 2.0
	effects.append({"kind": "ring", "x": player.x, "y": player.y - 20.0, "r": 120.0, "life": 0.6, "total": 0.6, "color": sp.color})
	burst(player.x, player.y - 20.0, sp.color, 26, 190.0)
	emit("boost")
	emit("special", {"id": sp.id})


func special_def(id: String) -> Dictionary:
	for s in SPECIALS:
		if s.id == id:
			return s
	return {}


func fire_special() -> bool:
	var p := player
	var sp := special_def(p.special.id)
	if sp.is_empty():
		p.special = null
		return false
	p.cool = float(sp.delay) * (0.65 if p.rapid > 0.0 else 1.0)
	p.fireFx = 0.065
	if sp.get("hitscan", false):
		# A strobing laser column: everything in front of Joey takes the hit, shields included.
		var reach: float = float(sp.width) / 2.0
		var targets: Array = enemies.duplicate()
		if boss != null:
			targets.append(boss)
		for z in targets:
			if not z.dead and z.y < p.y - 14.0 and absf(z.x - p.x) < reach + float(z.get("r", 14.0)) * 0.8:
				damage(z, sp.damage, "dmr")
		if arena != null:
			for tg in arena.targets:
				if absf(tg.x - p.x) < reach + 12.0:
					hit_arena_target(tg)
		for item in pickups:
			if item.life > 0.0 and absf(item.x - p.x) < reach + 14.0:
				collect(item)
		for barrel in barrels:
			if not barrel.dead and absf(barrel.x - p.x) < reach + 12.0:
				barrel.hp -= sp.damage
				if barrel.hp <= 0.0:
					explode_barrel(barrel)
		beams.append({"x": p.x, "y": p.y - 30.0, "life": 0.11, "total": 0.11, "width": sp.width, "color": sp.color})
	else:
		var fan: Array = sp.get("fan", [0.0])
		for a in fan:
			var j: float = a
			if sp.has("jitter"):
				j = a + (rand() - 0.5) * 2.0 * float(sp.jitter)
			bullets.append({
				"id": next_id, "x": p.x, "y": p.y - 27.0, "prevX": p.x, "prevY": p.y - 27.0,
				"vx": sin(j) * sp.speed, "vy": -cos(j) * sp.speed, "damage": sp.damage, "gun": "special", "sp": sp.id,
				"pierce": int(sp.pierce), "hit": [], "life": sp.life,
			})
			next_id += 1
	emit("shot", {"gun": sp.sound, "id": sp.id})
	return true


func special_hit(b: Dictionary, z: Dictionary) -> void:
	var sp := special_def(b.sp)
	if sp.is_empty():
		return
	if sp.has("knock") and not z.get("boss", false):
		z.y = maxf(-10.0, z.y - sp.knock)
	if sp.has("slow") and not z.get("boss", false):
		z.slowT = 2.2
	if sp.has("blast"):
		explode(b.x, b.y, sp.blast, float(sp.damage) * 0.7, false)
	if sp.has("chain"):
		var from: Dictionary = z
		var used := {z.id: true}
		for hop in range(int(sp.chain)):
			var best = null
			var bd := 95.0
			for o in enemies:
				if not o.dead and not used.has(o.id):
					var d := hypot(o.x - from.x, o.y - from.y)
					if d < bd:
						bd = d
						best = o
			if best == null:
				break
			used[best.id] = true
			arcs.append({"x1": from.x, "y1": from.y - 10.0, "x2": best.x, "y2": best.y - 10.0, "life": 0.16, "total": 0.16})
			damage(best, float(sp.damage) * 0.7, "chain")
			from = best


func update_bullets(dt: float) -> void:
	for b in bullets:
		b.prevX = b.x
		b.prevY = b.y
		b.x += b.vx * dt
		b.y += b.vy * dt
		b.life -= dt
		var dx: float = b.x - b.prevX
		var dy: float = b.y - b.prevY
		var length: float = dx * dx + dy * dy
		if length == 0.0:
			length = 1.0
		if arena != null:
			for tg in arena.targets:
				if segment_distance(tg.x, tg.y, b.prevX, b.prevY, b.x, b.y) < 16.0:
					hit_arena_target(tg)
		var pool: Array = enemies.duplicate()
		if boss != null:
			pool.append(boss)
		pool.append_array(barrels)
		var hits: Array = []
		for z in pool:
			if z.dead or (z.id in b.hit):
				continue
			var rad: float
			if z.has("r"):
				rad = float(z.r)
			else:
				rad = float(BARREL.throwHitRadius) if z.get("thrown", false) else float(BARREL.hitRadius)
			if segment_distance(z.x, z.y, b.prevX, b.prevY, b.x, b.y) < rad + 3.0:
				hits.append(z)
		js_sort(hits, func(a, z): return ((a.x - z.x) * dx + (a.y - z.y) * dy) / length)
		for item in pickups:
			if item.life > 0.0 and segment_distance(item.x, item.y, b.prevX, b.prevY, b.x, b.y) < 16.0 + 2.0:
				collect(item)
		for z in hits:
			if b.pierce <= 0 or z.dead or scene != null:
				break
			b.hit.append(z.id)
			b.pierce -= 1
			if z.has("r"):
				damage(z, b.damage, "dmr" if b.sp == "remover" else b.gun)
				if b.sp != "":
					special_hit(b, z)
			else:
				z.hp -= b.damage
				if z.hp <= 0.0:
					explode_barrel(z)
				else:
					emit("ricochet")
	bullets = bullets.filter(func(b): return b.pierce > 0 and b.life > 0.0 and b.y > -35.0 and b.x > -20.0 and b.x < W + 20.0)


func damage(z: Dictionary, amount_in: float, source: String = "pistol") -> void:
	var amount := amount_in
	if z.dead or scene != null or (z.get("boss", false) and z.phaseGrace > 0.0):
		return
	var shield: bool = z.get("type", "") == "bulwark" and fmod(z.age, 3.5) < 2.0 and source != "grenade" and source != "chain" and source != "dmr"
	if shield:
		amount *= 0.28
		emit("ricochet")
	z.hp -= amount
	z.flash = 0.07
	emit("hit", {"boss": z.get("boss", false), "source": source})
	burst(z.x, z.y, "#8de8ff" if shield else "#fbd078", 3, 35.0)
	if z.get("boss", false):
		# Each form owns a health segment. Excess damage never skips a reveal or a form.
		var floor_hp: float = (z.maxHp * (z.stages - z.stage)) / z.stages
		if z.stage < z.stages and z.hp <= floor_hp:
			z.hp = floor_hp
			z.stage += 1
			z.attack = 1.35
			z.wind = 0
			z.mode = "idle"
			z.shake = 0
			z.chainIn = null
			z.followUps = []
			barrels = barrels.filter(func(x): return not x.get("thrown", false))
			shots = []
			bullets = []
			grenades = []
			emit("mutation", {"stage": z.stage})
			scene = {"kind": "mutation", "phase": 0, "time": 0.0, "duration": 2.8 if z.stage == 3 else 1.8, "bossId": z.bossId, "stage": z.stage}
			reset_input()
		elif z.hp <= 0.0:
			kill_boss()
		return
	if z.hp <= 0.0:
		z.dead = true
		resolve(z)
		kills += 1
		combo += 1
		combo_left = 7.0
		var previous := multiplier
		multiplier = 10 if combo >= 30 else (4 if combo >= 20 else (2 if combo >= 10 else 1))
		var points: float = float(z.points) * multiplier
		add_points(points, z.x, z.y)
		if multiplier > previous:
			emit("boost", {"multiplier": multiplier})
		burst(z.x, z.y, "#9cff65" if z.type == "fuse" else "#bfd595", 8, 60.0)
		emit("kill", {"type": z.type})
		if z.type == "fuse":
			explode(z.x, z.y, 85.0, 6.0, false)
		if kills % 20 == 0 or rand() < 0.022:
			drop(z.x, z.y)


func resolve(z: Dictionary) -> void:
	if z.get("resolved", false):
		return
	z.resolved = true
	if not z.get("minion", false):
		resolved += 1


func add_points(n: float, x: float, y: float) -> void:
	var r := js_round(n)
	score += r
	pops.append({"x": x, "y": y, "text": "+" + commas(r), "life": 0.9})
	if pops.size() > 12:
		pops.pop_front()


static func commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


func reset_combo() -> void:
	combo = 0
	multiplier = 1
	combo_left = 0.0


func hurt(reason: String) -> void:
	var p := player
	if over or scene != null or p.inv > 0.0 or p.shield > 0.0 or invincible:
		return
	p.lives -= 1
	p.inv = 1.25
	p.hit = 1.25
	shake = 2.0
	reset_combo()
	emit("hurt")
	if p.lives <= 0:
		end(reason)


func equip(gun: String, ammo = null) -> void:
	if not GUNS.has(gun):
		return
	var g: Dictionary = GUNS[gun]
	player.gun = gun
	player.ammo = float(ammo) if ammo != null else g.ammo
	banner = g.name + " READY"
	banner_left = 1.2


func use_stored(gun: String) -> bool:
	var p := player
	if not active or not (p.inventory.get(gun, 0.0) > 0.0) or not GUNS.has(gun) or scene != null or over or gun == p.gun:
		return false
	var ammo: float = p.inventory[gun]
	if p.gun != "pistol" and p.ammo > 0.0:
		p.inventory[p.gun] = p.ammo
	p.inventory[gun] = 0.0
	p.special = null
	equip(gun, ammo)
	emit("weaponUse", {"gun": gun})
	return true


func drop(x: float, y: float, forced: String = "") -> void:
	var types := ["grenade", "shield", "heart", "smg", "shotgun", "burst", "dmr"]
	var type := forced
	if type == "":
		var r := rand()
		if max_lives < 10 and rand() < 0.08:
			type = "goldheart"
		elif player.lives <= 2 and r < 0.35:
			type = "heart"
		elif r < 0.2:
			type = "grenade"
		elif r < 0.38:
			type = "shield"
		elif r < 0.54:
			type = "speed"
		else:
			type = types[3 + int(floor(rand() * 4.0))]
	pickups.append({"x": cl(x, 20.0, W - 20.0), "y": cl(y, 20.0, H - 45.0), "type": type, "life": PICKUP_LIFE + 5.0 if type == "goldheart" else PICKUP_LIFE, "age": 0.0})


func update_pickups(dt: float) -> void:
	for item in pickups:
		item.age += dt
		item.life -= dt
		item.y = minf(H - 52.0, item.y + 37.0 * dt)
		if item.life > 0.0 and joey_distance(item.x, item.y) < 22.0:
			collect(item)
	pickups = pickups.filter(func(i): return i.life > 0.0)


func collect(item: Dictionary) -> void:
	if item.life <= 0.0:
		return
	var p := player
	if GUNS.has(item.type):
		if p.inventory.get(item.type, 0.0) > 0.0 or (p.gun == item.type and p.ammo > 0.0):
			add_points(200.0, item.x, item.y)
			banner = GUNS[item.type].name + " ALREADY STORED"
			banner_left = 0.9
		else:
			p.inventory[item.type] = GUNS[item.type].ammo
			banner = GUNS[item.type].name + " STORED"
			banner_left = 1.2
	elif item.type == "heart":
		p.lives = mini(max_lives, p.lives + 1)
	elif item.type == "goldheart":
		if max_lives < 10:
			max_lives += 1
			p.lives = mini(max_lives, p.lives + 1)
			banner = "GOLD HEART · +1 MAX LIFE"
		else:
			p.lives = max_lives
			add_points(500.0, item.x, item.y)
			banner = "GOLD HEART · FULL HEALTH"
		banner_left = 1.4
	elif item.type == "grenade":
		p.grenades = mini(9, p.grenades + 2)
	elif item.type == "speed":
		p.speedUp = 7.0
		banner = "SPEED UP"
		banner_left = 1.0
	elif item.type == "shield":
		p.shield = 7.0
	item.life = 0.0
	emit("pickup", {"type": item.type})


func throw_grenade() -> bool:
	var p := player
	if not active or over or scene != null or next_in > 0.0 or p.grenades <= 0:
		return false
	p.grenades -= 1
	var tx: float = p.x
	var ty: float = maxf(48.0, p.y - H * 0.5)
	grenades.append({"sx": p.x, "sy": p.y - 20.0, "x": p.x, "y": p.y - 20.0, "tx": tx, "ty": ty, "age": 0.0, "duration": 0.52})
	emit("throw")
	return true


func update_grenades(dt: float) -> void:
	for g in grenades:
		g.age += dt
		var q := cl(g.age / g.duration, 0.0, 1.0)
		g.x = g.sx + (g.tx - g.sx) * q
		g.y = g.sy + (g.ty - g.sy) * q - sin(q * PI) * 35.0
		if q >= 1.0:
			explode(g.tx, g.ty, 125.0, 20.0, true)
	grenades = grenades.filter(func(g): return g.age < g.duration)


func explode(x: float, y: float, r: float, dmg: float, grenade: bool) -> void:
	effects.append({"kind": "ring", "x": x, "y": y, "r": r, "life": 0.48, "total": 0.48, "color": "#ffd27b" if grenade else "#92ee56"})
	burst(x, y, "#ffb341" if grenade else "#a2ed55", 24, 160.0)
	if grenade:
		shake = 3.0
		hit_stop = 0.025
		emit("explosion")
	var targets: Array = enemies.duplicate()
	if boss != null:
		targets.append(boss)
	for z in targets:
		if not z.dead and hypot(z.x - x, z.y - y) < r + z.r:
			damage(z, dmg, "grenade" if grenade else "chain")
	shots = shots.filter(func(s): return hypot(s.x - x, s.y - y) > r)
	for barrel in barrels.duplicate():
		if not barrel.dead and hypot(barrel.x - x, barrel.y - y) < r * 0.85:
			explode_barrel(barrel)


func burst(x: float, y: float, color: String, n: int, speed: float) -> void:
	for i in range(n):
		var a := rand() * PI * 2.0
		var v := speed * (0.4 + rand() * 0.6)
		var life := 0.16 + rand() * 0.25
		effects.append({"kind": "spark", "x": x, "y": y, "vx": cos(a) * v, "vy": sin(a) * v, "color": color, "life": life, "total": life, "r": 1.0 + rand() * 2.0})
	if effects.size() > 180:
		effects = effects.slice(effects.size() - 180)


func aimed_shot(x: float, y: float, kind: String, speed: float = 120.0, r: float = 9.0, offset: float = 0.0) -> void:
	var lead := 0.0
	if boss != null and boss.cycle % 3 == 0:
		lead = cl(float(player.vx) * 0.16, -32.0, 32.0)
	var a := atan2(player.y - y, cl(player.x + lead, 28.0, W - 28.0) - x) + offset
	shots.append({"x": x, "y": y, "vx": cos(a) * speed, "vy": sin(a) * speed, "kind": kind, "r": r, "life": 5.0, "age": 0.0, "color": ""})


func queue_boss(id: String, stage: int = 1) -> void:
	var def := boss_def(id)
	if def.is_empty():
		return
	boss = null
	enemies = []
	shots = []
	bullets = []
	grenades = []
	barrels = barrels.filter(func(b): return not b.get("thrown", false))
	scene = {"kind": "arrival", "bossId": id, "phase": 0, "time": 0.0, "duration": 0.7, "startStage": stage}
	reset_input()
	emit("entrance", {"id": id})
	emit("music", {"track": "disco" if id == "discoman" else "boss"})


func advance_scene() -> void:
	var s = scene
	if s == null:
		return
	if s.kind == "arrival" and s.phase < 2:
		s.phase += 1
		s.time = 0.0
		s.duration = 2.1 if s.phase == 1 else 2.8
		emit("panel", {"phase": s.phase})
		return
	scene = null
	if s.kind == "arrival":
		spawn_boss(s.bossId, s.get("startStage", 1))
	if s.kind == "down":
		next_in = 1.2
		banner = "BOSS DOWN · KEEP MOVING"
		banner_left = 1.2
		drop(W / 2.0, H - 75.0, "heart")
		drop(W / 2.0 + 60.0, H - 130.0, "dmr")
		if max_lives < 10:
			drop(W / 2.0 - 60.0, H - 150.0, "goldheart")
	if s.kind == "mutation":
		player.inv = 1.5
		if boss != null:
			boss.phaseGrace = 1.4
		emit("music", {"track": "disco" if (boss != null and boss.bossId == "discoman") else "boss"})
	if s.kind == "loss":
		over = true
		active = false
		emit("over", {"reason": s.reason})


func spawn_boss(id: String, stage: int = 1) -> void:
	var b := boss_def(id)
	if b.is_empty():
		return
	boss = {
		"id": next_id, "boss": true, "bossId": id, "name": b.name, "x": W / 2.0, "y": 118.0 if (id == "drmantis" and stage == 3) else 105.0,
		"r": 36.0, "vx": 0.0, "vy": 0.0, "mode": "idle", "shake": 0, "maxHp": float(b.hp) * 1.55,
		"hp": float(b.hp) * 1.55 * (1.0 - (float(stage) - 1.0) / float(b.stages)), "stages": int(b.stages), "stage": stage,
		"phaseGrace": 1.4, "age": 0.0, "attack": 1.55, "flash": 0.0, "dead": false, "wind": 0, "cycle": 0, "type": "",
		"followUps": [], "chainIn": null, "wp": null, "wpIn": 0.0, "mt": 0.0, "ox": 0.0, "oy": 0.0, "sgIn": 1.2,
		"bursting": false, "lunging": false, "miniIn": 1.0, "lastGlow": -1, "recordVolley": false, "modeT": 0.0, "chargeT": 0.0,
		"tx": 0.0, "ty": 0.0, "hx": 0.0, "hy": 0.0,
	}
	next_id += 1
	player.inv = 1.5
	banner = ""
	emit("fight", {"id": id})


func skip_boss(id: String, stage: int = 1) -> void:
	practice = true
	active = true
	over = false
	next_in = 0.0
	player.lives = max_lives
	player.grenades = 9
	player.inv = 2.0
	spawned = target
	resolved = target
	var def := boss_def(id)
	wave = int(def.wave)
	queue_boss(id, int(cl(float(stage), 1.0, float(def.stages))))


func boss_move(b: Dictionary, dt: float) -> void:
	var p := player
	if b.mode == "prep" or b.mode == "shake":
		return
	if b.mode == "charge":
		var dx: float = b.tx - b.x
		var dy: float = b.ty - b.y
		var l: float = hypot(dx, dy)
		if l == 0.0:
			l = 1.0
		var step_len := 270.0 * dt
		b.chargeT += dt
		if l <= step_len or b.chargeT > 1.2:
			b.mode = "retreat"
		else:
			b.x += (dx / l) * step_len
			b.y += (dy / l) * step_len
		return
	if b.mode == "retreat":
		var dx2: float = b.hx - b.x
		var dy2: float = b.hy - b.y
		var l2: float = hypot(dx2, dy2)
		if l2 == 0.0:
			l2 = 1.0
		var step2 := 150.0 * dt
		if l2 <= step2:
			b.x = b.hx
			b.y = b.hy
			b.mode = "idle"
			b.attack = 1.9
		else:
			b.x += (dx2 / l2) * step2
			b.y += (dy2 / l2) * step2
		return
	# Every boss has its own way of moving: roaming, orbiting, stop-and-go bursts or zig-zag darts.
	var st: Dictionary = BOSS_MOVE.get(b.bossId, BOSS_MOVE.jordan)
	var stage_mul: float = 1.0 + (b.stage - 1) * 0.16
	var vmul := 1.0
	b.mt += dt
	if st.kind == "orbit":
		var tt: float = b.mt * (1.0 + (b.stage - 1) * 0.2)
		var tx: float = W / 2.0 + st.ax * sin(tt * st.fx)
		var ty: float = st.cy + st.ay * sin(tt * st.fy)
		var follow := minf(1.0, dt * 5.0)
		b.vx = (tx - b.x) * 5.0
		b.vy = (ty - b.y) * 5.0
		b.x += (tx - b.x) * follow
		b.y += (ty - b.y) * follow
	else:
		b.wpIn -= dt
		if st.kind == "stopgo":
			# Crawl, twitch, then burst to a new spot.
			b.sgIn -= dt
			if b.sgIn <= 0.0:
				b.bursting = not b.bursting
				b.sgIn = 0.38 if b.bursting else 1.15 - b.stage * 0.15 + rand() * 0.7
				if b.bursting:
					b.wpIn = 0.0
			vmul = (st.burst if b.bursting else st.crawl) / 60.0
		if b.wp == null or b.wpIn <= 0.0 or hypot(b.wp[0] - b.x, b.wp[1] - b.y) < 6.0:
			var dive := false
			if st.has("lunge") and st.lunge != 0.0:
				dive = rand() < st.lunge * (0.7 + b.stage * 0.3) and b.phaseGrace <= 0.0
			if dive:
				# Lunge down the screen to one side of Joey, then come back up.
				var side := -1.0 if rand() < 0.5 else 1.0
				var wx0 := cl(p.x + side * (70.0 + rand() * 40.0), st.x[0], st.x[1])
				b.wp = [wx0, 168.0 + rand() * 14.0]
				b.wpIn = 0.85
				b.lunging = true
			else:
				b.lunging = false
				var wx: float = st.x[0] + rand() * (st.x[1] - st.x[0])
				if st.has("follow"):
					wx = cl(wx + (p.x - wx) * st.follow, st.x[0], st.x[1])
				b.wp = [wx, st.y[0] + rand() * (st.y[1] - st.y[0])]
				var d: Array = st.get("dwell", [1.0, 1.6])
				b.wpIn = d[0] + rand() * (d[1] - d[0])
				if st.kind == "zigzag":
					b.wp[0] = cl(b.x + (1.0 if b.x < W / 2.0 else -1.0) * (90.0 + rand() * 80.0), st.x[0], st.x[1])
		var dx3: float = b.wp[0] - b.x
		var dy3: float = b.wp[1] - b.y
		var l3: float = hypot(dx3, dy3)
		if l3 == 0.0:
			l3 = 1.0
		var v: float = st.get("v", 60.0) * stage_mul * vmul * (1.5 if b.lunging else 1.0)
		var k := minf(1.0, dt * (8.0 if (st.kind == "zigzag" or b.bursting) else 3.0))
		b.vx += ((dx3 / l3) * v - b.vx) * k
		b.vy += ((dy3 / l3) * v - b.vy) * k
		b.x += b.vx * dt
		b.y += b.vy * dt
	# Sway rides on top of the path: [x amplitude, y amplitude, x speed, y speed].
	var ox: float = st.sway[0] * sin(b.mt * st.sway[2])
	var oy: float = st.sway[1] * sin(b.mt * st.sway[3])
	b.x += ox - b.ox
	b.y += oy - b.oy
	b.ox = ox
	b.oy = oy
	b.x = cl(b.x, 67.0, W - 67.0)
	var min_d: float = (p.y + 28.0) / 2.0
	var ddx: float = b.x - p.x
	if hypot(ddx, b.y - p.y) < min_d:
		b.y = p.y - sqrt(maxf(0.0, min_d * min_d - ddx * ddx))
	b.y = cl(b.y, 111.0 if (b.bossId == "drmantis" and b.stage == 3) else 98.0, 190.0)


func update_boss(dt: float) -> void:
	var b = boss
	if b == null or b.dead:
		return
	var p := player
	var loss: String = boss_def(b.bossId).playerLoss
	b.phaseGrace = maxf(0.0, b.phaseGrace - dt)
	b.age += dt
	b.flash = maxf(0.0, b.flash - dt)
	b.attack -= dt
	var chain_live := false
	for s in shots:
		if s.kind == "chain" and s.life > 0.0:
			chain_live = true
			break
	if not chain_live:
		boss_move(b, dt)
	b.wind = 1 if (b.attack > 0.0 and b.attack <= 0.48) else 0
	# Later forms mix a main pattern with a brief follow-up.
	for shot in b.followUps:
		shot.in -= dt
		if shot.in <= 0.0:
			aimed_shot(b.x, b.y, shot.kind, shot.speed, shot.r)
			emit("bossAttack", {"id": b.bossId})
		else:
			b.wind = 1
	b.followUps = b.followUps.filter(func(shot): return shot.in > 0.0)
	# Debo: the chain lunges through the thrown barrel as it reaches Joey's line.
	if b.chainIn != null:
		b.chainIn -= dt
		if b.chainIn <= 0.0:
			b.chainIn = null
			var any_thrown := false
			for x in barrels:
				if x.get("thrown", false) and not x.dead:
					any_thrown = true
					break
			if any_thrown:
				var dx: float = b.tx - b.x
				var dy: float = b.ty - b.y
				var l: float = hypot(dx, dy)
				if l == 0.0:
					l = 1.0
				shots.append({"kind": "chain", "ox": b.x, "oy": b.y, "x": b.x, "y": b.y, "dx": dx / l, "dy": dy / l, "reach": l, "r": 17.0,
					"age": 0.0, "life": 1.4, "wind": BARREL.chainWind, "ext": BARREL.chainExtend, "hold": 0.18, "ret": 0.32, "color": ""})
	# Dr Mantis form 3: mini Mantises walk down from the top and sides, one shot each.
	if b.bossId == "drmantis" and b.stage == 3 and b.phaseGrace <= 0.0:
		b.miniIn -= dt
		if b.miniIn <= 0.0:
			b.miniIn = 1.2 + rand() * 0.7
			var minis := 0
			for z in enemies:
				if z.type == "mantismini" and not z.dead:
					minis += 1
			if minis < 8:
				var r := rand()
				var side := -1 if r < 0.34 else (1 if r < 0.67 else 0)
				var z2: Dictionary
				if side != 0:
					z2 = spawn("mantismini", -12.0 if side < 0 else W + 12.0, 22.0 + rand() * 90.0, true)
				else:
					z2 = spawn("mantismini", 30.0 + rand() * (W - 60.0), -24.0, true)
				if side != 0:
					z2.vx = -side * 34.0
	# Fat Amy form 3: stop and shake, charge at where Joey stands, then retreat.
	if b.bossId == "fatamy" and b.stage == 3:
		if b.mode == "prep":
			b.modeT -= dt
			b.wind = 1
			if b.modeT <= 0.0:
				b.mode = "shake"
				b.modeT = 1.0
				b.shake = 1
			return
		if b.mode == "shake":
			b.modeT -= dt
			b.wind = 1
			if b.modeT <= 0.0:
				b.mode = "charge"
				b.shake = 0
				b.hx = b.x
				b.hy = b.y
				b.tx = p.x
				b.ty = p.y - 14.0
				b.chargeT = 0.0
				emit("bossAttack", {"id": b.bossId})
			return
		if b.mode == "charge":
			if joey_distance(b.x, b.y) < b.r + 8.0:
				hurt(loss)
			return
		if b.mode == "retreat":
			return
	if b.attack > 0.0:
		return
	b.cycle += 1
	b.attack = 3.0
	# Disco Man's and Fat Amy's throws fly faster.
	var fast := 1.4 if (b.bossId == "discoman" or b.bossId == "fatamy") else 1.0
	var vv: float = (1.1 + (b.stage - 1) * 0.045) * fast
	match b.bossId:
		"jordan":
			_fan(b, "ember", 3 if b.stage > 1 else (2 if b.cycle % 3 == 0 else 1), 0.3, 150.0, 8.0, vv)
			b.attack = 2.3 if b.stage > 1 else 1.7
		"glowinghumanity":
			if b.stage == 1:
				_fan(b, "glowstick", 1, 0.0, 125.0, 11.0, vv)
				var s: Dictionary = shots[shots.size() - 1]
				var k: int
				while true:
					k = int(floor(rand() * GLOW.size()))
					if k != b.lastGlow:
						break
				b.lastGlow = k
				s.color = GLOW[k]
				b.attack = 2.0
			else:
				for side2 in [-1.0, 1.0]:
					shots.append({"x": b.x, "y": b.y, "vx": side2 * 96.0, "vy": 108.0, "kind": "handcuffs", "r": 11.0, "life": 7.0, "age": 0.0, "color": ""})
				b.attack = 3.2
		"debo":
			if b.stage == 1:
				var dx2: float = p.x - b.x
				var dy2: float = p.y - b.y
				var l2: float = hypot(dx2, dy2)
				shots.append({"kind": "chain", "ox": b.x, "oy": b.y, "x": b.x, "y": b.y, "dx": dx2 / l2, "dy": dy2 / l2, "reach": l2 + 22.0, "r": 17.0,
					"age": 0.0, "life": 2.2, "wind": 0.48, "ext": 0.24, "hold": 0.2, "ret": 0.4, "color": ""})
				b.attack = 3.3
			else:
				var flight: float = BARREL.flight
				var tx2 := cl(p.x, 30.0, W - 30.0)
				var ty2: float = p.y - 6.0
				var sy: float = b.y + 20.0
				barrels.append({"id": next_id, "x": b.x, "y": sy, "hp": 1.5, "dead": false, "thrown": true, "small": true, "tx": tx2, "ty": ty2,
					"vx": (tx2 - b.x) / flight, "vy": (ty2 - sy) / flight, "rot": 0.0, "age": 0.0, "T": flight})
				next_id += 1
				b.tx = tx2
				b.ty = ty2
				b.chainIn = flight - float(BARREL.chainWind) - float(BARREL.chainExtend)
				b.attack = 4.1
		"discoman":
			b.recordVolley = not b.recordVolley
			if b.stage == 1:
				_fan(b, "record" if b.recordVolley else "disco", 2, 0.4, 110.0, 12.0, vv)
			else:
				_fan(b, "record" if b.recordVolley else "disco", 3, 0.34, 115.0, 11.0, vv)
			b.attack = 2.9
		"caffeinatedsloth":
			if b.stage == 1:
				_fan(b, "coffee", 1, 0.0, 130.0, 11.0, vv)
				b.attack = 2.1
			else:
				_fan(b, "coffee", 3, 0.3, 135.0, 11.0, vv)
				b.attack = 2.7
		"fatamy":
			if b.stage == 1:
				_fan(b, "missile", 1, 0.0, 120.0, 11.0, vv)
				b.attack = 2.7
			elif b.stage == 2:
				_fan(b, "burger" if rand() < 0.5 else "donut", 1, 0.0, 120.0, 11.0, vv)
				b.attack = 2.1
			else:
				for side3 in [-1.0, 1.0]:
					shots.append({"x": b.x, "y": b.y, "vx": side3 * 98.0 * fast, "vy": 92.0 * fast, "kind": "donut", "r": 11.0, "life": 7.0, "age": 0.0, "color": ""})
				b.mode = "prep"
				b.modeT = 1.3
				b.attack = 99.0
		"drmantis":
			if b.stage == 1:
				_fan(b, "bodypart", 1, 0.0, 125.0, 12.0, vv)
				b.attack = 2.7
			elif b.stage == 2:
				_fan(b, "venom", 2, 0.32, 130.0, 10.0, vv)
				b.attack = 2.5
			else:
				_fan(b, "bodypart", 1, 0.0, 125.0, 12.0, vv)
				_fan(b, "venom", 2, 0.4, 130.0, 10.0, vv)
				b.attack = 3.1
	if b.stage > 1:
		if b.bossId == "jordan" and b.cycle % 2 == 0:
			_follow(b, "ember", 155.0, 8.0, 0.32, vv)
		if b.bossId == "caffeinatedsloth":
			_follow(b, "coffee", 142.0, 11.0, 0.3, vv)
		if b.bossId == "glowinghumanity" and b.cycle % 3 == 0:
			_follow(b, "handcuffs", 125.0, 11.0, 0.38, vv)
		if b.bossId == "fatamy" and b.stage == 2 and b.cycle % 3 == 0:
			var last_kind: String = shots[shots.size() - 1].kind if not shots.is_empty() else ""
			_follow(b, "donut" if last_kind == "burger" else "burger", 132.0, 11.0, 0.34, vv)
		if b.bossId == "drmantis" and b.stage == 3 and b.cycle % 2 == 0:
			_follow(b, "venom", 140.0, 10.0, 0.4, vv)
	if b.attack < 50.0:
		b.attack *= 0.78 - (b.stage - 1) * 0.035
	emit("bossAttack", {"id": b.bossId})


func _fan(b: Dictionary, kind: String, n: int, gap: float, speed: float, r: float, vv: float) -> void:
	for i in range(n):
		aimed_shot(b.x, b.y, kind, speed * vv, r, (i - (n - 1) / 2.0) * gap)


func _follow(b: Dictionary, kind: String, speed: float, r: float, delay: float, vv: float) -> void:
	b.followUps.append({"kind": kind, "speed": speed * vv, "r": r, "in": delay})


func update_shots(dt: float) -> void:
	var p := player
	for s in shots:
		var px: float = s.x
		var py: float = s.y
		s.age += dt
		s.life -= dt
		if s.kind == "chain":
			var ex: float = s.ext if s.ext != 0.0 else 0.45
			var hd: float = s.hold if s.hold != 0.0 else 0.3
			var rt: float = s.ret if s.ret != 0.0 else 0.65
			var q: float
			if s.age < s.wind:
				q = 0.0
			elif s.age < s.wind + ex:
				q = (s.age - s.wind) / ex
			elif s.age < s.wind + ex + hd:
				q = 1.0
			else:
				q = maxf(0.0, 1.0 - (s.age - s.wind - ex - hd) / rt)
			s.x = s.ox + s.dx * s.reach * q
			s.y = s.oy + s.dy * s.reach * q
			if s.age > s.wind + ex + hd + rt:
				s.life = 0.0
		else:
			s.x += s.vx * dt
			s.y += s.vy * dt
			if s.kind in ["donut", "disco", "handcuffs"] and (s.x < s.r or s.x > W - s.r):
				s.vx *= -1.0
				s.x = cl(s.x, s.r, W - s.r)
		if s.kind == "chain" and s.age < s.wind:
			continue
		if joey_hit(px, py, s.x, s.y, s.r * 0.6):
			hurt(boss_def(boss.bossId).playerLoss if boss != null else "Toxic spit caught Joey.")
			if s.kind != "chain":
				s.life = 0.0
	shots = shots.filter(func(s): return s.life > 0.0 and s.y < H + 35.0 and s.x > -60.0 and s.x < W + 60.0)


func kill_boss() -> void:
	var b = boss
	var def := boss_def(b.bossId)
	if b.dead:
		return
	b.dead = true
	kills += 1
	add_points(float(def.points) * multiplier, b.x, b.y)
	bosses_down.append(b.bossId)
	shots = []
	enemies = []
	bullets = []
	grenades = []
	barrels = barrels.filter(func(x): return not x.get("thrown", false))
	burst(b.x, b.y, def.accent, 35, 120.0)
	scene = {"kind": "down", "bossId": b.bossId, "stage": b.stage, "phase": 0, "time": 0.0, "duration": 3.4}
	reset_input()
	emit("bossDown")
	boss = null


func end(reason: String) -> void:
	if over or (scene != null and scene.kind == "loss"):
		return
	var id = null
	if boss != null:
		id = boss.bossId
	danger_source = id
	scene = {"kind": "loss", "bossId": id, "phase": 0, "time": 0.0, "duration": 3.2 if id != null else 1.1, "reason": reason}
	reset_input()
	emit("death")
