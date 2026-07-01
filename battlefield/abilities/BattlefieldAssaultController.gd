class_name BattlefieldAssaultController
extends RefCounted

var bf: BattlefieldManager
var used_active_keys: Dictionary = {}
var global_bonus_turn: Dictionary = {"player": 0, "enemy": 0}
var insight_used_turn: Dictionary = {"player": -1, "enemy": -1}
var promotion_turn: Dictionary = {"player": -1, "enemy": -1}
var attacked_slot_ids: Dictionary = {"player": {}, "enemy": {}}
var triggered_gambit_this_round: Dictionary = {"player": false, "enemy": false}
var triggered_gambit_last_round: Dictionary = {"player": false, "enemy": false}


func _init(owner_battlefield: BattlefieldManager) -> void:
	bf = owner_battlefield


func opposite(owner: String) -> String:
	return "enemy" if owner == "player" else "player"


func get_card_ability(card: CardData, id: StringName) -> AbilityData:
	if card == null: return null
	for ability in card.get_abilities():
		if ability != null and ability.category.to_lower() == "assault" and ability.ability_id == id: return ability
	return null


func slot_ability(slot: Node, id: StringName) -> AbilityData:
	if slot == null or bool(slot.get_meta("face_down", false)): return null
	var result := get_card_ability(bf.get_slot_card_data(slot), id)
	if result != null: return result
	if slot.has_method("get_equipment_cards") and not bf.is_equipment_suppressed(slot):
		for card in slot.call("get_equipment_cards"):
			result = get_card_ability(card as CardData, id)
			if result != null: return result
	return null


func resolve_deployment(card: CardData, slot: Node, owner: String) -> bool:
	if card == null or slot == null or bool(slot.get_meta("face_down", false)): return false
	var resolved := false
	for ability in card.get_abilities():
		if ability == null or ability.category.to_lower() != "assault": continue
		match ability.get_handler_id():
			&"battle_positions":
				if bf.is_gambit_card(card):
					global_bonus_turn[owner] = maxi(int(global_bonus_turn[owner]), 1)
					await bf.ability_presentation_controller.show_trigger(ability, "All allied units gain +1 AP")
					resolved = true
			&"overrun":
				if bf.is_gambit_card(card):
					global_bonus_turn[owner] = maxi(int(global_bonus_turn[owner]), 2)
					await bf.ability_presentation_controller.show_trigger(ability, "All allied units gain +2 AP")
					resolved = true
			&"momentum":
				if ability.trigger == "on_deploy":
					var primary := bf.get_slot_card_data(slot)
					var faction := primary.race.to_lower() if primary != null else card.race.to_lower()
					var allies := 0
					for lane in ["left", "middle", "right"]:
						var ally := bf.get_slot_card_data(bf.find_slot_by_owner_row_lane(owner, "front", lane))
						if bf.is_unit_card(ally) and ally != primary and ally.race.to_lower() == faction: allies += 1
					slot.set_meta("assault_momentum_turn", bf.turn_number)
					slot.set_meta("assault_momentum_bonus", allies * 2)
					await bf.ability_presentation_controller.show_trigger(ability, "+" + str(allies * 2) + " AP")
					resolved = true
	return resolved


func resolve_hidden_gambit(card: CardData, slot: Node, owner: String) -> bool:
	return await resolve_deployment(card, slot, owner)


