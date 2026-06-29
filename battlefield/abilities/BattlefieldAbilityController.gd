class_name BattlefieldAbilityController
extends RefCounted

## Domain controller extracted from BattlefieldManager. The manager facade preserves
## scene callbacks and dynamic-call compatibility.

var bf: BattlefieldManager


func _init(owner_battlefield: BattlefieldManager) -> void:
	bf = owner_battlefield


func handle_card_deployed(card_data: CardData, slot: Node = null) -> void:
	if card_data == null:
		return

	bf.ai_memory_note_player_deployment(card_data, slot)

	# A set card has not entered play yet. Its deployment abilities become
	# eligible only when the card is revealed or when it is placed face up.
	if slot != null and bool(slot.get_meta("face_down", false)):
		return

	if await bf.resolve_mobility_deployment(card_data, slot, "player"):
		return

	var resolved_insight := await bf.resolve_insight_abilities(card_data, &"on_deploy")

	if resolved_insight:
		return

	var ability_text_lower: String = card_data.get_ability_text().to_lower()

	if ability_text_lower == "":
		return

	if ability_text_lower.contains("on deploy") or ability_text_lower.contains("when deployed"):
		if bf.ability_requires_choice(card_data):
			if bf.ability_prompt_panel != null:
				bf.ability_prompt_panel.show_for_card(card_data)
		else:
			bf.log_msg("On-deploy ability triggered: " + card_data.card_name)
			bf.log_msg(card_data.get_ability_text())

		return

	bf.log_msg("Passive ability active: " + card_data.card_name)


func resolve_mobility_deployment(card_data: CardData, slot: Node, owner_name: String = "player") -> bool:
	if card_data == null or slot == null:
		return false
	var mobility_abilities: Array[AbilityData] = []
	for ability in card_data.get_abilities():
		if ability != null and ability.category.to_lower() == "mobility":
			mobility_abilities.append(ability)
	if mobility_abilities.is_empty():
		return false
	if bf.is_gambit_card(card_data):
		if bool(slot.get_meta("face_down", false)):
			return false
		for ability in mobility_abilities:
			await bf.animate_gambit_activation(slot, card_data, false, owner_name)
			await bf.resolve_mobility_gambit_effect(ability, owner_name)
			break
		return true
	for ability in mobility_abilities:
		if ability.trigger == "on_deploy" and ability.get_handler_id() == &"reassign":
			if owner_name == "player":
				await bf.resolve_reassign(ability)
			return true
	return false


func resolve_mobility_gambit_effect(ability: AbilityData, caster_owner: String) -> bool:
	if ability == null:
		return false
	var result := AbilityResolver.resolve(ability, bf.build_ability_context({"owner": caster_owner}))
	if not bool(result.get("success", false)):
		return false
	match ability.get_handler_id():
		&"imperial_decree":
			return await bf.resolve_imperial_decree(ability, caster_owner)
		&"flank_swap":
			return await bf.resolve_flank_swap(ability, caster_owner)
		&"vortex":
			return await bf.resolve_vortex(ability, caster_owner)
	return true


func resolve_imperial_decree(ability: AbilityData, caster_owner: String) -> bool:
	var target_owner := "enemy" if caster_owner == "player" else "player"
	var candidates: Array[Node] = []
	for lane in ["left", "middle", "right"]:
		var slot := bf.find_slot_by_owner_row_lane(target_owner, "front", lane)
		var card := bf.get_slot_card_data(slot)
		if bf.is_unit_card(card) and bf.get_slot_combat_ap(slot) <= 6:
			candidates.append(slot)
	if candidates.is_empty():
		await bf.show_timed_mobility_message(ability.ability_name + "  -  No legal target")
		return false
	if caster_owner != "player":
		bf.send_slot_card_to_discard(candidates.pick_random())
		return true
	var target := await bf.choose_mobility_slot(candidates, ability.ability_name + "  -  Choose a unit with 6 AP or less")
	if target == null:
		return false
	bf.send_slot_card_to_discard(target)
	return true


func resolve_vortex(ability: AbilityData, caster_owner: String) -> bool:
	var occupied: Array[Node] = []
	for lane in ["left", "middle", "right"]:
		var front_slot := bf.find_slot_by_owner_row_lane(caster_owner, "front", lane)
		if bf.is_unit_card(bf.get_slot_card_data(front_slot)):
			occupied.append(front_slot)
	if occupied.size() < 2:
		await bf.show_timed_mobility_message(ability.ability_name + "  -  Two frontline units required")
		return false
	var target: Node = null
	if caster_owner == "player":
		target = await bf.choose_mobility_slot(occupied, ability.ability_name + "  -  Choose the lane to keep")
	else:
		target = occupied.pick_random()
	if target == null:
		return false
	var donors: Array[Node] = []
	for slot in occupied:
		if slot != target:
			donors.append(slot)
	var donor: Node = null
	if caster_owner == "player":
		donor = await bf.choose_mobility_slot(donors, ability.ability_name + "  -  Choose the unit to merge")
	else:
		donor = donors.pick_random()
	if donor == null:
		return false
	var donor_snapshot: Dictionary = donor.call("take_slot_snapshot")
	await bf.animate_snapshot_between_slots(donor_snapshot, donor, target)
	var donor_card := donor_snapshot.get("card") as CardData
	if donor_card != null:
		target.call("add_stacked_unit", bf.TEST_CARD_SCENE, donor_card)
	for stacked in donor_snapshot.get("stacked_units", []):
		target.call("add_stacked_unit", bf.TEST_CARD_SCENE, stacked as CardData)
	for equipment in donor_snapshot.get("equipment", []):
		target.call("attach_equipment", bf.TEST_CARD_SCENE, equipment as CardData, true)
	target.set_meta("vortex_bonus_turn", bf.turn_number)
	return true


func resolve_reassign(ability: AbilityData) -> void:
	var keep_rearranging := true
	while keep_rearranging:
		var occupied: Array[Node] = []
		for slot in bf.get_player_front_slots():
			if bf.is_unit_card(bf.get_slot_card_data(slot)):
				occupied.append(slot)
		if occupied.is_empty():
			return
		var source := await bf.choose_mobility_slot(occupied, ability.ability_name + "  -  Choose a unit")
		if source == null:
			return
		var destinations: Array[Node] = []
		for slot in bf.get_player_front_slots():
			if slot != source:
				destinations.append(slot)
		var target := await bf.choose_mobility_slot(destinations, ability.ability_name + "  -  Choose its lane")
		if target == null:
			return
		if bf.get_slot_card_data(target) == null:
			await bf.move_slot_contents(source, target)
		else:
			await bf.swap_slot_contents(source, target)
		keep_rearranging = await bf.prompt_mobility_choice(ability.ability_name + "  -  Move another unit?", "MOVE ANOTHER", "DONE")


