class_name Cartridge
extends RefCounted
## What every game on an arcade machine provides. A machine does not know which game it runs: it asks its cartridge for a
## picture, feeds it the joystick and buttons, and listens for what happened. Zombie Smash is the first cartridge; our own
## future games, and one day an emulator mode, are more of the same.
##
## Input given to a cartridge each frame (a Dictionary, so new controls can be added without breaking old games):
##   axis   float   -1..1  the machine's stick, left and right
##   stick  Vector2        the stick on both axes (for games that need up and down)
##   fire   bool           the main button
##   alt    bool           the second button (Zombie Smash: grenade)
##   menu   bool           the machine's MENU button (pause)

signal sound(name: String, data: Dictionary)           # something to hear
signal haptic(strength: float, seconds: float)         # something to feel
signal finished(result: Dictionary)                    # a run ended: {score, ...} for the high score boards

var id := ""                     # short name, e.g. "zombie_smash"
var title := ""                  # shown on the machine's game list
var kind := "native"             # "native" (one of our games) or "emulator" (plays a file the player imported)
var enabled := true              # false = listed but not playable yet
var note := ""                   # shown under the title, e.g. "coming later"
var tint := Color("#7fd64a")     # the colour of this game's light pool and menu entry


## Create anything the game needs (its screen, its sounds). `host` is a node it may add children to.
func build(_host: Node) -> void:
	pass


## The live picture of the game, for the machine's monitor.
func screen_texture() -> Texture2D:
	return null


## What the monitor shows while nobody is playing.
func attract_texture() -> Texture2D:
	return screen_texture()


func start() -> void:
	pass


func stop() -> void:
	pass


func pause(_on: bool) -> void:
	pass


func set_input(_input: Dictionary) -> void:
	pass


func tick(_delta: float) -> void:
	pass


## Words for the machine's labels, so a different game can rename the controls: {"stick": "MOVE", "fire": "FIRE", "alt": "BOMB"}.
func control_names() -> Dictionary:
	return {"stick": "MOVE", "fire": "FIRE", "alt": "BOMB"}
