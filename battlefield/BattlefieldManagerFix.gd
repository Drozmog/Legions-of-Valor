extends "res://battlefield/BattlefieldManagerModeAI.gd"

var draw_temp_old_hand_limit: int = -1


func _ready() -> void:
	super._ready()
	resolve_runtime_references()
	force_mode_ui_state()


func resolve_runtime_references() -> void:
	if hand == null:
		hand = get_node_or_null("UI/Hand") as HandUI
	if draw_pile == null:
		draw_pile = get_node_or_null("DrawPile") as DrawPile
	if tribute_pile == null:
		tribute_pile = get_node_or_null("TributePile") as TributePile
	if player_deck == null:
		player_deck = get_node_or_null("PlayerDeck") as PlayerDeck
	if battle_plan_manager == null:
		battle_plan_manager = get_node_or_null("BattlePlanManager") as BattlePlanManager
		if battle_plan_manager == null:
			battle_plan_manager = get_node_or_null("battlePlanManager") as BattlePlanManager
	if battle_plan_panel == null:
		battle_plan_panel = get_node_or_null("UI/BattlePlanPanel") as BattlePlanPanel
	if battle_plan_selection_screen == null:
		battle_plan_selection_screen = get_node_or_null("UI/BattlePlanSelectionScreen") as BattlePlanSelectionScreen
	if discard_pile == null:
		discard_pile = get_node_or_null("DiscardPile") as DiscardPile


func force_mode_ui_state() -> void:
	if ai_panel != null:
		ai_panel.visible = game_mode == "ai"
	if spell_panel != null:
		spell_panel.hide()
	if parry_panel != null:
		parry_panel.hide()


func _on_mode_chosen(selected_mode: String) -> void:
	resolve_runtime_references()
	game_mode = selected_mode
	mode_selected = true
	waiting_for_battle_plan = true

	if mode_panel != null:
		mode_panel.hide()

	if game_mode == "ai":
		setup_ai_match()
		log_msg("Mode selected: Battle Against AI.")
	else:
		clear_ai_match_state()
		log_msg("Mode selected: Practice Mode.")

	force_mode_ui_state()
	setup_battle_plan_flow()


func clear_ai_match_state() -> void:
	ai_deck.clear()
	ai_hand.clear()
	ai_discard.clear()
	ai_tribute.clear()
	ai_perm_tp = 0
	ai_current_perm_tp = 0
	ai_temp_tp = 0
	ai_current_tp = 0
	ai_tribute_used = false
	ai_starting_hand_done = false
	if ai_panel != null:
		ai_panel.hide()


func _on_battle_plan_selected(plan: Dictionary) -> void:
	resolve_runtime_references()
	waiting_for_battle_plan = false

	if battle_plan_selection_screen != null:
		battle_plan_selection_screen.hide_selection()
		battle_plan_selection_screen.hide()

	if battle_plan_manager != null:
		battle_plan_manager.select_battle_plan(plan)

	if battle_plan_panel != null:
		battle_plan_panel.set_battle_plan(plan)

	choose_opponent_battle_plan()
	apply_battle_plan_rules(plan)
	apply_initiative_rules(plan)

	log_msg("Selected Battle Plan: " + str(plan.get("name", "Unknown Battle Plan")))
	log_msg("Opponent Battle Plan: " + str(opponent_battle_plan.get("name", "Unknown Battle Plan")))

	if not game_has_started:
		begin_game_after_battle_plan_selection()

	draw_battleplan_cards(plan)
	force_player_hand_visible()
	force_mode_ui_state()
	set_phase(BattlePhase.TRIBUTE)


func begin_game_after_battle_plan_selection() -> void:
	if game_has_started:
		return

	resolve_runtime_references()
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

	force_mode_ui_state()


func ensure_player_deck_ready() -> void:
	resolve_runtime_references()

	if player_deck == null:
		log_msg("PlayerDeck is missing. Check that the scene still has a node named PlayerDeck at the Battlefield3D root.")
		return

	if player_deck.cards_remaining() <= 0 and player_deck.has_method("build_test_deck"):
		player_deck.build_test_deck()
		log_msg("Player deck rebuilt for new game. Cards: " + str(player_deck.cards_remaining()))

	if draw_pile != null:
		draw_pile.set_card_count(player_deck.cards_remaining())


func deal_visible_opening_hand() -> void:
	resolve_runtime_references()

	if hand == null:
		log_msg("Hand is missing. Check that the scene still has UI/Hand.")
		return

	if player_deck == null:
		log_msg("PlayerDeck is missing. Cannot deal opening hand.")
		return

	hand.visible = true
	hand.show()

	if not hand.cards.is_empty():
		force_player_hand_visible()
		return

	var target_opening_size: int = mini(5, max(hand.max_hand_size, 5))
	var drawn_count: int = 0

	for i in range(target_opening_size):
		var drawn_card: CardData = player_deck.draw_top_card()
		if drawn_card == null:
			break
		if hand.add_card_to_hand(drawn_card, false):
			drawn_count += 1

	if draw_pile != null:
		draw_pile.set_card_count(player_deck.cards_remaining())

	force_player_hand_visible()
	log_msg("Opening hand dealt: " + str(drawn_count) + " cards. Deck remaining: " + str(player_deck.cards_remaining()))