func show_timed_mobility_message(message: String) -> void:
	bf.show_mobility_prompt(message)
	await bf.get_tree().create_timer(0.9).timeout
	await bf.hide_mobility_prompt()


func resolve_vanish_when_targeted(slot: Node, card_data: CardData, player_defender: bool) -> bool:
	var ability := bf.slot_has_mobility_ability(slot, &"vanish")
	if ability == null or bool(slot.get_meta("vanish_used", false)):
		return false
	var use_vanish := true
	if player_defender:
		var visual := slot.call("get_placed_card_visual") as Node if slot.has_method("get_placed_card_visual") else null
		if visual != null and visual.has_method("set_usable_ability_ids"):
			var vanish_ids: Array[StringName] = [&"vanish"]
			visual.call("set_usable_ability_ids", vanish_ids)
		use_vanish = await bf.prompt_mobility_choice(ability.ability_name + "  -  Return " + card_data.card_name + " to your hand?", "VANISH", "STAY")
		if visual != null and is_instance_valid(visual) and visual.has_method("set_usable_ability_ids"):
			var no_ids: Array[StringName] = []
			visual.call("set_usable_ability_ids", no_ids)
	if not use_vanish:
		return false
	slot.set_meta("vanish_used", true)
	await bf.return_board_card_to_hand(slot, card_data, "player" if player_defender else "enemy")
	return true

func return_board_card_to_hand(slot: Node, card_data: CardData, owner_name: String) -> void:
	if slot == null or card_data == null:
		return
	var target: Node = bf.get_node_or_null("CardAnimationManager/PlayerHandOrigin")
	if owner_name == "enemy":
		target = bf.get_node_or_null("CardAnimationManager/EnemyHandOrigin")
	if bf.card_animation_manager != null and target != null:
		await bf.card_animation_manager.animate_card_between_nodes(card_data, slot, target, false)
	if slot.has_method("clear_slot"):
		slot.call("clear_slot")
	if owner_name == "enemy":
		bf.ai_hand.append(card_data)
		bf.update_ai_visuals()
	elif bf.hand != null:
		bf.hand.add_card_to_hand(card_data)


func animate_gambit_activation(slot: Node, card_data: CardData, return_to_hand: bool, owner_name: String = "player") -> void:
	if slot == null or card_data == null:
		return
	var original := slot.call("get_placed_card_visual") as Node3D if slot.has_method("get_placed_card_visual") else null
	var visual := bf.TEST_CARD_SCENE.instantiate() as Node3D
	bf.add_child(visual)
	visual.top_level = true
	visual.global_position = original.global_position if original != null else (slot as Node3D).global_position
	visual.global_rotation = original.global_rotation if original != null else (slot as Node3D).global_rotation
	visual.call("assign_card_data", card_data, false)
	if original != null:
		original.visible = false
	var base_scale := visual.scale
	var center := bf.screen_to_battle_plane(bf.get_viewport().get_visible_rect().size * 0.5, visual.global_position.y + 0.45)
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.74, 1.0)
	light.light_energy = 0.0
	light.omni_range = 3.2
	visual.add_child(light)
	var rise := bf.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.tween_property(visual, "global_position", center, 0.48)
	rise.parallel().tween_property(visual, "scale", base_scale * 1.42, 0.48)
	rise.parallel().tween_property(light, "light_energy", 4.2, 0.48)
	await rise.finished
	if bf.card_animation_manager != null:
		var activation_profile := (
			CardAnimationManager.RARE_ACTION_3D_GOLDEN_DISCARD
			if card_data.is_premium_rarity()
			else CardAnimationManager.COMMON_ACTION_3D_FLASH_DISCARD
		)
		await bf.card_animation_manager.play_card_showcase_flash_3d(visual, activation_profile)
	else:
		var pulse := bf.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(light, "light_energy", 7.0, 0.18)
		pulse.parallel().tween_property(visual, "scale", base_scale * 1.49, 0.18)
		pulse.tween_property(light, "light_energy", 3.0, 0.22)
		pulse.parallel().tween_property(visual, "scale", base_scale * 1.42, 0.22)
		await pulse.finished
	if return_to_hand:
		var hand_target: Node3D = bf.get_node_or_null("CardAnimationManager/PlayerHandOrigin") as Node3D
		if owner_name == "enemy":
			hand_target = bf.get_node_or_null("CardAnimationManager/EnemyHandOrigin") as Node3D
		if hand_target != null:
			var return_tween := bf.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			return_tween.tween_property(visual, "global_position", hand_target.global_position, 0.46)
			return_tween.parallel().tween_property(visual, "scale", base_scale * 0.72, 0.46)
			return_tween.parallel().tween_property(light, "light_energy", 0.0, 0.46)
			await return_tween.finished
	else:
		var discard_target: Node = bf.discard_pile if owner_name == "player" else bf.get_enemy_visual_target("EnemyDiscardPileVisual")
		var premium := card_data.is_premium_rarity()
		light.light_energy = 0.0
		if bf.card_animation_manager != null and discard_target != null:
			var destination := Transform3D(
				Basis.from_euler(bf.card_animation_manager.get_exact_landing_rotation(discard_target)),
				bf.card_animation_manager.get_exact_landing_position(discard_target)
			)
			await bf.card_animation_manager.vaporize_card_to_destination_3d(visual, destination, premium)
		else:
			var disperse := bf.create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
			disperse.tween_property(visual, "scale", base_scale * 0.03, 0.30)
			await disperse.finished
	visual.free()
	if slot.has_method("clear_slot"):
		slot.call("clear_slot")
	if return_to_hand:
		if owner_name == "enemy":
			bf.ai_hand.append(card_data)
		else:
			bf.hand.add_card_to_hand(card_data)
	else:
		if owner_name == "enemy":
			bf.ai_discard.append(card_data)
		else:
			bf.discard_pile.add_card(card_data)
	bf.update_ai_visuals()


func resolve_insight_abilities(card_data: CardData, trigger: StringName, extra_context: Dictionary = {}) -> bool:
	if card_data == null:
		return false
	var resolved_any := false
	for ability in card_data.get_abilities():
		if ability == null:
			continue
		if ability.category.to_lower() != "insight":
			continue
		if StringName(ability.trigger) != trigger:
			continue
		var result := await bf.resolve_insight_with_presentation(ability, extra_context)
		resolved_any = true
		if not bool(result.get("success", false)):
			bf.log_msg("Insight ability failed: " + ability.ability_name + " (" + String(result.get("reason", "unknown")) + ").")
	return resolved_any


