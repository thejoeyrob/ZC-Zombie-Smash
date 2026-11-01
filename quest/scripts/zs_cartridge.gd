class_name ZombieSmashCartridge
extends Cartridge
## Zombie Smash as the first cartridge. For now it leans on the game that already runs inside the app (its engine, screen and
## intro live in vr_main.gd); the machines reach it only through this interface, so moving its parts in here later changes
## nothing for the machines or for any other game.

var _main: Node            # the app, which owns the running game for now


func _init(main: Node = null) -> void:
	_main = main
	id = "zombie_smash"
	title = "ZOMBIE SMASH"
	kind = "native"
	tint = Color("#7fd64a")


func screen_texture() -> Texture2D:
	if _main != null and _main.get("viewport") != null:
		return _main.viewport.get_texture()
	return null


func start() -> void:
	if _main != null:
		_main.start_game()


func pause(on: bool) -> void:
	if _main != null and _main.has_method("set_game_paused"):
		_main.set_game_paused(on)


func control_names() -> Dictionary:
	return {"stick": "MOVE", "fire": "FIRE", "alt": "BOMB"}
