extends "res://battlefield/BattlefieldManagerPhase.gd"


func _on_hand_card_drag_released(card: CardUI, screen_position: Vector2) -> void:
	var target_node := get_3d_node_under_screen_position(screen_position)
	var target_slot := find_board_slot_from_node(target_node)

	if target_slot == null and selected_card_data != null and get_clean_card_type(selected_card_data) == "equipment":
		target_slot = find_equipment_target_slot_from_screen_position(screen_position)

	if target_slot != null:
		if current_phase != BattlePhase.DEPLOYMENT:
			log_msg("Cards can only be deployed during the Deployment Phase.")
			hand.return_dragged_card_to_hand(card)
			cancel_selected_card()
			return

		var placed := try_place_selected_card_on_slot(target_slot)

		if placed:
			hand.consume_dragged_card(card)
		else:
			hand.return_dragged_card_to_hand(card)

		cancel_selected_card()
		return

	if is_node_inside_target(target_node, tribute_pile):
		if current_phase != BattlePhase.TRIBUTE:
			log_msg("Cards can only be sent to Tribute during the Tribute Phase.")
			hand.return_dragged_card_to_hand(card)
			cancel_selected_card()
			return

		var sacrificed := try_sacrifice_selected_card_to_tribute()

		if sacrificed:
			hand.consume_dragged_card(card)
		else:
			hand.return_dragged_card_to_hand(card)

		cancel_selected_card()
		return

	log_msg("Card dropped nowhere valid.")
	hand.return_dragged_card_to_hand(card)
	cancel_selected_card()


func find_equipment_target_slot_from_screen_position(screen_position: Vector2) -> Node:
	if board_slots == null:
		return null

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null

	var best_slot: Node = null
	var best_distance := 999999.0
	var max_distance := 260.0

	for slot in board_slots.get_children():
		if slot.get_meta("owner", "") != "player":
			continue

		if slot.get_meta("row", "") != "front":
			continue

		if not slot.occupied:
			continue

		if not is_unit_card(get_slot_card_data(slot)):
			continue

		if slot.has_method("can_attach_equipment") and not slot.can_attach_equipment():
			continue

		var slot_screen_position := camera.unproject_position(slot.global_position)
		var distance := slot_screen_position.distance_to(screen_position)

		if distance < best_distance:
			best_distance = distance
			best_slot = slot

	if best_distance <= max_distance:
		return best_slot

	return null


func try_place_selected_card_on_slot(slot: Node) -> bool:
	if slot == null:
		return false

	var slot_id: String = slot.get_meta("slot_id", "")

	if not has_selected_card or selected_card_data == null:
		log_msg("No card selected.")
		return false

	if not is_valid_slot_for_selected_card(slot):
		log_msg("Invalid placement for " + selected_card_data.card_name + " on " + str(slot_id))
		return false

	if not tribute_manager.can_afford(selected_card_data.tribute_cost):
		log_msg("Not enough Tribute Points. Need " + str(selected_card_data.tribute_cost) + ", have " + str(tribute_manager.current_tribute_points) + ".")
		return false

	var card_type := get_clean_card_type(selected_card_data)
	var placed_successfully := false

	if card_type == "equipment":
		if slot.has_method("attach_equipment"):
			placed_successfully = slot.attach_equipment(selected_card_scene, selected_card_data)
	else:
		var place_face_down: bool = slot.get_meta("row", "") == "back"
		placed_successfully = slot.place_card(selected_card_scene, selected_card_data, place_face_down)

	if placed_successfully:
		tribute_manager.spend_tribute(selected_card_data.tribute_cost)
		log_msg("Spent " + str(selected_card_data.tribute_cost) + " TP. " + tribute_manager.get_status_text())
		handle_card_deployed(selected_card_data)
		return true

	return false


func is_valid_slot_for_selected_card(slot: Node) -> bool:
	if current_phase != BattlePhase.DEPLOYMENT:
		return false

	if not has_selected_card or selected_card_data == null:
		return false

	if slot.get_meta("owner", "") != "player":
		return false

	var card_type := get_clean_card_type(selected_card_data)
	var slot_row: String = slot.get_meta("row", "")
	var lane := get_slot_lane(slot)

	if card_type == "unit":
		return slot_row == "front" and not slot.occupied

	if card_type == "equipment":
		if slot_row != "front":
			return false
		if not slot.occupied:
			return false
		if not is_unit_card(get_slot_card_data(slot)):
			return false
		if slot.has_method("can_attach_equipment"):
			return slot.can_attach_equipment()
		return false

	if is_spell_like_type(card_type):
		if slot_row != "back":
			return false
		if slot.occupied:
			return false
		return lane_has_front_unit("player", lane)

	return false


func _on_slot_right_clicked(_slot: Node) -> void:
	log_msg("Manual battlefield clearing is disabled. Cards leave the board only through combat, cleanup, or abilities.")


func lane_has_front_unit(owner: String, lane: String) -> bool:
	var front_slot := find_slot_by_owner_row_lane(owner, "front", lane)
	return front_slot != null and front_slot.occupied and is_unit_card(get_slot_card_data(front_slot))


func is_unit_card(card_data: CardData) -> bool:
	return card_data != null and get_clean_card_type(card_data) == "unit"


func is_spell_like_type(card_type: String) -> bool:
	return card_type == "spell" or card_type == "event" or card_type == "trap" or card_type == "ruse"


func get_clean_card_type(card_data: CardData) -> String:
	if card_data == null:
		return ""

	return card_data.card_type.to_lower().strip_edges()
