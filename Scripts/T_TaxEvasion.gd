extends Node

@export var refund_ratio := 0.5

func on_round_end(game: Node, result: String) -> void:
	if result != "lose":
		return

	var refund := int(round(float(game.bet) * refund_ratio))
	game.money += refund
	game.update_ui()