func resolve_insight_with_presentation(ability: AbilityData, extra_context: Dictionary = {}) -> Dictionary:
	if ability == null:
		return {"success": false, "reason": "missing_ability"}
	match ability.get_handler_id():
		&"intel":
			return await bf.present_intel(ability)
		&"intelligence":
			return await bf.present_intelligence(ability)
		&"secrecy":
			return await bf.present_secrecy(ability)
		&"seer":
			return await bf.present_ai_deck_choice(ability)
		&"vantage":
			return await bf.present_ai_deck_choice(ability)
		&"vision":
			return await bf.present_vision(ability)
		&"intuition", &"true_sight":
			return await bf.present_hidden_enemy_gambit_choice(ability)
	return AbilityResolver.resolve(ability, bf.build_ability_context(extra_context))


func present_insight_cards(cards: Array[CardData], config: Dictionary) -> Dictionary:
	if bf.insight_presenter == null or cards.is_empty():
		return {"success": false, "reason": "no_cards_to_present"}
	bf.insight_presentation_active = true
	bf.insight_presenter.present(cards, config)
	var result: Dictionary = await bf.insight_presenter.completed
	bf.insight_presentation_active = false
	result["success"] = true
	return result


func pop_ai_deck_top_cards(count: int) -> Array[CardData]:
	var cards: Array[CardData] = []
	for i in range(mini(count, bf.ai_deck.size())):
		cards.append(bf.ai_deck.pop_back() as CardData)
	return cards


func pop_player_deck_top_cards(count: int) -> Array[CardData]:
	var cards: Array[CardData] = []
	if bf.player_deck == null:
		return cards
	for i in range(mini(count, bf.player_deck.deck.size())):
		var card := bf.player_deck.draw_top_card()
		if card != null:
			cards.append(card)
	if bf.draw_pile != null:
		bf.draw_pile.set_card_count(bf.player_deck.cards_remaining())
	return cards


func peek_player_deck_top_cards(count: int) -> Array[CardData]:
	var cards: Array[CardData] = []
	if bf.player_deck == null:
		return cards
	for offset in range(mini(count, bf.player_deck.deck.size())):
		cards.append(bf.player_deck.deck[bf.player_deck.deck.size() - 1 - offset] as CardData)
	return cards


func get_insight_world_position(source_name: String) -> Vector3:
	match source_name:
		"enemy_deck":
			if bf.opponent_visuals != null and bf.opponent_visuals.deck_root != null:
				return bf.opponent_visuals.deck_root.global_position
		"enemy_hand":
			if bf.opponent_visuals != null and bf.opponent_visuals.hand_root != null:
				return bf.opponent_visuals.hand_root.global_position
		"enemy_discard":
			if bf.opponent_visuals != null and bf.opponent_visuals.discard_root != null:
				return bf.opponent_visuals.discard_root.global_position
		"player_deck":
			if bf.draw_pile != null:
				return bf.draw_pile.global_position
		"player_hand":
			var hand_origin := bf.get_node_or_null("CardAnimationManager/PlayerHandOrigin") as Node3D
			if hand_origin != null:
				return hand_origin.global_position
	return Vector3(0.0, 0.8, 0.8)


func present_intel(ability: AbilityData) -> Dictionary:
	var cards := bf.pop_player_deck_top_cards(3)
	if cards.is_empty():
		bf.show_phase_title("NO CARDS TO REVEAL")
		return {"success": false, "reason": "player_deck_empty"}
	var result := await bf.present_insight_cards(cards, {
		"mode": "choose",
		"ability_name": "Intel",
		"ability_description": ability.rules_text,
		"display_scale": 1.80,
		"source_position": bf.get_insight_world_position("player_deck"),
		"chosen_destination": bf.get_insight_world_position("player_hand"),
		"other_destination": bf.get_insight_world_position("player_deck") + Vector3(0.0, -0.04, 0.0),
		"lift_return_pile": bf.draw_pile,
	})
	var chosen_index := clampi(int(result.get("index", 0)), 0, cards.size() - 1)
	var chosen := cards[chosen_index]
	if bf.hand != null:
		var old_limit := bf.hand.max_hand_size
		if not bf.hand.can_accept_card():
			bf.hand.max_hand_size = old_limit + 1
		bf.hand.add_card_to_hand(chosen)
		bf.hand.max_hand_size = old_limit
	for index in range(cards.size()):
		if index != chosen_index:
			bf.player_deck.deck.insert(0, cards[index])
	if bf.draw_pile != null:
		bf.draw_pile.set_card_count(bf.player_deck.cards_remaining())
	bf.player_deck.deck_changed.emit(bf.player_deck.cards_remaining())
	return {"success": true, "cards_seen": cards, "card_taken": chosen}


func present_ai_deck_choice(ability: AbilityData) -> Dictionary:
	var cards := bf.pop_ai_deck_top_cards(3)
	if cards.is_empty():
		bf.show_phase_title("NO CARDS TO REVEAL")
		return {"success": false, "reason": "opponent_deck_empty"}
	bf.update_ai_visuals()
	var result := await bf.present_insight_cards(cards, {
		"mode": "choose",
		"ability_name": ability.ability_name,
		"ability_description": ability.rules_text,
		"display_scale": 1.42,
		"source_position": bf.get_insight_world_position("enemy_deck"),
		"chosen_destination": bf.get_insight_world_position("enemy_discard"),
		"other_destination": bf.get_insight_world_position("enemy_deck"),
	})
	var chosen_index := clampi(int(result.get("index", 0)), 0, cards.size() - 1)
	var discarded := cards[chosen_index]
	bf.ai_discard.append(discarded)
	var returned: Array[CardData] = []
	for index in range(cards.size()):
		if index != chosen_index:
			returned.append(cards[index])
	for index in range(returned.size() - 1, -1, -1):
		bf.ai_deck.append(returned[index])
	bf.update_ai_visuals()
	return {"success": true, "cards_seen": cards, "card_discarded": discarded}


func present_intelligence(ability: AbilityData) -> Dictionary:
	var cards: Array[CardData] = []
	for card in bf.ai_hand:
		cards.append(card as CardData)
	if cards.is_empty():
		bf.show_phase_title("OPPONENT HAND IS EMPTY")
		return {"success": false, "reason": "opponent_hand_empty"}
	if bf.opponent_visuals != null:
		for index in range(cards.size()):
			bf.opponent_visuals.set_hand_card_action_hidden(index, true)
	var result := await bf.present_insight_cards(cards, {
		"mode": "hidden_pick",
		"ability_name": "Intelligence",
		"ability_description": ability.rules_text,
		"face_down": true,
		"shuffle": true,
		"source_position": bf.get_insight_world_position("enemy_hand"),
	})
	if bf.opponent_visuals != null:
		for index in range(cards.size()):
			bf.opponent_visuals.set_hand_card_action_hidden(index, false)
	return {"success": true, "cards_seen": [result.get("card")]}