func get_combat_bonus(slot: Node, is_attacking: bool) -> int:
	if slot == null: return 0
	var card := bf.get_slot_card_data(slot)
	if not bf.is_unit_card(card): return 0
	var owner := String(slot.get_meta("owner", ""))
	var bonus := int(global_bonus_turn.get(owner, 0))
	if is_attacking:
		if slot_ability(slot, &"challenger") != null: bonus += 2
		if slot_ability(slot, &"challenger_advanced") != null: bonus += 3
		if slot_ability(slot, &"honed_edge") != null: bonus += 2
	if slot_ability(slot, &"brutality") != null:
		bonus += int(float(get_hand_size(owner)) / 2.0)
	if slot_ability(slot, &"duelist") != null and count_front_units(owner) == 1: bonus += 2
	if slot_ability(slot, &"glean_strike") != null and int(insight_used_turn.get(owner, -1)) == bf.turn_number: bonus += 3
	if slot_ability(slot, &"haste") != null and int(promotion_turn.get(owner, -1)) == bf.turn_number: bonus += 2
	if int(slot.get_meta("assault_momentum_turn", -1)) == bf.turn_number: bonus += int(slot.get_meta("assault_momentum_bonus", 0))
	if slot_ability(slot, &"quick_draw") != null and bool(triggered_gambit_last_round.get(owner, false)): bonus += 1
	if slot_ability(slot, &"turbo") != null and another_unit_attacked(owner, slot): bonus += 2
	if slot_ability(slot, &"unequality") != null: bonus += count_non_orc_units(owner)
	if slot_ability(slot, &"unity") != null: bonus += count_same_race_front(owner, card.race)
	if int(slot.get_meta("assault_bargain_turn", -1)) == bf.turn_number: bonus += 2
	if int(slot.get_meta("assault_delirium_turn", -1)) == bf.turn_number: bonus += 3
	if int(slot.get_meta("assault_energy_bonus_turn", -1)) == bf.turn_number: bonus += 2
	return bonus


func announce_combat_bonuses(slot: Node, is_attacking: bool) -> void:
	for id in [&"battle_positions", &"overrun", &"challenger", &"challenger_advanced", &"honed_edge", &"brutality", &"duelist", &"glean_strike", &"haste", &"momentum", &"quick_draw", &"turbo", &"unequality", &"unity", &"bargain", &"delirium", &"energy_cycle"]:
		var ability := slot_ability(slot, id)
		if ability == null: continue
		var applies := get_single_bonus(slot, id, is_attacking) > 0
		if applies and int(slot.get_meta("assault_announced_" + String(id), -1)) != bf.turn_number:
			slot.set_meta("assault_announced_" + String(id), bf.turn_number)
			await bf.ability_presentation_controller.show_trigger(ability, "+" + str(get_single_bonus(slot, id, is_attacking)) + " AP")


func get_single_bonus(slot: Node, id: StringName, is_attacking: bool) -> int:
	var card := bf.get_slot_card_data(slot)
	var owner := String(slot.get_meta("owner", ""))
	match id:
		&"battle_positions": return 1 if int(global_bonus_turn.get(owner, 0)) == 1 else 0
		&"overrun": return 2 if int(global_bonus_turn.get(owner, 0)) == 2 else 0
		&"challenger": return 2 if is_attacking else 0
		&"challenger_advanced": return 3 if is_attacking else 0
		&"honed_edge": return 2 if is_attacking else 0
		&"brutality": return int(float(get_hand_size(owner)) / 2.0)
		&"duelist": return 2 if count_front_units(owner) == 1 else 0
		&"glean_strike": return 3 if int(insight_used_turn.get(owner, -1)) == bf.turn_number else 0
		&"haste": return 2 if int(promotion_turn.get(owner, -1)) == bf.turn_number else 0
		&"momentum": return int(slot.get_meta("assault_momentum_bonus", 0)) if int(slot.get_meta("assault_momentum_turn", -1)) == bf.turn_number else 0
		&"quick_draw": return 1 if bool(triggered_gambit_last_round.get(owner, false)) else 0
		&"turbo": return 2 if another_unit_attacked(owner, slot) else 0
		&"unequality": return count_non_orc_units(owner)
		&"unity": return count_same_race_front(owner, card.race)
		&"bargain": return 2 if int(slot.get_meta("assault_bargain_turn", -1)) == bf.turn_number else 0
		&"delirium": return 3 if int(slot.get_meta("assault_delirium_turn", -1)) == bf.turn_number else 0
		&"energy_cycle": return 2 if int(slot.get_meta("assault_energy_bonus_turn", -1)) == bf.turn_number else 0
	return 0


