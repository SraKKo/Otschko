extends Node

@export var payout_bonus := 0.30
@export var bust_cap := 20

func modify_bust_limit(_game: Node, limit: int) -> int:
	# zaostrza limit (zostawiamy niższy)
	return min(limit, bust_cap)

func modify_payout(_game: Node, payout: int, _context: String) -> int:
	# działa tylko na wygrane, bo u Ciebie modify_payout jest wołane tylko dla winów
	return int(round(payout * (1.0 + payout_bonus)))