func present_secrecy(ability: AbilityData) -> Dictionary:
	var indexes: Array[int] = []
	for index in range(bf.ai_hand.size()):
		indexes.append(index)
	indexes.shuffle()
	var cards: Array[CardData] = []
	for index in range(mini(2, indexes.size())):
		cards.append(bf.ai_hand[indexes[index]] as CardData)
	if cards.is_empty():
		bf.show_phase_title("OPPONENT HAND IS EMPTY")
		return {"success": false, "reason": "opponent_hand_empty"}
	if bf.opponent_visuals != null:
		for index in indexes.slice(0, cards.size()):
			bf.opponent_visuals.set_hand_card_action_hidden(int(index), true)
	await bf.present_insight_cards(cards, {
		"mode": "reveal",
		"ability_name": "Secrecy",
		"ability_description": ability.rules_text,
		"display_scale": 1.56,
		"source_position": bf.get_insight_world_position("enemy_hand"),
		"return_destination": bf.get_insight_world_position("enemy_hand"),
	})
	if bf.opponent_visuals != null:
		for index in indexes.slice(0, cards.size()):
			bf.opponent_visuals.set_hand_card_action_hidden(int(index), false)
	return {"success": true, "cards_seen": cards}


func present_vision(ability: AbilityData) -> Dictionary:
	var cards := bf.peek_player_deck_top_cards(3)
	if cards.is_empty():
		bf.show_phase_title("NO CARDS TO REVEAL")
		return {"success": false, "reason": "player_deck_empty"}
	await bf.present_insight_cards(cards, {
		"mode": "reveal",
		"ability_name": "Vision",
		"ability_description": ability.rules_text,
		"display_scale": 1.42,
		"source_position": bf.get_insight_world_position("player_deck"),
		"return_destination": bf.get_insight_world_position("player_deck"),
	})
	return {"success": true, "cards_seen": cards}


func present_hidden_enemy_gambit_choice(ability: AbilityData) -> Dictionary:
	bf.insight_gambit_candidate_slots.clear()
	if bf.board_slots != null:
		for slot in bf.board_slots.get_children():
			if String(slot.get_meta("owner", "")) != "enemy":
				continue
			if String(slot.get_meta("row", "")) != "back" or not bool(slot.get_meta("face_down", false)):
				continue
			if not bf.is_gambit_card(bf.get_slot_card_data(slot)):
				continue
			bf.insight_gambit_candidate_slots.append(slot)
	if bf.insight_gambit_candidate_slots.is_empty():
		bf.show_phase_title("NO GAMBITS TO REVEAL")
		return {"success": false, "reason": "no_hidden_enemy_gambits"}
	var reveal_all := ability.get_handler_id() == &"true_sight"
	var remaining_slots: Array[Node] = bf.insight_gambit_candidate_slots.duplicate()
	var cards_seen: Array[CardData] = []
	while not remaining_slots.is_empty():
		bf.insight_gambit_candidate_slots = remaining_slots.duplicate()
		bf.insight_gambit_selection_active = true
		bf.insight_presentation_active = true
		for slot in remaining_slots:
			slot.call("set_insight_highlight", true, Color(0.18, 0.55, 1.0, 1.0))
		var chosen_slot: Node = await bf.insight_gambit_slot_chosen
		for slot in remaining_slots:
			slot.call("set_insight_highlight", false, Color.WHITE)
		bf.insight_gambit_selection_active = false
		bf.insight_presentation_active = false
		var card_data := bf.get_slot_card_data(chosen_slot)
		if card_data != null:
			cards_seen.append(card_data)
			var revealed_cards: Array[CardData] = [card_data]
			await bf.present_insight_cards(revealed_cards, {
				"mode": "reveal",
				"ability_name": ability.ability_name,
				"ability_description": ability.rules_text,
				"display_scale": 1.5,
				"source_position": (chosen_slot as Node3D).global_position,
				"return_destination": (chosen_slot as Node3D).global_position,
			})
		remaining_slots.erase(chosen_slot)
		if not reveal_all:
			break
	bf.insight_gambit_candidate_slots.clear()
	return {"success": true, "cards_seen": cards_seen}


func build_ability_context(extra_context: Dictionary = {}) -> Dictionary:
	var context := {
		"battlefield": bf,
		"log": Callable(bf, "log_msg"),
		"player_deck": bf.player_deck,
		"draw_pile": bf.draw_pile,
		"hand": bf.hand,
		"ai_deck": bf.ai_deck,
		"ai_hand": bf.ai_hand,
		"ai_discard": bf.ai_discard,
	}
	context.merge(extra_context, true)
	return context


