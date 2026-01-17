extends Node
class_name TrinketNervousDealer

func modify_dealer_stand_value(_game: Node, current_value: int) -> int:
	# dealer staje wcześniej
	return min(current_value, 16)
