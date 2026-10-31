class_name VRProgress
extends RefCounted
## What this headset's player has achieved: bosses beaten (unlocks the bobble heads), best and last run, badges.

const PATH := "user://progress.json"
const BADGES := [
	["first_boss", "First boss down", "Beat any boss"],
	["all_bosses", "Boss slayer", "Beat all seven bosses in one run"],
	["score_10k", "10,000 club", "Score 10,000"],
	["score_100k", "100,000 club", "Score 100,000"],
	["grenadier", "Grenade master", "Throw 10 grenades in one run"],
	["clean_wave", "Untouchable", "Clear a wave without a scratch"],
	["wave_10", "Survivor", "Reach wave 10"],
	["record", "High-score hero", "Set a new personal best"],
]

var bosses_beaten := 0           # every boss defeat, ever; each one unlocks the next bobble head
var best := 0
var last := {}                   # {score, wave, kills, bosses, seconds}
var badges: Array = []
var runs := 0


func load_all() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		bosses_beaten = int(d.get("bosses_beaten", 0))
		best = int(d.get("best", 0))
		last = d.get("last", {})
		badges = d.get("badges", [])
		runs = int(d.get("runs", 0))


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"bosses_beaten": bosses_beaten, "best": best, "last": last, "badges": badges, "runs": runs}))


## How many bobble heads are unlocked (they open in stage order).
func unlocked() -> int:
	return mini(bosses_beaten, ZSEngine.BOSSES.size())


## Records a finished run; returns the badges earned for the first time.
func record_run(score: int, wave: int, kills: int, bosses: int, grenades: int, clean_wave: bool, seconds: float) -> Array:
	runs += 1
	var fresh: Array = []
	bosses_beaten += bosses
	var new_best := score > best
	if new_best:
		best = score
	last = {"score": score, "wave": wave, "kills": kills, "bosses": bosses, "seconds": int(seconds)}
	var earned := {
		"first_boss": bosses >= 1,
		"all_bosses": bosses >= ZSEngine.BOSSES.size(),
		"score_10k": score >= 10000,
		"score_100k": score >= 100000,
		"grenadier": grenades >= 10,
		"clean_wave": clean_wave,
		"wave_10": wave >= 10,
		"record": new_best and runs > 1,
	}
	for k in earned:
		if earned[k] and not badges.has(k):
			badges.append(k)
			fresh.append(k)
	save()
	return fresh
