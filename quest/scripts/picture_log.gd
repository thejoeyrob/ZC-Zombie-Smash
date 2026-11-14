class_name PictureLog
extends Node
## A running report of what the picture is doing, written to the log (adb logcat, tag godot) while the game runs: once a second a PERF line (frame rate,
## time per frame, the size drawn per eye, edge detail, refresh rate, GPU and CPU time, draw calls), a line for every change (eye size, refresh rate, edge
## detail, headset overrides such as Quest Games Optimiser settings, the headset focusing or losing the game), and a MARK line when you press
## A+X together (picture looks GOOD) or B+Y together (picture looks BAD). Tools/watch-picture.sh collects it all with the time of day.

var iface: XRInterface
var vp: Viewport
var _t := 0.0
var _frames := 0
var _worst := 0.0
var _last_eye := ""
var _last_hz := -1.0
var _last_fov := ""
var _thread: Thread
var _props: Dictionary = {}
var _have_props := false
var _prop_t := 2.0
var _held_good := 0.0
var _held_bad := 0.0
var _marked_good := false
var _marked_bad := false
var _last_line := ""
var _up := 0.0
var hud_lines: Array = []            # the last few changes, shown on the in-game readout
var _file: FileAccess
var _held_click := 0.0
var _clicked := false


## One line of the report: printed to the log, kept in a file in the game's own folder, and remembered for the on-screen readout.
func _emit(msg: String, to_hud := true) -> void:
	print(msg)
	if _file != null:
		_file.store_line("%s  %s" % [Time.get_datetime_string_from_system(false, true), msg])
		_file.flush()
	if to_hud:
		hud_lines.append("%d  %s" % [int(_up), msg.substr(0, 90)])
		while hud_lines.size() > 7:
			hud_lines.pop_front()


## What a headset tool (Quest Games Optimiser and the like) is forcing on every app, in plain words; empty when nothing is.
func overrides_warning() -> String:
	var out: Array = []
	var fl: String = str(_props.get("debug.oculus.foveation.level", ""))
	if fl != "" and fl != "0":
		out.append("edge blur (FFR) level %s" % fl)
	var tw: String = str(_props.get("debug.oculus.textureWidth", ""))
	var th: String = str(_props.get("debug.oculus.textureHeight", ""))
	if tw != "" or th != "":
		out.append("eye size %sx%s" % [tw, th])
	var rr: String = str(_props.get("debug.oculus.refreshRate", ""))
	if rr != "":
		out.append("refresh %s Hz" % rr)
	var gl: String = str(_props.get("debug.oculus.gpuLevel", ""))
	var cl: String = str(_props.get("debug.oculus.cpuLevel", ""))
	if gl != "" or cl != "":
		out.append("cpu/gpu level %s/%s" % [cl, gl])
	return "" if out.is_empty() else "FORCED BY A HEADSET TOOL: " + ", ".join(out)


## Text for the on-screen readout (hold both thumbstick clicks to show or hide it): the current numbers and the last few changes.
func hud_text() -> String:
	var sz: String = _eye()
	var head := "%d fps  %s  x%s  %dHz  gpu %.1fms  %s" % [int(round(Engine.get_frames_per_second())), sz, str(_prop("render_target_size_multiplier", "?")), int(float(_prop("display_refresh_rate", 0.0))), RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid()), _last_fov]
	var warn := overrides_warning()
	return head + ("\n" + warn if warn != "" else "") + "\n" + "\n".join(hud_lines) + "\nreport file: " + ProjectSettings.globalize_path("user://picture-report.txt")


## Both thumbstick clicks held for about half a second: returns true once, to switch the readout on or off.
func readout_toggle(hs: Array, delta: float) -> bool:
	var both: bool = bool(hs[0].get("click", false)) and bool(hs[1].get("click", false))
	_held_click = _held_click + delta if both else 0.0
	if not both:
		_clicked = false
	if _held_click > 0.6 and not _clicked:
		_clicked = true
		return true
	return false


func setup(xr_iface: XRInterface, viewport: Viewport) -> void:
	_file = FileAccess.open("user://picture-report.txt", FileAccess.WRITE_READ)
	if _file != null:
		_file.seek_end()
	iface = xr_iface
	vp = viewport
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	for s in ["session_begun", "session_stopping", "session_focussed", "session_visible", "pose_recentered"]:
		if iface.has_signal(s):
			iface.connect(s, func(): _event(s))
	if iface.has_signal("refresh_rate_changed"):
		iface.connect("refresh_rate_changed", func(r): _event("refresh_rate_changed " + str(r)))
	_emit("PICTURELOG started  window %s  screen %s  file %s" % [str(DisplayServer.window_get_size()), str(DisplayServer.screen_get_size()), ProjectSettings.globalize_path("user://picture-report.txt")])
	_snapshot("start")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_event("app_focus_in")
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_event("app_focus_out")
		NOTIFICATION_APPLICATION_PAUSED:
			_event("app_paused")
		NOTIFICATION_APPLICATION_RESUMED:
			_event("app_resumed")


func _event(name: String) -> void:
	_emit("EVENT %s up=%.1f" % [name, _up])
	_snapshot("after event")


