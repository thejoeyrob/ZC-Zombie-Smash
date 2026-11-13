class_name BowlingReaction
extends Node3D
## Two event-driven displays. No continuous offscreen rendering while idle.
var viewport: SubViewport
var title: Label
var status: Label
var portrait: TextureRect
var card: Control
var time := 0.0
var message := ""
var pictures: Array[Texture2D] = []
func build(parent: Node3D, at: Vector3, font: Font, lane: int) -> void:
	parent.add_child(self)
	position=at;rotation.y=PI
	viewport=SubViewport.new();viewport.size=Vector2i(768,432);viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(viewport)
	var bg:=TextureRect.new();bg.texture=load("res://assets/art/pbr-leather-black-c.jpg");bg.size=Vector2(768,432);bg.modulate=Color(0.16,0.2,0.24);viewport.add_child(bg)
	card=Control.new();card.size=Vector2(768,432);viewport.add_child(card)
	portrait=TextureRect.new();portrait.position=Vector2(16,42);portrait.size=Vector2(310,350);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;card.add_child(portrait)
	for file in ["boss-jordan-stage1.webp","boss-debo-stage1.webp","boss-drmantis-stage1.webp"]:
		pictures.append(load("res://assets/art/"+file))
	portrait.texture=pictures[lane%3]
	title=Label.new();title.position=Vector2(330,50);title.size=Vector2(420,200);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.add_theme_font_size_override("font_size",64);title.add_theme_color_override("font_color",Color(1,0.79,0.35));card.add_child(title)
	status=Label.new();status.position=Vector2(330,260);status.size=Vector2(410,160);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",30);card.add_child(status)
	if font!=null:
		title.add_theme_font_override("font",font);status.add_theme_font_override("font",font)
	title.text="STRIKERS\nLANE %d"%(lane+1)
	status.text="Pick up a ball to begin"
	VRBuild.box(self,Vector3(1.50,0.87,0.065),Vector3(0,0,-0.04),VRBuild.pbr("metal",Color(0.22,0.25,0.28),Vector2.ONE,0.2,0.65))
	VRBuild.quad(self,Vector2(1.44,0.81),Vector3.ZERO,VRBuild.tex_mat(viewport.get_texture(),0,0.9,true))
	set_process(false)
func react(result: String, pins: int, player: int) -> void:
	title.text=result
	message="PLAYER %d  /  %d PINS"%[player+1,pins]
	status.text=message+"\n"+("THE SHACK GOES WILD!" if result=="STRIKE!" else "CLEANED UP!" if result=="SPARE!" else "NEXT SHOT IS YOURS")
	portrait.texture=pictures[0 if pins==10 else 1 if pins>=5 else 2]
	time=0;set_process(true)
func _process(delta: float) -> void:
	time+=delta
	# Short character celebration; capped at 24 updates/s, stops after 2.4s.
	if int(time*24)!=int((time-delta)*24):
		portrait.position.y=42-absf(sin(time*6))*18*maxf(0,1-time/2.4)
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	if time>=2.4:
		portrait.position.y=42;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;set_process(false)
