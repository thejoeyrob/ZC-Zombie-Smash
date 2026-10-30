extends SceneTree
## Runs the GDScript engine through the same scripted scenarios as quest/tools/golden.mjs and compares every digest.
## Usage: godot --headless --path quest -s tests/trace.gd

const AXES := [-1.0, -0.5, 0.0, 0.5, 1.0, 0.0, 1.0, -1.0]
const SCENARIOS := [
	{"name": "wave-play-seed1", "seed": 1, "ticks": 7200, "invincible": true},
	{"name": "wave-play-seed7", "seed": 7, "ticks": 7200, "invincible": true},
	{"name": "wave-play-seed42-mortal", "seed": 42, "ticks": 6000, "invincible": false},
	{"name": "wave9-dance-floor", "seed": 5, "ticks": 4800, "invincible": true, "jumpWave": 9},
	{"name": "wave13-harvest", "seed": 3, "ticks": 4800, "invincible": true, "jumpWave": 13},
	{"name": "boss-jordan", "seed": 100, "ticks": 5400, "invincible": true, "boss": "jordan"},
	{"name": "boss-glowinghumanity", "seed": 101, "ticks": 5400, "invincible": true, "boss": "glowinghumanity"},
	{"name": "boss-debo", "seed": 102, "ticks": 5400, "invincible": true, "boss": "debo"},
	{"name": "boss-caffeinatedsloth", "seed": 103, "ticks": 5400, "invincible": true, "boss": "caffeinatedsloth"},
	{"name": "boss-discoman", "seed": 104, "ticks": 5400, "invincible": true, "boss": "discoman"},
	{"name": "boss-fatamy", "seed": 105, "ticks": 5400, "invincible": true, "boss": "fatamy"},
	{"name": "boss-drmantis", "seed": 106, "ticks": 5400, "invincible": true, "boss": "drmantis"},
]

var events := {}


func _on_event(type: String, _d: Dictionary) -> void:
	events[type] = int(events.get(type, 0)) + 1


func run_scenario(sc: Dictionary) -> Dictionary:
	events = {}
	var g := ZSEngine.new(sc.seed, Callable(self, "_on_event"))
	g.invincible = sc.invincible
	g.start()
	if sc.has("jumpWave"):
		g.wave = sc.jumpWave
		g.prepare_wave(sc.jumpWave)
	if sc.has("boss"):
		g.skip_boss(sc.boss, 1)
	var digests: Array = []
	for i in range(int(sc.ticks)):
		g.set_input(AXES[(i / 41) % AXES.size()], i % 260 < 215)
		if i % 333 == 150:
			g.throw_grenade()
		if i % 900 == 450 and g.player.inventory.smg > 0.0:
			g.use_stored("smg")
		if sc.has("boss") and g.boss != null and i % 600 == 599:
			g.damage(g.boss, 40.0, "dmr")
		g.step(1.0 / 60.0)
		if i % 30 == 29:
			var ex := 0.0
			var ey := 0.0
			for z in g.enemies:
				ex += z.x
				ey += z.y
			var b = null
			if g.boss != null:
				b = [g.boss.stage, g.boss.hp, g.boss.x, g.boss.y]
			digests.append({
				"i": i, "score": g.score, "kills": g.kills, "wave": g.wave, "breaches": g.breaches, "lives": g.player.lives, "px": g.player.x,
				"gun": g.player.gun, "grenades": g.player.grenades, "enemies": g.enemies.size(), "ex": ex, "ey": ey,
				"bullets": g.bullets.size(), "shots": g.shots.size(), "pickups": g.pickups.size(), "barrels": g.barrels.size(),
				"boss": b, "scene": g.scene.kind if g.scene != null else null,
				"seed": g.seed_value, "nextId": g.next_id, "over": g.over, "special": g.player.special.id if g.player.special != null else null,
			})
	return {"name": sc.name, "events": events.duplicate(), "digests": digests}


func close(a, b) -> bool:
	if a == null or b == null:
		return a == b
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not close(a[i], b[i]):
				return false
		return true
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) <= 1e-6 * maxf(1.0, absf(float(b)))
	return a == b


func _init() -> void:
	var f := FileAccess.open("res://tests/golden.json", FileAccess.READ)
	var golden: Array = JSON.parse_string(f.get_as_text())
	var failures := 0
	for k in range(SCENARIOS.size()):
		var sc: Dictionary = SCENARIOS[k]
		var want: Dictionary = golden[k]
		var got := run_scenario(sc)
		var bad := ""
		for i in range(want.digests.size()):
			var wd: Dictionary = want.digests[i]
			var gd: Dictionary = got.digests[i]
			for key in wd:
				if not close(gd.get(key), wd[key]):
					bad = "tick %d key %s: got %s want %s" % [wd.i, key, str(gd.get(key)), str(wd[key])]
					break
			if bad != "":
				break
		var ev_ok := true
		for key in want.events:
			if int(got.events.get(key, 0)) != int(want.events[key]):
				ev_ok = false
		if bad == "" and ev_ok and got.events.size() == want.events.size():
			print("PASS ", sc.name, " (", got.digests.size(), " digests, score ", got.digests[-1].score, ")")
		else:
			failures += 1
			print("FAIL ", sc.name, " ", bad, " events ", got.events, " want ", want.events)
	print("RESULT: ", "all scenarios match" if failures == 0 else str(failures) + " scenarios differ")
	quit(1 if failures > 0 else 0)