func get_hand_size(owner: String) -> int:
	return bf.hand.cards.size() if owner == "player" else bf.ai_hand.size()


func count_front_units(owner: String) -> int:
	var count := 0
	for lane in ["left", "middle", "right"]:
		if bf.is_unit_card(bf.get_slot_card_data(bf.find_slot_by_owner_row_lane(owner, "front", lane))): count += 1
	return count


func count_non_orc_units(owner: String) -> int:
	var count := 0
	for slot in bf.board_slots.get_children():
		if String(slot.get_meta("owner", "")) != owner or bool(slot.get_meta("face_down", false)): continue
		var card := bf.get_slot_card_data(slot)
		if bf.is_unit_card(card) and not card.race.to_lower().contains("orc") and not card.race.to_lower().contains("orkhael"): count += 1
	return count


func count_same_race_front(owner: String, race: String) -> int:
	var count := 0
	for lane in ["left", "middle", "right"]:
		var card := bf.get_slot_card_data(bf.find_slot_by_owner_row_lane(owner, "front", lane))
		if bf.is_unit_card(card) and card.race.to_lower() == race.to_lower(): count += 1
	return count


func another_unit_attacked(owner: String, slot: Node) -> bool:
	for raw_id in (attacked_slot_ids.get(owner, {}) as Dictionary).keys():
		if int(raw_id) != slot.get_instance_id(): return true
	return false


func note_attack(slot: Node) -> void:
	if slot == null: return
	var owner := String(slot.get_meta("owner", ""))
	attacked_slot_ids[owner][slot.get_instance_id()] = true


func note_insight_used(owner: String) -> void:
	insight_used_turn[owner] = bf.turn_number


func note_promotion(owner: String) -> void:
	promotion_turn[owner] = bf.turn_number


func note_gambit_triggered(owner: String) -> void:
	triggered_gambit_this_round[owner] = true


func start_new_round() -> void:
	for owner in ["player", "enemy"]:
		triggered_gambit_last_round[owner] = bool(triggered_gambit_this_round[owner])
		triggered_gambit_this_round[owner] = false
		attacked_slot_ids[owner].clear()
		global_bonus_turn[owner] = 0
	used_active_keys.clear()


func can_unit_attack(slot: Node) -> bool:
	return slot == null or int(slot.get_meta("assault_energy_forfeit_turn", -1)) != bf.turn_number


func can_activate(slot: Node, ability: AbilityData) -> bool:
	return can_activate_for_owner(slot, ability, "player")


func can_activate_for_owner(slot: Node, ability: AbilityData, owner: String) -> bool:
	if slot == null or ability == null or ability.category.to_lower() != "assault" or ability.trigger != "active": return false
	if String(slot.get_meta("owner", "")) != owner or bool(slot.get_meta("face_down", false)): return false
	if bf.current_phase != bf.BattlePhase.COMBAT: return false
	if owner == "player" and not bf.can_player_take_priority_action_in_lane(bf.get_slot_lane(slot)): return false
	var key := usage_key(slot, ability)
	if used_active_keys.has(key): return false
	if ability.ability_id == &"bargain" and get_hand_size(owner) <= 0: return false
	if ability.ability_id == &"energy_cycle": return not adjacent_friendly_units(slot).is_empty()
	return true


func usage_key(slot: Node, ability: AbilityData) -> String:
	return str(slot.get_instance_id()) + ":" + String(ability.ability_id) + ":" + str(bf.turn_number)


