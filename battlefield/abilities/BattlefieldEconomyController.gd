class_name BattlefieldEconomyController
extends RefCounted

var bf: BattlefieldManager
var used_active_keys: Dictionary = {}
var focus_discount: Dictionary = {"player": 0, "enemy": 0}
var pending_temp_tp: Dictionary = {"player": 0, "enemy": 0}
var pending_temp_cards: Dictionary = {"player": [], "enemy": []}


func _init(owner_battlefield: BattlefieldManager) -> void:
	bf = owner_battlefield


func opposite(owner: String) -> String:
	return "enemy" if owner == "player" else "player"


func get_card_ability(card: CardData, id: StringName) -> AbilityData:
	if card == null: return null
	for ability in card.get_abilities():
		if ability != null and ability.category.to_lower() == "economy" and ability.ability_id == id: return ability
	return null


func slot_ability(slot: Node, id: StringName) -> AbilityData:
	if slot == null or bool(slot.get_meta("face_down", false)): return null
	var result := get_card_ability(bf.get_slot_card_data(slot), id)
	if result != null: return result
	if slot.has_method("get_equipment_cards") and not bf.is_equipment_suppressed(slot):
		for equipment in slot.call("get_equipment_cards"):
			result = get_card_ability(equipment as CardData, id)
			if result != null: return result
	return null


func resolve_deployment(card: CardData, slot: Node, owner: String) -> bool:
	if card == null or slot == null or bool(slot.get_meta("face_down", false)): return false
	var resolved := false
	for ability in card.get_abilities():
		if ability == null or ability.category.to_lower() != "economy": continue
		var id := ability.get_handler_id()
		var should_activate := ability.trigger == "on_deploy" or (bf.is_gambit_card(card) and ability.trigger in ["passive", "on_draw"]) or id in [&"profit", &"wrath_of_aurion", &"rykards_plight", &"arms_race"]
		if not should_activate: continue
		match id:
			&"excavate": resolved = await excavate(owner, ability, 1) or resolved
			&"double_excavate": resolved = await excavate(owner, ability, 2) or resolved
			&"profit":
				await draw_cards(owner, 2, ability)
				resolved = true
			&"harvest": resolved = await harvest(owner, ability) or resolved
			&"tithe":
				await bf.ability_presentation_controller.show_trigger(ability, "Draw 1; opponent loses 1 TP this round")
				await draw_cards(owner, 1, null)
				lose_tp_temporarily(opposite(owner), 1)
				resolved = true
			&"transmute": resolved = await transmute(owner, ability) or resolved
			&"old_flame":
				await bf.ability_presentation_controller.show_trigger(ability, "Opponent loses 1 Permanent Tribute")
				remove_permanent_tribute(opposite(owner))
				resolved = true
			&"arms_race", &"rykards_plight": resolved = await equip_from_deck(owner, slot, ability, 2, false) or resolved
			&"wrath_of_aurion": resolved = await equip_from_deck(owner, slot, ability, 1, true) or resolved
	return resolved


func resolve_hidden_gambit(card: CardData, slot: Node, owner: String) -> bool:
	return await resolve_deployment(card, slot, owner)


func draw_cards(owner: String, count: int, ability: AbilityData = null) -> Array[CardData]:
	var drawn: Array[CardData] = []
	if ability != null: await bf.ability_presentation_controller.show_trigger(ability, "Draw " + str(count) + " card(s)")
	for i in range(count):
		var card: CardData = null
		if owner == "player":
			card = bf.player_deck.draw_top_card()
			if card == null: break
			var target := bf.get_node_or_null("CardAnimationManager/PlayerHandOrigin")
			if bf.card_animation_manager != null and bf.draw_pile != null and target != null:
				await bf.card_animation_manager.animate_card_between_nodes(card, bf.draw_pile, target, false)
			if not bf.hand.add_card_to_hand(card):
				bf.discard_pile.add_card(card)
			bf.draw_pile.set_card_count(bf.player_deck.cards_remaining())
		else:
			if bf.ai_deck.is_empty(): break
			card = bf.ai_deck.pop_back() as CardData
			bf.ai_hand.append(card)
			bf.update_ai_visuals()
		drawn.append(card)
	return drawn


