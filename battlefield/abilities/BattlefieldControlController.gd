class_name BattlefieldControlController
extends RefCounted

## Control ability rules and duration state. BattlefieldManager remains the
## stable facade used by scene signals and the other ability domains.

var bf: BattlefieldManager


func _init(owner_battlefield: BattlefieldManager) -> void:
	bf = owner_battlefield


func get_card_control_ability(card_data: CardData, ability_id: StringName) -> AbilityData:
	if card_data == null:
		return null
	for ability in card_data.get_abilities():
		if ability != null and ability.category.to_lower() == "control" and ability.ability_id == ability_id:
			return ability
	return null


func card_has_control_ability(card_data: CardData, ability_id: StringName) -> bool:
	return get_card_control_ability(card_data, ability_id) != null


func slot_has_control_ability(slot: Node, ability_id: StringName, include_equipment: bool = true) -> AbilityData:
	if slot == null or bool(slot.get_meta("face_down", false)):
		return null
	var found := get_card_control_ability(bf.get_slot_card_data(slot), ability_id)
	if found != null:
		return found
	if not include_equipment or is_equipment_suppressed(slot):
		return null
	if slot.has_method("get_equipment_cards"):
		for equipment in slot.call("get_equipment_cards"):
			found = get_card_control_ability(equipment as CardData, ability_id)
			if found != null:
				return found
	return null


func opposite_owner(owner_name: String) -> String:
	return "enemy" if owner_name == "player" else "player"


func face_up_control_source(owner_name: String, ability_id: StringName, lane: String = "") -> Dictionary:
	for lane_name in ["left", "middle", "right"]:
		if lane != "" and lane_name != lane:
			continue
		for row_name in ["front", "back"]:
			var slot := bf.find_slot_by_owner_row_lane(owner_name, row_name, lane_name)
			if slot == null or bool(slot.get_meta("face_down", false)):
				continue
			var primary := bf.get_slot_card_data(slot)
			# Lockdown is also assigned to a Gambit. A face-up Gambit can project
			# its automatic aura from the back row; units/equipment still require
			# their normal frontline host.
			if row_name == "back" and not (ability_id == &"lockdown" and bf.is_gambit_card(primary)):
				continue
			# Inspect the source directly here. Calling slot_has_control_ability()
			# would ask whether equipment is Dampen-suppressed, which itself needs
			# this lookup and would recurse forever while searching for Dampen.
			var ability := get_card_control_ability(primary, ability_id)
			if ability == null and slot.has_method("get_equipment_cards"):
				for equipment in slot.call("get_equipment_cards"):
					ability = get_card_control_ability(equipment as CardData, ability_id)
					if ability != null:
						break
			if ability != null:
				return {"slot": slot, "ability": ability}
	return {}


func get_lockdown_source_against(slot: Node) -> Dictionary:
	if slot == null:
		return {}
	var owner_name := String(slot.get_meta("owner", ""))
	return face_up_control_source(opposite_owner(owner_name), &"lockdown", bf.get_slot_lane(slot))


func is_ability_suppressed_by_lockdown(slot: Node, trigger_name: String) -> bool:
	if trigger_name != "active" and trigger_name != "on_deploy":
		return false
	return not get_lockdown_source_against(slot).is_empty()


func is_equipment_suppressed(slot: Node) -> bool:
	if slot == null:
		return false
	var owner_name := String(slot.get_meta("owner", ""))
	return not face_up_control_source(opposite_owner(owner_name), &"dampen", bf.get_slot_lane(slot)).is_empty()


func get_halt_source_against(owner_name: String) -> Dictionary:
	return face_up_control_source(opposite_owner(owner_name), &"halt")


func is_unit_chained_down(slot: Node) -> bool:
	return slot != null and int(slot.get_meta("control_chain_down_turn", -1)) == bf.turn_number


func unit_must_attack(slot: Node) -> bool:
	return slot != null and int(slot.get_meta("control_forced_attack_turn", -1)) == bf.turn_number


func lane_attack_is_disabled(owner_name: String, lane: String) -> bool:
	return int(bf.control_disabled_lane_turns.get(owner_name + ":" + lane, -1)) == bf.turn_number


func owner_cannot_parry(owner_name: String) -> bool:
	return int(bf.control_no_parry_turns.get(owner_name, -1)) == bf.turn_number


func owner_has_handicap(owner_name: String) -> bool:
	return int(bf.control_handicap_turns.get(owner_name, -1)) == bf.turn_number


