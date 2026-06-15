extends "res://battlefield/BattlefieldManagerModeAI.gd"

var draw_temp_old_hand_limit: int = -1


func begin_game_after_battle_plan_selection() -> void:
	if game_has_started:
		return

	game_has_started = true
	ensure_player_deck_ready()
	update_tribute_counter()
	deal_visible_opening_hand()

	if game_mode == "ai" and not ai_starting_hand_done:
		ai_draw_cards(5)
		ai_starting_hand_done = true
		log_msg("AI starting hand dealt. AI deck remaining: " + str(ai_deck.size()))
		update_ai_panel()

	if tribute_manager != null:
		log_msg("Starting Tribute: " + tribute_manager.get_status_text())


func ensure_player_deck_ready() -> void:
	if player_deck == null:
		log_msg("PlayerDeck is missing.")
		return

	if player_deck.cards_remaining() <= 0 and player_deck.has_method("build_test_deck"):
		player_deck.build_test_deck()
		log_msg("Player deck rebuilt for new game. Cards: " + str(player_deck.cards_remaining()))

	if draw_pile != null:
		draw_pile.set_card_count(player_deck.cards_remaining())


func deal_visible_opening_hand() -> void:
	if hand == null:
		log_msg("Hand is missing.")
		return

	if player_deck == null:
		log_msg("PlayerDeck is missing.")
		return

	if not hand.cards.is_empty():
		hand.raise_hand()
		hand.arrange_fan(false)
		return

	var target_opening_size: int = mini(5, hand.max_hand_size)
	var drawn_count: int = 0

	for i in range(target_opening_size):
		var drawn_card: CardData = player_deck.draw_top_card()
		if drawn_card == null:
			break
		if hand.add_card_to_hand(drawn_card, false):
			drawn_count += 1

	if draw_pile != null:
		draw_pile.set_card_count(player_deck.cards_remaining())

	hand.raise_hand()
	hand.arrange_fan(false)
	log_msg("Opening hand dealt: " + str(drawn_count) + " cards. Deck remaining: " + str(player_deck.cards_remaining()))


func draw_battleplan_cards(plan: Dictionary) -> void:
	ensure_player_deck_ready()

	var draw_amount: int = int(plan.get("draw_amount", 0))
	var drawn_count: int = 0

	if draw_amount > 0 and player_deck != null and hand != null:
		for i in range(draw_amount):
			if not hand.can_accept_card():
				break
			var drawn_card: CardData = player_deck.draw_top_card()
			if drawn_card == null:
				break
			if hand.add_card_to_hand(drawn_card, true):
				drawn_count += 1

		if draw_pile != null:
			draw_pile.set_card_count(player_deck.cards_remaining())

		hand.raise_hand()
		hand.arrange_fan()
		log_msg("Battleplan draw: player drew " + str(drawn_count) + "/" + str(draw_amount) + " cards.")

	if game_mode == "ai":
		var ai_amount: int = int(opponent_battle_plan.get("draw_amount", draw_amount))
		ai_draw_cards(ai_amount)
		log_msg("AI battleplan draw: AI drew " + str(ai_amount) + " cards.")
		update_ai_panel()
	else:
		log_msg("Opponent draws " + str(draw_amount) + " cards. Opponent hand is simulated for now.")


func _on_draw_pile_drag_started(screen_position: Vector2) -> void:
	if not mode_selected:
		log_msg("Choose a game mode before drawing cards.")
		return

	if waiting_for_battle_plan:
		log_msg("Choose a Battle Plan before drawing from the Draw Pile.")
		return

	if current_phase == BattlePhase.COMBAT:
		log_msg("Cannot draw during Combat Phase.")
		return

	if hand == null:
		log_msg("Hand is missing.")
		return

	if player_deck == null:
		log_msg("PlayerDeck is missing.")
		return

	ensure_player_deck_ready()

	var preview_card: CardData = player_deck.peek_top_card()
	if preview_card == null:
		log_msg("Draw Pile is empty.")
		return

	# Manual draw-pile dragging is an admin/test action. If the hand is already at
	# the battleplan cap, temporarily open one slot so the drag preview can finish.
	draw_temp_old_hand_limit = -1
	if not hand.can_accept_card():
		draw_temp_old_hand_limit = hand.max_hand_size
		hand.max_hand_size = hand.cards.size() + 1
		log_msg("Admin draw: temporarily allowing 1 card over hand limit for testing.")

	hand.raise_hand()
	var started: bool = hand.start_draw_pile_drag(screen_position, preview_card)

	if started:
		log_msg("Dragging card from Draw Pile.")
	else:
		restore_draw_temp_hand_limit()
		log_msg("Draw Pile drag could not start.")


func _on_draw_pile_drag_moved(screen_position: Vector2) -> void:
	if hand == null:
		return

	hand.update_draw_pile_drag(screen_position)


func _on_draw_pile_drag_released(screen_position: Vector2) -> void:
	if hand == null:
		restore_draw_temp_hand_limit()
		return

	if player_deck == null:
		restore_draw_temp_hand_limit()
		log_msg("PlayerDeck is missing.")
		return

	if current_phase == BattlePhase.COMBAT:
		hand.finish_draw_pile_drag(screen_position, null)
		restore_draw_temp_hand_limit()
		log_msg("Draw cancelled. Cannot draw during Combat Phase.")
		return

	if waiting_for_battle_plan:
		hand.finish_draw_pile_drag(screen_position, null)
		restore_draw_temp_hand_limit()
		log_msg("Draw cancelled. Choose a Battle Plan first.")
		return

	var drawn_card: CardData = player_deck.draw_top_card()
	if drawn_card == null:
		hand.finish_draw_pile_drag(screen_position, null)
		restore_draw_temp_hand_limit()
		log_msg("Draw cancelled. Deck is empty.")
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var forced_hand_position := Vector2(screen_position.x, viewport_size.y - 1.0)
	var accepted: bool = hand.finish_draw_pile_drag(forced_hand_position, drawn_card)

	if accepted:
		if draw_pile != null:
			draw_pile.set_card_count(player_deck.cards_remaining())
		log_msg("Card drawn into hand. Deck remaining: " + str(player_deck.cards_remaining()))
	else:
		if hand.add_card_to_hand(drawn_card):
			if draw_pile != null:
				draw_pile.set_card_count(player_deck.cards_remaining())
			log_msg("Card drawn into hand. Deck remaining: " + str(player_deck.cards_remaining()))
		else:
			log_msg("Draw failed: card could not be added to hand.")

	restore_draw_temp_hand_limit()
	hand.raise_hand()
	hand.arrange_fan()


func restore_draw_temp_hand_limit() -> void:
	if hand != null and draw_temp_old_hand_limit >= 0:
		hand.max_hand_size = draw_temp_old_hand_limit
	draw_temp_old_hand_limit = -1
