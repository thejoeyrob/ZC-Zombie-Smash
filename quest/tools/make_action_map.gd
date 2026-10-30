extends SceneTree
func _init():
	var m := OpenXRActionMap.new()
	m.create_default_action_sets()
	var err := ResourceSaver.save(m, "res://openxr_action_map.tres")
	print("saved action map: ", err)
	quit()
