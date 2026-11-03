extends SceneTree
## Renders every display-machine variation in a row, for choosing a favourite. Run with a display: -s res://tests/showroom.gd
func _tex(f: String) -> Texture2D:
	return load("res://assets/art/" + f) if ResourceLoader.exists("res://assets/art/" + f) else null
func _initialize() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var v := [
		{"name": "joeyrob", "side": "side-joeyrob-flat.png", "marquee": "marquee-joeyrob.jpg", "screen": "arena-jordan.webp", "trim": Color(0.45, 0.85, 0.25), "btn_a": Color(0.9, 0.15, 0.1), "btn_b": Color(0.2, 0.55, 1.0), "btn_c": Color(1, 0.85, 0.1)},
		{"name": "mantis", "side": "side-mantis-flat.png", "marquee": "marquee-mantis.jpg", "screen": "arena-drmantis.webp", "trim": Color(0.6, 1.0, 0.2), "btn_a": Color(0.7, 1.0, 0.2), "btn_b": Color(1.0, 0.2, 0.7), "btn_c": Color(0.2, 0.9, 1.0)},
		{"name": "disco", "side": "side-disco-flat.png", "marquee": "marquee-disco.jpg", "screen": "arena-discoman.webp", "trim": Color(1.0, 0.2, 0.75), "btn_a": Color(1.0, 0.25, 0.7), "btn_b": Color(0.3, 0.8, 1.0), "btn_c": Color(1.0, 0.9, 0.2)},
		{"name": "fatamy", "side": "side-fatamy-flat.png", "marquee": "marquee-fatamy.jpg", "screen": "arena-fatamy.webp", "trim": Color(1.0, 0.3, 0.6), "btn_a": Color(1.0, 0.3, 0.6), "btn_b": Color(0.6, 0.4, 1.0), "btn_c": Color(1.0, 0.8, 0.3)},
		{"name": "pacman", "side": "retro-pacman-side.jpg", "marquee": "retro-pacman-marquee.jpg", "screen": "retro-pacman-screen.jpg", "trim": Color(1.0, 0.85, 0.05), "btn_a": Color(1, 0.2, 0.1), "btn_b": Color(1, 0.85, 0.1), "btn_c": Color(0.3, 0.6, 1), "mirror": false},
		{"name": "galaga", "side": "retro-galaga-side.jpg", "marquee": "retro-galaga-marquee.jpg", "screen": "retro-galaga-screen.jpg", "trim": Color(0.2, 0.3, 0.9), "btn_a": Color(0.9, 0.1, 0.1), "btn_b": Color(0.2, 0.5, 1), "btn_c": Color(1, 1, 1)},
		{"name": "asteroids", "side": "retro-asteroids-side.jpg", "marquee": "retro-asteroids-marquee.jpg", "screen": "", "trim": Color(0.1, 0.35, 0.9), "btn_a": Color(0.9, 0.1, 0.1), "btn_b": Color(1, 1, 1), "btn_c": Color(1, 1, 1)},
		{"name": "mortalkombat", "side": "retro-mk-side.jpg", "marquee": "retro-mk-marquee.jpg", "screen": "", "trim": Color(0.75, 0.05, 0.05), "btn_a": Color(0.9, 0.1, 0.1), "btn_b": Color(0.1, 0.1, 0.1), "btn_c": Color(1, 0.8, 0.1), "mirror": false},
	]
	for i in range(v.size()):
		var d: Dictionary = v[i]
		var m := ModelMachine.new()
		m.position = Vector3((i % 4 - 1.5) * 1.35, 0, -(i / 4) * 2.2)
		m.rotation.y = 0.45
		root.add_child(m)
		m.build({"side": _tex(d.side), "marquee": _tex(d.marquee), "screen": _tex(d.screen) if d.screen != "" else null, "trim": d.trim, "btn_a": d.btn_a, "btn_b": d.btn_b, "btn_c": d.btn_c, "mirror_right": d.get("mirror", true)})
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.03, 0.09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.55, 0.85)
	env.environment.ambient_light_energy = 0.9
	root.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-35, 25, 0)
	l.light_energy = 0.8
	root.add_child(l)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 40
	var shots := [[Vector3(0, 1.5, 6.5), Vector3(0, 0.9, -1.1)], [Vector3(-3.0, 1.3, 3.6), Vector3(-1.4, 0.95, 0.0)], [Vector3(3.2, 1.3, -2.3), Vector3(1.5, 0.95, -2.2)]]
	for k in range(shots.size()):
		cam.look_at_from_position(shots[k][0], shots[k][1], Vector3.UP)
		for f in range(4):
			await process_frame
		get_root().get_viewport().get_texture().get_image().save_png("/tmp/claude-0/showroom_%d.png" % k)
	quit()
