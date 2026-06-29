class_name BattlefieldDeploymentController
extends RefCounted

## Domain controller extracted from BattlefieldManager. The manager facade preserves
## scene callbacks and dynamic-call compatibility.

var bf: BattlefieldManager


func _init(owner_battlefield: BattlefieldManager) -> void:
	bf = owner_battlefield


func select_card(card_data: CardData) -> void:
	if card_data == null:
		return
	bf.selected_card_scene = bf.TEST_CARD_SCENE
	bf.selected_card_data = card_data
	bf.has_selected_card = true
	bf.log_msg("Selected: " + card_data.card_name + " | TP " + str(card_data.tribute_cost) + " | " + card_data.card_type)
	bf.update_slot_highlights()


func cancel_selected_card() -> void:
	bf.selected_card_scene = null
	bf.selected_card_data = null
	bf.has_selected_card = false
	bf.update_slot_highlights()





func try_place_selected_card_on_slot(slot: Node) -> bool:
	if slot == null:
		return false

	if not bf.has_selected_card or bf.selected_card_data == null:
		return false

	var slot_id: String = String(slot.get_meta("slot_id", ""))
	var slot_row: String = String(slot.get_meta("row", ""))
	var card_type: String = bf.get_clean_card_type(bf.selected_card_data)

	if bf.can_promote_selected_card_on_slot(slot):
		return bf.try_promote_selected_card_on_slot(slot)

	if card_type == "equipment" and not bf.can_place_selected_equipment_face_down(slot):
		return bf.try_attach_selected_equipment_to_slot(slot)

	if not bf.is_valid_slot_for_selected_card(slot):
		bf.log_msg("Invalid placement for " + bf.selected_card_data.card_name + " on " + slot_id)
		return false

	if not bf.should_skip_player_faction_gate_for_slot(bf.selected_card_data, slot) and not bf.player_card_passes_faction_gate(bf.selected_card_data):
		return false

	var place_face_down: bool = false

	if (card_type == "unit" or card_type == "equipment") and slot_row == "back":
		place_face_down = true

	if bf.is_gambit_card(bf.selected_card_data):
		# Front row Gambits are always face up.
		# Back row Gambits should normally come through confirm_pending_spell_placement().
		place_face_down = false

	var deployment_cost: int = bf.get_player_face_down_card_deployment_cost(bf.selected_card_data, place_face_down)

	if not bf.tribute_manager.can_afford(deployment_cost):
		var cost_reason: String = "Shadowtax face-down setup cost" if place_face_down else "printed cost"
		bf.log_msg("Not enough Tribute Points. Need " + str(deployment_cost) + " TP for " + cost_reason + ", have " + str(bf.tribute_manager.current_tribute_points) + ".")
		return false

	var placed_successfully: bool = slot.place_card(bf.TEST_CARD_SCENE, bf.selected_card_data, place_face_down)

	if placed_successfully:
		bf.tribute_manager.spend_tribute(deployment_cost)

		if place_face_down:
			bf.player_face_down_gambits_this_round += 1
			bf.log_msg("Shadowtax paid for face-down card: " + bf.selected_card_data.card_name + ".")

		bf.log_msg("Spent " + str(deployment_cost) + " TP. " + bf.tribute_manager.get_status_text())
		bf.handle_card_deployed(bf.selected_card_data, slot)
		return true

	return false

