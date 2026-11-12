class_name MiniArcade
extends Control
## Runs one built-in game on the JW EDS machine's screen: a title screen, the game, and a game over screen, in the machine's own 576 x 876 picture.
## The games are our own (see MiniGame). Best scores are kept on the headset.

signal exited

const IDS := ["serpent", "paddle", "brick", "rocks", "aliens"]
const NAMES := {"serpent": "SERPENT", "paddle": "PADDLE BALL", "brick": "BRICK BREAK", "rocks": "ROCK BLASTER", "aliens": "ALIEN WAVE"}
const SAVE_PATH := "user://mini_scores.json"

var game: MiniGame
var game_id := ""
var state := "title"            # title, play, over, paused
var font: Font
var best := {}
var _prev := {}
var _edge := {}
var _st := Vector2.ZERO
var _btn := {}
var _t := 0.0
var _scale := 1.0
var _off := Vector2.ZERO


static func make(id: String) -> MiniGame:
	match id:
		"serpent": return MGSerpent.new()
		"paddle": return MGPaddle.new()
		"brick": return MGBrick.new()
		"rocks": return MGRocks.new()
		"aliens": return MGAliens.new()
	return null


func _init() -> void:
	size = Vector2(576, 876)
	clip_contents = true


func start(id: String, f: Font) -> void:
	font = f
	game_id = id
	game = make(id)
	state = "title"
	_load()
	queue_redraw()


func _load() -> void:
	var fa := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if fa != null:
		var d = JSON.parse_string(fa.get_as_text())
		if d is Dictionary:
			best = d


func _save() -> void:
	var fa := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if fa != null:
		fa.store_string(JSON.stringify(best))


## stick: x right, y down (-1..1); buttons: the machine's a, b, c, d, menu...
func set_input(stick: Vector2, buttons: Dictionary) -> void:
	_edge = {}
	for k in ["a", "b", "c", "d", "start", "menu"]:
		var d: bool = bool(buttons.get(k, false))
		_edge[k] = d and not bool(_prev.get(k, false))
		_prev[k] = d
	_st = stick
	_btn = buttons
	if state == "title" and (_edge.a or _edge.start):
		state = "play"
	elif state == "over" and (_edge.a or _edge.start):
		game = make(game_id)
		state = "play"
	elif state == "play" and _edge.menu:
		state = "paused"
	elif state == "paused":
		if _edge.menu or _edge.a or _edge.start:
			state = "play"
		elif _edge.b:
			exited.emit()


func tick(delta: float) -> void:
	_t += delta
	if state == "play" and game != null:
		game.update(minf(delta, 0.05), _st, _btn, _edge)
		if game.over:
			state = "over"
			if game.score > int(best.get(game_id, 0)):
				best[game_id] = game.score
				_save()
	queue_redraw()


func _draw() -> void:
	if game == null or font == null:
		return
	_scale = minf(size.x / MiniGame.W, size.y / MiniGame.H)
	_off = Vector2((size.x - MiniGame.W * _scale) / 2.0, (size.y - MiniGame.H * _scale) / 2.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0))
	draw_set_transform(_off, 0.0, Vector2(_scale, _scale))
	# the score bar
	draw_rect(Rect2(0, 0, MiniGame.W, MiniGame.TOP), Color(0.05, 0.08, 0.06))
	draw_string(font, Vector2(8, 26), "SCORE %05d" % game.score, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, game.tint)
	if game.lives > 0:
		draw_string(font, Vector2(150, 26), "LIVES %d" % game.lives, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.8, 0.4))
	draw_string(font, Vector2(0, 26), "BEST %d" % int(best.get(game_id, 0)), HORIZONTAL_ALIGNMENT_RIGHT, MiniGame.W - 8, 14, Color(0.6, 0.7, 0.65))
	game.draw(self, font)
	if state == "title":
		_panel(game.title, game.blurb, "PRESS A TO START")
	elif state == "over":
		_panel("YOU WIN!" if game.won else "GAME OVER", "SCORE %d\nBEST %d" % [game.score, int(best.get(game_id, 0))], "A = AGAIN    MENU = LEAVE")
	elif state == "paused":
		_panel("PAUSED", "", "MENU / A = CONTINUE\nB = LEAVE THE GAME")
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _panel(head: String, body: String, foot: String) -> void:
	draw_rect(Rect2(20, 150, MiniGame.W - 40, 250), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(20, 150, MiniGame.W - 40, 250), game.tint, false, 2.0)
	draw_string(font, Vector2(20, 200), head, HORIZONTAL_ALIGNMENT_CENTER, MiniGame.W - 40, 34, game.tint)
	var y := 240.0
	for line in body.split("\n"):
		draw_string(font, Vector2(20, y), line, HORIZONTAL_ALIGNMENT_CENTER, MiniGame.W - 40, 18, Color(0.85, 0.9, 0.85))
		y += 26.0
	var blink := 0.6 + 0.4 * sin(_t * 5.0)
	y = 345.0
	for line in foot.split("\n"):
		draw_string(font, Vector2(20, y), line, HORIZONTAL_ALIGNMENT_CENTER, MiniGame.W - 40, 17, Color(1, 0.85, 0.4, blink))
		y += 22.0