func harvest(owner: String, ability: AbilityData) -> bool:
	var card: CardData = null
	if owner == "player": card = bf.player_deck.draw_top_card()
	elif not bf.ai_deck.is_empty(): card = bf.ai_deck.pop_back() as CardData
	if card == null: return false
	bf.show_mobility_prompt(ability.ability_name.to_upper() + "  -  " + card.card_name + " becomes Permanent Tribute", bf.ECONOMY_PROMPT_ICON_PATH)
	var source := bf.draw_pile if owner == "player" else bf.get_enemy_visual_target("EnemyDeckVisual")
	var target := bf.tribute_pile if owner == "player" else bf.get_enemy_visual_target("EnemyTributePileVisual")
	if bf.card_animation_manager != null and source != null and target != null:
		await bf.card_animation_manager.animate_card_reveal_between_nodes(card, source, target, false, 0.95)
	else:
		await bf.get_tree().create_timer(2.05).timeout
	await bf.hide_mobility_prompt()
	if owner == "player":
		bf.tribute_manager.add_permanent_tribute(card)
		bf.tribute_pile.add_card(card)
		bf.draw_pile.set_card_count(bf.player_deck.cards_remaining())
	else:
		bf.ai_tribute.append(card)
		bf.ai_perm_tp += 1
		bf.ai_current_perm_tp += 1
		bf.ai_current_tp += 1
		bf.update_ai_visuals()
	return true


func excavate(owner: String, ability: AbilityData, count: int) -> bool:
	var cards: Array[CardData] = []
	for i in range(count):
		var card := bf.discard_pile.remove_top_card() if owner == "player" else (bf.ai_discard.pop_back() as CardData if not bf.ai_discard.is_empty() else null)
		if card != null: cards.append(card)
	if cards.is_empty(): return false
	await bf.ability_presentation_controller.show_trigger(ability, "Return " + str(cards.size()) + " card(s) from discard")
	if owner == "player":
		for card in cards: bf.hand.add_card_to_hand(card)
	else:
		bf.ai_hand.append_array(cards)
		bf.update_ai_visuals()
	return true


func transmute(owner: String, ability: AbilityData) -> bool:
	var hand_size := bf.hand.cards.size() if owner == "player" else bf.ai_hand.size()
	if hand_size < 2: return false
	await bf.ability_presentation_controller.show_trigger(ability, "Discard 2; draw 3", true)
	var discarded := await bf.attrition_controller.discard_from_hand(owner, 2, ability, false, owner == "player")
	if discarded.size() < 2: return false
	await draw_cards(owner, 3, null)
	return true


func equip_from_deck(owner: String, source_slot: Node, ability: AbilityData, amount: int, source_only: bool) -> bool:
	var equipped := 0
	for i in range(amount):
		var deck: Array = bf.player_deck.deck if owner == "player" else bf.ai_deck
		var equipment: Array[CardData] = []
		for candidate in deck:
			if bf.is_equipment_card(candidate as CardData): equipment.append(candidate as CardData)
		if equipment.is_empty(): break
		var chosen := equipment.pick_random() as CardData
		if owner == "player":
			var choice := await bf.ability_presentation_controller.choose_card(equipment, ability, bf.draw_pile.global_position, (source_slot as Node3D).global_position)
			if bool(choice.get("cancelled", false)): break
			chosen = equipment[clampi(int(choice.get("index", 0)), 0, equipment.size() - 1)]
		var targets: Array[Node] = []
		if source_only: targets.append(source_slot)
		else:
			for lane in ["left", "middle", "right"]:
				var candidate_target := bf.find_slot_by_owner_row_lane(owner, "front", lane)
				if candidate_target != null and candidate_target.has_method("can_attach_equipment") and candidate_target.call("can_attach_equipment"): targets.append(candidate_target)
		if targets.is_empty(): break
		var selected_target: Node = targets.pick_random() as Node
		if owner == "player":
			selected_target = await bf.ability_presentation_controller.choose_slot(targets, ability, "Choose a unit to equip " + chosen.card_name)
		if selected_target == null or not selected_target.call("attach_equipment", bf.TEST_CARD_SCENE, chosen): break
		deck.erase(chosen)
		equipped += 1
		await bf.ability_presentation_controller.show_trigger(ability, chosen.card_name + " equipped")
	if owner == "player":
		bf.player_deck.deck.shuffle()
		bf.player_deck.deck_changed.emit(bf.player_deck.cards_remaining())
		bf.draw_pile.set_card_count(bf.player_deck.cards_remaining())
	else:
		bf.ai_deck.shuffle()
		bf.update_ai_visuals()
	return equipped > 0