func try_sacrifice_selected_card_to_tribute() -> bool:
	if not bf.has_selected_card or bf.selected_card_data == null:
		return false

	if bf.tribute_manager == null:
		return false

	if not bf.tribute_manager.can_offer_card_this_turn():
		bf.log_msg("Tribute already used this turn. Only 1 card can be used as Tribute per turn.")
		return false

	var offered_card_name: String = bf.selected_card_data.card_name
	var offered_card_type: String = bf.get_clean_card_type(bf.selected_card_data)

	if offered_card_type == "gambit":
		bf.tribute_manager.add_temporary_tribute(bf.selected_card_data)
		bf.tribute_manager.tribute_card_used_this_turn = true
		bf.log_msg("Offered " + offered_card_name + " for temporary Tribute. +2 TP this turn.")
	else:
		bf.tribute_manager.add_permanent_tribute(bf.selected_card_data)
		bf.tribute_manager.tribute_card_used_this_turn = true
		bf.log_msg("Offered " + offered_card_name + " for permanent Tribute. +1 permanent TP.")

	if bf.tribute_pile != null:
		bf.tribute_pile.add_card(bf.selected_card_data)

	bf.update_tribute_counter()
	call_deferred("try_auto_advance_tribute_phase")
	return true



func get_clean_card_race(card_data: CardData) -> String:
	return CardRules.get_clean_card_race(card_data)


func should_skip_player_faction_gate_for_slot(card_data: CardData, slot: Node) -> bool:
	if card_data == null or slot == null:
		return false

	# Face-down cards do not need faction access.
	# Current prototype face-down placements happen in the back row.
	var slot_row: String = String(slot.get_meta("row", ""))
	if slot_row != "back":
		return false

	# Units placed in the back row are face down.
	if bf.is_unit_card(card_data):
		return true

	# Gambits in the back row can be chosen face down from the visibility prompt,
	# so the slot should remain legal even without faction access.
	if bf.is_gambit_card(card_data) or bf.is_equipment_card(card_data):
		return true

	return false



func player_card_passes_faction_gate(card_data: CardData, show_log: bool = false) -> bool:
	if card_data == null:
		return false

	var clean_race: String = bf.get_clean_card_race(card_data)

	if clean_race == "" or clean_race == "neutral":
		return true

	if bf.tribute_manager == null:
		if show_log:
			bf.log_msg("Faction Gate blocked " + card_data.card_name + ": TributeManager is missing.")
		return false

	if bf.tribute_manager.has_method("has_faction_access"):
		var has_access: bool = bf.tribute_manager.has_faction_access(clean_race)

		if not has_access and show_log:
			bf.log_msg("Faction Gate locked: need at least 1 " + clean_race.capitalize() + " card in permanent Tribute to play " + card_data.card_name + ".")

		return has_access

	if show_log:
		bf.log_msg("Faction Gate could not check " + card_data.card_name + ". TributeManager has no has_faction_access method.")

	return true


func can_promote_selected_card_on_slot(slot: Node) -> bool:
	if bf.current_phase != bf.BattlePhase.DEPLOYMENT:
		return false

	if not bf.has_selected_card or bf.selected_card_data == null:
		return false

	if slot == null:
		return false

	if String(slot.get_meta("owner", "")) != "player":
		return false

	if String(slot.get_meta("row", "")) != "front":
		return false

	if not bool(slot.get_meta("occupied", false)):
		return false

	if bool(slot.get_meta("face_down", false)):
		return false

	if not bf.is_unit_card(bf.selected_card_data):
		return false

	if not bf.player_card_passes_faction_gate(bf.selected_card_data, false):
		return false

	var old_unit: CardData = bf.get_slot_card_data(slot)

	if not bf.is_unit_card(old_unit):
		return false

	var new_race: String = bf.get_clean_card_race(bf.selected_card_data)
	var old_race: String = bf.get_clean_card_race(old_unit)

	if new_race == "" or old_race == "":
		return false

	if new_race != old_race:
		return false

	if bf.selected_card_data.tribute_cost <= old_unit.tribute_cost:
		return false

	return true


