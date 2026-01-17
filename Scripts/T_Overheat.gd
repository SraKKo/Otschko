extends Node
class_name TrinketOverheat

func modify_bust_limit(_game: Node, current_limit: int) -> int:
	# zwiększamy limit co najmniej do 22
	return max(current_limit, 22)
