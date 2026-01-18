extends Node

var deck: Deck

var round_count: int = 0

var player_cards: Array = []
var dealer_cards: Array = []
var player_hand1 := []
var player_hand2 := []
var split_active := false
var current_hand := 1   # 1 lub 2
var dealer_hidden_card: int = -1

var money: int = 500     
var bet: int = 0         
var in_round: bool = false

var max_time := 10     
var current_time := 10
const TIMER_DECREASE_EVERY := 5 
const TIMER_DECREASE_BY := 1.5
const TIMER_MIN := 3

const STAGE_LENGTH := 5
const STAGE_MULTIPLIER := 1.5
const FINAL_STAGE := 5

var stage_index: int = 1
var stage_start_money: int = 0
var stage_target_money: int = 0

var active_effects: Array[Node] = []

var reward_shown_this_round := false

const GAME_OVER_SCENE := "res://Scenes/GameOverScreen.tscn"
const VICTORY_SCENE := "res://Scenes/VictoryScreen.tscn"

@onready var player1: AnimatedSprite2D = $PlayerCard1
@onready var player2: AnimatedSprite2D = $PlayerCard2
@onready var dealer1: AnimatedSprite2D = $DealerCard1
@onready var dealer2: AnimatedSprite2D = $DealerCard2

@onready var hit_button: Button = $HitButton
@onready var hold_button: Button = $HoldButton
@onready var bet_plus = $BetPlusButton
@onready var bet_minus = $BetMinusButton
@onready var deal_button = $DealButton
@onready var split_button: Button = $SplitButton


@onready var money_label = $Money/MoneyLabel
@onready var round_label: Label = $Round/RoundLabel
@onready var bet_label = $Bet/BetLabel
@onready var win_label = $Win
@onready var bust_label = $Bust
@onready var draw_label = $Draw
@onready var stage_label: Label = $UI/Stage/StageLabel
@onready var target_label: Label = $UI/Sprite2D/TargetLabel
@onready var hand1_arrow: CanvasItem = $UI/Hand1Arrow
@onready var hand2_arrow: CanvasItem = $UI/Hand2Arrow



@onready var time_bar: ProgressBar = $TimeBar
@onready var round_timer: Timer = $RoundTime
@onready var anim = $AnimationPlayer

@onready var trinkets_root: Node = $Trinkets

@onready var pause_menu: Control = $UI/PauseMenu
@onready var crt_rect: ColorRect = $CRT/Rect
@onready var trinket_choice : TrinketChoice = $UI/TrinketChoice


const CARD_BACK = 52  

func _ready():
	SettingsMenager.apply_crt(crt_rect)
	MusicPlayer.play_crossfade(preload("res://Sounds/Music/Base.ogg"), 1.0)
	
	trinket_choice.chosen.connect(_on_trinket_chosen)
	
	win_label.visible = false
	bust_label.visible = false
	draw_label.visible = false
	hand1_arrow.visible = false
	hand2_arrow.visible = false

	anim.animation_finished.connect(_on_result_anim_finished)

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
	
	split_button.visible = false
	
	update_ui()
	
func can_split() -> bool:
	if player_cards.size() != 2:
		return false

	var rank1 = player_cards[0] % 13
	var rank2 = player_cards[1] % 13

	return rank1 == rank2

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
	start_round_timer()
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
	
	
	if can_split():
		split_button.visible = true
	else:
		split_button.visible = false


func on_hit_pressed():
	# ====== NORMALNY HIT (BEZ SPLITU) ======
	if not split_active:
		var new_card = deck.draw_card()
		player_cards.append(new_card)

		# pozwól trinketom cofnąć bust na pierwszym Hicie
		for eff in active_effects:
			if eff.has_method("prevent_first_hit_bust"):
				if eff.prevent_first_hit_bust(self, player_cards):
					update_ui()
					return

		add_new_player_card_sprite(new_card)

		if count_score(player_cards) > get_bust_limit():
			game_over("Przegrana! Masz ponad limit.")
			show_result("BUST")
		return   # <-- TO jest kluczowe

	# ====== SPLIT AKTYWNY ======
	if current_hand == 1:
		var c1 = deck.draw_card()
		player_hand1.append(c1)
		update_split_sprites()

		if count_score(player_hand1) > get_bust_limit():
			current_hand = 2
		return

	if current_hand == 2:
		var c2 = deck.draw_card()
		player_hand2.append(c2)
		update_split_sprites()
		update_split_arrows()


		if count_score(player_hand2) > get_bust_limit():
			finish_split()
		return


