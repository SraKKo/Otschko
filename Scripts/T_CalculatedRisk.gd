extends Node

func modify_bust_limit(game: Node, limit: int) -> int:
	# sprawdzamy tylko aktywną rękę gracza
	var score := 0

	if not game.split_active:
		score = game.count_score(game.player_cards)
	else:
		var cards: Array[int] = game.player_hand1 if game.current_hand == 1 else game.player_hand2
		score = game.count_score(cards)

	if score >= 16 and score <= 18:
		return max(limit, 23) # podnosi limit do 22
	return limit
