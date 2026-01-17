extends Node
class_name TrinketDoubleOrNothing

@export var double_chance := 0.20
@export var zero_chance := 0.20

func modify_payout(_game: Node, current_payout: int, _context: String) -> int:
	# działa tylko na wygrane payouty (>= 1 bet), reszta bez zmian
	if current_payout <= 0:
		return current_payout

	var r := randf()

	# 20% -> 0
	if r < zero_chance:
		return 0

	# kolejne 20% -> x2
	if r < zero_chance + double_chance:
		return current_payout * 2

	return current_payout
