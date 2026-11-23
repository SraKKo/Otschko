extends Node

func after_player_hand_updated(game: Node) -> void:
	# normalna ręka
	if not game.split_active:
		if game.count_score(game.player_cards) == 21:
			game.show_result("WIN")
			game.game_over("win_last_breath")
		return

	# split – aktualna ręka
	var cards: Array[int] = game.player_hand1 if game.current_hand == 1 else game.player_hand2

	if game.count_score(cards) == 21:
		if game.current_hand == 1:
			game.current_hand = 2
			game.update_split_arrows()
		else:
			game.finish_split()