func show_control_trigger(ability: AbilityData, detail: String = "", include_description: bool = false) -> void:
	if ability == null:
		return
	var message := ability.ability_name.to_upper()
	if detail != "":
		message += "  -  " + detail
	if include_description and ability.rules_text.strip_edges() != "":
		message += "\n" + ability.rules_text.strip_edges()
	bf.log_msg("Control triggered: " + ability.ability_name + (" - " + detail if detail != "" else ""))
	bf.show_mobility_prompt(message, bf.CONTROL_PROMPT_ICON_PATH)
	await bf.get_tree().create_timer(0.9).timeout
	await bf.hide_mobility_prompt()


func choose_control_slot(candidates: Array[Node], ability: AbilityData, instruction: String) -> Node:
	return await bf.choose_mobility_slot(
		candidates,
		ability.ability_name.to_upper() + "  -  " + instruction,
		bf.CONTROL_PROMPT_ICON_PATH,
		ability.rules_text
	)


func get_face_up_unit_slots(owner_name: String, frontline_only: bool = false) -> Array[Node]:
	var result: Array[Node] = []
	if bf.board_slots == null:
		return result
	for slot in bf.board_slots.get_children():
		if String(slot.get_meta("owner", "")) != owner_name:
			continue
		if frontline_only and String(slot.get_meta("row", "")) != "front":
			continue
		if bool(slot.get_meta("face_down", false)):
			continue
		if bf.is_unit_card(bf.get_slot_card_data(slot)):
			result.append(slot)
	return result


func choose_ai_target(candidates: Array[Node]) -> Node:
	var best: Node = null
	var best_ap := -1
	for slot in candidates:
		var ap := bf.get_slot_combat_ap(slot)
		if ap > best_ap:
			best = slot
			best_ap = ap
	return best


func get_siren_targets(owner_name: String) -> Array[Node]:
	var result: Array[Node] = []
	for slot in get_face_up_unit_slots(owner_name, true):
		var lane := bf.get_slot_lane(slot)
		if is_unit_chained_down(slot) or lane_attack_is_disabled(owner_name, lane):
			continue
		var lane_index := bf.combat_lane_order.find(lane)
		if lane_index >= 0 and lane_index < bf.combat_next_lane_index:
			continue
		result.append(slot)
	return result


func resolve_control_deployment(card_data: CardData, slot: Node, owner_name: String) -> bool:
	if card_data == null or slot == null or bool(slot.get_meta("face_down", false)):
		return false
	if bf.is_equipment_card(card_data) and is_equipment_suppressed(slot):
		var dampen := face_up_control_source(opposite_owner(owner_name), &"dampen", bf.get_slot_lane(slot))
		await show_control_trigger(dampen.get("ability") as AbilityData, card_data.card_name + " suppressed")
		return true
	var resolved := false
	for ability in card_data.get_abilities():
		if ability == null or ability.category.to_lower() != "control":
			continue
		if is_ability_suppressed_by_lockdown(slot, "on_deploy"):
			var source := get_lockdown_source_against(slot)
			await show_control_trigger(source.get("ability") as AbilityData, ability.ability_name + " suppressed")
			continue
		match ability.get_handler_id():
			&"chain_down":
				resolved = await apply_chain_down(ability, owner_name) or resolved
			&"fog_of_war":
				bf.control_no_parry_turns[opposite_owner(owner_name)] = bf.turn_number
				await show_control_trigger(ability, opposite_owner(owner_name).capitalize() + " cannot Parry")
				resolved = true
			&"handicap":
				bf.control_handicap_turns[opposite_owner(owner_name)] = bf.turn_number
				await show_control_trigger(ability, "Enemy units get -1 AP")
				resolved = true
			&"dampen", &"halt", &"lockdown", &"burdened":
				await show_control_trigger(ability, "Aura active")
				resolved = true
	return resolved


func resolve_hidden_control_gambit(card_data: CardData, owner_name: String, _lane: String) -> bool:
	if card_data == null:
		return false
	for ability in card_data.get_abilities():
		if ability == null or ability.category.to_lower() != "control":
			continue
		match ability.get_handler_id():
			&"chain_down":
				return await apply_chain_down(ability, owner_name)
			&"lockdown":
				await show_control_trigger(ability, "Aura active")
				return true
			&"fog_of_war":
				bf.control_no_parry_turns[opposite_owner(owner_name)] = bf.turn_number
				await show_control_trigger(ability, opposite_owner(owner_name).capitalize() + " cannot Parry")
				return true
			&"handicap":
				bf.control_handicap_turns[opposite_owner(owner_name)] = bf.turn_number
				await show_control_trigger(ability, "Enemy units get -1 AP")
				return true
	return false


