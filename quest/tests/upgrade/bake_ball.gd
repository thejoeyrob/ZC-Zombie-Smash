extends SceneTree
func _initialize() -> void:
	build.call_deferred()
func build() -> void:
	var ball := CSGSphere3D.new()
	ball.radius=0.109;ball.radial_segments=48;ball.rings=24
	var shell:=StandardMaterial3D.new();shell.resource_name="shell";ball.material=shell
	root.add_child(ball)
	for at in [Vector3(-0.025,0.09,0.03),Vector3(0.025,0.09,0.03),Vector3(0,0.085,-0.03)]:
		var cut:=CSGCylinder3D.new()
		cut.radius=0.012;cut.height=0.08;cut.sides=16
		var bore:=StandardMaterial3D.new();bore.resource_name="bore";bore.albedo_color=Color(0.012,0.012,0.018);cut.material=bore
		cut.operation=CSGShape3D.OPERATION_SUBTRACTION
		ball.add_child(cut)
		cut.position=at.normalized()*0.105
		cut.quaternion=Quaternion(Vector3.UP,at.normalized())
	for i in range(5): await physics_frame
	var meshes:=ball.get_meshes()
	if meshes.size()<2: quit(1);return
	ResourceSaver.save(meshes[1],"res://assets/renovation/bowling_ball.res")
	quit()
