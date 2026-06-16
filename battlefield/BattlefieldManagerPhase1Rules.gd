class_name BattlefieldManagerPhase1Rules
extends "res://battlefield/BattlefieldManager.gd"


func is_gambit_card(card_data: CardData) -> bool:
	return get_clean_card_type(card_data) == "gambit"


# Legacy wrapper: older code still calls this for the old spell-like bucket.
func is_spell_like_card(card_data: CardData) -> bool:
	return is_gambit_card(card_data)


func is_spell_card(card_data: CardData) -> bool:
	return is_gambit_card(card_data)


func is_event_card(_card_data: CardData) -> bool:
	return false


func is_trap_card(_card_data: CardData) -> bool:
	return false


func is_ruse_card(_card_data: CardData) -> bool:
	return false


func try_sacrifice_selected_card_to_tribute() -> bool:
	if not has_selected_card or selected_card_data == null:
		return false

	if tribute_manager != null and not tribute_manager.can_offer_card_this_turn():
		log_msg("Tribute already used this turn. Only 1 card can be used as Tribute per turn.")
		return false

	var offered_card_name: String = selected_card_data.card_name
	var offered_card_type: String = get_clean_card_type(selected_card_data)
	var tribute_success: bool = tribute_manager.offer_card_to_tribute(selected_card_data)

	if not tribute_success:
		return false

	if tribute_pile != null:
		tribute_pile.add_card(selected_card_data)

	if offered_card_type == "gambit":
		log_msg("Offered " + offered_card_name + " for temporary Tribute. +2 TP this turn.")
	else:
		log_msg("Offered " + offered_card_name + " for permanent Tribute. +1 permanent TP.")

	return true


func debug_tribute_selected_card() -> void:
	if selected_card_data == null:
		return

	try_sacrifice_selected_card_to_tribute()
	log_msg("Debug tribute: " + selected_card_data.card_name + ". " + tribute_manager.get_status_text())


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

	var tribute_card: CardData = ai_hand[tribute_index]

	if tribute_card == null:
		return

	await play_enemy_hand_to_node_animation(
		tribute_card,
		get_enemy_visual_target("EnemyTributePileVisual"),
		false
	)

	ai_hand.pop_at(tribute_index)
	ai_tribute.append(tribute_card)
	ai_tribute_used_this_turn = true

	var card_type: String = get_clean_card_type(tribute_card)

	if card_type == "gambit":
		ai_temp_tp += 2
		ai_current_tp += 2
		log_msg("AI offered " + tribute_card.card_name + " for +2 temporary TP.")
	else:
		ai_perm_tp += 1
		ai_current_perm_tp += 1
		ai_current_tp += 1
		log_msg("AI offered " + tribute_card.card_name + " for +1 permanent TP.")

	log_msg("AI TP: " + str(ai_current_tp) + "/" + str(ai_perm_tp) + " Temp +" + str(ai_temp_tp))
	update_ai_visuals()


func ai_choose_tribute_card_index() -> int:
	# Prefer unit/equipment for permanent TP.
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if card_data == null:
			continue

		var card_type: String = get_clean_card_type(card_data)

		if card_type == "unit" or card_type == "equipment":
			return i

	# If no permanent option exists, use a gambit for temporary TP.
	for i in range(ai_hand.size()):
		var card_data: CardData = ai_hand[i]

		if is_gambit_card(card_data):
			return i

	return -1


func ai_choose_slot_for_card(card_data: CardData) -> Node:
	if card_data == null:
		return null

	if is_unit_card(card_data):
		return ai_choose_front_slot_for_card(card_data)

	if is_equipment_card(card_data):
		return ai_choose_equipment_target_slot(card_data)

	if is_gambit_card(card_data):
		return ai_choose_spell_like_slot(card_data)

	return null


func ai_should_place_card_face_down(card_data: CardData, target_slot: Node) -> bool:
	if card_data == null or target_slot == null:
		return false

	var row: String = String(target_slot.get_meta("row", ""))

	if row == "front":
		return false

	if row == "back":
		return is_unit_card(card_data) or is_gambit_card(card_data)

	return false


func cleanup_battlefield_spells() -> void:
	cleanup_phase_one_board_cards()


func cleanup_phase_one_board_cards() -> void:
	if board_slots == null:
		return

	var returned_count: int = 0
	var discarded_count: int = 0

	for slot in board_slots.get_children():
		var card_data: CardData = get_slot_card_data(slot)

		if card_data == null:
			continue

		var slot_owner: String = String(slot.get_meta("owner", ""))
		var slot_row: String = String(slot.get_meta("row", ""))
		var is_face_down: bool = bool(slot.get_meta("face_down", false))
		var was_interacted: bool = bool(slot.get_meta("interacted_this_round", false))

		if is_face_down and slot_row == "back" and not was_interacted:
			return_face_down_setup_card_to_owner_hand(slot, card_data, slot_owner)
			returned_count += 1
			continue

		if is_gambit_card(card_data) and not is_face_down:
			discard_slot_card_for_cleanup(slot, card_data, slot_owner)
			discarded_count += 1
			continue

		slot.set_meta("interacted_this_round", false)

	if returned_count > 0:
		log_msg("Returned " + str(returned_count) + " untouched face-down back-row card(s) to hand.")

	if discarded_count > 0:
		log_msg("Cleaned up " + str(discarded_count) + " face-up Gambit card(s).")

	update_ai_visuals()


func return_face_down_setup_card_to_owner_hand(slot: Node, card_data: CardData, slot_owner: String) -> void:
	if card_data == null or slot == null:
		return

	if slot_owner == "enemy":
		ai_hand.append(card_data)
	else:
		if hand != null:
			hand.add_card_to_hand(card_data)

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	slot.set_meta("interacted_this_round", false)


func discard_slot_card_for_cleanup(slot: Node, card_data: CardData, slot_owner: String) -> void:
	if card_data == null or slot == null:
		return

	play_card_to_discard_animation(card_data, slot, slot_owner)

	if slot_owner == "enemy":
		ai_discard.append(card_data)
	elif discard_pile != null:
		discard_pile.add_card(card_data)

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	slot.set_meta("interacted_this_round", false)
