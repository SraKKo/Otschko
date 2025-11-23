extends Node
class_name Deck 

var deck: Array = []

func reset_deck():
	deck.clear()
	for i in range(52):     
		deck.append(i)
	deck.shuffle()

func draw_card() -> int:
	if deck.is_empty():
		reset_deck()
	return deck.pop_back()
