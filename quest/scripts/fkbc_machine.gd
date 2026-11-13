class_name FKBCMachine
extends Node3D
signal leave
var viewport: SubViewport
var view: MiniArcade
var sound: AudioStreamPlayer3D
var active:=false
var _was_state:="title"
var _clips:={}
func build(parent: Node3D,font: Font) -> void:
	parent.add_child(self)
	viewport=SubViewport.new();viewport.size=Vector2i(576,876);viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(viewport)
	view=MiniArcade.new();viewport.add_child(view);view.start("fkbc",font)
	view.exited.connect(func(): view.start("fkbc",font);leave.emit())
	sound=AudioStreamPlayer3D.new();sound.position=Vector3(0,1.2,0);sound.max_distance=8;add_child(sound)
	for name in ["punch","kick","block","win"]: _clips[name]=load("res://fkbc/sfx_"+name+".wav")
func texture() -> Texture2D: return viewport.get_texture()
func set_input(stick: Vector2,buttons: Dictionary) -> void: view.set_input(stick,buttons)
func tick(delta: float,on: bool,volume: float) -> void:
	active=on
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on:
		view._st=Vector2.ZERO;view._btn={};view._prev={};view._edge={}
		sound.stop()
		return
	view.tick(delta)
	var game:=view.game as MGFKBC
	var clip:=game.hit_sound
	game.hit_sound=""
	if view.state=="over" and _was_state!="over": clip="win"
	_was_state=view.state
	if clip!="" and volume>0:
		sound.volume_db=linear_to_db(volume*0.65);sound.stream=_clips[clip];sound.play()

static func cabinet_profile() -> Dictionary:
	# Clean furniture outline; no character-shaped contour on a plain painted cabinet.
	var poly: Array=[]
	for zy in [Vector2(-0.76,0.02),Vector2(0.12,0.02),Vector2(0.12,0.92),Vector2(0.28,0.96),Vector2(0.28,1.04),Vector2(0.02,1.12),Vector2(-0.10,1.62),Vector2(0.01,1.80),Vector2(0.01,1.96),Vector2(-0.76,1.96)]:
		poly.append([(zy.x-CabProfile.Z_BACK)/CabProfile.W_M,1.0-zy.y/CabProfile.H_M])
	return {"poly":poly,"back_body":0.03636,"front_body":0.83636}
