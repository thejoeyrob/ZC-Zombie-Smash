extends SceneTree
## Plays TRUCKIN' & DRIVIN' with a simple bot for several seeds: no crash in the code, the road always has a way through, scores and events appear.
func _initialize() -> void:
	var fails := 0
	var kinds := {}
	for seed_i in range(1, 7):
		var g := TTGame.new(seed_i * 977)
		var t := 0.0
		while not g.finished and t < 600.0:
			# bot: look ahead for the nearest hazard in my lane, move to a safe neighbour; honk when the sheep bleat; take pickups when free
			var want := g.lane
			var danger := false
			for e in g.items:
				if bool(e.done) or TTGame.PICKUPS.has(str(e.type)):
					continue
				var d: float = float(e.z) - g.distance
				if d > -40.0 and d < 330.0 and (int(e.lane) == g.lane or absf(float(e.lane) - g.x) < 0.7):
					danger = true
			if danger:
				for cand in [g.lane - 1, g.lane + 1, g.lane - 2, g.lane + 2]:
					if cand < 0 or cand > 4:
						continue
					var ok := true
					for e in g.items:
						if bool(e.done) or TTGame.PICKUPS.has(str(e.type)):
							continue
						var d: float = float(e.z) - g.distance
						if d > -80.0 and d < 330.0 and int(e.lane) == cand:
							ok = false
					if ok:
						want = cand
						break
			else:
				for e in g.items:
					if (e.type == "crumb" or e.type == "coin" or e.type == "job" or e.type == "finish") and not bool(e.done):
						var d2: float = float(e.z) - g.distance
						if d2 > 0.0 and d2 < 400.0:
							want = int(e.lane)
							break
			g.set_lane(want)
			if not g.sheep.is_empty() and bool(g.sheep.baa) and not bool(g.sheep.cleared) and g.time - float(g.sheep.baa_at) > 0.15:
				g.horn()
			g.tick(1.0 / 60.0)
			t += 1.0 / 60.0
			for ev in g.events:
				kinds[ev.type] = int(kinds.get(ev.type, 0)) + 1
			g.events.clear()
		print("seed %d: %.0fs, %.0f m, earned %.0f, jobs %d, finished=%s (%s)" % [seed_i, t, g.distance, g.earned, g.jobs, g.finished, g.end_reason])
		if g.distance < 1500.0:
			fails += 1
	print("events seen: ", kinds)
	print("TT GAME ", "PASS" if fails == 0 else "FAIL")
	quit(fails)