func activate(slot: Node, ability: AbilityData, owner: String = "player") -> Dictionary:
	var success := false
	var consumes_attack := false
	match ability.get_handler_id():
		&"bargain":
			var discarded := await discard_own_choice(owner, ability)
			if discarded:
				slot.set_meta("assault_bargain_turn", bf.turn_number)
				await bf.ability_presentation_controller.show_trigger(ability, "+2 AP this Combat Phase")
				success = true
		&"delirium":
			slot.set_meta("assault_delirium_turn", bf.turn_number)
			slot.set_meta("assault_delirium_pending", true)
			await bf.ability_presentation_controller.show_trigger(ability, "+3 AP; unit discarded after its clash")
			success = true
		&"energy_cycle":
			var candidates := adjacent_friendly_units(slot)
			var target: Node = candidates.pick_random() as Node
			if owner == "player":
				target = await bf.ability_presentation_controller.choose_slot(candidates, ability, "Choose an adjacent allied unit")
			if target != null:
				target.set_meta("assault_energy_bonus_turn", bf.turn_number)
				slot.set_meta("assault_energy_forfeit_turn", bf.turn_number)
				await bf.ability_presentation_controller.show_trigger(ability, bf.get_slot_card_data(target).card_name + " gains +2 AP")
				success = true
				consumes_attack = true
	if success: used_active_keys[usage_key(slot, ability)] = true
	return {"success": success, "consumes_attack": consumes_attack}


func discard_own_choice(owner: String, ability: AbilityData) -> bool:
	var cards: Array[CardData] = bf.attrition_controller.player_hand_cards() if owner == "player" else bf.ai_hand.duplicate()
	if cards.is_empty(): return false
	var chosen := cards.pick_random() as CardData
	if owner == "player":
		var result := await bf.ability_presentation_controller.choose_card(cards, ability, bf.get_insight_world_position("player_hand"), bf.get_insight_world_position("player_discard"))
		if bool(result.get("cancelled", false)): return false
		chosen = cards[clampi(int(result.get("index", 0)), 0, cards.size() - 1)]
		bf.attrition_controller.remove_player_hand_card(chosen)
	else: bf.ai_hand.erase(chosen)
	bf.discard_cards_with_animation([chosen], bf.get_node_or_null("CardAnimationManager/PlayerHandOrigin") if owner == "player" else bf.get_node_or_null("CardAnimationManager/EnemyHandOrigin"), owner)
	await bf.economy_controller.on_card_discarded_from_hand(owner, chosen)
	return true


func adjacent_friendly_units(slot: Node) -> Array[Node]:
	var result: Array[Node] = []
	var owner := String(slot.get_meta("owner", ""))
	for lane in bf.get_adjacent_lanes(bf.get_slot_lane(slot)):
		var candidate := bf.find_slot_by_owner_row_lane(owner, "front", lane)
		if bf.is_unit_card(bf.get_slot_card_data(candidate)): result.append(candidate)
	return result


func on_clash_won(winner_slot: Node, _defeated_card: CardData) -> void:
	if winner_slot == null: return
	var owner := String(winner_slot.get_meta("owner", ""))
	for id in [&"bloodthirst", &"pierce", &"ravage"]:
		var ability := slot_ability(winner_slot, id)
		if ability == null: continue
		await bf.ability_presentation_controller.show_trigger(ability)
		match id:
			&"bloodthirst": winner_slot.set_meta("assault_bloodthirst_extra_turn", bf.turn_number)
			&"pierce", &"ravage": bf.add_aurion("player" if owner == "player" else "ai", 1, ability.ability_name)


func has_bloodthirst_extra(slot: Node) -> bool:
	return slot != null and int(slot.get_meta("assault_bloodthirst_extra_turn", -1)) == bf.turn_number


func consume_bloodthirst_extra(slot: Node) -> void:
	if slot != null: slot.set_meta("assault_bloodthirst_extra_turn", -1)


func finish_clash(attacker_slot: Node) -> void:
	if attacker_slot == null or not bool(attacker_slot.get_meta("assault_delirium_pending", false)): return
	attacker_slot.set_meta("assault_delirium_pending", false)
	var card := bf.get_slot_card_data(attacker_slot)
	if card != null:
		var ability := slot_ability(attacker_slot, &"delirium")
		await bf.ability_presentation_controller.show_trigger(ability, card.card_name + " discarded after clash")
		bf.send_slot_card_to_discard(attacker_slot)
