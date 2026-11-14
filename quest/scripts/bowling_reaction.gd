class_name BowlingReaction
extends Node3D
## The comic-book screen above each lane. After every ball it plays a short animated panel in the style of the game's comic scenes:
## a full-size comic picture that punches in and shakes, a spinning ray fan, a starburst that pops with the result, a sound-effect word
## and flying stars. It holds the last frame until the next ball. No continuous offscreen rendering while idle: the picture is only
## redrawn (about 30 times a second) for the 2.4 seconds the animation runs.

const W := 768
const H := 432
const RUN := 2.4

## file, how far down the (portrait) picture the 16:9 crop sits (0 top, 1 bottom), burst colour, ray colour
const SCENES := {
	"strike": ["battle-discoman.jpg", 0.32, Color(1.0, 0.86, 0.12), Color(1.0, 0.25, 0.75)],
	"spare": ["battle-jordan.jpg", 0.45, Color(1.0, 0.62, 0.15), Color(1.0, 0.85, 0.3)],
	"pins": ["battle-debo.jpg", 0.42, Color(1.0, 0.8, 0.2), Color(0.3, 0.8, 1.0)],
	"miss": ["battle-caffeinatedsloth.jpg", 0.36, Color(0.55, 0.95, 0.35), Color(0.4, 0.9, 0.5)],
	"idle": ["battle-glowinghumanity.jpg", 0.48, Color(0.4, 0.9, 1.0), Color(0.4, 0.9, 1.0)],
}


## Rotating fan of light rays behind the burst.
class RayFan extends Control:
	var angle := 0.0
	var color := Color(1, 1, 1, 0.2)

	func _draw() -> void:
		var c: Vector2 = size / 2.0
		var n := 18
		for k in range(n):
			var a0: float = angle + TAU * float(k) / float(n)
			var a1: float = a0 + TAU / float(n) * 0.5
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 900.0, c + Vector2(cos(a1), sin(a1)) * 900.0]), color)


