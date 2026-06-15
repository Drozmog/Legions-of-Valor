class_name BattlefieldManager
extends BattlefieldManagerPhase

var ai_deck: Array[CardData] = []
var ai_hand: Array[CardData] = []
var ai_discard: Array[CardData] = []
var ai_tribute: Array[CardData] = []

var ai_perm_tp: int = 0
var ai_current_perm_tp: int = 0
var ai_temp_tp: int = 0
var ai_current_tp: int = 0
var ai_tribute_used_this_turn: bool = false
var ai_has_starting_hand: bool = false


func create_phase_ui() -> void:
	phase_panel = PanelContainer.new()
	phase_panel.name = "PhasePanel"
	phase_panel.anchor_left = 0.5
	phase_panel.anchor_right = 0.5
	phase_panel.anchor_top = 0.0
	phase_panel.anchor_bottom = 0.0
	phase_panel.offset_left = -190.0
	phase_panel.offset_right = 190.0
	phase_panel.offset_top = 20.0
	phase_panel.offset_bottom = 145.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.58)
	style.border_color = Color(0.9, 0.75, 0.35, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	phase_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	phase_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(phase_label)

	next_phase_button = Button.new()
	next_phase_button.focus_mode = Control.FOCUS_NONE
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	vbox.add_child(next_phase_button)

	# No more "Spawn Opponent Test Cards" button.
	spawn_opponent_button = null

	$UI.add_child(phase_panel)
	update_phase_ui()


func begin_game_after_battle_plan_selection() -> void:
	if game_has_started:
		return

	game_has_started = true

	setup_ai_deck()
	ai_draw_cards(5)
	ai_has_starting_hand = true

	update_tribute_counter()
	deal_starting_hand()

	if tribute_manager != null:
		log_msg("Starting Tribute: " + tribute_manager.get_status_text())

	log_msg("AI starting hand dealt. AI hand: " + str(ai_hand.size()) + " | AI deck: " + str(ai_deck.size()))


func _on_hand_card_drag_released(card: CardUI, screen_position: Vector2) -> void:
	if card == null:
		cancel_selected_card()
		return

	if not is_instance_valid(card):
		cancel_selected_card()
		return

	if selected_card_data == null and card.card_data != null:
		select_card(card.card_data)

	var target_node: Node = get_3d_node_under_screen_position(screen_position)
	var target_slot: Node = find_board_slot_from_node(target_node)

	# 1. Tribute pile has priority during Tribute Phase.
	if is_node_inside_target(target_node, tribute_pile):
		if current_phase != BattlePhase.TRIBUTE:
			log_msg("Cards can only be sent to Tribute during the Tribute Phase.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

		var sacrificed: bool = try_sacrifice_selected_card_to_tribute()

		if sacrificed:
			if hand != null:
				hand.consume_dragged_card(card)
		else:
			return_card_to_hand_safely(card)

		cancel_selected_card()
		return

	# 2. Board slot placement has priority during Deployment Phase.
	if target_slot != null:
		if current_phase != BattlePhase.DEPLOYMENT:
			log_msg("Cards can only be deployed during the Deployment Phase.")
			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

		var placed: bool = try_place_selected_card_on_slot(target_slot)

		if placed:
			if hand != null:
				hand.consume_dragged_card(card)
		else:
			return_card_to_hand_safely(card)

		cancel_selected_card()
		return

	# 3. If released back inside the hand area, reorder the hand.
	if hand != null and hand.has_method("is_screen_position_in_hand_reorder_zone"):
		if hand.is_screen_position_in_hand_reorder_zone(screen_position):
			if hand.has_method("reorder_card_in_hand"):
				hand.reorder_card_in_hand(card, screen_position.x)

			return_card_to_hand_safely(card)
			cancel_selected_card()
			return

	# 4. Anything else returns to hand.
	log_msg("Card dropped nowhere valid.")
	return_card_to_hand_safely(card)
	cancel_selected_card()


func return_card_to_hand_safely(card: CardUI) -> void:
	if hand == null:
		return

	if card != null and is_instance_valid(card):
		card.mouse_is_pressed = false
		card.is_dragging = false
		card.set_process(false)

	if hand.has_method("return_dragged_card_to_hand"):
		hand.return_dragged_card_to_hand(card)


func draw_battleplan_cards(plan: Dictionary) -> void:
	var draw_amount: int = int(plan.get("draw_amount", 0))

	var player_drawn_count: int = 0

	if draw_amount > 0 and player_deck != null and hand != null:
		for i in range(draw_amount):
			if not hand.can_accept_card():
				break

			var drawn_card: CardData = player_deck.draw_top_card()

			if drawn_card == null:
				break

			hand.add_card_to_hand(drawn_card)
			player_drawn_count += 1

			if draw_pile != null:
				draw_pile.consume_top_card()

	log_msg("Battleplan draw: player drew " + str(player_drawn_count) + "/" + str(draw_amount) + " cards.")

	var ai_draw_amount: int = int(opponent_battle_plan.get("draw_amount", draw_amount))
	ai_draw_cards(ai_draw_amount)

	log_msg("AI battleplan draw: AI drew " + str(ai_draw_amount) + " cards. AI hand: " + str(ai_hand.size()))


func set_phase(new_phase: int) -> void:
	current_phase = new_phase
	update_phase_ui()
	update_slot_highlights()

	match current_phase:
		BattlePhase.BATTLEPLAN:
			log_msg("Phase: Battleplan")

		BattlePhase.TRIBUTE:
			log_msg("Phase: Tribute")
			ai_start_tribute_phase()

		BattlePhase.DEPLOYMENT:
			begin_deployment_phase()

		BattlePhase.COMBAT:
			begin_combat_phase()


func begin_deployment_phase() -> void:
	log_msg("Phase: Deployment")

	if player_has_initiative:
		log_msg("Player has initiative and deploys first. AI will deploy after you press Go to Combat.")
	else:
		log_msg("AI has initiative and deploys first.")
		ai_deploy_one_card()


func _on_next_phase_pressed() -> void:
	match current_phase:
		BattlePhase.BATTLEPLAN:
			open_battle_plan_selection()

		BattlePhase.TRIBUTE:
			set_phase(BattlePhase.DEPLOYMENT)

		BattlePhase.DEPLOYMENT:
			if player_has_initiative:
				ai_deploy_one_card()
			set_phase(BattlePhase.COMBAT)

		BattlePhase.COMBAT:
			start_next_round()


func setup_ai_deck() -> void:
	ai_deck.clear()
	ai_hand.clear()
	ai_discard.clear()
	ai_tribute.clear()

	ai_perm_tp = 0
	ai_current_perm_tp = 0
	ai_temp_tp = 0
	ai_current_tp = 0
	ai_tribute_used_this_turn = false

	var pool: Array[CardData] = [
		ARCH_WIZARD_MAELCOR,
		IMPERIAL_ARCHIVE_MASTER,
		JENA_OF_YEL,
		IVAAN_BONE_CRUSHER,
		UPPER_HALL_PROSPECTOR,
		TEST_EQUIPMENT,
		TEST_SPELL
	]

	for i in range(40):
		ai_deck.append(pool[i % pool.size()])

	ai_deck.shuffle()


func ai_draw_cards(amount: int) -> void:
	for i in range(amount):
		if ai_deck.is_empty():
			return

		var drawn_card: CardData = ai_deck.pop_back()

		if drawn_card != null:
			ai_hand.append(drawn_card)


func ai_start_tribute_phase() -> void:
	ai_current_perm_tp = ai_perm_tp
	ai_temp_tp = 0
	ai_current_tp = ai_current_perm_tp
	ai_tribute_used_this_turn = false

	ai_offer_one_card_to_tribute()


func ai_offer_one_card_to_tribute() -> void:
	if ai_tribute_used_this_turn:
		return

	if ai_hand.is_empty():
		log_msg("AI has no cards to offer as Tribute.")
		return

	var tribute_index: int = ai_choose_tribute_card_index()

	if tribute_index < 0:
		log_msg("AI found no valid Tribute card.")
		return

	var tribute_card: CardData = ai_hand.pop_at(tribute_index)

	if tribute_card == null:
		return

	ai_tribute.append(tribute_card)
	ai_tribute_used_this_turn = true

	var card_type: String = tribute_card.card_type.to_lower().strip_edges()

	if card_type == "spell" or card_type == "event" or card_type == "trap" or card_type == "ruse":
		ai_temp_tp += 2
		ai_current_tp += 2
		log_msg("AI sacrificed " + tribute_card.card_name + " for +2 temporary TP.")
	else:
		ai_perm_tp += 1
		ai_current_perm_tp += 1
		ai_current_tp += 1
		log_msg("AI sacrificed " + tribute_card.card_name + " for +1 permanent TP.")

	log_msg("AI TP: " + str(ai_current_tp) + "/" + str(ai_perm_tp) + " Temp +" + str(ai_temp_tp))


func ai_choose_tribute_card_index() -> int:
	# Prefer a unit/equipment for permanent TP.
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		var card_type: String = card_data.card_type.to_lower().strip_edges()

		if card_type == "unit" or card_type == "equipment":
			return i

	# If no permanent tribute option exists, use a spell/event/trap/ruse.
	if not ai_hand.is_empty():
		return 0

	return -1


func ai_deploy_one_card() -> void:
	if ai_hand.is_empty():
		log_msg("AI has no hand cards to deploy.")
		return

	var target_slot: Node = ai_find_empty_front_slot()

	if target_slot == null:
		log_msg("AI has no empty front slot.")
		return

	var deploy_index: int = ai_choose_deploy_card_index()

	if deploy_index < 0:
		log_msg("AI passes deployment. No affordable unit in hand.")
		return

	var deploy_card: CardData = ai_hand.pop_at(deploy_index)

	if deploy_card == null:
		return

	if not ai_spend_tp(deploy_card.tribute_cost):
		ai_hand.append(deploy_card)
		log_msg("AI could not afford " + deploy_card.card_name + ".")
		return

	var placed: bool = target_slot.place_card(TEST_CARD_SCENE, deploy_card, false)

	if placed:
		log_msg("AI deployed " + deploy_card.card_name + " for " + str(deploy_card.tribute_cost) + " TP.")
		log_msg("AI TP after deployment: " + str(ai_current_tp) + "/" + str(ai_perm_tp) + " Temp +" + str(ai_temp_tp))
	else:
		ai_hand.append(deploy_card)
		log_msg("AI failed to deploy " + deploy_card.card_name + ".")


func ai_find_empty_front_slot() -> Node:
	if board_slots == null:
		return null

	for slot in board_slots.get_children():
		if slot.get_meta("owner", "") == "enemy" and slot.get_meta("row", "") == "front" and not slot.occupied:
			return slot

	return null


func ai_choose_deploy_card_index() -> int:
	var best_index: int = -1
	var best_ap: int = -999

	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		var card_type: String = card_data.card_type.to_lower().strip_edges()

		if card_type != "unit":
			continue

		if card_data.tribute_cost > ai_current_tp:
			continue

		if card_data.ap > best_ap:
			best_ap = card_data.ap
			best_index = i

	return best_index


func ai_spend_tp(cost: int) -> bool:
	if cost <= 0:
		return true

	if ai_current_tp < cost:
		return false

	var remaining_cost: int = cost

	if ai_temp_tp > 0:
		var temp_spent: int = mini(ai_temp_tp, remaining_cost)
		ai_temp_tp -= temp_spent
		ai_current_tp -= temp_spent
		remaining_cost -= temp_spent

	if remaining_cost > 0:
		ai_current_perm_tp -= remaining_cost
		ai_current_tp -= remaining_cost

	return true


func spawn_random_opponent_cards() -> void:
	# Old test-spawn disabled.
	# AI must deploy through hand + TP + phase rules.
	log_msg("Old opponent test spawn is disabled. AI uses legal deployment now.")
