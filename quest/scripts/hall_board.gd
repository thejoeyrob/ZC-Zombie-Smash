class_name HallBoard
extends Node3D
## The high-score wall: the shared league table on the left (one row per player, highest score), and on the right
## a separate section with this player's last run and badges. Drawn with ordinary UI into a SubViewport.

const ENDPOINT := "https://xdsrnnkuxfaycnlngjbq.supabase.co/rest/v1/rpc/zs7_leaderboard"
const API_KEY := "sb_publishable_AicVoQAwV-KnlOs1Fc2RuQ_T81In0MC"   # the public read key the phone game ships with
const CHEAT_MARK := ".cht"
const CACHE := "user://league.json"
const VIEW := Vector2i(1800, 1000)
const SIZE := Vector2(2.7, 1.5)

var viewport: SubViewport
var font: Font
var rows: Array = []
var online := false
var status := "Loading the league..."
var progress: VRProgress
var _http: HTTPRequest
var _dirty := true


func build(root: Node3D, ui_font: Font, prog: VRProgress, pos: Vector3, yaw: float) -> void:
	font = ui_font
	progress = prog
	position = pos
	rotation.y = yaw
	root.add_child(self)
	viewport = SubViewport.new()
	viewport.size = VIEW
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	# frame and screen
	VRBuild.box(self, Vector3(SIZE.x + 0.18, SIZE.y + 0.18, 0.06), Vector3(0, 0, -0.04), VRBuild.mat(Color(0.05, 0.04, 0.08), 0.5, 0.4))
	VRBuild.box(self, Vector3(SIZE.x + 0.24, 0.035, 0.07), Vector3(0, (SIZE.y + 0.18) / 2.0, -0.035), VRBuild.mat(Color(1.0, 0.8, 0.2), 0.3, 0.0, 1.6))
	VRBuild.box(self, Vector3(SIZE.x + 0.24, 0.035, 0.07), Vector3(0, -(SIZE.y + 0.18) / 2.0, -0.035), VRBuild.mat(Color(1.0, 0.8, 0.2), 0.3, 0.0, 1.6))
	var m := StandardMaterial3D.new()
	m.albedo_texture = viewport.get_texture()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	VRBuild.quad(self, SIZE, Vector3(0, 0, -0.005), m)
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_response)
	_load_cache()
	_draw()
	refresh_online()


func refresh_online() -> void:
	status = "Contacting the league..."
	_dirty = true
	var err := _http.request(ENDPOINT, ["Content-Type: application/json", "apikey: " + API_KEY], HTTPClient.METHOD_POST, "{}")
	if err != OK:
		status = "Offline: showing the saved league"


