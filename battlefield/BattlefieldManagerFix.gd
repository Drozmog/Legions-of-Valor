extends "res://battlefield/BattlefieldManagerModeAI.gd"


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

	if not hand.can_accept_card():
		log_msg("Hand is full. Max hand size: " + str(hand.max_hand_size))
		return

	var preview_card: CardData = player_deck.peek_top_card()
	if preview_card == null:
		log_msg("Draw Pile is empty.")
		return

	hand.raise_hand()
	var started: bool = hand.start_draw_pile_drag(screen_position, preview_card)

	if started:
		log_msg("Dragging card from Draw Pile.")
	else:
		log_msg("Draw Pile drag could not start.")


func _on_draw_pile_drag_moved(screen_position: Vector2) -> void:
	if hand == null:
		return

	hand.update_draw_pile_drag(screen_position)


func _on_draw_pile_drag_released(screen_position: Vector2) -> void:
	if hand == null:
		return

	if player_deck == null:
		log_msg("PlayerDeck is missing.")
		return

	if current_phase == BattlePhase.COMBAT:
		hand.finish_draw_pile_drag(screen_position, null)
		log_msg("Draw cancelled. Cannot draw during Combat Phase.")
		return

	if waiting_for_battle_plan:
		hand.finish_draw_pile_drag(screen_position, null)
		log_msg("Draw cancelled. Choose a Battle Plan first.")
		return

	if not hand.can_accept_card():
		hand.finish_draw_pile_drag(screen_position, null)
		log_msg("Draw cancelled. Hand is full. Max hand size: " + str(hand.max_hand_size))
		return

	var drawn_card: CardData = player_deck.draw_top_card()
	if drawn_card == null:
		hand.finish_draw_pile_drag(screen_position, null)
		log_msg("Draw cancelled. Deck is empty.")
		return

	# Force the preview card to resolve into the hand even if the mouse is released
	# slightly outside the hand drop zone. This makes draw-pile dragging reliable
	# in both Practice Mode and AI Mode.
	var viewport_size: Vector2 = get_viewport_rect().size
	var forced_hand_position := Vector2(screen_position.x, viewport_size.y - 1.0)
	var accepted: bool = hand.finish_draw_pile_drag(forced_hand_position, drawn_card)

	if accepted:
		if draw_pile != null:
			draw_pile.consume_top_card()
		log_msg("Card drawn into hand. Deck remaining: " + str(player_deck.cards_remaining()))
	else:
		# Safety: if the preview somehow failed, put the card directly in hand so the draw still works.
		if hand.add_card_to_hand(drawn_card):
			if draw_pile != null:
				draw_pile.consume_top_card()
			log_msg("Card drawn into hand. Deck remaining: " + str(player_deck.cards_remaining()))
