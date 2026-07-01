class_name BattlefieldAttritionController
extends RefCounted

var bf: BattlefieldManager
var used_active_keys: Dictionary = {}
var shockwave_locks: Array[Dictionary] = []


func _init(owner_battlefield: BattlefieldManager) -> void:
	bf = owner_battlefield


func opposite(owner: String) -> String:
	return "enemy" if owner == "player" else "player"


func get_card_ability(card: CardData, ability_id: StringName) -> AbilityData:
	if card == null:
		return null
	for ability in card.get_abilities():
		if ability != null and ability.category.to_lower() == "attrition" and ability.ability_id == ability_id:
			return ability
	return null


func slot_ability(slot: Node, ability_id: StringName) -> AbilityData:
	if slot == null or bool(slot.get_meta("face_down", false)):
		return null
	var found := get_card_ability(bf.get_slot_card_data(slot), ability_id)
	if found != null:
		return found
	if slot.has_method("get_equipment_cards") and not bf.is_equipment_suppressed(slot):
		for equipment in slot.call("get_equipment_cards"):
			found = get_card_ability(equipment as CardData, ability_id)
			if found != null:
				return found
	return null


func unit_slots(owner_filter: String = "", max_ap: int = 999) -> Array[Node]:
	var result: Array[Node] = []
	for slot in bf.board_slots.get_children():
		if owner_filter != "" and String(slot.get_meta("owner", "")) != owner_filter:
			continue
		if bool(slot.get_meta("face_down", false)):
			continue
		var card := bf.get_slot_card_data(slot)
		if bf.is_unit_card(card) and bf.get_slot_combat_ap(slot) <= max_ap:
			result.append(slot)
	return result


func equipment_slots(owner_filter: String = "") -> Array[Node]:
	var result: Array[Node] = []
	for slot in bf.board_slots.get_children():
		if owner_filter != "" and String(slot.get_meta("owner", "")) != owner_filter:
			continue
		if slot.has_method("get_equipment_count") and int(slot.call("get_equipment_count")) > 0:
			result.append(slot)
	return result


func resolve_deployment(card: CardData, slot: Node, owner: String) -> bool:
	if card == null or slot == null or bool(slot.get_meta("face_down", false)):
		return false
	var resolved := false
	for ability in card.get_abilities():
		if ability == null or ability.category.to_lower() != "attrition":
			continue
		if ability.trigger != "on_deploy" and not (bf.is_gambit_card(card) and ability.trigger != "active"):
			continue
		resolved = await resolve_effect(ability, slot, owner) or resolved
	return resolved


func resolve_hidden_gambit(card: CardData, slot: Node, owner: String) -> bool:
	if card == null:
		return false
	for ability in card.get_abilities():
		if ability != null and ability.category.to_lower() == "attrition" and ability.trigger != "active":
			return await resolve_effect(ability, slot, owner)
	return false


func resolve_effect(ability: AbilityData, source_slot: Node, owner: String) -> bool:
	match ability.get_handler_id():
		&"assasinate":
			var target := await choose_target(unit_slots(opposite(owner)), ability, "Choose an enemy unit", owner)
			if target == null: return false
			await bf.ability_presentation_controller.show_trigger(ability, bf.get_slot_card_data(target).card_name + " destroyed")
			await bf.destroy_unit_with_protection(target, source_slot, false, true, true)
		&"banish":
			var target := await choose_target(unit_slots(), ability, "Choose any unit", owner)
			if target == null: return false
			await bf.ability_presentation_controller.show_trigger(ability, bf.get_slot_card_data(target).card_name + " returned")
			await return_unit_with_equipment(target)
		&"banishment":
			var targets := unit_slots("", 999).filter(func(candidate: Node) -> bool: return bf.get_slot_card_data(candidate).tribute_cost < 5)
			await bf.ability_presentation_controller.show_trigger(ability, str(targets.size()) + " unit(s) returned")
			for target in targets: await return_unit_with_equipment(target)
		&"break":
			await bf.ability_presentation_controller.show_trigger(ability, "Enemy equipment destroyed")
			await destroy_all_equipment(opposite(owner))
		&"calamity":
			var target := await choose_target(lane_representatives(), ability, "Choose a lane", owner)
			if target == null: return false
			var lane := bf.get_slot_lane(target)
			await bf.ability_presentation_controller.show_trigger(ability, lane.capitalize() + " lane discarded")
			for side in ["player", "enemy"]:
				for row in ["front", "back"]:
					var victim := bf.find_slot_by_owner_row_lane(side, row, lane)
					if bf.is_unit_card(bf.get_slot_card_data(victim)):
						bf.send_slot_card_to_discard(victim)
		&"inquisition":
			await inspect_and_discard(owner, ability, 3)
		&"scorch":
			await remove_chosen_equipment(opposite(owner), owner, ability)
		&"shockwave":
			var target := await choose_target(lane_representatives(), ability, "Choose a lane", owner)
			if target == null: return false
			var lane := bf.get_slot_lane(target)
			await bf.ability_presentation_controller.show_trigger(ability, lane.capitalize() + " lane equipment locked")
			await destroy_lane_equipment(lane)
			shockwave_locks.append({
				"source": weakref(source_slot),
				"source_card": bf.get_slot_card_data(source_slot),
				"lane": lane,
			})
		&"terrorize":
			await bf.ability_presentation_controller.show_trigger(ability, "Opponent discards 1 card")
			await discard_from_hand(opposite(owner), 1, ability, owner == "player")
		&"wrath":
			await bf.ability_presentation_controller.show_trigger(ability, "All equipment destroyed")
			await destroy_all_equipment("")
		&"tactic_death":
			var target := await choose_target(unit_slots("", 4), ability, "Choose a unit with 4 AP or less", owner)
			if target == null: return false
			await bf.ability_presentation_controller.show_trigger(ability, bf.get_slot_card_data(target).card_name + " returned")
			await return_unit_with_equipment(target)
		_:
			return false
	return true


