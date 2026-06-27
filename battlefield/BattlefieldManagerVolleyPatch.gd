class_name BattlefieldManagerVolleyPatch
extends "res://battlefield/BattlefieldManager.gd"

# Runtime patch for the current Mobility combat rules.
# This leaves the large base manager intact, then overrides only the rules that
# need to behave differently for Lane Shift and Volley.

func ability_requires_choice(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var ability_text_lower: String = card_data.get_ability_text().to_lower()
	return ability_text_lower.contains("may ") or ability_text_lower.contains("choose")


func refresh_player_usable_ability_icons() -> void:
	if board_slots == null:
		return

	for slot in board_slots.get_children():
		if slot == null:
			continue

		var is_player_slot := String(slot.get_meta("owner", "")) == "player"
		var is_face_down := bool(slot.get_meta("face_down", false))
		var entries: Array = slot.call("get_ability_visual_entries") if slot.has_method("get_ability_visual_entries") else []
		for entry in entries:
			var card_data := entry.get("card") as CardData
			var visual := entry.get("visual") as Node
			var usable_ids: Array[StringName] = []
			if is_player_slot and card_data != null and not is_face_down and not phase_transition_busy:
				for ability in card_data.get_abilities():
					if ability == null:
						continue
					var category := ability.category.to_lower()
					var handler_id := ability.get_handler_id()
					if category == "insight" and ability.trigger == "active" and can_activate_insight_ability(slot, ability):
						usable_ids.append(ability.ability_id)
					elif category == "mobility" and (ability.trigger == "active" or handler_id == &"tactic_flow" or handler_id == &"volley") and can_activate_mobility_ability(slot, ability):
						usable_ids.append(ability.ability_id)
			if visual != null and visual.has_method("set_usable_ability_ids"):
				visual.call("set_usable_ability_ids", usable_ids)
			connect_card_ability_icon_signals(slot, visual)


func add_active_mobility_actions_to_board_menu(slot: Node) -> void:
	if slot == null or String(slot.get_meta("owner", "")) != "player" or bool(slot.get_meta("face_down", false)):
		return
	var entries: Array = slot.call("get_ability_visual_entries") if slot.has_method("get_ability_visual_entries") else []
	for entry in entries:
		var card_data := entry.get("card") as CardData
		if card_data == null:
			continue
		for ability in card_data.get_abilities():
			if ability == null or ability.category.to_lower() != "mobility":
				continue
			var handler_id := ability.get_handler_id()
			if ability.trigger != "active" and handler_id != &"tactic_flow" and handler_id != &"volley":
				continue
			var action_id := BOARD_ACTION_ACTIVE_INSIGHT_BASE + board_action_ability_map.size()
			board_action_ability_map[action_id] = ability
			board_action_menu.add_item(ability.ability_name, action_id)
			var item_index := board_action_menu.get_item_count() - 1
			if not can_activate_mobility_ability(slot, ability):
				board_action_menu.set_item_disabled(item_index, true)


func can_activate_mobility_ability(slot: Node, ability: AbilityData) -> bool:
	if slot == null or ability == null:
		return false
	var handler_id := ability.get_handler_id()
	if handler_id == &"volley":
		return can_activate_volley_ability(slot, ability)
	if handler_id == &"lane_shift":
		return can_activate_lane_shift_to_empty(slot, ability)
	return super.can_activate_mobility_ability(slot, ability)


func can_activate_lane_shift_to_empty(slot: Node, ability: AbilityData) -> bool:
	if slot == null or ability == null:
		return false
	if ability.trigger != "active":
		return false
	if String(slot.get_meta("owner", "")) != "player" or bool(slot.get_meta("face_down", false)):
		return false
	if current_phase != BattlePhase.DEPLOYMENT and current_phase != BattlePhase.COMBAT:
		return false
	if phase_transition_busy or combat_resolution_running or parry_system.active:
		return false
	if not is_unit_card(get_slot_card_data(slot)):
		return false
	var used_turns: Dictionary = slot.get_meta("used_mobility_turns", {})
	if int(used_turns.get(String(ability.ability_id), -1)) == turn_number:
		return false
	return not get_empty_player_front_slots_excluding(slot).is_empty()


func get_empty_player_front_slots_excluding(source_slot: Node) -> Array[Node]:
	var result: Array[Node] = []
	for candidate in get_player_front_slots():
		if candidate == null or candidate == source_slot:
			continue
		if get_slot_card_data(candidate) == null:
			result.append(candidate)
	return result


func resolve_lane_shift(source_slot: Node, ability: AbilityData) -> bool:
	var candidates := get_empty_player_front_slots_excluding(source_slot)
	var target := await choose_mobility_slot(candidates, ability.ability_name + "  -  Choose an empty lane")
	if target == null:
		return false
	await move_slot_contents(source_slot, target)
	return true


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
	return not get_volley_target_slots_for_slot(slot).is_empty()


func activate_mobility_ability_from_slot(slot: Node, ability: AbilityData) -> void:
	if ability == null or ability.get_handler_id() != &"volley":
		await super.activate_mobility_ability_from_slot(slot, ability)
		return

	if not can_activate_mobility_ability(slot, ability):
		return

	var used_turns: Dictionary = slot.get_meta("used_mobility_turns", {}).duplicate()
	used_turns[String(ability.ability_id)] = turn_number
	slot.set_meta("used_mobility_turns", used_turns)

	var success := await resolve_volley_from_slot(slot, ability)
	if success:
		used_mobility_ability_keys[get_mobility_usage_key(slot, ability)] = true
	else:
		used_turns.erase(String(ability.ability_id))
		slot.set_meta("used_mobility_turns", used_turns)
	refresh_player_usable_ability_icons()


func get_player_attackers_for_lane(target_lane: String) -> Array[Node]:
	var attackers: Array[Node] = []
	var direct := find_slot_by_owner_row_lane("player", "front", target_lane)
	if is_unit_card(get_slot_card_data(direct)):
		attackers.append(direct)
	return attackers


func get_volley_target_lanes_for_slot(source_slot: Node) -> Array[String]:
	match get_slot_lane(source_slot):
		"left":
			return ["left", "middle"]
		"middle":
			return ["left", "middle", "right"]
		"right":
			return ["middle", "right"]
	return []


func get_volley_target_slots_for_slot(source_slot: Node) -> Array[Node]:
	var result: Array[Node] = []
	for lane in get_volley_target_lanes_for_slot(source_slot):
		if not can_player_take_priority_action_in_lane(lane):
			continue
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
	await resolve_player_attack_lane_from_specific_attacker(target_lane, source_slot, ability.ability_name)
	return true


func resolve_player_attack_lane_from_specific_attacker(lane: String, attacker_slot: Node, ability_name: String = "Volley") -> void:
	if combat_resolution_running:
		return

	combat_resolution_running = true

	if not prepare_player_lane_action(lane):
		combat_resolution_running = false
		return

	player_passed_current_lane = false
	set_active_combat_lane_highlight(lane)
	var attacker_lane := get_slot_lane(attacker_slot)
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
		return

	if enemy_back_is_face_down:
		await resolve_attack_into_face_down_backrow(lane, player_card, enemy_front_slot, enemy_back_slot, enemy_back_card)
		combat_resolution_running = false
		return

	if enemy_front_card == null:
		resolve_monarch_strike(lane, player_card)
		await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
		await advance_combat_lane_after_resolution()
		combat_resolution_running = false
		return

	await resolve_directed_clash(lane, attacker_slot, player_card, enemy_front_slot, enemy_front_card, true)

	if parry_system.active:
		combat_resolution_running = false
		return

	await get_tree().create_timer(COMBAT_LANE_END_DELAY).timeout
	await advance_combat_lane_after_resolution()
	combat_resolution_running = false