func on_hold_pressed():
	# ==== SPLIT =====
	if split_active:
		if current_hand == 1:
			# kończymy pierwszą rękę, przechodzimy do drugiej
			current_hand = 2
			update_split_arrows()
			return
		else:
			# druga ręka zakończona → teraz dealer gra
			finish_split()
			return
	# ==== NORMALNA GRA BEZ SPLITU ====
	set_card(dealer2, dealer_hidden_card)

	# ==== BEZ SPLITU – NORMALNE ZACHOWANIE ====
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
	
func do_split():
	if not can_split():
		return

	split_active = true
	current_hand = 1

	# rozdziel karty
	player_hand1 = [player_cards[0]]
	player_hand2 = [player_cards[1]]

	# rozdaj po jednej karcie do każdej ręki
	player_hand1.append(deck.draw_card())
	player_hand2.append(deck.draw_card())

	# bet dla drugiej ręki
	money -= bet
	update_ui()

	# zaktualizuj wizualnie karty
	update_split_sprites()
	update_split_arrows()

	
func update_split_sprites():
	# wyczyść dodatkowe karty gracza (poza bazowymi sprite’ami)
	for child in get_children():
		if child is AnimatedSprite2D and child not in [player1, player2, dealer1, dealer2]:
			child.queue_free()

	var offset := Vector2(140, 0)

	# --- RĘKA 1 (u góry, na player1 / player2) ---
	if player_hand1.size() > 0:
		set_card(player1, player_hand1[0])
	if player_hand1.size() > 1:
		set_card(player2, player_hand1[1])

	var base1_start := player2.position

	for i in range(2, player_hand1.size()):
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = player1.sprite_frames
		spr.scale = player1.scale
		spr.position = base1_start + offset * (i - 1)
		add_child(spr)
		set_card(spr, player_hand1[i])

	# --- RĘKA 2 (drugi rząd, pod pierwszą) ---
	var hand2_start := player1.position + Vector2(0, 140)

	for i in range(player_hand2.size()):
		var spr2 := AnimatedSprite2D.new()
		spr2.sprite_frames = player1.sprite_frames
		spr2.scale = player1.scale
		spr2.position = hand2_start + offset * i
		add_child(spr2)
		set_card(spr2, player_hand2[i])

func split_payout(result: String, bet_amount: int, context: String) -> int:
	var base := 0
	match result:
		"win":
			base = bet_amount * 2
		"draw":
			base = bet_amount
		"lose":
			base = 0

	# modyfikujemy TYLKO wygrane (draw i lose zostawiamy)
	if result == "win":
		return apply_payout_modifiers(base, context)
	return base


func finish_split():
	# odkrywamy kartę dealera i dealer gra
	set_card(dealer2, dealer_hidden_card)
	dealer_play()

		# wyniki
	var score1 = count_score(player_hand1)
	var score2 = count_score(player_hand2)
	var dealer_score = count_score(dealer_cards)

	var result1 = hand_result(score1, dealer_score)
	var result2 = hand_result(score2, dealer_score)

	# payout
	money += split_payout(result1, bet, "split_hand1_win")
	money += split_payout(result2, bet, "split_hand2_win")
	update_ui()

	# === pokaż animację wyniku dla całego splita ===
	# (proste zasady: jak chociaż jedna ręka wygra -> WIN,
	#  jak obie przegrają -> BUST, inaczej DRAW)
	if result1 == "win" or result2 == "win":
		show_result("WIN")
	elif result1 == "lose" and result2 == "lose":
		show_result("BUST")
	else:
		show_result("DRAW")

	# kończymy split dopiero po rozliczeniu
	split_active = false
	current_hand = 1
	update_split_arrows()
	game_over("Split zakończony")


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
		show_result("WIN")
	elif dealer_score > player_score:
		game_over("Przegrana! Dealer ma więcej punktów.")
		show_result("BUST")
	elif dealer_score < player_score:
		game_over("Wygrałeś! Masz więcej punktów.")
		show_result("WIN")
	else:
		show_result("DRAW")
		game_over("Remis!")


func game_over(msg: String):
	print(msg)

	hit_button.disabled = true
	hold_button.disabled = true

