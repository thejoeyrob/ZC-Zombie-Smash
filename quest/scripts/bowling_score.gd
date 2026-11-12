class_name BowlingScore
extends RefCounted
## Ten-pin scoring. A game is just the list of how many pins each ball knocked down (0-10), in order.

## Where the game stands after these balls: {frame (1-10), ball (1-3), standing (pins to be set for the next ball), done}.
static func state(rolls: Array) -> Dictionary:
	var frame := 1
	var ball := 1
	var standing := 10
	var i := 0
	var first := 0
	var second := 0
	while i < rolls.size():
		var r: int = rolls[i]
		if frame < 10:
			if ball == 1:
				if r == 10:
					frame += 1
					standing = 10
				else:
					ball = 2
					first = r
					standing = 10 - r
			else:
				frame += 1
				ball = 1
				standing = 10
		else:
			if ball == 1:
				first = r
				ball = 2
				standing = 10 if r == 10 else 10 - r
			elif ball == 2:
				second = r
				if first == 10:
					ball = 3
					standing = 10 if r == 10 else 10 - r
				elif first + second == 10:
					ball = 3
					standing = 10
				else:
					return {"frame": 10, "ball": 3, "standing": 10, "done": true}
			else:
				return {"frame": 10, "ball": 3, "standing": 10, "done": true}
		i += 1
	return {"frame": frame, "ball": ball, "standing": standing, "done": frame > 10}


## The ten frames: [{balls: [..], text: "X" / "7/" / "9-", total: running total or -1 while a bonus is still to come}].
static func frames(rolls: Array) -> Array:
	var out: Array = []
	var i := 0
	var running := 0
	for f in range(1, 11):
		if i >= rolls.size():
			break
		var balls: Array = []
		var total := -1
		if f < 10:
			if rolls[i] == 10:
				balls = [10]
				if i + 2 < rolls.size():
					total = 10 + rolls[i + 1] + rolls[i + 2]
				i += 1
			else:
				balls = [rolls[i]]
				if i + 1 < rolls.size():
					balls.append(rolls[i + 1])
					if rolls[i] + rolls[i + 1] == 10:
						if i + 2 < rolls.size():
							total = 10 + rolls[i + 2]
					else:
						total = rolls[i] + rolls[i + 1]
				i += balls.size()
		else:
			while i < rolls.size() and balls.size() < 3:
				balls.append(rolls[i])
				i += 1
			var complete := false
			if balls.size() == 3:
				complete = true
			elif balls.size() == 2 and balls[0] != 10 and balls[0] + balls[1] < 10:
				complete = true
			if complete:
				total = 0
				for b in balls:
					total += int(b)
		if total >= 0 and running >= 0:
			running += total
			out.append({"balls": balls, "text": _text(f, balls), "total": running})
		else:
			running = -1
			out.append({"balls": balls, "text": _text(f, balls), "total": -1})
	return out


static func _text(f: int, balls: Array) -> String:
	var s := ""
	for k in range(balls.size()):
		var b: int = balls[k]
		if b == 10 and (f == 10 or k == 0):
			s += "X"
		elif k > 0 and balls[k - 1] != 10 and balls[k - 1] + b == 10 and not (f == 10 and k == 2 and balls[1] == 10):
			s += "/"
		elif b == 0:
			s += "-"
		else:
			s += str(b)
	return s


static func total(rolls: Array) -> int:
	var fr := frames(rolls)
	var t := 0
	for f in fr:
		if int(f.total) >= 0:
			t = int(f.total)
	return t
