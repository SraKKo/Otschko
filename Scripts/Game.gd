extends Node

var deck: Deck

var round_count: int = 0

var player_cards: Array = []
var dealer_cards: Array = []
var dealer_hidden_card: int = -1
var money: int = 500     
var bet: int = 0         
var in_round: bool = false

var max_time := 10     
var current_time := 10



@onready var player1: AnimatedSprite2D = $PlayerCard1
@onready var player2: AnimatedSprite2D = $PlayerCard2
@onready var dealer1: AnimatedSprite2D = $DealerCard1
@onready var dealer2: AnimatedSprite2D = $DealerCard2

@onready var hit_button: Button = $HitButton
@onready var hold_button: Button = $HoldButton
@onready var bet_plus = $BetPlusButton
@onready var bet_minus = $BetMinusButton
@onready var deal_button = $DealButton

@onready var money_label = $MoneyLabel
@onready var round_label: Label = $RoundLabel
@onready var bet_label = $BetLabel

@onready var time_bar: ProgressBar = $TimeBar
@onready var round_timer: Timer = $RoundTime

const CARD_BACK = 52  


func _ready():
	deck = Deck.new()
	deck.reset_deck()

	player_cards.clear()
	dealer_cards.clear()

	deal_initial_cards()

	hit_button.pressed.connect(on_hit_pressed)
	hold_button.pressed.connect(on_hold_pressed)
	bet_plus.pressed.connect(on_bet_plus)
	bet_minus.pressed.connect(on_bet_minus)
	deal_button.pressed.connect(on_deal)

	update_ui()


func on_bet_plus():
	if in_round: 
		return
	if money >= 10:
		bet += 10
		money -= 10
		update_ui()


func on_bet_minus():
	if in_round: 
		return
	if bet >= 10:
		bet -= 10
		money += 10
		update_ui()


func deal_initial_cards():
	# --- KARTY GRACZA ---
	var p1 = deck.draw_card()
	var p2 = deck.draw_card()

	player_cards = [p1, p2]

	set_card(player1, p1)
	set_card(player2, p2)

	# --- KARTY DEALERA ---
	var d1 = deck.draw_card()
	dealer_hidden_card = deck.draw_card()

	dealer_cards = [d1, dealer_hidden_card]

	set_card(dealer1, d1)
	set_card(dealer2, CARD_BACK)
	
	round_timer.stop()
	start_round_timer()


func on_hit_pressed():
	var new_card = deck.draw_card()
	player_cards.append(new_card)

	var new_sprite := AnimatedSprite2D.new()
	new_sprite.sprite_frames = player1.sprite_frames
	new_sprite.scale = player1.scale

	var offset := Vector2(140, 0) 
	new_sprite.position = player2.position + offset * (player_cards.size() - 2)

	add_child(new_sprite)

	set_card(new_sprite, new_card)

	if count_score(player_cards) > 21:
		game_over("Przegrana! Masz ponad 21.")


func on_hold_pressed():
	set_card(dealer2, dealer_hidden_card)

	while count_score(dealer_cards) < 17:
		var new_card = deck.draw_card()
		dealer_cards.append(new_card)

		var new_sprite := AnimatedSprite2D.new()
		new_sprite.sprite_frames = dealer1.sprite_frames
		new_sprite.scale = dealer1.scale

		var offset := Vector2(140, 0)
		new_sprite.position = dealer2.position + offset * (dealer_cards.size() - 2)

		add_child(new_sprite)

		set_card(new_sprite, new_card)

	check_winner()


func set_card(sprite: AnimatedSprite2D, index: int):
	sprite.play("cards")
	sprite.frame = index


func count_score(cards: Array) -> int:
	var total = 0
	var aces = 0

	for c in cards:
		var rank = c % 13   

		if rank == 0:
			aces += 1
		elif rank >= 10:
			total += 10     
		else:
			total += rank + 1

	for i in range(aces):
		if total + 11 <= 21:
			total += 11
		else:
			total += 1

	return total


func check_winner():
	var player_score = count_score(player_cards)
	var dealer_score = count_score(dealer_cards)

	if dealer_score > 21:
		game_over("Wygrałeś! Dealer ma ponad 21.")
	elif dealer_score > player_score:
		game_over("Przegrana! Dealer ma więcej punktów.")
	elif dealer_score < player_score:
		game_over("Wygrałeś! Masz więcej punktów.")
	else:
		game_over("Remis!")


func game_over(msg: String):
	print(msg)

	hit_button.disabled = true
	hold_button.disabled = true

	# Rozliczenie betu
	match msg:
		"Wygrałeś! Dealer ma ponad 21.":
			money += bet * 2
		"Wygrałeś! Masz więcej punktów.":
			money += bet * 2
		"Przegrana! Masz ponad 21.":
			money -= bet
		"Przegrana! Dealer ma więcej punktów.":
			money -= bet
		"Remis!":
			money += bet

	update_ui()

	await get_tree().create_timer(1.0).timeout

	start_new_game()
	in_round = false
	round_timer.stop()


func start_new_game():
	for child in get_children():
		if child is AnimatedSprite2D and child not in [player1, player2, dealer1, dealer2]:
			child.queue_free()

	hit_button.disabled = true
	hold_button.disabled = true

	bet = bet     
	update_ui()
	
	round_timer.stop()
	start_round_timer()


func on_deal():
	if in_round: return
	if bet == 0:
		print("Postaw najpierw zakład!")
		return
	round_count += 1
	update_round_label()

	in_round = true

	hit_button.disabled = false
	hold_button.disabled = false

	deck.reset_deck()
	player_cards.clear()
	dealer_cards.clear()

	deal_initial_cards()


func update_ui():
	money_label.text = "Money: " + str(money)
	bet_label.text = "Bet: " + str(bet)
	
	
func start_round_timer():
	current_time = max_time
	time_bar.max_value = max_time
	time_bar.value = max_time
	round_timer.start()


func time_out():
	print("Czas minął!")
	# Gracz automatycznie przegrywa
	game_over("Przegrana! Czas minął.")


func _on_round_time_timeout() -> void:
	current_time -= 1
	time_bar.value = current_time

	if current_time <= 0:
		round_timer.stop()
		time_out()

func update_round_label():
	round_label.text = "Round: " + str(round_count)
