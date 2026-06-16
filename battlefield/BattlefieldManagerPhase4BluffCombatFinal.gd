class_name BattlefieldManagerPhase4BluffCombatFinal
extends "res://battlefield/BattlefieldManagerPhase4BluffCombatFull.gd"


func resolve_attack_into_face_down_backrow(
	lane: String,
	attacker_card: CardData,
	enemy_front_slot: Node,
	enemy_back_slot: Node,
	enemy_back_card: CardData
) -> void:
	if enemy_back_slot == null or enemy_back_card == null:
		return

	enemy_back_slot.set_meta("interacted_this_round", true)

	if enemy_back_slot.has_method("reveal_card"):
		enemy_back_slot.reveal_card()

	await get_tree().create_timer(BLUFF_REVEAL_DELAY).timeout

	if is_gambit_card(enemy_back_card):
		log_msg("Attack failed. Hidden Gambit was revealed. Attack is stopped.")
		send_slot_card_to_discard(enemy_back_slot)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		advance_combat_lane_after_resolution()
		return

	log_msg("Attack read correctly. Hidden decoy is discarded and attack continues.")
	send_slot_card_to_discard(enemy_back_slot)
	await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout

	var enemy_front_card: CardData = get_slot_card_data(enemy_front_slot)

	if enemy_front_card == null:
		resolve_monarch_strike(lane, attacker_card)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		advance_combat_lane_after_resolution()
		return

	var player_front_slot: Node = find_slot_by_owner_row_lane("player", "front", lane)
	resolve_lane_combat(lane, player_front_slot, enemy_front_slot)

	if parry_active:
		return

	await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
	advance_combat_lane_after_resolution()


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
