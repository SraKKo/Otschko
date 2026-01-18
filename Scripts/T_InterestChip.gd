extends Node

@export var interest := 0.05

func on_stage_cleared(game: Node) -> void:
	var bonus := int(round(game.money * interest))
	game.money += bonus
	game.update_ui()