func choose_target(candidates: Array[Node], ability: AbilityData, instruction: String, owner: String) -> Node:
	if candidates.is_empty():
		await bf.ability_presentation_controller.show_trigger(ability, "No legal target")
		return null
	if owner == "player":
		return await bf.ability_presentation_controller.choose_slot(candidates, ability, instruction)
	return candidates.pick_random()


func lane_representatives() -> Array[Node]:
	var result: Array[Node] = []
	for lane in ["left", "middle", "right"]:
		var slot := bf.find_slot_by_owner_row_lane("enemy", "front", lane)
		if slot != null: result.append(slot)
	return result


func return_unit_with_equipment(slot: Node) -> void:
	var owner := String(slot.get_meta("owner", ""))
	var cards: Array[CardData] = [bf.get_slot_card_data(slot)]
	if slot.has_method("get_equipment_cards"):
		cards.append_array(slot.call("get_equipment_cards"))
	var target := bf.get_node_or_null("CardAnimationManager/PlayerHandOrigin") if owner == "player" else bf.get_node_or_null("CardAnimationManager/EnemyHandOrigin")
	for card in cards:
		if bf.card_animation_manager != null and target != null:
			await bf.card_animation_manager.animate_card_between_nodes(card, slot, target, false)
	slot.call("clear_slot")
	if owner == "player":
		for card in cards: bf.hand.add_card_to_hand(card)
	else:
		bf.ai_hand.append_array(cards)
		bf.update_ai_visuals()


func destroy_all_equipment(owner_filter: String) -> void:
	for slot in equipment_slots(owner_filter):
		await discard_all_equipment(slot)


func destroy_lane_equipment(lane: String) -> void:
	for owner in ["player", "enemy"]:
		var slot := bf.find_slot_by_owner_row_lane(owner, "front", lane)
		if slot != null: await discard_all_equipment(slot)


func discard_all_equipment(slot: Node) -> void:
	var cards: Array[CardData] = slot.call("remove_all_equipment")
	var owner := String(slot.get_meta("owner", ""))
	for card in cards:
		await bf.discard_cards_with_animation([card], slot, owner)


func remove_chosen_equipment(target_owner: String, caster_owner: String, ability: AbilityData) -> bool:
	var candidates := equipment_slots(target_owner)
	var slot := await choose_target(candidates, ability, "Choose a unit whose Equipment is removed", caster_owner)
	if slot == null: return false
	var equipment: Array[CardData] = slot.call("get_equipment_cards")
	var chosen := equipment[0]
	if caster_owner == "player" and equipment.size() > 1:
		var result := await bf.ability_presentation_controller.choose_card(equipment, ability, (slot as Node3D).global_position, bf.discard_pile.global_position)
		if bool(result.get("cancelled", false)): return false
		chosen = equipment[clampi(int(result.get("index", 0)), 0, equipment.size() - 1)]
	slot.call("remove_equipment_card", chosen)
	bf.discard_cards_with_animation([chosen], slot, target_owner)
	await bf.ability_presentation_controller.show_trigger(ability, chosen.card_name + " destroyed")
	return true


