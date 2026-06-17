class_name BattlefieldManagerPhase4BluffCombatFinal
extends "res://battlefield/PhaseShared.gd"


func resolve_player_check_lane_with_visuals(lane: String) -> void:
	if combat_resolution_running:
		return

	combat_resolution_running = true

	if not prepare_player_lane_action(lane):
		combat_resolution_running = false
		return

	set_active_combat_lane_highlight(lane)
	log_msg("Checking hidden back-row card in the " + lane + " lane.")
	await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout

	var back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)
	var back_card: CardData = get_slot_card_data(back_slot)

	if back_slot == null or back_card == null or not bool(back_slot.get_meta("face_down", false)):
		log_msg(lane.capitalize() + " lane: no face-down back-row card to check.")
		combat_resolution_running = false
		return

	back_slot.set_meta("interacted_this_round", true)

	if back_slot.has_method("reveal_card"):
		back_slot.reveal_card()

	await get_tree().create_timer(BLUFF_REVEAL_DELAY).timeout

	if is_gambit_card(back_card):
		add_aurion("player", 1, "Successful Check: " + back_card.card_name + " was a Gambit.")
		log_msg("Check successful. Gambit goes to discard. Lane action ends.")
		send_slot_card_to_discard(back_slot)
	else:
		add_aurion("ai", 1, "Failed Check: " + back_card.card_name + " was a decoy.")
		enemy_fortified_lanes[lane] = true
		log_msg("Check failed. Decoy returns to enemy hand. Enemy is fortified in this lane.")
		return_setup_card(back_slot, back_card, "enemy")

	await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
	advance_combat_lane_after_resolution()
	combat_resolution_running = false


func prepare_player_lane_action(lane: String) -> bool:
	if lane == "":
		return false

	if not combat_direction_selected:
		if lane == "left":
			set_combat_lane_order_from_left()
		elif lane == "right":
			set_combat_lane_order_from_right()
		else:
			log_msg("Choose the leftmost or rightmost lane first to set combat direction.")
			return false

	if combat_next_lane_index >= combat_lane_order.size():
		log_msg("All combat lanes are already resolved.")
		return false

	var expected_lane: String = combat_lane_order[combat_next_lane_index]

	if lane != expected_lane:
		log_msg("Next combat must resolve in the " + expected_lane + " lane.")
		return false

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	var player_card: CardData = get_slot_card_data(player_front_slot)

	if not is_unit_card(player_card):
		log_msg(lane.capitalize() + " lane: you have no front-row unit to act with.")
		return false

	return true