func try_promote_selected_card_on_slot(slot: Node) -> bool:
	if not bf.player_card_passes_faction_gate(bf.selected_card_data, true):
		return false

	if not bf.can_promote_selected_card_on_slot(slot):
		bf.log_msg("Invalid promotion target.")
		return false

	if bf.tribute_manager == null:
		return false

	var old_unit: CardData = bf.get_slot_card_data(slot)
	var new_unit: CardData = bf.selected_card_data
	var promotion_cost: int = new_unit.tribute_cost

	if not bf.tribute_manager.can_afford(promotion_cost):
		bf.log_msg("Not enough Tribute Points to promote. Need " + str(promotion_cost) + ", have " + str(bf.tribute_manager.current_tribute_points) + ".")
		return false

	var placed_successfully: bool = bf.promote_slot_unit_preserving_equipment(slot, new_unit, "player")

	if not placed_successfully:
		bf.log_msg("Promotion failed. Could not place " + new_unit.card_name + " after discarding " + old_unit.card_name + ".")
		return false

	bf.tribute_manager.spend_tribute(promotion_cost)
	bf.log_msg("Promoted " + old_unit.card_name + " into " + new_unit.card_name + " for full cost: " + str(promotion_cost) + " TP.")
	bf.log_msg("Spent " + str(promotion_cost) + " TP. " + bf.tribute_manager.get_status_text())
	bf.handle_card_deployed(new_unit, slot)
	return true

func is_valid_slot_for_selected_card(slot: Node) -> bool:
	if bf.current_phase != bf.BattlePhase.DEPLOYMENT:
		return false

	if not bf.has_selected_card or bf.selected_card_data == null:
		return false

	if slot == null:
		return false

	if String(slot.get_meta("owner", "")) != "player":
		return false

	if not bf.should_skip_player_faction_gate_for_slot(bf.selected_card_data, slot):
		if not bf.player_card_passes_faction_gate(bf.selected_card_data, false):
			return false

	var slot_row: String = String(slot.get_meta("row", ""))
	var slot_occupied: bool = bool(slot.get_meta("occupied", false))
	var card_type: String = bf.get_clean_card_type(bf.selected_card_data)

	if card_type == "equipment":
		if not slot_occupied:
			return slot_row == "back"

		if not slot.has_method("can_attach_equipment"):
			return false

		if not slot.can_attach_equipment():
			return false

		var existing_card: CardData = bf.get_slot_card_data(slot)
		return bf.is_unit_card(existing_card)

	if bf.is_gambit_card(bf.selected_card_data):
		# Spells can go front or back, any lane.
		# Front = face up automatically.
		# Back = prompt for face up / face down.
		return (slot_row == "front" or slot_row == "back") and not slot_occupied

	if card_type == "unit":
		# Units can go front face-up or back face-down.
		return (slot_row == "front" or slot_row == "back") and not slot_occupied

	return false


func can_place_selected_equipment_face_down(slot: Node) -> bool:
	if slot == null or bf.selected_card_data == null:
		return false
	return (
		bf.is_equipment_card(bf.selected_card_data)
		and String(slot.get_meta("owner", "")) == "player"
		and String(slot.get_meta("row", "")) == "back"
		and not bool(slot.get_meta("occupied", false))
	)


func update_slot_highlights() -> void:
	if bf.board_slots == null:
		return

	for slot in bf.board_slots.get_children():
		if not slot.has_method("set_highlight") or not slot.has_method("set_invalid_highlight"):
			continue

		var has_promotion_highlight: bool = slot.has_method("set_promotion_highlight")

		slot.set_highlight(false)
		slot.set_invalid_highlight(false)

		if has_promotion_highlight:
			slot.set_promotion_highlight(false)

		if not bf.has_selected_card or bf.current_phase != bf.BattlePhase.DEPLOYMENT or bf.player_passed_deployment:
			continue

		if bf.can_promote_selected_card_on_slot(slot):
			if has_promotion_highlight:
				slot.set_promotion_highlight(true)
			else:
				slot.set_highlight(true)

				if slot.has_method("set_outline_color"):
					slot.set_outline_color(Color(1.0, 0.82, 0.12, 1.0))
		elif bf.is_valid_slot_for_selected_card(slot):
			slot.set_highlight(true)
		else:
			slot.set_invalid_highlight(true)