func _on_response(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var d = JSON.parse_string(body.get_string_from_utf8())
		if d is Array:
			rows = d
			online = true
			status = "Live league: every player on the phone game"
			var f := FileAccess.open(CACHE, FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify(rows))
	else:
		status = "Offline: showing the saved league"
	_draw()


func _load_cache() -> void:
	if FileAccess.file_exists(CACHE):
		var d = JSON.parse_string(FileAccess.open(CACHE, FileAccess.READ).get_as_text())
		if d is Array:
			rows = d


func _label(parent: Control, text: String, size: int, color: Color, pos: Vector2, width := 0.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.position = pos
	if width > 0.0:
		l.size = Vector2(width, size * 1.3)
		l.horizontal_alignment = align
	parent.add_child(l)


func _rect(parent: Control, r: Rect2, color: Color) -> void:
	var c := ColorRect.new()
	c.position = r.position
	c.size = r.size
	c.color = color
	parent.add_child(c)


func _picture(parent: Control, tex: Texture2D, r: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture = tex
	t.position = r.position
	t.size = r.size
	parent.add_child(t)
	return t


func refresh() -> void:
	_draw()


func _draw() -> void:
	for c in viewport.get_children():
		c.queue_free()
	var root := Control.new()
	root.size = Vector2(VIEW)
	viewport.add_child(root)
	_rect(root, Rect2(Vector2.ZERO, Vector2(VIEW)), Color(0.03, 0.02, 0.08))
	_rect(root, Rect2(0, 0, VIEW.x, 6), Color(0.2, 0.9, 1.0))
	var hh = load("res://assets/art/hall-header.jpg")
	if hh != null:
		_picture(root, hh, Rect2((VIEW.x * 0.64 - 920.0) / 2.0, 6, 920, 230))
	else:
		_label(root, "HALL OF FAME", 112, Color(1.0, 0.82, 0.25), Vector2(0, 14), VIEW.x * 0.64, HORIZONTAL_ALIGNMENT_CENTER)
	_label(root, status, 30, Color(0.6, 0.7, 0.9) if online else Color(1.0, 0.7, 0.4), Vector2(0, 238), VIEW.x * 0.64, HORIZONTAL_ALIGNMENT_CENTER)
	# league table: one row per player
	var shown: Array = []
	for r in rows:
		var n := String(r.get("username", r.get("name", r.get("gamertag", ""))))
		if n.to_lower().ends_with(CHEAT_MARK):
			continue
		shown.append([n, int(float(r.get("score", r.get("high_score", 0))))])
	shown.sort_custom(func(a, b): return a[1] > b[1])
	var seen := {}
	var top: Array = []
	for e in shown:
		var k: String = e[0].to_lower()
		if seen.has(k):
			continue
		seen[k] = true
		top.append(e)
	var y := 285.0
	for i in range(mini(9, top.size())):
		var gold := i < 3
		var col: Color = [Color(1.0, 0.85, 0.2), Color(0.85, 0.88, 0.95), Color(0.95, 0.6, 0.3)][i] if gold else Color(0.8, 0.88, 1.0)
		_rect(root, Rect2(50, y, VIEW.x * 0.64 - 100, 68), Color(1, 1, 1, 0.07 if i % 2 == 0 else 0.03))
		_label(root, "%d" % (i + 1), 52, col, Vector2(70, y + 4), 90, HORIZONTAL_ALIGNMENT_CENTER)
		_label(root, top[i][0], 52, col, Vector2(190, y + 4))
		_label(root, ZSEngine.commas(top[i][1]), 52, col, Vector2(0, y + 4), VIEW.x * 0.64 - 80, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 74.0
	if top.is_empty():
		_label(root, "No scores yet. Be the first!", 54, Color(0.7, 0.8, 1.0), Vector2(0, 520), VIEW.x * 0.64, HORIZONTAL_ALIGNMENT_CENTER)
	# the player's own section
	var x0 := VIEW.x * 0.66
	_rect(root, Rect2(x0 - 24, 30, 6, VIEW.y - 60), Color(0.2, 0.9, 1.0, 0.6))
	var w := VIEW.x - x0 - 40.0
	var rh = load("res://assets/art/record-header.jpg")
	if rh != null:
		_picture(root, rh, Rect2(x0, 12, w, w / 4.0))
	else:
		_label(root, "YOUR RECORD", 76, Color(0.4, 1.0, 0.7), Vector2(x0, 24), w, HORIZONTAL_ALIGNMENT_CENTER)
	var last: Dictionary = progress.last
	if last.is_empty():
		_label(root, "Play a game and your\nlast run shows here.", 40, Color(0.8, 0.88, 1.0), Vector2(x0, 190), w, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_label(root, "LAST RUN", 34, Color(0.6, 0.7, 0.9), Vector2(x0, 168), w, HORIZONTAL_ALIGNMENT_CENTER)
		_label(root, ZSEngine.commas(int(last.score)), 90, Color.WHITE, Vector2(x0, 198), w, HORIZONTAL_ALIGNMENT_CENTER)
		_label(root, "Wave %d   Kills %d   Bosses %d" % [int(last.wave), int(last.kills), int(last.bosses)], 34, Color(0.8, 0.88, 1.0), Vector2(x0, 308), w, HORIZONTAL_ALIGNMENT_CENTER)
	_label(root, "YOUR BEST", 34, Color(0.6, 0.7, 0.9), Vector2(x0, 372), w, HORIZONTAL_ALIGNMENT_CENTER)
	_label(root, ZSEngine.commas(progress.best), 64, Color(1.0, 0.82, 0.25), Vector2(x0, 404), w, HORIZONTAL_ALIGNMENT_CENTER)
	_label(root, "BADGES  %d / %d" % [progress.badges.size(), VRProgress.BADGES.size()], 40, Color(0.4, 1.0, 0.7), Vector2(x0, 500), w, HORIZONTAL_ALIGNMENT_CENTER)
	var size := 124.0
	var gap := (w - 4.0 * size) / 3.0
	for i in range(VRProgress.BADGES.size()):
		var got: bool = progress.badges.has(VRProgress.BADGES[i][0])
		var icon = load("res://assets/art/badge-%d.png" % (i + 1))
		var pos := Vector2(x0 + (i % 4) * (size + gap), 560.0 + (i / 4) * (size + 70.0))
		if icon != null:
			var tr := _picture(root, icon, Rect2(pos, Vector2(size, size)))
			tr.modulate = Color(1, 1, 1, 1) if got else Color(0.18, 0.18, 0.22, 0.85)
		_label(root, VRProgress.BADGES[i][1], 22, Color(1.0, 0.9, 0.5) if got else Color(0.5, 0.55, 0.7), Vector2(pos.x - gap / 2.0, pos.y + size + 2.0), size + gap, HORIZONTAL_ALIGNMENT_CENTER)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