func _eye() -> String:
	var sz: Vector2 = iface.get_render_target_size() if iface != null else Vector2.ZERO
	return "%dx%d" % [int(sz.x), int(sz.y)]


func _prop(prop: String, fallback = null):
	return iface.get(prop) if iface != null and prop in iface else fallback


func _snapshot(why: String) -> void:
	_emit("STATE (%s) eye=%s mult=%s foveation=%s/%s vrs=%s refresh=%s msaa=%s" % [why, _eye(), str(_prop("render_target_size_multiplier", "?")), str(_prop("foveation_level", "n/a")), str(_prop("foveation_dynamic", "n/a")), str(vp.vrs_mode), str(_prop("display_refresh_rate", "?")), str(vp.msaa_3d)])


## Call every frame. `where` says which part of the world you are in (shown in each line).
func tick(delta: float, where: String) -> void:
	_up += delta
	_t += delta
	_frames += 1
	_worst = maxf(_worst, delta)
	_poll_props(delta)
	if _t < 1.0:
		return
	var avg := _t / float(_frames)
	var rid := vp.get_viewport_rid()
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(rid)
	var eye := _eye()
	var hz := float(_prop("display_refresh_rate", 0.0))
	var fov := "%s/%s/%s" % [str(_prop("foveation_level", "n/a")), str(_prop("foveation_dynamic", "n/a")), str(vp.vrs_mode)]
	if _last_eye != "" and eye != _last_eye:
		_emit("CHANGE eye %s -> %s up=%.1f" % [_last_eye, eye, _up])
	if _last_hz >= 0.0 and not is_equal_approx(hz, _last_hz):
		_emit("CHANGE refresh %s -> %s up=%.1f" % [str(_last_hz), str(hz), _up])
	if _last_fov != "" and fov != _last_fov:
		_emit("CHANGE foveation(level/dynamic/vrs) %s -> %s up=%.1f" % [_last_fov, fov, _up])
	_last_eye = eye
	_last_hz = hz
	_last_fov = fov
	_last_line = "PERF up=%.0f where=%s fps=%d frame_ms=%.1f worst_ms=%.1f gpu_ms=%.1f cpu_ms=%.1f eye=%s mult=%s fov=%s hz=%d msaa=%s draws=%d tris=%dk tex_mb=%d" % [
		_up, where, int(round(float(_frames) / _t)), avg * 1000.0, _worst * 1000.0, gpu, cpu, eye, str(_prop("render_target_size_multiplier", "?")), fov, int(hz),
		str(vp.msaa_3d), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0)]
	_emit(_last_line, false)
	_t = 0.0
	_frames = 0
	_worst = 0.0


## Presses of A+X together mark the picture as good, B+Y together as bad (hold for half a second; a short buzz tells you it was noted).
## Returns "good", "bad" or "".
func marks(hs: Array, delta: float) -> String:
	var good: bool = bool(hs[0].get("a", false)) and bool(hs[1].get("a", false))
	var bad: bool = bool(hs[0].get("b", false)) and bool(hs[1].get("b", false))
	_held_good = _held_good + delta if good else 0.0
	_held_bad = _held_bad + delta if bad else 0.0
	if not good:
		_marked_good = false
	if not bad:
		_marked_bad = false
	if _held_good > 0.5 and not _marked_good:
		_marked_good = true
		_emit("MARK GOOD up=%.1f | %s" % [_up, _last_line])
		return "good"
	if _held_bad > 0.5 and not _marked_bad:
		_marked_bad = true
		_emit("MARK BAD up=%.1f | %s" % [_up, _last_line])
		return "bad"
	return ""


# ---- headset overrides, read off the main thread so it never causes a hitch -------------------------------------------------
func _poll_props(delta: float) -> void:
	if not OS.has_feature("android"):
		return
	if _thread != null:
		if _thread.is_alive():
			return
		var now: Dictionary = _thread.wait_to_finish()
		_thread = null
		if _have_props:
			var changes: Array = []
			for k in now:
				if not _props.has(k):
					changes.append("+%s=%s" % [k, now[k]])
				elif _props[k] != now[k]:
					changes.append("%s: %s -> %s" % [k, _props[k], now[k]])
			for k in _props:
				if not now.has(k):
					changes.append("-%s" % k)
			if not changes.is_empty():
				_emit("OVERRIDES CHANGED up=%.1f %s" % [_up, ", ".join(changes)])
				_snapshot("after overrides changed")
		else:
			_emit("OVERRIDES " + str(now))
		_props = now
		_have_props = true
		return
	_prop_t -= delta
	if _prop_t <= 0.0:
		_prop_t = 3.0
		_thread = Thread.new()
		_thread.start(_read_props)


func _read_props() -> Dictionary:
	var out: Array = []
	var d := {}
	if OS.execute("getprop", [], out) == 0 and not out.is_empty():
		for line in str(out[0]).split("\n"):
			var l := line.strip_edges()
			if l.begins_with("[debug.oculus.") or l.begins_with("[persist.oculus.") or l.begins_with("[debug.ovr"):
				var parts := l.split("]: [")
				if parts.size() == 2:
					d[parts[0].trim_prefix("[")] = parts[1].trim_suffix("]")
	return d
