extends Node
class_name TrinketLuckyDraw

@export var trinket_id: String = "lucky_draw"
@export var rounds_left: int = 10

var used_this_round := false


func on_round_start(game: Node) -> void:
	rounds_left -= 1
	if rounds_left <= 0:
		var def: TrinketDef = get_meta("def", null)
		game.expire_trinket(def)


# Zwraca true jeśli uratował od spalenia i cofnął kartę
func prevent_first_hit_bust(game, hand: Array) -> bool:
	if used_this_round:
		return false
	if hand.size() <= 2:
		# to nie jest HIT (ręka startowa), tylko rozdanie
		return false

	var limit = 21
	if game.has_method("get_bust_limit"):
		limit = game.get_bust_limit()

	if game.count_score(hand) > limit:
		# cofamy ostatnią dobraną kartę
		hand.pop_back()
		used_this_round = true
		return true

	return false