func force_player_hand_visible() -> void:
	if hand == null:
		return
	hand.visible = true
	hand.show()
	hand.raise_hand()
	hand.move_to_front()
	hand.arrange_fan(false)


func draw_battleplan_cards(plan: Dictionary) -> void:
	resolve_runtime_references()
	ensure_player_deck_ready()

	var draw_amount: int = int(plan.get("draw_amount", 0))
	var drawn_count: int = 0

	if draw_amount > 0 and player_deck != null and hand != null:
		hand.visible = true
		hand.show()
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

		force_player_hand_visible()
		log_msg("Battleplan draw: player drew " + str(drawn_count) + "/" + str(draw_amount) + " cards.")

	if game_mode == "ai":
		var ai_amount: int = int(opponent_battle_plan.get("draw_amount", draw_amount))
		ai_draw_cards(ai_amount)
		log_msg("AI battleplan draw: AI drew " + str(ai_amount) + " cards.")
		update_ai_panel()
	else:
		log_msg("Opponent draws " + str(draw_amount) + " cards. Opponent hand is simulated for now.")

	force_mode_ui_state()


func _on_hand_card_drag_released(card: CardUI, screen_position: Vector2) -> void:
	resolve_runtime_references()

	if card == null:
		cancel_selected_card()
		return

	if selected_card_data == null and card.card_data != null:
		select_card(card.card_data)

	var target_node: Node = get_3d_node_under_screen_position(screen_position)
	var dropped_on_tribute: bool = is_tribute_drop_target(target_node, screen_position)

	# Tribute Phase is only for feeding the Tribute Pile. This prevents cards from
	# being left floating over board slots when the player releases them on the board.
	if current_phase == BattlePhase.TRIBUTE:
		if dropped_on_tribute:
			sacrifice_dragged_card_to_tribute(card)
			return

		safe_return_card_to_hand(card)
		cancel_selected_card()
		log_msg("Tribute Phase: drop a card onto the Tribute Pile, not the battlefield.")
		return

	var target_slot: Node = find_board_slot_from_node(target_node)

	if target_slot == null and selected_card_data != null and get_clean_card_type(selected_card_data) == "equipment":
		target_slot = find_equipment_target_slot_from_screen_position(screen_position)

	if target_slot != null:
		if current_phase != BattlePhase.DEPLOYMENT:
			log_msg("Cards can only be deployed during the Deployment Phase.")
			safe_return_card_to_hand(card)
			cancel_selected_card()
			return

		if should_prompt_spell_visibility(target_slot):
			show_spell_choice(card, target_slot, false)
			return

		var placed: bool = try_place_selected_card_on_slot(target_slot)
		if placed:
			hand.consume_dragged_card(card)
		else:
			safe_return_card_to_hand(card)
		cancel_selected_card()
		return

	if dropped_on_tribute:
		log_msg("Cards can only be sent to Tribute during the Tribute Phase.")
		safe_return_card_to_hand(card)
		cancel_selected_card()
		return

	log_msg("Card dropped nowhere valid.")
	safe_return_card_to_hand(card)
	cancel_selected_card()


func sacrifice_dragged_card_to_tribute(card: CardUI) -> void:
	if hand == null:
		return

	if selected_card_data == null and card != null and card.card_data != null:
		select_card(card.card_data)

	var sacrificed: bool = try_sacrifice_selected_card_to_tribute()

	if sacrificed:
		hand.consume_dragged_card(card)
		log_msg("Tribute accepted.")
	else:
		safe_return_card_to_hand(card)

	cancel_selected_card()
	force_player_hand_visible()


func safe_return_card_to_hand(card: CardUI) -> void:
	if hand == null:
		return

	if card != null:
		card.mouse_is_pressed = false
		card.is_dragging = false
		card.set_process(false)

	hand.return_dragged_card_to_hand(card)
	force_player_hand_visible()


func is_tribute_drop_target(target_node: Node, screen_position: Vector2) -> bool:
	if tribute_pile == null:
		return false

	if is_node_inside_target(target_node, tribute_pile):
		return true

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return false

	var tribute_screen_position: Vector2 = camera.unproject_position(tribute_pile.global_position)
	var tribute_radius_pixels: float = 230.0

	return tribute_screen_position.distance_to(screen_position) <= tribute_radius_pixels


func _on_draw_pile_drag_started(screen_position: Vector2) -> void:
	resolve_runtime_references()

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

	draw_temp_old_hand_limit = -1
	if not hand.can_accept_card():
		draw_temp_old_hand_limit = hand.max_hand_size
		hand.max_hand_size = hand.cards.size() + 1
		log_msg("Admin draw: temporarily allowing 1 card over hand limit for testing.")

	force_player_hand_visible()
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
	resolve_runtime_references()

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
	force_player_hand_visible()


func restore_draw_temp_hand_limit() -> void:
	if hand != null and draw_temp_old_hand_limit >= 0:
		hand.max_hand_size = draw_temp_old_hand_limit
	draw_temp_old_hand_limit = -1
