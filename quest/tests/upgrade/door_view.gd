extends SceneTree
var ticks := 0
var door: DoorScene
func _initialize() -> void:
	_build.call_deferred()
func _build() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.6,0.65,0.72)
	we.environment.ambient_light_energy = 0.6
	world.add_child(we)
	door = DoorScene.new()
	door.build(world,0,4,3.4,VRBuild.pbr("brick-light"),VRBuild.mat(Color.GRAY),null)
	door.set_process(false)
	var light := OmniLight3D.new()
	light.position = Vector3(1,2,2)
	light.omni_range = 5
	world.add_child(light)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0,1.65,3)
	cam.look_at(Vector3(0,1.5,0))
	cam.current = true
func _process(_dt: float) -> bool:
	if door == null:
		return false
	ticks += 1
	if ticks == 20:
		root.get_texture().get_image().save_png("/tmp/fattys-door.png")
		door._start_pass()
		door._pause = 0
		door._process(0.15)
	if ticks == 40:
		root.get_texture().get_image().save_png("/tmp/fattys-scare.png")
		quit()
	return false