func apply_chain_down(ability: AbilityData, owner_name: String) -> bool:
	var target_owner := opposite_owner(owner_name)
	var candidates := get_face_up_unit_slots(target_owner)
	if candidates.is_empty():
		return false
	var target: Node
	if owner_name == "player":
		target = await choose_control_slot(candidates, ability, "Choose an opponent unit")
	else:
		target = choose_ai_target(candidates)
	if target == null:
		return false
	target.set_meta("control_chain_down_turn", bf.turn_number + 1)
	await show_control_trigger(ability, bf.get_slot_card_data(target).card_name + " is chained next turn")
	return true


func get_control_usage_key(slot: Node, ability: AbilityData) -> String:
	return str(slot.get_instance_id()) + ":" + String(ability.ability_id) + ":" + str(bf.turn_number)


func can_activate_control_ability(slot: Node, ability: AbilityData) -> bool:
	if slot == null or ability == null or ability.trigger != "active":
		return false
	if ability.get_handler_id() == &"lockdown":
		return false
	if String(slot.get_meta("owner", "")) != "player" or bool(slot.get_meta("face_down", false)):
		return false
	if bf.current_phase != bf.BattlePhase.COMBAT or bf.phase_transition_busy or bf.combat_resolution_running or bf.parry_system.active:
		return false
	if is_ability_suppressed_by_lockdown(slot, "active") or is_unit_chained_down(slot):
		return false
	if bf.used_active_control_ability_keys.has(get_control_usage_key(slot, ability)):
		return false
	if not bf.can_player_take_priority_action_in_lane(bf.get_slot_lane(slot)):
		return false
	match ability.get_handler_id():
		&"order":
			return true
		&"siren":
			return not get_siren_targets("enemy").is_empty()
	return false


func activate_control_ability(slot: Node, ability: AbilityData, ai_owner: bool = false) -> bool:
	if not ai_owner and not can_activate_control_ability(slot, ability):
		return false
	var caster_owner := "enemy" if ai_owner else "player"
	var target_owner := opposite_owner(caster_owner)
	var success := false
	match ability.get_handler_id():
		&"order":
			var lane := await choose_order_lane(ability, caster_owner)
			if lane != "":
				bf.control_disabled_lane_turns[target_owner + ":" + lane] = bf.turn_number
				await show_control_trigger(ability, lane.capitalize() + " lane deactivated")
				success = true
		&"siren":
			var candidates := get_siren_targets(target_owner)
			var target: Node = choose_ai_target(candidates) if ai_owner else await choose_control_slot(candidates, ability, "Choose an enemy unit")
			if target != null:
				target.set_meta("control_forced_attack_turn", bf.turn_number)
				await show_control_trigger(ability, bf.get_slot_card_data(target).card_name + " must attack")
				success = true
	if success:
		bf.used_active_control_ability_keys[get_control_usage_key(slot, ability)] = true
	return success


func choose_order_lane(ability: AbilityData, owner_name: String) -> String:
	var target_owner := opposite_owner(owner_name)
	var candidates: Array[Node] = []
	for lane in ["left", "middle", "right"]:
		var slot := bf.find_slot_by_owner_row_lane(target_owner, "front", lane)
		if slot != null:
			candidates.append(slot)
	if owner_name == "player":
		var chosen := await choose_control_slot(candidates, ability, "Choose an opponent lane")
		return bf.get_slot_lane(chosen)
	var best_lane := ""
	var best_ap := -1
	for candidate in candidates:
		var ap := bf.get_slot_combat_ap(candidate)
		if ap > best_ap:
			best_ap = ap
			best_lane = bf.get_slot_lane(candidate)
	return best_lane


