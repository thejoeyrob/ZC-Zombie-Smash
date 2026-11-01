class_name Cartridges
extends RefCounted
## The list of games a machine can offer. Adding a game means adding one entry here and one Cartridge script.

## Entries a machine's game list can show. "enabled": false games are listed but greyed out.
static func catalogue() -> Array:
	return [
		{"id": "zombie_smash", "title": "ZOMBIE SMASH", "kind": "native", "enabled": true, "note": ""},
		{"id": "emulator", "title": "EMULATOR", "kind": "emulator", "enabled": false, "note": "your own game files, coming later"},
	]


static func create(id: String, main: Node) -> Cartridge:
	match id:
		"zombie_smash":
			return ZombieSmashCartridge.new(main)
	return null


static func default_id() -> String:
	return "zombie_smash"