func on_clash_won(winner_owner: String, winner_slot: Node) -> void:
	if winner_slot != null:
		var bargain := slot_ability(winner_slot, &"hard_bargain")
		if bargain != null:
			await bf.ability_presentation_controller.show_trigger(bargain, "+1 Aurion")
			bf.add_aurion("player" if winner_owner == "player" else "ai", 1, bargain.ability_name)


func on_unit_killed(killer_owner: String) -> void:
	for slot in field_slots(killer_owner):
		var endless := slot_ability(slot, &"endless_stream")
		if endless == null:
			continue
		await bf.ability_presentation_controller.show_trigger(endless, "Unit defeated: draw 1")
		await draw_cards(killer_owner, 1, null)


func on_unit_destroyed(defeated_owner: String, defeated_card: CardData, was_attacked: bool = true, by_gambit: bool = false) -> void:
	var martyr := get_card_ability(defeated_card, &"martyrdom")
	if martyr != null and was_attacked:
		await bf.ability_presentation_controller.show_trigger(martyr, "+1 Aurion")
		bf.add_aurion("player" if defeated_owner == "player" else "ai", 1, martyr.ability_name)
	var hard := get_card_ability(defeated_card, &"hard_bargain")
	if hard != null:
		await bf.ability_presentation_controller.show_trigger(hard, "Lose 2 Aurion")
		bf.lose_aurion(defeated_owner, 2, hard.ability_name)
	var rebound := get_card_ability(defeated_card, &"rebound")
	if rebound != null and by_gambit:
		await draw_cards(defeated_owner, 2, rebound)
	var soul := get_card_ability(defeated_card, &"soul_tribute")
	if soul != null:
		await bf.ability_presentation_controller.show_trigger(soul, "+1 Temporary TP next round")
		pending_temp_tp[defeated_owner] = int(pending_temp_tp[defeated_owner]) + 1
		(pending_temp_cards[defeated_owner] as Array).append(defeated_card)
		if defeated_owner == "player": bf.discard_pile.remove_card(defeated_card)
		else: bf.ai_discard.erase(defeated_card)


func on_card_discarded_from_hand(owner: String, card: CardData) -> void:
	var recycle := get_card_ability(card, &"recycle")
	if recycle != null: await draw_cards(owner, 2, recycle)
	for slot in field_slots(owner):
		var resilience := slot_ability(slot, &"resilience")
		if resilience != null:
			await bf.ability_presentation_controller.show_trigger(resilience, "Discarded a card: draw 1")
			await draw_cards(owner, 1, null)


func on_successful_parry(owner: String, cards: Array[CardData]) -> void:
	if cards.size() >= 2:
		var chain := get_card_ability(cards[1], &"chain_link")
		if chain != null:
			await bf.ability_presentation_controller.show_trigger(chain, "Added to Permanent Tribute")
			move_parry_card_to_tribute(owner, cards[1], true)
		var refuel := get_card_ability(cards[1], &"refuel")
		if refuel != null: await draw_cards(owner, 2, refuel)
	if cards.size() == 1:
		var shield := get_card_ability(cards[0], &"logistics_shield")
		if shield != null:
			await bf.ability_presentation_controller.show_trigger(shield, "+1 Temporary TP next round")
			move_parry_card_to_tribute(owner, cards[0], false)
			pending_temp_tp[owner] = int(pending_temp_tp[owner]) + 1
			(pending_temp_cards[owner] as Array).append(cards[0])