func add_active_control_actions_to_board_menu(slot: Node) -> void:
	if slot == null or String(slot.get_meta("owner", "")) != "player" or bool(slot.get_meta("face_down", false)):
		return
	var entries: Array = slot.call("get_ability_visual_entries") if slot.has_method("get_ability_visual_entries") else []
	for entry in entries:
		var card_data := entry.get("card") as CardData
		if card_data == null or (card_data != bf.get_slot_card_data(slot) and is_equipment_suppressed(slot)):
			continue
		for ability in card_data.get_abilities():
			if ability == null or ability.category.to_lower() != "control" or ability.trigger != "active" or ability.get_handler_id() == &"lockdown":
				continue
			var action_id := bf.BOARD_ACTION_ACTIVE_INSIGHT_BASE + bf.board_action_ability_map.size()
			bf.board_action_ability_map[action_id] = ability
			bf.board_action_menu.add_item(ability.ability_name, action_id)
			var item_index := bf.board_action_menu.get_item_count() - 1
			if not can_activate_control_ability(slot, ability):
				bf.board_action_menu.set_item_disabled(item_index, true)


func ai_try_activate_control(current_lane: String) -> bool:
	var source := bf.find_slot_by_owner_row_lane("enemy", "front", current_lane)
	if source == null or is_unit_chained_down(source) or is_ability_suppressed_by_lockdown(source, "active"):
		return false
	var entries: Array = source.call("get_ability_visual_entries") if source.has_method("get_ability_visual_entries") else []
	for entry in entries:
		var card := entry.get("card") as CardData
		if card == null or (card != bf.get_slot_card_data(source) and is_equipment_suppressed(source)):
			continue
		for ability in card.get_abilities():
			if ability == null or ability.category.to_lower() != "control" or ability.trigger != "active" or ability.get_handler_id() == &"lockdown":
				continue
			if bf.used_active_control_ability_keys.has(get_control_usage_key(source, ability)):
				continue
			if await activate_control_ability(source, ability, true):
				bf.ai_passed_current_lane = true
				bf.set_lane_priority_to_player(current_lane, ability.ability_name + " used instead of attacking.")
				return true
	return false


func control_can_parry(attacker_slot: Node, defender_slot: Node, attacker_ap: int, defender_ap: int) -> bool:
	var attacker_owner := String(attacker_slot.get_meta("owner", ""))
	var defender_owner := String(defender_slot.get_meta("owner", ""))
	var swift := slot_has_control_ability(attacker_slot, &"swift")
	if swift != null:
		await show_control_trigger(swift, "Attack cannot be parried")
		return false
	if owner_cannot_parry(defender_owner):
		var fog_source := find_active_control_ability(&"fog_of_war", attacker_owner)
		await show_control_trigger(fog_source, "Opponent cannot Parry")
		return false
	var dominance := slot_has_control_ability(attacker_slot, &"dominance")
	if dominance != null and attacker_ap >= defender_ap + 2:
		await show_control_trigger(dominance, "AP advantage prevents Parry")
		return false
	return true


func find_active_control_ability(ability_id: StringName, owner_name: String) -> AbilityData:
	if bf.board_slots == null:
		return null
	for slot in bf.board_slots.get_children():
		if String(slot.get_meta("owner", "")) != owner_name or bool(slot.get_meta("face_down", false)):
			continue
		var found := slot_has_control_ability(slot, ability_id)
		if found != null:
			return found
	return null


func resolve_ambush_from_parry(parry_cards: Array[CardData], owner_name: String) -> bool:
	if parry_cards.size() < 2:
		return false
	var ambush_card := parry_cards[1]
	var ability := get_card_control_ability(ambush_card, &"ambush")
	if ability == null or not bf.is_unit_card(ambush_card):
		return false
	var candidates: Array[Node] = []
	for lane in ["left", "middle", "right"]:
		var slot := bf.find_slot_by_owner_row_lane(owner_name, "front", lane)
		if slot != null and bf.get_slot_card_data(slot) == null:
			candidates.append(slot)
	if candidates.is_empty():
		return false
	var target: Node = await choose_control_slot(candidates, ability, "Choose a frontline lane") if owner_name == "player" else candidates.pick_random()
	if target == null:
		return false
	if not target.call("place_card", bf.TEST_CARD_SCENE, ambush_card, false):
		return false
	if owner_name == "player" and bf.discard_pile != null:
		bf.discard_pile.remove_card(ambush_card)
	elif owner_name == "enemy":
		bf.ai_discard.erase(ambush_card)
	await show_control_trigger(ability, ambush_card.card_name + " deployed for free")
	bf.connect_card_ability_icon_signals(target)
	if owner_name == "player":
		await bf.handle_card_deployed(ambush_card, target)
	else:
		await bf.resolve_control_deployment(ambush_card, target, "enemy")
		await bf.resolve_mobility_deployment(ambush_card, target, "enemy")
	return true
