extends Node

@export var bonus_per_win := 0.05
var win_streak := 0

func on_round_end(_game: Node, result: String) -> void:
	if result == "win":
		win_streak += 1
	elif result == "lose":
		win_streak = 0
	# draw nic nie zmienia

func modify_payout(_game: Node, payout: int, _context: String) -> int:
	if win_streak <= 0:
		return payout
	var mult := 1.0 + (float(win_streak) * bonus_per_win)
	return int(round(float(payout) * mult))