func get_clean_card_type(card_data: CardData) -> String:
	return CardRules.get_clean_card_type(card_data)


func is_gambit_card(card_data: CardData) -> bool:
	return CardRules.is_gambit_card(card_data)


# Legacy wrapper: older code still calls this for the old spell-like bucket.


func is_equipment_card(card_data: CardData) -> bool:
	return CardRules.is_equipment_card(card_data)


func is_spell_card(card_data: CardData) -> bool:
	return CardRules.is_spell_card(card_data)


func get_face_down_card_setup_cost(count_already_set_this_round: int) -> int:
	return CardRules.get_face_down_card_setup_cost(count_already_set_this_round)


func get_player_next_face_down_card_setup_cost() -> int:
	return bf.get_face_down_card_setup_cost(bf.player_face_down_gambits_this_round)


func get_ai_next_face_down_card_setup_cost() -> int:
	return bf.get_face_down_card_setup_cost(bf.ai_face_down_gambits_this_round)


func get_player_face_down_card_deployment_cost(card_data: CardData, place_face_down: bool) -> int:
	if card_data == null:
		return 0

	if place_face_down:
		return bf.get_player_next_face_down_card_setup_cost()

	return card_data.tribute_cost


func get_ai_face_down_card_deployment_cost(card_data: CardData, place_face_down: bool) -> int:
	if card_data == null:
		return 0

	if place_face_down:
		return bf.get_ai_next_face_down_card_setup_cost()

	return card_data.tribute_cost


# Legacy wrappers kept so older code still works.
func reset_face_down_gambit_setup_counters() -> void:
	bf.player_face_down_gambits_this_round = 0
	bf.ai_face_down_gambits_this_round = 0


func return_card_to_hand_safely(card: CardUI) -> void:
	if bf.hand == null:
		return

	if card != null and is_instance_valid(card):
		card.mouse_is_pressed = false
		card.is_dragging = false
		card.set_process(false)

	if bf.hand.has_method("return_dragged_card_to_hand"):
		bf.hand.return_dragged_card_to_hand(card)
	if bf.player_hand_3d != null:
		bf.player_hand_3d.restore_card(
			card,
			bf.last_player_hand_animation_start,
			bf.has_player_hand_animation_start
		)
	bf.has_player_hand_animation_start = false


func is_unit_card(card_data: CardData) -> bool:
	return CardRules.is_unit_card(card_data)


func try_attach_selected_equipment_to_slot(slot: Node) -> bool:
	if slot == null:
		return false

	if bf.selected_card_data == null:
		return false

	if not bf.is_equipment_card(bf.selected_card_data):
		return false

	if not bf.player_card_passes_faction_gate(bf.selected_card_data, true):
		return false

	if String(slot.get_meta("owner", "")) != "player":
		bf.log_msg("Equipment can only be attached to your units.")
		return false

	if not bool(slot.get_meta("occupied", false)):
		bf.log_msg("Equipment cannot be placed alone. Attach it to an existing unit.")
		return false

	if bool(slot.get_meta("face_down", false)):
		bf.log_msg("Equipment cannot be attached to a face-down card.")
		return false
	
	var existing_card: CardData = bf.get_slot_card_data(slot)

	if not bf.is_unit_card(existing_card):
		bf.log_msg("Equipment can only be attached to a unit.")
		return false

	if not slot.has_method("can_attach_equipment") or not slot.can_attach_equipment():
		bf.log_msg("This unit already has the maximum 2 equipment cards.")
		return false

	if not bf.tribute_manager.can_afford(bf.selected_card_data.tribute_cost):
		bf.log_msg("Not enough Tribute Points. Need " + str(bf.selected_card_data.tribute_cost) + ", have " + str(bf.tribute_manager.current_tribute_points) + ".")
		return false

	if not slot.has_method("attach_equipment"):
		bf.log_msg("This slot does not support equipment attachment.")
		return false

	var attached: bool = slot.attach_equipment(bf.TEST_CARD_SCENE, bf.selected_card_data)

	if attached:
		bf.tribute_manager.spend_tribute(bf.selected_card_data.tribute_cost)
		bf.log_msg("Attached " + bf.selected_card_data.card_name + " to " + existing_card.card_name + ".")
		bf.log_msg("Spent " + str(bf.selected_card_data.tribute_cost) + " TP. " + bf.tribute_manager.get_status_text())
		bf.handle_card_deployed(bf.selected_card_data, slot)
		return true

	return false