## A comic starburst: black outline, flat colour, lighter inner shine.
class Burst extends Control:
	var fill := Color(1.0, 0.86, 0.12)
	var spikes := 16

	func _points(scale_by: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var c: Vector2 = size / 2.0
		for k in range(spikes * 2):
			var a: float = TAU * float(k) / float(spikes * 2) - PI / 2.0
			var r: float = 1.0 if k % 2 == 0 else 0.68
			if k % 4 == 0:
				r *= 0.93
			pts.append(c + Vector2(cos(a) * size.x * 0.5 * r, sin(a) * size.y * 0.5 * r) * scale_by)
		return pts

	func _draw() -> void:
		draw_colored_polygon(_points(1.0), Color(0.04, 0.02, 0.08))
		draw_colored_polygon(_points(0.94), fill)
		draw_colored_polygon(_points(0.78), fill.lerp(Color.WHITE, 0.45))
		draw_colored_polygon(_points(0.70), fill)


var viewport: SubViewport
var stage: Control            # clips everything to the screen
var picture: TextureRect
var shade: ColorRect
var rays: RayFan
var burst: Burst
var burst_text: Label
var sfx: Label                # the sound-effect word
var strip: ColorRect          # the result line along the bottom
var strip_text: Label
var title: Label
var stars: Array[Burst] = []
var time := 99.0
var kind := "idle"
var font_ref: Font
var lane_no := 1
var scene_cache: Dictionary = {}


func build(parent: Node3D, at: Vector3, font: Font, lane: int) -> void:
	parent.add_child(self)
	position = at
	rotation.y = PI
	font_ref = font
	lane_no = lane + 1
	viewport = SubViewport.new()
	viewport.size = Vector2i(W, H)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	stage = Control.new()
	stage.size = Vector2(W, H)
	stage.clip_contents = true
	viewport.add_child(stage)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.size = Vector2(W, H)
	picture.pivot_offset = Vector2(W, H) / 2.0
	stage.add_child(picture)
	shade = ColorRect.new()
	shade.size = Vector2(W, H)
	shade.color = Color(0, 0, 0, 0.0)
	stage.add_child(shade)
	rays = RayFan.new()
	rays.size = Vector2(W, H)
	stage.add_child(rays)
	for k in range(7):
		var st := Burst.new()
		st.size = Vector2(64, 64)
		st.pivot_offset = Vector2(32, 32)
		st.spikes = 5
		st.visible = false
		stage.add_child(st)
		stars.append(st)
	burst = Burst.new()
	burst.size = Vector2(500, 330)
	burst.position = Vector2(W - 500 - 28, 24)
	burst.pivot_offset = burst.size / 2.0
	stage.add_child(burst)
	burst_text = _label(96, Color(0.98, 0.1, 0.18), 16)
	burst_text.size = burst.size
	burst_text.position = Vector2.ZERO
	burst_text.pivot_offset = burst.size / 2.0
	burst_text.rotation = -0.07
	burst.add_child(burst_text)
	sfx = _label(58, Color(1.0, 0.95, 0.25), 12)
	sfx.position = Vector2(18, 18)
	sfx.size = Vector2(330, 80)
	sfx.pivot_offset = Vector2(60, 40)
	sfx.rotation = -0.13
	stage.add_child(sfx)
	strip = ColorRect.new()
	strip.position = Vector2(0, H - 62)
	strip.size = Vector2(W, 62)
	strip.color = Color(0.03, 0.01, 0.08, 0.86)
	stage.add_child(strip)
	strip_text = _label(30, Color(1, 1, 1), 6)
	strip_text.position = Vector2(18, 8)
	strip_text.size = Vector2(W - 36, 48)
	strip_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	strip.add_child(strip_text)
	title = _label(66, Color(1.0, 0.86, 0.2), 14)
	title.position = Vector2(20, 14)
	title.size = Vector2(520, 160)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title.rotation = -0.05
	stage.add_child(title)
	VRBuild.box(self, Vector3(1.50, 0.87, 0.065), Vector3(0, 0, -0.04), VRBuild.pbr("metal", Color(0.22, 0.25, 0.28), Vector2.ONE, 0.2, 0.65))
	VRBuild.quad(self, Vector2(1.44, 0.81), Vector3.ZERO, VRBuild.tex_mat(viewport.get_texture(), 0, 0.9, true))
	set_process(false)
	show_idle()


func _label(size_px: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	if font_ref != null:
		l.add_theme_font_override("font", font_ref)
	return l


## The picture for a kind of result, cropped to the screen's 16:9 from the portrait comic scene.
func _scene(key: String) -> Texture2D:
	if scene_cache.has(key):
		return scene_cache[key]
	var info: Array = SCENES[key]
	var tex := load("res://assets/art/" + str(info[0])) as Texture2D
	var out: Texture2D = tex
	if tex != null:
		var sz: Vector2 = tex.get_size()
		var h: float = sz.x * float(H) / float(W)
		if h < sz.y:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(0, (sz.y - h) * float(info[1]), sz.x, h)
			out = at
	scene_cache[key] = out
	return out


func _redraw() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Waiting for the first ball.
func show_idle() -> void:
	kind = "idle"
	time = 99.0
	picture.texture = _scene("idle")
	picture.scale = Vector2.ONE
	picture.position = Vector2.ZERO
	shade.color = Color(0.02, 0.0, 0.08, 0.35)
	rays.visible = false
	burst.visible = false
	sfx.visible = false
	for st in stars:
		st.visible = false
	title.visible = true
	title.text = "STRIKERS\nLANE %d" % lane_no
	strip_text.text = "PICK UP A BALL TO BEGIN"
	strip_text.add_theme_color_override("font_color", Color(0.5, 0.95, 1.0))
	_redraw()


func react(result: String, pins: int, player: int) -> void:
	var word := result
	var effect := "CRASH!"
	var tail := "NEXT SHOT IS YOURS"
	if result == "STRIKE!":
		kind = "strike"
		effect = "KA-POW!"
		tail = "THE SHACK GOES WILD"
	elif result == "SPARE!":
		kind = "spare"
		effect = "WHAM!"
		tail = "CLEANED UP!"
	elif result == "GUTTER BALL" or result == "MISSED":
		kind = "miss"
		word = "GUTTER!" if result == "GUTTER BALL" else "MISSED!"
		effect = "THUD..."
		tail = "TRY AGAIN"
	else:
		kind = "pins"
		word = result + "!"
		effect = "CRASH!" if pins >= 6 else "CLACK!" if pins >= 3 else "TINK!"
		tail = "KEEP GOING"
	var info: Array = SCENES[kind]
	picture.texture = _scene(kind)
	title.visible = false
	rays.visible = true
	rays.color = Color(info[3].r, info[3].g, info[3].b, 0.0)
	burst.visible = true
	burst.fill = info[2]
	burst.queue_redraw()
	burst_text.text = word
	burst_text.add_theme_font_size_override("font_size", 88 if word.length() <= 7 else 72 if word.length() <= 9 else 56)
	burst_text.add_theme_color_override("font_color", Color(0.95, 0.08, 0.16) if kind != "miss" else Color(0.1, 0.35, 0.08))
	sfx.visible = true
	sfx.text = effect
	strip_text.text = "P%d  •  %d PIN%s  •  %s" % [player + 1, pins, "" if pins == 1 else "S", tail]
	strip_text.add_theme_color_override("font_color", info[2])
	for st in stars:
		st.fill = info[2].lerp(Color.WHITE, 0.2)
		st.queue_redraw()
		st.visible = kind == "strike" or kind == "spare"
	time = 0.0
	_animate(0.0)
	set_process(true)


func _pop(t: float) -> float:
	# overshoot, then settle: 0 -> 1.18 -> 1.0
	if t >= 1.0:
		return 1.0
	var c1 := 1.9
	var c3 := c1 + 1.0
	var u := t - 1.0
	return 1.0 + c3 * u * u * u + c1 * u * u


func _animate(t: float) -> void:
	var settle: float = clampf(t / RUN, 0.0, 1.0)
	# the picture punches in, then drifts slowly; it shakes hard for the first half second
	var shake: float = maxf(0.0, 1.0 - t / 0.5) * (14.0 if kind == "strike" else 8.0)
	picture.scale = Vector2.ONE * (1.22 - 0.12 * minf(1.0, t / 0.35) + 0.05 * settle)
	picture.position = Vector2(sin(t * 95.0), cos(t * 83.0)) * shake
	shade.color = Color(0.02, 0.0, 0.08, 0.22 + 0.12 * settle)
	rays.angle = t * 0.9
	rays.color.a = minf(1.0, t / 0.25) * 0.30
	rays.queue_redraw()
	var p: float = _pop(minf(1.0, t / 0.4))
	burst.scale = Vector2.ONE * p * (1.0 + 0.025 * sin(t * 9.0) * (1.0 - settle))
	burst.rotation = -0.05 + 0.03 * sin(t * 5.0) * (1.0 - settle)
	sfx.scale = Vector2.ONE * _pop(clampf((t - 0.12) / 0.35, 0.0, 1.0))
	for k in range(stars.size()):
		var st: Burst = stars[k]
		var a: float = TAU * float(k) / float(stars.size()) + 0.4
		var d: float = (60.0 + 260.0 * (1.0 - pow(1.0 - clampf(t / 1.1, 0.0, 1.0), 2.0)))
		var cx: float = burst.position.x + burst.size.x * 0.5
		var cy: float = burst.position.y + burst.size.y * 0.5
		st.position = Vector2(cx + cos(a) * d * 1.3, cy + sin(a) * d * 0.8) - st.size / 2.0
		st.rotation = t * 3.0 + float(k)
		var fade: float = clampf(1.6 - t, 0.0, 1.0)
		st.scale = Vector2.ONE * (0.4 + 0.9 * fade)
		st.modulate.a = fade
	_redraw()


func _process(delta: float) -> void:
	var before := time
	time += delta
	# capped at about 30 redraws a second; stops after RUN seconds and holds the last frame
	if int(time * 30.0) != int(before * 30.0):
		_animate(minf(time, RUN))
	if time >= RUN:
		_animate(RUN)
		set_process(false)
