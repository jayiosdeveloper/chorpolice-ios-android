## Bot — an enemy operative. Reuses Player's visuals/movement/combat; the AI is
## driven by game.gd (matching the iOS design where the scene runs the bot).
class_name Bot
extends Player

var think_t := 0.0
var fire_t := 1.0
var move_dir := 0.0
var wants_dodge := false

func _init() -> void:
	team = "enemy"
