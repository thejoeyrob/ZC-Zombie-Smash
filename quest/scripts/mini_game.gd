class_name MiniGame
extends RefCounted
## One of the built-in games on the JW EDS machine. These are our own: simple, classic arcade ideas written from scratch with our own drawings and no
## names or artwork from anybody else's games, so they work with or without the emulator. A game draws itself in a 360 x 548 portrait field.

const W := 360.0
const H := 548.0
const TOP := 40.0                       # the score bar across the top

var title := ""
var blurb := ""                         # the controls, shown on the title screen
var score := 0
var lives := 3
var over := false
var won := false
var tint := Color(0.4, 1.0, 0.5)
var t := 0.0
var rng := RandomNumberGenerator.new()


## st: the stick (x right, y down, -1..1). btn: what is held (a, b, c, d). edge: what was pressed this frame.
func update(_dt: float, _st: Vector2, _btn: Dictionary, _edge: Dictionary) -> void:
	pass


func draw(_ci: CanvasItem, _font: Font) -> void:
	pass


func text(ci: CanvasItem, font: Font, s: String, at: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	ci.draw_string(font, at, s, align, width, size, col)


func glow_rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(r, col)
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), col.lightened(0.35), false, 1.0)