func move_parry_card_to_tribute(owner: String, card: CardData, permanent: bool) -> void:
	if owner == "player":
		bf.discard_pile.remove_card(card)
		bf.tribute_pile.add_card(card)
		if permanent: bf.tribute_manager.add_permanent_tribute(card)
	else:
		bf.ai_discard.erase(card)
		bf.ai_tribute.append(card)
		if permanent:
			bf.ai_perm_tp += 1
			bf.ai_current_perm_tp += 1
			bf.ai_current_tp += 1


func get_deployment_discount(card: CardData, _slot: Node, owner: String, is_promotion: bool, face_down: bool) -> int:
	if card == null or face_down: return 0
	var discount := 0
	if is_promotion and get_card_ability(card, &"loyalty") != null: discount += 1
	if bf.is_unit_card(card) and has_logistics_for_faction(owner, card.race): discount += 1
	if bf.is_gambit_card(card) and int(focus_discount.get(owner, 0)) > 0: discount += 2
	return discount


func consume_focus_discount(owner: String, card: CardData, face_down: bool) -> void:
	if card != null and bf.is_gambit_card(card) and not face_down and int(focus_discount.get(owner, 0)) > 0:
		focus_discount[owner] = 0


func has_logistics_for_faction(owner: String, faction: String) -> bool:
	for slot in field_slots(owner):
		var primary := bf.get_slot_card_data(slot)
		for id in [&"logistic_specialist", &"logistic_specialist_unit", &"logistic_specialist_equipment"]:
			if slot_ability(slot, id) != null and primary != null and primary.race.to_lower() == faction.to_lower(): return true
	return false


func field_slots(owner: String) -> Array[Node]:
	var result: Array[Node] = []
	for slot in bf.board_slots.get_children():
		if String(slot.get_meta("owner", "")) == owner and not bool(slot.get_meta("face_down", false)) and bf.get_slot_card_data(slot) != null: result.append(slot)
	return result


func can_activate(slot: Node, ability: AbilityData) -> bool:
	return can_activate_for_owner(slot, ability, "player")


func can_activate_for_owner(slot: Node, ability: AbilityData, owner: String) -> bool:
	if slot == null or ability == null or ability.category.to_lower() != "economy" or ability.trigger != "active": return false
	if String(slot.get_meta("owner", "")) != owner or bool(slot.get_meta("face_down", false)): return false
	if bf.current_phase != bf.BattlePhase.COMBAT: return false
	if owner == "player" and not bf.can_player_take_priority_action_in_lane(bf.get_slot_lane(slot)): return false
	return not used_active_keys.has(usage_key(slot, ability))


func usage_key(slot: Node, ability: AbilityData) -> String:
	return str(slot.get_instance_id()) + ":" + String(ability.ability_id) + ":" + str(bf.turn_number)


func activate(slot: Node, ability: AbilityData, owner: String = "player") -> Dictionary:
	if ability.get_handler_id() != &"focus": return {"success": false}
	focus_discount[owner] = 2
	used_active_keys[usage_key(slot, ability)] = true
	await bf.ability_presentation_controller.show_trigger(ability, "Next face-up Gambit costs 2 less TP")
	return {"success": true, "consumes_attack": true}


func activate_focus_on_pass(slot: Node) -> bool:
	var ability := slot_ability(slot, &"focus")
	if ability == null or used_active_keys.has(usage_key(slot, ability)): return false
	return bool((await activate(slot, ability, String(slot.get_meta("owner", "")))).get("success", false))