func ability_requires_choice(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var ability_text_lower: String = card_data.get_ability_text().to_lower()
	return ability_text_lower.contains("may ") or ability_text_lower.contains("choose")

func get_slot_combat_ap_with_protection_announcements(slot: Node) -> int:
	if slot == null:
		return 0

	var card_data := bf.get_slot_card_data(slot)

	if not bf.is_unit_card(card_data):
		return 0

	var total := maxi(card_data.ap, 0)
	var owner_name := String(slot.get_meta("owner", ""))

	var shielded := bf.slot_has_protection_ability(slot, &"shielded")

	if shielded != null and owner_name != bf.combat_priority_owner:
		total += 2
		await bf.show_protection_trigger(shielded, "+2 AP while defending")

	# Solidarity is DP-only. Do not add it to combat AP.

	if slot != null and int(slot.get_meta("vortex_bonus_turn", -1)) == bf.turn_number and slot.has_method("get_stacked_unit_cards"):
		for stacked in slot.call("get_stacked_unit_cards"):
			var stacked_card := stacked as CardData

			if stacked_card != null:
				total += maxi(stacked_card.ap, 0)

	return total


func get_card_protection_ability(card_data: CardData, ability_id: StringName) -> AbilityData:
	if card_data == null:
		return null
	for ability in card_data.get_abilities():
		if ability != null and ability.category.to_lower() == "protection" and ability.ability_id == ability_id:
			return ability
	return null


func get_gambit_attack_protection(attacker_slot: Node) -> AbilityData:
	var infiltrator := bf.slot_has_protection_ability(attacker_slot, &"infiltrator")
	if infiltrator != null:
		return infiltrator
	return bf.slot_has_protection_ability(attacker_slot, &"spell_shield")


func slot_has_protection_ability(slot: Node, ability_id: StringName) -> AbilityData:
	if slot == null:
		return null
	var ability := bf.get_card_protection_ability(bf.get_slot_card_data(slot), ability_id)
	if ability != null:
		return ability
	if slot.has_method("get_equipment_cards"):
		for equipment in slot.call("get_equipment_cards"):
			ability = bf.get_card_protection_ability(equipment as CardData, ability_id)
			if ability != null:
				return ability
	return null


func show_protection_trigger(ability: AbilityData, detail: String = "") -> void:
	if ability == null:
		return

	var message := ability.ability_name.to_upper()

	if not detail.is_empty():
		message += "  -  " + detail

	bf.log_msg("Protection triggered: " + message)
	bf.show_mobility_prompt(message, bf.PROTECTION_PROMPT_ICON_PATH)
	await bf.get_tree().create_timer(0.9).timeout
	await bf.hide_mobility_prompt()


func destroy_unit_with_protection(slot: Node, opposing_slot: Node = null, from_clash: bool = false) -> bool:
	if slot == null or bf.get_slot_card_data(slot) == null:
		return false
	var plated := bf.slot_has_protection_ability(slot, &"plated")
	if plated != null and bf.discard_protection_equipment(slot, &"plated"):
		await bf.show_protection_trigger(plated, "Destruction prevented")
		return false
	var spiked := bf.slot_has_protection_ability(slot, &"spiked")
	bf.send_slot_card_to_discard(slot)
	if from_clash and spiked != null and opposing_slot != null and bf.get_slot_card_data(opposing_slot) != null:
		await bf.show_protection_trigger(spiked, "Attacker destroyed")
		await bf.destroy_unit_with_protection(opposing_slot, null, false)
	return true


func discard_protection_equipment(slot: Node, ability_id: StringName) -> bool:
	if slot == null or not slot.has_method("discard_equipment_with_ability"):
		return false
	var discarded: CardData = slot.call("discard_equipment_with_ability", ability_id)
	if discarded == null:
		return false
	bf.discard_cards_with_animation([discarded], slot, String(slot.get_meta("owner", "")))
	return true


func add_active_insight_actions_to_board_menu(slot: Node, card_data: CardData) -> void:
	if slot == null or card_data == null:
		return
	if String(slot.get_meta("owner", "")) != "player":
		return
	if bool(slot.get_meta("face_down", false)):
		return
	for ability in card_data.get_abilities():
		if ability == null:
			continue
		if ability.category.to_lower() != "insight" or ability.trigger != "active":
			continue
		var action_id := bf.BOARD_ACTION_ACTIVE_INSIGHT_BASE + bf.board_action_ability_map.size()
		bf.board_action_ability_map[action_id] = ability
		bf.board_action_menu.add_item(ability.ability_name, action_id)
		var item_index := bf.board_action_menu.get_item_count() - 1
		if not bf.can_activate_insight_ability(slot, ability):
			bf.board_action_menu.set_item_disabled(item_index, true)


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
			var action_id := bf.BOARD_ACTION_ACTIVE_INSIGHT_BASE + bf.board_action_ability_map.size()
			bf.board_action_ability_map[action_id] = ability
			bf.board_action_menu.add_item(ability.ability_name, action_id)
			var item_index := bf.board_action_menu.get_item_count() - 1
			if not bf.can_activate_mobility_ability(slot, ability):
				bf.board_action_menu.set_item_disabled(item_index, true)

func can_activate_insight_ability(slot: Node, ability: AbilityData) -> bool:
	if slot == null or ability == null:
		return false
	if bf.current_phase == bf.BattlePhase.COMBAT and bf.parry_system.active:
		return false
	var card_data := bf.get_slot_card_data(slot)
	if card_data == null:
		return false
	var usage_key := bf.get_active_insight_usage_key(slot, ability)
	if bf.used_active_insight_ability_keys.has(usage_key):
		return false
	var handler_id := ability.get_handler_id()
	if handler_id == &"true_sight" or handler_id == &"vantage":
		return bf.can_player_take_priority_action_in_lane(bf.get_slot_lane(slot))
	return true


func activate_insight_from_board_action(action_id: int, slot: Node) -> void:
	var ability := bf.board_action_ability_map.get(action_id) as AbilityData
	await bf.activate_insight_ability_from_slot(slot, ability)


func activate_insight_ability_from_slot(slot: Node, ability: AbilityData) -> void:
	if slot == null or ability == null:
		return
	if not bf.can_activate_insight_ability(slot, ability):
		bf.log_msg("Insight ability is not available right now: " + ability.ability_name)
		return
	var card_data := bf.get_slot_card_data(slot)
	var handler_id := ability.get_handler_id()
	var lane := bf.get_slot_lane(slot)
	if handler_id == &"true_sight" or handler_id == &"vantage":
		if not bf.prepare_player_lane_action(lane):
			return
	var result := await bf.resolve_insight_with_presentation(ability, {
		"card": card_data,
		"slot": slot,
		"trigger": &"active",
		"lane": lane,
	})
	if not bool(result.get("success", false)):
		bf.log_msg("Insight ability failed: " + ability.ability_name + " (" + String(result.get("reason", "unknown")) + ").")
		return
	bf.used_active_insight_ability_keys[bf.get_active_insight_usage_key(slot, ability)] = true
	if handler_id == &"true_sight" or handler_id == &"vantage":
		bf.player_passed_current_lane = true
		bf.set_lane_priority_to_ai(lane, ability.ability_name + " used instead of attacking.")
		await bf.resolve_ai_current_priority_lane(lane)


func get_active_insight_usage_key(slot: Node, ability: AbilityData) -> String:
	return str(slot.get_instance_id()) + ":" + String(ability.ability_id) + ":" + str(bf.turn_number)


func get_mobility_usage_key(slot: Node, ability: AbilityData) -> String:
	return str(slot.get_instance_id()) + ":" + String(ability.ability_id) + ":" + str(bf.turn_number)


func get_card_mobility_ability(card_data: CardData, ability_id: StringName) -> AbilityData:
	if card_data == null:
		return null
	for ability in card_data.get_abilities():
		if ability != null and ability.category.to_lower() == "mobility" and ability.ability_id == ability_id:
			return ability
	return null


func slot_has_mobility_ability(slot: Node, ability_id: StringName) -> AbilityData:
	if slot == null:
		return null
	var entries: Array = slot.call("get_ability_visual_entries") if slot.has_method("get_ability_visual_entries") else []
	for entry in entries:
		var found := bf.get_card_mobility_ability(entry.get("card") as CardData, ability_id)
		if found != null:
			return found
	return null


func get_player_front_slots() -> Array[Node]:
	var result: Array[Node] = []
	for lane in ["left", "middle", "right"]:
		var slot := bf.find_slot_by_owner_row_lane("player", "front", lane)
		if slot != null:
			result.append(slot)
	return result


func get_adjacent_lanes(lane: String) -> Array[String]:
	match lane:
		"left":
			return ["middle"]
		"middle":
			return ["left", "right"]
		"right":
			return ["middle"]
	return []


func can_activate_mobility_ability(slot: Node, ability: AbilityData) -> bool:
	if slot == null or ability == null:
		return false
	var handler_id := ability.get_handler_id()
	if handler_id == &"volley":
		return bf.can_activate_volley_ability(slot, ability)
	if handler_id == &"lane_shift":
		return bf.can_activate_lane_shift_to_empty(slot, ability)
	return bf.can_activate_mobility_ability_base(slot, ability)

func activate_mobility_ability_from_slot(slot: Node, ability: AbilityData) -> void:
	if ability == null or ability.get_handler_id() != &"volley":
		await bf.activate_mobility_ability_from_slot_base(slot, ability)
		return

	if not bf.can_activate_mobility_ability(slot, ability):
		return

	var used_turns: Dictionary = slot.get_meta("used_mobility_turns", {}).duplicate()
	used_turns[String(ability.ability_id)] = bf.turn_number
	slot.set_meta("used_mobility_turns", used_turns)

	var success := await bf.resolve_volley_from_slot(slot, ability)
	if success:
		bf.used_mobility_ability_keys[bf.get_mobility_usage_key(slot, ability)] = true
	else:
		used_turns.erase(String(ability.ability_id))
		slot.set_meta("used_mobility_turns", used_turns)
	bf.refresh_player_usable_ability_icons()

func resolve_lane_shift(source_slot: Node, ability: AbilityData) -> bool:
	var candidates := bf.get_empty_adjacent_player_front_slots(source_slot)
	var target := await bf.choose_mobility_slot(candidates, ability.ability_name + "  -  Choose an adjacent empty lane")
	if target == null:
		return false
	await bf.move_slot_contents(source_slot, target)
	return true

func resolve_mobilize(source_slot: Node, ability: AbilityData) -> bool:
	var candidates: Array[Node] = []
	for lane in bf.get_adjacent_lanes(bf.get_slot_lane(source_slot)):
		var candidate := bf.find_slot_by_owner_row_lane("player", "front", lane)
		if candidate != null and bf.get_slot_card_data(candidate) == null:
			candidates.append(candidate)
	var target := await bf.choose_mobility_slot(candidates, ability.ability_name + "  -  Choose an adjacent lane")
	if target == null:
		return false
	await bf.move_slot_contents(source_slot, target)
	return true


func resolve_tactic_flow(source_slot: Node, ability: AbilityData) -> bool:
	var candidates: Array[Node] = []
	for lane in ["left", "right"]:
		var slot := bf.find_slot_by_owner_row_lane("player", "front", lane)
		if slot != null and bf.get_slot_card_data(slot) == null:
			candidates.append(slot)
	var target := await bf.choose_mobility_slot(candidates, ability.ability_name + "  -  Choose a side lane")
	if target == null:
		return false
	await bf.move_slot_contents(source_slot, target)
	return true


func resolve_flank_swap(ability: AbilityData, owner_name: String = "player") -> bool:
	if owner_name != "player":
		var ai_lanes := ["left", "middle", "right"]
		ai_lanes.shuffle()
		await bf.swap_owner_lanes(owner_name, ai_lanes[0], ai_lanes[1])
		return true
	var lanes := bf.get_player_front_slots()
	var first := await bf.choose_mobility_slot(lanes, ability.ability_name + "  -  Choose the first lane")
	if first == null:
		return false
	var remaining: Array[Node] = []
	for slot in lanes:
		if slot != first:
			remaining.append(slot)
	var second := await bf.choose_mobility_slot(remaining, ability.ability_name + "  -  Choose the second lane")
	if second == null:
		return false
	await bf.swap_owner_lanes(owner_name, bf.get_slot_lane(first), bf.get_slot_lane(second))
	return true


func move_slot_contents(source: Node, target: Node) -> void:
	if source == null or target == null or not source.has_method("take_slot_snapshot"):
		return
	var snapshot: Dictionary = source.call("take_slot_snapshot")
	await bf.animate_snapshot_between_slots(snapshot, source, target)
	if target.has_method("restore_slot_snapshot"):
		target.call("restore_slot_snapshot", bf.TEST_CARD_SCENE, snapshot)


func swap_slot_contents(first: Node, second: Node) -> void:
	if first == null or second == null:
		return
	var first_snapshot: Dictionary = first.call("take_slot_snapshot")
	var second_snapshot: Dictionary = second.call("take_slot_snapshot")
	bf.animate_snapshot_between_slots(first_snapshot, first, second)
	bf.animate_snapshot_between_slots(second_snapshot, second, first)
	await bf.get_tree().create_timer(0.34).timeout
	first.call("restore_slot_snapshot", bf.TEST_CARD_SCENE, second_snapshot)
	second.call("restore_slot_snapshot", bf.TEST_CARD_SCENE, first_snapshot)


func swap_owner_lanes(owner_name: String, first_lane: String, second_lane: String) -> void:
	for row in ["front", "back"]:
		var first := bf.find_slot_by_owner_row_lane(owner_name, row, first_lane)
		var second := bf.find_slot_by_owner_row_lane(owner_name, row, second_lane)
		await bf.swap_slot_contents(first, second)


func animate_snapshot_between_slots(snapshot: Dictionary, source: Node, target: Node) -> void:
	if bf.card_animation_manager == null:
		return
	var cards: Array = []
	if snapshot.get("card") != null:
		cards.append(snapshot.get("card"))
	cards.append_array(snapshot.get("equipment", []))
	cards.append_array(snapshot.get("stacked_units", []))
	for card in cards:
		bf.card_animation_manager.animate_card_between_nodes(card as CardData, source, target, false)
	await bf.get_tree().create_timer(0.30).timeout


func resolve_stealth_hidden_decoy(back_slot: Node, card_data: CardData, owner_name: String, lane: String) -> bool:
	if back_slot == null or card_data == null:
		return false
	var stealth_ability := bf.get_card_insight_ability(card_data, &"stealth")
	if stealth_ability == null:
		return false
	var result := AbilityResolver.resolve(
		stealth_ability,
		bf.build_ability_context({
			"card": card_data,
			"slot": back_slot,
			"trigger": &"active",
			"lane": lane,
			"owner": owner_name,
		})
	)
	if not bool(result.get("success", false)):
		bf.log_msg("Insight ability failed: Stealth (" + String(result.get("reason", "unknown")) + ").")
		return false

	if owner_name == "player":
		bf.pending_stealth_deployments.append({"slot": back_slot, "card": card_data, "lane": lane})
		back_slot.set_meta("stealth_pending", true)
		return true

	var front_slot := bf.find_slot_by_owner_row_lane(owner_name, "front", lane)
	if front_slot != null and bf.get_slot_card_data(front_slot) == null:
		back_slot.clear_slot()
		front_slot.call("place_card", bf.TEST_CARD_SCENE, card_data, false)
	else:
		back_slot.reveal_card()
	bf.update_ai_visuals()
	return true


func get_card_insight_ability(card_data: CardData, ability_id: StringName) -> AbilityData:
	if card_data == null:
		return null
	for ability in card_data.get_abilities():
		if ability != null and ability.category.to_lower() == "insight" and ability.ability_id == ability_id:
			return ability
	return null


func get_hidden_enemy_gambit_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	if bf.board_slots == null:
		return cards
	for slot in bf.board_slots.get_children():
		if String(slot.get_meta("owner", "")) != "enemy":
			continue
		if not bool(slot.get_meta("face_down", false)):
			continue
		var card_data := bf.get_slot_card_data(slot)
		if bf.is_gambit_card(card_data):
			cards.append(card_data)
	return cards


func resolve_immediate_hidden_gambit_cast(gambit_card: CardData, caster_owner: String, lane: String, slot: Node = null) -> bool:
	if gambit_card == null:
		return false

	var caster_label: String = "Defender"
	var clean_owner: String = caster_owner.to_lower().strip_edges()

	if clean_owner == "enemy" or clean_owner == "ai" or clean_owner == "opponent":
		caster_label = "Enemy"
	elif clean_owner == "player":
		caster_label = "Player"

	for ability in gambit_card.get_abilities():
		if ability == null or ability.category.to_lower() != "mobility":
			continue
		await bf.animate_gambit_activation(slot, gambit_card, true, clean_owner)
		await bf.resolve_mobility_gambit_effect(ability, clean_owner)
		return true
	bf.log_msg(caster_label + " casts " + gambit_card.card_name + " immediately from the " + lane + " lane.")
	return false


func activate_mobility_ability_from_slot_base(slot: Node, ability: AbilityData) -> void:
	if not bf.can_activate_mobility_ability(slot, ability):
		return
	var used_turns: Dictionary = slot.get_meta("used_mobility_turns", {}).duplicate()
	used_turns[String(ability.ability_id)] = bf.turn_number
	slot.set_meta("used_mobility_turns", used_turns)
	var success := false
	match ability.get_handler_id():
		&"lane_shift":
			success = await bf.resolve_lane_shift(slot, ability)
		&"mobilize":
			success = await bf.resolve_mobilize(slot, ability)
		&"flank_swap":
			success = await bf.resolve_flank_swap(ability)
		&"tactic_flow":
			success = await bf.resolve_tactic_flow(slot, ability)
	if success:
		bf.used_mobility_ability_keys[bf.get_mobility_usage_key(slot, ability)] = true
	else:
		used_turns.erase(String(ability.ability_id))
		slot.set_meta("used_mobility_turns", used_turns)
	bf.refresh_player_usable_ability_icons()


func can_activate_mobility_ability_base(slot: Node, ability: AbilityData) -> bool:
	if slot == null or ability == null:
		return false
	if ability.trigger != "active" and ability.get_handler_id() != &"tactic_flow":
		return false
	if String(slot.get_meta("owner", "")) != "player" or bool(slot.get_meta("face_down", false)):
		return false
	if bf.current_phase != bf.BattlePhase.DEPLOYMENT and bf.current_phase != bf.BattlePhase.COMBAT:
		return false
	if bf.phase_transition_busy or bf.combat_resolution_running or bf.parry_system.active:
		return false
	var used_turns: Dictionary = slot.get_meta("used_mobility_turns", {})
	if int(used_turns.get(String(ability.ability_id), -1)) == bf.turn_number:
		return false
	var lane := bf.get_slot_lane(slot)
	match ability.get_handler_id():
		&"lane_shift":
			for candidate in bf.get_player_front_slots():
				if candidate != slot and bf.is_unit_card(bf.get_slot_card_data(candidate)):
					return true
			return false
		&"mobilize":
			for adjacent in bf.get_adjacent_lanes(lane):
				if bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("player", "front", adjacent)) == null:
					return true
			return false
		&"flank_swap":
			return true
		&"tactic_flow":
			if lane != "middle" or String(slot.get_meta("row", "")) != "front":
				return false
			return bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("player", "front", "left")) == null or bf.get_slot_card_data(bf.find_slot_by_owner_row_lane("player", "front", "right")) == null
	return false