# Rozliczenie betu (tylko normalna gra)
	if msg != "Split zakończony":
		match msg:
			"Wygrałeś! Dealer ma ponad 21.", "Wygrałeś! Masz więcej punktów.":
				var base = bet * 2
				money += apply_payout_modifiers(base, "normal_win")

			"Remis!":
				money += bet  # zwrot stawki (tego zwykle nie modyfikujemy)

			"Przegrana! Masz ponad 21.", "Przegrana! Dealer ma więcej punktów.", "Przegrana! Czas minął.":
				pass


	update_ui()

	await get_tree().create_timer(1.0).timeout

	# --- KONIEC RUNDY (zawsze) ---
	in_round = false
	round_timer.stop()

	# --- BANKRUCTWO ---
	if money <= 0:
		get_tree().change_scene_to_file(GAME_OVER_SCENE)
		return

	# --- KONIEC ETAPU (co 5 rund) ---
	if round_count % STAGE_LENGTH == 0:
		if money < stage_target_money:
			print("Stage FAILED. Money:", money, "Target:", stage_target_money)
			get_tree().change_scene_to_file(GAME_OVER_SCENE)
			inventory.clear()
			return
		else:
			print("Stage PASSED! Money:", money, "Target:", stage_target_money)
			update_timer_difficulty()
			
		if stage_index >= FINAL_STAGE:
			get_tree().change_scene_to_file(VICTORY_SCENE)
			return

	# --- NAGRODA CO 5 RUND (tylko jeśli nie pokazana) ---
	if (round_count % 5 == 0) and (not reward_shown_this_round):
		reward_shown_this_round = true
		show_trinket_reward()  # pauzuje grę i czeka na wybór
		return

	# --- NORMALNIE: NOWA RĘKA ---
	start_new_game()

func start_new_game():
	for child in get_children():
		if child is AnimatedSprite2D and child not in [player1, player2, dealer1, dealer2]:
			child.queue_free()

	hit_button.disabled = true
	hold_button.disabled = true

	bet = 0     
	update_ui()
	
	round_timer.stop()
	start_round_timer()
	split_button.visible = false


func on_deal():
	if in_round: return
	if bet == 0:
		print("Postaw najpierw zakład!")
		return
	
	round_count += 1
	update_round_label()
	
	# start nowego etapu co 5 rund (1,6,11...)
	if (round_count - 1) % STAGE_LENGTH == 0:
		start_stage(((round_count - 1) / STAGE_LENGTH) + 1)

	
	notify_round_start()
	reward_shown_this_round = false


	in_round = true

	hit_button.disabled = false
	hold_button.disabled = false
	
	split_button.visible = false

	deck.reset_deck()
	player_cards.clear()
	dealer_cards.clear()

	deal_initial_cards()

func update_ui():
	money_label.text = "Money: " + str(money)
	bet_label.text = "Bet: " + str(bet)
	update_stage_ui()

func start_round_timer():
	current_time = max_time
	time_bar.max_value = max_time
	time_bar.value = max_time
	round_timer.start()

func notify_round_start():
	for eff in active_effects:
		if eff.has_method("on_round_start"):
			eff.on_round_start(self)

func time_out():
	print("Czas minął!")
	# Gracz automatycznie przegrywa
	game_over("Przegrana! Czas minął.")

func _on_round_time_timeout() -> void:
	var step := 1
	for eff in active_effects:
		if eff.has_method("modify_timer_step"):
			step = eff.modify_timer_step(self, step)

	current_time -= step

	time_bar.value = current_time

	if current_time <= 0:
		round_timer.stop()
		time_out()

func update_round_label():
	round_label.text = "Round: " + str(round_count)
	
func add_new_player_card_sprite(card_index: int):
	var new_sprite := AnimatedSprite2D.new()
	new_sprite.sprite_frames = player1.sprite_frames
	new_sprite.scale = player1.scale

	# Pozycja — obok ostatniej karty
	var offset := Vector2(140, 0)
	new_sprite.position = player2.position + offset * (player_cards.size() - 2)

	add_child(new_sprite)
	set_card(new_sprite, card_index)
	