func confirm_pending_spell_placement(place_face_down: bool) -> void:
	if bf.pending_spell_slot == null:
		bf.hide_spell_choice_panel()
		bf.cancel_selected_card()
		return

	if bf.selected_card_data == null:
		bf.hide_spell_choice_panel()
		bf.cancel_selected_card()
		return

	if not bf.is_gambit_card(bf.selected_card_data):
		bf.hide_spell_choice_panel()
		bf.cancel_selected_card()
		return

	if not place_face_down:
		if not bf.player_card_passes_faction_gate(bf.selected_card_data, true):
			bf.hide_spell_choice_panel()
			bf.cancel_selected_card()
			return

	if bf.current_phase != bf.BattlePhase.DEPLOYMENT:
		bf.log_msg("Spells can only be placed during the Deployment Phase.")
		bf.hide_spell_choice_panel()
		bf.cancel_selected_card()
		return

	if String(bf.pending_spell_slot.get_meta("owner", "")) != "player":
		bf.log_msg("Spells can only be placed on your side of the board.")
		bf.hide_spell_choice_panel()
		bf.cancel_selected_card()
		return

	if String(bf.pending_spell_slot.get_meta("row", "")) != "back":
		bf.log_msg("Only back-row spells can be placed face down.")
		bf.hide_spell_choice_panel()
		bf.cancel_selected_card()
		return

	if bool(bf.pending_spell_slot.get_meta("occupied", false)):
		bf.log_msg("That slot is already occupied.")
		bf.hide_spell_choice_panel()
		bf.cancel_selected_card()
		return

	if not bf.player_card_passes_faction_gate(bf.selected_card_data):
		bf.log_msg("Faction Gate locked for " + bf.selected_card_data.card_name + ".")
		bf.hide_spell_choice_panel()
		bf.cancel_selected_card()
		return

	var deployment_cost: int = bf.get_player_face_down_card_deployment_cost(bf.selected_card_data, place_face_down)

	if not bf.tribute_manager.can_afford(deployment_cost):
		var cost_reason: String = "face-down setup cost" if place_face_down else "printed cost"
		bf.log_msg("Not enough Tribute Points. Need " + str(deployment_cost) + " TP for " + cost_reason + ", have " + str(bf.tribute_manager.current_tribute_points) + ".")
		bf.hide_spell_choice_panel()
		bf.cancel_selected_card()
		return

	var spell_card_data: CardData = bf.selected_card_data
	var spell_slot: Node = bf.pending_spell_slot
	var spell_card_ui: CardUI = bf.pending_spell_card_ui

	if spell_card_ui != null and is_instance_valid(spell_card_ui):
		spell_card_ui.visible = false

	bf.hide_spell_choice_panel()

	await bf.play_player_hand_to_node_animation(spell_card_data, spell_slot, place_face_down)

	var placed: bool = spell_slot.place_card(bf.TEST_CARD_SCENE, spell_card_data, place_face_down)

	if placed:
		bf.tribute_manager.spend_tribute(deployment_cost)

		if place_face_down:
			bf.player_face_down_gambits_this_round += 1

		var visibility_text: String = "face down" if place_face_down else "face up"
		var cost_text: String = "setup cost" if place_face_down else "printed cost"
		bf.log_msg("Placed Gambit " + spell_card_data.card_name + " " + visibility_text + ".")
		bf.log_msg("Spent " + str(deployment_cost) + " TP " + cost_text + ". " + bf.tribute_manager.get_status_text())

		if spell_card_ui != null and bf.hand != null:
			bf.hand.consume_dragged_card(spell_card_ui)
		elif bf.hand != null:
			bf.hand.remove_selected_card()

		bf.handle_card_deployed(spell_card_data, spell_slot)
	else:
		if spell_card_ui != null and is_instance_valid(spell_card_ui):
			spell_card_ui.visible = true

		if spell_card_ui != null:
			bf.return_card_to_hand_safely(spell_card_ui)

	bf.cancel_selected_card()


