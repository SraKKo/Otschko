extends Node
class_name TrinketLazyDealer

@export var skip_chance := 0.25  # 25%

# Zwraca true, jeśli dealer ma pominąć dobranie (i zakończyć dobieranie)
func should_skip_dealer_draw(_game: Node) -> bool:
	return randf() < skip_chance
