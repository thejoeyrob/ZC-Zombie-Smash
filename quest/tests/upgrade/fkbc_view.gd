extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(900,1000)
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.09,0.10,0.13);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=0.8;world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-30,0);light.light_energy=1.2;world.add_child(light)
	var cabinet:=Cabinet.new();world.add_child(cabinet);cabinet.bezel_id="fkbc";cabinet.emu=true;cabinet.profile=FKBCMachine.cabinet_profile()
	cabinet.build(null,null,Color("#cc1722"),Color("#cc1722"),true,"FKBC")
	var session:=FKBCMachine.new();session.build(cabinet,ThemeDB.fallback_font);session.view.state="play";cabinet.set_live(session.texture())
	var cam:=Camera3D.new();world.add_child(cam);cam.position=Vector3(1.6,1.65,2.0);cam.look_at(Vector3(0,1,-0.3));cam.current=true
	for i in range(18): session.tick(1.0/60,true,0);await process_frame
	root.get_texture().get_image().save_png("/tmp/fkbc-cabinet.png")
	world.queue_free();await process_frame
	root.size=Vector2i(576,876)
	var view:=MiniArcade.new();root.add_child(view);view.start("fkbc",ThemeDB.fallback_font);view.state="play"
	view.game.fighters[0].x=135;view.game.fighters[1].x=210
	view.game.fighters[0].state="kick";view.game.fighters[0].t=0.16;view.game.banner_t=0
	view.queue_redraw()
	for i in range(8):await process_frame
	root.get_texture().get_image().save_png("/tmp/fkbc-game.png")
	quit()