func clear_deployment_slot_highlights_for_animation() -> void:
	if bf.board_slots == null:
		return

	for slot in bf.board_slots.get_children():
		if slot.has_method("set_highlight"):
			slot.set_highlight(false)

		if slot.has_method("set_invalid_highlight"):
			slot.set_invalid_highlight(false)

		if slot.has_method("set_promotion_highlight"):
			slot.set_promotion_highlight(false)


func cleanup_battlefield_spells() -> void:
	bf.cleanup_phase_one_board_cards()


func cleanup_face_up_gambits_before_combat() -> void:
	if bf.board_slots == null:
		return

	var discarded_count: int = 0

	for slot in bf.board_slots.get_children():
		var card_data: CardData = bf.get_slot_card_data(slot)

		if card_data == null:
			continue

		if not bf.is_gambit_card(card_data):
			continue

		var is_face_down: bool = bool(slot.get_meta("face_down", false))

		if is_face_down:
			continue

		var slot_owner: String = String(slot.get_meta("owner", ""))
		bf.discard_slot_card_for_cleanup(slot, card_data, slot_owner)
		discarded_count += 1

	if discarded_count > 0:
		bf.log_msg("Combat setup: removed " + str(discarded_count) + " face-up Gambit card(s) from the battlefield.")

	bf.update_ai_visuals()


func cleanup_phase_one_board_cards() -> void:
	if bf.board_slots == null:
		return

	var returned_count: int = 0
	var discarded_count: int = 0

	for slot in bf.board_slots.get_children():
		var card_data: CardData = bf.get_slot_card_data(slot)

		if card_data == null:
			continue

		var slot_owner: String = String(slot.get_meta("owner", ""))
		var slot_row: String = String(slot.get_meta("row", ""))
		var is_face_down: bool = bool(slot.get_meta("face_down", false))
		var was_interacted: bool = bool(slot.get_meta("interacted_this_round", false))

		if is_face_down and slot_row == "back" and not was_interacted:
			bf.return_face_down_setup_card_to_owner_hand(slot, card_data, slot_owner)
			returned_count += 1
			continue

		if bf.is_gambit_card(card_data) and not is_face_down:
			bf.discard_slot_card_for_cleanup(slot, card_data, slot_owner)
			discarded_count += 1
			continue

		slot.set_meta("interacted_this_round", false)

	if returned_count > 0:
		bf.log_msg("Returned " + str(returned_count) + " untouched face-down back-row card(s) to hand.")

	if discarded_count > 0:
		bf.log_msg("Cleaned up " + str(discarded_count) + " face-up Gambit card(s).")

	bf.update_ai_visuals()


func return_face_down_setup_card_to_owner_hand(slot: Node, card_data: CardData, slot_owner: String) -> void:
	if card_data == null or slot == null:
		return

	if slot_owner == "enemy":
		bf.ai_hand.append(card_data)
	else:
		if bf.hand != null:
			bf.hand.add_card_to_hand(card_data)

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	slot.set_meta("interacted_this_round", false)


func discard_slot_card_for_cleanup(slot: Node, card_data: CardData, slot_owner: String) -> void:
	if card_data == null or slot == null:
		return

	bf.discard_cards_with_animation([card_data], slot, slot_owner)

	if slot.has_method("clear_slot"):
		slot.clear_slot()

	slot.set_meta("interacted_this_round", false)