func can_activate_lane_shift_to_empty(slot: Node, ability: AbilityData) -> bool:
	if slot == null or ability == null:
		return false
	if ability.trigger != "active":
		return false
	if String(slot.get_meta("owner", "")) != "player" or bool(slot.get_meta("face_down", false)):
		return false
	if bf.current_phase != bf.BattlePhase.DEPLOYMENT and bf.current_phase != bf.BattlePhase.COMBAT:
		return false
	if bf.phase_transition_busy or bf.combat_resolution_running or bf.parry_system.active:
		return false
	if not bf.is_unit_card(bf.get_slot_card_data(slot)):
		return false
	var used_turns: Dictionary = slot.get_meta("used_mobility_turns", {})
	if int(used_turns.get(String(ability.ability_id), -1)) == bf.turn_number:
		return false
	return not bf.get_empty_adjacent_player_front_slots(slot).is_empty()

func get_empty_adjacent_player_front_slots(source_slot: Node) -> Array[Node]:
	var result: Array[Node] = []
	for lane in bf.get_adjacent_lanes(bf.get_slot_lane(source_slot)):
		var candidate := bf.find_slot_by_owner_row_lane("player", "front", lane)
		if candidate == null:
			continue
		if bf.get_slot_card_data(candidate) == null:
			result.append(candidate)
	return result

