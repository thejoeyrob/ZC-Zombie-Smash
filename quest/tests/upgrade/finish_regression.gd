extends SceneTree
var failures := 0
var checks := 0
class FakeXR:
	extends RefCounted
	var render_target_size_multiplier := 1.0
	func get_render_target_size() -> Vector2:
		return Vector2(2100, 2100) * render_target_size_multiplier
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(msg)
func _run() -> void:
	var main = load("res://scripts/vr_main.gd").new()
	var xr := FakeXR.new()
	main.settings.resolution = "headset"
	main.settings.sharp = 1.6
	check(main._eye_multiplier(xr) == 1.0, "QGO resolution never receives an additional boost")
	main.q_tier = 2
	check(main._eye_multiplier(xr) == 1.0, "Adaptive lighting preserves requested resolution")
	main.free()
	var world := Node3D.new()
	root.add_child(world)
	var door := DoorScene.new()
	door.build(world, 0, 4, 3.4, VRBuild.mat(Color.GRAY), VRBuild.mat(Color.GRAY), null)
	door.set_process(false)
	check(door._timer >= 90 and door._timer <= 180, "Quiet start")
	var impacts: Array = []
	door.scare.connect(func(kind): impacts.append(kind))
	door._start_pass()
	door._pause = 0
	door._process(0.15)
	check(impacts.size() == 1 and door.zombie.visible, "One impact accompanies reveal")
	door._process(0.2)
	check(impacts.size() == 1, "No repeated impact spam")
	door.allowed = false
	door._process(0.01)
	check(not door.zombie.visible and not door._walking, "Menu or sports immediately cancels scare")
	check(door._timer >= 150 and door._timer <= 360, "Rare random cooldown")
	var holder := Node3D.new()
	world.add_child(holder)
	var a := VRBuild.mat(Color.WHITE)
	var b := VRBuild.mat(Color.WHITE)
	b.clearcoat_enabled = true
	b.clearcoat = 0.7
	var mesh := VRBuild.box(holder, Vector3.ONE, Vector3.ZERO, a)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	VRBuild.box(holder, Vector3.ONE, Vector3(2,0,0), b)
	VRBuild.merge_static(holder)
	check(holder.get_child_count() == 2, "Distinct finish materials cannot collapse together")
	check(holder.get_child(0).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Merged mesh preserves shadow policy")
	world.free()
	print("FINISH: %d checks; %d failures" % [checks, failures])
	quit(failures)