func player_hand_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	for card_ui in bf.hand.cards:
		if card_ui != null and card_ui.card_data != null: result.append(card_ui.card_data)
	return result


func remove_player_hand_card(card_data: CardData) -> bool:
	for card_ui in bf.hand.cards.duplicate():
		if card_ui.card_data == card_data:
			bf.hand.cards.erase(card_ui)
			card_ui.queue_free()
			bf.hand.arrange_fan()
			return true
	return false


func discard_from_hand(
	owner: String,
	amount: int,
	ability: AbilityData,
	caster_chooses: bool = false,
	owner_chooses: bool = false
) -> Array[CardData]:
	var discarded: Array[CardData] = []
	for i in range(amount):
		var cards: Array[CardData] = player_hand_cards() if owner == "player" else bf.ai_hand.duplicate()
		if cards.is_empty(): break
		var chosen := cards.pick_random() as CardData
		if owner_chooses and owner == "player":
			var own_result := await bf.ability_presentation_controller.choose_card(cards, ability, bf.get_insight_world_position("player_hand"), bf.get_insight_world_position("player_discard"))
			if bool(own_result.get("cancelled", false)): break
			chosen = cards[clampi(int(own_result.get("index", 0)), 0, cards.size() - 1)]
		if caster_chooses and owner == "enemy":
			var result := await bf.ability_presentation_controller.choose_card(cards, ability, bf.get_insight_world_position("enemy_hand"), bf.get_insight_world_position("enemy_discard"))
			if bool(result.get("cancelled", false)): break
			chosen = cards[clampi(int(result.get("index", 0)), 0, cards.size() - 1)]
		if owner == "player": remove_player_hand_card(chosen)
		else: bf.ai_hand.erase(chosen)
		discarded.append(chosen)
		bf.discard_cards_with_animation([chosen], bf.get_node_or_null("CardAnimationManager/PlayerHandOrigin") if owner == "player" else bf.get_node_or_null("CardAnimationManager/EnemyHandOrigin"), owner)
		if bf.economy_controller != null: await bf.economy_controller.on_card_discarded_from_hand(owner, chosen)
	bf.update_ai_visuals()
	return discarded


func inspect_and_discard(owner: String, ability: AbilityData, seen_count: int) -> bool:
	var target_owner := opposite(owner)
	var hand_cards: Array[CardData] = player_hand_cards() if target_owner == "player" else bf.ai_hand.duplicate()
	hand_cards.shuffle()
	var seen: Array[CardData] = hand_cards.slice(0, mini(seen_count, hand_cards.size()))
	if seen.is_empty(): return false
	var chosen := seen.pick_random() as CardData
	if owner == "player":
		var result := await bf.ability_presentation_controller.choose_card(seen, ability, bf.get_insight_world_position("enemy_hand"), bf.get_insight_world_position("enemy_discard"))
		if bool(result.get("cancelled", false)): return false
		chosen = seen[clampi(int(result.get("index", 0)), 0, seen.size() - 1)]
	if target_owner == "player": remove_player_hand_card(chosen)
	else: bf.ai_hand.erase(chosen)
	bf.discard_cards_with_animation([chosen], bf.get_node_or_null("CardAnimationManager/PlayerHandOrigin") if target_owner == "player" else bf.get_node_or_null("CardAnimationManager/EnemyHandOrigin"), target_owner)
	await bf.ability_presentation_controller.show_trigger(ability, chosen.card_name + " discarded")
	return true


func on_clash_won(winner_slot: Node, loser_owner: String) -> void:
	if winner_slot == null: return
	var owner := String(winner_slot.get_meta("owner", ""))
	for id in [&"cleave", &"raging_cry", &"sweeping_strike"]:
		var ability := slot_ability(winner_slot, id)
		if ability == null: continue
		match id:
			&"cleave":
				await bf.ability_presentation_controller.show_trigger(ability, "Opponent discards 1 card")
				await discard_from_hand(loser_owner, 1, ability, owner == "player")
			&"raging_cry": await inspect_and_discard(owner, ability, 2)
			&"sweeping_strike": await discard_hidden_gambit(loser_owner, owner, ability)