func can_activate_volley_ability(slot: Node, ability: AbilityData) -> bool:
	if slot == null or ability == null:
		return false
	if String(slot.get_meta("owner", "")) != "player" or bool(slot.get_meta("face_down", false)):
		return false
	if bf.current_phase != bf.BattlePhase.COMBAT:
		return false
	if bf.phase_transition_busy or bf.combat_resolution_running or bf.parry_system.active:
		return false
	if not bf.is_unit_card(bf.get_slot_card_data(slot)):
		return false
	var used_turns: Dictionary = slot.get_meta("used_mobility_turns", {})
	if int(used_turns.get(String(ability.ability_id), -1)) == bf.turn_number:
		return false
	if not bf.can_player_take_priority_action_in_lane(bf.get_slot_lane(slot)):
		return false
	return not bf.get_volley_target_slots_for_slot(slot).is_empty()

func get_volley_target_lanes_for_slot(source_slot: Node) -> Array[String]:
	match bf.get_slot_lane(source_slot):
		"left":
			return ["left", "middle"]
		"middle":
			return ["left", "middle", "right"]
		"right":
			return ["middle", "right"]
	return []

func get_volley_target_slots_for_slot(source_slot: Node) -> Array[Node]:
	var result: Array[Node] = []
	if source_slot == null:
		return result
	if not bf.can_player_take_priority_action_in_lane(bf.get_slot_lane(source_slot)):
		return result
	for lane in bf.get_volley_target_lanes_for_slot(source_slot):
		var enemy_front_slot := bf.find_slot_by_owner_row_lane("enemy", "front", lane)
		if enemy_front_slot != null:
			result.append(enemy_front_slot)
	return result

