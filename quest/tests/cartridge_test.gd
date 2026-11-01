extends SceneTree
## Checks that the cartridge list and the Zombie Smash cartridge hang together.
func _init() -> void:
	var cat := Cartridges.catalogue()
	assert(cat.size() >= 1)
	var c := Cartridges.create(Cartridges.default_id(), null)
	assert(c != null and c.id == "zombie_smash" and c.kind == "native" and c.enabled)
	assert(c.control_names().has("fire"))
	assert(Cartridges.create("emulator", null) == null)      # listed, but not built yet
	print("CARTRIDGE TEST OK: ", cat.size(), " entries, default ", c.id)
	quit()
