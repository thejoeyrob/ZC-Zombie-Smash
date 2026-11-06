extends SceneTree
var failures := 0
var count := 0
func _initialize() -> void:
 scan("res://scripts")
 print("COMPILE: %d scripts; %d failures" % [count, failures])
 quit(1 if failures else 0)
func scan(path: String) -> void:
 for file in DirAccess.get_files_at(path):
  if file.ends_with(".gd"):
   var script = load(path + "/" + file)
   count += 1
   if script == null or not script.can_instantiate():
    push_error("Invalid script: " + path + "/" + file)
    failures += 1
 for folder in DirAccess.get_directories_at(path):
  scan(path + "/" + folder)