func on_monarch_strike(attacker_slot: Node, defender_owner: String) -> void:
	var siphon := slot_ability(attacker_slot, &"siphon")
	if siphon != null:
		await bf.ability_presentation_controller.show_trigger(siphon, "Opponent loses 1 Aurion")
		bf.lose_aurion(defender_owner, 1, siphon.ability_name)


func on_battleplan_completed(owner: String) -> void:
	for slot in field_slots(owner):
		var sovereign := slot_ability(slot, &"sovereign")
		if sovereign != null:
			await bf.ability_presentation_controller.show_trigger(sovereign, "+1 Aurion for objective completion")
			bf.add_aurion("player" if owner == "player" else "ai", 1, sovereign.ability_name)


func start_new_round() -> void:
	for owner in ["player", "enemy"]:
		for slot in field_slots(owner):
			var silent := slot_ability(slot, &"silent_skill")
			if silent != null and not (bf.assault_controller.attacked_slot_ids.get(owner, {}) as Dictionary).has(slot.get_instance_id()):
				pending_temp_tp[owner] = int(pending_temp_tp[owner]) + 1
				await bf.ability_presentation_controller.show_trigger(silent, "+1 Temporary TP")
		var amount := int(pending_temp_tp[owner])
		if owner == "enemy":
			bf.ai_current_perm_tp = bf.ai_perm_tp
			bf.ai_temp_tp = 0
			bf.ai_current_tp = bf.ai_current_perm_tp
		if amount > 0:
			if owner == "player":
				bf.tribute_manager.temporary_tp += amount
				for card in pending_temp_cards[owner]:
					if not bf.tribute_manager.temporary_tribute_cards.has(card):
						bf.tribute_manager.temporary_tribute_cards.append(card)
					if not bf.tribute_pile.tribute_cards.has(card):
						bf.tribute_pile.add_card(card)
				bf.tribute_manager.refresh_tribute_points()
			else:
				bf.ai_temp_tp = amount
				bf.ai_current_tp = bf.ai_current_perm_tp + amount
				bf.ai_tribute.append_array(pending_temp_cards[owner])
		pending_temp_tp[owner] = 0
		pending_temp_cards[owner].clear()
	used_active_keys.clear()


func lose_tp_temporarily(owner: String, amount: int) -> void:
	if owner == "player" and bf.tribute_manager != null:
		var loss := mini(amount, bf.tribute_manager.current_tribute_points)
		var temp_loss := mini(loss, bf.tribute_manager.temporary_tp)
		bf.tribute_manager.temporary_tp -= temp_loss
		bf.tribute_manager.current_permanent_tp -= loss - temp_loss
		bf.tribute_manager.refresh_tribute_points()
	elif owner == "enemy":
		var loss := mini(amount, bf.ai_current_tp)
		var temp_loss := mini(loss, bf.ai_temp_tp)
		bf.ai_temp_tp -= temp_loss
		bf.ai_current_perm_tp -= loss - temp_loss
		bf.ai_current_tp -= loss
		bf.update_ai_visuals()


func remove_permanent_tribute(owner: String) -> void:
	if owner == "player" and bf.tribute_manager != null and not bf.tribute_manager.permanent_tribute_cards.is_empty():
		var card: CardData = bf.tribute_manager.permanent_tribute_cards.pop_back() as CardData
		bf.tribute_manager.permanent_tp = maxi(0, bf.tribute_manager.permanent_tp - 1)
		bf.tribute_manager.current_permanent_tp = maxi(0, bf.tribute_manager.current_permanent_tp - 1)
		bf.tribute_manager.refresh_tribute_points()
		bf.tribute_pile.tribute_cards.erase(card)
		bf.tribute_pile.build_stack()
	elif owner == "enemy" and not bf.ai_tribute.is_empty():
		bf.ai_tribute.pop_back()
		bf.ai_perm_tp = maxi(0, bf.ai_perm_tp - 1)
		bf.ai_current_perm_tp = maxi(0, bf.ai_current_perm_tp - 1)
		bf.ai_current_tp = maxi(0, bf.ai_current_tp - 1)
		bf.update_ai_visuals()
