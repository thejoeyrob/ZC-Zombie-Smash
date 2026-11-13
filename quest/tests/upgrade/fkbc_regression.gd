extends SceneTree
var errors:=0
func check(ok: bool,label: String) -> void:
	if not ok: errors+=1;push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game:=MGFKBC.new()
	check(game.assets.size()==5,"Five source fighters")
	for id in game.assets:
		for pose in game.assets[id]:
			check(game._sprite(id,pose,1)!=null,"Right pose loads")
			check(game._sprite(id,pose,-1)!=null,"Left pose loads")
	game.fighters[0].x=140;game.fighters[1].x=185
	var hp: float=game.fighters[1].hp
	game.update(1.0/60,Vector2.ZERO,{}, {"a":true})
	for i in range(18):game.update(1.0/60,Vector2.ZERO,{}, {})
	check(game.fighters[1].hp<hp,"Punch damages opponent at reach")
	game.fighters[1].blocking=true;game.fighters[1].face=-1;hp=game.fighters[1].hp
	game._hurt(game.fighters[1],game.fighters[0],10,"punch")
	check(is_equal_approx(hp-game.fighters[1].hp,1.8),"Guard reduces front damage")
	for i in range(4):
		game.opp=i;game._new_round()
		check(game.banner.contains(MGFKBC.NAMES[i]),"All four opponents reachable")
	var machine:=Cabinet.new();machine.dual=true
	check(machine._make_button_defs().size()==2,"Dual sticks keep one weapon button plus menu")
	machine.dual=false
	check(machine._make_button_defs().size()==4,"Button layout has fire/grenade/weapon/menu")
	machine.free()
	var view:=MiniArcade.new();root.add_child(view);view.start("fkbc",ThemeDB.fallback_font)
	view.set_input(Vector2.ZERO,{"a":true});check(view.state=="play","Controller starts game")
	view.set_input(Vector2.ZERO,{});view.set_input(Vector2.ZERO,{"menu":true});check(view.state=="paused","Menu pauses")
	var before: float=view.game.time_left;view.tick(1);check(view.game.time_left==before,"Pause freezes clock")
	print("FKBC REGRESSION: ",errors," failures")
	view.queue_free();quit(errors)
