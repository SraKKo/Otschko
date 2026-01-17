extends Node
class_name TrinketGoldenChip

@export var bonus_percent := 0.10  # 10%

func modify_payout(_game: Node, current_payout: int, context: String) -> int:
	# działa tylko na dodatnie payouty
	if current_payout <= 0:
		return current_payout
		
	if context == "draw":
		return current_payout

	# +10% (zaokrąglamy w dół)
	return int(floor(float(current_payout) * (1.0 + bonus_percent)))
