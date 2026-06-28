class_name BattlefieldManagerVolleyPatch2
extends "res://battlefield/BattlefieldManagerVolleyPatch.gd"

# Follow-up Volley patch:
# - Volley target selection checks priority from the user's own lane.
# - The highlighted target lanes are all legal enemy lanes for that Volley unit.
# - Resolving Volley consumes the current lane action, so there is no follow-up normal attack.

func can_activate_volley_ability(slot: Node, ability: AbilityData) -> bool:
	if slot == null or ability == null:
		return false
	if String(slot.get_meta("owner", "")) != "player" or bool(slot.get_meta("face_down", false)):
		return false
	if current_phase != BattlePhase.COMBAT:
		return false
	if phase_transition_busy or combat_resolution_running or parry_system.active:
		return false
	if not is_unit_card(get_slot_card_data(slot)):
		return false
	var used_turns: Dictionary = slot.get_meta("used_mobility_turns", {})
	if int(used_turns.get(String(ability.ability_id), -1)) == turn_number:
		return false
	if not can_player_use_volley_from_slot(slot):
		return false
	return not get_volley_target_slots_for_slot(slot).is_empty()


func can_player_use_volley_from_slot(source_slot: Node) -> bool:
	if source_slot == null:
		return false
	var source_lane := get_slot_lane(source_slot)
	if source_lane == "":
		return false
	return can_player_take_priority_action_in_lane(source_lane)


func get_volley_target_slots_for_slot(source_slot: Node) -> Array[Node]:
	var result: Array[Node] = []
	if not can_player_use_volley_from_slot(source_slot):
		return result
	for lane in get_volley_target_lanes_for_slot(source_slot):
		var enemy_front_slot := find_slot_by_owner_row_lane("enemy", "front", lane)
		if enemy_front_slot != null:
			result.append(enemy_front_slot)
	return result


func resolve_volley_from_slot(source_slot: Node, ability: AbilityData) -> bool:
	var candidates := get_volley_target_slots_for_slot(source_slot)
	var target_slot := await choose_mobility_slot(candidates, ability.ability_name + "  -  Choose enemy lane to attack")
	if target_slot == null:
		return false
	var target_lane := get_slot_lane(target_slot)
	if target_lane == "":
		return false
	return await resolve_player_attack_lane_from_specific_attacker(target_lane, source_slot, ability.ability_name)


func prepare_player_volley_lane_action(source_lane: String, target_lane: String) -> bool:
	if source_lane == "" or target_lane == "":
		return false

	if not combat_direction_selected:
		if not player_has_initiative and combat_priority_owner != "player":
			log_msg("AI has initiative. You cannot choose the starting lane yet.")
			return false

		if source_lane == "left":
			set_combat_lane_order_from_left()
		elif source_lane == "right":
			set_combat_lane_order_from_right()
		else:
			log_msg("Choose the leftmost or rightmost lane first to set combat direction.")
			return false

	if combat_next_lane_index >= combat_lane_order.size():
		log_msg("All combat lanes are already resolved.")
		return false

	var expected_lane: String = combat_lane_order[combat_next_lane_index]
	if source_lane != expected_lane:
		log_msg("Next combat must resolve from the " + expected_lane + " lane.")
		return false

	if combat_priority_owner != "player":
		log_msg("AI has priority in the " + source_lane + " lane. You can act after AI passes or resolves its action.")
		return false

	return true


func resolve_player_attack_lane_from_specific_attacker(lane: String, attacker_slot: Node, ability_name: String = "Volley") -> bool:
	if combat_resolution_running:
		return false

	combat_resolution_running = true

	var attacker_lane := get_slot_lane(attacker_slot)
	if not prepare_player_volley_lane_action(attacker_lane, lane):
		combat_resolution_running = false
		return false

	player_passed_current_lane = false
	set_active_combat_lane_highlight(lane)
	if attacker_lane == lane:
		log_msg(ability_name + ": attacking the " + lane + " lane.")
	else:
		log_msg(ability_name + ": diagonal attack from the " + attacker_lane + " lane into the " + lane + " lane.")
	await get_tree().create_timer(COMBAT_LANE_START_DELAY).timeout

	var enemy_front_slot: Node = find_slot_by_owner_row_lane("enemy", "front", lane)
	var enemy_back_slot: Node = find_slot_by_owner_row_lane("enemy", "back", lane)

	var player_card: CardData = get_slot_card_data(attacker_slot)
	var enemy_front_card: CardData = get_slot_card_data(enemy_front_slot)
	var enemy_back_card: CardData = get_slot_card_data(enemy_back_slot)
	var enemy_back_is_face_down: bool = enemy_back_card != null and enemy_back_slot != null and bool(enemy_back_slot.get_meta("face_down", false))

	if not is_unit_card(player_card):
		log_msg(ability_name + ": the chosen attacker is no longer a unit.")
		combat_resolution_running = false
		return false

	if enemy_back_is_face_down:
		await resolve_volley_attack_into_face_down_backrow(lane, player_card, enemy_front_slot, enemy_back_slot, enemy_back_card, ability_name)
		combat_resolution_running = false
		return true

	if enemy_front_card == null:
		resolve_monarch_strike(lane, player_card)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		await advance_combat_lane_after_resolution()
		combat_resolution_running = false
		return true

	await resolve_directed_clash(lane, attacker_slot, player_card, enemy_front_slot, enemy_front_card, true)

	if parry_system.active:
		combat_resolution_running = false
		return true

	await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
	await advance_combat_lane_after_resolution()
	combat_resolution_running = false
	return true


func resolve_volley_attack_into_face_down_backrow(
	lane: String,
	_attacker_card: CardData,
	_enemy_front_slot: Node,
	enemy_back_slot: Node,
	enemy_back_card: CardData,
	ability_name: String = "Volley"
) -> void:
	if enemy_back_slot == null or enemy_back_card == null:
		return

	enemy_back_slot.set_meta("interacted_this_round", true)

	if enemy_back_slot.has_method("reveal_card"):
		enemy_back_slot.reveal_card()

	await get_tree().create_timer(BLUFF_REVEAL_DELAY).timeout

	if is_gambit_card(enemy_back_card):
		log_msg(ability_name + " failed: " + enemy_back_card.card_name + " was a hidden Gambit.")
		var mobility_returned := await resolve_immediate_hidden_gambit_cast(enemy_back_card, "enemy", lane, enemy_back_slot)
		if not mobility_returned:
			send_slot_card_to_discard(enemy_back_slot)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		await advance_combat_lane_after_resolution()
		return

	if resolve_stealth_hidden_decoy(enemy_back_slot, enemy_back_card, "enemy", lane):
		log_msg(ability_name + " is spent. No follow-up attack is available this lane.")
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		await advance_combat_lane_after_resolution()
		return

	add_aurion("player", 1, "Successful " + ability_name + " read: " + enemy_back_card.card_name + " was not a Gambit.")
	log_msg(ability_name + " read correctly: " + enemy_back_card.card_name + " was not a Gambit. Decoy is discarded and the attack is spent.")
	send_slot_card_to_discard(enemy_back_slot)
	await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
	await advance_combat_lane_after_resolution()