func dealer_play():
	set_card(dealer2, dealer_hidden_card)

	while count_score(dealer_cards) < get_dealer_stand_value():
		var stop_drawing := false
		for eff in active_effects:
			if eff.has_method("should_skip_dealer_draw"):
				if eff.should_skip_dealer_draw(self):
					stop_drawing = true
					break
		if stop_drawing:
			break

		var new_card = deck.draw_card()
		dealer_cards.append(new_card)

		var new_sprite := AnimatedSprite2D.new()
		new_sprite.sprite_frames = dealer1.sprite_frames
		new_sprite.scale = dealer1.scale

		var offset := Vector2(140, 0)
		new_sprite.position = dealer2.position + offset * (dealer_cards.size() - 2)

		add_child(new_sprite)
		set_card(new_sprite, new_card)



func hand_result(player_score: int, dealer_score: int) -> String:
	if player_score > get_bust_limit():
		return "lose"

	if dealer_score > get_bust_limit():
		return "win"

	if player_score > dealer_score:
		return "win"

	if player_score < dealer_score:
		return "lose"

	return "draw"


func _on_split_button_pressed() -> void:
	do_split()
	split_button.visible = false
	
func get_current_hand_score() -> int:
	if current_hand == 1:
		return count_score(player_hand1)
	return count_score(player_hand2)
	
func apply_equipped_trinkets():
	# usuń stare efekty
	for e in active_effects:
		if is_instance_valid(e):
			e.queue_free()
	active_effects.clear()

	# dodaj nowe efekty
	for def in inventory.equipped:
		if def == null or def.effect_script == null:
			continue
		var eff: Node = def.effect_script.new()

		eff.set_meta("def", def)

		trinkets_root.add_child(eff)
		active_effects.append(eff)


func get_bust_limit() -> int:
	var limit := 21
	for eff in active_effects:
		if eff.has_method("modify_bust_limit"):
			limit = eff.modify_bust_limit(self, limit)
	return limit

	
func get_dealer_stand_value() -> int:
	var stand := 17
	for eff in active_effects:
		if eff.has_method("modify_dealer_stand_value"):
			stand = eff.modify_dealer_stand_value(self, stand)
	return stand

func apply_payout_modifiers(base_payout: int, context: String) -> int:
	var payout := base_payout
	for eff in active_effects:
		if eff.has_method("modify_payout"):
			payout = eff.modify_payout(self, payout, context)
	return payout
	
func _input(event):
	if event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause():
	if get_tree().paused:
		get_tree().paused = false
		pause_menu.hide_menu()
	else:
		get_tree().paused = true
		pause_menu.show_menu()

func _on_result_anim_finished(_name: StringName) -> void:
	win_label.visible = false
	bust_label.visible = false
	draw_label.visible = false
	anim.play("TextShake")

func show_result(kind: String) -> void:
	# schowaj oba i pokaż tylko właściwy
	win_label.visible = false
	bust_label.visible = false
	draw_label.visible = false

	if kind == "WIN":
		win_label.visible = true
		anim.play("WIN")
	elif kind == "BUST":
		bust_label.visible = true
		anim.play("BUST")
	elif kind == "DRAW":
		draw_label.visible = true
		anim.play("DRAW")

func _on_trinket_chosen(def: TrinketDef) -> void:
	inventory.add_trinket(def)

	if inventory.equipped.size() < inventory.max_equipped:
		inventory.equip(def)

	apply_equipped_trinkets()
	update_ui()

	start_new_game()

func show_trinket_reward():
	trinket_choice.open()
	
func update_timer_difficulty():
	if round_count % TIMER_DECREASE_EVERY != 0:
		return

	var new_time := max_time - TIMER_DECREASE_BY
	max_time = max(new_time, TIMER_MIN)

	print("Timer reduced to:", max_time)
	
func start_stage(new_stage_index: int) -> void:
	stage_index = new_stage_index

	#bet odejmuje money, więc realny "kapitał" na starcie etapu to money + bet
	stage_start_money = money + bet

	stage_target_money = int(ceil(float(stage_start_money) * STAGE_MULTIPLIER))

	print("=== STAGE ", stage_index, " START ===")
	print("Start money:", stage_start_money, " Target:", stage_target_money)
	update_stage_ui()


func update_stage_ui():
	stage_label.text = "STAGE " + str(stage_index)
	target_label.text = "Money Required: " + str(stage_target_money)

func update_split_arrows() -> void:
	# bez splita - nic nie pokazujemy
	if not split_active:
		hand1_arrow.visible = false
		hand2_arrow.visible = false
		return

	# split aktywny - pokazuj tylko aktualną rękę
	hand1_arrow.visible = (current_hand == 1)
	hand2_arrow.visible = (current_hand == 2)