func resolve_volley_from_slot(source_slot: Node, ability: AbilityData) -> bool:
	var candidates := bf.get_volley_target_slots_for_slot(source_slot)
	var target_slot := await bf.choose_mobility_slot(candidates, ability.ability_name + "  -  Choose enemy lane to attack")
	if target_slot == null:
		return false
	var target_lane := bf.get_slot_lane(target_slot)
	if target_lane == "":
		return false
	await bf.resolve_player_attack_lane_from_specific_attacker(target_lane, source_slot, ability.ability_name)
	return true

func resolve_player_attack_lane_from_specific_attacker(lane: String, attacker_slot: Node, ability_name: String = "Volley") -> void:
	if bf.combat_resolution_running:
		return
	bf.combat_resolution_running = true
	var attacker_lane := bf.get_slot_lane(attacker_slot)
	if not bf.prepare_player_volley_lane_action(attacker_lane, lane):
		bf.combat_resolution_running = false
		return
	bf.player_passed_current_lane = false
	bf.set_active_combat_lane_highlight(lane)
	if attacker_lane == lane:
		bf.log_msg(ability_name + ": attacking the " + lane + " lane.")
	else:
		bf.log_msg(ability_name + ": diagonal attack from the " + attacker_lane + " lane into the " + lane + " lane.")
	await bf.get_tree().create_timer(bf.COMBAT_LANE_START_DELAY).timeout
	var enemy_front_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "front", lane)
	var enemy_back_slot: Node = bf.find_slot_by_owner_row_lane("enemy", "back", lane)
	var player_card: CardData = bf.get_slot_card_data(attacker_slot)
	var enemy_front_card: CardData = bf.get_slot_card_data(enemy_front_slot)
	var enemy_back_card: CardData = bf.get_slot_card_data(enemy_back_slot)
	var enemy_back_is_face_down: bool = enemy_back_card != null and enemy_back_slot != null and bool(enemy_back_slot.get_meta("face_down", false))
	if not bf.is_unit_card(player_card):
		bf.log_msg(ability_name + ": the chosen attacker is no longer a unit.")
		bf.combat_resolution_running = false
		return
	if enemy_back_is_face_down:
		await bf.resolve_volley_attack_into_face_down_backrow(lane, enemy_back_slot, enemy_back_card, ability_name)
		bf.combat_resolution_running = false
		return
	if enemy_front_card == null:
		bf.resolve_monarch_strike(lane, player_card)
		await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
		await bf.advance_combat_lane_after_resolution()
		bf.combat_resolution_running = false
		return
	await bf.resolve_directed_clash(lane, attacker_slot, player_card, enemy_front_slot, enemy_front_card, true)
	if bf.parry_system.active:
		bf.combat_resolution_running = false
		return
	await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
	await bf.advance_combat_lane_after_resolution()
	bf.combat_resolution_running = false

func prepare_player_volley_lane_action(source_lane: String, target_lane: String) -> bool:
	if source_lane == "" or target_lane == "":
		return false
	if not bf.combat_direction_selected:
		if not bf.player_has_initiative and bf.combat_priority_owner != "player":
			bf.log_msg("AI has initiative. You cannot choose the starting lane yet.")
			return false
		if source_lane == "left":
			bf.set_combat_lane_order_from_left()
		elif source_lane == "right":
			bf.set_combat_lane_order_from_right()
		else:
			bf.log_msg("Choose the leftmost or rightmost lane first to set combat direction.")
			return false
	if bf.combat_next_lane_index >= bf.combat_lane_order.size():
		bf.log_msg("All combat lanes are already resolved.")
		return false
	var expected_lane: String = bf.combat_lane_order[bf.combat_next_lane_index]
	if source_lane != expected_lane:
		bf.log_msg("Next combat must resolve from the " + expected_lane + " lane.")
		return false
	if bf.combat_priority_owner != "player":
		bf.log_msg("AI has priority in the " + source_lane + " lane. You can act after AI passes or resolves its action.")
		return false
	return true

func resolve_volley_attack_into_face_down_backrow(lane: String, enemy_back_slot: Node, enemy_back_card: CardData, ability_name: String = "Volley") -> void:
	if enemy_back_slot == null or enemy_back_card == null:
		return
	enemy_back_slot.set_meta("interacted_this_round", true)
	if enemy_back_slot.has_method("reveal_card"):
		enemy_back_slot.reveal_card()
	await bf.get_tree().create_timer(bf.BLUFF_REVEAL_DELAY).timeout
	if bf.is_gambit_card(enemy_back_card):
		bf.log_msg(ability_name + " failed: " + enemy_back_card.card_name + " was a hidden Gambit.")
		var mobility_returned := await bf.resolve_immediate_hidden_gambit_cast(enemy_back_card, "enemy", lane, enemy_back_slot)
		if not mobility_returned:
			bf.send_slot_card_to_discard(enemy_back_slot)
		await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
		await bf.advance_combat_lane_after_resolution()
		return
	if bf.resolve_stealth_hidden_decoy(enemy_back_slot, enemy_back_card, "enemy", lane):
		bf.log_msg(ability_name + " is spent. No follow-up attack is available this lane.")
		await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
		await bf.advance_combat_lane_after_resolution()
		return
	bf.add_aurion("player", 1, "Successful " + ability_name + " read: " + enemy_back_card.card_name + " was not a Gambit.")
	bf.log_msg(ability_name + " read correctly: " + enemy_back_card.card_name + " was not a Gambit. Decoy is discarded and the attack is spent.")
	bf.send_slot_card_to_discard(enemy_back_slot)
	await bf.get_tree().create_timer(bf.COMBAT_LANE_END_DELAY).timeout
	await bf.advance_combat_lane_after_resolution()