func discard_hidden_gambit(target_owner: String, caster_owner: String, ability: AbilityData) -> bool:
	var candidates: Array[Node] = []
	for lane in ["left", "middle", "right"]:
		var slot := bf.find_slot_by_owner_row_lane(target_owner, "back", lane)
		if slot != null and bool(slot.get_meta("face_down", false)) and bf.is_gambit_card(bf.get_slot_card_data(slot)): candidates.append(slot)
	var chosen := await choose_target(candidates, ability, "Choose a face-down Gambit", caster_owner)
	if chosen == null: return false
	await bf.ability_presentation_controller.show_trigger(ability, "Face-down Gambit discarded")
	bf.send_slot_card_to_discard(chosen)
	return true


func on_destroyed(_slot: Node, card: CardData, owner: String) -> void:
	for id in [&"curse", &"despair"]:
		var ability := get_card_ability(card, id)
		if ability == null: continue
		if id == &"curse":
			await bf.ability_presentation_controller.show_trigger(ability, "Owner discards 1 card")
			await discard_from_hand(owner, 1, ability)
		else:
			await bf.ability_presentation_controller.show_trigger(ability, "Owner loses 1 Aurion")
			bf.lose_aurion(owner, 1, ability.ability_name)


func on_monarch_strike(attacker_slot: Node, defender_owner: String) -> void:
	var ability := slot_ability(attacker_slot, &"shatter")
	if ability != null:
		await bf.ability_presentation_controller.show_trigger(ability, "Opponent discards 1 card")
		await discard_from_hand(defender_owner, 1, ability)


func can_activate(slot: Node, ability: AbilityData) -> bool:
	return can_activate_for_owner(slot, ability, "player")


func can_activate_for_owner(slot: Node, ability: AbilityData, owner: String) -> bool:
	if slot == null or ability == null or ability.category.to_lower() != "attrition" or ability.trigger != "active": return false
	if String(slot.get_meta("owner", "")) != owner or bool(slot.get_meta("face_down", false)): return false
	if bf.current_phase != bf.BattlePhase.COMBAT: return false
	if owner == "player" and not bf.can_player_take_priority_action_in_lane(bf.get_slot_lane(slot)): return false
	return not used_active_keys.has(str(slot.get_instance_id()) + ":" + String(ability.ability_id) + ":" + str(bf.turn_number))


func activate(slot: Node, ability: AbilityData, owner: String = "player") -> bool:
	var success := false
	match ability.get_handler_id():
		&"brugos_accord", &"one_man_army": success = await discard_all_but_one(opposite(owner), ability, owner)
		&"cursed_mist":
			await bf.ability_presentation_controller.show_trigger(ability, "Opponent discards 1 and loses 1 Aurion")
			await discard_from_hand(opposite(owner), 1, ability, owner == "player")
			bf.lose_aurion(opposite(owner), 1, ability.ability_name)
			success = true
	if success: used_active_keys[str(slot.get_instance_id()) + ":" + String(ability.ability_id) + ":" + str(bf.turn_number)] = true
	return success


func discard_all_but_one(target_owner: String, ability: AbilityData, _caster_owner: String) -> bool:
	var cards: Array[CardData] = player_hand_cards() if target_owner == "player" else bf.ai_hand.duplicate()
	if cards.size() <= 1: return false
	var keep := cards.pick_random() as CardData
	if target_owner == "player":
		var result := await bf.ability_presentation_controller.choose_card(cards, ability, bf.get_insight_world_position("player_hand"), bf.get_insight_world_position("player_hand"))
		if bool(result.get("cancelled", false)): return false
		keep = cards[clampi(int(result.get("index", 0)), 0, cards.size() - 1)]
	await bf.ability_presentation_controller.show_trigger(ability, "Opponent keeps " + keep.card_name)
	for card in cards:
		if card == keep: continue
		if target_owner == "player": remove_player_hand_card(card)
		else: bf.ai_hand.erase(card)
		bf.discard_cards_with_animation([card], bf.get_node_or_null("CardAnimationManager/PlayerHandOrigin") if target_owner == "player" else bf.get_node_or_null("CardAnimationManager/EnemyHandOrigin"), target_owner)
	return true


func is_equipment_lane_locked(slot: Node) -> bool:
	var lane := bf.get_slot_lane(slot)
	for lock in shockwave_locks.duplicate():
		var source_ref := lock.get("source") as WeakRef
		var source: Node = source_ref.get_ref() as Node if source_ref != null else null
		var source_card := lock.get("source_card") as CardData
		if source == null or source_card == null or bf.get_slot_card_data(source) != source_card:
			shockwave_locks.erase(lock)
			continue
		if String(lock.get("lane", "")) == lane: return true
	return false
