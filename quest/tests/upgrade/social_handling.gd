extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		push_error(msg)
func _run() -> void:
	for fps in [36,60,72,90,120]:
		var track := HandTrack.new()
		for i in range(fps):
			track.push(float(i)/fps, Vector3(0,0,float(i)/fps*3), Basis.IDENTITY)
		check(absf(track.peak_velocity().z-3)<0.05, "stable speed")
	var dart := SportAssist.launch(Vector3(-3,0,0), Vector3.LEFT, 2.37, 6.5,18)
	check(-dart.x >=6.5 and dart.y>0 and dart.z==0, "Dart gets speed/lift but no sideways auto aim")
	check(SportAssist.launch(Vector3.ZERO,Vector3.LEFT,2.37,6.5,18)==Vector3.ZERO,"Dropping is not throwing")
	check(SportAssist.launch(Vector3.RIGHT*3,Vector3.LEFT,2.37,6.5,18)==Vector3.RIGHT*3,"Backswing is not redirected")
	var g := AxeGame.new()
	root.add_child(g)
	g.build(null)
	g._start(0)
	var t: Throwable = g.axes[0]
	t.node.global_position = Vector3(ShackAnnex.AXE_X[0],1.52,ShackAnnex.AXE_LINE_Z)
	g.on_release(t,Transform3D.IDENTITY,Vector3(0,0,3),Vector3.ZERO,0)
	for i in range(120):
		if t.state == "flying":g._fly(t,1.0/120.0)
	check(t.state=="stuck", "Social axe reaches own target from line with moderate effort")
	g.free()
	print("SOCIAL HANDLING: 9 checks; ",failures," failures")
	quit(failures)
